-- Boss/kill observation state, owned by one collector factory.
return function(mod,api,C,D)
    local breed,extension,is_enemy,enemy_display,local_unit,live_context,member=D.breed,D.extension,D.is_enemy,D.enemy_display,D.local_unit,D.context,D.member
    local marker,timeline,Timeline=D.marker,D.timeline,D.Timeline
    local BossIdentity,EnemyCatalog,Grouping,last_enemy_attack=D.BossIdentity,D.EnemyCatalog,D.Grouping,D.last_enemy_attack
    local credited_kills=setmetatable({}, {__mode="k"})
    local boss_identity_cache=setmetatable({},{__mode="k"})
    local function boss_token(unit)
        local spawner=Managers.state and Managers.state.unit_spawner
        if spawner and spawner.game_object_id then local value=spawner:game_object_id(unit);if value then return "network:"..tostring(value) end end
        return tostring(unit)
    end
    local prophet_unit,prophet_health,prophet_mission
    local function watch_prophet(health,context,unit)
        local m=api.tracker().mission;if not m or m.context.mission_name~="spillway"then return end;local b=breed(unit)
        if b and b.name=="renegade_wizard"then prophet_unit=unit;prophet_health=health;prophet_mission=m end
    end
    local function sample_prophet()
        if not prophet_unit then return end
        local m=api.tracker().mission
        if m~=prophet_mission or not Unit.alive(prophet_unit)then prophet_unit=nil;prophet_health=nil;prophet_mission=nil;return end
        local maximum=prophet_health:max_health();local hp=prophet_health:current_health()
        if maximum and maximum>0 and hp and hp<=0 then
            marker(m,"boss_death");if not (m.completion_markers and m.completion_markers.boss_death)then return end;m.completion_markers.boss_death_basis="replicated_prophet_health_depleted"
            api.tracker():boss_defeated("renegade_wizard",EnemyCatalog.name("renegade_wizard"),boss_token(prophet_unit),false);api.save()
            prophet_unit=nil;prophet_health=nil;prophet_mission=nil
        end
    end
    -- a captain map's boss is the captain the game makes its kill objective; any other captain reads "default" or has no objective
    local FINAL_TARGET={km_station="objective_km_station_eliminate_target",km_enforcer="objective_km_enforcer_eliminate_target"}
    local function final_captain(m,unit,b)
        local want=FINAL_TARGET[m.context.mission_name];if not want or not (b.name=="renegade_captain"or b.name=="cultist_captain")then return false end
        local target=extension(unit,"mission_objective_target_system")
        return target and type(target.objective_name)=="function"and target:objective_name()==want or false
    end
    local function boss_label(id,label,b)label=label or EnemyCatalog.name(id);if label=="Unknown enemy"and b then label=EnemyCatalog.name(enemy_display(b))end;return label end
    local function boss_death(unit,profile_name)
        if not api.enabled() then return end
        local b=breed(unit);local tags=b and b.tags or {}
        if not b or not (b.is_boss or tags.monster or tags.captain) then return end
        if not api.tracker().mission and not live_context() then return end
        local id,captain_label,weakened=BossIdentity.identify(unit,b,extension);if not id then return end;local label=boss_label(id,captain_label,b)
        if id=="chaos_mutator_daemonhost" then
            local ritual=profile_name=="default";id=ritual and "hexbound_ritual" or "hexbound_daemonhost";label=ritual and "Hexbound Daemonhost - Ritual stopped" or "Hexbound Daemonhost - Defeated"
        end
        local m=api.tracker().mission
        if m and final_captain(m,unit,b)then marker(m,"boss_death")end
        boss_identity_cache[unit]={id=id,label=label,weakened=weakened,token=boss_token(unit)}
        if api.tracker():boss_defeated(id,label,boss_token(unit),weakened) then api.save() end
    end
    mod:hook_safe("MinionDeathManager","set_dead",function(_,unit,_,_,profile_name)boss_death(unit,profile_name)end)
    local function boss_report_credit(target,attacker,profile,result)
        if not api.enabled()or result~="died"or not attacker or not live_context()then return end
        local m=api.tracker().mission;if not m then return end
        local b=breed(target);local tags=b and b.tags or {};local cached=target and boss_identity_cache[target]
        if not cached and (not b or not (b.is_boss or tags.monster or tags.captain))then return end
        local id,label,weakened
        if cached then id,label,weakened=cached.id,cached.label,cached.weakened else id,label,weakened=BossIdentity.identify(target,b,extension)end
        if not id then return end
        if id=="chaos_mutator_daemonhost"then if profile and profile.name=="default"then return end;id="hexbound_daemonhost";label="Hexbound Daemonhost - Defeated"end
        if id=="hexbound_ritual"then return end
        local actor,class,personal=member(attacker);if not actor then return end
        local ids=m.context.operative_identities;local identity=ids and ids[actor]
        api.tracker():boss_operative_killing_blow(actor,class,personal,identity,id,boss_label(id,label,b),cached and cached.token or boss_token(target),weakened)
    end
    local function kill_credit(target,attacker,profile,damage,weakspot)
        if attacker~=local_unit() then return end
        local c=live_context()
        if not c then return end
        if not target and profile then
            local candidate, count_matches=nil,0
            for _,e in ipairs(C.expected) do
                if e.profile==profile.name and e.predicted_result=="died" and e.weakspot==weakspot
                    and type(e.predicted_damage)=="number" and math.abs(e.predicted_damage-(damage or 0))<=math.max(1,math.abs(e.predicted_damage)*0.001) then
                    candidate=e.target;count_matches=count_matches+1
                end
            end
            if count_matches==1 then target=candidate end
        end
        if target and credited_kills[target] then return end
        local enemy,b=is_enemy(target)
        if target and not enemy then return end
        local tags=b and b.tags or {}
        local category
        if not tags.monster and not tags.captain and not (b and b.is_boss) then
            category=tags.special and "special" or tags.elite and "elite" or enemy and "regular" or nil
        else category="boss"
        end
        if target and b and (b.is_boss or tags.monster or tags.captain) then
            local id,label,weakened=BossIdentity.identify(target,b,extension)
            if id and id~="chaos_mutator_daemonhost" then api.tracker():boss_killing_blow(id,boss_label(id,label,b),boss_token(target),weakened)
            elseif id=="chaos_mutator_daemonhost" and profile and profile.name~="default" then api.tracker():boss_killing_blow("hexbound_daemonhost","Hexbound Daemonhost - Defeated",boss_token(target),false) end
        end
        if target then credited_kills[target]=true end
        if enemy then local data,t=timeline();if data then Timeline.kill(data,t)end end
        api.tracker():kill_credit(c,category,b and Grouping.trash_ranged(b.name,b.ranged,last_enemy_attack[target]));
        if not b then
            

        end
    end
    return {watch_prophet=watch_prophet,sample_prophet=sample_prophet,
        boss_report_credit=boss_report_credit,kill_credit=kill_credit,
        reset_kills=function()credited_kills=setmetatable({}, {__mode="k"})end}
end
