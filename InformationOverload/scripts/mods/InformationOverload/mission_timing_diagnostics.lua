-- Session-matched backend completion times and bounded clock observations.
-- Live UI clocks continue to use their existing collector methods.
return function(mod,api,C)
    local Times=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_times")
    local D={}
    local anchor,anchor_manager,observed,observed_tracker,next_sample
    local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
    local function seconds(n)return finite(n)and n>=0 and n<=86400 end
    local function clock(name)
        local time=Managers.time
        if not time or time.has_timer and not time:has_timer(name)then return end
        local value=time:time(name)
        if finite(value)then return value end
    end
    local function session()
        local connection=Managers.connection
        return connection and connection.session_id and connection:session_id()
    end
    local function eligible(m)
        local c=m and m.context
        return type(c)=="table"and type(c.mission_instance)=="string"and c.mission_instance~=""and c.difficulty~="psykhanium"and c.difficulty~="TEST ONLY"
    end
    local function data(m)
        m.timing_diagnostics=m.timing_diagnostics or {version=1}
        return m.timing_diagnostics
    end
    local function sample(m)
        local d=data(m)
        local gameplay,main=clock("gameplay"),clock("main")
        if not seconds(gameplay)then return end
        local now={gameplay_seconds=gameplay,source="server_synchronized_gameplay_clock",observed_main_seconds=main,observed_collector_seconds=C.clock}
        local sync=d.clock_sync
        if sync and finite(main)and finite(sync.observed_main_seconds)and main>=sync.observed_main_seconds then
            now.from_initial_sync_seconds=sync.server_clock_seconds+main-sync.observed_main_seconds
            now.gameplay_minus_initial_sync_seconds=gameplay-now.from_initial_sync_seconds
        end
        d.current=now
    end
    function D.observe(m)
        if not api.enabled()or not eligible(m)then return end
        observed,observed_tracker=m,api.tracker()
        if anchor and anchor_manager==Managers.state.mission and anchor.session_id==m.context.mission_instance then
            local d=data(m)
            if d.clock_sync~=anchor then d.clock_sync=anchor;sample(m)end
        end
    end
    function D.sync(clock_start,clock_offset,last_frame)
        if not api.enabled()or not seconds(clock_start)then return end
        local id=session()
        if type(id)~="string"or id==""then return end
        anchor_manager=Managers.state.mission
        anchor={session_id=id,server_clock_seconds=clock_start,
            clock_offset_seconds=finite(clock_offset)and clock_offset or nil,
            server_frame=finite(last_frame)and last_frame or nil,
            observed_gameplay_seconds=clock("gameplay"),observed_main_seconds=clock("main"),
            observed_collector_seconds=C.clock,source="AdaptiveClockHandlerClient.rpc_sync_clock"}
        D.observe(api.tracker().mission)
    end
    function D.tick(m)
        if not api.enabled()or not eligible(m)then return end
        D.observe(m)
        if next_sample and C.clock<next_sample then return end
        next_sample=C.clock+1
        if m.timing_diagnostics then sample(m)end
    end
    function D.mark(m,name)
        if not api.enabled()or not eligible(m)then return end
        D.observe(m);sample(m)
        local d=data(m);local current=d.current
        if not current then return end
        d.events=d.events or {}
        if not d.events[name]then
            local event={};for k,v in pairs(current)do event[k]=v end
            d.events[name]=event
        end
    end
    function D.complete(m,victory)
        if not eligible(m)then return end
        local d=data(m)
        if type(victory)=="boolean"then d.outcome=victory and "won"or "lost"
        elseif type(m.victory)=="boolean"then victory=m.victory
        else victory=d.outcome=="won"end
        local completion=victory and Times.backend(m)
        if completion then
            local previous=m.completion_time
            if not previous or previous.source~=completion.source or previous.seconds~=completion.seconds then mod.io_times_revision=(mod.io_times_revision or 0)+1 end
            m.completion_time=completion
        end
    end
    function D.report(manager,eor)
        if not api.enabled()or manager and manager._session_report_is_dummy==true or type(eor)~="table"then return end
        local id=eor.sessionId;local mission=eor.mission
        if type(id)~="string"or id==""or type(mission)~="table"then return end
        local play=seconds(mission.playTimeSeconds)and mission.playTimeSeconds or nil
        local extra=mission.additionalData
        local horde=type(extra)=="table"and extra.hordeData
        local completion=type(horde)=="table"and seconds(horde.completionTime)and horde.completionTime or nil
        if play==nil and completion==nil then return end
        local tracker=api.tracker();local target=tracker.mission;local saved=false
        if not eligible(target)or target.context.mission_instance~=id then target=nil end
        if not target then
            local history=tracker.data and tracker.data.run_history or {}
            for i=#history,1,-1 do local run=history[i]
                if eligible(run)and run.context.mission_instance==id then target=run;saved=true;break end
            end
        end
        if not target and observed_tracker==tracker and eligible(observed)and not observed.history_recorded and observed.context.mission_instance==id then target=observed end
        if not target then return end -- Never guess the latest match for an unmatched/dummy report.
        local d=data(target);local old=d.backend
        if old and old.play_time_seconds==play and old.game_mode_completion_time_seconds==completion then return end
        d.backend={session_id=id,play_time_seconds=play,game_mode_completion_time_seconds=completion,
            source="ProgressionManager._parse_mission_stats:eor.mission",observed_gameplay_seconds=clock("gameplay"),
            observed_main_seconds=clock("main"),observed_collector_seconds=C.clock}
        D.complete(target)
        tracker.dirty=true
        if mod.info then mod:info("I/O mission time: session=%s playTimeSeconds=%s completionTime=%s",id,play and string.format("%.3f",play)or "Not recorded",completion and string.format("%.3f",completion)or "Not recorded")end
        -- spread over frames, as on the End Screen and in the Mourningstar the player is watching, unless another mission is under way
        if saved then api.save(true,not tracker.mission)end
    end
    return D
end
