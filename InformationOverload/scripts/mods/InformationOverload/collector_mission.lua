-- Mission lifecycle and recovery; constructed inside the collector factory.
return function(mod,api,C,deps)
    local Mission={}
    local Context,Damage,RunResume=deps.Context,deps.Damage,deps.RunResume
    local Timeline,DepartureTracking,Attacks,Incidents,Bosses=deps.Timeline,deps.DepartureTracking,deps.Attacks,deps.Incidents,deps.Bosses
    local SocialNames,Measurements=deps.SocialNames,deps.Experimental
    local timeline,sample_prophet,sample_controls,drain_attacks,update_dps=deps.timeline,deps.sample_prophet,deps.sample_controls,deps.drain_attacks,deps.update_dps
    local finish_compact,reset_down_seen,set_control_states=deps.finish_compact,deps.reset_down_seen,deps.set_control_states
    local invoke=deps.invoke
    local Timing=deps.Timing
    local function stored_set(key,value)if mod.io_data_set then mod.io_data_set(key,value)else mod:set(key,value,false)end end
    -- the records a mission set, by the key of their rows, which a relaunch builds again, so a mission brought back from its checkpoint names
    -- its match on them as it would without a crash; only a row's highest value in the mission can still be its best, so that one is kept
    local function credit_keys(m)
        local rows,key_of=api.tracker().data.rows or {},{}
        for k in pairs(m.recovery_rows or {})do if rows[k]then key_of[rows[k]]=k end end
        local function keyed(refs,kept,field)
            local top,out={},{}
            local function add(k,id,value)
                if type(k)~="string"or id==nil or type(value)~="number"then return end
                top[k]=top[k]or {};local t=top[k][id]
                if not t then t={key=k,[field]=id,value=value};top[k][id]=t;out[#out+1]=t elseif value>t.value then t.value=value end
            end
            for _,u in ipairs(kept or {})do add(u.key,u[field],u.value)end
            for _,u in ipairs(refs or {})do add(key_of[u.row],u[field],u.value)end
            return out[1]and out or nil
        end
        return keyed(m.record_updates,m.record_update_keys,"name"),keyed(m.enemy_updates,m.enemy_update_keys,"enemy")
    end
    local mission_manager, saw_intro, intro_manager, ended, pending_result
    if mod.get then
        local recovered=mod.io_data_get and mod.io_data_get("unfinished_run_v1")or mod:get("unfinished_run_v1")
        -- a checkpoint holding its mission's result is that mission as it ended; any other is a mission left part way
        if type(recovered)=="table" and recovered.context then local review=type(recovered.private_review_victory)=="boolean";local finished=review or type(recovered.finished_victory)=="boolean";if not finished then recovered.interrupted=true;recovered.full=false end;pending_result={mission=recovered,victory=recovered.private_review_victory==true or not review and recovered.finished_victory==true,private_review=review,interrupted=not finished} end
    end
    local completed_timing
    local entry_clock, entry_clock_manager
    local pending_intro
    local intro_origin

    local function mission_time()
        local manager=Managers.time
        if not manager or manager.has_timer and not manager:has_timer("gameplay")then return end
        local t=manager:time("gameplay")
        if type(t)=="number"and t>0 and t<=86400 then return t end
    end
    local function marker(m,key)
        local t=mission_time();if not m or not t then return end
        m.completion_markers=m.completion_markers or {};m.completion_markers[key]=m.completion_markers[key]or t
        if Timing then invoke(Timing.mark,m,key)end
    end
    -- a match joined late never sees its own start, so its clock is the server's, less the 7 seconds in that a match starts on it when its intro is seen
    C.timer_seconds=function(self)
        local m=api.tracker().mission
        if not m or m.context.difficulty=="psykhanium"then return end
        local origin=m.timing_origin;if origin==nil and not m.full and m.timing_diagnostics and m.timing_diagnostics.clock_sync then origin=7 end
        if not origin then return end
        local marks=m.completion_markers or {};local boss=mod.io_display_options and (mod.io_display_options()or {}).boss_map_timing;local stop=boss and marks.boss_death or marks.victory_request or marks.victory_transition or marks.outro_start
        local now=stop or mission_time();return now and math.max(0,now-origin)
    end
    function Mission:observe_context(c)
        -- Mission identity is the manager instance, not a name that may repeat.
        local manager = Managers.state.mission
        if manager ~= mission_manager then
            -- The intro can run before the gameplay mission manager exists.
            local participated = pending_intro == true or (saw_intro and intro_manager == manager) or (entry_clock_manager==manager and entry_clock~=nil and entry_clock<=5)
            pending_intro = nil
            C:boundary()
            if pending_result and not pending_result.interrupted and not pending_result.private_review then pending_result=nil end
            mission_manager, ended = manager, false
            saw_intro = participated
        end
        if pending_result and pending_result.private_review then return end
        if not ended and not api.tracker().mission and pending_result and pending_result.interrupted and RunResume.restore(api.tracker(),pending_result.mission,c)then pending_result=nil;stored_set("unfinished_run_v1",nil)end
        if not ended and not api.tracker().mission then completed_timing=nil;api.tracker():begin_mission(c, c.solo==true or saw_intro == true or api.debug()) end
        if Timing then invoke(Timing.observe,api.tracker().mission)end
    end
    function Mission:scene_init(system)
        if system._skip_intro_cinematic then intro_origin=0 else intro_origin=nil end
    end
    function Mission:cinematic_update(manager,story)
        if story and story.cinematic_scene_name=="intro_abc"and not intro_origin and manager._storyteller then
            local id=story.story_id
            if manager._storyteller:length(id)<manager._storyteller:time(id)then intro_origin=mission_time()end
        end
        if story and story.cinematic_scene_name=="outro_win"then marker(api.tracker().mission,"victory_transition")end
    end
    function Mission:sync_clock(clock_start)
        if type(clock_start)~="number" or clock_start<0 then return end
        entry_clock,entry_clock_manager=clock_start,Managers.state.mission
        local m=api.tracker().mission
        if m and mission_manager==entry_clock_manager and clock_start<=5 then m.full=true end
    end
    function Mission:play_cutscene(system,name,client_channel_id)
        if name=="outro_win"and client_channel_id==nil then
            marker(api.tracker().mission,"victory_transition");return
        end
        if name ~= "intro_abc" or client_channel_id ~= nil then return end
        if not system or system._current_cinematic_name ~= name then return end
        pending_intro = true
        saw_intro = true
        intro_manager = Managers.state.mission
        local m = api.tracker().mission
        if m and not m.resumed then m.full = true end
    end
    function Mission:end_conditions(outcome)
        if not api.enabled() or ended or (outcome ~= "won" and outcome ~= "lost") then return end
        local tracker = api.tracker()
        local m=tracker.mission
        if not m or m.context.difficulty=="psykhanium" or m.context.difficulty=="TEST ONLY" then return end
        sample_controls()
        m.ended_clock=C.clock;m.ended_wall=os and os.time and os.time()or nil
        if Timing then invoke(Timing.mark,m,"end_conditions")end
        if outcome=="won"then
            m.completion_markers=m.completion_markers or {}
            if not m.completion_markers.victory_request and m.completion_markers.outro_start then
                m.completion_markers.victory_request=m.completion_markers.outro_start
                m.completion_markers.victory_request_basis="replicated_outro_state"
            elseif m.completion_markers.victory_request then m.completion_markers.victory_request_basis="cinematic_request"end
        end
        if outcome=="won"and m.full and Managers.time then
            local seconds=mission_time()
            if type(seconds)=="number"and seconds>0 and seconds<=86400 then
                m.completion_markers=m.completion_markers or {};m.completion_markers.result_notification=seconds
                local boss=mod.io_display_options and (mod.io_display_options()or {}).boss_map_timing
                local chosen=boss and m.completion_markers.boss_death or m.completion_markers.victory_request or m.completion_markers.victory_transition
                if chosen then m.completion_markers.win_condition=chosen end
                m.completion_time={seconds=math.max(0,(chosen or seconds)-(m.timing_origin or 0)),source=m.timing_origin~=nil and "mission_clock"or "unverified_clock"}
            end
        end
        if Timing then invoke(Timing.complete,m,outcome=="won")end
        ended = true
        pending_intro=nil

        finish_compact(m)
        -- the result goes into the mission's checkpoint, written now in one go, so the save of its match can spread over frames: a crash
        -- before that save commits brings the mission back as it ended, not as its checkpoint from up to a minute before
        if m.context.private_game==true then m.private_review_victory=outcome=="won"else m.finished_victory=outcome=="won"end
        if api.keep_result then api.keep_result()end
        api.save()
        if tracker.mission.full and not m.context.private_game then
            tracker:finish_mission(true, outcome == "won", false); api.save()
            if outcome=="won"then completed_timing={id=tracker.data.run_sequence,markers=m.completion_markers};if Managers.time then local t=Managers.time:time("main");if type(t)=="number"then completed_timing.main=t;completed_timing.seconds=m.completion_markers and m.completion_markers.result_notification end end end
        else
            pending_result = {mission = tracker.mission, victory = outcome == "won",private_review=m.context.private_game==true}
            if pending_result.private_review then m.private_review_victory=pending_result.victory end
            tracker.mission = nil
            -- nothing asks: a late join or a rejoin counts like any mission, and a private game is kept as data only; Match History deletes either
            if pending_result.private_review then C:save_private()
            -- a counted win keeps the moment its end screen opened, as a full mission's does
            elseif C:count_partial()and outcome=="won"then completed_timing={id=tracker.data.run_sequence}end
        end
        if tracker.mission==nil and not pending_result and api.mission_finished then api.mission_finished() end
    end
    function Mission:end_screen()
        local t=mission_time()
        if completed_timing and completed_timing.main and completed_timing.seconds and Managers.time then
            local now=Managers.time:time("main")
            if type(now)=="number"then t=completed_timing.seconds+math.max(0,now-completed_timing.main)end
        end
        if not t then return end
        if completed_timing then
            for _,run in ipairs(api.tracker().data.run_history or {})do
                if run.id==completed_timing.id and run.victory and not run.data_only then
                    run.completion_markers=run.completion_markers or {};run.completion_markers.end_screen=run.completion_markers.end_screen or t
                    if api.end_screen_marked then api.end_screen_marked(api.tracker())end;break
                end
            end
        end
        completed_timing=nil
    end

    function C:checkpoint()
        Damage.checkpoint_party()
        if not mod.set or api.debug() then return end
        local m=pending_result and pending_result.mission or api.tracker().mission
        Damage.checkpoint_damage(m)
        if not m or m.context.solo or m.context.difficulty=="psykhanium" or m.context.difficulty=="TEST ONLY" or m.history_recorded then
            stored_set("unfinished_run_v1",nil);return
        end
        local snapshot={}
        for _,name in ipairs({"private_review_victory","finished_victory","started_at","timing_origin","completion_time","completion_markers","timing_diagnostics","context","full","exploded","failed","damage","barrel_pops","team_damage","party_records","psyk_dps","record_values","replay_best","replay_armour","replay_kill_segments","replay_blo_contexts","replay_blo_best","data_before","ammo","ammo_seen","kills","incidents","friendly_fire_pairs","pickup_pairs","pickup_states","team_psykers","field_improvisation","enemy_lethality","hyper_critical","haymaker","class_events","clutches","clutch_bot_recovered","operative_clutches","kill_categories","leave_hits","departure_snapshot","departure_events","all_departures","segments","resumed","bot_links","bot_candidates","bot_appearances","bot_pickup_events","last_departure","last_observed_clock","ended_clock","ended_wall","boss_seen","boss_credit_seen","boss_operative_seen","boss_operatives","boss_kills","departed_players","players_left","lethality_events","lethality_active","enemy_kill_counts","recovery_rows","experimental","measurements","combat_timeline"}) do snapshot[name]=m[name] end
        if api.recovery_delta and m.data_before then snapshot.progress_delta=api.recovery_delta(m)end
        snapshot.record_update_keys,snapshot.enemy_update_keys=credit_keys(m)
        stored_set("unfinished_run_v1",snapshot)
    end
    function C:save_interrupted(data_only)
        if not pending_result or not pending_result.interrupted then return false end
        local m=pending_result.mission
        if not data_only then return self:count_partial() end
        m.data_only=true;m.interrupted=true
        finish_compact(m)

        api.tracker():save_run(m,nil)
        pending_result=nil;if mod.set then stored_set("unfinished_run_v1",nil) end;api.save(true,true)
        return true
    end
    function C:count_partial()
        if not pending_result then return false end
        local tracker = api.tracker()
        local active = tracker.mission
        tracker.mission = pending_result.mission
        finish_compact(pending_result.mission)
        local partial_mission=pending_result.mission;local partial_win=pending_result.victory
        local counted = tracker:finish_mission(true, pending_result.victory, not partial_mission.full)
        tracker.mission = active
        pending_result = nil
        if mod.set then stored_set("unfinished_run_v1",nil) end
        api.save()
        if api.mission_finished then api.mission_finished() end
        return counted
    end
    function C:forget_partial() pending_result=nil end
    function C:partial_pending() return pending_result ~= nil end
    -- a private game is kept as data only, with its result: out of the win and loss streaks, as any data-only run
    function C:save_private()
        local result=pending_result;if not result or not result.private_review then return false end
        local m=result.mission;m.data_only=true
        finish_compact(m);api.tracker():save_run(m,result.victory)
        pending_result=nil;if mod.set then stored_set("unfinished_run_v1",nil)end;api.save(true,true)
        return true
    end
    -- nothing asks: back in the Mourningstar, a mission left and not rejoined counts as a loss, or as data only when it was a private game,
    -- and a rejoin later merges with it; a private game still waiting from before a crash is kept as data only, and a finished result left
    -- waiting by an error is tried once more and then let go, so nothing that waits on it waits forever
    function C:settle_pending()
        local result=pending_result;if not result or api.tracker().mission or not api.enabled()then return false end
        if result.private_review then return self:save_private()end
        if result.interrupted then if api.in_hub and api.in_hub()then return self:save_interrupted(result.mission.context.private_game==true)end;return false end
        if result.tried then pending_result=nil;if mod.set then stored_set("unfinished_run_v1",nil)end;return false end
        result.tried=true;return self:count_partial()
    end

    function C:update(dt)
        self.clock = self.clock + dt
        invoke(drain_attacks)
        if self.modifier_probe.active and self.modifier_probe.started and self.clock-self.modifier_probe.started>=600 then self.modifier_probe:stop("timeout")end
        if dt>=.05 then self.last_busy_frame=self.clock end
        SocialNames.update_clock(self.clock)
        sample_prophet()
        -- A scalar state check covers game-mode subclasses that copied their
        -- inherited transition method before hooks were installed. Timestamp
        -- only once, before any boundary handling can release the mission.
        local timing_mission=api.tracker().mission
        if Timing then invoke(Timing.tick,timing_mission)end
        timeline(true)
        if timing_mission and timing_mission.timing_origin==nil then
            if intro_origin~=nil then timing_mission.timing_origin=intro_origin
            else
                local mode=Managers.state and Managers.state.game_mode
                local mechanism=Managers.mechanism and Managers.mechanism._mechanism
                local state=mechanism and mechanism._mechanism_data
                if timing_mission.full and (mode and mode._game_mode and mode._game_mode._skip_intro_cinematic or state and state.skip_intro_cinematic)then timing_mission.timing_origin=0 end
            end
        end
        if timing_mission and not (timing_mission.completion_markers and timing_mission.completion_markers.outro_start)then
            local manager=Managers.state and Managers.state.game_mode
            local game_mode=manager and manager._game_mode
            if game_mode and game_mode._state=="outro_cinematic"then marker(timing_mission,"outro_start")end
        end

        if not self.next_context or self.clock>=self.next_context then self.next_context=self.clock+.25;deps.live_context()end
        if timing_mission and timing_mission.context.difficulty=="psykhanium"then update_dps()end
        if pending_result then C.settle_pending(self)end
        if api.enabled()and api.tracker().mission then sample_controls()end
        Measurements.tick(dt)
    end
    function C:recovery_ready()
        if not api.tracker().mission then return true end
        if self.last_combat and self.clock-self.last_combat<3 then return false end
        if self.last_busy_frame and self.clock-self.last_busy_frame<.25 then return false end
        return true
    end
    function C:boundary()
        Context.reset()
        local m=api.tracker().mission
        if m and not ended then finish_compact(m)end
        if m and not ended then
         for _,person in pairs(m.departure_snapshot and m.departure_snapshot.people or {})do if person.personal then m.all_departures=m.all_departures or {};local existing=false;for _,event in ipairs(m.all_departures)do if event.personal and not event.returned then existing=true end end;if not existing then m.all_departures[#m.all_departures+1]={player=person.key,character_id=person.id,name=person.name,class=person.class,personal=true,steam_id=person.steam_id,steam_name=person.steam_name,at=C.clock,wall_at=os and os.time and os.time()or nil}end end end
         local pending=DepartureTracking.capture_self(m,C.clock);if pending then api.tracker().data.self_leave_pending=pending;api.tracker().dirty=true;api.save(true)end end
        if m and m.context.solo and not ended then
            m.interrupted=true;m.data_only=true
            finish_compact(m);api.tracker():finish_mission(true,false,true);api.save();ended=true;m=nil
        end
        if m and not ended and not pending_result and not api.debug() and m.context.difficulty~="psykhanium" and m.context.difficulty~="TEST ONLY" then

            m.interrupted=true;m.full=false;m.ended_clock=m.ended_clock or C.clock;m.ended_wall=m.ended_wall or os and os.time and os.time()or nil
            pending_result={mission=m,victory=false,interrupted=true}
        end
        self:checkpoint()
        if api.tracker().mission then pending_intro=nil end
        self.attacks, self.expected, self.projectiles = {}, {}, {}
        Attacks.reset();Incidents.reset_dodge()
        reset_down_seen()
        set_control_states(Incidents.reset_transients())
        Bosses.reset_kills()
        intro_origin=nil;self.last_combat=nil;self.last_busy_frame=nil;Incidents.reset_sampling()
        saw_intro, intro_manager, mission_manager, ended = false, nil, nil, false
        -- Keep a completed partial result available in the hub. Switching test
        -- databases must not move a test result into the lifetime database.
        if self.pending_debug ~= api.debug() then pending_result = nil end
        self.pending_debug = api.debug()
        api.tracker():boundary()
        api.save()
    end

    Mission.mission_time,Mission.marker,Mission.update=mission_time,marker,C.update
    return Mission
end
