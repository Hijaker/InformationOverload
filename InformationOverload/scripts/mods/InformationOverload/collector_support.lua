-- The scoreboard's Support page: revives, saves, blocks, dodges, time in coherency, blitzes and abilities for every human in the squad.
-- Each is counted from what the server sends every client, the way the game counts its own end-of-mission stat; saves also take in
-- killing an enemy that has a teammate pinned. Kept on the mission as support[character id].
return function(mod, api, d)
    local member, local_unit, invoke = d.member, d.local_unit, d.invoke
    local S = {}
    -- tracked: the seconds each player was alive and in the mission, which time in coherency is a share of
    local FIELDS = {"revives", "saves", "blocked", "dodged", "coherency", "tracked", "blitzes", "abilities"}
    local function live()
        local m = api.tracker().mission
        if not m or not m.context or m.context.difficulty == "psykhanium" or not api.enabled() then return end
        return m
    end
    local function bump(unit, field, n)
        local m = live();if not m or not unit then return end
        local id = member(unit);if not id then return end
        m.support = m.support or {}
        local r = m.support[id]
        if not r then r = {};for _, f in ipairs(FIELDS) do r[f] = 0 end;m.support[id] = r end
        r[field] = (r[field] or 0) + (n or 1)
    end
    S.bump = bump

    -- Revives and saves: the interaction's kind is taken as it starts, as the downed or pinned state can end before its success arrives
    local pending = setmetatable({}, {__mode = "k"})
    local KIND = {revive = "revives", pull_up = "saves", remove_net = "saves", rescue = "saves"}
    local function kind_of(ext) local ok, k = pcall(ext.interaction_type, ext);return ok and k or nil end
    mod:hook_safe("PlayerInteracteeExtension", "started", function(self, actor)
        invoke(function() pending[self._unit] = {kind = kind_of(self), actor = actor} end)
    end)
    -- DMF takes one hook a mod per function, and collectors.lua already hooks stopped, so it calls this
    function S.stopped(self, result, actor)
        if result ~= "success" then return end
        local p = pending[self._unit];pending[self._unit] = nil
        local kind = p and p.kind ~= "none" and p.kind or kind_of(self)
        actor = actor or (p and p.actor)
        local field = KIND[kind]
        if field and actor and actor ~= self._unit then bump(actor, field) end
    end

    -- Dodges: the server plays a successful melee dodge's sound on the dodging player for every client, one for each dodge the game counts
    local DODGE = {["wwise/events/player/play_player_dodge_melee_success"] = true, ["wwise/events/player/play_player_dodge_melee_success_specials"] = true}
    do local ok, aliases = pcall(require, "scripts/settings/sound/player_character_sound_event_aliases")
        local alias = ok and type(aliases) == "table" and rawget(aliases, "dodge_success_melee")
        local function add(v) if type(v) == "string" then DODGE[v] = true elseif type(v) == "table" then for _, x in pairs(v) do add(x) end end end
        if type(alias) == "table" then add(rawget(alias, "events")) end
    end
    -- called from collectors.lua's own hook on the exclusive sound
    function S.sound(fx, event_name) if DODGE[event_name] then bump(fx._unit, "dodged") end end

    -- Your own blitzes and abilities: the call the game itself counts, once each, not again when a frame is played over. Some
    -- abilities (Chorus, Telekine Shield, Stimm Field) spend their charge on the server alone, so your charge dropping with no
    -- such call just before counts them too.
    local spent, last_clock = setmetatable({}, {__mode = "k"}), 0
    mod:hook_safe("PlayerUnitAbilityExtension", "consume_ability_usage_cost", function(self, ability_type)
        invoke(function()
            local field = ability_type == "combat_ability" and "abilities" or ability_type == "grenade_ability" and "blitzes"
            if not field or not (self._equipped_abilities and self._equipped_abilities[ability_type]) then return end
            local data = ScriptUnit.has_extension(self._unit, "unit_data_system")
            local again = data and data.is_resimulating;if type(again) == "function" then again = again(data) end
            if again then return end
            local seen = spent[self._unit];if not seen then seen = {};spent[self._unit] = seen end;seen[ability_type] = last_clock
            bump(self._unit, field)
        end)
    end)

    -- Blocks: every blocked attack on a player, whoever made it; a kill of an enemy that had a teammate pinned is a save for the killer
    local pinned = setmetatable({}, {__mode = "k"})
    function S.report(target, attacker, result)
        if result == "blocked" then bump(target, "blocked")
        elseif result == "died" and target then
            local p = pinned[target]
            if p and attacker and attacker ~= p.victim then pinned[target] = nil;bump(attacker, "saves") end
        end
    end

    -- Each frame: who is pinned and by what, and teammates' blitzes and abilities from their charge; once a gameplay second, coherency
    local seen_ability = setmetatable({}, {__mode = "k"})
    local COUNTED = {combat_ability = "abilities", grenade_ability = "blitzes"}
    local next_sample, last_sample, sample_m
    local function data_of(unit) return ScriptUnit.has_extension(unit, "unit_data_system") end
    local function read(data, name) local ok, c = pcall(data.read_component, data, name);return ok and c or nil end
    local function charge_uses(unit, data, now, own)
        local ext = ScriptUnit.has_extension(unit, "ability_system");if not ext then return end
        local last = seen_ability[unit];if not last then last = {};seen_ability[unit] = last end
        for kind, field in pairs(COUNTED) do
            local ok, equipped = pcall(ext.equipped_abilities, ext);local name = ok and equipped and equipped[kind] and equipped[kind].name
            local c = read(data, kind)
            if name and c then
                if name == "broker_missile_launcher" then
                    -- its shots spend grenade charges, which the game does not count as blitzes
                elseif kind == "combat_ability" and name:find("^cryptic") then
                    -- your own is counted by the call; a teammate's each time it turns on
                    if own then last[kind .. "_active"] = c.active == true else
                    local active = c.active == true;if active and not last[kind .. "_active"] then bump(unit, field) end;last[kind .. "_active"] = active end
                else
                    local okr, r = pcall(ext.remaining_ability_resource, ext, kind);local okc, cost = pcall(ext.get_ability_resource_cost_per_charge, ext, kind)
                    if okr and okc and type(r) == "number" and type(cost) == "number" and cost > 0 then
                        local before = last[kind]
                        if before and before - r >= .5 * cost then
                            local called = own and spent[unit] and spent[unit][kind]
                            if not (called and now - called <= 1) then bump(unit, field) end
                        end
                        last[kind] = r
                    end
                end
            end
        end
    end
    function S.update(clock)
        local m = live();if not m then return end
        local players = Managers.player and Managers.player:players()
        local me = local_unit()
        last_clock = clock
        local now = Managers.time and Managers.time:has_timer("gameplay") and Managers.time:time("gameplay")
        -- the gameplay clock starts again from 0 each mission, so a new mission, or a clock gone back, starts the sampling again
        if m ~= sample_m or now and last_sample and now < last_sample then sample_m, next_sample, last_sample = m, nil, nil end
        local sample = now and (not next_sample or now >= next_sample)
        local dt = sample and last_sample and now - last_sample or 0
        if sample then last_sample, next_sample = now, now + 1 end
        for _, player in pairs(players or {}) do
            local unit = player.player_unit
            local data = unit and ALIVE[unit] and data_of(unit)
            if data then
                local dis = read(data, "disabled_character_state")
                if dis and dis.is_disabled and dis.disabling_unit and dis.disabling_type ~= "netted" then pinned[dis.disabling_unit] = {victim = unit, at = clock} end
                charge_uses(unit, data, clock, unit == me)
                if sample and dt > 0 and dt < 5 then
                    bump(unit, "tracked", dt)
                    local co = ScriptUnit.has_extension(unit, "coherency_system")
                    local ok, n = false, nil;if co then ok, n = pcall(co.num_units_in_coherency, co) end
                    if ok and type(n) == "number" and n > 1 then bump(unit, "coherency", dt) end
                end
            end
        end
        -- an enemy stays counted as pinning for a moment after the pin ends, as its death report can arrive just after
        for enemy, p in pairs(pinned) do if clock - p.at > 1.5 then pinned[enemy] = nil end end
    end
    S.FIELDS = FIELDS
    return S
end
