local mod=type(get_mod)=="function"and get_mod("information_overload")
if mod and mod.io_enemy_grouping then return mod.io_enemy_grouping end
-- an operative's kills by enemy, as the mission keeps them or as a saved match packs them
local Party;local function enemy_kills(p)if not Party and mod and mod.io_dofile then Party=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")end;return Party and Party.kills(p)or p.enemy_kills or {}end
local G={}
G.groups={{id="normal",label="Trash Enemies"},{id="elite",label="Elites"},{id="special",label="Specials"},{id="boss",label="Bosses"},{id="environment",label="Environment"}}
G.subgroups={normal={{id="ranged",label="Ranged"},{id="bruiser",label="Bruiser"},{id="horde",label="Horde"}},elite={{id="ranged",label="Ranged"},{id="melee",label="Melee"}},boss={{id="monstrosity",label="Monstrosities"},{id="captain",label="Captains"},{id="daemonhost",label="Daemonhosts"}}}
local ranged={cultist_assault=true,renegade_assault=true,renegade_rifleman=true}
local horde={chaos_poxwalker=true,chaos_newly_infected=true}
local captains={hammer_captain=true,sword_captain=true,renegade_captain=true,cultist_captain=true,renegade_twin_captain=true,renegade_twin_captain_two=true}
function G.classify(id,group,is_ranged,attack)
 if group=="boss"then return tostring(id):find("daemonhost",1,true)and "daemonhost"or captains[id]and "captain"or "monstrosity"end
 if group=="elite"then return is_ranged and "ranged"or "melee"end
 if group=="normal"then
  if ranged[id]then return attack=="melee"and "bruiser"or "ranged"end
  return horde[id]and "horde"or "bruiser"
 end
 return group
end
function G.trash_ranged(id,default,observed)if ranged[id]then return observed~="melee"end;return default end
function G.label(group,sub)
 for _,g in ipairs(G.groups)do if g.id==group then if sub then for _,s in ipairs(G.subgroups[group]or {})do if s.id==sub then return g.label.." / "..s.label end end end;return g.label end end
 return "Unknown cause"
end
local cache=setmetatable({},{__mode="k"})
local identity
local function bucket()return {downs=0,deaths=0,total=0,enemies={}}end
local function add(b,outcome,id,label)local key=outcome=="down"and "downs"or "deaths";b[key]=b[key]+1;b.total=b.total+1;if id then local e=b.enemies[id]or {label=label,downs=0,deaths=0,total=0};b.enemies[id]=e;e[key]=e[key]+1;e.total=e.total+1 end end
function G.build(tracker,patch,mode,E,player)
 local data=tracker.data;local rev=tostring(data.run_sequence)..":"..tostring(data.history_policy_revision)..":"..tostring(#(data.run_history or {}))
 local c=cache[tracker];if not c or c.rev~=rev or c.data~=data then c={rev=rev,data=data,values={}};cache[tracker]=c end
 local key=tostring(patch)..":"..tostring(mode)..":"..tostring(player or "personal");if c.values[key]then return c.values[key]end
 local result={all=bucket(),groups={},games=0,killed={}};local catalog=E.catalog();identity=identity or get_mod("information_overload"):io_dofile("InformationOverload/scripts/mods/InformationOverload/player_identity");if player then identity.learn(data)end
 for _,run in ipairs(data.run_history or {})do local ctx=run.context
  if ctx and (patch==nil or ctx.patch==patch)and ctx.mode==mode and not run.stats_excluded and not run.data_only and type(run.victory)=="boolean"then
   local victims={};if player then for id,p in pairs(ctx.operative_roster or {})do if identity.matches(p,player)then victims[id]=true end end;for _,p in pairs(run.operative_clutches or {})do if identity.matches(p,player)and p.character_id then victims[p.character_id]=true end end end
   local present=not player or next(victims)~=nil
   if present then result.games=result.games+1 end
   if present and run.incidents then local counts=tracker.incident_counts(run);local own=not player and counts.personal
    if player then own={downs=0,deaths=0};for id in pairs(victims)do local p=counts.members and counts.members[id];p=p and p.counts;if p then own.downs=own.downs+(p.downs or 0);own.deaths=own.deaths+(p.deaths or 0)end end end
    if own then result.all.downs=result.all.downs+(own.downs or 0);result.all.deaths=result.all.deaths+(own.deaths or 0)end
   end
   for id,p in pairs(run.enemy_kill_counts and run.enemy_kill_counts.members or {})do if not player and p.personal or player and victims[id]then
    for _,k in pairs(enemy_kills(p))do local key=k.enemy..":"..tostring(k.subgroup);local old=result.killed[key]or {enemy=k.enemy,label=k.label,group=k.group,subgroup=k.subgroup,count=0};result.killed[key]=old;old.count=old.count+k.count end
   end end
   for _,event in ipairs(run.lethality_events or {})do if (not player and event.personal or player and victims[event.victim])and (event.outcome=="down"or event.outcome=="direct_death"or event.outcome=="down_to_death")then
    -- One primary cause per event; environmental overlaps remain in raw history.
    local source;for _,s in ipairs(event.sources or {})do if s.group~="environment"and s.group~="unknown"then source=s;break end end;source=source or (event.sources or {})[1]or {enemy="unknown_cause",group="unknown",label="Unknown cause"}
    local entry=catalog[source.enemy]or {};local group=source.group or entry.group or "unknown";local sub=source.subgroup or G.classify(source.enemy,group,entry.horde_type=="ranged"or source.horde_type=="ranged",source.attack_type)
    local g=result.groups[group];if not g then g=bucket();g.subgroups={};result.groups[group]=g end
    local s=g.subgroups[sub];if not s then s=bucket();g.subgroups[sub]=s end
    local name=E.name(source.label or source.enemy);add(g,event.outcome,source.enemy,name);add(s,event.outcome,source.enemy,name)
    -- Retain the existing fall/barrel overlap, without counting the event twice in overall totals.
    for _,extra in ipairs(event.sources or {})do if extra.group=="environment"and extra.enemy~=source.enemy then
     local env=result.groups.environment;if not env then env=bucket();env.subgroups={};result.groups.environment=env end
     env.subgroups.environment=env.subgroups.environment or bucket();local label=E.name(extra.label or extra.enemy)
     add(env,event.outcome,extra.enemy,label);add(env.subgroups.environment,event.outcome,extra.enemy,label)
    end end
   end end
  end
 end
 result.all.total=result.all.downs+result.all.deaths;if (c.count or 0)>=12 then c.values={};c.count=0 end;c.values[key]=result;c.count=(c.count or 0)+1;return result
end
function G.best(data)
 local best
 local function consider(label,b)if b.total>0 and (not best or b.total>best.total or b.total==best.total and label<best.label)then best={label=label,downs=b.downs,deaths=b.deaths,total=b.total}end end
 for id,g in pairs(data.groups)do if id~="environment"and id~="unknown"then
  if G.subgroups[id]then for sub,b in pairs(g.subgroups)do consider(G.label(id,sub),b)end
  else for _,e in pairs(g.enemies)do consider(e.label,e)end end
 end end
 return best
end
local function num(n)return string.format("%.1f",n):gsub(",","."):gsub("%.0$","")end
function G.stat(label,n,total)return label..": "..n..(total and total>0 and " - "..num(n/total*100).."%"or "")end
function G.summary(data)
 local b=G.best(data);if not b then return {}end
 local lines={"Most Lethal Enemy: "..b.label,G.stat("Downs",b.downs,data.all.downs),G.stat("Deaths",b.deaths,data.all.deaths),G.stat("Total",b.total,data.all.total)};return lines
end
if mod then mod.io_enemy_grouping=G end
return G
