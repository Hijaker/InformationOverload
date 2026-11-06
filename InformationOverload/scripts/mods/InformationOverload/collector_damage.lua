-- Damage adapters share one collector's live state and original dependency order.
return function(mod,api,C,Timeline,mission_time)
    local DPS,TestDamage
    local Compact,Party,PartyWeapon,local_unit,breed,Armor,member,Grouping,last_enemy_attack
    local BossIdentity,extension,EnemyCatalog,Context,Measurements,Loadouts,WeaponTemplate,invoke,is_enemy,enemy_display
    local party_kill,collect_team_damage
    local function timeline(heartbeat)
        local m=api.tracker().mission
        if not m or not api.enabled()or m.context and m.context.excluded then return end
        local t=mission_time();if not t then return end
        m.combat_timeline=m.combat_timeline or Timeline.new(t,m.timing_origin)
        if heartbeat then Timeline.heartbeat(m.combat_timeline,t,m.timing_origin)else Timeline.touch(m.combat_timeline,t,m.timing_origin)end
        return m.combat_timeline,t
    end
    mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/kill_streaks").install(
        mod,api,C,Timeline,timeline,function()return local_unit()end)
    local dps_mission,dps_state
    local function ensure_dps()
        local m=api.tracker().mission;if not m then return end
        if dps_mission~=m then dps_mission=m;dps_state=m.psyk_dps or DPS.new();if m.context.difficulty=="psykhanium"then m.psyk_dps=dps_state end end
        return m
    end
    local function dps_report(profile,target,attacker,damage,result,kind,measurement)
        local m=ensure_dps();if not m or attacker~=local_unit()or m.context.difficulty~="psykhanium"then return end
        local b=target and breed(target);local armour=target and Armor.armor_type(target,b,nil,kind)or "unknown"
        if armour~="void_shield"then DPS.hit(dps_state,C.clock,damage,measurement and measurement.useful,TestDamage.category({profile=profile and profile.name,category=kind}))end
    end
    function C:dps_snapshot()return dps_state end
    local party_mission,party_state;local weapon_info=setmetatable({},{__mode="k"})
    local function party(m)
     if party_mission~=m then party_mission=m;party_state=Party.new(m.party_records,m.enemy_kill_counts);weapon_info=setmetatable({},{__mode="k"})end
     for id,p in pairs(m.context.operative_roster or {})do Party.register(party_state,tostring(id),p.class,p.personal)end
     return party_state
    end
    local function party_weapon(m,unit,id)
     local info=unit and weapon_info[unit];if info then return info end
     local spawner=Managers.state and Managers.state.player_unit_spawn;local player=unit and spawner and spawner.owner and spawner:owner(unit)
     if not player then for _,p in pairs(Managers.player and Managers.player.players and Managers.player:players()or {})do if p.player_unit==unit then player=p;break end end end
     local profile=player and player.profile and player:profile();if not profile then return {}end
     local loadout=profile.loadout or {};local snapshot=(m.context.operative_loadouts or {})[id]or Loadouts.weapon_names(profile)
     info={melee=snapshot.melee,ranged=snapshot.ranged,melee_template=WeaponTemplate.weapon_template_from_item(loadout.slot_primary),ranged_template=WeaponTemplate.weapon_template_from_item(loadout.slot_secondary)}
     if unit then weapon_info[unit]=info end;return info
    end
    party_kill=function(target,attacker)
     local m=api.tracker().mission;if not m or not target then return end
     local enemy,b=is_enemy(target);if not enemy then return end;local id,class,personal=member(attacker);if not id then return end
     local tags=b and b.tags or {};local kind=(b and b.is_boss or tags.monster or tags.captain)and "boss"or tags.special and "special"or tags.elite and "elite"or b and (Grouping.trash_ranged(b.name,b.ranged,last_enemy_attack[target])and "horde_ranged"or "horde_melee")
     local group=kind=="horde_ranged"or kind=="horde_melee";group=group and "normal"or kind
     local kill_id,kill_label=b.name,EnemyCatalog.name(b.name)
     if group=="boss"then local resolved,label=BossIdentity.identify(target,b,extension);kill_id=resolved or kill_id;kill_label=label or kill_label end
     if Party.kill(party(m),{actor=id,class=class,personal=personal,target=target,kind=kind,fixed_kind=group=="normal"and (b.ranged and "trash_fixed_ranged"or "trash_fixed_melee")or group=="elite"and (b.ranged and "elite_ranged"or "elite_melee")or nil,enemy=kill_id,label=kill_label,group=group,subgroup=Grouping.classify(kill_id,group,b.ranged,last_enemy_attack[target])})then api.tracker().dirty=true end
    end
    local damage_mission,damage_state
    local function party_hit(m,id,class,personal,target,attacker,profile,damage,attack_type,category,armour,enemy_name,result)
     if result=="died"then party_kill(target,attacker)end
     local state=party(m);local info=party_weapon(m,attacker,id)or {};local component=attacker and extension(attacker,"unit_data_system");component=component and component.read_component and component.read_component(component,"weapon_action")
     local current=component and WeaponTemplate.current_weapon_template(component)
     local group=PartyWeapon.group(info,profile,attack_type,component,current)
     Party.hit(state,{actor=id,class=class,personal=personal,target=target,damage=damage,category=category,armour=armour,enemy=enemy_name,weapon=PartyWeapon.attribute(info,profile,attack_type),group=group,clock=C.clock})
    end
    local spawn_health=setmetatable({},{__mode="k"})
    collect_team_damage=function(profile,target,attacker,weakspot,damage,result,attack_type,_,critical)
        local m=api.tracker().mission;if not m then return end
        local enemy,b=is_enemy(target);if not enemy and target then return end
        if type(damage)~="number"or damage~=damage or damage<=0 or damage>=math.huge then return end
        C.last_combat=C.clock
        if damage_mission~=m then damage_mission=m;damage_state=Compact.new(m.team_damage); end
        local spawn=target and spawn_health[target]
        if spawn and spawn.mission==(Managers.state and Managers.state.mission)then Compact.seed(damage_state,target,spawn.hp,spawn.maximum);spawn_health[target]=nil end
        local id,class,personal=member(attacker);local account
        local identity_info=attacker and Context.cached_identity(attacker)
        if identity_info and identity_info.mission==m then account=identity_info.account end
        local health=target and extension(target,"health_system")
        local maximum=health and health.max_health and health.max_health(health)
        local hp=health and health.current_health and health.current_health(health)
        local armour=target and Armor.armor_type(target,b,nil,attack_type)or "unknown"
        local name=profile and profile.name or "unknown"
        local category=({bleeding="Bleed",burning="Burn",phosphor_burning="Burn",warpfire="Soulblaze",toxin_variant_1="Toxin",toxin_variant_2="Toxin",toxin_variant_3="Toxin"})[name]or attack_type or "unknown"
        local shield=armour=="void_shield"and target and extension(target,"toughness_system");local shield_maximum=shield and shield.max_toughness and shield.max_toughness(shield);local shield_damage=shield and shield.toughness_damage and shield.toughness_damage(shield);local shield_hp=type(shield_maximum)=="number"and type(shield_damage)=="number"and math.max(0,shield_maximum-shield_damage)or nil
        local enemy_name=b and enemy_display(b,target)or "Unknown Enemy"
        if id then party_hit(m,id,class,personal,target,attacker,profile,damage,attack_type,category,armour,enemy_name,result)end
        return Compact.hit(damage_state,{shield_hp=shield_hp,shield_maximum=shield_maximum,target=target,actor=id,class=class,personal=personal,boss=b and (b.is_boss or b.tags and (b.tags.monster or b.tags.captain))or false,account=account,profile=name,enemy=enemy_name,armour=armour,category=category,damage=damage,result=result,maximum=maximum,hp=hp,weakspot=enemy and weakspot==true,critical=enemy and critical==true})
    end
    function C:damage_snapshot(m)
        if m and m==damage_mission and damage_state then return Compact.results(damage_state)end
        return m and m.team_damage
    end
    -- the live squad tables themselves, uncopied, for the scoreboard to read
    function C:live_squad(m)
        if not m then return end
        return damage_mission==m and damage_state and damage_state.data or m.team_damage,party_mission==m and party_state and party_state.data or m.party_records
    end
    local function finish_compact(m)
        Measurements.finish(m)
        if m and party_mission==m and party_state then m.party_records,m.enemy_kill_counts=Party.export(party_state);party_state=nil;party_mission=nil;weapon_info=setmetatable({},{__mode="k"})end
        if m and m==damage_mission and damage_state then m.team_damage=Compact.results(damage_state);damage_state=nil;damage_mission=nil end
    end
    local function update_dps()if ensure_dps()then DPS.update(dps_state,C.clock)end end
    local function install_health_hooks(watch_prophet)
    mod:hook_safe("HuskHealthExtension","init",function(health,ctx,unit)
        watch_prophet(health,ctx,unit)
        invoke(function()
            local hp=health.current_health and health:current_health();local maximum=health.max_health and health:max_health()
            if type(hp)=="number"and type(maximum)=="number"and maximum>0 then spawn_health[unit]={hp=hp,maximum=maximum,mission=Managers.state and Managers.state.mission}end
        end)
    end)
    mod:hook_safe("HealthExtension","init",function(health,ctx,unit,data)
        watch_prophet(health,ctx,unit)
        invoke(function()local hp=data and data.health;if unit and type(hp)=="number"and hp>0 then spawn_health[unit]={hp=hp,maximum=hp,mission=Managers.state and Managers.state.mission}end end)
    end)
    end
    local function checkpoint_party()
        local active=api.tracker().mission;if active and party_mission==active and party_state then active.party_records,active.enemy_kill_counts=Party.checkpoint(party_state)end
    end
    local function checkpoint_damage(m)
        if m and m==damage_mission and damage_state and C.clock>=(damage_state.next_checkpoint or 0)then m.team_damage=damage_state.data;damage_state.next_checkpoint=C.clock+15 end
    end
    local function refresh_squad(m)
        if not m and (party_mission or damage_mission)then finish_compact(party_mission or damage_mission)end
        if m and party_mission~=m then party(m)end
    end
    local function bind_dps(counter,damage)
        DPS,TestDamage=counter,damage
    end
    local function bind_squad(D)
        Compact,Party,PartyWeapon=D.Compact,D.Party,D.PartyWeapon
        local_unit,breed,Armor,member,is_enemy,enemy_display=D.local_unit,D.breed,D.Armor,D.member,D.is_enemy,D.enemy_display
        Grouping,last_enemy_attack,BossIdentity=D.Grouping,D.last_enemy_attack,D.BossIdentity
        extension,EnemyCatalog,Context,Measurements=D.extension,D.EnemyCatalog,D.Context,D.Experimental
        Loadouts,WeaponTemplate,invoke=D.Loadouts,D.WeaponTemplate,D.invoke
    end
    return {timeline=timeline,dps_report=dps_report,party_kill=party_kill,
        collect_team_damage=collect_team_damage,finish_compact=finish_compact,
        update_dps=update_dps,install_health_hooks=install_health_hooks,
        checkpoint_party=checkpoint_party,checkpoint_damage=checkpoint_damage,
        refresh_squad=refresh_squad,bind_dps=bind_dps,bind_squad=bind_squad}
end
