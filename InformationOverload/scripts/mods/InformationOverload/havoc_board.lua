-- Integrated Havoc service and local-history projection for the I/O frontend.
return function(mod, api, ports)
    local base = "InformationOverload/scripts/mods/InformationOverload/"
    local service = mod:io_dofile(base .. "havoc_board_runtime")(mod, ports)
    local history_modules
    local function ensure() return service.get_state() end
    local function catalog() return service.catalog() end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = copy(item) end
        return result
    end
    -- On-demand projection. Reuse normal history eligibility, identity and timing rules.
    -- All figures are the viewer's own Havoc history, across ranks and modifiers.
    function service.records(map)
        local state, reason = ensure()
        if not state then return nil, reason end
        if type(map) ~= "string" or not catalog().maps[map] then return nil, "unknown map" end
        local tracker = api.dashboard_tracker()
        if not tracker or not tracker.data then return nil, "history unavailable" end
        if not history_modules then
            history_modules = {
                overview = mod:io_dofile(base .. "io_overview"),
                records = mod:io_dofile(base .. "records"),
                times = mod:io_dofile(base .. "mission_times"),
                identity = mod:io_dofile(base .. "player_identity"),
            }
        end
        local Overview, Records = history_modules.overview, history_modules.records
        local Times, Identity = history_modules.times, history_modules.identity
        Identity.learn(tracker.data)
        local result = {runs = 0, wins = 0, losses = 0, teammates = {}, scope = {mode = "havoc", map = map, ranks = "all", modifiers = "all"}}
        for id in pairs(state.members) do
            if id ~= state.myself then result.teammates[id] = {wins = 0, losses = 0} end
        end
        local history = {}
        for _, run in ipairs(tracker.data.run_history or {}) do
            local context = run.context
            if context and context.mode == "havoc" and context.mission_name == map and Overview.accepted(run) then
                history[#history + 1] = run
                result.runs = result.runs + 1
                local outcome = run.victory and "wins" or "losses"
                result[outcome] = result[outcome] + 1
                local damage = Records.run_useful(run)
                if damage and (not result.best_damage or damage > result.best_damage) then result.best_damage = damage end
                local seen = {}
                -- The oldest matches name teammates by account only, as the rest of the mod counts them.
                for _, set in ipairs({context.operative_roster or {}, Identity.team_accounts(tracker.data, context)}) do
                    for _, person in pairs(set) do
                        if type(person) == "table" and not person.personal then
                            for id in pairs(result.teammates) do
                                local identity = Identity.key({account_id = id})
                                if not seen[id] and Identity.matches(person, identity) then
                                    seen[id] = true
                                    result.teammates[id][outcome] = result.teammates[id][outcome] + 1
                                end
                            end
                        end
                    end
                end
            end
        end
        if result.runs > 0 then result.win_rate = result.wins / result.runs end
        local options = mod.io_display_options and mod.io_display_options() or {}
        local timing = Times.build(history, "havoc", options.boss_map_timing and "boss" or "victory")
        local best
        for _, maps in pairs(timing) do
            local run = maps[map]
            if run and (not best or Times.faster(run, best)) then best = run end
        end
        if best then result.best_clear = copy(best.completion_time) end
        return result
    end

    service.api.records = service.records
    return service
end
