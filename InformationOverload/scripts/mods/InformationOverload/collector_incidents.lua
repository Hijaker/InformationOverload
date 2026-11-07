return function(mod, api, C, initial)
    local local_unit,extension,field,breed=initial.local_unit,initial.extension,initial.field,initial.breed
    local enemy_display,human,member=initial.enemy_display,initial.human,initial.member
    local live_context,crystalline=initial.live_context,initial.crystalline
    local Timeline,timeline=initial.Timeline,initial.timeline
    local BossIdentity=initial.BossIdentity
    local PsykerEligibility,SocialNames=initial.PsykerEligibility,initial.SocialNames
    local Barrels,barrel_tracking,DepartureTracking,EnemyCatalog,Grouping
    local FieldImprovisation,Roster,ClutchTracking,hyper_register
    local last_dodge
    local control_states,pickup_done,pickup_helpers={},{},{}
    local recent_kicks,recent_explosions,control_transitions,incap_sources,psyker_detonation_times,incap_counted={},{},{},{},{},{}
    local state_events={knocked_down="knocked_down",pounced="dog_pounced",netted="trapper_netted",mutant_charged="mutant_charged",dead="died",hogtied="died"}
    -- Specialist kick actions share this melee profile. Restrict by breed,
    -- since gunners/captains also use the profile for unrelated melee attacks.
    local kick_specialists={renegade_sniper=true,renegade_grenadier=true,cultist_grenadier=true,
        renegade_flamer=true,cultist_flamer=true,renegade_flamer_mutator=true}
    local blast_profiles={barrel_explosion=true,barrel_explosion_close=true,fire_barrel_explosion=true,fire_barrel_explosion_close=true,
        poxwalker_explosion=true,poxwalker_explosion_close=true,poxwalker_explosion_mild=true,poxwalker_explosion_close_mild=true}
    local barrel_profiles={barrel_explosion=true,barrel_explosion_close=true,fire_barrel_explosion=true,fire_barrel_explosion_close=true,liquid_area_fire_burning_barrel=true}
    local environment_sources,fatal_hits={},{}
    -- damage the game sends with no one behind it: fire and gas an enemy left, gone or not, and the Spillway Prophet's warp lightning and Upheaval and a
    -- Trapper's net, named for the enemy they come from
    local unowned={grenadier_liquid_fire_burning="fire",renegade_flamer_liquid_fire_burning="fire",cultist_flamer_liquid_fire_burning="fire",liquid_area_fire_burning="fire",
        burning="fire",horde_flame_impact="fire",flamer_implosion="fire",cultist_grenadier_gas="gas",toxic_gas="gas",toxic_gas_mutator="gas",
        toxin_variant_3="renegade_wizard",renegade_wizard_z_catapult="renegade_wizard",netted_tick="renegade_netgunner"}
    local HAZARD={fire={enemy="fire",label="Fire"},gas={enemy="toxic_gas",label="Toxic Gas"}}
    local sample_cache={players=setmetatable({},{__mode="k"}),tick=0,next_refresh=0}
    local barrel_report

    local function confirmed_dodge(unit, dodge_type, attack_type)
        if attack_type ~= "melee" then return end
        if unit ~= local_unit() or dodge_type == "buff" or dodge_type == "sprint" then return end
        local c = live_context()
        if not c then return end
        local data = extension(unit, "unit_data_system")
        local movement = data and data:read_component("movement_state")
        local component = data and data:read_component("dodge_character_state")
        -- A successful dodge signal plus actual dodge movement excludes
        -- talent-based evasion and random button presses. One physical dodge
        -- can evade multiple attacks but only adds one to the streak.
        if not movement or not component then return end
        local token = field(component,"dodge_time")
        if token==nil or (not field(movement,"is_dodging") and dodge_type ~= "linger") then return end
        if token == last_dodge then return end
        last_dodge = token
        api.tracker():dodge(c); 
    end
    local function barrel_key(unit)
        local spawn=Managers.state and Managers.state.unit_spawner
        local id=spawn and spawn.level_index and spawn:level_index(unit)
        return id and tostring(id)or tostring(unit)
    end
    local function barrel_colour(e)
        if e._content=="explosion"then return "yellow"elseif e._content=="fire"or e._content=="gas"then return "red"end
    end
    local function barrel_actor(unit)
        local id,class,personal=member(unit);if id then return {id=id,class=class,personal=personal}end
    end
    barrel_report=function(target,attacker)
        local e=target and extension(target,"hazard_prop_system");if not e then return end
        local colour=barrel_colour(e);local m=api.tracker().mission
        if Barrels.hit(barrel_tracking,m,barrel_key(target),colour,barrel_actor(attacker),C.clock,e._current_state=="idle")then api.tracker().dirty=true;end
    end
    local function lethal_kick(unit)
        local id,class,personal=member(unit);local recent=id and recent_kicks[id]
        if not recent or recent.counted or recent.deadline<C.clock then return end
        recent.counted=true
        api.tracker():combat_incident("lethal_kicks",1,personal,not personal and id or nil,class,recent.specialist)
    end
    local function martyrdom_selected(unit)
        local player
        for _,candidate in pairs(Managers.player and Managers.player.players and Managers.player:players() or {}) do
            if candidate.player_unit==unit then player=candidate;break end
        end
        if not player then local spawn=Managers.state and Managers.state.player_unit_spawn;player=spawn and spawn.owner and spawn:owner(unit) end
        if not player or type(player.profile)~="function" then return false end
        local profile=player:profile();if not profile then return false end
        local selected=profile.talents and profile.talents.zealot_martyrdom
        local tier=type(selected)=="table" and selected.tier or selected
        return tier==true or type(tier)=="number" and tier>0
    end
    local function explosion_outcome(unit,state)
        local victim=member(unit);local source=victim and recent_explosions[victim]
        if not source or source.counted or source.deadline<C.clock then return end
        if source.self and (state=="knocked_down" or state=="dead" or state=="hogtied") then
            source.counted=true
            if source.defer_self_damage then
                local damage=0;for _,hit in ipairs(source.held or {}) do if C.clock-hit.at<=10 then damage=damage+hit.damage end end
                api.tracker():combat_incident("friendly_fire",damage,source.personal,not source.personal and source.id or nil,source.class)
                for _,hit in ipairs(source.held or {})do if C.clock-hit.at<=10 then api.tracker():friendly_fire_pair(source.id,victim,hit.damage,nil,hit.source)end end
            end
            api.tracker():combat_incident("suicides",1,source.personal,not source.personal and source.id or nil,source.class)
            api.tracker():friendly_fire_pair(source.id,victim,0,"suicide")
        elseif not source.self and (state=="dead" or state=="hogtied") then
            source.counted=true;api.tracker():combat_incident("murders",1,source.personal,not source.personal and source.id or nil,source.class);api.tracker():friendly_fire_pair(source.id,victim,0,"murder")
        end
    end
    local function enemy_incapacitation(unit,state)
        for _,p in pairs(Managers.player and Managers.player:players() or {})do if p.player_unit==unit and p.is_human_controlled and not p:is_human_controlled()then return end end
        local id,class,personal=member(unit);local source=id and incap_sources[id]
        if not id then return end
        local detonated=psyker_detonation_times[id]
        local perils=detonated and C.clock-detonated<=2
        if perils then source={enemy="perils_of_the_warp",label="Perils Of The Warp",group="environment",deadline=C.clock+10};incap_sources[id]=source end
        local sources={};if source and (source.counted or source.deadline>=C.clock) then source.counted=true;sources[#sources+1]={enemy=source.enemy,label=source.label,group=source.group,horde_type=source.horde_type,attack_type=source.attack_type,subgroup=source.subgroup,attack_inferred=source.attack_inferred} end
        local env=environment_sources[id];if env and (env.counted or env.deadline>=C.clock)then env.counted=true;sources[#sources+1]={enemy=env.enemy,label=env.label,group="environment"} end
        if #sources==0 then sources={{enemy="unknown_cause",label="Unknown cause",group="unknown"}} end
        local tm=Managers.time;local ok,at=pcall(function()return tm and (not tm.has_timer or tm:has_timer("gameplay"))and tm:time("gameplay")end)
        api.tracker():lethality_state(id,class,personal,state or "knocked_down",sources,perils,ok and type(at)=="number"and math.floor(at*1000+.5)or nil)
    end
    -- the game reports the hit that downs or kills a few frames after the down itself, so a cause that comes that soon names a down or death still
    -- unknown; a hit later than that lands on someone already down
    local function just_down(victim)
        local t,st=control_transitions[victim],control_states[victim]
        return t and C.clock-t.at<=.25 and t.previous~="dead" and (st=="knocked_down" or st=="dead")and st or nil
    end
    local function late_cause(victim,unit)
        local st=just_down(victim);if not st then return end
        local m=api.tracker().mission;local i=m and m.lethality_active and m.lethality_active[victim];local e=i and m.lethality_events and m.lethality_events[i]
        for _,s in ipairs(e and e.sources or {})do if s.enemy=="unknown_cause"then enemy_incapacitation(unit,st);return end end
    end
    local function combat_report(data)
        if not api.enabled() or type(data)~="table" then return end
        local target,attacker=data.attacked_unit,data.attacking_unit
        local victim=member(target)
        local m=api.tracker().mission;if not m then if not live_context() then return end;m=api.tracker().mission end
        if not m then return end
        local id,class,personal=member(attacker)
        if not victim then return end
        local amount=data.damage
        if type(amount)=="number"and amount>0 or data.attack_result=="toughness_absorbed"or data.attack_result=="knock_down"or data.attack_result=="died"then C.last_combat=C.clock end
        local b=breed(attacker);local profile=data.damage_profile
        local name=profile and profile.name or ""
        local fatal=data.attack_result=="knock_down" or data.attack_result=="died"
        local fall=name:find("fall",1,true) or name:find("kill_volume",1,true) or name=="default" and not id and fatal
        local landed=data.attack_result=="toughness_absorbed" or data.attack_result=="toughness_absorbed_melee" or data.attack_result=="toughness_broken"
        if b and b.breed_type=="minion" and (type(amount)=="number" and amount>0 or fatal or landed) then
            if fatal then fatal_hits[victim]=C.clock end
            local previous=incap_sources[victim]
            if not (previous and previous.counted) then
                local enemy,label=b.name,EnemyCatalog.name(b.name)
                if BossIdentity.captains[b.name] then enemy,label=BossIdentity.identify(attacker,b,extension) end
                if enemy then incap_sources[victim]={enemy=enemy,label=label and label~="Unknown enemy" and label or enemy_display(b,attacker),group=(b.is_boss or b.tags and (b.tags.monster or b.tags.captain)) and "boss" or b.tags and b.tags.elite and "elite" or b.tags and b.tags.special and "special" or "normal",horde_type=b.ranged and "ranged" or "melee",deadline=C.clock+10} else incap_sources[victim]=nil end
                local saved=incap_sources[victim]
                if saved then
                 local attack=data.attack_type
                 if saved.group~="boss"and saved.group~="elite"then saved.attack_type=(attack=="melee"or attack=="ranged")and attack or nil end
                 saved.subgroup=Grouping.classify(enemy,saved.group,b.ranged,saved.attack_type)
                 saved.attack_inferred=saved.group=="normal"and (enemy=="cultist_assault"or enemy=="renegade_assault"or enemy=="renegade_rifleman")and not saved.attack_type or nil
                end
            end
        elseif fatal and not fall and (id or name~="knocked_down_tick") then
            -- Only a hit that downs or kills replaces the last enemy, and a teammate's own hit is named as the cause; bleeding out, the down's own ticks
            -- that name no one, keeps the enemy who downed
            incap_sources[victim]=id and id~=victim and not blast_profiles[name] and not barrel_profiles[name] and {enemy="teammate",label="Teammate",group="environment",deadline=C.clock+10} or nil
        end
        if barrel_profiles[name] then environment_sources[victim]={enemy="barrels",label="Barrels",deadline=C.clock+10} end
        local from=not b and not id and unowned[name]
        -- the Prophet's lightning shares its damage with the flies of an Expedition
        if from and name=="toxin_variant_3"then local gm=Managers.state and Managers.state.game_mode;local ok,mode=pcall(function()return gm:game_mode_name()end);if ok and mode=="expedition"then from=nil end end
        -- fire or gas that downs, or lands as the down is seen, is the cause; a knock_down a buff survives leaves it only a moment
        if from and HAZARD[from] and (fatal or (landed or type(amount)=="number"and amount>0)and just_down(victim))then local h=HAZARD[from];environment_sources[victim]={enemy=h.enemy,label=h.label,deadline=C.clock+2}
        elseif from and not HAZARD[from] and (fatal or landed or type(amount)=="number"and amount>0) then local previous=incap_sources[victim]
            if not (previous and previous.counted) then local group=from=="renegade_wizard"and "boss"or "special"
                incap_sources[victim]={enemy=from,label=EnemyCatalog.name(from),group=group,subgroup=Grouping.classify(from,group,from=="renegade_netgunner",nil),deadline=C.clock+10} end
        end
        local transition=control_transitions[victim]
        if blast_profiles[name] and (fatal or data.attack_result=="toughness_absorbed"or type(amount)=="number"and amount>0)then DepartureTracking.hit(m,victim,C.clock,name:find("poxwalker",1,true)and "Poxburster"or "Barrel")end
        if name=="chaos_plague_ogryn_charge"or name=="chaos_plague_ogryn_catapult"then DepartureTracking.hit(m,victim,C.clock,"Plague Ogryn")end
        local real_fall=tostring(data.damage_type or "")=="instakill"or name:find("damage_volume_instakill",1,true)or name:find("kill_volume",1,true)or name:find("fall",1,true) or tostring(data.damage_type or ""):find("fall",1,true) or name=="default" and fatal and (control_states[victim]=="falling"or control_states[victim]=="catapulted"or transition and (transition.previous=="falling"or transition.previous=="catapulted"))
        if real_fall and data.attack_result=="died"then DepartureTracking.fall_death(m,victim,C.clock)end
        if real_fall and not b and not (environment_sources[victim] and environment_sources[victim].deadline>=C.clock) then environment_sources[victim]={enemy="falls",label="Falls",deadline=C.clock+10} end
        if name:find("poxwalker_explosion",1,true)and not (incap_sources[victim]and incap_sources[victim].counted)then incap_sources[victim]={enemy="chaos_poxwalker_bomber",label="Poxburster",group="special",deadline=C.clock+10} end
        if fatal or b and b.breed_type=="minion" or from then late_cause(victim,target) end
        -- knock_down also comes for a hit a resist-death buff survives, so a down is saved from its state.
        if data.attack_result=="died" then enemy_incapacitation(target,"dead") end
        local self_barrel=id and id==victim and barrel_profiles[name]
        local defer_self_damage=self_barrel and class=="zealot" and martyrdom_selected(attacker)
        if id and type(amount)=="number" and amount>0 and (id~=victim or self_barrel and not defer_self_damage) then
            local source_kind=name=="liquid_area_fire_burning_barrel"and "barrel_fire"or barrel_profiles[name]and "barrel_explosion"or "other"
            api.tracker():combat_incident("friendly_fire",amount,personal,not personal and id or nil,class);api.tracker():friendly_fire_pair(id,victim,amount,nil,source_kind)
        end
        if id and (blast_profiles[name] or name=="liquid_area_fire_burning_barrel") and (id~=victim or self_barrel) then
            local existing=recent_explosions[victim]
            local incapacitated=control_states[victim]=="knocked_down" or control_states[victim]=="dead" or control_states[victim]=="hogtied"
            if not (existing and existing.counted and incapacitated) then
                local held={}
                if defer_self_damage then
                    for _,hit in ipairs(existing and existing.id==id and existing.held or {}) do if C.clock-hit.at<=10 then held[#held+1]=hit end end
                    if type(amount)=="number" and amount>0 then held[#held+1]={at=C.clock,damage=amount,source=name=="liquid_area_fire_burning_barrel"and "barrel_fire"or "barrel_explosion"} end
                end
                recent_explosions[victim]={id=id,class=class,personal=personal,self=id==victim,defer_self_damage=defer_self_damage,deadline=C.clock+10,held=held}
            end
        end
        if data.attack_result=="died" then explosion_outcome(target,"dead") end
        local kick=b and kick_specialists[b.name] and profile and profile.name=="chaos_ogryn_gunner_melee" and data.attack_type=="melee"
        if kick then
            -- A kick against an already incapacitated victim isn't a new down.
            local state=control_states[victim]
            local transition=control_transitions[victim]
            local old=transition and transition.previous
            local fresh_fatal=fatal and transition and C.clock-transition.at<0.5 and old~="knocked_down" and old~="dead" and old~="hogtied"
            if (state~="knocked_down" and state~="dead" and state~="hogtied" or fresh_fatal) and not (recent_kicks[victim] and recent_kicks[victim].counted and (state=="knocked_down" or state=="dead" or state=="hogtied")) then
                recent_kicks[victim]={specialist=b.name,deadline=C.clock+3}
                if data.attack_result=="died" then lethal_kick(target) end
            end
        elseif type(amount)=="number" and amount>0 and not fall then
            -- Damage from a different source breaks the estimated causal link.
            recent_kicks[victim]=nil
        end
    end
    local function helper(target,actor)
        local key=member(target);if not key or not actor then return end
        local existing=pickup_helpers[key]
        if existing and existing.deadline>C.clock and existing.actor~=actor then pickup_helpers[key]={ambiguous=true,deadline=C.clock+4};return end
        pickup_helpers[key]={actor=actor,deadline=C.clock+4}
    end
    local function pickup(target,actor)
        local m=api.tracker().mission;if not m then return end
        local key=member(target);if not key then return end
        local pending=pickup_helpers[key];local pickup_state=control_states[key];if pickup_state~="knocked_down"and pickup_state~="hogtied"then pickup_state=nil end;actor=actor or (pending and pending.deadline>=C.clock and not pending.ambiguous and pending.actor)
        if actor then local owner=Managers.state and Managers.state.player_unit_spawn;owner=owner and owner.owner and owner:owner(actor)
         if not owner then for _,p in pairs(Managers.player:players()or {})do if p.player_unit==actor then owner=p;break end end end
         if owner and not human(owner)then
          m.clutch_bot_recovered=m.clutch_bot_recovered or {};m.clutch_bot_recovered[key]=true
          local done=pickup_done[key];if not done then api.tracker():incident("pickup",false,nil);done={from_state=pickup_state};pickup_done[key]=done end
          if not done.credited then api.tracker():credit_bot_pickup();done.credited=true;api.tracker():lethality_recovered(key)end
          if not done.bot_observed then done.bot_observed=true;if DepartureTracking.observe_bot_pickup(m,tostring(actor))then done.bot_credited=true end;api.tracker().dirty=true end
          api.save()
          return
         end
        end
        local id,class,personal=member(actor)
        if actor and not id then return end
        if actor and id then api.tracker():lethality_recovered(key) end
        local done=pickup_done[key]
        if not done then api.tracker():incident("pickup",false,nil);done={from_state=pickup_state};pickup_done[key]=done end
        if actor and id and not done.credited then api.tracker():credit_pickup(personal,not personal and id or nil,class);api.tracker():pickup_pair(id,key,pickup_state or done.from_state);done.credited=true end
        api.save()
    end
    local function observe_control(unit,state,from_hook)
        if not unit or not api.enabled() then return end
        local m=api.tracker().mission;if not m then if not live_context() then return end;m=api.tracker().mission end
        if not m then return end
        local id,class,personal=member(unit);if not id then return end;local previous=control_states[id]
        if previous==state then return end
        if state=="catapulted"then
         local source=incap_sources[id];local cause=previous=="mutant_charged"and "Mutant"or previous=="grabbed"and "Chaos Spawn"or source and source.enemy=="chaos_spawn"and "Chaos Spawn"
         if cause then DepartureTracking.hit(m,id,C.clock,cause)end
        end
        control_states[id]=state;control_transitions[id]={previous=previous,at=C.clock}
        if (previous=="knocked_down" or previous=="dead" or previous=="hogtied" or previous==nil and m.lethality_active and m.lethality_active[id]) and ({walking=true,jumping=true,dodging=true,sliding=true,sprinting=true,idle=true})[state] then recent_explosions[id]=nil;incap_sources[id]=nil;incap_counted[id]=nil;environment_sources[id]=nil;api.tracker():lethality_recovered(id) end
        if state=="knocked_down"or state=="hogtied"then pickup_done[id]=nil;pickup_helpers[id]=nil;if m.clutch_bot_recovered then m.clutch_bot_recovered[id]=nil end end
        local event=state_events[state]
        -- A player first found already down or dead, on a late join or rejoin, was not seen going down.
        local seen=previous~=nil or m.full or from_hook
        explosion_outcome(unit,state)
        -- Dying straight out of a fall is a kill volume, which sends no attack report, unless an enemy's hit just killed.
        if state=="dead" and (previous=="falling" or previous=="ledge_hanging_falling" or previous=="catapulted") and not (fatal_hits[id] and C.clock-fatal_hits[id]<=1) then
            if not (environment_sources[id] and environment_sources[id].deadline>=C.clock) then environment_sources[id]={enemy="falls",label="Falls",deadline=C.clock+10} end
            DepartureTracking.fall_death(m,id,C.clock)
        end
        -- the game enters hogtied only on a respawn, after the death's cause was saved
        if (state=="knocked_down" or state=="dead") and seen then enemy_incapacitation(unit,state) end
        if (state=="knocked_down" or state=="dead" or state=="hogtied") and previous~="knocked_down" and previous~="dead" and previous~="hogtied" then lethal_kick(unit) end
        if event and event~=state_events[previous] and seen then
            if personal and event~="died" then api.tracker():survival_event(event) end
            if personal and (event=="knocked_down" or event=="died") then local data,t=timeline();if data then Timeline.reset(data,t,event)end;api.tracker():reset_kill_run(m.context) end
            api.tracker():incident(event,personal,not personal and id or nil,class)
            if personal then local record=api.tracker():mode_streak(m.context.patch,m.context.mode);local scoped=api.tracker():class_mode_streak(m.context.patch,m.context.mode,m.context.class);for name,d in pairs(api.tracker().mode_streak_fields) do if d.event==event then record.current[name]=0;scoped.current[name]=0 end end end
            api.save()
        end
        if (previous=="knocked_down" or previous=="hogtied") and ({walking=true,jumping=true,falling=true,dodging=true,sliding=true,sprinting=true,idle=true})[state] then pickup(unit) end
    end
    local function refresh_controls()
        local clutch_states,clutch_owner={},nil
        local departure_people,departure_bots={},{}
        local psyker_present=false
        local mission=api.tracker().mission
        if mission then mission.team_psykers=mission.team_psykers or {};mission.team_psykers.members=mission.team_psykers.members or {} end
        for _,player in pairs(Managers.player and Managers.player.players and Managers.player:players() or {}) do
            local unit=player.player_unit;local data=extension(unit,"unit_data_system")
            local profile=type(player.profile)=="function" and player:profile();local archetype=profile and profile.archetype
            local class=type(archetype)=="table" and archetype.name or archetype
            if class=="broker"and human(player)then hyper_register(unit,profile)end
            if class=="psyker" and PsykerEligibility.crystalline(profile) then
                local id=member(unit);if mission and id then mission.team_psykers.members[id]=nil;local det=false;for _,n in pairs(mission.team_psykers.members) do if n>0 then det=true end end;mission.team_psykers.detonated=det;if unit==local_unit() then mission.context.crystalline_will=true end end
            end
            if class=="psyker" and human(player) and not PsykerEligibility.crystalline(profile) then
                psyker_present=true;local id=member(unit);local m=api.tracker().mission
                if id and m then m.team_psykers=m.team_psykers or {};m.team_psykers.members=m.team_psykers.members or {};m.team_psykers.members[id]=m.team_psykers.members[id] or 0 end
            end
            local state=data and data:read_component("character_state")
            if human(player)then local person=unit and member(unit)or type(player.character_id)=="function"and player:character_id();if person then person=tostring(person)end;if person then clutch_states[person]=state and field(state,"state_name")or "unknown";if unit==local_unit()then clutch_owner=person end end end
            if human(player)then
             local person=unit and member(unit)or type(player.character_id)=="function"and player:character_id()
             if person then
              local key=tostring(person);if type(player.account_id)=="function"then local value=player:account_id();if value then key=tostring(value)end end
              local steam_id,steam_name=SocialNames.steam_identity(player)
              departure_people[key]={steam_id=steam_id,steam_name=steam_name,key=key,id=tostring(person),name=profile and profile.name or "Operative",class=class,personal=unit~=nil and unit==local_unit(),state=state and field(state,"state_name")or "unknown"}
             end
            elseif unit then departure_bots[tostring(unit)]=true end
            if unit and state then observe_control(unit,field(state,"state_name"),false) end
        end
        Roster.sample(api.tracker(),Managers.player and Managers.player:players(),local_unit(),SocialNames)
        if DepartureTracking.restore_self(api.tracker(),departure_people)then api.save(true)end
        DepartureTracking.sample(api.tracker().mission,departure_people,departure_bots,C.clock)
        ClutchTracking.sample(api.tracker().mission,clutch_states,clutch_owner)
        local active=api.tracker().mission
        if active then active.operative_clutches=active.operative_clutches or {}
         for key,p in pairs(departure_people)do if p.steam_id then
          local row=active.operative_clutches[key]or {clutches={episodes=0,seen=false}};active.operative_clutches[key]=row
          row.character_id=p.id;row.steam_id=p.steam_id;row.steam_name=p.steam_name;row.class=p.class;row.personal=p.personal;row.name=p.name
          if p.personal then row.clutches=active.clutches else local sample={context=active.context,clutches=row.clutches,clutch_bot_recovered=active.clutch_bot_recovered};ClutchTracking.sample(sample,clutch_states,p.id);row.clutches=sample.clutches end
         end end
        end
        api.tracker():observe_team_psykers(psyker_present)
        FieldImprovisation.sample(mod,api.tracker(),Managers.player and Managers.player.players and Managers.player:players(),C.clock)
    end
    local function sample_controls()
        local m=api.tracker().mission;local changed=m~=sample_cache.mission
        sample_cache.tick=sample_cache.tick+1;local tick=sample_cache.tick
        local players=Managers.player and Managers.player.players and Managers.player:players()or {}
        for _,player in pairs(players)do
            local unit=player.player_unit;local data=extension(unit,"unit_data_system");local state=data and data:read_component("character_state");local name=state and field(state,"state_name")
            local old=sample_cache.players[player]
            if not old or old.unit~=unit or old.state~=name then
                changed=true
                old=old or {};sample_cache.players[player]=old;old.unit=unit;old.state=name
                if unit and state then observe_control(unit,name,false)end
            end
            old.seen=tick
        end
        for player,old in pairs(sample_cache.players)do if old.seen~=tick then sample_cache.players[player]=nil;changed=true end end
        if changed or C.clock>=sample_cache.next_refresh then
            sample_cache.mission=m;sample_cache.next_refresh=C.clock+1;refresh_controls()
        elseif m then m.last_observed_clock=C.clock end
    end
    local function survival(unit,event)
        if event~="peril_detonated" or not api.enabled() then return end
        if not api.tracker().mission and not live_context() then return end
        if crystalline(unit) then return end
        local id,class,personal=member(unit)
        if id and (class=="psyker" or personal and api.tracker().mission and api.tracker().mission.context.class=="psyker") then
            if not psyker_detonation_times[id] or C.clock-psyker_detonation_times[id]>1 then
                psyker_detonation_times[id]=C.clock;api.tracker():team_psyker_detonation(personal,id);api.save()
                -- The down this explosion caused can arrive first.
                local state,change=control_states[id],control_transitions[id]
                if (state=="knocked_down" or state=="dead" or state=="hogtied") and change and C.clock-change.at<=2 then enemy_incapacitation(unit,state) end
            end
        end
    end

    local function bind_barrels(barrels,tracking)
        Barrels,barrel_tracking=barrels,tracking
    end
    local function bind_combat(deps)
        DepartureTracking=deps.DepartureTracking
        EnemyCatalog=deps.EnemyCatalog
        Grouping=deps.Grouping
    end
    local function bind_controls(deps)
        FieldImprovisation=deps.FieldImprovisation
        Roster=deps.Roster
        ClutchTracking=deps.ClutchTracking
        hyper_register=deps.hyper_register
    end
    local function control_state_table()
        return control_states
    end
    local function reset_dodge()
        last_dodge=nil
    end
    local function reset_transients()
        environment_sources,fatal_hits={},{}
        control_states,pickup_done,pickup_helpers={},{},{};recent_kicks,recent_explosions,control_transitions,incap_sources,psyker_detonation_times,incap_counted={},{},{},{},{},{}
        return control_states
    end
    local function reset_sampling()
        sample_cache.mission=nil;sample_cache.next_refresh=0;sample_cache.players=setmetatable({},{__mode="k"})
    end
    return {
        confirmed_dodge=confirmed_dodge,
        barrel_key=barrel_key,
        barrel_colour=barrel_colour,
        barrel_actor=barrel_actor,
        barrel_report=barrel_report,
        lethal_kick=lethal_kick,
        martyrdom_selected=martyrdom_selected,
        explosion_outcome=explosion_outcome,
        enemy_incapacitation=enemy_incapacitation,
        combat_report=combat_report,
        helper=helper,
        pickup=pickup,
        observe_control=observe_control,
        refresh_controls=refresh_controls,
        sample_controls=sample_controls,
        survival=survival,
        bind_barrels=bind_barrels,
        bind_combat=bind_combat,
        bind_controls=bind_controls,
        control_state_table=control_state_table,
        reset_dodge=reset_dodge,
        reset_transients=reset_transients,
        reset_sampling=reset_sampling,
    }
end
