-- Information Overload: the Social screen's two records, yours on the operative you play and yours with a teammate, laid out on the mockup's 2000-wide page.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Overview=mod:io_dofile(base.."io_overview")
local Records=mod:io_dofile(base.."records")
local Team=mod:io_dofile(base.."team_damage")
local R={}
local commas=Overview.commas
local function cname(id)return Overview.class_names[id]or Records.class_name(id)end
local function short(n)n=math.floor(n+.5);if n>=999500 then return string.format("%.2fM",n/1e6)elseif n>=1e4 then return string.format("%.0fK",n/1e3)end;return commas(n)end
local function label(c)return (Overview.diff_label(c):gsub(" Maelstrom$",""))end
local function plural(n,one)return n.." "..(n==1 and one or one.."s")end
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function ymd(run)local y,m,d=tostring(run and run.started_at or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");if y then return y,MONTHS[tonumber(m)],tonumber(d)end end
function R.day(run,year)local y,m,d=ymd(run);if not y then return nil end;return d.." "..m..(year and " "..y or "")end
-- "5 To 6 Oct", the year added at the end when asked for and given on both ends when they differ
function R.span(a,b,year)
 local y1,m1,d1=ymd(a);local y2,m2,d2=ymd(b);if not y1 or not y2 then return nil end
 local tail=year and " "..y2 or ""
 if y1~=y2 then return d1.." "..m1.." "..y1.." To "..d2.." "..m2.." "..y2 end
 if m1~=m2 then return d1.." "..m1.." To "..d2.." "..m2..tail end
 if d1~=d2 then return d1.." To "..d2.." "..m2..tail end;return d2.." "..m2..tail
end
local function streak(runs)
 local best,cur,from,span=0,0,nil,nil
 for _,run in ipairs(runs)do if run.victory==true then if cur==0 then from=run end;cur=cur+1;if cur>best then best=cur;span={from,run}end else cur=0 end end
 return best,span,span~=nil and span[2]==runs[#runs]and cur==best
end
local function where(tracker,run)return run and run.context and tracker.run_mission_name and tracker:run_mission_name(run.context)or nil end

-- the match file holds per-weapon and per-player damage; decoding one costs a file read, so each run is read once and kept.
-- Kept on mod, as io_dofile reruns this file and the hub reads them ahead for the screen.
mod.io_social_heavy=mod.io_social_heavy or setmetatable({},{__mode="k"})
local heavy=mod.io_social_heavy
local function decode(run)
 local h={};local d=run.damage
 if type(d)=="table"then for _,slot in ipairs({"melee","ranged"})do local g=d[slot];if type(g)=="table"then local n=0
  for a,b in pairs(g)do if a~="all"and a~="void_shield"and type(b)=="table"then n=n+(tonumber(b.total)or 0)end end;h[slot]=n end end end
 local t=run.team_damage;if type(t)=="table"then h.members={};for id in pairs(t.members or {})do h.members[tostring(id)]=Team.summary(t,id,"total").useful end end
 return h
end
-- reads at most one uncached run per call and says how many of the list are ready
function R.warm(runs)
 local done,read=0,false
 for _,run in ipairs(runs)do if heavy[run]then done=done+1 elseif not read then read=true;local ok,h=pcall(decode,run);if not ok and not R.told then R.told=true;mod:error("I/O social record, match %s: %s",tostring(run.id),tostring(h))end;heavy[run]=ok and h or {};done=done+1 end end
 return done,#runs
end

-- most games first, then the better win rate, then by name
function R.by_games(a,b)if a[2]~=b[2]then return a[2]>b[2]end;local x,y=(a[3]or 0)*b[2],(b[3]or 0)*a[2];if x~=y then return x>y end;return a[1]<b[1]end
local GRABS={{"mutant_charges","Mutant Grabs"},{"pounces","Pox Hound Pounces"},{"nets","Trapper Nets"}}
local STREAKS={{"head","Headshot Streak"},{"dodges","Dodge Streak"},{"kir","Kill Streak"},{"mkills","Kills In A Game"},{"single","Biggest Hit"}}
-- yours on one operative, from the Dossier's own figures for it
function R.own(tracker,ch)
 local o={name=ch.name,cls=ch.cls,n=#ch.runs,span=R.span(ch.first,ch.last,true),wins=0,diffs={},dmg=ch.tot.dmg.v,inc=ch.tot.downs.n,downs=ch.tot.downs.v or 0,deaths=ch.tot.deaths.v or 0,grabs={},weapons={},streaks={},last=ch.last}
 for _,x in ipairs(ch.won)do o.wins=o.wins+x.w;o.diffs[#o.diffs+1]={x.label,x.g,x.w}end
 table.sort(o.diffs,R.by_games)
 local kinds={};for _,run in ipairs(ch.runs)do local p=run.incidents and run.incidents.personal;if p then for _,g in ipairs(GRABS)do kinds[g[1]]=(kinds[g[1]]or 0)+(tonumber(p[g[1]])or 0)end end end
 for _,g in ipairs(GRABS)do if (kinds[g[1]]or 0)>0 then o.grabs[#o.grabs+1]={g[2],kinds[g[1]]}end end
 table.sort(o.grabs,R.by_games)
 local byid={};for _,run in ipairs(ch.runs)do byid[run.id]=run end
 for i=1,math.min(3,#ch.weapons)do local x=ch.weapons[i];local runs={};for _,id in ipairs(x.runs)do runs[#runs+1]=byid[id]end
  o.weapons[i]={n=x.n,slot=x.slot,runs=runs,staff=x.slot=="ranged"and x.n:find("Force Staff",1,true)~=nil}end
 local best,span,going=streak(ch.runs)
 if best>0 then local sp=R.span(span[1],span[2]);o.streaks[1]={"Most Wins In A Row",best,sp and sp..(going and ", Still Going"or "")or going and "Still Going"or nil}end
 for _,s in ipairs(STREAKS)do local top
  for _,row in pairs(ch.bests or {})do local x=row[s[1]];if x and x.v and (not top or x.v>top.v)then top=x end end
  if top then o.streaks[#o.streaks+1]={s[2],top.v,where(tracker,top.run)}end
 end
 local c=ch.last.context or {};o.last_line={R.day(ch.last,true),where(tracker,ch.last),label(c),ch.last.victory and "Won"or "Lost"}
 return o
end

local function matches(p,who)return type(p)=="table"and not p.personal and (who.sid and p.steam_id~=nil and tostring(p.steam_id)==who.sid or who.acc and p.account_id~=nil and tostring(p.account_id)==who.acc)end
local function bump(map,list,key)local x=map[key];if not x then x={key,0,0};map[key]=x;list[#list+1]=x end;return x end
local function count(n)return type(n)=="number"and n or type(n)=="table"and (n.count or 0)or 0 end
-- yours with one teammate, every saved mission they were in, oldest first
function R.mate(tracker,runs,who)
 local m={games=0,wins=0,names={},nlist={},dmap={},diffs={},cmap={},classes={},downs=0,deaths=0,inc=false,emap={},causes={},clutch={wins=0,full=0,semi=0,failed=0},they=0,you=0,picks=false,shared={}}
 local chrono={}
 for i=#runs,1,-1 do local run=runs[i];local c=run.context or {};local keys,row,cl={},nil,nil
  for k,p in pairs(c.operative_roster or {})do if matches(p,who)then keys[tostring(k)]=true;row=row or p end end
  for k,p in pairs(run.operative_clutches or {})do if matches(p,who)then keys[tostring(p.character_id or k)]=true;cl=cl or p;row=row or p end end
  if row then local won=run.victory==true;chrono[#chrono+1]=run
   m.games=m.games+1;if won then m.wins=m.wins+1 end
   local name=type(row.name)=="string"and row.name~=""and row.name;if name then local n=bump(m.names,m.nlist,name);n[2]=n[2]+1 end
   local x=bump(m.dmap,m.diffs,label(c));x[2]=x[2]+1;if won then x[3]=x[3]+1 end
   local class=row.class;for k in pairs(keys)do local p=c.operative_roster and c.operative_roster[k];if p and p.class then class=p.class end end
   if class then x=bump(m.cmap,m.classes,class);x[2]=x[2]+1;if won then x[3]=x[3]+1 end end
   if run.incidents then m.inc=true;local counts=Records.incident_counts(run).members or {}
    for k in pairs(keys)do local e=counts[k];local n=e and e.counts;if n then m.downs=m.downs+(n.downs or 0);m.deaths=m.deaths+(n.deaths or 0)end end end
   for _,e in ipairs(run.lethality_events or {})do if keys[tostring(e.victim)]and (e.outcome=="down"or e.outcome=="down_to_death"or e.outcome=="direct_death")then
    local named,seen={},{};for _,s in ipairs(e.sources or {})do local l=s.label;if l and l~="Unknown cause"and not seen[l]then seen[l]=true;named[#named+1]=l end end
    if #named==0 then named={"Unknown Cause"}end;for _,l in ipairs(named)do x=bump(m.emap,m.causes,l);x[2]=x[2]+1 end
   end end
   local cc=cl and cl.clutches
   if type(cc)=="table"then if won and cc.seen then m.clutch.wins=m.clutch.wins+(cc.episodes or 0);m.clutch.full=m.clutch.full+(cc.full_episodes or 0);m.clutch.semi=m.clutch.semi+(cc.semi_episodes or 0)
    elseif not won then m.clutch.failed=m.clutch.failed+(cc.attempts or 0)end end
   if run.pickup_pairs then m.picks=true;local own=tostring(c.character)
    for actor,victims in pairs(run.pickup_pairs)do actor=tostring(actor)
     for v,n in pairs(victims)do v=tostring(v);if keys[actor]and v==own then m.they=m.they+count(n)elseif actor==own and keys[v]then m.you=m.you+count(n)end end
    end
   end
   m.shared[#m.shared+1]={run=run,keys=keys,class=class};m.last,m.last_class=run,class
  end
 end
 for _,l in ipairs({m.nlist,m.diffs,m.classes,m.causes})do table.sort(l,R.by_games)end
 local best,span=streak(chrono);m.streak,m.streak_span=best,span and R.span(span[1],span[2])
 if m.last then local c=m.last.context or {};m.last_line={R.day(m.last,true),where(tracker,m.last),label(c),"As "..cname(m.last_class),m.last.victory and "Won"or "Lost"}end
 m.runs=chrono;return m
end
-- their best damage in a mission with you, once every shared match file is read
function R.best_damage(tracker,m)
 local top
 for _,s in ipairs(m.shared)do local h=heavy[s.run];if not h then return nil,true end
  if h.members then local n,any=0,false;for k in pairs(s.keys)do local v=h.members[k];if v then n=n+v;any=true end end
   if any and n>0 and (not top or n>top.v)then top={v=n,s=s}end end
 end
 if not top then return nil end
 local run=top.s.run;local c=run.context or {}
 return {v=top.v,where=where(tracker,run),meta={label(c),"As "..cname(top.s.class),run.victory and "Won"or "Lost",R.day(run)},you=(Records.run_mission_damage(run))}
end
function R.weapon_damage(o)
 local any=false;local out={}
 for i,w in ipairs(o.weapons)do local n=0;local known=not w.staff
  local has=false
  for _,run in ipairs(w.runs)do local h=heavy[run];if not h then return nil end;if known and h[w.slot]then n=n+h[w.slot];has=true;any=true end end
  out[i]=has and n or nil
 end
 return any and out or {}
end

-- the page: colours, and a writer that keeps positions in the mockup's own pixels
local C={white={255,225,234,219},label={255,124,133,117},dim={255,96,104,92},soft={255,170,180,163},gold={255,201,162,90},dname={255,196,206,189},
 card={38,0,0,0},bar={82,124,133,117},win={158,196,210,188},dark={64,0,0,0},line={56,0,0,0}}
R.C=C
local function hex(c)return "{#color("..c[2]..","..c[3]..","..c[4]..")}"end
-- the parts that are known, joined by the mockup's dim dot
local function dots(parts,c)local out={};for i=1,table.maxn(parts)do if parts[i]then out[#out+1]=parts[i]end end;return table.concat(out,hex(C.dim).." · "..hex(c))end
local function pen()
 local L={}
 local w={}
 -- p is the shadow: the same text with its colours taken out, so it keeps the size changes and sits under it
 function w.t(s,x,y,wd,h,size,c,a,font)L[#L+1]={t=s,p=(s:gsub("{#color%([^)]*%)}","")),x=x,y=y,w=wd,h=h,s=size,c=c,a=a or "l",f=font}end
 function w.r(x,y,wd,h,c,z)L[#L+1]={r=true,x=x,y=y,w=wd,h=h,c=c,z=z or 1}end
 function w.card(x,y,wd,h,title)w.r(x,y,wd,h,C.card,0);if title then w.t(title,x+18,y+14,wd-36,22,18,C.label)end end
 function w.bar(x,y,wd,f,bg,fg)w.r(x,y,wd,6,bg);if f>0 then w.r(x,y,math.max(1,wd*math.min(1,f)),6,fg,2)end end
 w.L=L;return w
end
local function rate(w,g)return g>0 and string.format("%.1f%%",100*w/g)or Overview.dash end
local function stat(w,x,wd,k,v,c,small,k2)w.card(x,410,wd,92);w.t(k,x+18,423,wd-36,22,18,C.label);w.t(v..(small and "{#size("..math.floor(19*.96*k2+.5)..")}"..hex(C.label).."  "..small or ""),x+18,449,wd-36,40,38,c or C.white)end
local function downs(w,x,y,downed,died)w.t(dots({"Downed "..downed,"Died "..died},C.white),x,y,296,25,21,C.white)end
local function drows(w,x,y,rows,n)local top=0;for i=1,math.min(n,#rows)do top=math.max(top,rows[i][2])end
 for i=1,math.min(n,#rows)do local r=rows[i];local ry=y+(i-1)*31
  w.t(r[1],x,ry,172,22,18,C.dname);w.r(x+184,ry+8,74,6,C.dark);w.r(x+184,ry+8,math.max(1,74*r[2]/top),6,C.bar,2);w.t(tostring(r[2]),x,ry,296,22,18,C.white,"r")end
end
-- the lines of your own record, in the mockup's pixels; k is the renderer's scale, for the sizes written into the text
function R.own_page(o,dmg,k)
 local w=pen()
 w.t("Your Record On This Operative",786,308,1000,23,19,C.label);w.t(o.name,786,334,1000,40,32,C.white)
 w.t(dots({cname(o.cls),plural(o.n,"Game").." On File"..(o.span and ", "..o.span or "")},C.label),786,374,1000,20,16,C.label,"l","m")
 stat(w,786,332,"Games",tostring(o.n));stat(w,1133,332,"Wins",tostring(o.wins));stat(w,1480,332,"Win Rate",rate(o.wins,o.n))
 w.card(786,516,332,152,"Win Rate By Difficulty")
 for i=1,math.min(2,#o.diffs)do local d=o.diffs[i];local y=563+(i-1)*52
  w.t(d[1],804,y,150,27,22,C.white);w.t(dots({plural(d[2],"Game"),plural(d[3],"Win")},C.soft),804,y,232,27,17,C.soft,"r");w.t(math.floor(100*d[3]/d[2]+.5).."%",804,y,296,27,22,C.white,"r")
  w.bar(804,y+35,296,d[3]/d[2],C.bar,C.win)end
 w.card(786,680,332,204,"What Downs You")
 if o.inc>0 then downs(w,804,726,o.downs,o.deaths)
  if #o.grabs>0 then w.t("Grabbed Or Pinned",804,755,296,18,14,C.label,"l","m");drows(w,804,782,o.grabs,3)end end
 w.card(1133,516,332,368,"Top Weapons")
 local top,gtop=0,0;for i,x in ipairs(o.weapons)do top=math.max(top,dmg and dmg[i]or 0);gtop=math.max(gtop,#x.runs)end
 for i,x in ipairs(o.weapons)do local y=565+(i-1)*118;local d=dmg and dmg[i]
  w.t(x.n,1151,y,296,24,19.5,C.white);w.t(dots({plural(#x.runs,"Game"),d and short(d).." Damage"},C.soft),1151,y+29,296,20,17,C.soft)
  w.bar(1151,y+58,296,top>0 and (d or 0)/top or #x.runs/gtop,C.dark,C.win);if i<#o.weapons then w.r(1151,y+90,296,1,C.line)end end
 w.card(1480,516,332,368,"Best Streaks")
 for i,s in ipairs(o.streaks)do local y=559+(i-1)*54
  w.t(s[1],1498,y,220,22,18,C.white);if s[3]then w.t(s[3],1498,y+22,220,18,14,C.label,"l","m")end;w.t(commas(s[2]),1498,y,296,40,29,C.gold,"r")
  if i<#o.streaks then w.r(1498,y+46,296,1,C.line)end end
 w.card(786,896,1026,64);w.t("Last Played",804,896,200,64,18,C.label);w.t(dots(o.last_line,C.white),921,896,640,64,21,C.white)
 if o.dmg then w.t("Damage Dealt  {#size("..math.floor(21*.96*k+.5)..")}"..hex(C.white)..short(o.dmg),804,896,990,64,16,C.label,"r")end
 return w.L
end
local function names(list)
 local n={};for i=1,math.min(4,#list)do n[i]=hex(C.soft)..list[i][1]..hex(C.label)end
 if #list>4 then n[#n+1]=(#list-4).." More"end
 if #n==1 then return n[1]end;return table.concat(n,", ",1,#n-1).." and "..n[#n]
end
-- the lines of your record with a teammate; best is their best damage run, or nil while the match files are read
function R.mate_page(m,acct,best,k)
 local w=pen()
 w.t("In Your Strike Team",786,308,1000,23,19,C.label);w.t(acct,786,334,1000,40,32,C.white)
 if #m.nlist>0 then w.t("Played with you as "..names(m.nlist),786,374,1026,20,16,C.label,"l","m")end
 stat(w,786,244,"Games Together",tostring(m.games));stat(w,1044,244,"Wins Together",tostring(m.wins));stat(w,1302,244,"Win Rate",rate(m.wins,m.games))
 stat(w,1560,252,"Most Wins In A Row",tostring(m.streak),C.gold,m.streak>0 and m.streak_span,k)
 local nd=math.max(1,math.min(3,#m.diffs));local dh=96+(nd-1)*40
 w.card(786,516,332,dh,"By Difficulty")
 for i=1,math.min(3,#m.diffs)do local d=m.diffs[i];local y=564+(i-1)*40;w.t(d[1],804,y,170,28,23,C.white);w.t(dots({plural(d[2],"Game"),plural(d[3],"Win")},C.soft),804,y,296,28,18,C.soft,"r")end
 local y0=516+dh+12;w.card(786,y0,332,884-y0,"Classes They Played With You")
 local fit=math.floor((884-y0-50-37)/55)+1
 for i=1,math.min(fit,#m.classes)do local c=m.classes[i];local y=y0+50+(i-1)*55
  w.t(cname(c[1]),804,y,170,27,22,C.white);w.t(dots({plural(c[2],"Game"),plural(c[3],"Win")},C.soft),804,y,296,27,17,C.soft,"r")
  if i<math.min(fit,#m.classes)then w.r(804,y+40,296,1,C.line)end end
 w.card(1133,516,332,196,"Best Damage Run With You")
 if best then w.t(commas(best.v),1151,564,296,46,46,C.gold);w.t(best.where or "",1151,622,296,25,21,C.white);w.t(dots(best.meta,C.soft),1151,653,296,20,17,C.soft)
  if best.you then w.t("You did "..hex(C.white)..commas(best.you)..hex(C.label).." that mission.",1151,687,296,20,17,C.label,"l","m")end end
 w.card(1133,724,332,160,"Clutches")
 local cl=m.clutch;local kinds={};if cl.full>0 then kinds[#kinds+1]=cl.full.." Full"end;if cl.semi>0 then kinds[#kinds+1]=cl.semi.." Semi"end
 w.t(tostring(cl.wins),1151,772,148,40,40,C.white);w.t("In Wins",1151,818,148,20,17,C.soft);if #kinds>0 then w.t(table.concat(kinds,", "),1151,841,148,19,16,C.label,"l","m")end
 w.t(tostring(cl.failed),1299,772,148,40,40,C.white);w.t("Failed",1299,818,148,20,17,C.soft);w.t("In Losses",1299,841,148,19,16,C.label,"l","m")
 w.card(1480,516,332,216,"What Downs Them")
 if m.inc or #m.causes>0 then downs(w,1498,562,m.downs,m.deaths)end
 local shown=#m.causes==4 and 4 or 3;drows(w,1498,596,m.causes,shown)
 local rest=#m.causes-shown
 if rest>0 then local once=true;for i=shown+1,#m.causes do if m.causes[i][2]~=1 then once=false end end
  w.t(rest.." Others"..(once and ", Once Each"or ""),1498,596+shown*31,296,22,16,C.label,"l","m")end
 w.card(1480,744,332,140,"Last Played Together")
 if m.last_line then local l=m.last_line;w.t(l[1]or "",1498,790,296,25,21,C.white);w.t(l[2]or "",1498,821,296,20,17,C.soft);w.t(dots({l[3],l[4],l[5]},C.soft),1498,844,296,20,17,C.soft)end
 w.card(786,896,1026,64);w.t("You Two",804,896,200,64,18,C.label)
 if m.picks then w.t("They picked you up "..(m.they==1 and "once"or m.they.." times")..". You picked them up "..(m.you==1 and "once"or tostring(m.you))..".",896,896,900,64,21,C.white)end
 return w.L
end
return R
