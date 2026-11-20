-- Information Overload: the End Screen's Mission Debrief figures, read from the run just saved and the history before it; the card lays them out.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Party;local function enemy_kills(p,counts)if not Party and mod and mod.io_dofile then Party=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")end;return Party and Party.kills(p,counts)or p.enemy_kills or {}end
local Records=mod:io_dofile(base.."records")
local Imported=mod:io_dofile(base.."imported_records")
local Overview=mod:io_dofile(base.."io_overview")
local Team=mod:io_dofile(base.."team_damage")
local Times=mod:io_dofile(base.."mission_times")
-- a name that cleans to nothing takes the fallback
local clean;do local c=mod:io_dofile(base.."display_name").clean;clean=function(s)s=c(s);if s~="" then return s end end end
local B={}
local commas,CN=Overview.commas,Overview.class_names
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function day(ts)local _,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");if m and MONTHS[tonumber(m)]then return tonumber(d).." "..MONTHS[tonumber(m)]end end
local function stamp(ts)local d=day(ts);local hm=tostring(ts or ""):match("^%d+%-%d+%-%d+[ T](%d%d:%d%d)");return d and (hm and d..", "..hm or d)end
function B.clock(s)s=math.max(0,math.floor(s));return string.format("%d:%02d",math.floor(s/60),s%60)end
local function useful(run)return (Records.run_useful(run))end
local function kills(run)return type(run.kills)=="number"and run.kills or nil end
local function rec(k)return function(run)local r=run.records;return r and r[k]end end
local function cat(k)return function(run)local c=run.kill_categories;return c and (c[k]or 0)end end
-- the Dossier's bests, each read from what a saved run keeps resident, so no match file is opened; damage is useful damage, as the Dossier's is
B.STATS={{"dmg","Most Damage In A Mission",useful},{"kills","Most Kills In A Mission",kills},{"elites","Most Elites In A Mission",cat("elite")},
 {"specials","Most Specials In A Mission",cat("special")},{"bosses","Most Bosses In A Mission",cat("boss")},{"single","Biggest Single-Target Hit",rec("single_hit")},
 {"cleave","Biggest Melee Cleave",rec("melee_cleave")},{"blast","Biggest Explosion",rec("explosive_hit")},{"dodges","Dodges In A Row",rec("dodges")},
 {"head","Headshots In A Row",rec("head_combined")},{"kir","Kills In A Row",rec("kills")}}
local function best(list,get)local v,who;for _,r in ipairs(list)do local n=get(r);if type(n)=="number"and n>0 and (not v or n>v)then v,who=n,r end end;return v,who end
-- what this run broke: a first or faster clear of its map on its patch, then each best it beat across its mode; a best beaten only within its class goes to the second list
function B.broken(tracker,run,basis)
 local c=run.context or {};local out,cls={}, {};local history=tracker.data.run_history or {}
 -- a match imported from Power DI breaks no record, and is no record to break, unless Imported Matches Count For Records is on
 if not Imported.ranked(run)then return out,cls end
 local function clear(list)local maps=Times.build(list,c.mode,basis)[tostring(c.difficulty)];return maps and maps[c.mission_name]end
 local own=clear({run})
 if own then local before={};for _,r in ipairs(history)do if r.id~=run.id and r.context and r.context.patch==c.patch then before[#before+1]=r end end
  local old=clear(before);local t=own.completion_time.seconds;local o=old and old.completion_time.seconds
  -- the two clocks cannot be compared, so a clear with only the other kind before it on the patch claims no record
  local comparable=not old or (own.completion_time.source=="backend")== (old.completion_time.source=="backend")
  local backend=own.completion_time.source=="backend"
  -- a server-timed clear with only mission-clock clears before it is set against them by its own mission clock, as the Tracker Panel does
  local mine=run.completion_time
  if not comparable and backend and old.completion_time.source~="backend"and type(mine)=="table"and mine.source=="mission_clock"and type(mine.seconds)=="number"then
   comparable,t,backend=true,mine.seconds,false
  end
  -- an imported match's estimate on either side shows marked as one
  local est=t==own.completion_time.seconds and Times.estimate(own)~=nil or nil;local prev_est=old and Times.estimate(old)~=nil or nil
  if comparable and (not o or t<o)then out[1]={key="clear",label="Fastest Clear",v=t,time=true,backend=backend,est=est,prev=o,prev_est=prev_est,who=old,how=not o and "First Clear On This Patch"or nil}end
 end
 if not Overview.accepted(run)then return out,cls end
 local same,mine={}, {}
 for _,r in ipairs(history)do local rc=r.context;if r.id~=run.id and rc and rc.mode==c.mode and Overview.accepted(r)and Imported.ranked(r)then same[#same+1]=r;if rc.class==c.class then mine[#mine+1]=r end end end
 for _,s in ipairs(B.STATS)do local v=s[3](run)
  if type(v)=="number"and v>0 then local p,who=best(same,s[3])
   if p and v>p then out[#out+1]={key=s[1],label=s[2],v=v,prev=p,who=who,how=s[4]}
   else local q,qwho=best(mine,s[3]);if q and v>q then cls[#cls+1]={key=s[1],label=s[2],v=v,prev=q,who=qwho}end end
  end
 end
 return out,cls
end
local ARMOUR={unarmored="Unarmoured",disgustingly_resilient="Infested",berserker="Maniac",resistant="Unyielding",armored="Flak",super_armor="Carapace",unknown="Unknown"}
local function personal(r)if not r.incidents and not r.lethality_events then return nil end;return Records.incident_counts(r).personal or {}end
local function disabled(p)return (p.pounces or 0)+(p.nets or 0)+(p.mutant_charges or 0)end
local function typed(k)return {(k.horde_melee or 0)+(k.horde_ranged or 0),k.elite or 0,k.special or 0,k.boss or 0}end
-- m is the mission just played and run its saved copy, if it was saved; the figures come from the saved run first
-- the downs and deaths at their mission time, a down that ended in death at the death: every one by the time saved with it, or, in a match from
-- before teammates' were saved, the player's own from the damage timeline's resets when it holds every one of them; gives the mission's length
-- to measure them against, and whether everyone's is placed
local function placed(src,ev)
 local o=type(src.timing_origin)=="number"and math.floor(src.timing_origin*1000+.5)or 0
 local tl=type(src.combat_timeline)=="table"and type(src.combat_timeline.segments)=="table"and src.combat_timeline or nil
 local downs,deaths,last,stop={}, {}, {},0
 for _,s in ipairs(tl and tl.segments or {})do if type(s)=="table"and type(s.last_ms)=="number"then stop=math.max(stop,(s.last_ms-o)/1000)end end
 local all=#ev>0;for _,e in ipairs(ev)do if type(e.at)~="number"then all=false end end
 if all then local most=stop;for _,e in ipairs(ev)do e.t=math.max(0,(e.at-o)/1000);most=math.max(most,e.t)end;if most>0 then return most,true end;for _,e in ipairs(ev)do e.t=nil end end
 if not tl then return nil end
 for _,s in ipairs(tl.segments)do if type(s)=="table"then
  for _,e in ipairs(s.streak_events or {})do local k=e[3]=="reset"and (e[4]=="knocked_down"and downs or e[4]=="died"and deaths)
   if k then local t=(e[1]-o)/1000;if not last[k]or t-last[k]>1 then k[#k+1]=t;last[k]=t end end end
 end end
 local di,xi,mine,ok=0,0,0,true
 for _,e in ipairs(ev)do if e.you then mine=mine+1
  if e.outcome=="down"then di=di+1;e.t=downs[di]elseif e.outcome=="down_to_death"then di=di+1;xi=xi+1;e.t=deaths[xi]else xi=xi+1;e.t=deaths[xi]end
  if not e.t then ok=false end;stop=math.max(stop,e.t or 0)end end
 if mine==0 or not ok or di~=#downs or xi~=#deaths or stop<=0 then for _,e in ipairs(ev)do e.t=nil end;return nil end
 return stop
end
function B.model(tracker,m,run,seconds,basis,list,cls)
 local src=run or m;local c=src.context or m.context or {};local history=tracker.data.run_history or {}
 local M={won=run and run.victory==true or not run and m.completion_time~=nil,date=stamp(src.started_at),map=tracker:run_mission_name(c),diff=Overview.diff_label(c),time=seconds and (Times.estimate(src)and Times.estimate_text(seconds)or Times.backend(src)and Times.format(seconds)or B.clock(seconds)),run_id=run and run.id}
 local name=clean(c.character_name)or "Your Operative";M.class=CN[c.class]or "Class";M.who=CN[c.class]and name..", "..M.class or name
 local L=c.operative_loadouts;local lo=L and (L[tostring(c.character)]or L[c.character_name])or {};M.weapons={}
 for _,k in ipairs({"melee","ranged"})do if type(lo[k])=="string"and lo[k]~=""then M.weapons[#M.weapons+1]=lo[k]end end
 local with={};for id,p in pairs(c.operative_roster or {})do if not p.personal and tostring(id)~=tostring(c.character)and type(p.name)=="string"then with[#with+1]=clean(p.name)or "Teammate"end end
 table.sort(with);M.with=with
 M.records,M.class_records={}, {};if run then if list then M.records,M.class_records=list,cls or {}else M.records,M.class_records=B.broken(tracker,run,basis)end end
 -- who held each best before, where and when
 for _,list in ipairs({M.records,M.class_records})do for _,e in ipairs(list)do local r=e.who
  if r then local wc=r.context or {};local d=day(r.started_at);e.tail=", "..(clean(wc.character_name)or "Operative").." On "..tostring(tracker:run_mission_name(wc))..(d and ", "..d or "")end
 end end
 local before={};for _,r in ipairs(history)do if (not run or r.id~=run.id)and r.context and r.context.mode==c.mode and Overview.accepted(r)and Overview.diff_label(r.context)==M.diff then before[#before+1]=r end end
 -- By Enemy Type: your kills against your average at this difficulty
 local total=kills(src);local cur=typed(src.kill_categories or {});local sum=cur[1]+cur[2]+cur[3]+cur[4]
 local tot,n={0,0,0,0,0},0
 for _,r in ipairs(before)do if r.kill_categories and kills(r)then n=n+1;local t=typed(r.kill_categories);for i=1,4 do tot[i]=tot[i]+t[i]end;tot[5]=tot[5]+math.max(0,r.kills-(t[1]+t[2]+t[3]+t[4]))end end
 local rows={};for i,l in ipairs({"Horde","Elites","Specials","Bosses"})do rows[i]={l,cur[i],n>0 and tot[i]/n or nil}end
 local none=total and math.max(0,total-sum)or 0;if none>0 then rows[5]={"No Type",none,n>0 and tot[5]/n or nil}end
 local by={};local ek=src.enemy_kill_counts or m.enemy_kill_counts
 for _,p in pairs(ek and ek.members or {})do if p.personal then for _,k in pairs(enemy_kills(p,ek))do local l=k.label or "Unknown Enemy";by[l]=(by[l]or 0)+(k.count or 0)end end end
 local most={};for l,v in pairs(by)do if v>0 then most[#most+1]={l,v}end end
 table.sort(most,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end);for i=#most,4,-1 do most[i]=nil end
 M.kills={total=total or sum,rows=rows,n=n,most=most}
 -- your useful damage by armour; the one match file this reads is the run's own
 local data=run and Team.from_run(run)or Team.from_run(m)
 if data then local me;for id,p in pairs(data.members or {})do if id~="unknown_operative"and (p.personal==true or tostring(id)==tostring(c.character))then me=id end end
  local useful=me and Team.summary(data,me,"total").useful or 0
  if useful>0 then local list={};for key in pairs(Team.armours(data))do local u=Team.summary(data,me,"total",key).useful;if u>0 then list[#list+1]={ARMOUR[key]or "Unknown",u}end end
   table.sort(list,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end);for i=#list,7,-1 do list[i]=nil end
   local mel,ran,dot=Team.summary(data,me,"melee").useful,Team.summary(data,me,"ranged").useful,Team.summary(data,me,"dot").useful
   M.armour={total=useful,rows=list,split={mel,ran,dot,math.max(0,useful-mel-ran-dot)}}
  end
 end
 -- Against Your Average: left of the tick is worse, right is better, half the line is twice or none of the average
 local sums={};local function add(i,v)if type(v)=="number"then local s=sums[i]or {0,0};s[1]=s[1]+v;s[2]=s[2]+1;sums[i]=s end end
 -- Damage is useful damage, as the armour list beside it is
 for _,r in ipairs(before)do add(1,Records.run_useful(r));add(2,kills(r));local p=personal(r);if p then add(4,p.downs or 0);add(5,p.deaths or 0);add(6,disabled(p))end end
 local p=personal(src);local now={Records.run_useful(src),total,nil,p and (p.downs or 0),p and (p.deaths or 0),p and disabled(p)}
 M.avg={};local any=false
 for i,l in ipairs({"Damage","Kills","Mission Time","Downs","Deaths","Disabled"})do local v,s=now[i],sums[i]
  if i==3 then if seconds then M.avg[#M.avg+1]={l=l,text=Times.estimate(src)and Times.estimate_text(seconds)or Times.backend(src)and Times.format(seconds)or B.clock(seconds)}end
  elseif type(v)=="number"then local r={l=l,text=commas(v)};M.avg[#M.avg+1]=r
   if s and s[2]>0 then any=true;local mean=s[1]/s[2];local d=v-mean;r.v,r.mean=v,mean;local rel=mean>0 and d/mean or (d>0 and 1 or d<0 and -1 or 0)
    local off=math.max(-.5,math.min(.5,rel*.5));if i>2 then off=-off end;r.n=s[2];r.off=off;r.good=off>=0
    if i<=2 then local pc=math.floor(math.abs(rel)*100+.5);r.delta=pc==0 and "Same"or pc.."% "..(d>0 and "More"or "Less")
    else local a=math.floor(math.abs(d)*10+.5)/10;r.delta=a==0 and "Same"or (string.format("%.1f",a):gsub("%.0$","")).." "..(d>0 and "More"or "Less")end
    if r.delta=="Same"then r.good=true end
   end
  end
 end
 M.avg_any=any;M.before=before
 -- the average mission's length in minutes, from those before this one that have a time, for the card's figures a minute
 local tm,tn=0,0;for _,r in ipairs(before)do local t=Times.completion(r);if t and type(t.seconds)=="number"and t.seconds>0 then tm,tn=tm+t.seconds,tn+1 end end;M.avg_mins=tn>0 and tm/tn/60 or nil
 -- Downs And Deaths in the order they were recorded; a down that ended in death is one death, as the counts have it
 local roster,ids=c.operative_roster or {},c.operative_identities or {}
 local function who(id,class)id=tostring(id or "");local q=roster[id]or ids[id]or {};return clean(q.name)or CN[q.class or class]or "Teammate"end
 local ev={};for _,e in ipairs(src.lethality_events or {})do local s=e.sources and e.sources[1]
  ev[#ev+1]={you=e.personal==true,died=e.outcome~="down",outcome=e.outcome,at=e.died_at or e.at,down_at=e.at,died_at=e.died_at,id=e.victim and tostring(e.victim),what=s and s.label or nil,name=e.personal~=true and who(e.victim,e.class)or nil}end
 M.events=ev;M.clock,M.everyone=placed(src,ev)
 local all=Records.incident_counts(src);local own=all.personal or {};local team=all.team
 M.you={own.downs or 0,own.deaths or 0};M.mutant=own.mutant_charges or 0
 if team and team.downs then M.squad={team.downs or 0,team.deaths or 0}
 else local d,x=M.you[1],M.you[2];for _,q in pairs(all.members or {})do local k=q.counts or {};d=d+(k.downs or 0);x=x+(k.deaths or 0)end;M.squad={d,x}end
 return M
end
return B
