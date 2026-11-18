-- Native launch/voting boundary. UI layout remains entirely outside this module.
return function(mod, codec, known, callbacks)
    local game = {}
    local registered, tracked_vote = false, nil

    function game.claim_weekly_rewards(done, failed)
        local havoc = Managers.data_service and Managers.data_service.havoc
        if not havoc or type(havoc.get_rewards_if_available) ~= "function" then return false end
        havoc:get_rewards_if_available():next(done):catch(failed)
        return true
    end

    local function allowed()
        local party = Managers.party_immaterium
        local havoc = Managers.data_service and Managers.data_service.havoc
        if not party or not havoc then return false end
        local vote = party:party_vote_state()
        -- The game's own Play button also needs the backend's minimum party size.
        local settings = havoc.get_settings and havoc:get_settings()
        local minimum = type(settings) == "table" and tonumber(settings.min_participants) or 1
        return havoc:can_all_party_members_play_havoc() == true and party:are_all_members_in_hub() == true
            and not (vote and vote.state == "ONGOING") and (minimum <= 1 or #(party:all_members() or {}) >= minimum)
    end
    -- Every current member must be among the ongoing mission's participants, as on the game's Play button.
    local function participants_allowed(participants)
        if type(participants) ~= "table" then return true end
        for _, member in ipairs(Managers.party_immaterium:all_members() or {}) do
            local id, found = member:account_id(), false
            for _, other in ipairs(participants) do if other == id then found = true end end
            if not found then return false end
        end
        return true
    end

    function game.start_own(assignment, current, prepared, voting, failed)
        local havoc = Managers.data_service and Managers.data_service.havoc
        if not havoc then return failed("Havoc service unavailable") end
        local function vote_for(mission)
            if not current() then return failed("launch request no longer current") end
            if not allowed() then return failed("party eligibility changed") end
            if type(mission) ~= "table" or type(mission.id) ~= "string" or mission.id == "" then return failed("activation returned no mission") end
            if not prepared(mission.id) then return failed("launch request no longer current") end
            if not current() then return failed("launch request no longer current") end
            local data = Managers.data_service
            local region = data.region_latency:get_prefered_mission_region()
            voting(mission.id)
            return Managers.party_immaterium:wanted_mission_selected(mission.id, false, region)
        end
        -- The Havoc service turns a backend error into an empty list; the orders interface rejects instead.
        local backend = Managers.backend and Managers.backend.interfaces
        if not backend or not backend.orders then return failed("Havoc service unavailable") end
        return backend.orders:orders_by_order_type("havoc"):next(function(orders)
            if not current() then return failed("launch request no longer current") end
            if not allowed() then return failed("party eligibility refused launch") end
            if type(orders) ~= "table" then return failed("invalid assignment response") end
            local order
            for _, candidate in pairs(orders) do
                if type(candidate) == "table" and candidate.id == assignment.assignment_id then order = candidate; break end
            end
            if not order then return failed("assignment_changed") end
            local fresh, err = codec.from_order(order, known)
            if not fresh then return failed(err) end
            local encoded = codec.encode(fresh, known)
            if not encoded or encoded ~= codec.encode(assignment, known) then return failed("assignment_changed") end
            -- An activated mission stays with the backend until played, so resume it as the Havoc terminal does.
            return havoc:check_ongoing_havoc():next(function(missions)
                if not current() then return failed("launch request no longer current") end
                for _, mission in ipairs(type(missions) == "table" and missions or {}) do
                    if type(mission) == "table" and not mission.depleted then
                        if not participants_allowed(mission.eligibleParticipants) then return failed("party is not eligible for the ongoing mission") end
                        return vote_for({id = mission.id})
                    end
                end
                return havoc:activate_havoc_mission(order.id):next(vote_for)
            end)
        end):catch(failed)
    end

    local function contained(name, fn, ...)
        if not callbacks.active() then return end
        local ok, err = pcall(fn, ...)
        if not ok then mod:error("Havoc %s: %s", name, tostring(err)) end
    end

    local function vote_key(id) return tostring(id):gsub("^immaterium_party:", "") end

    local function havoc_params(params)
        if type(params) ~= "table" or params.qp == "true" or type(params.mission_data) ~= "string" then return false end
        local json = cjson
        if not json or not json.decode then return false end
        local ok, data = pcall(json.decode, params.mission_data)
        return ok and type(data) == "table" and type(data.mission) == "table" and data.mission.category == "havoc"
    end

    function game.install()
        if registered then return true end
        if not mod.hook_require or not mod.hook_safe then return false end
        registered = true
        mod:hook_require("scripts/ui/views/mission_voting_view/mission_voting_view", function(view)
            -- The game requires the view again on each vote, so it is hooked once per load of the mod.
            if view.io_havoc_vote == game then return end
            view.io_havoc_vote = game
            mod:hook_safe(view, "init", function(self, settings, context)
                if callbacks.active() then self._io_havoc_mission_id = context and context.backend_mission_id end
            end)
            mod:hook_safe(view, "on_enter", function(self)
                if callbacks.active() and self._mission_data and self._mission_data.category == "havoc" then
                    contained("prompt", function()
                        tracked_vote = vote_key(self._voting_id)
                        callbacks.prompt(self, self._io_havoc_mission_id, self._voting_started_by_account_id)
                    end)
                end
            end)
            mod:hook_safe(view, "on_exit", function(self) contained("prompt close", callbacks.close_prompt, self) end)
        end)
        mod:hook_require("scripts/settings/voting/voting_templates/mission_vote_matchmaking_immaterium", function(template)
            mod:hook_safe(template, "on_started", function(id, _, params)
                contained("vote start", function() if havoc_params(params) then tracked_vote = vote_key(id) end end)
            end)
            mod:hook_safe(template, "on_completed", function(id, _, state, result)
                contained("vote completion", function()
                    if tracked_vote == vote_key(id) or havoc_params(state and state.params) then
                        tracked_vote = nil
                        callbacks.finished(result == "approved")
                    end
                end)
            end)
            mod:hook_safe(template, "on_aborted", function(id, _, params)
                contained("vote abort", function()
                    if tracked_vote == vote_key(id) or havoc_params(params) then
                        tracked_vote = nil
                        callbacks.finished(false)
                    end
                end)
            end)
        end)
        return true
    end

    function game.clear() tracked_vote = nil end
    return game
end
