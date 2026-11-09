-- Read-only game adapter. Confirmed reports are matched to locally observed
-- direct attacks by target/profile, in firing order. Unconfirmed hits censor
-- streaks instead of inventing damage. Projectile and melee-special explosions retain their launch/swing identity.
return function(mod, api)
    local Mission
    local function mission_time(...)return Mission.mission_time(...)end
    local function marker(...)return Mission.marker(...)end
    local Faction=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/havoc_faction")
    local Loadouts=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/operative_loadout")
    local Armor = require("scripts/utilities/attack/armor")
    local Attack = require("scripts/utilities/attack/attack")
    local DamageCalculation = require("scripts/utilities/attack/damage_calculation")
    local Dodge = require("scripts/extension_systems/character_state_machine/character_states/utilities/dodge")
    local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
    local SocialNames=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/social_names")
    local C = {projectiles = {}, attacks = {}, expected = {}, clock = 0}
    -- I/O's own work inside a hook runs contained, so a fault in it is told once and never stops the game's call or the frame.
    local trace=mod.io_slow_trace
    local failed={}
    local function contained(tag,ok,...)
        if not ok and not failed[tag] then failed[tag]=true;mod:error("I/O collector %s: %s",tag,tostring((...))) end
        return ok,...
    end
    local function invoke(fn, ...)
        local began=trace and trace.start()
        local ok,err=pcall(fn,...)
        if trace then trace.finish(fn,began)end
        if not ok then local info=debug and debug.getinfo and debug.getinfo(fn,"S")
            contained("callback at "..tostring(info and info.source and info.source:match("[^/]+$"))..":"..tostring(info and info.linedefined),false,err)end
    end
    C.pending_debug=api.debug()
    local circumstance_name
    mod:hook_safe("MutatorManager","init",function(_,is_server,world,nav_world,network_event_delegate,name) circumstance_name=name end)
    mod:hook_safe("CinematicSceneSystem","init",function(system)Mission:scene_init(system)end)
    mod:hook("CinematicManager","update",function(func,manager,dt,t)
        invoke(function()
            local story=manager._active_story
            Mission:cinematic_update(manager,story)
        end)
        return func(manager,dt,t)
    end)
    local Timeline=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/combat_timeline")
    local Damage=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_damage")(mod,api,C,Timeline,mission_time)
    local timeline=Damage.timeline
    local down_seen = setmetatable({}, {__mode = "k"})

    -- Watched presence entries can publish a profile at the title screen,
    -- before UIManager's callback has a local player to dereference.
    mod:hook("UIManager", "event_player_profile_updated", function(func, ui, ...)
        local manager = Managers.player
        local player = manager and manager.local_player_safe and manager:local_player_safe(1)
        if not player then return end
        return func(ui, ...)
    end)


    local RunResume=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/run_resume")
    local PsykerEligibility=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/psyker_eligibility")
    local function crystalline(unit)
        for _,p in pairs(Managers.player and Managers.player.players and Managers.player:players() or {}) do if p.player_unit==unit then return PsykerEligibility.crystalline(type(p.profile)=="function" and p:profile()) end end
        return false
    end
    local HyperCritical=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/hyper_critical")
    local Haymaker=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/haymaker")
    local ClassEvents
    local haymaker_report
    local hyper_report
    local BossIdentity=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/boss_identity")
    local live_context
    local Context=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_context")(
        mod,api,C,WeaponTemplate,Loadouts,SocialNames,BossIdentity,crystalline,invoke,
        function(...)return live_context(...)end)
    local local_unit,extension,field,breed=Context.local_unit,Context.extension,Context.field,Context.breed
    local enemy_display,is_enemy,human=Context.enemy_display,Context.is_enemy,Context.human
    local identity,member,peril_players=Context.identity,Context.member,Context.peril_players
    live_context=function(action, category, template)
        local c=Context.observe_context(action,category,template)
        if not c then return end
        Mission:observe_context(c)
        local m=api.tracker().mission
        if m then
            if c.private_game==true then m.context.private_game=true elseif m.context.private_game==nil then m.context.private_game=c.private_game end
            m.context.mission_instance=m.context.mission_instance or c.mission_instance
            m.context.mission_name=m.context.mission_name or c.mission_name
            m.context.mission_display_name=m.context.mission_display_name or c.mission_display_name
            invoke(function()
                if C.clock<(m.next_modifier_sample or 0) then return end
                m.next_modifier_sample=C.clock+2
                local circumstances=require("scripts/settings/circumstance/circumstance_templates")
                local chosen={}
                if circumstance_name then chosen[#chosen+1]=circumstance_name;m.context.circumstance=circumstance_name end
                local difficulty=Managers.state.difficulty
                local havoc=difficulty and difficulty.get_parsed_havoc_data and difficulty:get_parsed_havoc_data()
                Faction.capture(m.context,havoc)
                for _,id in ipairs(havoc and havoc.circumstances or {}) do chosen[#chosen+1]=id end
                do
                    m.context.modifiers=m.context.modifiers or {}
                    for _,id in ipairs(chosen) do
                        local template=circumstances[id];local ui=template and template.ui;local key=template and (template.display_name or ui and ui.display_name)
                        if ui and tostring(ui.icon or ""):find("maelstrom",1,true) then m.context.maelstrom=true end
                        if type(key)=="string" then local label=Localize(key);if type(label)=="string" and label~=key and not label:find("<unlocalized",1,true) then m.context.modifiers[id]=label end end
                    end
                end
                local manager=Managers.state.mutator
                local templates=require("scripts/settings/mutator/mutator_templates")
                if manager and manager._mutators then
                    m.context.modifiers=m.context.modifiers or {}
                    for id in pairs(manager._mutators) do
                        local template=templates[id];local key=template and (template.display_name or template.name)
                        if type(key)=="string"then local label=Localize(key);if type(label)=="string" and label~=key and label~="" and not label:find("<unlocalized",1,true) then m.context.modifiers[id]=label end end
                    end
                end
            end)
            Context.sample_loadout(m)
        end
        return c
    end
    C.context = live_context
    local Incidents=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_incidents")(mod,api,C,{
        local_unit=local_unit,extension=extension,field=field,breed=breed,enemy_display=enemy_display,human=human,member=member,
        live_context=live_context,crystalline=crystalline,Timeline=Timeline,timeline=timeline,
        BossIdentity=BossIdentity,PsykerEligibility=PsykerEligibility,SocialNames=SocialNames})
    local confirmed_dodge=Incidents.confirmed_dodge
    local barrel_key,barrel_colour,barrel_actor,barrel_report=Incidents.barrel_key,Incidents.barrel_colour,Incidents.barrel_actor,Incidents.barrel_report
    local lethal_kick,martyrdom_selected=Incidents.lethal_kick,Incidents.martyrdom_selected
    local explosion_outcome,enemy_incapacitation,combat_report=Incidents.explosion_outcome,Incidents.enemy_incapacitation,Incidents.combat_report
    local helper,pickup,observe_control=Incidents.helper,Incidents.pickup,Incidents.observe_control
    local refresh_controls,sample_controls,survival=Incidents.refresh_controls,Incidents.sample_controls,Incidents.survival
    local control_states=Incidents.control_state_table()
    C.modifier_probe=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/modifier_probe")({extension=extension,identity=function(unit)return unit and identity(unit)end,is_enemy=is_enemy})
    local Measurements=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/measurement_collector")(mod,api,C,{local_unit=local_unit,extension=extension,context=live_context,is_enemy=is_enemy,enemy_display=enemy_display,peril_players=peril_players})
    -- The gameplay function is always called unchanged; errors in collection
    -- are isolated. Only the original gameplay errors propagate normally.
    local Attacks=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_attacks")(mod,api,C,{
        Armor=Armor,Attack=Attack,DamageCalculation=DamageCalculation,Damage=Damage,local_unit=local_unit,
        extension=extension,breed=breed,enemy_display=enemy_display,is_enemy=is_enemy,context=live_context,
        Experimental=Measurements,invoke=invoke,contained=contained})
    local dot_report,dps_report,pack,drain_attacks=Attacks.dot_report,Attacks.dps_report,Attacks.pack,Attacks.drain_attacks
    mod:hook_safe(Dodge, "sucessful_dodge", function(unit, attacker, attack_type, dodge_type)
        confirmed_dodge(unit, dodge_type, attack_type)
    end)
    -- Only the melee subset of the server dodge signal counts.
    mod:hook_safe("StatsManager", "record_private", function(_, name, player, breed_name, attack_type, dodge_type)
        if name == "hook_dodged_attack" and player then confirmed_dodge(player.player_unit, dodge_type, attack_type) end
    end)
    -- Dedicated-server melee evasion is also signalled through this exclusive
    -- sound RPC. Resolve the alias instead of guessing an audio resource name.
    mod:hook_safe("PlayerUnitFxExtension", "trigger_exclusive_wwise_event", function(fx, event_name)
        if C.support then invoke(C.support.sound,fx,event_name)end
        invoke(function()
            if fx._unit ~= local_unit() then return end
            if event_name == "wwise/events/player/play_player_dodge_ranged_success" then
                return
            end
            local loadout = fx._visual_loadout_extension
            if not loadout then return end
            local ok, name = loadout:resolve_gear_sound("dodge_success_melee")
            if ok and name == event_name then confirmed_dodge(fx._unit, "dodge", "melee") end
        end)
    end)
    local environmental = {barrel = true, liquid = true, vomit = true, corruption = true,
        grimoire = true, daemonhost_corruption = true, toxic_gas = true, damage_volume = true}
    local function report(profile, target, attacker, weakspot, damage, result, attack_type, measurement)
        if not api.enabled() then return end
        local own=local_unit();if target~=own and attacker~=own then return end
        local c = live_context()
        if not c then return end
        if target == local_unit() then
            if result~="blocked"and result~="dodged"and ((damage or 0)>0 or result=="toughness_absorbed"or result=="toughness_absorbed_melee"or result=="toughness_broken"or result=="knock_down"or result=="died")then
                local data,t=timeline();if data then Timeline.reset(data,t,result)end
            end

            local enemy = is_enemy(attacker)
            local excluded = false
            for word in pairs(environmental) do if (profile.name or ""):find(word, 1, true) then excluded = true; break end end
            if enemy and attack_type=="melee" and not excluded and ((damage or 0) > 0 or result == "toughness_absorbed") then
                api.tracker():damage_received(c, "enemy_attack"); 
            elseif enemy and attack_type=="melee" and result == "dodged" then confirmed_dodge(target, "dodge", "melee") end
        end
        ClassEvents.report(profile,target,attacker,damage,result)
        if attacker ~= local_unit() or (attack_type ~= "melee" and attack_type ~= "ranged" and attack_type ~= "explosion") then return end
        -- Range counters do not depend on attack timing/correlation. Ownership
        -- and enemy identity come from the existing confirmed damage report.
        local distance_counted=false
        if is_enemy(target)and (attack_type=="ranged"or attack_type=="explosion")then
            local own=local_unit();local distance
            if target and own and Unit.alive(target)and Unit.alive(own)then distance=Vector3.distance(Unit.world_position(own,1),Unit.world_position(target,1))end
            distance_counted=Measurements.distance_report(attack_type,result=="died",distance,measurement and measurement.useful)
        end
        return Attacks.match_report(profile,target,attacker,weakspot,damage,result,attack_type,measurement,distance_counted)
    end
    local Grouping=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/enemy_grouping")
local last_enemy_attack=setmetatable({},{__mode="k"})
local EnemyCatalog=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/enemy_catalog")
    local party_kill
    local Barrels=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/barrel_tracking")
    local barrel_tracking=Barrels.new();local collect_team_damage
    Incidents.bind_barrels(Barrels,barrel_tracking)
    local Bosses=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_bosses")(mod,api,C,{
        breed=breed,extension=extension,is_enemy=is_enemy,enemy_display=enemy_display,local_unit=local_unit,context=live_context,member=member,
        marker=marker,timeline=timeline,Timeline=Timeline,BossIdentity=BossIdentity,EnemyCatalog=EnemyCatalog,
        Grouping=Grouping,last_enemy_attack=last_enemy_attack})
    local watch_prophet,sample_prophet=Bosses.watch_prophet,Bosses.sample_prophet
    local boss_report_credit,kill_credit=Bosses.boss_report_credit,Bosses.kill_credit
    mod:hook_safe("MinionDeathManager","die",function(_,target,attacker,_,_,profile)boss_report_credit(target,attacker,profile,"died");kill_credit(target,attacker,profile);if party_kill then party_kill(target,attacker)end end)
    local Support=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_support")(mod,api,{member=member,local_unit=local_unit,invoke=invoke})
    C.support=Support
    local function before_report(profile, target, attacker, weakspot, damage, result, attack_type, efficiency, critical)
        if Support and (result=="blocked"or result=="died")then invoke(Support.report,target,attacker,result)end
        local attack_breed=breed(attacker)
        if attack_breed and attack_breed.breed_type=="minion"and not (attack_breed.is_boss or attack_breed.tags and (attack_breed.tags.monster or attack_breed.tags.captain))and (attack_type=="melee"or attack_type=="ranged")then last_enemy_attack[attacker]=attack_type end
        if C.modifier_probe.active then
            local ok,err=pcall(C.modifier_probe.observe,C.modifier_probe,C.clock,profile,target,attacker,weakspot,damage,result,attack_type,efficiency,critical)
            if not ok then local probe=C.modifier_probe;probe.counts.errors=probe.counts.errors+1;probe.last_error=tostring(err);if probe.counts.errors>=3 then probe:stop("errors")end end
        end
        local measurement;if collect_team_damage then measurement=collect_team_damage(profile,target,attacker,weakspot,damage,result,attack_type,efficiency,critical)end
        if hyper_report then hyper_report(profile,target,attacker,result,attack_type,critical,measurement)end
        if haymaker_report and Haymaker.signature(profile,result,attack_type)then haymaker_report(profile,target,attacker,result,attack_type,measurement)end
        if api.enabled()and attacker==local_unit()and is_enemy(target)and type(damage)=="number"and damage>=0 then
            local data,t=timeline()
            if data then
                local b=breed(target);local armour=Armor.armor_type(target,b,nil,attack_type)
                Timeline.hit(data,t,{damage=damage,useful=measurement and measurement.useful,profile=profile and profile.name,attack_type=attack_type,result=result,weakspot=weakspot,critical=critical,shield=armour=="void_shield"})
            end
        end
        if api.enabled()and attacker==local_unit()and not target and type(damage)=="number"and damage>=0 then
            local data=timeline();if data then local coverage=data.segments[#data.segments].coverage;coverage.unresolved_target_reports=(coverage.unresolved_target_reports or 0)+1 end
        end
        dps_report(profile,target,attacker,damage,result,attack_type,measurement)
        return measurement
    end
    local function after_report(manager, profile, target, attacker, weakspot, damage, result, attack_type, measurement)
        if barrel_report then barrel_report(target,attacker)end
        boss_report_credit(target,attacker,profile,result)
        if result=="died" and not manager._is_server then kill_credit(target,attacker,profile,damage,weakspot) end
        if not dot_report(profile,target,attacker,damage,result,attack_type) then report(profile, target, attacker, weakspot, damage, result, attack_type,measurement) end
    end
    mod:hook("AttackReportManager", "add_attack_result", function(func,manager, profile, target, attacker, direction, position, weakspot, damage, result, attack_type, efficiency, critical,...)
        local began=trace and trace.start()
        local ok,measurement=contained("add_attack_result",pcall(before_report,profile,target,attacker,weakspot,damage,result,attack_type,efficiency,critical))
        if trace then trace.finish("attack before",began)end
        if not ok then measurement=nil end
        local returns=pack(func(manager,profile,target,attacker,direction,position,weakspot,damage,result,attack_type,efficiency,critical,...))
        began=trace and trace.start()
        contained("add_attack_result",pcall(after_report,manager,profile,target,attacker,weakspot,damage,result,attack_type,measurement))
        if trace then trace.finish("attack after",began)end
        return unpack(returns,1,returns.n)
    end)

    local DepartureTracking=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/departure_tracking")
    Incidents.bind_combat({DepartureTracking=DepartureTracking,EnemyCatalog=EnemyCatalog,Grouping=Grouping})
    ClassEvents=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_class_events")(mod,api,C,{
        local_unit=local_unit,extension=extension,field=field,identity=identity,breed=breed,is_enemy=is_enemy,
        crystalline=crystalline,context=live_context,invoke=invoke,WeaponTemplate=WeaponTemplate,
        HyperCritical=HyperCritical,Haymaker=Haymaker})
    local hyper_register=ClassEvents.hyper_register
    hyper_report,haymaker_report=ClassEvents.hyper_report,ClassEvents.haymaker_report
    local Compact=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage")
    local Party=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")
    local PartyWeapon=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_weapon")
    Damage.bind_squad({Compact=Compact,Party=Party,PartyWeapon=PartyWeapon,
        local_unit=local_unit,breed=breed,Armor=Armor,member=member,is_enemy=is_enemy,enemy_display=enemy_display,Grouping=Grouping,last_enemy_attack=last_enemy_attack,
        BossIdentity=BossIdentity,extension=extension,EnemyCatalog=EnemyCatalog,Context=Context,Experimental=Measurements,
        Loadouts=Loadouts,WeaponTemplate=WeaponTemplate,invoke=invoke})
    party_kill,collect_team_damage=Damage.party_kill,Damage.collect_team_damage
    local finish_compact=Damage.finish_compact
    Damage.install_health_hooks(watch_prophet)
    local hot_joining=false
    mod:hook("HazardPropExtension","hot_join_sync",function(func,e,...)
        local old=hot_joining;hot_joining=true;local result=pack(func(e,...));hot_joining=old;return unpack(result,1,result.n)
    end)
    mod:hook("HazardPropExtension","set_current_state",function(func,e,state,...)
        local previous=e._current_state;local idle=previous=="idle";local result=pack(func(e,state,...))
        if (idle and state=="triggered"or previous=="triggered"and state=="exploding")and not hot_joining then invoke(function()
            if Barrels.transition(barrel_tracking,api.tracker().mission,barrel_key(e._unit),barrel_colour(e),C.clock,state)then api.tracker().dirty=true;end
        end)end
        return unpack(result,1,result.n)
    end)
    mod:hook("HazardPropExtension","add_damage",function(func,e,amount,actor,direction,attacker,...)
        local previous=e._current_state;local idle=previous=="idle";local result=pack(func(e,amount,actor,direction,attacker,...))
        if e._is_server and (idle and e._current_state~="idle"or previous=="triggered"and e._current_state=="exploding")then invoke(function()
            if Barrels.hit(barrel_tracking,api.tracker().mission,barrel_key(e._unit),barrel_colour(e),barrel_actor(attacker),C.clock,false,idle and "first"or "second")then api.tracker().dirty=true;end
        end)end
        return unpack(result,1,result.n)
    end)
    mod:hook_safe("AttackReportManager","_process_attack_result",function(_,data)combat_report(data)end)
    local FieldImprovisation=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/field_improvisation")
    local Roster=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/operative_roster")
    local ClutchTracking=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/clutch_tracking")
    Incidents.bind_controls({FieldImprovisation=FieldImprovisation,Roster=Roster,ClutchTracking=ClutchTracking,hyper_register=hyper_register})
    -- Dedicated-server explosions replicate their owning operative to clients.
    mod:hook_safe("WeaponSystem","rpc_trigger_husk_explosion",function(_,_,template_id,position,_,_,_,owner_id)
        invoke(function()
            local names=NetworkLookup and NetworkLookup.explosion_templates
            if not names then return end
            local owner=owner_id and Managers.state.unit_spawner and Managers.state.unit_spawner:unit(owner_id)
            
            if names[template_id]~="warp_charge_overload" then return end
            local spawner=Managers.state and Managers.state.unit_spawner
            local unit=owner_id and spawner and spawner:unit(owner_id)
            if unit then survival(unit,"peril_detonated") end
        end)
    end)
    for class_name,state in pairs({PlayerCharacterStateKnockedDown="knocked_down",PlayerCharacterStatePounced="pounced",PlayerCharacterStateNetted="netted",PlayerCharacterStateMutantCharged="mutant_charged",PlayerCharacterStateDead="dead",PlayerCharacterStateHogtied="hogtied",PlayerCharacterStateFalling="falling"}) do
        local entered=state
        mod:hook_safe(class_name,"on_enter",function(_,unit)observe_control(unit,entered,true)end)
        if class_name~="PlayerCharacterStateDead" then
            mod:hook_safe(class_name,"on_exit",function(_,unit,_,next_state)
                if type(next_state)=="string" then observe_control(unit,next_state,true) end
            end)
        end
    end
    mod:hook_safe("PlayerInteracteeExtension","stopped",function(self,result,actor)
        if C.support then invoke(C.support.stopped,self,result,actor)end
        invoke(function()
            if result~="success" then return end
            local key=member(self._unit);local state=key and control_states[key]
            if state=="knocked_down" or state=="hogtied" then pickup(self._unit,actor) end
        end)
    end)
    local Notifications=require("scripts/utilities/player_assist_notifications")
    do mod:hook_safe(Notifications,"show_notification",function(target,actor,kind)
        if target~=actor and (kind=="saved" or kind=="rescued") then helper(target,actor) end
    end) end
    mod:hook_safe("PlayerManager","_show_assist_notification",function(self,peer,kind)
        invoke(function()
            if (kind=="saved" or kind=="rescued") and type(self.player)=="function" then local player=self:player(peer,1);if player then helper(local_unit(),player.player_unit) end end
        end)
    end)
    mod:hook_safe("BtInjectSyringeAction","_send_revived_ally_telemetry",function(_,owner,target,from_state)
        if owner and (from_state=="knocked_down" or from_state=="hogtied") then helper(target,owner.player_unit) end
    end)
    mod:hook_safe("ActionOverloadExplosion", "_explode", function(action, settings)
        if settings and settings.overload_type == "warp_charge" then
            survival(action._player_unit, "peril_detonated")
        end
    end)
    -- This is the server's mission clock at initial synchronization, not
    -- elapsed time since this client finished loading. Fresh Havoc starts in
    -- the supplied logs synchronize near 1.6 s; late joins near 100/500 s.
    local Timing=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_timing_diagnostics")(mod,api,C)
    mod:hook_safe("ProgressionManager","_parse_mission_stats",function(manager,eor)
        invoke(Timing.report,manager,eor)
    end)
    mod:hook_safe("AdaptiveClockHandlerClient", "rpc_sync_clock", function(_, clock_start, clock_offset, last_frame)
        Mission:sync_clock(clock_start)
        invoke(Timing.sync,clock_start,clock_offset,last_frame)
    end)
    -- Loading views and replicated client_set_scene also occur on hot join.
    -- Only a locally queued mission introduction confirms start participation.
    -- The replicated game-mode transition exists even when a client bypasses
    -- the cinematic entry points. It is only promoted after a confirmed win.
    mod:hook_safe("GameModeCoopCompleteObjective","_change_state",function(_,new_state)
        if new_state=="outro_cinematic"then marker(api.tracker().mission,"outro_start")end
    end)
    mod:hook_safe("CinematicSceneSystem","play_cutscene",function(_,name,channel)
        if name=="outro_win"and channel==nil then marker(api.tracker().mission,"victory_request")end
    end)
    mod:hook_safe("CinematicSceneSystem", "_play_cutscene", function(system, name, client_channel_id)
        invoke(function()
            Mission:play_cutscene(system,name,client_channel_id)
        end)
    end)
    mod:hook_safe("GameModeManager", "_set_end_conditions_met", function(_, outcome)
        invoke(function()Mission:end_conditions(outcome)end)
    end)
    mod:hook_safe("EndPlayerView","on_enter",function()
        invoke(function()Mission:end_screen()end)
    end)
    Mission=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collector_mission")(mod,api,C,{
        Context=Context,Damage=Damage,RunResume=RunResume,Timeline=Timeline,DepartureTracking=DepartureTracking,
        Attacks=Attacks,Incidents=Incidents,Bosses=Bosses,SocialNames=SocialNames,Experimental=Measurements,
        timeline=timeline,sample_prophet=sample_prophet,sample_controls=sample_controls,drain_attacks=drain_attacks,
        update_dps=Damage.update_dps,finish_compact=finish_compact,live_context=live_context,
        reset_down_seen=function()down_seen=setmetatable({},{__mode="k"})end,invoke=invoke,
        set_control_states=function(value)control_states=value end,Timing=Timing})

    ClassEvents.install_ammo_hooks()
    local update=C.update
    C.update=function(self,...)
        local result=update(self,...);local m=api.tracker().mission
        Damage.refresh_squad(m)
        if Support then invoke(Support.update,self.clock)end

        return result
    end
    -- a mission joined late or picked up after a mods reload has no start, only how long it has been tracked, from the first frame it is asked for; it lasted at least that
    local NO_MARKS={}
    function C:tracked_seconds()
        local m=api.tracker().mission
        if not m or m.context.difficulty=="psykhanium"then return end
        if m.tracked_from==nil then m.tracked_from=mission_time()end;if not m.tracked_from then return end
        local marks=m.completion_markers or NO_MARKS;local boss=mod.io_display_options and (mod.io_display_options()or NO_MARKS).boss_map_timing;local stop=boss and marks.boss_death or marks.victory_request or marks.victory_transition or marks.outro_start
        local now=stop or mission_time();return now and math.max(0,now-m.tracked_from)
    end
    return C
end












