-- Attack hooks and correlation state share the collector's routed tracker and tables.
return function(mod,api,C,deps)
    local Armor,Attack,DamageCalculation,Damage=deps.Armor,deps.Attack,deps.DamageCalculation,deps.Damage
    local local_unit,extension,breed=deps.local_unit,deps.extension,deps.breed
    local enemy_display,is_enemy,live_context=deps.enemy_display,deps.is_enemy,deps.context
    local Measurements,invoke,contained=deps.Experimental,deps.invoke,deps.contained
    local WeaponExplosions=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/weapon_explosions")
    local scope,processing_explosions
    local special_queues={}
    local action_ids=setmetatable({},{__mode="k"})
    local function new_attack(action, category)
        local c = live_context(action, category)
        if not c then return end
        local template=action._weapon_template
        -- a blitz or ability wielded as a weapon (missile launcher, transonic claw) is not the loadout's melee or ranged
        local wielded=action._wielded_slot
        if template and not c.grenade and (wielded==nil or wielded=="slot_primary" or wielded=="slot_secondary") then
            c.weapon_slot=deps.PartyWeapon.slot(template)
            if c.weapon_slot then
                local component=action._weapon_action_component
                local settings=action._action_settings or {}
                local powered=component and component.special_active_at_start
                    and (category=="melee" or settings.fire_special_configuration~=nil)
                c.weapon_special=deps.PartyWeapon.action_special(template,settings,c.weapon_slot,category)
                    or powered==true
            end
        end
        local explosion_profiles=category=="ranged" and WeaponExplosions.profiles(template)
        if type(explosion_profiles)=="table" and next(explosion_profiles) then c.explosive=true;c.hitscan_explosive=true end
        -- measured before it is queued, so a fault here leaves no queued attack that never resolves
        local measurement=Measurements.attack(action,category)
        local id = api.tracker():begin_attack(c)
        C.attacks[id] = {action=action,id = id, context = c, measurement=measurement, start = C.clock, remaining = 0, closed = false}

        C.attacks[id].hitscan_explosions=type(explosion_profiles)=="table" and next(explosion_profiles) and explosion_profiles or nil
        return id
    end
    local function close_attack(id)
        local a = id and C.attacks[id]
        if a and not a.closed then a.closed = true; a.closed_at = C.clock end
    end
    local function scoped_hook(class_name, method, before, after)
        local tag=class_name..":"..method
        mod:hook(class_name, method, function(func, action, ...)
            local previous = scope
            local ok,s=contained(tag,pcall(before,action,...))
            scope = ok and s or previous
            local result = {func(action, ...)}
            if after then contained(tag,pcall(after,action,scope,...)) end
            scope = previous
            return unpack(result)
        end)
    end
    scoped_hook("ActionShootHitScan", "_shoot", function(action) return new_attack(action, "ranged") end,
        function(_, id) close_attack(id) end)
    -- Shotgun pellets may span several simulation frames; collect at the
    -- concrete damage-processing call, which executes once for the shell.
    scoped_hook("ActionShootPellets", "_process_hits", function(action) return new_attack(action, "ranged") end,
        function(_, id) close_attack(id) end)
    scoped_hook("ActionDamageTarget", "_deal_damage", function(action) return new_attack(action,"ranged") end,
        function(_, id) close_attack(id) end)
    mod:hook_safe("ActionSweep", "start", function(action)
        invoke(function() action_ids[action] = nil end)
    end)
    scoped_hook("ActionSweep", "fixed_update", function(action)
        if not action_ids[action] then
            -- A cancelled wind-up is not an attack. Start when its damage
            -- window is reached, or on the first actual damage call below.
            local component = action._action_sweep_component
            if component and component.sweep_state ~= "before_damage_window" then
                action_ids[action] = new_attack(action, "melee")
            end
        end
        return action_ids[action] or {action = action, category = "melee"}
    end, function(action, id)
        local component = action._action_sweep_component
        if type(id) == "table" then
            id = action_ids[action]
            if not id and component and component.sweep_state ~= "before_damage_window" then
                id = new_attack(action,"melee"); action_ids[action] = id
            end
        end
        if component and component.sweep_state == "after_damage_window" then close_attack(id) end
    end)
    mod:hook_safe("ActionSweep", "finish", function(action)
        invoke(function()
            local id = action_ids[action]
            close_attack(id); action_ids[action] = nil
        end)
    end)

    -- Every weapon projectile gets a launch record. Server/Psykhanium damage
    -- retains its unit identity; client reports can be used only when there is
    -- exactly one compatible live projectile, otherwise the whole shot is censored.
    local function launch_projectile(action,template)
        if not template then return end
        local id = new_attack(action,"ranged")
        if not id then return end
        local a=C.attacks[id]
        a.projectile=true;a.template_name=template.name;a.profiles={};a.explosion_profiles={}
        local function profile(p) if p and p.name then a.profiles[p.name]=true end end
        for _, stage in pairs(template.damage or {}) do
            if type(stage)=="table" then
                profile(stage.damage_profile)
                local explosion=stage.explosion_template
                if explosion then
                    profile(explosion.damage_profile);profile(explosion.close_damage_profile)
                    if explosion.damage_profile then a.explosion_profiles[explosion.damage_profile.name]=true end
                    if explosion.close_damage_profile then a.explosion_profiles[explosion.close_damage_profile.name]=true end
                    a.context.explosive=true
                end
            end
        end
        api.tracker().pending[id].context.explosive=a.context.explosive
        a.exact=action._is_server==true

        return id
    end
    scoped_hook("ActionShootProjectile", "_shoot", function(action, position, rotation, power, charge, t, fire_config)
        return launch_projectile(action,fire_config and fire_config.projectile)
    end, function(action, id, position, rotation, power, charge, t)
        local a=id and C.attacks[id]
    end)
    local ActionUtility=require("scripts/extension_systems/weapon/actions/utilities/action_utility")
    scoped_hook("ActionThrowGrenade","_spawn_projectile",function(action)
        local template=ActionUtility.projectile_template(action._ability_type,action._action_settings,action._weapon_template,action._ability_extension)
        local id=launch_projectile(action,template)
        if id then local a=C.attacks[id];a.context.grenade=true;api.tracker().pending[id].context.grenade=true end
        return id
    end)
    local function attach_projectile(unit,owner,template_name)
        if owner~=local_unit() then return end
        local chosen
        if type(scope)=="number" and C.attacks[scope] and C.attacks[scope].projectile then chosen=scope end
        if not chosen then
            for id,a in pairs(C.attacks) do
                if a.projectile and not a.unit and a.template_name==template_name and (not chosen or id<chosen) then chosen=id end
            end
        end
        if chosen then C.projectiles[unit]=chosen;C.attacks[chosen].unit=unit; end
    end
    mod:hook_safe("ProjectileDamageExtension","init",function(_,ctx,unit,data)
        attach_projectile(unit,data.owner_unit,data.projectile_template.name)
    end)
    mod:hook_safe("ProjectileFxExtension","init",function(fx,ctx,unit,data)
        attach_projectile(unit,data.owner_unit,data.projectile_template_name)
    end)
    mod:hook_safe("ProjectileFxExtension","destroy",function(fx)
        invoke(function()
            local id=C.projectiles[fx._unit];local a=id and C.attacks[id]
            if a then a.destroyed_at=C.clock; end
        end)
    end)
    -- Queued blasts from empowered melee and explosive hitscan firing keep
    -- their originating attack, including every affected target.
    mod:hook("WeaponSystem", "prepare_queued_explosion", function(func, system, ...)
        local index, data = func(system, ...)
        invoke(function()
            local id = scope
            if type(id)=="table" and id.category=="melee" then
                local action=id.action
                id=action_ids[action] or new_attack(action,"melee")
                action_ids[action]=id
                scope=id
            end
            local a=id and C.attacks[id]
            if a and (a.context.category=="melee" or a.hitscan_explosions) then
                special_queues[data]={id=id,index=index,system=system}
                a.queues=(a.queues or 0)+1
            end
        end)
        return index, data
    end)
    mod:hook("WeaponSystem", "_update_queued_explosions", function(func, system, ...)
        local previous=processing_explosions
        processing_explosions=system
        local result={func(system,...)}
        processing_explosions=previous
        invoke(function()
            for data,q in pairs(special_queues) do
                if q.system==system and system._queued_explosions[0]>q.index then
                    local a=C.attacks[q.id]
                    if a then a.queues=math.max(0,(a.queues or 1)-1) end
                    special_queues[data]=nil
                end
            end
        end)
        return unpack(result)
    end)
    local function special_explosion_id(target,profile,args)
        if not processing_explosions or args.attack_type~="explosion" or args.attacking_unit~=local_unit() then return end
        local pos=args.hit_world_position
        if not pos then return end
        local x,y,z=Vector3.to_elements(pos)
        local match
        for data,q in pairs(special_queues) do
            local t=data.explosion_template
            if q.system==processing_explosions and t and data.attacking_unit==local_unit()
                and data.source_position_x==x and data.source_position_y==y and data.source_position_z==z
                and (t.damage_profile==profile or t.close_damage_profile==profile)
                and (not C.attacks[q.id] or not C.attacks[q.id].hitscan_explosions or C.attacks[q.id].hitscan_explosions[profile.name]) then
                for i=data[0],data.num_hit_units do
                    if data[(i-1)*2+1]==target then
                        if match and match~=q.id then return end
                        match=q.id;break
                    end
                end
            end
        end
        return match
    end
    local function expect(target, profile, args)
        local projectile_id = C.projectiles[args.attacking_unit]
        local special_id = special_explosion_id(target,profile,args)
        local attack_id = special_id or projectile_id or scope
        if not attack_id then return end
        local category = args.attack_type
        local scoped=type(scope)=="number" and C.attacks[scope]
        local hitscan_id=scoped and scoped.hitscan_explosions and scoped.hitscan_explosions[profile.name] and scope
        if category ~= "melee" and category ~= "ranged" and not ((projectile_id or special_id or hitscan_id) and category=="explosion") then return end
        if not projectile_id and args.attacking_unit ~= local_unit() then return end
        local enemy, b = is_enemy(target)
        if not enemy then return end -- barrels/props/friendly fire never count
        if type(attack_id) == "table" then
            local action = scope.action
            local id = action_ids[action] or new_attack(action, scope.category)
            action_ids[action] = id
            if not id then return end
            scope = id
        end
        attack_id=special_id or projectile_id or scope
        local a = C.attacks[attack_id]
        if not a then return end
        local health = extension(target, "health_system")
        local cleave=profile.cleave_distribution and profile.cleave_distribution.attack
        local can_cleave=category=="melee" and (type(cleave)=="number" and cleave>0 or type(cleave)=="table" and ((cleave[2] or cleave[1] or 0)>0))
        local tags=b.tags or {}
        local entry = {id = attack_id, target = target, profile = profile.name,
            headshot = category~="explosion" and args.hit_zone_name == "head", category = category, cleave=can_cleave,
            armour = Armor.armor_type(target,b,args.hit_zone_name,category),
            boss_max = (b.is_boss or tags.monster or tags.captain) and health and health:max_health() or nil}
        C.expected[#C.expected + 1] = entry
        a.remaining = a.remaining + 1
        return entry
    end
    local DPS=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/dps_counter")
    local TestDamage=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage")
    Damage.bind_dps(DPS,TestDamage)
    local dps_report=Damage.dps_report
    local calculation_entry
    local function pack(...) return {n=select("#",...),...} end
    mod:hook(DamageCalculation,"calculate",function(func,...)
        local entry=calculation_entry
        if not entry or select(30,...)~=entry.target then return func(...) end
        local args=pack(...)
        local result=pack(func(...))
        invoke(function()
            entry.general_damage=result[1]
            entry.measurement=Measurements.calculate(args,result)
            local health=args[23] or extension(entry.target,"health_system")
            if health and type(health.max_health)=="function" and type(health.damage_taken)=="function" then
                local remaining=health:max_health()-health:damage_taken()
                if type(remaining)=="number" and remaining==remaining and remaining>0 and remaining<math.huge then entry.general_health=remaining end
            end
        end)
        return unpack(result,1,result.n)
    end)
    -- Explicit tick profiles from weapon/minion interval buffs; never infer
    -- DoT from all buff attacks (which also include direct ability impacts).
    local dot_profiles={bleeding="bleed",burning="burn",phosphor_burning="burn",warpfire="soulblaze",
        toxin_variant_1="toxin",toxin_variant_2="toxin",toxin_variant_3="toxin"}
    local dot_snapshot
    -- What of yours last set each enemy alight, as one burn takes stacks from every fire and its ticks do not say which lit it: the
    -- Flamer's own hits keep it the Flamer's while their burn lasts, until an Immolation Grenade, an explosion or an
    -- incendiary round of yours lights it after them.
    local FLAMER={default_flamer_assault=true,default_flamer_assault_burst=true}
    -- each damage profile's kind of fire, worked out once: this runs on every attack report
    local fire=setmetatable({},{__index=function(t,name)
        local v=FLAMER[name]and "flamer"or not dot_profiles[name]and (name=="fire_grenade_impact"or name:find("incendiary",1,true)or name:find("phosphor",1,true))and "other"or false
        t[name]=v;return v end})
    local lit=setmetatable({},{__mode="k"})
    -- the Flamer in hand stacks its burn on a target once an application interval, up to its own cap, as the game's flamer action does;
    -- what was last read stands when it cannot be read, and at first the fastest interval and the most stacks any Flamer has
    local flamer_cap,flamer_rate=20,0.25
    local function flamer_stats()
        local ok,t=pcall(function()local w=extension(local_unit(),"weapon_system");return w and w:burninating_template()end)
        if ok and type(t)=="table"then local n,r=tonumber(t.max_stacks),tonumber(t.stack_application_rate)
            if n and n>0 then flamer_cap=math.ceil(n)end;if r and r>0 then flamer_rate=r end end
    end
    -- the burn runs 4 s past the last stack, then sheds a stack each half second
    local function flamer_stacks(l)return l.flamer and math.max(0,l.stacks-math.max(0,math.floor((C.clock-l.flamer-4.5)/0.5)))or 0 end
    local function flamer_hit(l)local left=flamer_stacks(l)
        if l.stacked and C.clock-l.stacked<flamer_rate-1e-6 then l.stacks=left else flamer_stats();l.stacks=math.min(flamer_cap,left+1);l.stacked=C.clock end
    end
    local function by_flamer(target)local l=lit[target];return l~=nil and flamer_stacks(l)>0 and not (l.other and l.other>=l.flamer)end
    local function dot_report(profile,target,attacker,damage,result,attack_type)
        local name=profile and profile.name
        if name and target then local f=fire[name]or attack_type=="explosion"and "other"
            if f and attacker==local_unit()then local l=lit[target]or {};lit[target]=l;if f=="flamer"then flamer_hit(l)end;l[f]=C.clock end
        end
        local kind=profile and dot_profiles[profile.name]
        if not kind or attack_type~="buff" or attacker~=local_unit() or not api.enabled() then return end
        if type(damage)~="number" or damage<=0 then return true end
        local enemy,b=is_enemy(target)
        if target and not enemy then return true end
        local c=live_context(nil,"dot")
        if not c then return true end
        local snapshot=dot_snapshot
        if not snapshot or snapshot.target~=target or snapshot.profile~=profile.name then snapshot=nil end
        local armour=snapshot and snapshot.armour or b and Armor.armor_type(target,b,nil,"buff") or "unknown"
        -- A nonlethal damaged result proves the reported tick fit in health.
        -- Fatal remote ticks lack reliable pre-health; leave their split unknown.
        local health=snapshot and snapshot.general_health
        if not health and result=="damaged" then health=damage end
        api.tracker():run_damage_hit({category="dot"},{damage=damage,health_before=health,armour=armour,dot_type=kind,flamer=name=="burning"and by_flamer(target)or nil})

        return true
    end
    -- what an attack is to I/O: an execution, a damage-over-time tick of ours, or an ordinary hit it expects to see land
    local function attack_plan(target, profile, ...)
        local args = {}
        for i = 1, select("#", ...), 2 do local k, v = select(i, ...); args[k] = v end
        -- Execution attacks apply a kill, not another ordinary weapon impact.
        if args.instakill then return "instakill" end
        local kind=profile and dot_profiles[profile.name]
        local owner=args.attacking_unit_owner_unit or args.attacking_unit
        if kind and args.attack_type=="buff" and owner==local_unit() and is_enemy(target) then
            local _,b=is_enemy(target)
            return "dot",{target=target,profile=profile.name,armour=Armor.armor_type(target,b,args.hit_zone_name,"buff")}
        end
        return "hit",expect(target, profile, args)
    end
    mod:hook(Attack, "execute", function(func, target, profile, ...)
        local ok,kind,entry=contained("Attack.execute",pcall(attack_plan,target,profile,...))
        -- unplanned, nothing of this attack is credited to an attack around it
        if not ok then local previous=calculation_entry;calculation_entry=nil;local result=pack(func(target,profile,...));calculation_entry=previous;return unpack(result,1,result.n)end
        local previous,previous_dot=calculation_entry,dot_snapshot
        calculation_entry=entry;if kind=="dot"then dot_snapshot=entry end
        local result=pack(func(target,profile,...))
        calculation_entry=previous;if kind=="dot"then dot_snapshot=previous_dot end
        if kind=="hit"and entry then invoke(function()
            entry.predicted_damage, entry.predicted_result, entry.weakspot = result[1], result[2], result[5]
        end)end
        return unpack(result,1,result.n)
    end)

    local function match_report(profile,target,attacker,weakspot,damage,result,attack_type,measurement,distance_counted)
        -- Exact target/profile matching avoids crediting any unrelated explosion
        -- or DoT just because its owner happens to be the local player.
        local fallback
        if not target and result == "died" then
            -- The server can omit units transferred to the death manager.
            -- Accept only a unique compatible locally predicted killing hit;
            -- ambiguous reports remain censored, never guessed into a boss hit.
            local candidates = 0
            for i,e in ipairs(C.expected) do
                if e.profile == profile.name and e.category == attack_type and e.predicted_result == "died"
                    and e.weakspot == weakspot and type(e.predicted_damage) == "number"
                    and math.abs(e.predicted_damage - (damage or 0)) <= math.max(1, math.abs(e.predicted_damage)*0.001) then
                    candidates = candidates + 1; fallback = i
                end
            end
            if candidates ~= 1 then fallback = nil end
        end
        for i, e in ipairs(C.expected) do
            if (e.target == target or i == fallback) and e.profile == profile.name and e.category == attack_type then
                table.remove(C.expected, i)
                local a = C.attacks[e.id]
                if not a then return end
                a.remaining = a.remaining - 1
                a.last_report = C.clock

                C.last_melee_reports=C.last_melee_reports or setmetatable({},{__mode="k"}); if target then C.last_melee_reports[target]={profile=profile.name,damage=damage,clock=C.clock} end
                local reported_distance;local own=local_unit();if target and own and Unit.alive(target)and Unit.alive(own)then reported_distance=Vector3.distance(Unit.world_position(own,1),Unit.world_position(target,1))end
                Measurements.confirm(e.measurement,damage,result=="died",reported_distance,measurement and measurement.useful,a.measurement,weakspot,distance_counted)
                C.event_id = (C.event_id or 0) + 1
                api.tracker():hit(e.id, {is_explosion=e.category=="explosion",calculated_damage=e.general_damage,health_before=e.general_health,event_id = C.event_id, origin = "player_attack", damage = damage, target_id = tostring(e.target),
                    killed = result == "died", headshot = e.headshot, cleave=e.cleave, armour=e.armour,enemy=enemy_display(breed(e.target),e.target),
                    boss_id = e.boss_max and tostring(e.target) or nil, boss_max_health = e.boss_max})
                return a.context,e.armour,e.general_damage,e.general_health
            end
        end
        local candidates={}
        for id,a in pairs(C.attacks) do
            if a.projectile and not a.exact and not a.closed and a.profiles[profile.name] then candidates[#candidates+1]=id end
        end
        if #candidates>1 then
            for _,id in ipairs(candidates) do C.attacks[id].ambiguous=true end
            ;return
        end
        if #candidates==1 then
            local id=candidates[1];local a=C.attacks[id]
            local enemy,b=is_enemy(target)
            if not enemy then
                -- Missing dying target identity cannot safely exclude props.
                if not target then a.ambiguous=true end
                return
            end
            if a.ambiguous then return end
            local health=extension(target,"health_system");local tags=b.tags or {}
            C.event_id=(C.event_id or 0)+1;a.last_report=C.clock
            local blast=attack_type=="explosion" or a.explosion_profiles and a.explosion_profiles[profile.name]==true
            local armour=blast and Armor.armor_type(target,b,"center_mass","explosion") or "unknown"
            api.tracker():hit(id,{is_explosion=blast,event_id=C.event_id,origin="player_attack",target_id=tostring(target),damage=damage,
                armour=armour,enemy=enemy_display(b,target), killed=result=="died",headshot=attack_type~="explosion" and weakspot and not tags.monster and not tags.captain,
                boss_id=(b.is_boss or tags.monster or tags.captain) and tostring(target) or nil,
                boss_max_health=health and health:max_health() or nil})
            return a.context,armour
        end

    end
    local function drain_attacks()
            for id, a in pairs(C.attacks) do
                if a.projectile and a.destroyed_at and C.clock - math.max(a.destroyed_at,a.last_report or 0) >= 1 then
                    if a.ambiguous then
                        Measurements.close_attack(a.measurement,true);api.tracker():cancel(id);C.attacks[id]=nil
                        if a.unit then C.projectiles[a.unit]=nil end
                    else close_attack(id) end
                end
                if C.attacks[id] and a.closed and (a.queues or 0)==0 and a.remaining == 0 and C.clock - a.closed_at >= 0.1 then
                    Measurements.close_attack(a.measurement,false);api.tracker():resolve(id); C.attacks[id] = nil;
                    if a.unit then C.projectiles[a.unit]=nil end
                elseif C.attacks[id] and C.clock - a.start > (a.projectile and 30 or 8) then
                    Measurements.close_attack(a.measurement,true);api.tracker():cancel(id); C.attacks[id] = nil;
                    if a.unit then C.projectiles[a.unit]=nil end
                    for i = #C.expected, 1, -1 do if C.expected[i].id == id then table.remove(C.expected, i) end end
                end
            end
    end
    local function reset()
        special_queues={}
        action_ids=setmetatable({},{__mode="k"})
        scope=nil
    end
    return {dot_report=dot_report,dps_report=dps_report,pack=pack,drain_attacks=drain_attacks,match_report=match_report,reset=reset}
end
