-- Information Overload: data and small drawing helpers for Dossier, Team, Friends, Psykhanium and Settings.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Records=mod:io_dofile(base.."records")
local Times=mod:io_dofile(base.."mission_times")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local Sum=mod:io_dofile(base.."psyk_summary")
local C,DASH=D.c,Overview.dash
local P={dash=DASH,commas=Overview.commas,compact=Overview.compact,class_names=Overview.class_names}
P.ARMOUR={{"unarmored","Unarmoured"},{"armored","Flak"},{"berserker","Maniac"},{"super_armor","Carapace"},{"resistant","Unyielding"},{"disgustingly_resilient","Infested"}}
P.ARMOUR_NAME={};for _,a in ipairs(P.ARMOUR)do P.ARMOUR_NAME[a[1]]=a[2]end
local function plural(n,one,many)return tostring(n).." "..(n==1 and one or many or one.."s")end
P.plural=plural
function P.times(n)return n==1 and "Once"or n==2 and "Twice"or n.." Times"end
function P.day(ts)local y,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");return y and d.."/"..m.."/"..y or DASH end
function P.dm(ts)local _,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");return m and d.."/"..m or DASH end
function P.mss(s)s=math.max(0,math.floor(s or 0));return string.format("%d:%02d",math.floor(s/60),s%60)end
-- Character Select's record figures, kept short for that screen whatever Number Format says
function P.short(n)n=math.floor(n+.5);if n>=1e6 then return string.format("%.2fM",n/1e6)elseif n>=1e4 then return string.format("%.0fK",n/1e3)end;return Overview.commas(n)end
function P.wrap(view,text,size,width,font)
 local lines,cur={},""
 for word in tostring(text):gmatch("%S+")do local try=cur==""and word or cur.." "..word
  if cur~=""and view:_w(try,size,font)>width then lines[#lines+1]=cur;cur=word else cur=try end
 end
 if cur~=""then lines[#lines+1]=cur end;return lines
end
function P.toggle(view,cv,x,y,on,fn)
 local w,h=46,24
 view:_ctl(cv,"base",x,y,w,h,fn,{sel=on,hv={bg=C.fill_h,edge=C.hover}})
 cv.z=5;cv:rect(on and x+w-20 or x+6,y+5,14,14,on and C.gold or C.label)
end
function P.button(view,cv,x,y,w,h,label,fn,opt)
 opt=opt or {};local k=view:_ctl(cv,"base",x,y,w,h,fn,{sel=opt.sel,dis=opt.dis,hv={bg=C.fill_s,edge=C.sel}})
 cv:text(label,x,y,w,h,16,opt.sel and C.gold_hi or opt.danger and C.bad or C.value,"center",nil,k)
end
function P.select(view,cv,popup,id,x,y,w,value,options,pick)
 local open=view.dd==id
 view:_ctl(cv,"base",x,y,w,34,function()view.dd=not open and id or nil end,{open=open})
 cv:text(value,x+14,y,w-50,34,16,C.value);cv:chevron(x+w-24,y+13,"down",10,C.value)
 if not open then return end
 local sc=view.sheet;local sy=y+(sc and sc.dy or 0)
 local pw=math.max(w,260);local h=#options*30+2;local py=sy+38;if py+h>850 then py=sy-4-h end
 view:_panel(popup,x,py,pw,h)
 for i,o in ipairs(options)do local oy=py+1+(i-1)*30;local on=o.value==o.current
  if i>1 then popup:rect(x+1,oy,pw-2,1,C.line)end
  if on then popup:rect(x+1,oy,pw-2,30,C.on);popup:rect(x+1,oy,3,30,C.sel)end
  popup:text(o.label,x+12,oy,o.n and pw-140 or pw-24,30,16,on and C.gold_hi or o.dis and C.muted or C.value)
  if o.n then popup:text(o.n,x+pw-132,oy,120,30,14,C.muted,"right")end
  if not o.dis then view:_hit("popup",x+1,oy,pw-2,30,function()view.dd=nil;pick(o.value)end,{bg=C.fill_h},nil,nil,id.."|"..tostring(o.value))end
 end
end
function P.open_run(view,id)return function()view.io_params=view.io_params or {};view.io_params.run=id;view.io_tab="overview";view:_go("run")end end

local function damage(run)return (Records.run_mission_damage(run))end
local function mode_label(c)local l=Overview.diff_label(c);return (l:gsub(" Maelstrom$",""))end
local function diff_rank(label)local n=label:match("^Havoc (%d+)$");if n then return -tonumber(n)end
 local r=({Sedition=1,Uprising=2,Malice=3,Heresy=4,Damnation=5,Auric=6})[label]or 9;return 100-r end
local STATS={{"mkills","Most Kills In A Mission"},{"mdmg","Most Damage In A Mission"},{"mboss","Most Bosses In A Mission"},{"single","Biggest Single-Target Hit"},
 {"dodges","Melee Dodges In A Row"},{"head","Headshots In A Row"},{"kir","Kills In A Row"}}
P.dossier_stats=STATS
-- Most Damage is useful damage, overkill left out, as the Overview has it; the biggest hit keeps its overkill
local function stat(run,k)
 if not run.contributions then return nil end
 local r=run.records or {}
 if k=="mkills"then return run.kills elseif k=="mdmg"then return (Records.run_useful(run))elseif k=="mboss"then return run.kill_categories and (run.kill_categories.boss or 0)or nil
 elseif k=="single"then return r.single_hit elseif k=="dodges"then return r.dodges elseif k=="head"then return r.head_combined elseif k=="kir"then return r.kills end
end
local function holder(runs,k)local best;for _,run in ipairs(runs)do local v=stat(run,k);if type(v)=="number"and (not best or v>=best[1])then best={v,run}end end;return best end
local function wins_in_a_row(runs)
 local best,cur,start,span=0,0,nil,nil
 for _,run in ipairs(runs)do if run.victory then if cur==0 then start=run end;cur=cur+1;if cur>best then best=cur;span={start,run}end else cur=0 end end
 return best,cur,span
end
local function lethality(tracker,runs)
 local E,order,with,two={},{},{},false
 -- causes are saved only when someone in the squad goes down, so a file without them is on file when its own counts show none of your downs
 for _,run in ipairs(runs)do local own=not run.lethality_events and run.incidents and run.incidents.personal or {}
  if run.lethality_events or run.incidents and (own.downs or 0)+(own.deaths or 0)==0 then with[#with+1]=run.id
  for _,e in ipairs(run.lethality_events or {})do if e.personal and (e.outcome=="down"or e.outcome=="down_to_death"or e.outcome=="direct_death")then
   local named,seen={},{};for _,s in ipairs(e.sources or {})do local l=s.label;if l and l~="Unknown cause"and not seen[l]then seen[l]=true;named[#named+1]=l end end
   if #named==0 then named={"Unknown Cause"}end;if #named>1 then two=true end
   for _,l in ipairs(named)do local x=E[l];if not x then x={n=l,down=0,death=0,runs={}};E[l]=x;order[#order+1]=x end
    if e.outcome=="down"then x.down=x.down+1 else x.death=x.death+1 end;if x.runs[#x.runs]~=run.id then x.runs[#x.runs+1]=run.id end
   end
  end end
 end end
 table.sort(order,function(a,b)local ua,ub=a.n=="Unknown Cause",b.n=="Unknown Cause";if ua~=ub then return ub end;if a.death~=b.death then return a.death>b.death end;if a.down~=b.down then return a.down>b.down end;return a.n<b.n end)
 return order,with,two
end
-- an operative's wins by difficulty, totals and weapons over some of their missions, oldest first, as the Dossier works them out over all of them
function P.figures(ms)
 local f={first=ms[1],last=ms[#ms]}
 local won,wl={},{}
 for _,run in ipairs(ms)do local c=run.context;local key=c.mode..":"..mode_label(c)
  local x=won[key];if not x then x={mode=c.mode,label=mode_label(c),g=0,w=0,mw=0,seq={}};won[key]=x;wl[#wl+1]=x end
  x.g=x.g+1;if run.victory then x.w=x.w+1;if Overview.diff_label(c):find("Maelstrom",1,true)then x.mw=x.mw+1 end end;x.seq[#x.seq+1]={id=run.id,win=run.victory==true}
 end
 table.sort(wl,function(a,b)return diff_rank(a.label)<diff_rank(b.label)end);f.won=wl
 local tot={kills={n=0},dmg={n=0},bosses={n=0},downs={n=0},deaths={n=0}}
 local function add(k,v)if type(v)=="number"then local t=tot[k];t.v=(t.v or 0)+v;t.n=t.n+1 end end
 for _,run in ipairs(ms)do add("kills",run.kills);add("dmg",damage(run));add("bosses",run.kill_categories and (run.kill_categories.boss or 0)or nil)
  if run.incidents then local own=Records.incident_counts(run).personal or {};add("downs",own.downs or 0);add("deaths",own.deaths or 0)end
 end
 f.tot=tot
 local W,wl2,with,nolo={},{},{},0
 for _,run in ipairs(ms)do local lo=Sum.loadout(run)
  if lo and (lo.melee or lo.ranged)then with[#with+1]=run.id
   for _,slot in ipairs({"melee","ranged"})do local n=lo[slot];if type(n)=="string"and n~=""then local key=slot..":"..n;local x=W[key]
    if not x then x={n=n,slot=slot,runs={}};W[key]=x;wl2[#wl2+1]=x end;x.runs[#x.runs+1]=run.id end end
  else nolo=nolo+1 end
 end
 table.sort(wl2,function(a,b)if #a.runs~=#b.runs then return #a.runs>#b.runs end;if a.slot~=b.slot then return a.slot=="melee"end;return a.n<b.n end)
 f.weapons,f.wd_runs,f.nolo=wl2,with,nolo
 return f
end
-- a mission's difficulty as the Dossier names it, Maelstrom counted in with its own
P.mode_label=mode_label
function P.dossier(tracker)
 local all=Overview.runs(tracker);local chrono={};for i=#all,1,-1 do chrono[#chrono+1]=all[i]end
 local account={}
 for _,mode in ipairs({"havoc","non-havoc"})do local ms={};for _,run in ipairs(chrono)do if run.context.mode==mode then ms[#ms+1]=run end end
  local a={};for _,s in ipairs(STATS)do a[s[1]]=holder(ms,s[1])end;account[mode]=a
 end
 local chars,list={},{}
 for _,run in ipairs(chrono)do local c=run.context;local id=tostring(c.character or "unknown")
  local ch=chars[id];if not ch then ch={id=id,cls=c.class,runs={},names={},first_seen={},seen=0};chars[id]=ch;list[#list+1]=ch end
  ch.runs[#ch.runs+1]=run;local n=c.character_name;if type(n)=="string"and n~=""then ch.names[n]=(ch.names[n]or 0)+1;ch.seen=ch.seen+1;ch.first_seen[n]=ch.first_seen[n]or ch.seen end
 end
 local basis=(mod.io_display_options and mod.io_display_options()or {}).boss_map_timing and "boss"or "victory"
 for _,ch in ipairs(list)do local ms=ch.runs;local N=#ms
  local names={};for n in pairs(ch.names)do names[#names+1]=n end
  table.sort(names,function(a,b)if ch.names[a]~=ch.names[b]then return ch.names[a]>ch.names[b]end;return ch.first_seen[a]<ch.first_seen[b]end)
  ch.name=names[1]or "Unknown Operative";ch.others={};for i=2,#names do ch.others[#ch.others+1]={n=names[i],k=ch.names[names[i]]}end
  table.sort(ch.others,function(a,b)return ch.first_seen[a.n]<ch.first_seen[b.n]end)
  ch.first,ch.last=ms[1],ms[N];ch.newest_ts=tostring(ms[N].started_at or "")
  local fig=P.figures(ms);ch.won=fig.won
  for i=N,1,-1 do local lo=Sum.loadout(ms[i])
   if lo and (lo.keystone or lo.blitz)then ch.keystone=lo.keystone;ch.blitz=lo.blitz;break end end
  ch.tot=fig.tot;ch.enemies,ch.leth_runs,ch.leth_two=lethality(tracker,ms)
  ch.bests={}
  for _,mode in ipairs({"havoc","non-havoc"})do local mm={};for _,run in ipairs(ms)do if run.context.mode==mode then mm[#mm+1]=run end end
   if #mm>0 then local row={n=#mm}
    for _,s in ipairs(STATS)do local k=s[1];local h=holder(mm,k);local n=0;for _,run in ipairs(mm)do if type(stat(run,k))=="number"then n=n+1 end end
     if h then local a=account[mode][k];row[k]={v=h[1],run=h[2],n=n,of=#mm,rec=a and a[2]==h[2]and "holds"or a and a[1]==h[1]and "equals"or nil}else row[k]={n=0,of=#mm}end
    end
    local best,cur,span=wins_in_a_row(mm);row.wins={v=best,run=span and span[2],from=span and span[1],going=span~=nil and span[2]==mm[#mm]and cur==best}
    ch.bests[mode]=row
   end
  end
  ch.weapons,ch.wd_runs,ch.nolo=fig.weapons,fig.wd_runs,fig.nolo
  local clears={}
  for _,mode in ipairs({"havoc","non-havoc"})do local timed=Times.build(ms,mode,basis);local G,gl={},{}
   for _,run in ipairs(ms)do local c=run.context;if c.mode==mode then local key=tostring(c.difficulty).."|"..tostring(c.mission_name)
    local g=G[key];if not g then g={map=tracker:run_mission_name(c),label=mode_label(c),diff=tostring(c.difficulty),mission=c.mission_name,runs={}};G[key]=g;gl[#gl+1]=g end;g.runs[#g.runs+1]=run end end
   for _,g in ipairs(gl)do local t=timed[g.diff]and timed[g.diff][g.mission];local row={map=g.map,label=g.label,n=#g.runs}
    if t then row.st="time";row.s=t.completion_time.seconds;row.run=t;row.mael=Overview.diff_label(t.context):find("Maelstrom",1,true)~=nil
    else local win;for _,run in ipairs(g.runs)do if run.victory then win=run end end
     if win then row.st="won";row.run=win;row.partial=true;for _,run in ipairs(g.runs)do if run.victory and run.full~=false then row.partial=false end end
     else row.st="lost";row.run=g.runs[#g.runs]end
    end
    clears[#clears+1]=row
   end
  end
  local rank={time=0,won=1,lost=2}
  table.sort(clears,function(a,b)if a.st~=b.st then return rank[a.st]<rank[b.st]end;if (a.s or 0)~=(b.s or 0)then return (a.s or 0)<(b.s or 0)end;return tostring(a.run.started_at)<tostring(b.run.started_at)end)
  ch.clears=clears
 end
 local corder={};for i,c in ipairs(Nav.classes)do corder[c]=i end
 table.sort(list,function(a,b)local x,y=corder[a.cls]or 99,corder[b.cls]or 99;if x~=y then return x<y end;return a.name<b.name end)
 local newest;for _,ch in ipairs(list)do if not newest or ch.newest_ts>newest.newest_ts then newest=ch end end
 return {chars=list,newest=newest and newest.id}
end

local BOSS_ORDER={["Beast of Nurgle"]=1,["Chaos Spawn"]=2,["Plague Ogryn"]=3,["Pack Master"]=4,["Hammer-captain"]=5,["Sword-captain"]=6,["Melee-Twin"]=7,["Ranged-Twin"]=8,["Rodin Karnak, Prophet of Decay"]=9,["Daemonhost"]=10}
local RITUAL=" %- Ritual stopped$"
local function tally(tracker,patch,mode)
 if type(tracker.running_tallies)=="function"then return tracker:running_tallies(patch,mode)end
 local g=tracker.data.running_tallies;return g and g[patch]and g[patch][mode]or {}
end
function P.team(tracker,patch,mode)
 local t={bosses={},rituals={},clutches={},quiet=0,fun={},leave={},bots={}}
 local groups=tracker.data.boss_tallies or {};local entries=groups[patch or "Unknown patch"]and groups[patch or "Unknown patch"][mode]or {}
 for _,e in pairs(entries)do local label=tostring(e.label or "Unknown boss");local n=(e.count or 0)-(e.weakened or 0)
  local v=tostring(n)..((e.weakened or 0)>0 and " · "..e.weakened.." Weakened"or "")
  if label:find(RITUAL)then t.rituals[#t.rituals+1]={label:gsub(RITUAL,""),v}
  else t.bosses[#t.bosses+1]={label,v,BOSS_ORDER[label]or 99}end
 end
 table.sort(t.bosses,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;return a[1]<b[1]end)
 local tl=tally(tracker,patch,mode)
 local people={};for _,e in pairs(tl.allies or {})do people[#people+1]=e end
 local cn=function(id)return Overview.class_names[id]or Records.class_name(id)end
 for _,e in ipairs(people)do if (e.clutch_wins or 0)>0 then
  local rows={{"Missions Won With A Clutch",tostring(e.clutch_wins)},{"Most Clutches In One Win",e.clutch_episodes.." · "..cn(e.clutch_record_class)}}
  if (e.full_clutch_episodes or 0)>0 then rows[#rows+1]={"Most Full Clutches In One Win",e.full_clutch_episodes.." · "..cn(e.full_clutch_record_class)}end
  if (e.semi_clutch_episodes or 0)>0 then rows[#rows+1]={"Most Semi-Clutches In One Win",e.semi_clutch_episodes.." · "..cn(e.semi_clutch_record_class)}end
  if (e.failed_clutches_game or 0)>0 then rows[#rows+1]={"Most Failed Clutches In One Loss",e.failed_clutches_game.." · "..cn(e.failed_clutch_record_class)}end
  t.clutches[#t.clutches+1]={name=(e.name or "Steam Name Unavailable")..(e.personal and " (You)"or ""),me=e.personal==true,wins=e.clutch_wins,rows=rows}
 else t.quiet=t.quiet+1 end end
 table.sort(t.clutches,function(a,b)if a.me~=b.me then return a.me end;if a.wins~=b.wins then return a.wins>b.wins end;return a.name<b.name end)
 while #t.clutches>10 do table.remove(t.clutches);t.quiet=t.quiet+1 end
 local fun=t.fun
 local fi=type(tracker.mode_streak)=="function"and tracker:mode_streak(patch,mode)or {}
 if (fi.field_improv_missing_total or 0)>0 then fun[#fun+1]={"Veterans Without Field Improvisation",tostring(fi.field_improv_missing_total)}end
 if (tonumber(tl.psyker_total)or 0)>0 then
  fun[#fun+1]={"Psykers Who Detonated",tostring(tl.psyker_detonating or 0)};fun[#fun+1]={"Psykers In Your Teams",tostring(tl.psyker_total)}
  local ns={};for n,v in pairs(tl.repeats or {})do if (tonumber(v)or 0)>0 then ns[#ns+1]=tonumber(n)end end;table.sort(ns)
  for _,n in ipairs(ns)do fun[#fun+1]={"Psykers With "..n.." Detonations",tostring(tl.repeats[tostring(n)])}end
 end
 local s=Nav.incident_outcome_summary(tracker,patch,mode)
 for _,f in ipairs({{"lethal_kicks","Downed After A Specialist Kick"},{"murders","Murders"},{"suicides","Suicides"}})do
  local team=s.best["team_"..f[1].."_mission"]
  if (team or 0)>0 then fun[#fun+1]={f[2]..", Team",tostring(team),s.record_runs["team_"..f[1].."_mission"]}
   local own,other=s.best["personal_"..f[1].."_mission"]or 0,s.best["teammate_"..f[1].."_mission"]or 0
   if math.max(own,other)>0 then local mine=own>=other;local id=mine and "personal_"..f[1].."_mission"or "teammate_"..f[1].."_mission";local src=s.sources[id]or {}
    local who=mine and "You"or src.friend_name;fun[#fun+1]={f[2]..", Top Operative",math.max(own,other).." · "..cn(src.class)..(who and " ("..who..")"or ""),s.record_runs[id]}
   end
  end
 end
 if mode=="havoc"then
  local rows={};for _,e in pairs(tl.leave_abuse or {})do rows[#rows+1]=e end;table.sort(rows,function(a,b)return (a.name or "")<(b.name or "")end)
  for _,e in ipairs(rows)do if (e.count or 0)>0 then t.leave[#t.leave+1]={e.name or "Steam Name Unavailable",e.count..((e.failed or 0)>0 and " · "..e.failed.." Failed"or "")}end
   if (e.bot_clutches or 0)>0 then t.bots[#t.bots+1]={e.name or "Steam Name Unavailable",tostring(e.bot_clutches)}end end
 end
 t.named=Nav.show_leave_abuse();return t
end

function P.friends(tracker,patch,mode)
 local rows=mod.io_friend_rows and mod.io_friend_rows(patch,mode)or {}
 local out={}
 for _,r in ipairs(rows)do local s=r.stats or {};local games=s.games or 0
  local f={id=r.id,name=r.name,info={},clutch={},enemies={}}
  f.info[#f.info+1]={"Missions Together",tostring(games)};f.info[#f.info+1]={"Wins Together",tostring(s.wins or 0)}
  f.info[#f.info+1]={"Win Rate With You",games>0 and string.format("%.1f%%",100*(s.wins or 0)/games)or DASH}
  local best,class;for id,x in pairs(s.classes or {})do if (x.games or 0)>=5 and (not best or x.wins*best.games>best.wins*x.games or x.wins*best.games==best.wins*x.games and x.games>best.games)then best=x;class=id end end
  f.info[#f.info+1]={"Most Successful Class",best and (Overview.class_names[class]or Records.class_name(class))or DASH}
  f.info[#f.info+1]={"Class Win Rate",best and string.format("%.1f%%",100*best.wins/best.games).." Of "..best.games or DASH}
  local cn=function(id)return Overview.class_names[id]or Records.class_name(id)end
  f.clutch[#f.clutch+1]={"Missions Won With A Clutch",tostring(s.clutch_wins or 0)}
  for _,k in ipairs({{"clutch_episodes","Most Clutches In One Win","clutch_record_class"},{"full_clutch_episodes","Most Full Clutches In One Win","full_clutch_record_class"},{"semi_clutch_episodes","Most Semi-Clutches In One Win","semi_clutch_record_class"},{"failed_clutches_game","Most Failed Clutches In One Loss","failed_clutch_record_class"}})do
   if (s[k[1]]or 0)>0 then f.clutch[#f.clutch+1]={k[2],s[k[1]].." · "..cn(s[k[3]])}end end
  for _,e in pairs(s.enemies or {})do if (e.downs or 0)+(e.deaths or 0)>0 or (e.count or 0)>0 then f.enemies[#f.enemies+1]={n=e.label or "Unknown Enemy",down=e.downs,death=e.deaths,count=e.count or 0}end end
  table.sort(f.enemies,function(a,b)if a.count~=b.count then return a.count>b.count end;return a.n<b.n end)
  out[#out+1]=f
 end
 local tracked=tracker.data.friend_tracking and tracker.data.friend_tracking.tracked or {}
 -- tracked players get stats only while Stats For Tracked Players is on
 local n=0;if mod:get("friend_stats_scope")~="off"then for _ in pairs(tracked)do n=n+1 end end
 return out,n
end

local function melee_of(run)return Sum.loadout(run)end
local armour_hits=Sum.hits
-- run.damage on a saved log decodes its file. Saved logs never change in place (save, delete, reset and merges bring new tables), so the table keys its totals.
-- Kept on mod because io_dofile reruns this file for every page; the hub warm-up fills the same cache.
mod.io_saved_armour=mod.io_saved_armour or setmetatable({},{__mode="k"})
local saved_hits=mod.io_saved_armour
local function saved_armour(run)local a=saved_hits[run];if not a then a=armour_hits(run);saved_hits[run]=a end;return a end
local function dps(state)if not state or not state.first or not state.last then return end;local d=state.last-state.first;return {total=state.total or 0,hits=state.hits or 0,dur=d,wh=d>0 and (state.total or 0)/d or nil}end
function P.bench_session(run,id,live)
 local lo=melee_of(run);local c=run.context or {};local arm=live and armour_hits(run)or saved_armour(run);local d=dps(run.psyk_dps)
 local single=run.records and run.records.single_hit
 return {id=id,live=live,run=run,weapon=lo.melee or "Unknown Weapon",blessings=lo.melee_blessings,perks=lo.melee_perks,op=c.character_name or "Unknown Operative",cls=c.class,
  arm=arm,dps=d,dmg=d and d.total or arm.all.dmg,hits=d and d.hits or arm.all.n,best=single,dur=d and d.dur or 0,label=c.mission_display_name}
end
-- The main file keeps the summary; a page loaded without it, as the tests do, counts one here.
local function summary(data)
 if mod.io_psyk_summary then return mod.io_psyk_summary(data)end
 local c=mod.io_psyk_local;if not Sum.ready(c,data)then local job=Sum.job(data);c=Sum.step(job,function()return true end)and job.sum or nil;mod.io_psyk_local=c end;return c
end
-- Each session's mission figures are its own loadout's (s.own) or, when that loadout was never taken into a mission, its weapon's.
function P.psyk(tracker)
 local session=mod.io_psykhanium and mod.io_psykhanium()
 local m=session and session.mission
 local out={saved={}}
 if m then
  local state=mod.io_collectors and mod.io_collectors.dps_snapshot and mod.io_collectors:dps_snapshot()
  local run={context=m.context,damage=m.damage,psyk_dps=state or m.psyk_dps,records=m.record_values}
  out.live=P.bench_session(run,"live",true)
 end
 local logs=mod.io_psykhanium_logs and mod.io_psykhanium_logs();local hist=logs and logs.data and logs.data.run_history or {}
 for i=#hist,1,-1 do local run=hist[i];if run.context then out.saved[#out.saved+1]=P.bench_session(run,"log"..tostring(run.id or i),false)end end
 local cur=out.live or out.saved[1]
 if cur then
  local sum,progress=summary(tracker and tracker.data)
  if not sum then out.counting=progress and string.format("Counting your missions, %d of %d.",progress.done,progress.total)or "Your missions are counted next time you are in the hub."end
  local all={cur};for _,s in ipairs(out.saved)do all[#all+1]=s end
  for _,s in ipairs(all)do s.mis,s.own=Sum.pick(sum,s.weapon,s.blessings,s.perks)end
  out.same={runs=cur.mis and cur.mis.runs or 0,diffs=Sum.diffs(cur.mis),data=cur.mis,own=cur.own}
  local rows,rseen={},{}
  for _,s in ipairs(all)do if not rseen[s.weapon]then rseen[s.weapon]=true;rows[#rows+1]=s end end
  out.rows=rows
 end
 return out
end
-- Decodes at most one uncached saved log per call; true once every log the tab reads is cached.
function P.warm()
 local logs=mod.io_psykhanium_logs and mod.io_psykhanium_logs();local hist=logs and logs.data and logs.data.run_history or {}
 for _,run in ipairs(hist)do if run.context and not saved_hits[run]then saved_armour(run);return false end end
 return true
end
return P
