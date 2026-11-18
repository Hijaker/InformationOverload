-- Direct Immaterium presence transport. The board's frames ride in one presence key, two only for a value over 250 bytes, sent only
-- when it changed since the last good send; the beat moves it on alone only once it falls due. The presence service refuses a stream
-- with more than 20 entries, an empty value counted as one, so a build carries I/O's keys only while they hold something, and a key
-- withdrawn is emptied once on the live stream and left out after. The game registers a stream with a whole build of create_key_values
-- and updates it with partial ones, and a reader replaces a player's entry whole on each change, so a new stream holds what its
-- registration carried and nothing it left out; an older stream's value carried over anyway would read as stale once its beat stopped.
-- The guard sits on GRPCManager._convert_presence_key_values, the last step of a registration and an update alike before gRPC. Counting
-- the game's thirteen keys whether or not they are there, every other key the stream holds and I/O's own, it leaves I/O's keys out of
-- anything that would pass 20 and never touches another key.
return function(mod, protocol)
    local transport = {}
    local F, KEYS = protocol.fields, protocol.keys
    local OURS = {}
    for _, key in ipairs(KEYS) do OURS[key] = true end
    local LIMIT, GAME = 20, 13
    local GAME_KEYS = {character_id = true, activity_id = true, party_id = true, num_party_members = true, num_mission_members = true,
        cross_play_disabled = true, cross_play_disabled_in_party = true, is_cross_playing = true, psn_session_id = true,
        havoc_status = true, havoc_rank_cadence_high = true, havoc_rank_all_time_high = true, game_session_id = true}
    local values, wire, staged_beat = {}, {}, nil
    -- What the live stream holds of each of I/O's keys (a value, "" once emptied, false after a failed send), and the fields last sent.
    local sent, sent_fields, sent_beat, used = {}, {}, nil, nil
    -- Every key on the stream since it registered; the stream the guard saw register, and what of I/O's it carried.
    local entries, opened, opened_with = {}, nil, {}
    local registering, pushing, dropped, full, told = 0, false, false, false, false
    -- Set when the guard may have missed what reached the stream: it registered unseen, or the board stopped, as DMF turns a mod's hooks
    -- off before its on_disabled.
    local hooked, guarded, registered, blind = false, false, false, false
    -- The hook points the game's code no longer has, once its presence is up, and whether the log has said so.
    local changed, said = nil, false
    local elapsed = 2

    local function copy(t) local out = {}; for k, v in pairs(t) do out[k] = v end; return out end
    local function beat_of(value) local frame = value and protocol.decode("B", value); return frame and frame.beat end
    local function count(...)
        local seen, n = {}, GAME
        for i = 1, select("#", ...) do
            for key in pairs((select(i, ...))) do
                if not GAME_KEYS[key] and not seen[key] then seen[key], n = true, n + 1 end
            end
        end
        return n
    end
    local function mark(blocked)
        full = blocked
        if blocked and not told then
            told = true
            if mod.info then mod:info("Server presence is blocked. I/O cannot share between players.") end
        end
    end

    local function guard(original, grpc, key_values)
        if type(key_values) ~= "table" then return original(grpc, key_values) end
        local fresh = registering > 0
        local mine, new, says = false, false, false
        for key, value in pairs(key_values) do
            if OURS[key] then mine, new, says = true, new or fresh or not entries[key], says or value ~= "" end
        end
        if mine and new and count(fresh and {} or entries, key_values) > LIMIT then
            local kept = {}
            for key, value in pairs(key_values) do if not OURS[key] then kept[key] = value end end
            key_values, dropped = kept, pushing
            if says then mark(true) end
        elseif says then mark(false) end
        if fresh then entries, opened_with = {}, {} end
        for key, value in pairs(key_values) do
            entries[key] = true
            if OURS[key] then if fresh then opened_with[key] = value elseif not pushing then sent[key] = value end end
        end
        return original(grpc, key_values)
    end

    local function register(original, grpc, ...)
        registering, entries, opened_with = registering + 1, {}, {}
        local ok, stream = pcall(original, grpc, ...)
        registering = registering - 1
        if not ok then error(stream, 0) end
        opened = stream
        return stream
    end

    local function hook_presence(class)
        if hooked or type(class) ~= "table" or type(class.create_key_values) ~= "function" then return end
        mod:hook(class, "create_key_values", function(original, self, whitelist)
            local result = original(self, whitelist)
            if guarded and type(result) == "table" then
                for _, key in ipairs(KEYS) do
                    local value = wire[key]
                    if value and (not whitelist or whitelist[key]) then result[key] = value end
                end
            end
            return result
        end)
        hooked = true
    end

    local function hook_grpc(class)
        if guarded or type(class) ~= "table" or type(class._convert_presence_key_values) ~= "function"
            or type(class.start_presence) ~= "function" then return end
        mod:hook(class, "_convert_presence_key_values", guard)
        mod:hook(class, "start_presence", register)
        guarded = true
    end

    -- Nothing is published without the guard. Once the game's presence is up its classes are loaded, so a hook point still missing then
    -- is a change in the game's code: the board stays off and says so.
    function transport.start()
        if hooked and guarded then return true end
        if not registered and mod.hook_require then
            registered = true
            mod:hook_require("scripts/managers/presence/presence_entry_myself", hook_presence)
            mod:hook_require("scripts/managers/grpc/grpc_manager", hook_grpc)
        end
        local classes = CLASS or {}
        hook_presence(classes.PresenceEntryMyself)
        hook_grpc(classes.GRPCManager)
        changed = nil
        if hooked and guarded then return true end
        if Managers and Managers.grpc and Managers.presence then
            local class, gone = classes.GRPCManager, {}
            if not hooked then gone[#gone + 1] = "PresenceEntryMyself.create_key_values" end
            for _, name in ipairs(guarded and {} or {"_convert_presence_key_values", "start_presence"}) do
                if type(class) ~= "table" or type(class[name]) ~= "function" then gone[#gone + 1] = "GRPCManager." .. name end
            end
            changed = table.concat(gone, ", ")
            if not said and mod.info then said = true; mod:info("The game's presence code has changed (%s not found), so the Havoc board is off.", changed) end
        end
        return false
    end

    function transport.available() return hooked and guarded and not full end
    function transport.full() return full end
    function transport.changed() return changed ~= nil end

    function transport.publish(next_values)
        local fields = {}
        for _, field in pairs(F) do
            local value = next_values[field]
            if value ~= nil and (type(value) ~= "string" or #value > protocol.MAX_BYTES) then return nil, "presence value exceeds 250 bytes" end
            if value ~= "" then fields[field] = value end
        end
        local raw, err = protocol.pack(fields)
        if not raw then return nil, err end
        local first, rest = protocol.split(raw)
        values, wire, staged_beat = fields, {}, beat_of(fields[F.beat])
        if first ~= "" then wire[KEYS[1]], wire[KEYS[2]] = first, rest end
        return true
    end

    local function push()
        local manager = Managers.presence
        local stream = manager and manager._my_presence_stream
        if not stream or not stream.send_stream_message then return false end
        if stream ~= used then
            local held = {}
            if stream == opened then held = opened_with
            else
                -- Registered while the guard was not there to see it, so with nothing of I/O's.
                opened, entries, blind = stream, {}, true
            end
            sent = copy(held)
            for key in pairs(sent) do entries[key] = true end
            sent_fields, sent_beat, used = {}, nil, stream
        end
        if blind then
            -- What the guard did not see reach the stream is counted from what a registration would carry now.
            blind = false
            local myself = manager.presence_entry_myself and manager:presence_entry_myself()
            local ok, whole = pcall(function() return myself:create_key_values() end)
            if ok and type(whole) == "table" then for key in pairs(whole) do if not OURS[key] then entries[key] = true end end end
        end
        -- A key the stream holds takes no more room, so only new ones are counted against the limit.
        local want, new = wire, false
        for key in pairs(wire) do new = new or not entries[key] end
        if new and count(entries, wire) > LIMIT then want = {}; mark(true) else mark(false) end
        local outgoing, any = {}, false
        for _, key in ipairs(KEYS) do
            local value, held = want[key], sent[key]
            if value then
                if held ~= value then outgoing[key], any = value, true end
            elseif held == false or held and held ~= "" then
                outgoing[key], any = "", true
            end
        end
        if any then
            pushing, dropped = true, false
            local ok, err = pcall(stream.send_stream_message, stream, outgoing)
            pushing = false
            if not ok then
                for key in pairs(outgoing) do sent[key] = false end
                return nil, tostring(err)
            end
            -- What the guard left out did not go.
            if dropped then return true end
            for key, value in pairs(outgoing) do sent[key], entries[key] = value, true end
        end
        -- While the presence is full nothing counts as sent, so every poll tries again and the value goes as soon as it fits.
        if want == wire then sent_fields, sent_beat = copy(values), staged_beat else sent_fields, sent_beat = {}, nil end
        return true
    end

    -- The beat counts seconds of the sender's clock, so it falls due by its own value, even after a long hitch.
    local function due()
        for _, key in ipairs(KEYS) do if sent[key] == false then return true end end
        for _, field in pairs(F) do
            if sent_fields[field] ~= values[field] and (field ~= F.beat or not staged_beat or not sent_beat
                or staged_beat - sent_beat >= protocol.BEAT) then return true end
        end
    end

    function transport.update(dt)
        elapsed = elapsed + dt
        if elapsed >= 2 and due() and transport.start() then
            elapsed = 0
            return push()
        end
        return true
    end

    function transport.stop()
        if not registered and not hooked then return true end
        values, wire, staged_beat = {}, {}, nil
        local ok, err = push()
        blind = true
        return ok, err
    end

    -- An entry that does not read as this protocol's value is handed on as its meta, so it shows as incompatible.
    function transport.read()
        local result = {}
        local party = Managers.party_immaterium
        if not party then return result end
        local myself = party:get_myself()
        local me = myself and myself:account_id()
        for _, member in ipairs(party:all_members() or {}) do
            local id = member:account_id()
            if id and id ~= me then
                local presence = member:presence()
                if presence and presence._key_value_string then
                    local first = presence:_key_value_string(KEYS[1])
                    local raw = protocol.join(first, presence:_key_value_string(KEYS[2]))
                    result[id] = raw and protocol.unpack(raw) or first and first ~= "" and {[F.meta] = first} or {}
                end
            end
        end
        return result
    end

    return transport
end
