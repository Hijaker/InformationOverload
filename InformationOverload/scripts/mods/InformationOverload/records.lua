-- Pure Lua: no game globals. All game-specific observations go through adapters.
local Records = {}
Records.__index = Records
Records.schema = 1
local class_labels={broker="Hive Scum",adamant="Arbites",cryptic="Skitarii",veteran="Veteran",zealot="Zealot",psyker="Psyker",ogryn="Ogryn"}
-- Same reported-damage basis as the per-player Team Damage view. Summary
-- metadata avoids decoding file-backed combat detail during navigation.
function Records.class_name(id) return class_labels[id] or "Unknown class" end

local mod = get_mod and get_mod("information_overload")
local Core
if mod and mod.io_dofile then
    Core=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_core")
else
    Core=dofile("InformationOverload/scripts/mods/InformationOverload/records_core.lua")
end
local copy,deep_copy,checkpoint_copy,key,fresh_row=Core.copy,Core.deep_copy,Core.checkpoint_copy,Core.key,Core.fresh_row
Records.rows_for,Records.best,Records.mission_row=Core.rows_for,Core.best,Core.mission_row

-- Completed history rows are not modified by live collection. Snapshot their
-- array membership for rollback, while copying mutable aggregate statistics.



local function bot_identity(identity)
 return identity and (identity.human==false or identity.is_bot==true or type(identity.name)=="string"and identity.name:find("[BOT]",1,true)~=nil)
end
function Records:remove_known_bots()
 local changed={}
 for _,run in ipairs(self.data.run_history or {})do local c=run.context or {};local bots={}
  for id,identity in pairs(c.operative_identities or {})do if bot_identity(identity)then bots[id]=true;c.operative_identities[id]=nil;changed[run.id or tostring(run)]=run end end
  for id,person in pairs(run.incidents and run.incidents.members or {})do if bots[id]or bot_identity(person)then
   for field,value in pairs(person.counts or {})do if type(value)=="number"then local team=run.incidents.team or {};team[field]=math.max(0,(team[field]or 0)-value)end end
   local rc=c
   for _,row in pairs(self.data.rows or {})do local x=row.context
    if row.aggregate and x.patch==rc.patch and x.mode==rc.mode and x.class==rc.class and x.character==rc.character and tostring(x.difficulty)==tostring(rc.difficulty)then
     for field,value in pairs(person.counts or {})do if type(value)=="number"and row.combat_totals then local key="team_"..field;if row.combat_totals[key]then row.combat_totals[key]=math.max(0,row.combat_totals[key]-value)end end end
    end
   end
   run.incidents.members[id]=nil;changed[run.id or tostring(run)]=run
  end end
  for name in pairs(c.teammates or {})do if name:find("[BOT]",1,true)then c.teammates[name]=nil;if c.operative_loadouts then c.operative_loadouts[name]=nil end end end
  for id,operative in pairs(c.operative_roster or {})do if bot_identity(operative)then c.operative_roster[id]=nil end end
  for id in pairs(bots)do if run.team_psykers and run.team_psykers.members then run.team_psykers.members[id]=nil end end
 end
 -- Correct maxima only when their provenance identifies an affected saved run.
 for _,row in pairs(self.data.rows or {})do for metric,run_id in pairs(row.best_runs or {})do local run=changed[run_id]
  if run then local scope,field=metric:match("^(team)_([%w_]+)_mission$");if not scope then scope,field=metric:match("^(teammate)_([%w_]+)_mission$")end
   if scope and not field:find("^boss_")and field~="ritual_stops"then local best,best_run,best_source=0,nil,nil
    for _,candidate in ipairs(self.data.run_history or {})do local c=candidate.context;local rc=row.context
     if c.patch==rc.patch and c.mode==rc.mode and c.class==rc.class and c.character==rc.character and tostring(c.difficulty)==tostring(rc.difficulty)then local inc=candidate.incidents or {}
      if scope=="team"then local value=inc.team and inc.team[field]or 0;if value>best then best=value;best_run=candidate.id;best_source={class=c.class}end
      else for id,p in pairs(inc.members or {})do local value=p.counts and p.counts[field]or 0;if value>best then best=value;best_run=candidate.id;local identity=c.operative_identities and c.operative_identities[id];best_source={class=p.class,friend_name=identity and identity.friend_name}end end end
     end
    end
    row.best[metric]=best;row.best_runs[metric]=best_run;row.best_weapons=row.best_weapons or {};row.best_weapons[metric]=best_source
   end
  end
 end end
 if next(changed)then self.dirty=true end
end
function Records.new(saved)
    assert(not saved or saved.schema == Records.schema, "Unsupported records schema; preserve the saved data.")
    local tracker=setmetatable({ data = saved or {schema = Records.schema, rows = {}}, pending = {}, queue = {}, next_id = 0,
        current = {head_melee = 0, head_ranged = 0, head_combined = 0, dodges = 0, kills = 0, blo = 0}, dirty = false }, Records)
    tracker:normalize_boss_records()
    tracker:remove_known_bots()
    for _,run in ipairs(tracker.data.run_history or {}) do tracker:cache_class_run(run) end
    tracker:initialize_class_win_streaks()
    tracker:initialize_class_mode_streaks()
    tracker:initialize_class_bosses()
    tracker:initialize_maelstrom_streaks()
    tracker:initialize_class_overview()
    tracker:initialize_ally_overview()
    return tracker
end


function Records:is_class_grenade(c)
    return c.grenade==true or (type(c.weapon)=="string" and c.weapon:find("grenade",1,true)~=nil)
end



local survival_events = {
    knocked_down = {current = "undowned_current", best = "undowned_wins"},
    dog_pounced = {current = "unpounced_current", best = "unpounced_wins"},
    trapper_netted = {current = "unnetted_current", best = "unnetted_wins"},
    mutant_charged = {current = "uncharged_current", best = "uncharged_wins"},
}

local Presentation
if mod and mod.io_dofile then
    Presentation=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_presentation")
else
    Presentation=dofile("InformationOverload/scripts/mods/InformationOverload/records_presentation.lua")
end
Presentation(Records)

local Blo
if mod and mod.io_dofile then
    Blo=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_blo")
else
    Blo=dofile("InformationOverload/scripts/mods/InformationOverload/records_blo.lua")
end
Blo(Records,copy,deep_copy,key)

local Incidents
if mod and mod.io_dofile then
    Incidents=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_incidents")
else
    Incidents=dofile("InformationOverload/scripts/mods/InformationOverload/records_incidents.lua")
end
Incidents(Records,deep_copy,key,survival_events)

local Bosses
if mod and mod.io_dofile then
    Bosses=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_bosses")
else
    Bosses=dofile("InformationOverload/scripts/mods/InformationOverload/records_bosses.lua")
end
Bosses(Records)

local Progress
if mod and mod.io_dofile then
    Progress=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_progress")
else
    Progress=dofile("InformationOverload/scripts/mods/InformationOverload/records_progress.lua")
end
Progress(Records,copy)

local Attacks
if mod and mod.io_dofile then
    Attacks=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_attacks")
else
    Attacks=dofile("InformationOverload/scripts/mods/InformationOverload/records_attacks.lua")
end
Attacks(Records,copy,key)

local Missions
if mod and mod.io_dofile then
    Missions=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records_missions")
else
    Missions=dofile("InformationOverload/scripts/mods/InformationOverload/records_missions.lua")
end
Missions(Records,copy,deep_copy,checkpoint_copy,key,fresh_row,survival_events)

return Records



