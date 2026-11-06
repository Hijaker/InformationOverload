local mod=get_mod("information_overload")
local Roster=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/operative_roster")
local Identity=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/player_identity")
local P={}
local gold="{#color(221,183,99)}";local reset="{#reset()}"
-- the oldest matches saved no identities, only each teammate's character name and class: a class held by one teammate and one listed player names that player, and a teammate no listed player can be is listed by name
local function teammates(c,members)
    local named,extra,names,held={},{},{},{}
    if type(c.teammates)~="table"or next(c.operative_identities or {})or next(c.operative_roster or {})then return named,extra end
    for name,class in pairs(c.teammates)do if type(name)=="string"and name~=c.character_name and type(class)=="string"and not name:find("[BOT]",1,true)then names[class]=names[class]or {};table.insert(names[class],name)end end
    for id,m in pairs(members or {})do id=tostring(id);if type(m)=="table"and type(m.class)=="string"and id~="unknown_operative"and not id:find("bot_%d+$")then held[m.class]=held[m.class]or {};table.insert(held[m.class],id)end end
    for class,list in pairs(names)do local ids=held[class]
        if not ids then for _,name in ipairs(list)do extra[name]=class end elseif #ids==1 and #list==1 then named[ids[1]]=list[1]end
    end
    return named,extra
end
function P.people(run,R)
    local c=run.context;local stats=R.incident_counts and R.incident_counts(run)or run.incidents or {personal={},members={}}
    local named,extra=teammates(c,stats.members)
    local list={{name=c.character_name or "Your operative",counts=stats.personal or {},personal=true}}
    for id,person in pairs(stats.members or {}) do
        local identity=c.operative_identities and c.operative_identities[id]
        if not identity or not (identity.human==false or identity.is_bot or identity.name and identity.name:find("[BOT]",1,true))then list[#list+1]={name=identity and identity.name or named[tostring(id)]or R.class_name(person.class),counts=person.counts or {},id=id,class=person.class,character=named[tostring(id)]}end
    end
    local known={};for _,p in ipairs(list) do if p.id then known[p.id]=true end end
    for id,identity in pairs(c.operative_identities or {}) do if not identity.personal and not known[id] and identity.human~=false and not identity.is_bot and not (identity.name and identity.name:find("[BOT]",1,true))then list[#list+1]={name=identity.name or R.class_name(identity.class),id=id,counts={}} end end
    for name,class in pairs(extra)do list[#list+1]={name=name,id=name,class=class,counts={},character=name}end
    table.sort(list,function(a,b)if a.personal~=b.personal then return a.personal==true end;return a.name<b.name end)
    for _,p in ipairs(list)do p.name=P.name(c,p.personal and tostring(c.character)or p.id,R,p.class,p.character)end
    return list
end
function P.name(c,id,R,fallback,character)
 id=tostring(id or "");if id=="unknown_operative"then return "Unknown Operative"end;local saved=c.operative_identities and c.operative_identities[id]or {};local roster=c.operative_roster and c.operative_roster[id]or {};local identity={}
 for k,v in pairs(roster)do identity[k]=v end;for k,v in pairs(saved)do identity[k]=v end
 identity.name=identity.name or character or id==tostring(c.character)and c.character_name or nil
 if not (identity.name or identity.steam_name or identity.friend_name)then identity.name=id==tostring(c.character)and "Your Operative"or "Name unavailable"end
 identity.class=identity.class or fallback or (id==tostring(c.character)and c.class)
 -- a tracked player goes by Steam name as a friend does, as Match History's Played With names them, Steam read by the id another match tied their account to
 local data=type(R)=="table"and R.data;if data then Identity.learn(data)end
 local key=Identity.key(identity);if key and not key:find(":",1,true)then identity.steam_id=identity.steam_id or key end
 local tracked=data and data.friend_tracking and data.friend_tracking.tracked
 return Roster.label(identity,R,key and tracked and Identity.lookup(tracked,key)and true)
end
function P.friendly_fire(R,index)
 local run=R.data.run_history[tonumber(index)];if not run then return {"Choose A Mission."}end
 local c=run.context;local lines={"Friendly Fire"};local people=P.people(run,R);local seen={}
 if run.friendly_fire_pairs and run.friendly_fire_pairs.unknown_operative then local counts={friendly_fire=0,murders=0,suicides=0};for _,row in pairs(run.friendly_fire_pairs.unknown_operative)do counts.friendly_fire=counts.friendly_fire+(row.damage or 0);counts.murders=counts.murders+(row.murders or 0);counts.suicides=counts.suicides+(row.suicides or 0)end;people[#people+1]={id="unknown_operative",name="Unknown Operative",counts=counts}end
 local capture=c.detail_capture and c.detail_capture.friendly_fire;local incomplete=run.resumed==true or run.interrupted==true or run.detail_incomplete and run.detail_incomplete.friendly_fire
 for _,p in ipairs(people)do local id=p.personal and tostring(c.character)or p.id;local sums={damage=0,murders=0,suicides=0};for _,pair in pairs(run.friendly_fire_pairs and run.friendly_fire_pairs[id]or {})do for field in pairs(sums)do sums[field]=sums[field]+(pair[field]or 0)end end
 if (p.counts.friendly_fire or 0)>sums.damage+.01 or (p.counts.murders or 0)>sums.murders or (p.counts.suicides or 0)>sums.suicides then incomplete=true end end
 local pair_damage=0;for _,victims in pairs(run.friendly_fire_pairs or {})do for _,row in pairs(victims)do pair_damage=pair_damage+(row.damage or 0)end end;if (run.incidents and run.incidents.team and run.incidents.team.friendly_fire or 0)>pair_damage+.01 then incomplete=true end
 if incomplete then lines[#lines+1]="Friendly Fire data is incomplete for this match"end
 for _,p in ipairs(people)do
  local id=p.personal and tostring(c.character)or p.id;seen[id]=true
  lines[#lines+1]="";lines[#lines+1]=gold..p.name..reset;lines[#lines+1]="Friendly Fire: "..string.format("%.0f",p.counts.friendly_fire or 0)
  local rows={};for victim,row in pairs(run.friendly_fire_pairs and run.friendly_fire_pairs[id]or {})do rows[#rows+1]={name=P.name(c,victim,R),row=row}end;table.sort(rows,function(a,b)return a.name<b.name end)
  for _,e in ipairs(rows)do local row=e.row;lines[#lines+1]="  "..e.name;if (row.damage or 0)>0 then lines[#lines+1]="  Damage: "..string.format("%.0f",row.damage)end;if (row.murders or 0)>0 then lines[#lines+1]="  Murders: "..row.murders end;if (row.suicides or 0)>0 then lines[#lines+1]="  Suicides: "..row.suicides end end
  if #rows==0 then if (p.counts.murders or 0)>0 then lines[#lines+1]="Murders: "..p.counts.murders end;if (p.counts.suicides or 0)>0 then lines[#lines+1]="Suicides: "..p.counts.suicides end end
 end
 return lines
end
function P.deaths(R,index)
 local run=R.data.run_history[tonumber(index)];if not run then return {"Choose A Mission."}end
 local c=run.context;local grouped,unknown={},{}
 local function missing(name,field,n)if n>0 then unknown[name]=unknown[name]or {};unknown[name][field]=(unknown[name][field]or 0)+n end end
 for _,e in ipairs(run.lethality_events or {})do
  local name=P.name(c,e.personal and tostring(c.character)or e.victim,R,e.class);local known=false
  for _,source in ipairs(e.sources or {})do local label=source.label or "Unknown Cause";local is_unknown=source.group=="unknown"or source.enemy=="unknown_cause"or label:lower()=="unknown cause"
   if not is_unknown then known=true;grouped[name]=grouped[name]or {};local group=grouped[name];local counts=group[label]or {downs=0,deaths=0};group[label]=counts;if e.outcome=="down"then counts.downs=counts.downs+1 else counts.deaths=counts.deaths+1 end end
  end
  if not known then missing(name,e.outcome=="down"and "downs"or "deaths",1)end
 end
 local people=P.people(run,R);local pickups=run.incidents and run.incidents.team and run.incidents.team.pickups or 0
 local capture=c.detail_capture and c.detail_capture.pickups;local incomplete=run.resumed==true or run.interrupted==true or run.detail_incomplete and run.detail_incomplete.pickups
 local linked,known_states=0,0
 for actor,targets in pairs(run.pickup_pairs or {})do for victim,n in pairs(targets)do linked=linked+n;local state=run.pickup_states and run.pickup_states[actor]and run.pickup_states[actor][victim];known_states=known_states+(state and ((state.knocked_down or 0)+(state.hogtied or 0)+(state.unknown or 0))or 0)end end
 local bots=run.incidents and run.incidents.bot_pickups or 0
 local unattributed=run.incidents and run.incidents.unattributed_pickups or 0
 if pickups>0 and (known_states<linked or linked+bots+(capture and unattributed or 0)<pickups)then incomplete=true end
 local lines={"Death Stats"};if incomplete then lines[#lines+1]="Pickup-data incomplete for this match"end
 local names={};for name in pairs(grouped)do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names)do lines[#lines+1]="";lines[#lines+1]=gold..name..reset;local enemies={};for enemy in pairs(grouped[name])do enemies[#enemies+1]=enemy end;table.sort(enemies)
  for _,enemy in ipairs(enemies)do local e=grouped[name][enemy];lines[#lines+1]=enemy;if e.downs>0 then lines[#lines+1]="Downs: "..e.downs end;if e.deaths>0 then lines[#lines+1]="Deaths: "..e.deaths end;lines[#lines+1]=""end
 end
 if #names==0 and not next(unknown)then lines[#lines+1]="No Enemy Death Records."end
 lines[#lines+1]="";lines[#lines+1]="Pickups: "..pickups..(bots>0 and " ("..bots.." by bot)"or "")
 local actors={};for actor in pairs(run.pickup_pairs or {})do actors[#actors+1]=actor end;table.sort(actors,function(a,b)return P.name(c,a,R)<P.name(c,b,R)end)
 for _,actor in ipairs(actors)do local actor_name=P.name(c,actor,R);local targets={}
  for target,n in pairs(run.pickup_pairs[actor])do local state=run.pickup_states and run.pickup_states[actor]and run.pickup_states[actor][target];local identified=c.operative_identities and c.operative_identities[target]or c.operative_roster and c.operative_roster[target]or tostring(target)==tostring(c.character)
   if not identified or state and (state.unknown or 0)==n then missing(actor_name,"pickups",n)else targets[#targets+1]={name=P.name(c,target,R),count=n,state=state}end
  end
  table.sort(targets,function(a,b)return a.name<b.name end)
  if #targets>0 then lines[#lines+1]=gold..actor_name..reset end
  for _,target in ipairs(targets)do lines[#lines+1]="  "..target.name;if target.state then if (target.state.knocked_down or 0)>0 then lines[#lines+1]="  Down Pickups: "..target.state.knocked_down end;if (target.state.hogtied or 0)>0 then lines[#lines+1]="  Hogtie Pickups: "..target.state.hogtied end;if (target.state.unknown or 0)>0 then missing(actor_name,"pickups",target.state.unknown)end else lines[#lines+1]="  Pickups: "..target.count end end
  lines[#lines+1]=""
 end
 for _,person in ipairs(people)do local id=person.personal and tostring(c.character)or person.id;local paired=0;for _,n in pairs(run.pickup_pairs and run.pickup_pairs[id]or {})do paired=paired+n end;missing(person.name,"pickups",math.max(0,(person.counts.pickups or 0)-paired))end
 missing("Unknown Operative","pickups",run.incidents and run.incidents.unattributed_pickups or 0)
 if next(unknown)then lines[#lines+1]="";lines[#lines+1]="Unknown Deaths/Pickups:";local names={};for name in pairs(unknown)do names[#names+1]=name end;table.sort(names)
  for _,name in ipairs(names)do lines[#lines+1]="";lines[#lines+1]=gold..name..reset;local values=unknown[name];for _,field in ipairs({{"downs","Down"},{"deaths","Death"},{"pickups","Pickup"}})do local n=values[field[1]]or 0;if n>0 then lines[#lines+1]=n.." "..field[2]..(n~=1 and "s"or "")end end end
 end
 return lines
end
return P
