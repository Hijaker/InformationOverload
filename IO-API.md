# Information Overload API

Information Overload (I/O) lets other mods read what it tracks: the mission you're in, everyone's damage and kills, your streaks, and your match history. If you're writing a HUD script or your own mod and want those numbers, this is how you get them.

It only reads. Nothing you call here can change I/O's data, its settings or what it records.

## Contents

- [Quick start](#quick-start)
- [How every call answers](#how-every-call-answers)
- [Identifying players](#identifying-players)
- [The calls](#the-calls)
  - [revision](#revision) · [mission](#mission) · [squad](#squad) · [player_damage](#player_damage) · [whoami](#whoami) · [roster](#roster) · [streaks](#streaks)
  - [history](#history) · [history_match](#history_match) · [run_damage](#run_damage)
  - [names](#names) · [on and off](#on-and-off) · [reader](#reader)
- [What the damage numbers mean](#what-the-damage-numbers-mean)
- [Keeping it fast](#keeping-it-fast)
- [Reasons a call can give](#reasons-a-call-can-give)
- [What isn't shared](#what-isnt-shared)
- [Versions](#versions)

## Quick start

```lua
local io = get_mod("information_overload")
local api = io and io.io_public

if api and api.version >= 2 then
    local rows = api.squad()
    if rows then
        for _, row in ipairs(rows) do
            print(row.name, row.damage.useful, row.kills.total)
        end
    end
end
```

The mod id is `information_overload`, lowercase with an underscore. `get_mod("Information Overload")` won't find it.

A HUD that redraws every frame should only rebuild when something has changed:

```lua
local last, rows

local function update()
    local live = api.revision()
    if live == nil then return end        -- "stale": see below
    if live ~= last then
        last = live
        rows = api.squad()                -- nil when no mission is running
    end
end
```

## How every call answers

Every call gives you either an answer, or `nil` and a short reason:

```lua
local rows, why = api.squad()
if not rows then
    -- why is "no mission", "not yet counted", "stale" and so on
end
```

A `nil` never means zero. Zero damage comes back as `0`.

Everything you get back is a fresh copy made for you. Keep it, sort it, change it; nothing in I/O is affected, and no other mod sees your changes. A [reader](#reader) hands back the same copy until something changes, and it's still yours alone.

**Stale.** After a mods reload, the I/O you fetched earlier no longer runs the game, and every call returns `nil, "stale"`. Fetch it again with `get_mod("information_overload")`, and register any [event handlers](#on-and-off) again.

## Identifying players

Players are known by their character id, the string from `player:character_id()`. Slot numbers are never used: what's slot 1 on your screen isn't slot 1 for anyone else.

Where a call takes a `player`, you can give it:

| You pass | It means |
|---|---|
| nothing, or `true` | you |
| a character id string | that character |
| a player object | that player |
| a player unit | whoever owns that unit |

A number doesn't mean a slot. `api.player_damage(1)` finds no one.

## The calls

### revision

```lua
local live, history = api.revision()
```

Two numbers that only ever go up. `live` goes up when anything `squad()`, `player_damage()`, `roster()`, `whoami()` or `streaks()` would show has changed: damage, kills, downs, deaths, who's in the squad, your streaks. `history` goes up when a match is saved, deleted or recounted, or a clear time is edited.

`mission()`'s `tracked_seconds` counts up all the time without moving `live`, so read `mission()` directly when you want a timer.

Calling it costs almost nothing and makes no garbage, so call it every frame and only ask for the real data when a number moves.

### mission

```lua
local m = api.mission()
```

The mission being played. When there isn't one you still get a table, `{ active = false, in_hub = true or false }`.

| Field | What it is |
|---|---|
| `active` | `true` while a mission is running |
| `in_hub` | `true` in the Mourningstar |
| `name` | the mission's internal name, like `"cm_habs"` |
| `display_name` | its name as the game shows it |
| `difficulty` | the danger level, a Havoc rank as a string, or `"psykhanium"` |
| `mode` | `"havoc"` or `"non-havoc"` |
| `patch` | the game patch it's played on |
| `solo` | `true` in SoloPlay |
| `training` | `true` in the Psykhanium |
| `full` | `false` if I/O joined late, so it only saw part of the mission |
| `tracked_seconds` | how long I/O has been watching, in seconds (`nil` in the Psykhanium) |

### squad

```lua
local rows = api.squad()
local rows = api.squad({ overkill = true })   -- share and order by all damage instead
```

One row per player in the mission: everything I/O's Squad Cards show. You come first, then everyone else by damage. Players who left stay in, with `left = true`, so skip those if you only want who's still there.

| Field | What it is |
|---|---|
| `id` | character id |
| `name`, `class` | character name and class key (see [names](#names)) |
| `personal` | `true` on your own row |
| `left` | `true` if they left the mission |
| `damage.useful` | damage that took health off enemies |
| `damage.reported` | all damage, overkill included |
| `damage.overkill` | damage past what the enemy had left |
| `damage.unknown` | damage I/O couldn't split either way |
| `damage.share` | their part of the squad's damage, from 0 to 1 |
| `damage.boss` | damage to bosses (useful damage, or all of it with `overkill = true`) |
| `kills.total` | every kill |
| `kills.lesser`, `kills.elite`, `kills.special`, `kills.boss` | kills by enemy kind |
| `kills.melee`, `kills.ranged` | lesser and elite kills, split by whether the enemy fights up close or at range |
| `hits.weakspot`, `hits.critical` | weakspot and critical hits |
| `downs`, `deaths` | times downed and killed |

Your own row's kills come from the same count as I/O's This Mission panel, so they match what the scoreboard shows.

Before I/O has seen the rest of the squad, the list holds just you.

### player_damage

```lua
local d = api.player_damage()                                -- you
local d = api.player_damage(player)                          -- someone else
local d = api.player_damage(nil, { category = "melee" })
local d = api.player_damage(nil, { armour = "armored" })     -- Flak only
local d = api.player_damage(nil, { overkill = true })        -- share of all damage
```

One player's damage this mission.

| Field | What it is |
|---|---|
| `useful`, `reported`, `overkill`, `unknown` | as in [squad](#squad) |
| `share` | their part of the squad's damage for the same category and armour, 0 to 1 |
| `found` | `false` if that player isn't in this mission |

When `found` is `false`, the zeros are real zeros, not an error. A player who's in the mission but hasn't hit anything yet is `found = true` with zeros.

`category` can be `"total"` (the default), `"melee"`, `"ranged"`, `"other"`, `"boss"`, `"dot"` for all damage over time, or one kind of it: `"dot_bleed"`, `"dot_burn"`, `"dot_soulblaze"`, `"dot_toxin"`, `"dot_other"`.

`armour` is the game's own armour key: `"unarmored"`, `"armored"` (Flak), `"resistant"` (Unyielding), `"disgustingly_resilient"` (Infested), `"super_armor"` (Carapace), `"berserker"` (Maniac) or `"unknown"`.

Boss damage is kept as one number, not split by armour, so `category = "boss"` with an `armour` gives `nil, "unsupported"`.

### whoami

```lua
local my_id = api.whoami()
```

Your character id, as I/O sees it. Handy for checking which row in `squad()` is you without guessing.

### roster

```lua
local everyone = api.roster()
if everyone then
    for id, p in pairs(everyone) do print(id, p.name, p.class, p.present) end
end
```

Everyone I/O has seen in this mission, keyed by character id.

| Field | What it is |
|---|---|
| `name`, `class` | character name and class key |
| `personal` | `true` for you |
| `present` | `true` if they're connected right now |
| `left` | `true` if they left |

It's empty until I/O has had its first look at the squad.

### streaks

```lua
local s = api.streaks()
```

Your runs in progress: the counts behind I/O's Streaks page. Each goes back to 0 when it breaks.

| Field | What it is |
|---|---|
| `headshots` | headshots in a row, melee or ranged |
| `melee_headshots`, `ranged_headshots` | the same, one kind only |
| `kills` | kills in a row, from attacks that each killed something; an attack that kills nothing starts it again |
| `dodges` | melee dodges in a row |
| `kills_without_a_down` | kills on the class you're playing since you last went down, with Havoc and other missions counted apart |

### history

```lua
local h = api.history()                             -- every match
local h = api.history({ count = 10 })               -- your newest ten
local h = api.history({ from = 11, count = 10 })    -- the ten before those
local h = api.history({ count = 0 })                -- just how many there are
```

Your finished matches, newest first. `from` counts from the newest (1 is the newest), and `count` is how many you want. Leave both out to get everything.

| Field | What it is |
|---|---|
| `total` | how many matches there are in all |
| `excluded` | matches left out (see below) |
| `matches` | the matches you asked for |

Each match in `matches`:

| Field | What it is |
|---|---|
| `id` | the match's id, for [history_match](#history_match) and [run_damage](#run_damage) |
| `victory` | `true` for a win, `false` for a loss |
| `full` | `false` if I/O only saw part of it |
| `started_at` | when it started, as local date and time text like `"2026-11-08 14:02:11"` |
| `seconds` | how long it took, if I/O knows |
| `mission`, `display_name` | the mission's internal and shown names |
| `difficulty`, `mode`, `patch` | as in [mission](#mission) |
| `class`, `character`, `character_name` | who you played |
| `kills.total`, `kills.elite`, `kills.special`, `kills.boss` | your kills |
| `damage.own_useful` | your useful damage: `0` if you dealt none, `nil` only if the match has no squad numbers |
| `damage.team_useful` | the squad's useful damage (`nil` when the match has no squad numbers) |
| `damage.own_reported` | your damage with overkill: `0` if you dealt none, `nil` only if the match kept no damage figures at all |
| `run_kind` | `"full"` for a whole mission, `"late_join"` when I/O joined partway, `"partial_unknown"` for a partial Havoc mission it can't tell apart, `"early_leave"` when you left, `"rejoined"` for a mission you left and came back to |

Only matches I/O counts in its own statistics are listed. Missions you left, late joins and rejoins are included, marked by `run_kind` and `full`, unless your Counting settings leave them out. What isn't listed (private games, discarded or hidden matches, matches your Counting settings exclude, and games with no result) is counted in `excluded`.

SoloPlay matches are kept separately and don't appear here.

### history_match

```lua
local full = api.history_match(id)
```

One match with everything I/O saved about it: the damage tables, the timeline, incidents, records and more. This reads that match's file, so call it when someone opens a match, not every frame.

The fields follow I/O's frontend contract (`capabilities.frontend_contract` says which version). An `availability` table says which of the big parts the match has, since older matches may not have them all.

Frontend contract 2 (I/O 1.0.4): a saved match keeps what I/O's pages read, and older saves are tidied to match. I/O packs some parts on disk, but `history_match` hands them out read back, in the shapes below.

- `party_records.members[]` no longer has `enemy`, `armour`, `weapons` or `quality`. Kills and `best` are as before.
- `combat_timeline` hits are `{time_ms, reported, useful_or_false, profile, attack_type, result, flags}`, without the eighth number, the running sequence; segments have no `sequence`. Its `streak_events` keep only resets whose cause is `knocked_down` or `died`. The streak counters are as before.
- `enemy_kill_counts.members[]` keeps `personal` and `enemy_kills`, without `class`.
- `damage` tallies no longer count `health_hits`.
- `experimental` is gone from saved matches, and the old research blocks `talent_calibration`, `compact_damage_test`, `hyperviolence_poc`, `performance`, `damage_diagnostics` and `talent_test` with it.

It gives `nil, "excluded"` for a match `history()` leaves out, and `nil, "unreadable match"` if the file is missing or damaged.

### run_damage

```lua
local r = api.run_damage(id)
```

Just the damage numbers for one match, without loading the whole thing. Unlike `history()`, it also answers for matches I/O leaves out of its statistics. `id` is the match's id from [history](#history) or `mission_end`, the same one `history_match()` takes.

| Field | What it is |
|---|---|
| `own_useful`, `team_useful`, `own_reported` | as in [history](#history) |
| `run_kind` | as in [history](#history) |
| `excluded` | `true` if `history()` leaves it out, for any of the reasons listed there |
| `countable` | `true` if `history()` lists it; always the opposite of `excluded` |

### names

```lua
local n = api.names()
print(n.armour.armored)       -- "Flak"
print(n.class.broker)         -- "Hive Scum"
print(n.category.dot_burn)    -- "Burn"
```

Readable names for armour, damage categories and classes, so your script doesn't have to keep its own list. The armour and class names are the ones I/O's pages show, in English.

### on and off

```lua
local handle = api.on("mission_end", function(info)
    if info.victory then
        -- celebrate
    end
end)

api.off(handle)   -- stop listening
```

Get told when a mission starts or ends instead of checking yourself.

`mission_start` gives you `name`, `display_name`, `difficulty`, `mode`, `solo` and `training`.

`mission_end` gives you the same, plus:

| Field | What it is |
|---|---|
| `victory` | `true` for a win, `false` for a loss |
| `saved` | `true` if the match was saved |
| `id` | the saved match's id, for [history_match](#history_match); `nil` for SoloPlay, whose matches aren't in `history()` |

Your handler runs safely: if it errors, I/O carries on, and the error is logged once. Each handler gets its own table, so changing it doesn't affect anyone else.

When they come:

- `mission_end` comes when I/O finishes the match: right at the end for one you played through, or once you're back in the Mourningstar for one you left.
- If you rejoin a mission straight after a crash, before getting back to the Mourningstar, no second `mission_start` is sent and one `mission_end` comes at the end.
- If the part you left was already finished in the Mourningstar, rejoining sends `mission_start` again. I/O then joins the two parts into one match, and the second `mission_end` gives the joined match's id. The id the first `mission_end` gave no longer names a match.
- The Psykhanium sends neither. Private games send `mission_start` but no `mission_end`, as I/O doesn't keep them as matches.
- After a mods reload you need to call `on` again.

### reader

```lua
local reader = api.reader()    -- once, when your script starts

local rows = reader.squad()    -- as often as you like
```

A reader has the same calls as `api`: `revision`, `mission`, `squad`, `player_damage`, `whoami`, `roster`, `streaks`, `history`, `history_match`, `run_damage` and `names`. It hands back the same table each time you ask the same thing, until `revision()` moves, so asking every frame makes no new tables.

- Its tables are yours alone. No other mod sees them, and nothing you do to them reaches I/O.
- If you change one, your own next answer has your change in it until the numbers move. `names()` never changes, and `mission()` is written over every time you ask. Copy a table first if you want to sort or edit it.
- Each set of options is its own answer: `reader.squad()` and `reader.squad({ overkill = true })` are two tables.
- `reader.mission()` is always the same table, brought up to date every time you ask, because `tracked_seconds` counts up without moving `revision()`.
- It keeps the last 8 full matches you asked `history_match()` for, and the last 16 pages of `history()`.
- After a mods reload it's stale like every other call. Get a new one from the new `api`.

## What the damage numbers mean

Darktide reports every hit's full damage, even when the enemy only had a sliver of health left. I/O splits that up:

- `useful`: what actually came off the enemy's health. This is the fair number for comparing players, and it's what I/O's scoreboard shows.
- `overkill`: the rest, past what the enemy had left.
- `unknown`: damage where I/O couldn't tell how it split, usually because it never saw that enemy's health.
- `reported`: all of it, `useful + overkill + unknown`.

Damage to void shields is left out of every number, as it is on I/O's own pages.

## Keeping it fast

- `revision()` costs almost nothing. Call it every frame and only fetch data when it changes.
- `squad()`, `player_damage()`, `roster()` and `streaks()` are cheap enough for every frame, but each one builds new tables. With `revision()` you won't need to, or ask through a [reader](#reader), which hands back the same tables until something changes.
- `history()` is quick, and each match in it is small. With a long history, ask for a page instead of everything, and only when the `history` revision moves.
- `history_match()` reads a file. Call it when someone wants to see one match, never every frame.

## Reasons a call can give

| Reason | When |
|---|---|
| `"stale"` | the mods were reloaded; fetch I/O again |
| `"unavailable"` | I/O's live counting failed to load (`capabilities.live` is `false`) |
| `"not recording"` | I/O is turned off or Psykhanium tracking is off and you're in the Psykhanium |
| `"no mission"` | no mission is running |
| `"not yet counted"` | a mission is running but nobody has dealt damage yet |
| `"local player not in the squad yet"` | `whoami()` before I/O has seen you |
| `"unknown category"`, `"unknown armour"` | `player_damage()` got a key it doesn't know |
| `"unsupported"` | `player_damage()` was asked for boss damage of one armour |
| `"no such match"` | no match has that id |
| `"excluded"` | `history_match()` for a match `history()` leaves out |
| `"unreadable match"` | that match's file is missing or damaged |
| `"unknown event"`, `"not a function"` | `on()` was given something it can't use |

## What isn't shared

- Steam ids, Steam names, account ids and friends' names. Other players didn't agree to share those with every mod, so they're taken out of everything, full matches included. Where a match keeps something under a player's account id, you get it under their character id instead.
- Anything that changes I/O: recording, settings, deleting or importing matches.
- Talent and blessing breakdowns. I/O doesn't record them separately.

## Versions

`api.version` is `2`. New fields can be added without the number changing, so ignore fields you don't know. It goes up when something is removed or starts meaning something else.

`api.capabilities` says what this build supports: `live`, `roster`, `history`, `events`, and `frontend_contract` for the version of the full match data.

### Changes since version 1

- `history()` lists matches newest first, takes `from` and `count`, and tells you the `total`. Each match is now a small summary; the full match data is only in `history_match()`. The `contract_version` and `filters` fields are gone.
- `history_match()` no longer includes other players' Steam ids, Steam names, account ids or friends' names.
- `squad()` rows gained downs, deaths, weakspot and critical hits, boss damage, and lesser, melee and ranged kills.
- New calls: `revision()`, `streaks()`, `names()`, `on()` and `off()`.
- `reader()` came later in version 2, so check `api.reader` exists before you use it.
