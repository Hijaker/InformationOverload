-- Information Overload: the End Screen card's figures, in the shape its layout draws: the mission, each operative's plate and card, your
-- averages, the records broken and every down and death. Built once a mission from the debrief's model, the scoreboard's squad rows, the
-- squad's damage and kill tables and the mission clock's minutes.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Team=mod:io_dofile(base.."team_damage")
local Times=mod:io_dofile(base.."mission_times")
local Overview=mod:io_dofile(base.."io_overview")
-- a name that cleans to nothing takes the fallback
local clean;do local c=mod:io_dofile(base.."display_name").clean;clean=function(s)s=c(s);if s~="" then return s end end end
local Icons=mod:io_dofile(base.."weapon_icons")
local Party
local function party_kills(p,counts)Party=Party or mod:io_dofile(base.."party_records");return Party.kills(p,counts)end
local commas=Overview.commas
local X={}
local ARMOUR={unarmored="Unarmoured",disgustingly_resilient="Infested",berserker="Maniac",resistant="Unyielding",armored="Flak",super_armor="Carapace",unknown="Unknown"}
-- the records' short names, as the card's tiles have room for
local SHORT={["Most Damage In A Mission"]="Most Damage",["Most Kills In A Mission"]="Most Kills",["Most Elites In A Mission"]="Most Elites",
 ["Most Specials In A Mission"]="Most Specials",["Most Bosses In A Mission"]="Most Bosses"}
local function short(l)return SHORT[l]or l end
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function day(ts)local _,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");if m and MONTHS[tonumber(m)]then return tonumber(d).." "..MONTHS[tonumber(m)]end end
local function txt(s)return {s=s or "",syn=false}end
local function clock(s)s=math.max(0,math.floor(s));return string.format("%d:%02d",math.floor(s/60),s%60)end
-- a time as the card writes it: the server's to the millisecond, the mission clock's to the second, an estimate to the nearest second with its ~
local function time_text(s,backend,est)if not s then return nil end;if est then return Times.estimate_text(s)end;return backend and Times.format(s)or clock(s)end
-- a figure as the tile rounds it, so the margin is the gap between the two figures shown and a tie shows none
local function shown(s,time,backend,est)if not time then return tonumber(string.format("%.0f",s))end;if est then return math.floor(math.max(0,s)+.5)end;if backend then return math.floor(math.max(0,s)*1000+.5)/1000 end;return math.max(0,math.floor(s))end
-- one record or class best as a tile: the figure, what it beat and by how much, whose and where the old one was
local function entry(tracker,e)
 local t={label=short(e.label),how=e.how}
 if e.time then t.value=time_text(e.v,e.backend,e.est);if e.prev then t.prev=time_text(e.prev,e.backend,e.prev_est);local d=shown(e.prev,true,e.backend,e.prev_est)-shown(e.v,true,e.backend,e.est);if d>0 then t.delta="-"..time_text(d,e.backend,e.est or e.prev_est)end end
 else t.value=commas(e.v);if e.prev then t.prev=commas(e.prev);local d=shown(e.v)-shown(e.prev);if d>0 then t.delta="+"..commas(d)end end end
 local r=e.who;if r then local wc=r.context or {};t.who=txt(clean(wc.character_name)or "Operative");t.date=day(r.started_at);if not e.time then t.mission=txt(tostring(tracker:run_mission_name(wc)))end end
 return t
end
-- an operative's useful damage by armour, largest first, and their melee, ranged, damage over time and other split
local function armour(team,id)
 if not team then return {},{0,0,0,0}end
 local useful=Team.summary(team,id,"total").useful or 0;local list={}
 for key in pairs(Team.armours(team))do local u=Team.summary(team,id,"total",key).useful or 0;if u>0 then list[#list+1]={ARMOUR[key]or "Unknown",u}end end
 table.sort(list,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end);for i=#list,7,-1 do list[i]=nil end
 local mel,ran,dot=Team.summary(team,id,"melee").useful or 0,Team.summary(team,id,"ranged").useful or 0,Team.summary(team,id,"dot").useful or 0
 return list,{mel,ran,dot,math.max(0,useful-mel-ran-dot)}
end
-- an operative's three most killed enemies
local function most(party,id)
 local p=party and party.members and party.members[id];if not p then return {}end
 local by={};for _,k in pairs(party_kills(p,party))do local l=k.label or "Unknown Enemy";by[l]=(by[l]or 0)+(k.count or 0)end
 local list={};for l,v in pairs(by)do if v>0 then list[#list+1]={l,v}end end
 table.sort(list,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end);for i=#list,4,-1 do list[i]=nil end
 return list
end
-- an operative's biggest hits this mission: single target, melee cleave and explosion, nil where they had none
local function hits(party,id)
 local p=party and party.members and party.members[id];local b=p and p.best or {}
 local function v(k)return b[k]and b[k].value and math.floor(b[k].value+.5)or nil end
 -- a match saved before explosions were kept apart holds its biggest explosion as its single-target hit too, so that one is left out
 local single=b.single_hit and b.single_hit.category~="explosion"and v("single_hit")or nil
 return {single=single,cleave=v("melee_cleave"),blast=v("explosive_single_hit")}
end
-- f: the finished mission as the scoreboard holds it; run: its saved copy or nil; D: the debrief's model of it; rows: the scoreboard's squad
-- rows, yours first; team and party: the squad's damage and kill tables; seconds: the mission's length; backend: whether the server timed it
function X.model(tracker,f,run,D,rows,team,party,seconds,backend,counts)
 local src=run or f.m;local c=src.context or f.m.context or {};counts=counts or {}
 local won=D.won;local secs=seconds or 0
 local tt=seconds and (time_text(seconds,backend)..(won and ""or "+"))or "—"
 local M={result=won and "won"or "lost",title=txt(won and "The Emperor Protects"or "Mission Failed"),map=txt(D.map or ""),diff=txt(D.diff or ""),date=D.date or "",secs=secs,server=backend==true,timeText=tt,
  records={},classBests={},roster={},events={},vote={yes={}}}
 -- a saved match keeps the squad's builds in its file
 local mt=getmetatable(src);local L=(mt and mt.io_loadouts and mt.io_loadouts(src)or c.operative_loadouts)or {};local roster=c.operative_roster or {}
 local mins=team and Team.minutes(team,src.timing_origin)
 local idx={}
 M.squad={}
 -- with no squad rows to hand, your own plate from the debrief's figures; damage or kills the match never saved stay unknown, the dash
 local unsaved
 if not rows or #rows==0 then local k,by=D.kills or {},{};for _,row in ipairs(k.rows or {})do by[row[1]]=row[2]end
  unsaved={dmg=not (D.armour or team),kills=type(src.kills)~="number"and type(src.kill_categories)~="table"}
  rows={{id=tostring(c.character),you=true,name=clean(c.character_name)or "Your Operative",class=D.class,damage=D.armour and D.armour.total or 0,kills=k.total or 0,
   lesser=by.Horde or 0,elites=by.Elites or 0,specials=by.Specials or 0,monst=by.Bosses or 0,downs=D.you and D.you[1]or 0,deaths=D.you and D.you[2]or 0,share=1}}
 end
 -- an operative who left having done nothing, such as the slot a bot took over, gets no plate
 local kept={};for _,r in ipairs(rows or {})do if not (r.left and (r.damage or 0)<=0 and (r.kills or 0)<=0)then kept[#kept+1]=r end end;rows=kept
 for i,r in ipairs(rows)do if i>4 then break end
  local lo=L[r.id]or (r.you and (L[tostring(c.character)]or L[c.character_name]))or {}
  local inc=r.you and counts.personal or counts.members and counts.members[r.id]and counts.members[r.id].counts or {}
  local ro=roster[r.id]or roster[tonumber(r.id)or false]or {}
  local op={id=r.id,own=r.you==true,lvl=tonumber(ro.level),name=txt(r.name),acct=(ro.friend_name or ro.steam_name)and txt(ro.friend_name or ro.steam_name)or nil,cls=r.class or "",arch=r.arch,dmg=r.damage or 0,boss=r.boss or 0,ws=r.weak or 0,crit=r.crit or 0,lesser=r.lesser or 0,elites=r.elites or 0,
   specials=r.specials or 0,monst=r.monst or 0,ranged=r.ranged or 0,melee=r.melee or 0,kills=r.kills or 0,downs=r.downs or 0,deaths=r.deaths or 0,share=r.share or 0,
   weapons={melee=type(lo.melee)=="string"and lo.melee~=""and txt(lo.melee)or nil,ranged=type(lo.ranged)=="string"and lo.ranged~=""and txt(lo.ranged)or nil},
   icons={melee=type(lo.melee)=="string"and Icons.of(lo.melee)or nil,ranged=type(lo.ranged)=="string"and Icons.of(lo.ranged)or nil},
   disabled={pounces=inc.pounces or 0,nets=inc.nets or 0,mutant=inc.mutant_charges or 0}}
  local typed=op.lesser+op.elites+op.specials+op.monst
  op.kinds={{"Horde",op.lesser},{"Elites",op.elites},{"Specials",op.specials},{"Bosses",op.monst}}
  if op.kills>typed then op.kinds[5]={"No Type",op.kills-typed}end
  op.armour,op.split=armour(team,r.id)
  op.most=most(party,r.id);op.hits=hits(party,r.id)
  local kd=team and Team.kinds(team,r.id,"useful")
  op.kindDmg=kd and {horde=kd.lesser,elite=kd.elites,special=kd.specials,boss=kd.monst}or nil
  -- in a match that kept its minutes every operative has them, one with none of their own an empty clock, so picking them keeps the clock
  local m=mins and mins.members[r.id];op.minutes=m and {dmg=m.useful,kills=m.kills}or mins and {dmg={},kills={}}or nil
  M.squad[#M.squad+1]=op;idx[r.id]=#M.squad
 end
 if #M.squad==1 then M.squad[1].share=1 end
 if unsaved and M.squad[1]then local o=M.squad[1];if unsaved.dmg then o.dmg,o.share=nil,nil end;if unsaved.kills then o.kills=nil end end
 -- your kills by type against your average there, as the debrief reads them
 local me=M.squad[1]
 if me and D.kills and D.kills.n>0 then local by={}
  for _,row in ipairs(D.kills.rows)do by[row[1]]=row[3]end
  for _,k in ipairs(me.kinds)do k[3]=by[k[1]]end
 end
 -- your averages: the debrief's rows, Boss Damage among them with no average, as no saved match keeps it in memory
 local rows_avg={};local n=0
 for _,r in ipairs(D.avg or {})do local t={l=r.l,text=r.text,off=r.off,good=r.good,delta=r.delta}
  if r.n then n=math.max(n,r.n)end
  if r.mean then t.v,t.mean=r.v,r.mean end
  rows_avg[#rows_avg+1]=t
  if r.l=="Mission Time"and me then rows_avg[#rows_avg+1]={l="Boss Damage",text=commas(me.boss)}end
 end
 M.avg={n=n,rows=rows_avg,mins=D.avg_mins}
 for _,e in ipairs(D.records or {})do M.records[#M.records+1]=entry(tracker,e)end
 for _,e in ipairs(D.class_records or {})do M.classBests[#M.classBests+1]=entry(tracker,e)end
 -- downs and deaths: whose, as a squad index from 1, a left player's 0 and named, on the others' lane
 -- a down that ended in death sits at its down with its death after it, where both times were saved
 local o=type(src.timing_origin)=="number"and src.timing_origin*1000 or 0
 -- an event the debrief could not place keeps no time, so the card shows it in order untimed rather than at 0:00
 for n,e in ipairs(D.events or {})do
  local who=e.you and 1 or (e.id and idx[e.id])or 0;local t,died=type(e.t)=="number"and e.t or nil,nil
  if D.everyone and e.outcome=="down_to_death"and type(e.down_at)=="number"and type(e.died_at)=="number"then t,died=math.max(0,(e.down_at-o)/1000),math.max(0,(e.died_at-o)/1000)end
  M.events[#M.events+1]={who=who,name=who<1 and txt(e.name or "Teammate")or nil,outcome=e.outcome,t=t,diedT=died,n=n,cause=e.what and txt(e.what)or nil}
 end
 table.sort(M.events,function(a,b)if (a.t==nil)~=(b.t==nil)then return b.t==nil end;if a.t and a.t~=b.t then return a.t<b.t end;return a.n<b.n end)
 for _,e in ipairs(M.events)do e.n=nil end
 for id,p in pairs(roster)do if p.left and not idx[tostring(id)]and type(p.name)=="string"then M.roster[#M.roster+1]=txt(clean(p.name)or "Teammate")end end
 M.clock_known=D.clock~=nil
 return M
end
return X
