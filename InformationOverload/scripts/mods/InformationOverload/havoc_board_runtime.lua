-- Owns Havoc exchange, launch requests and voting lifecycle. No history or UI layout.
return function(mod, ports)
    local base = "InformationOverload/scripts/mods/InformationOverload/"
    local State = mod:io_dofile(base .. "havoc_board_state")
    local Codec = mod:io_dofile(base .. "havoc_assignment_codec")
    local Protocol = mod:io_dofile(base .. "havoc_board_protocol")
    ports = ports or {}
    local transport = ports.transport or mod:io_dofile(base .. "havoc_board_transport")(mod, Protocol)
    local service, K = {}, Protocol.fields
    local PASSING = {matchmaking = true, cinematic = true}
    local board, game, pending, event_manager, session, origin, scope, known
    local active, generation, elapsed, fetch_elapsed, useful = false, 0, 2, 30, false
    local assignment_status, shared, last_error, wire_error = "unknown", nil, nil, nil
    local slots, index, peers, replies, handled, beats = {}, {}, {}, {}, {}, {}
    local retired, availability, lost, clocks, request_sequence, refresh_sequence, last_beat = {}, {}, {}, {}, 0, 0, 0
    local launch, owner_launch, attempt, prompt, wire_request
    local peer_refresh, after_vote = false, nil
    -- when the roster last went missing: the game drops it for a moment; and each teammate's tile carried over a leave, by when
    local roster_gap, carried_at = nil, {}
    local rewards_visit, rewards_pending, gameplay = false, nil, nil
    local publish, sync_peers, process_requests, check_prompt, get_game

    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = copy(item) end
        return result
    end
    local function now()
        if ports.clock then return ports.clock() end
        local system = Mods and Mods.lua and Mods.lua.os or os
        return system.time()
    end
    -- Settings › Havoc Board holds these switches, each on until it is turned off.
    -- Not enable_havoc_board: builds with the board off by default saved that one as false.
    -- the board runs only while the Havoc screen it belongs to is on, as every screen's settings do
    local function enabled() return mod:is_enabled() and mod:get("havoc_board") ~= false and mod:get("screen_havoc") ~= false end
    -- With no room left in your presence, teammates cannot read your board, so nothing of yours reaches them.
    local function presence_full() return transport.full ~= nil and transport.full() == true end
    -- Nor while the game's presence code has changed under the board.
    local function presence_changed() return transport.changed ~= nil and transport.changed() == true end
    local function remote_allowed() return mod:get("havoc_allow_remote_start") ~= false end
    -- off until turned on
    local function auto_claim() return mod:get("havoc_auto_claim") == true end
    local function catalog()
        if not known then
            known = ports.known or {
                maps = require("scripts/settings/mission/mission_templates"),
                modifiers = require("scripts/settings/circumstance/circumstance_templates"),
            }
        end
        return known
    end
    service.catalog = catalog

    local function roster()
        if ports.roster then return ports.roster() end
        local party = Managers.party_immaterium
        local myself = party and party:get_myself()
        if not myself then return end
        local my_id = myself:account_id()
        if type(my_id) ~= "string" or my_id == "" then return end
        -- The game reports "" until the party connection exists.
        local party_id = party:party_id()
        if type(party_id) ~= "string" or party_id == "" then return end
        local members = {}
        for _, member in ipairs(party:all_members() or {}) do
            local id = member:account_id()
            if type(id) ~= "string" or id == "" then return end
            local profile = member:profile()
            members[id] = {
                name = member:name(), class = profile and profile.archetype and profile.archetype.name,
                character = profile and profile.character_id, activity = member:presence_name(), havoc_status = member:havoc_status(),
            }
        end
        return my_id, party_id, members
    end

    local function clear()
        generation = generation + 1
        board, pending, session, origin, scope, last_error, wire_error, shared = nil, nil, nil, nil, nil, nil, nil, nil
        slots, index, peers, replies, handled, retired, availability, lost, clocks, beats = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
        launch, owner_launch, attempt, prompt, wire_request = nil, nil, nil, nil, nil
        carried_at = {}
        assignment_status, elapsed, fetch_elapsed, refresh_sequence, peer_refresh, useful, last_beat = "unknown", 2, 30, 0, false, false, 0
        if game and game.clear then game.clear() end
        transport.publish({})
    end

    -- each reset of a board in use goes to the log with its reason, so a report says which one it was
    local function reset_note(reason) if board and mod.info then pcall(mod.info, mod, "Havoc board reset: %s", reason) end end
    -- A teammate who leaves takes only their own tile and votes, and one who joins starts with none: what the others had is carried onto the fresh board and shown
    -- while each teammate reconnects, up to LIVE seconds, then their own frames take over.
    local function carry_over(old, members)
        for owner, wanted in pairs(old.outgoing) do if members[owner] then board.outgoing[owner] = copy(wanted) end end
        for owner, assignment in pairs(old.held) do if members[owner] then board.held[owner] = copy(assignment) end end
        for owner, map in pairs(old.maps) do
            if members[owner] then
                local votes = {}
                for id in pairs(members) do votes[id] = map.votes[id] or 0 end
                board.maps[owner] = {assignment = copy(map.assignment), votes = votes}
                if owner ~= board.myself then board.held[owner], board.ready[owner], carried_at[owner] = copy(map.assignment), old.ready[owner] or 0, now() end
            end
        end
        board:emit("publish_own", {}); board:emit("publish_ready", {value = board:own_ready()})
    end
    local function synchronize()
        local myself, party, members = roster()
        -- Only drop a board that exists, so polling the API meanwhile leaves the update timer alone.
        -- A roster the game cannot read for a moment keeps the board for ten seconds before it is dropped.
        if not myself or not party or not members or not members[myself] then
            if board then
                roster_gap = roster_gap or now()
                if now() - roster_gap < 10 then return board end
                reset_note("roster unreadable for ten seconds")
                clear()
            end
            roster_gap = nil
            return nil, "strike team unavailable"
        end
        roster_gap = nil
        local next_slots, signature = {}, {}
        for id in pairs(members) do next_slots[#next_slots + 1] = id end
        table.sort(next_slots)
        if #next_slots > 4 then if board then clear() end; return nil, "strike team exceeds four members" end
        -- The party id and the accounts make the scope, so the scope alone tells another party or roster apart. Characters are left
        -- out: the assignment is the account's, and a character swapped or dropped for a moment must not start the board over.
        signature[1] = party
        for _, id in ipairs(next_slots) do signature[#signature + 1] = id end
        local next_scope = Protocol.digest(table.concat(signature, "|"))
        -- A PC clock belongs to a session: one stepped back would freeze the beat, so it starts a new session.
        if origin and math.floor(now()) - origin < last_beat - 10 then clear() end
        local carried
        if board and board.myself == myself and board.party == party and scope ~= next_scope then
            carried = board
        end
        if not board or board.myself ~= myself or board.party ~= party or scope ~= next_scope then
            reset_note(board and (board.party ~= party and "another party" or board.myself ~= myself and "another account" or "a teammate joined or left, the rest kept") or "")
            clear()
            board, scope, slots = State.new(myself), next_scope, next_slots
            -- A session is the second it began, never repeated by this client, so it needs no random part.
            local start = math.max(math.floor(now()) - Protocol.EPOCH, (mod.io_havoc_session_last or -1) + 1, 0)
            mod.io_havoc_session_last = start
            -- the beat counts from this clock even when the session id had to run ahead of it
            session, origin = Protocol.base36(start, 6), math.floor(now())
            for i, id in ipairs(slots) do index[id] = i end
        end
        -- Nothing on the board works unless you are in the hub with a teammate who is too, so only then does it send. Matchmaking
        -- and a cutscene are spent standing in the hub and pass, so they keep a board that sends going but never start one.
        -- After an approved vote your presence still reads "hub" for a moment before the matchmaking, so the board the vote cleared
        -- stays quiet until you have been out of the hub and come back (a matchmaking called off), or a minute has gone by.
        local kept, own = useful, members[myself].activity
        useful = false
        if after_vote then
            if own ~= "hub" then after_vote.away = true elseif after_vote.away or now() - after_vote.at >= 60 then after_vote = nil end
        end
        if not after_vote and (own == "hub" or kept and PASSING[own]) then
            for id, member in pairs(members) do useful = useful or id ~= myself and (member.activity == "hub" or PASSING[member.activity] == true) end
        end
        board:set_party(party, members)
        if carried then carry_over(carried, members) end
        board:drain_actions()
        return board
    end

    function service.party_changed() after_vote = nil; if active then clear() end end
    function service.game_state_changed(status, state)
        if state ~= "StateGameplay" then return end
        if status == "enter" then gameplay = true; elapsed = 2
        elseif status == "exit" then gameplay = false; rewards_visit = false; service.party_changed() end
    end
    function service.roster_changed()
        if not active then return end
        local ok, err = pcall(synchronize)
        if not ok then clear(); last_error = tostring(err) end
    end
    local events = {party_immaterium_joined = "party_changed", party_immaterium_other_members_updated = "roster_changed"}
    local function bind_events()
        local manager = ports.event_manager or Managers.event
        if manager == event_manager then return end
        if event_manager then for name in pairs(events) do pcall(function() event_manager:unregister(service, name) end) end end
        event_manager = manager
        if manager then for name, method in pairs(events) do manager:register(service, name, method) end end
    end
    function service.stop()
        active = false
        rewards_visit, rewards_pending, gameplay = false, nil, nil
        if event_manager then
            -- on quitting the game the event manager is destroyed before mods unload, so its calls may throw
            for name in pairs(events) do pcall(function() event_manager:unregister(service, name) end) end
            event_manager = nil
        end
        clear()
        after_vote = nil
        transport.stop()
    end
    local function ensure()
        if not enabled() then
            if active then service.stop() end
            return nil, "Havoc board disabled"
        end
        if not active then active = true; clear() end
        bind_events()
        transport.start()
        get_game().install()
        return synchronize()
    end
    service.get_state = ensure

    local EMPTY = Protocol.digest("")
    local function own_wire()
        local map = board and board.maps[board.myself]
        if not map then return "", EMPTY end
        local raw, err = Codec.encode(map.assignment, catalog())
        if not raw then wire_error = err; return "", EMPTY end
        return raw, Protocol.digest(raw)
    end
    -- The party is shown the last settled status, so a refresh under way sends nothing.
    local function settle(status)
        assignment_status = status
        if status ~= "loading" then shared = status end
    end
    local function request_frame(r) return {owner = r.owner, ack = r.ack, assignment = r.assignment, id = r.id, expires = r.expires - origin} end
    local function attempt_frame(a)
        return {requester = a.requester, ack = a.ack, assignment = a.assignment, mission = a.mission, id = a.id, expires = a.expires - origin}
    end

    publish = function()
        -- Quiet, the value is emptied once and then nothing more goes out.
        if not board or not session or not useful then return transport.publish({}) end
        -- A new session waits for its first fetch to settle, so its first send is whole.
        if not shared then return end
        local raw = own_wire()
        last_beat = math.max(last_beat, math.floor(now()) - origin, 0)
        local values = {[K.assignment] = raw, [K.beat] = Protocol.encode("B", {beat = last_beat})}
        local function put(key, kind, frame)
            local encoded, err = Protocol.encode(kind, frame)
            if not encoded then wire_error = err; return false end
            values[key] = encoded
            return true
        end
        local own, votes = board.maps[board.myself], 0
        for i = 1, 4 do if own and slots[i] and own.votes[slots[i]] == 1 then votes = votes + 2 ^ (i - 1) end end
        if not put(K.meta, "M", {scope = scope, session = session, status = shared, remote = remote_allowed() and 1 or 0})
            or not put(K.votes, "V", {votes = votes, refresh = refresh_sequence % 36}) then return end
        for id, peer in pairs(peers) do
            local wanted = board.outgoing[id]
            local value = wanted and board.maps[id] and wanted.assignment_id == board.maps[id].assignment.assignment_id and wanted.value or 0
            if not put(K["peer" .. index[id]], "P", {ack = peer.session, vote = value, target = peer.digest}) then return end
        end
        if wire_request and not put(K.request, "Q", request_frame(wire_request)) then return end
        if attempt and not put(K.attempt, "A", attempt_frame(attempt)) then return end
        -- Nobody reads a reply to yourself, so none is sent.
        for id, reply in pairs(replies) do
            if index[id] and id ~= board.myself and not put(K["reply" .. index[id]], "R", reply) then return end
        end
        local ok, err = transport.publish(values)
        if not ok then wire_error = err end
    end

    local function fetch(done, failed)
        if ports.fetch then return ports.fetch(done, failed) end
        -- The Havoc service turns a backend error into an empty list; the orders interface rejects instead.
        local backend = Managers.backend and Managers.backend.interfaces
        local orders = backend and backend.orders
        if not orders then return failed("Havoc service unavailable") end
        return orders:orders_by_order_type("havoc"):next(done):catch(failed)
    end
    function service.refresh(broadcast)
        local state, reason = ensure()
        if not state then return nil, reason end
        if pending then return true, "assignment refresh pending" end
        if broadcast ~= false then refresh_sequence = refresh_sequence + 1 end
        local request = {generation = generation, age = 0}
        pending, fetch_elapsed = request, 0
        settle("loading")
        local function current()
            if not active or not enabled() or pending ~= request or generation ~= request.generation then return false end
            return synchronize() == state and pending == request
        end
        local function failed(err)
            if not current() then return end
            pending, last_error = nil, tostring(err)
            settle("failed")
            publish()
        end
        local function received(orders)
            if not current() then return end
            if type(orders) ~= "table" then return failed("invalid assignment response") end
            local assignment, rejected
            for _, order in pairs(orders) do
                local candidate, err = Codec.from_order(order, catalog())
                -- An unusable order is skipped; the refresh fails only when nothing usable remains.
                if not candidate then rejected = rejected or err
                elseif not assignment or candidate.rank > assignment.rank or candidate.rank == assignment.rank and candidate.assignment_id < assignment.assignment_id then assignment = candidate end
            end
            if not assignment and rejected then return failed(rejected) end
            if assignment then
                local raw, err = Codec.encode(assignment, catalog())
                if not raw then return failed(err) end
            end
            local ok, err = state:receive_assignment(state.myself, assignment)
            if not ok then return failed(err) end
            pending, last_error = nil, nil
            settle(assignment and "available" or "none")
            publish()
        end
        publish()
        local ok, err = pcall(fetch, received, failed)
        if not ok then failed(err) end
        return ok, err
    end

    local function forget_peer(id)
        -- a tile carried over a leave stays while its teammate reconnects
        if carried_at[id] then if now() - carried_at[id] < Protocol.LIVE then return end; carried_at[id] = nil end
        board:lapse(id)
        if board.consent and board.consent.owner == id then board.consent = nil end
    end
    -- Losing one peer forgets only that peer, keeping your vote on its assignment; the next handshake brings it back.
    -- A start in flight keeps its consent, since the owner may only have lapsed; its own expiry ends a real loss.
    local function lose_peer(id, previous)
        local consent = board.consent
        forget_peer(id)
        board.consent = consent
        peers[id], lost[id] = nil, previous.session
    end
    -- Peer timestamps are judged by that session's clock offset, the smallest gap seen between our clock and its beat.
    -- The two PC clocks need not agree, and an old snapshot first seen late still reads as expired.
    local function remaining(id, expires)
        if id == board.myself then return expires - now() end
        local peer, clock = peers[id], clocks[id]
        if not peer or not clock or clock.session ~= peer.session then return 0 end
        return expires - (now() - clock.offset)
    end
    -- Once a session's beat has been seen to move on, it is live while it last did so within LIVE seconds by our own clock, which
    -- needs no agreement between the two clocks. Until then its beat must be within STALE seconds of our clock. A beat never goes back.
    local function beat_of(id, meta, raw)
        local frame = Protocol.decode("B", raw[K.beat])
        if not frame then return end
        local beat, seen = Protocol.base(meta.session) + frame.beat, beats[id]
        if not seen or seen.session ~= meta.session then seen = {session = meta.session, beat = beat}; beats[id] = seen
        elseif beat < seen.beat then return
        elseif beat > seen.beat then seen.beat, seen.at = beat, now() end
        if seen.at then return now() - seen.at <= Protocol.LIVE and beat or nil end
        return beat >= now() - Protocol.STALE and beat <= now() + 30 and beat or nil
    end
    local function bit(mask, i) return math.floor(mask / 2 ^ (i - 1)) % 2 end
    -- Readiness is a vote that still stands, and every vote is on the wire: on your own map among your map's votes, on the others in the peer frames.
    local function ready_of(raw, votes, slot)
        if bit(votes, slot) == 1 then return 1 end
        for i = 1, 4 do
            local pair = i ~= slot and Protocol.decode("P", raw[K["peer" .. i]])
            if pair and pair.vote == 1 then return 1 end
        end
        return 0
    end
    sync_peers = function()
        local incoming = transport.read()
        local my_raw, my_digest = own_wire()
        for _, id in ipairs(slots) do if id ~= board.myself then
            local raw = incoming[id] or {}
            local meta = Protocol.decode("M", raw[K.meta])
            local previous = peers[id]
            local beat = meta and meta.scope == scope and beat_of(id, meta, raw)
            if beat then
                local history = retired[id] or {}
                retired[id] = history
                local old = false
                for _, value in ipairs(history) do if value == meta.session then old = true end end
                -- A peer that went stale and returns under a new session retires the one it left with.
                -- A retired session showing meanwhile leaves that alone.
                if not old and not previous and lost[id] then
                    if lost[id] ~= meta.session then
                        history[#history + 1] = lost[id]
                        if #history > 16 then table.remove(history, 1) end
                    end
                    lost[id] = nil
                end
                if not old then
                    local clock = clocks[id]
                    local gap = now() - beat
                    if not clock or clock.session ~= meta.session then clock = {session = meta.session, offset = gap, beat = beat}; clocks[id] = clock end
                    -- Two fresh beats in a row further behind than any delivery delay mean our own clock stepped forward;
                    -- one alone is a snapshot first seen late.
                    if beat > clock.beat then
                        local high = gap > clock.offset + 30 and gap or nil
                        if high and clock.high then clock.offset = math.min(high, clock.high) end
                        clock.high = high
                    end
                    clock.offset, clock.beat = math.min(clock.offset, gap), beat
                    if previous and previous.session ~= meta.session then
                        history[#history + 1] = previous.session
                        if #history > 16 then table.remove(history, 1) end
                        forget_peer(id)
                        previous = nil
                    end
                    local peer = previous or {session = meta.session}
                    local tally = Protocol.decode("V", raw[K.votes])
                    if previous and tally and previous.refresh ~= tally.refresh then peer_refresh = true end
                    peer.refresh = tally and tally.refresh or peer.refresh
                    -- The frames of one value arrive together, so its map and meta always agree. Too long a value is refused unhashed.
                    local value = raw[K.assignment] or ""
                    peer.meta, peer.raw, peer.synced, peer.status = meta, raw, false, "handshake"
                    peer.digest = #value <= Codec.MAX_BYTES and Protocol.digest(value) or nil
                    availability[id] = "handshake"
                    peers[id] = peer
                    local pair = Protocol.decode("P", raw[K["peer" .. index[board.myself]]])
                    if pair and pair.ack == session then
                        local assignment, valid = nil, value == ""
                        if value ~= "" and peer.digest then
                            assignment = Codec.decode(value, catalog())
                            valid = assignment ~= nil
                        end
                        if valid and tally and (assignment or meta.status ~= "available") then
                            local votes = {}
                            for i, member in ipairs(slots) do votes[member] = bit(tally.votes, i) end
                            board:receive_assignment(id, assignment, votes)
                            board:receive_ready(id, ready_of(raw, tally.votes, index[id]))
                            -- A vote counts only on the assignment it names. No vote needs no name: it is how a vote taken back reaches the owner.
                            if my_raw ~= "" and (pair.vote == 0 or pair.target == my_digest) then
                                board:receive_vote(id, {recipient = board.myself, assignment_id = board.maps[board.myself].assignment.assignment_id, value = pair.vote})
                            end
                            peer.synced, peer.status, carried_at[id] = true, "ready", nil
                        else peer.status = "invalid" end
                    end
                    if not peer.synced then forget_peer(id) end
                elseif previous then
                    -- A retired session showing again leaves this peer unavailable until its current one returns.
                    lose_peer(id, previous)
                    availability[id] = "stale"
                end
            else
                if previous then lose_peer(id, previous) end
                peers[id] = nil
                availability[id] = meta and "stale" or raw[K.meta] and raw[K.meta] ~= "" and "incompatible" or "unknown"
            end
        end end
        board:drain_actions()
    end

    local function eligibility(owner, assignment_id, request_id)
        local state, reason = ensure()
        if not state then return {allowed = false, reason = reason, blockers = {}} end
        local blockers = {}
        for id, member in pairs(state.members) do
            if member.havoc_status ~= "ok" then blockers[#blockers + 1] = {account_id = id, reason = member.havoc_status or "unknown_havoc_status"} end
            local hub = member.activity == "hub" or id ~= state.myself and member.activity == "training_grounds"
            if not hub then blockers[#blockers + 1] = {account_id = id, reason = member.activity or "unknown_activity"} end
        end
        table.sort(blockers, function(a, b) if a.account_id == b.account_id then return a.reason < b.reason end; return a.account_id < b.account_id end)
        local vote
        if ports.vote_state then vote = ports.vote_state()
        else local party = Managers.party_immaterium; vote = party and party:party_vote_state() end
        if vote and vote.state == "ONGOING" then blockers[#blockers + 1] = {reason = "mission_vote_ongoing"} end
        -- The game's own Play button also needs the backend's minimum party size.
        local settings, count = nil, 0
        if ports.havoc_settings then settings = ports.havoc_settings()
        else local havoc = Managers.data_service and Managers.data_service.havoc; settings = havoc and havoc.get_settings and havoc:get_settings() end
        for _ in pairs(state.members) do count = count + 1 end
        if type(settings) == "table" and count < (tonumber(settings.min_participants) or 1) then blockers[#blockers + 1] = {reason = "party_too_small"} end
        local outgoing = launch and launch.id ~= request_id and (launch.status == "requesting" or launch.status == "accepted" or launch.status == "voting")
        if owner_launch or outgoing then blockers[#blockers + 1] = {reason = "launch_in_progress"} end
        if owner and owner ~= state.myself and presence_full() then blockers[#blockers + 1] = {reason = "presence_full"} end
        if owner and owner ~= state.myself and presence_changed() then blockers[#blockers + 1] = {reason = "presence_changed"} end
        if owner then
            local map = state.maps[owner]
            local peer = peers[owner]
            if not map or assignment_id and map.assignment.assignment_id ~= assignment_id then
                blockers[#blockers + 1] = {account_id = owner, reason = "assignment_unavailable"}
            elseif owner ~= state.myself and (not peer or not peer.synced) then
                blockers[#blockers + 1] = {account_id = owner, reason = "owner_unavailable"}
            elseif owner ~= state.myself and peer.meta.remote ~= 1 then
                blockers[#blockers + 1] = {account_id = owner, reason = "remote_start_disabled"}
            elseif owner ~= state.myself and map.votes[owner] ~= 1 then
                -- The owner starts the vote and the game counts their Yes without a prompt, so their own vote is their consent.
                blockers[#blockers + 1] = {account_id = owner, reason = "owner_not_voted"}
            end
        end
        return {allowed = #blockers == 0, start_available = get_game().install(), blockers = blockers}
    end
    function service.eligibility(owner, assignment_id) return eligibility(owner, assignment_id) end

    local function reply_to(sender, request, status)
        replies[sender] = {ack = request.session, status = status, id = request.id}
        if sender == board.myself and launch and launch.id == request.session .. "_" .. request.id then
            launch.status = status
            if status ~= "accepted" and status ~= "voting" then board.consent = nil end
        end
        publish()
    end
    local function begin_launch(sender, request, deadline)
        if owner_launch then reply_to(sender, request, "busy"); return end
        local own = board.maps[board.myself]
        local _, digest = own_wire()
        if not own or digest ~= request.assignment then
            reply_to(sender, request, "changed"); peer_refresh = true; return
        end
        -- The owner becomes the vote initiator and the game counts their Yes without a prompt, so a remote start needs
        -- the owner's own vote on this map. A start of one's own is an explicit choice and needs none.
        if sender ~= board.myself and (not remote_allowed() or own.votes[board.myself] ~= 1)
            or not eligibility(nil, nil, request.session .. "_" .. request.id).allowed then reply_to(sender, request, "denied"); return end
        local state, epoch = board, generation
        local operation = {sender = sender, request = request, age = 0, status = "accepted"}
        deadline = deadline or request.expires
        owner_launch = operation
        reply_to(sender, request, "accepted")
        local function current()
            if not active or not enabled() or owner_launch ~= operation or generation ~= epoch or now() > deadline then return false end
            if synchronize() ~= state then return false end
            local map = state.maps[state.myself]
            if not map then return false end
            local _, current_digest = own_wire()
            if current_digest ~= request.assignment then return false end
            if sender ~= state.myself then
                local peer = peers[sender]
                if not peer or not peer.synced or peer.session ~= request.session or not remote_allowed()
                    or map.votes[state.myself] ~= 1 then return false end
            end
            return true
        end
        local function failed(reason)
            if owner_launch ~= operation then return end
            owner_launch, attempt = nil, nil
            local status = reason == "assignment_changed" and "changed" or "failed"
            if launch and launch.id == request.session .. "_" .. request.id then launch.reason = tostring(reason) end
            reply_to(sender, request, status)
            peer_refresh = status == "changed" or peer_refresh
        end
        local function prepared(mission_id)
            if not current() then return false end
            local next_attempt = {requester = index[sender], ack = request.session, id = request.id, assignment = request.assignment,
                mission = type(mission_id) == "string" and Protocol.digest(mission_id), expires = now() + 60}
            local encoded, err = Protocol.encode("A", attempt_frame(next_attempt))
            if not encoded then failed(err); return false end
            attempt = next_attempt
            publish()
            transport.update(2)
            return true
        end
        local function voting(mission_id)
            operation.status, operation.mission_id = "voting", mission_id
            reply_to(sender, request, "voting")
        end
        local ok, err = pcall(get_game().start_own, copy(own.assignment), current, prepared, voting, failed)
        if not ok then failed(err) end
    end

    process_requests = function()
        for _, id in ipairs(slots) do
            local peer = peers[id]
            if peer and peer.synced then
                local request = Protocol.decode("Q", peer.raw[K.request])
                if request and request.owner == index[board.myself] and request.ack == session then
                    local sequence, old = request.id, handled[id]
                    if sequence >= 1 and sequence <= 999999999 and (not old or old.session ~= peer.session or sequence > old.sequence) then
                        handled[id] = {session = peer.session, sequence = sequence}
                        request.session, request.expires = peer.session, Protocol.base(peer.session) + request.expires
                        local left = remaining(id, request.expires)
                        if left > 0 and left <= 45 then begin_launch(id, request, now() + left) else reply_to(id, request, "expired") end
                    end
                end
                if launch and launch.owner == id then
                    local response = Protocol.decode("R", peer.raw[K["reply" .. index[board.myself]]])
                    if response and response.ack == session and session .. "_" .. response.id == launch.id then
                        launch.status = response.status
                        if response.status ~= "accepted" and response.status ~= "voting" then board.consent, wire_request = nil, nil end
                    end
                end
            end
        end
    end

    function service.start(owner, assignment_id)
        local state, reason = ensure()
        if not state then return nil, reason end
        if not owner or not assignment_id then return nil, "owner and assignment ID required" end
        if not get_game().install() then return nil, "game voting hooks unavailable" end
        if launch and (launch.status == "requesting" or launch.status == "accepted" or launch.status == "voting") then return nil, "launch already in progress" end
        local map = state.maps[owner]
        if not map or map.assignment.assignment_id ~= assignment_id then return nil, "assignment changed or unavailable" end
        if not eligibility(owner, assignment_id).allowed then return nil, "strike-team launch blocked" end
        local peer = peers[owner]
        if owner ~= state.myself and (not peer or not peer.synced or peer.meta.remote ~= 1) then return nil, "owner is unavailable or declines remote starts" end
        local consent, err = state:prepare_start(owner, now())
        if not consent then return nil, err end
        request_sequence = request_sequence + 1
        local id = session .. "_" .. request_sequence
        state.consent.attempt = id
        local raw = Codec.encode(map.assignment, catalog())
        if not raw then state.consent = nil; return nil, "assignment cannot be shared" end
        local request = {session = session, owner = index[owner], ack = owner == state.myself and session or peer.session,
            assignment = Protocol.digest(raw), id = request_sequence, expires = now() + 30}
        local encoded, why = Protocol.encode("Q", request_frame(request))
        if not encoded then state.consent = nil; return nil, why end
        launch = {id = id, owner = owner, assignment_id = assignment_id, status = "requesting", expires = request.expires}
        if owner == state.myself then begin_launch(state.myself, request) else wire_request = request; publish() end
        return true, id
    end

    function service.vote(owner, value, assignment_id)
        local state, reason = ensure()
        if not state then return nil, reason end
        local map = state.maps[owner]
        if assignment_id and (not map or map.assignment.assignment_id ~= assignment_id) then return nil, "assignment changed" end
        if owner ~= state.myself and (not peers[owner] or not peers[owner].synced) then return nil, "assignment owner unavailable" end
        local ok, err = state:request_vote(owner, value)
        state:drain_actions()
        -- A vote decides an open prompt, so one cast while it is open answers it at once.
        if ok then publish(); check_prompt() end
        return ok, err
    end

    local function correlated_attempt(owner, mission_id)
        local candidate, digest
        if owner == board.myself then candidate, digest = attempt, select(2, own_wire())
        else
            local peer = peers[owner]
            if not peer or not peer.synced then return end
            candidate = Protocol.decode("A", peer.raw[K.attempt])
            if not candidate then return end
            candidate.expires, digest = Protocol.base(peer.session) + candidate.expires, peer.digest
        end
        if not candidate then return end
        local requester = slots[candidate.requester]
        local requester_session = requester == board.myself and session or peers[requester] and peers[requester].session
        local map = board.maps[owner]
        local left = remaining(owner, candidate.expires)
        if requester_session ~= candidate.ack or left <= 0 or left > 75 or not map or candidate.assignment ~= digest then return end
        if type(mission_id) ~= "string" or candidate.mission ~= Protocol.digest(mission_id) then return nil, "different_mission" end
        return {assignment_id = map.assignment.assignment_id, id = candidate.ack .. "_" .. candidate.id}
    end
    check_prompt = function()
        if not prompt or not board or prompt.view._has_voted or prompt.attempted then return end
        local found, mismatch = correlated_attempt(prompt.owner, prompt.mission_id)
        local consent = board.consent
        -- The normal vote can reach the requester before the owner's presence
        -- advertisement. Keep that prompt manual while correlation catches up.
        if not found and mismatch ~= "different_mission" and consent and consent.owner == prompt.owner
            and consent.expires >= now() and launch and launch.id == consent.attempt then return end
        local decision = board:prompt_decision("havoc", found and prompt.owner, found and found.assignment_id, found and found.id, now())
        -- Prompts are only ever accepted for the player; everything else stays the game's normal prompt.
        if decision ~= "yes" then return end
        prompt.attempted = true
        local ok, err
        if ports.cast_prompt then ok, err = pcall(ports.cast_prompt, prompt.view, decision)
        else ok, err = pcall(prompt.view.cb_on_accept_mission_pressed, prompt.view) end
        if not ok then last_error = tostring(err) end
    end
    function service.prompt(view, mission_id, owner)
        if not ensure() then return end
        prompt = {view = view, mission_id = mission_id, owner = owner}
        check_prompt()
    end
    function service.close_prompt(view) if prompt and prompt.view == view then prompt = nil end end
    function service.finished(approved)
        if not active or not board then return end
        if approved then
            clear()
            after_vote = {at = now()}
        else
            board:attempt_finished(false)
            if owner_launch then reply_to(owner_launch.sender, owner_launch.request, "rejected") end
            owner_launch, attempt, wire_request, prompt = nil, nil, nil, nil
            if launch then launch.status = "rejected" end
            publish()
        end
    end
    get_game = function()
        if not game then
            game = ports.game or mod:io_dofile(base .. "havoc_board_game")(mod, Codec, catalog(), {
                active = function() return active and enabled() end,
                prompt = service.prompt, close_prompt = service.close_prompt, finished = service.finished,
            })
        end
        return game
    end

    local function claim_weekly_rewards(state)
        if gameplay == false or state.members[state.myself].activity ~= "hub" then rewards_visit = false; return end
        -- Turned on again in the hub, it claims on that visit.
        if rewards_visit or not auto_claim() then return end
        if rewards_pending then rewards_visit = true; return end
        local claim = get_game().claim_weekly_rewards
        if not claim then return end
        local request = {age = 0}
        rewards_pending = request
        local function completed()
            if rewards_pending == request then rewards_pending = nil end
        end
        local function failed(reason)
            if rewards_pending ~= request then return end
            completed()
            mod:error("Havoc weekly reward sync failed: %s", tostring(reason))
        end
        local ok, started = pcall(claim, completed, failed)
        if not ok then rewards_visit = true; failed(started)
        elseif started then rewards_visit = true
        else completed() end
    end

    function service.update(dt)
        if not enabled() then if active then service.stop() end; return end
        if rewards_pending then
            rewards_pending.age = rewards_pending.age + dt
            if rewards_pending.age >= 30 then rewards_pending = nil; mod:error("Havoc weekly reward sync timed out") end
        end
        elapsed, fetch_elapsed = elapsed + dt, fetch_elapsed + dt
        if pending then
            pending.age = pending.age + dt
            if pending.age >= 30 then pending, last_error, fetch_elapsed = nil, "assignment refresh timed out", 0; settle("failed") end
        end
        if owner_launch then
            owner_launch.age = owner_launch.age + dt
            local limit = owner_launch.status == "voting" and 90 or 30
            if owner_launch.age >= limit then
                local operation = owner_launch
                owner_launch, attempt = nil, nil
                if board then reply_to(operation.sender, operation.request, "expired") end
            end
        end
        if launch and launch.status ~= "voting" and now() > launch.expires and (launch.status == "requesting" or launch.status == "accepted") then
            launch.status, wire_request = "expired", nil
            if board then board.consent = nil end
        end
        if elapsed >= 2 then
            -- Reset before as well, so a poll that raises still waits; clear() inside ensure() sets it to 2.
            elapsed = 0
            local state = ensure()
            elapsed = 0
            if not state then return end
            claim_weekly_rewards(state)
            sync_peers()
            for id, at in pairs(carried_at) do if now() - at >= Protocol.LIVE then forget_peer(id) end end
            -- Quiet, the board asks nothing of the backend on its own account either.
            if useful then
                process_requests()
                -- A peer's refresh signal is honoured at most every fifteen seconds.
                if not pending and (fetch_elapsed >= 30 or peer_refresh and fetch_elapsed >= 15) then peer_refresh = false; service.refresh(false) end
            end
            publish()
        end
        check_prompt()
        local ok, err = transport.update(dt)
        if not ok and err then wire_error = err end
    end

    function service.snapshot()
        local state, reason = ensure()
        if not state then return {enabled = enabled(), reason = reason, members = {}, maps = {}} end
        local result = state:snapshot()
        result.enabled, result.myself = true, state.myself
        result.assignment_status, result.error, result.transport_error = assignment_status, last_error, wire_error
        result.presence_full, result.presence_changed = presence_full() or nil, presence_changed() or nil
        result.launch, result.owner_launch = copy(launch), owner_launch and {requester = owner_launch.sender, status = owner_launch.status, mission_id = owner_launch.mission_id}
        result.capabilities = {local_assignment = true, local_choices = true, peer_transport = transport.available(), start = get_game().install(), automatic_voting = get_game().install()}
        for id, member in pairs(result.members) do
            local peer = peers[id]
            member.assignment_status = id == state.myself and assignment_status or peer and peer.synced and peer.meta.status or "unknown"
            member.protocol_status = id == state.myself and "local" or peer and peer.status or availability[id] or "unknown"
            member.remote_start_allowed = id == state.myself and remote_allowed() or peer and peer.synced and peer.meta.remote == 1 or false
            -- a teammate whose tile was carried over a join or leave, shown while the board reconnects
            member.carried = carried_at[id] ~= nil or nil
            if id ~= state.myself and not (peer and peer.synced) then result.ready[id] = nil end
        end
        return result
    end

    service.api = {version = 1, snapshot = service.snapshot, refresh = function() return service.refresh(true) end,
        eligibility = service.eligibility, vote = service.vote, start = service.start}
    return service
end
