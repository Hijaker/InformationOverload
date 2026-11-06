local Grouping=get_mod("information_overload"):io_dofile("InformationOverload/scripts/mods/InformationOverload/enemy_grouping")
-- Rebuildable Steam-account summaries. Match History remains the event source.
local F={}
local I=get_mod("information_overload"):io_dofile("InformationOverload/scripts/mods/InformationOverload/player_identity")
function F.display_name(id,fallback)
 if not tostring(id):find("account:",1,true)and Friends and Friends.name then local name=Friends.name(id);if type(name)=="string"and name~=""then return name end end
 return fallback or "Steam name unavailable"
end
function F.scope(mod)return mod and mod.get and mod:get("friend_stats_scope")or "friends"end
function F.is_friend(id,p)
 if not tostring(id):find("account:",1,true)and Friends and Friends.relationship then return Friends.relationship(id)==Friends.FRIEND end
 return p.friend_name~=nil or p.friend==true
end
function F.people(data)
 local out={};I.learn(data)
 for _,run in ipairs(data.run_history or {})do
  for _,p in pairs(run.context and run.context.operative_roster or {})do if I.key(p)and not p.personal then local id=I.key(p);out[id]={id=id,name=p.steam_name or p.friend_name or p.name or "Steam name unavailable",friend=F.is_friend(id,p)}end end
  for _,p in pairs(run.operative_clutches or {})do if I.key(p)and not p.personal then local id=I.key(p);local row=out[id]or {id=id,name=p.steam_name or p.name or "Steam name unavailable",friend=false};row.name=p.steam_name or row.name;out[id]=row end end
 end
 for id,p in pairs(out)do p.name=I.lookup(data.friend_tracking and data.friend_tracking.aliases or {},id)or F.display_name(id,p.name)end
 return out
end
function F.enabled(data,id,p,scope)
 local policy=data.friend_tracking or {}
 return p.friend or scope~="off"and I.lookup(policy.tracked or {},id)~=nil
end
function F.refresh(tracker,cache,scope)
 local people=F.people(tracker.data);cache=cache or {};local changed=false
 for id,p in pairs(people)do if F.enabled(tracker.data,id,p,scope)then
  local file=cache[id];if file and (file.source_version~=2 or file.policy_revision~=(tracker.data.history_policy_revision or 0))then file=nil;changed=true end;file=file or {source_version=2,name=p.name,patches={},matches={},policy_revision=tracker.data.history_policy_revision or 0};cache[id]=file
  if file.name~=p.name then file.name=p.name;changed=true end
  for _,run in ipairs(tracker.data.run_history or {})do local c=run.context
   if c and not run.stats_excluded and not run.discarded and not run.hidden_contributions and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium"and c.difficulty~="TEST ONLY"and type(run.victory)=="boolean"and not file.matches[tostring(run.id)]then
    local roster,candidate={},nil
    for key,row in pairs(c.operative_roster or {})do if I.matches(row,id) then roster[key]=true;candidate=row end end
    for _,row in pairs(run.operative_clutches or {})do if I.matches(row,id) then candidate=row;if row.character_id then roster[row.character_id]=true end end end
    if candidate then
     file.patches[c.patch]=file.patches[c.patch]or {};local tally=file.patches[c.patch][c.mode]or {};file.patches[c.patch][c.mode]=tally
     local credited={};for k,v in pairs(candidate)do credited[k]=v end;credited.steam_id=id;local temp={context=c,victory=run.victory,operative_clutches={credited}}
     tracker.record_ally_overview({running_tallies=function()return tally end},temp)
     local summary=tally.allies[id];summary.enemies=summary.enemies or {};summary.matches=summary.matches or {};summary.matches[#summary.matches+1]=run.id
     for _,event in ipairs(run.lethality_events or {})do if roster[event.victim]then
      for _,source in ipairs(event.sources or {})do if source.group~="environment"and source.group~="unknown"and source.enemy then
       local e=summary.enemies[source.enemy]or {label=source.label,count=0};summary.enemies[source.enemy]=e;e.count=e.count+1;break
      end end
     end end
     file.matches[tostring(run.id)]={patch=c.patch,mode=c.mode};changed=true
    end
   end
  end
  file.outcome_matches=file.outcome_matches or {}
  for _,run in ipairs(tracker.data.run_history or {})do local c=run.context;local key=tostring(run.id)
   if c and file.matches[key]and not file.outcome_matches[key]and not run.stats_excluded and not run.discarded and not run.hidden_contributions and not run.data_only then
    local roster={};for k,row in pairs(c.operative_roster or {})do if I.matches(row,id) then roster[k]=true end end
    for _,row in pairs(run.operative_clutches or {})do if I.matches(row,id) and row.character_id then roster[row.character_id]=true end end
    local tally=file.patches[c.patch]and file.patches[c.patch][c.mode];local summary=tally and tally.allies and tally.allies[id]
    if summary then for _,event in ipairs(run.lethality_events or {})do if roster[event.victim]then
     for _,source in ipairs(event.sources or {})do if source.group~="environment"and source.group~="unknown"and source.enemy then
      local e=summary.enemies and summary.enemies[source.enemy]
      if e and (event.outcome=="down"or event.outcome=="down_to_death"or event.outcome=="direct_death")then
       e.downs=e.downs or 0;e.deaths=e.deaths or 0
       if event.outcome=="down"then e.downs=e.downs+1 else e.deaths=e.deaths+1 end
      end;break
     end end
    end end end
    file.outcome_matches[key]=true;changed=true
   end
  end
 end end
 return cache,people,changed
end
function F.rows(tracker,cache,patch,mode,scope)
 local rows={};local people=F.people(tracker.data)
 for id,p in pairs(people)do if F.enabled(tracker.data,id,p,scope)then local f=cache[id];local t=f and f.patches[patch]and f.patches[patch][mode];local row=t and t.allies and t.allies[id];if row then rows[#rows+1]={id=id,name=p.name,stats=row,patch=patch,mode=mode}end end end
 table.sort(rows,function(a,b)return a.name<b.name end);return rows
end
function F.lines(row,R,E)
 local s=row.stats;local function rate(x)return x.wins.."/"..x.games.." - "..string.format("%.1f",100*x.wins/x.games):gsub("%.0$","").."%"end
 local lines={row.name,"Winrate With You: "..rate(s)};local best,class
 for id,x in pairs(s.classes or {})do if x.games>=5 and (not best or x.wins*best.games>best.wins*x.games or x.wins*best.games==best.wins*x.games and x.games>best.games)then best=x;class=id end end
 if best then lines[#lines+1]="Most Successful Class: "..R.class_name(class);lines[#lines+1]="Class Winrate: "..rate(best)end
 lines[#lines+1]="";lines[#lines+1]="Clutch Wins: "..(s.clutch_wins or 0)
 for _,kind in ipairs({"full","semi"})do local n=s[kind.."_clutch_wins"]or 0;if n>0 then lines[#lines+1]=(kind=="full"and "Full Clutch Wins"or "Semi-Clutch Wins")..": "..n end end
 for _,k in ipairs({{"clutch_episodes","Most Clutches In One Win","clutch_record_class"},{"full_clutch_episodes","Most Full Clutches In One Win","full_clutch_record_class"},{"semi_clutch_episodes","Most Semi-Clutches In One Win","semi_clutch_record_class"},{"failed_clutches_game","Most Failed Clutches In One Loss","failed_clutch_record_class"}})do if (s[k[1]]or 0)>0 then lines[#lines+1]=k[2]..": "..s[k[1]];lines[#lines+1]="Class: "..R.class_name(s[k[3]])end end
 local lethal=Grouping.summary(Grouping.build(R,row.patch,row.mode,E,row.id))
 if #lethal>0 then lines[#lines+1]="";for _,line in ipairs(lethal)do lines[#lines+1]=line end end
 return lines
end
return F
