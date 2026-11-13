-- Information Overload: the End Screen's Mission Debrief, read from the run just saved and the history before it, and laid out in the mockup's own units.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Party;local function enemy_kills(p)if not Party and mod and mod.io_dofile then Party=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")end;return Party and Party.kills(p)or p.enemy_kills or {}end
local Records=mod:io_dofile(base.."records")
local Overview=mod:io_dofile(base.."io_overview")
local Team=mod:io_dofile(base.."team_damage")
local Times=mod:io_dofile(base.."mission_times")
local clean=mod:io_dofile(base.."display_name").clean
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
 local function clear(list)local maps=Times.build(list,c.mode,basis)[tostring(c.difficulty)];return maps and maps[c.mission_name]end
 local own=clear({run})
 if own then local before={};for _,r in ipairs(history)do if r.id~=run.id and r.context and r.context.patch==c.patch then before[#before+1]=r end end
  local old=clear(before);local t=own.completion_time.seconds;local o=old and old.completion_time.seconds
  -- the two clocks cannot be compared, so a clear with only the other kind before it on the patch claims no record
  local comparable=not old or (own.completion_time.source=="backend")== (old.completion_time.source=="backend")
  if comparable and (not o or t<o)then out[1]={key="clear",label="Fastest Clear",v=t,time=true,backend=own.completion_time.source=="backend",prev=o,who=old,how=not o and "First Clear On This Patch"or nil}end
 end
 if not Overview.accepted(run)then return out,cls end
 local same,mine={}, {}
 for _,r in ipairs(history)do local rc=r.context;if r.id~=run.id and rc and rc.mode==c.mode and r.contributions and Overview.accepted(r)then same[#same+1]=r;if rc.class==c.class then mine[#mine+1]=r end end end
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
 local M={won=run and run.victory==true or not run and m.completion_time~=nil,date=stamp(src.started_at),map=tracker:run_mission_name(c),diff=Overview.diff_label(c),time=seconds and (Times.backend(src)and Times.format(seconds)or B.clock(seconds)),run_id=run and run.id}
 local name=clean(c.character_name)or "Your Operative";M.class=CN[c.class]or "Class";M.who=CN[c.class]and name..", "..M.class or name
 local L=c.operative_loadouts;local lo=L and (L[tostring(c.character)]or L[c.character_name])or {};M.weapons={}
 for _,k in ipairs({"melee","ranged"})do if type(lo[k])=="string"and lo[k]~=""then M.weapons[#M.weapons+1]=lo[k]end end
 local with={};for id,p in pairs(c.operative_roster or {})do if not p.personal and tostring(id)~=tostring(c.character)and type(p.name)=="string"then with[#with+1]=clean(p.name)end end
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
 for _,p in pairs(ek and ek.members or {})do if p.personal then for _,k in pairs(enemy_kills(p))do local l=k.label or "Unknown Enemy";by[l]=(by[l]or 0)+(k.count or 0)end end end
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
  if i==3 then if seconds then M.avg[#M.avg+1]={l=l,text=Times.backend(src)and Times.format(seconds)or B.clock(seconds)}end
  elseif type(v)=="number"then local r={l=l,text=commas(v)};M.avg[#M.avg+1]=r
   if s and s[2]>0 then any=true;local mean=s[1]/s[2];local d=v-mean;local rel=mean>0 and d/mean or (d>0 and 1 or d<0 and -1 or 0)
    local off=math.max(-.5,math.min(.5,rel*.5));if i>2 then off=-off end;r.n=s[2];r.off=off;r.good=off>=0
    if i<=2 then local pc=math.floor(math.abs(rel)*100+.5);r.delta=pc==0 and "Same"or pc.."% "..(d>0 and "More"or "Less")
    else local a=math.floor(math.abs(d)*10+.5)/10;r.delta=a==0 and "Same"or (string.format("%.1f",a):gsub("%.0$","")).." "..(d>0 and "More"or "Less")end
    if r.delta=="Same"then r.good=true end
   end
  end
 end
 M.avg_any=any
 -- Downs And Deaths in the order they were recorded; a down that ended in death is one death, as the counts have it
 local roster,ids=c.operative_roster or {},c.operative_identities or {}
 local function who(id,class)id=tostring(id or "");local q=roster[id]or ids[id]or {};return clean(q.name)or CN[q.class or class]or "Teammate"end
 local ev={};for _,e in ipairs(src.lethality_events or {})do local s=e.sources and e.sources[1]
  ev[#ev+1]={you=e.personal==true,died=e.outcome~="down",outcome=e.outcome,at=e.died_at or e.at,what=s and s.label or nil,name=e.personal~=true and who(e.victim,e.class)or nil}end
 M.events=ev;M.clock,M.everyone=placed(src,ev)
 local all=Records.incident_counts(src);local own=all.personal or {};local team=all.team
 M.you={own.downs or 0,own.deaths or 0};M.mutant=own.mutant_charges or 0
 if team and team.downs then M.squad={team.downs or 0,team.deaths or 0}
 else local d,x=M.you[1],M.you[2];for _,q in pairs(all.members or {})do local k=q.counts or {};d=d+(k.downs or 0);x=x+(k.deaths or 0)end;M.squad={d,x}end
 return M
end
local function rgba(r,g,b,a)return {math.floor((a or 1)*255+.5),r,g,b}end
B.c={frame=rgba(60,78,57),soft=rgba(60,78,57,.55),line=rgba(60,78,57,.45),lane=rgba(60,78,57,.7),track=rgba(60,78,57,.35),body=rgba(169,191,153),dim=rgba(116,134,108),faint=rgba(78,94,74),
 value=rgba(216,229,207),gold=rgba(201,162,90),gold_soft=rgba(201,162,90,.5),gold_tint=rgba(201,162,90,.06),rust=rgba(184,96,74),panel=rgba(16,22,17,.72),dark=rgba(9,13,10),
 good=rgba(216,229,207,.45),bad=rgba(184,96,74,.55),tint=rgba(216,229,207,.05),preview=rgba(9,13,10,.76),pinned=rgba(9,13,10),edge=rgba(92,116,86),accent=rgba(169,191,153,.55),
 back=rgba(152,152,150),back_hover=rgba(238,236,228)}
B.font={display="machine_medium",text="proxima_nova_medium",bold="proxima_nova_bold"}
-- the card is 1272 by 824 with the 40 high bar under it; Downs And Deaths off takes its 140 out
B.W,B.H,B.BAR,B.TL=1272,824,40,140
-- ops in card units: rects, texts and circles, each with a layer; measure(s,size,font) gives a width in the same units
function B.layout(M,measure,downs)
 local C,F=B.c,B.font;local L={};local hot={}
 local function rect(x,y,w,h,c,l)if w>0 and h>0 then L[#L+1]={t="r",x=x,y=y,w=w,h=h,c=c,l=l or 1}end end
 local function edges(x,y,w,h,c,l)rect(x,y,w,1,c,l);rect(x,y+h-1,w,1,c,l);rect(x,y+1,1,h-2,c,l);rect(x+w-1,y+1,1,h-2,c,l)end
 local function text(s,x,y,w,h,size,c,font,align)L[#L+1]={t="t",s=s,x=x,y=y,w=w,h=h,size=size,c=c,font=font or F.text,align=align or "left",l=5}end
 local function dot(x,y,r,c,l)L[#L+1]={t="o",x=x,y=y,r=r,c=c,l=l or 3}end
 local function wid(s,size,font)return measure(s,size,font or F.text)end
 local function fit(s,size,w,font)
  if wid(s,size,font)<=w then return s,size end;local sz=size*.88;if wid(s,sz,font)<=w then return s,sz end
  for n=#s-1,1,-1 do local b=s:byte(n+1);if b<128 or b>=192 then local t=s:sub(1,n):gsub("[%s,]+$","").."…";if wid(t,sz,font)<=w then return t,sz end end end;return "…",sz
 end
 -- a line of parts {s,size,colour,font,gap before}, cut at max; the gaps are spaces of their own, since a measure may drop a part's edge spaces,
 -- and each part's box runs on to the line's end, since one cut to the measured width lets the game wrap a number like 111 as 11 over 1
 local function span(parts)local t=0;for _,p in ipairs(parts)do t=t+(p[5]or 0)+wid(p[1],p[2],p[4])end;return t end
 local function line(parts,x,y,h,max)
  local stop=max and x+max
  for _,p in ipairs(parts)do x=x+(p[5]or 0);local s,size,w=p[1],p[2],wid(p[1],p[2],p[4])
   if stop and x+w>stop then s,size=fit(s,size,stop-x,p[4]);if stop-x>8 then text(s,x,y,stop-x,h,size,p[3],p[4])end;return stop end
   text(s,x,y,stop and stop-x or w+40,h,size,p[3],p[4]);x=x+w
  end
  return x
 end
 local function h2(s,x,y)text(s,x,y,600,19,19,C.value,F.display)return wid(s,19,F.display)end
 local function panel(x,y,w,h)rect(x,y,w,h,C.panel,1);edges(x,y,w,h,C.soft,2)end
 local function was(e,x,y,w)line({{"Was",12,C.dim},{e.time and (e.backend and Times.format(e.prev)or B.clock(e.prev))or commas(e.prev),13.5,C.body,F.display,4},{e.tail or "",12,C.dim}},x,y,14,w)end
 -- header
 local res=M.won and "Mission Won"or "Mission Failed";local rw=wid(res,15,F.bold)+35
 rect(27,21,rw,26,C.tint,2);edges(27,21,rw,26,C.frame,3);rect(36,30,8,8,M.won and C.value or C.rust,3);text(res,52,21,rw-25,26,15,C.value,F.bold)
 local ex=27+rw+16;text("Mission Debrief",ex,21,200,26,15,C.dim);ex=ex+wid("Mission Debrief",15)+16;if M.date then text(M.date,ex,21,200,26,15,C.dim)end
 -- the big figures get room past their measured width, since the game wraps a text at any character once it overruns its box by a hair
 local tw=M.time and wid(M.time,76,F.display)or 0
 if M.time then text(M.time,1245-tw-60,21,tw+60,62,76,C.value,F.display,"right");text("Mission Time",880,58,1245-tw-18-880,16,14,C.dim,F.bold,"right")end
 local title,ts=fit(M.map or "",50,1245-27-tw-130,F.display);text(title,27,56,1245-27-tw-120,50,ts,C.value,F.display)
 local sub={M.diff,M.who};for _,w in ipairs(M.weapons)do sub[#sub+1]=w end
 local parts={};for i,s in ipairs(sub)do parts[#parts+1]={s,13.5,C.body,nil,i>1 and 16 or 0}end
 if #M.with>0 then parts[#parts+1]={"With "..table.concat(M.with,", "),13.5,C.dim,nil,16}end
 line(parts,27,114,16,1218)
 rect(27,135,1218,1,C.frame)
 -- Records Broken This Run
 h2("Records Broken This Run",27,150);local list=M.records
 if #list>0 then text(#list.." New",1045,150,200,19,12,C.dim,nil,"right")end
 for i=1,math.min(3,#list)do local e,x=list[i],27+(i-1)*306
  rect(x,179,292,174,C.gold_tint,1);edges(x,179,292,174,C.gold_soft,2);rect(x,179,3,174,C.gold,3)
  text("Best On Any Operative",x+17,192,258,15,13,C.gold,F.bold)
  local what,ws=fit(e.label,14,258);text(what,x+17,212,258,16,ws,C.value)
  local big=e.time and (e.backend and Times.format(e.v)or B.clock(e.v))or commas(e.v);local bs=56;if wid(big,56,F.display)>170 then bs=46 end;local bw=wid(big,bs,F.display)
  text(big,x+17,230,258,bs,bs,C.gold,F.display)
  if e.prev then local up=e.time and "-"..(e.backend and Times.format(e.prev-e.v)or B.clock(e.prev-e.v))or "+"..commas(e.v-e.prev);text(up,x+17+bw+12,230+bs-20,258-bw-12,16,16,C.gold,F.display)end
  local y=230+bs+4;if e.how then local how,hs=fit(e.how,12.5,258);text(how,x+17,y,258,15,hs,C.body);y=y+18 end
  if e.prev then was(e,x+17,y,258)end
 end
 if #list==0 then text("No Record Fell This Run",27,192,600,15,12.5,C.dim)end
 panel(945,179,300,174);text(M.class.." Bests",962,193,268,15,13,C.dim,F.bold)
 local cls=M.class_records
 if #cls==0 then rect(962,212,268,1,C.line,3);local s,sz=fit("No Other "..M.class.." Best Fell This Run",12.5,268);text(s,962,219,268,15,sz,C.dim)end
 for i=1,math.min(2,#cls)do local e,y=cls[i],212+(i-1)*50
  rect(962,y,268,1,C.line,3);local v=commas(e.v);local vw=wid(v,21,F.display);local l,ls=fit(e.label,13,262-vw);text(l,962,y+7,262-vw,15,ls,C.body)
  text(v,962,y+4,268,22,21,C.gold,F.display,"right");was(e,962,y+31,268)
 end
 -- By Enemy Type
 panel(27,367,704,252);h2("By Enemy Type",44,381);local K=M.kills
 text("Kills",44,412,100,16,13,C.dim,F.bold);text(commas(K.total),244,412,100,16,13.5,C.body,F.display,"right")
 -- the tick note goes under the kills rows, the only bars with ticks, and is left out rather than cut; Most Killed moves down under it, closing up
 -- only as far as it takes to end by 617, the panel's foot being 619, and five rows give up a pixel each when three entries would not fit
 -- the note comes down half a size at a time as far as 9 to fit its 300, and is left out only if it still does not fit
 local note;if K.n>0 then local s,sz="Tick Marks Your "..M.diff.." Average Over "..K.n..(K.n==1 and " Mission"or " Missions"),12
  while sz>9 and wid(s,sz)>300 do sz=sz-.5 end;if wid(s,sz)<=300 then note={s,sz}end end
 local rh=#K.rows==5 and 22 or 26;if note and #K.rows==5 and #K.most>=3 then rh=21 end
 local top=0;for _,r in ipairs(K.rows)do top=math.max(top,r[2])end
 for i,r in ipairs(K.rows)do local y=436+(i-1)*rh;local cy=y+rh/2;local m=r[3]and math.max(r[2],r[3])or top
  text(r[1],44,y,72,rh,13,C.body);rect(126,cy-3,166,6,C.track,2)
  if m>0 then local k=r[3]and .87 or 1;if r[2]>0 then rect(126,cy-4,math.max(1,166*k*r[2]/m),8,C.body,3)end
   if r[3]then local tx=126+166*k*r[3]/m;rect(tx-2,cy-9,4,18,C.dark,3);rect(tx-1,cy-8,2,16,C.value,4)end end
  text(commas(r[2]),262,y,82,rh,19,C.value,F.display,"right")
 end
 local my=436+#K.rows*rh;if note then text(note[1],44,my+4,300,14,note[2],C.dim);my=my+22 else my=my+9 end
 if #K.most>0 then local mx=44+wid("Most Killed",12)+12;local step=note and #K.most>1 and math.min(17,(617-15-my-9)/(#K.most-1))or 17
  rect(44,my,300,1,C.line,3);text("Most Killed",44,my+9,mx-44,15,12,C.dim)
  for i,e in ipairs(K.most)do line({{e[1],12,C.body,F.bold},{commas(e[2]),13.5,C.value,F.display,4}},mx,my+9+(i-1)*step,15,344-mx)end
 end
 text("Useful Damage By Armour",370,412,240,16,13,C.dim,F.bold);local A=M.armour
 if A then text(commas(A.total),514,412,200,16,13.5,C.body,F.display,"right")
  local first=A.rows[1]and A.rows[1][2]or 1
  -- each armour's share of the whole, small beside its number, as the bars only measure against the biggest
  for i,r in ipairs(A.rows)do local y=436+(i-1)*20;text(r[1],370,y,84,20,12.5,C.body);rect(464,y+6.5,math.max(1,120*r[2]/first),7,C.body,3)
   text(math.floor(100*r[2]/A.total+.5).."%",588,y,44,20,12.5,C.dim,nil,"right");text(commas(r[2]),598,y,116,20,15,C.value,F.display,"right")end
  local sy=436+#A.rows*20+9;local cols={C.value,C.body,C.faint,C.dim};local sx=370
  for i,v in ipairs(A.split)do local w=(344-6)*v/A.total;if w>0 then rect(sx,sy,w,6,cols[i],3)end;sx=sx+w+2 end
  local labs={};for i,l in ipairs({"Melee","Ranged","Damage Over Time","Other"})do labs[i]={{l,11.5,C.body,F.bold},{math.floor(100*A.split[i]/A.total+.5).."%",11.5,C.dim,nil,4}}end
  local widths,sum={},0;for i,p in ipairs(labs)do widths[i]=span(p);sum=sum+widths[i]end
  local gap=math.max(4,(344-sum)/3);local lx=370;for i,p in ipairs(labs)do line(p,lx,sy+11,13);lx=lx+widths[i]+gap end
 else text("No Damage Recorded",370,436,300,20,12.5,C.dim)end
 -- Against Your Average
 panel(745,367,500,252);local aw=1229-762-12-h2("Against Your "..M.diff.." Average",762,381)
 -- an aside that will not fit whole beside its heading is left out rather than cut
 if M.avg_any then local s,sz=fit("Your "..M.diff.." Missions Before This One",12,aw);if s:sub(-3)~="…"then text(s,1229-aw,383,aw,16,sz,C.dim,nil,"right")end end
 for i,r in ipairs(M.avg)do local y=412+(i-1)*30;rect(762,y,467,1,C.line,3)
  if r.n then text(r.l,762,y+1,76,15,13,C.body);text(r.n..(r.n==1 and " Mission"or " Missions"),762,y+16,76,12,10.5,C.dim)else text(r.l,762,y,90,30,13,C.body)end
  if r.off then local cy=y+15;local me=850+181*(.5+r.off);rect(850,cy-.5,181,1,C.frame,2)
   rect(math.min(940.5,me),cy-1.5,math.abs(me-940.5),3,r.good and C.good or C.bad,3);rect(939.5,cy-8,2,16,C.dim,4);dot(me,cy,5,r.good and C.value or C.rust,5)
   text(r.delta,1137,y,92,30,12,r.good and C.value or C.rust)
  end
  text(r.text,1003,y,122,30,19,C.value,F.display,"right")
 end
 if M.avg_any then rect(762,599.5,2,11,C.dim,3);local x=line({{"Your Average",11.5,C.dim}},769,598,13);text("Left Is Worse, Right Is Better",x+14,598,300,13,11.5,C.dim)end
 -- Downs And Deaths
 if downs then
  panel(27,633,1218,126);local hw=h2("Downs And Deaths",44,646)
  -- a match from before every time was saved says what is in order
  local sub=not M.everyone and (M.clock and "Teammates In Recorded Order"or "Shown In Recorded Order")
  if sub then text(sub,44+hw+12,649,360,13,11.5,C.dim)end
  local sum={{"You",12,C.dim},{tostring(M.you[1]),14,C.value,F.display,4},{"Downs,",12,C.dim,nil,4},{tostring(M.you[2]),14,C.rust,F.display,4},{"Died",12,C.dim,nil,4},
   {"Squad",12,C.dim,nil,18},{tostring(M.squad[1]),14,C.value,F.display,4},{"Downs,",12,C.dim,nil,4},{tostring(M.squad[2]),14,C.rust,F.display,4},{"Died",12,C.dim,nil,4}}
  if M.mutant>0 then sum[#sum+1]={"Caught By Mutant",12,C.dim,nil,18};sum[#sum+1]={tostring(M.mutant),14,C.value,F.display,4}end
  local lx=1229-span(sum);line(sum,lx,649,16);lx=lx-18
  local lw=wid("Died",11.5)+13;dot(lx-lw+4.5,657,4.5,C.rust,3);text("Died",lx-lw+13,650,lw,13,11.5,C.dim);lx=lx-lw-12
  lw=wid("Downed",11.5)+13;dot(lx-lw+4.5,657,4.5,C.value,3);dot(lx-lw+4.5,657,2.5,C.dark,4);text("Downed",lx-lw+13,650,lw,13,11.5,C.dim)
  text("You",44,680,70,15,12.5,C.body);text("Teammates",44,720,72,15,12.5,C.dim);rect(118,687,1111,1,C.lane,2);rect(118,727,1111,1,C.lane,2)
  local ev=M.events;local N=#ev;local last={-1e9,-1e9}
  -- with the times known, the player's lane is the mission's clock, each down or death at its time above it, and the teammates keep their order
  local mates,mi,tl=0,0,{};if M.clock then for _,e in ipairs(ev)do if not e.you then mates=mates+1 end end end
  for i,e in ipairs(ev)do local x
   if M.clock and (e.you or M.everyone)then x=124+1099*math.max(0,math.min(1,e.t/M.clock))end
   if M.clock and e.you then local s=B.clock(e.t);local w=wid(s,10.5);local a=math.max(118,math.min(1229-w,x-w/2));if a>=(tl[#tl]or -1e9)+6 then text(s,a,668,w+2,13,10.5,C.gold);tl[#tl+1]=a+w end
   elseif M.clock and not M.everyone then mi=mi+1;x=118+1111*(mates==1 and .5 or .076+(mi-1)*.848/(mates-1))
   elseif not M.clock then x=118+1111*(N==1 and .5 or .076+(i-1)*.848/(N-1))end
   local lane=e.you and 1 or 2
   local cy,r=e.you and 687.5 or 727.5,e.you and 5.5 or 4.5
   dot(x,cy,r,e.died and C.rust or C.value,3);if not e.died then dot(x,cy,r-2,C.dark,4)end
   local parts=e.you and {{e.died and "Died"or "Downed",11.5,e.died and C.rust or C.value,F.bold}}or {{e.name or "",10,C.faint}}
   if e.you and e.what then parts[2]={e.what,11.5,C.body,nil,4}end
   local w=span(parts);local lx0=math.max(118,math.min(1229-w,x-w/2))
   if lx0>=last[lane]+6 then line(parts,lx0,e.you and 697 or 734,e.you and 13 or 11);last[lane]=lx0+w end
  end
  if N==0 then text("No Downs Or Deaths",130,676,300,15,12.5,C.dim)end
 end
 -- the foot, the link and the bar under the card
 local fy=downs and 774.5 or 774.5-B.TL
 if M.run_id then rect(1090,fy,155,33,C.tint,2);edges(1090,fy,155,33,C.frame,3);text("Full History",1114,fy,110,33,17,C.value,F.display);text(">",1220,fy,14,33,15,C.body,F.bold);hot.link={1090,fy,155,33}end
 local by=(downs and B.H or B.H-B.TL)
 local pv={};local pn={};local function into(t,f)local keep=L;L=t;f();L=keep end
 into(pv,function()text("Click To Lock",0,by,B.W,B.BAR,14,C.body,nil,"center")end)
 into(pn,function()text("[Esc] Back",B.W-16-97,by+4.5,97,31,19,C.back,F.bold,"right");L[#L].id="back"end)
 hot.back={B.W-16-97,by+4.5,97,31}
 return {ops=L,preview=pv,pinned=pn,hot=hot,h=by+B.BAR,card=by}
end
return B
