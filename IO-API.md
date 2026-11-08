# Information Overload API

Read-only access to I/O's live mission data and match history, for other mods and HUD scripts.

```lua
local io = get_mod("information_overload")
local api = io and io.io_public
if not api or api.version < 2 then return end
```

## Conventions

- Every function returns a value, or `nil` plus a reason string. `nil` never means 0.
- Returned tables are fresh copies. Changing them affects nothing.
- Players are identified by character id (`player:character_id()`). Where a function takes a player you can pass a character id, a player object, a player unit, or `nil`/`true` for the local player. Slot numbers aren't accepted.
- After a mods reload every call returns `nil, "stale"`. Call `get_mod` again and re-register any event handlers.

## Live mission

### api.revision()

```lua
local live, history = api.revision()
```

Two counters. `live` goes up when anything returned by `squad`, `player_damage`, `roster`, `whoami` or `streaks` changes. `history` goes up when a match is saved, deleted or recounted, or a clear time is edited. It doesn't allocate, so poll it every frame and only re-query when a counter moves:

```lua
local last, rows
local function update()
    local live = api.revision()
    if live and live ~= last then
        last = live
        rows = api.squad()
    end
end
```

`mission().tracked_seconds` doesn't bump `live`.

### api.mission()

```lua
{
    active = true,            -- false when no mission is running (then only in_hub is set)
    in_hub = false,           -- true in the Mourningstar
    name = "cm_habs",
    display_name = "...",     -- localised
    difficulty = "...",       -- danger level, Havoc rank as a string, or "psykhanium"
    mode = "non-havoc",       -- or "havoc"
    patch = "1.13.0",
    solo = false,             -- SoloPlay
    training = false,         -- Psykhanium
    full = true,              -- false if I/O joined late
    tracked_seconds = 512,    -- nil in the Psykhanium
}
```

### api.squad(opts)

One row per player: local player first, then by damage. Players who left stay in with `left = true`. Before I/O has sampled the squad, only the local player is listed.

```lua
local rows = api.squad()                     -- share and order by useful damage
local rows = api.squad({ overkill = true })  -- by reported damage

-- each row
{
    id, name, class,          -- character id, name, class key
    personal = true,          -- local player
    left = false,
    damage = { useful, reported, overkill, unknown, share, boss },   -- share is 0..1
    kills = { total, lesser, elite, special, boss, melee, ranged },
    hits = { weakspot, critical },
    downs = 0,
    deaths = 0,
}
```

`kills.melee` and `kills.ranged` split lesser and elite kills by the enemy's role. The local player's kills use the same count as I/O's scoreboard. `damage.boss` follows the `overkill` option.

### api.player_damage(player, opts)

```lua
api.player_damage()                                 -- local player, total
api.player_damage(player, { category = "melee" })
api.player_damage(nil, { armour = "armored" })
api.player_damage(nil, { overkill = true })         -- share of reported damage

-- returns { useful, reported, overkill, unknown, share, found }
```

`found = false` means that player isn't in the mission, and the zeros are real. A player who hasn't hit anything yet is `found = true` with zeros.

Categories: `total` (default), `melee`, `ranged`, `other`, `boss`, `dot`, `dot_bleed`, `dot_burn`, `dot_soulblaze`, `dot_toxin`, `dot_other`.

Armour: `unarmored`, `armored` (Flak), `resistant` (Unyielding), `disgustingly_resilient` (Infested), `super_armor` (Carapace), `berserker` (Maniac), `unknown`.

Boss damage isn't split by armour, so `category = "boss"` with an `armour` returns `nil, "unsupported"`.

### api.whoami()

The local player's character id.

### api.roster()

Everyone seen this mission, keyed by character id: `{ name, class, personal, present, left }`. Empty until the first squad sample.

### api.streaks()

The local player's current streaks, reset when broken:

```lua
{ headshots, melee_headshots, ranged_headshots, kills, dodges, kills_without_a_down }
```

`kills` counts kills from consecutive attacks that each killed something. `kills_without_a_down` is for the current class, with Havoc and non-Havoc counted separately.

## Match history

### api.history(opts)

Finished matches, newest first.

```lua
api.history()                            -- all
api.history({ count = 10 })              -- newest 10
api.history({ from = 11, count = 10 })   -- the 10 before those
api.history({ count = 0 })               -- just the totals

-- returns { total, excluded, matches = { ... } }
-- each match
{
    id, victory, full, run_kind,
    started_at = "2026-11-08 14:02:11",   -- local time, as text
    seconds,                              -- completion time, if known
    mission, display_name, difficulty, mode, patch,
    class, character, character_name,
    kills = { total, elite, special, boss },
    damage = { own_useful, team_useful, own_reported },
}
```

`run_kind` is `"full"`, `"late_join"`, `"partial_unknown"`, `"early_leave"` or `"rejoined"`.

Only matches I/O counts in its statistics are listed. The rest (private games, discarded or hidden matches, ones excluded by the Counting settings, games with no result) are counted in `excluded`. SoloPlay matches aren't included.

`damage.own_useful` and `team_useful` are `nil` when the match has no squad figures. `own_reported` is `nil` only when it has no damage figures at all.

### api.history_match(id)

One match in full (damage tables, timeline, incidents, records and so on), in I/O's frontend contract format (version in `api.capabilities.frontend_contract`). `availability` lists which parts the match has. It reads the match file, so don't call it every frame.

Returns `nil, "excluded"` for a match `history()` leaves out, and `nil, "unreadable match"` if the file is missing or damaged.

### api.run_damage(id)

Damage figures for one match without loading it: `{ own_useful, team_useful, own_reported, run_kind, excluded, countable }`. Also works for excluded matches.

## Other

### api.names()

Display names in `armour`, `category` and `class` tables, e.g. `names().armour.armored` is `"Flak"` and `names().class.broker` is `"Hive Scum"`.

### api.on(event, fn) / api.off(handle)

```lua
local h = api.on("mission_end", function(info)
    print(info.name, info.victory, info.id)
end)
api.off(h)
```

`mission_start` passes `{ name, display_name, difficulty, mode, solo, training }`. `mission_end` adds `victory`, `saved` and `id` (the saved match's id, `nil` for SoloPlay). Handlers run in a pcall; an error is logged once.

- `mission_end` fires when I/O finishes the match: at the end, or back in the Mourningstar for a mission you left.
- Rejoining after a crash, before reaching the Mourningstar: no second `mission_start`, one `mission_end` at the end. If the part you left was already finished in the Mourningstar, the rejoin fires `mission_start` again and I/O merges the two parts. The second `mission_end`'s id replaces the first.
- Nothing fires in the Psykhanium. Private games fire `mission_start` only.

## Damage figures

Darktide reports each hit's full damage even when the enemy had less health left. I/O splits it:

- `useful`: health actually removed (what I/O's scoreboard shows)
- `overkill`: the rest
- `unknown`: couldn't be split, usually because I/O never saw that enemy's health
- `reported`: all of it, `useful + overkill + unknown`

Void shield damage is left out.

## Reasons

| Reason | When |
|---|---|
| `stale` | mods were reloaded |
| `unavailable` | I/O's live counting failed to load (`capabilities.live` is `false`) |
| `not recording` | I/O disabled, Personal Records enabled, or Psykhanium tracking off while in the Psykhanium |
| `no mission` | no mission running |
| `not yet counted` | mission running, no damage yet |
| `local player not in the squad yet` | `whoami()` too early |
| `unknown category`, `unknown armour`, `unsupported` | bad `player_damage` options |
| `no such match`, `excluded`, `unreadable match` | `history_match` / `run_damage` |
| `unknown event`, `not a function` | bad `on()` arguments |

## Not available

- Steam ids, Steam names, account ids and friend names. They're removed everywhere, full matches included; anything a match stores by account id comes back keyed by character id.
- Anything that changes I/O (recording, settings, deleting or importing matches).
- Talent and blessing breakdowns.

## Versioning

`api.version` is `2`. Fields can be added without a bump; removing a field or changing its meaning bumps it. `api.capabilities` has `live`, `roster`, `history`, `events` and `frontend_contract`.
