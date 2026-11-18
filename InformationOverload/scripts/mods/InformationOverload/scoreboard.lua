-- Information Overload: the in-mission scoreboard's settings, places and numbers, read from what the mission already records.
local S={}
S.HOLD=.25
S.LAYOUTS={{"off","Off"},{"table","Squad Table"},{"cards","Squad Cards"},{"strip","Strip"}}
local VALID={off=true,table=true,cards=true,strip=true}
-- the layouts Extra Stats adds its figures to; the Strip stays as it is
S.EXTRA={table=true,cards=true}
-- what a tap and a hold of the key do in a mission
S.KEY_MODES={{"hold_board","Hold For Scoreboard, Tap For I/O"},{"tap_board","Tap For Scoreboard, Hold For I/O"},{"hold_only","Hold For Scoreboard Only"},{"tap_only","Tap For Scoreboard Only"}}
local KEY_VALID,HOLDS={hold_board=true,tap_board=true,hold_only=true,tap_only=true},{hold_board=true,hold_only=true}
-- tm is the Tracker Panel with the key held or while dead, tm_esc the one beside the Esc menu
S.KEYS={tm={"scoreboard_tm_x","scoreboard_tm_y"},tm_esc={"scoreboard_tm_esc_x","scoreboard_tm_esc_y"},squad={"scoreboard_squad_x","scoreboard_squad_y"}}
-- Unsaved places, in UI units: the squad under the Special Condition box, the Esc Tracker Panel beside the menu's buttons; the held one starts top right.
local DEFAULT={squad={445,385},tm={0,11},tm_esc={725,330}}
-- the Esc menu's buttons in a mission: its 500 wide list, centred 25 above the middle
S.ESC_MENU={185,330,500,370}
S.ESC_TM={1920-185-725,370}
function S.canvas(x,y,sw,sh)return (sw-1920)/2+x,(sh-1080)/2+y end
-- The Tab overlay hangs off the screen's left edge rather than a centred canvas, and is centred top to bottom.
function S.left(x,y,sw,sh)return x,(sh-1080)/2+y end
-- How many lines a text wraps to at a width, measure giving a string's width.
function S.lines(text,width,measure)
 local n,line=0,nil
 for word in tostring(text or ""):gmatch("%S+")do
  if line and measure(line.." "..word)<=width then line=line.." "..word else n=n+1;line=word end
 end
 return n
end
-- Where the squad may start with the Tab overlay up: under the Special Condition's description, which runs past the box's own 120 when it is long (it starts 60 down, 29 a line), or under the box Havoc sizes to its mutators.
function S.below(sw,sh,lines,box)
 local _,y=S.left(0,245+(box or 60+lines*29+8)+16,sw,sh);return y
end
-- With the Tab overlay up the held Tracker Panel is 800x250 at its place, unmoved the overlay's empty top right corner, 11 in, down to just above
-- Penances, level with Active Indulgences (the overlay's side panels' top plus 180); the overlay keeps its own mission block in the other corner.
-- A shorter screen scales it whole to fit; returns x, y, scale, whether the kill kinds show, and the size.
-- the size picked in Settings for the Tab overlay's Tracker Panel, a whole percent of its full 800 by 250, or nil to fit above Penances
S.TAB_SIZE={min=50,max=120}
function S.tab_size(get)local v=tonumber(get("scoreboard_tab_size"));if not v then return nil end;return math.max(S.TAB_SIZE.min,math.min(S.TAB_SIZE.max,math.floor(v+.5)))end
function S.tab_slot(sw,sh,get)
 local _,bottom=S.left(0,25+180-4,sw,sh);local room=bottom-11
 local f=math.min(1,room/250);local cats=true
 local pick=S.tab_size(get or function()end);if pick then f=pick/100 end
 local w,h=800*f,250*f;local x,y=S.place("tm",get or function()end,sw,sh,w,h)
 return x,y,f,cats,w,h
end
function S.options(get)
 local layout=get("scoreboard_layout");if not VALID[layout]then layout="cards"end
 -- the end screen has its own choice, Squad Cards unless changed
 local end_layout=get("scoreboard_end_layout");if not VALID[end_layout]then end_layout="cards"end
 local key=get("scoreboard_key_mode");if not KEY_VALID[key]then key="hold_board"end;local own=get("scoreboard_key")
 -- Extra Stats is on unless turned off
 return {layout=layout,end_layout=end_layout,extra=get("scoreboard_extra")~=false,this_mission=get("scoreboard_this_mission")==true,end_tm=get("scoreboard_end_tm")==true,esc=get("scoreboard_esc")~=false,dead=get("scoreboard_dead")==true,key=key,own_key=type(own)=="table"and own[1]~=nil}
end
-- The key's choice where it is pressed: on the end screen the Only choices give the panel back to the other gesture, and a Scoreboard Key of its own never opens the panel.
function S.key_mode(mode,finished,own)
 if own then return (mode=="tap_board"or mode=="tap_only")and "tap_only"or "hold_only"end
 if finished then return mode=="hold_only"and "hold_board"or mode=="tap_only"and "tap_board"or mode end
 return mode or "hold_board"
end
-- The key: a press in a mission (or ctx, its end screen) starts a hold, and a shorter press is a tap. A hold shows the scoreboard from S.HOLD, a tap turns it on for ctx until the next, and "panel" opens the panel.
local function flip(st,ctx)if st.on~=nil and st.on==ctx then st.on=nil else st.on=ctx end end
function S.press(st,now,open,mission,layout,mode,ctx)
 st.t0=nil
 if open then st.on=nil;return "close"end
 if not mission then return "toggle"end
 mode,ctx=mode or "hold_board",ctx or true
 -- with nothing to hold the key keeps its tap and hold, an Only choice giving the panel to the other gesture, so a hold leaves the game's Tab overlay alone
 if layout=="off"then st.t0,st.ctx,st.idle=now,ctx,true;st.mode=mode=="tap_only"and "tap_board"or mode=="hold_only"and "hold_board"or mode;return "hold"end
 st.idle=nil
 if mode=="tap_only"then flip(st,ctx);return "board"end
 st.t0,st.mode,st.ctx=now,mode,ctx;return "hold"
end
function S.release(st,now)
 local t0,mode=st.t0,st.mode;st.t0=nil;if not t0 then return end
 local tap=now-t0<S.HOLD
 if mode=="tap_board"then if tap then if not st.idle then flip(st,st.ctx)end;return end;st.on=nil;return "panel"end
 if tap and mode~="hold_only"then return "panel"end
end
function S.page(st)return st.page=="support"and "support"or "combat"end
function S.flip(st)st.page=st.page~="support"and "support"or nil end
function S.held(st,now,ctx)
 if st.on~=nil and st.on==ctx then return true end
 return not st.idle and st.t0~=nil and (st.mode==nil or HOLDS[st.mode]==true)and now-st.t0>=S.HOLD
end
-- Sizes in UI units; the squad box grows with the number of players, and the Squad Table and Squad Cards with Extra Stats on.
function S.size(kind,layout,n,record,extra)
 n=math.max(1,math.min(4,n or 4))
 -- the Tracker Panel keeps one size: the time to beat sits under its clock, not in a row of its own; beside the Esc menu it matches the
 -- menu's 370 height and reaches as far right as the menu sits in from the left
 if kind=="tm_esc"then return S.ESC_TM[1],S.ESC_TM[2]end
 if kind=="tm"then return 700,312 end
 if layout=="table"then if extra then return 1010,96+n*84 end;return 950,62+n*58 end
 if layout=="strip"then return 540,70+n*72 end
 return n*230+(n-1)*10,extra and 486 or 300
end
local function clamp(v,lo,hi)return math.max(lo,math.min(math.max(lo,hi),v))end
-- Places are kept as fractions of the screen; nothing is let off it. A squad not yet moved starts no higher than below.
function S.place(kind,get,sw,sh,w,h,below)
 local k=S.KEYS[kind];local fx,fy=tonumber(get(k[1])),tonumber(get(k[2]));local dx,dy=(kind=="tm_esc"and S.canvas or S.left)(DEFAULT[kind][1],DEFAULT[kind][2],sw,sh)
 if kind=="tm"then dx,dy=sw-11-w,11 end
 if below then dy=math.max(dy,below)end
 return clamp(fx and fx*sw or dx,0,sw-w),clamp(fy and fy*sh or dy,0,sh-h)
end
-- With Extra Stats the squad, not yet moved, comes down in size, type and all, to stay short of Penances (the Tab overlay's right column, 465 in from the right) and above
-- the player's own panel (135 up), which also keeps it above the end screen's bar (110.4 up); returns x, y and the scale.
function S.squad_place(get,sw,sh,w,h,below,extra)
 local k,f=S.KEYS.squad,1
 if extra and tonumber(get(k[1]))==nil and tonumber(get(k[2]))==nil then local dx,dy=S.place("squad",get,sw,sh,0,0,below)
  f=math.max(.1,math.min(1,(sw-465-dx)/w,(sh-135-dy)/h))end
 local x,y=S.place("squad",get,sw,sh,w*f,h*f,below);return x,y,f
end
-- the Squad Table with Extra Stats, brought down to fit its height, stretches across to Penances (465 in from the right) rather than
-- leave the room beside it empty; nil keeps its own width
function S.squad_wide(sw,x,w,f,layout,extra)if layout=="table"and extra and f<1 then return math.max(w*f,sw-465-x)end end
-- On the end screen the squad, unless moved, lines up with the game's four currency boxes under it, 216 wide and 25 apart in a row centred on
-- the screen: four Squad Cards with their right edges on the boxes', as near as the cards' 240 step allows, fewer kept to the middle by half a
-- step each, any other layout centred over the row.
function S.end_place(get,sw,sh,w,h,layout,extra)
 local x,y,f=S.squad_place(get,sw,sh,w,h,nil,extra);local k=S.KEYS.squad
 if tonumber(get(k[1]))~=nil or tonumber(get(k[2]))~=nil then return x,y,f end
 local row=(sw-(216*4+25*3))/2
 local n=math.max(1,math.min(4,math.floor((w+10)/240+.5)))
 return clamp(layout=="cards"and row+216-230+1.5+(4-n)*120*f or (sw-w*f)/2,0,sw-w*f),y,f
end
-- the Tracker Panel on the end screen rests just above the squad, centred on it
function S.end_tm_place(sw,x,y,w,tw,th)return clamp(x+(w-tw)/2,0,sw-tw),math.max(0,y-th-12)end
function S.fraction(px,py,sw,sh,w,h)return clamp(px,0,sw-w)/sw,clamp(py,0,sh-h)/sh end
-- Where the held Tracker Panel, or with squad the squad, shows with the game's Tab overlay up ("tab") or down ("plain"), the usual one first, nil
-- for no second: holding Tab as I/O's key always raises the overlay, while a tapped-on scoreboard, another key or being dead leaves it down until
-- Tab is held over it; the squad never shows while dead, and the panel shows held only with This Mission on
function S.tm_shapes(o,tab_key,squad)
 local hold_tab=tab_key==true and not o.own_key and (o.key=="hold_board"or o.key=="hold_only")
 if hold_tab and (squad or o.this_mission)then return "tab",not squad and o.dead and "plain"or nil end
 return "plain","tab"
end
-- the held Tracker Panel's box in a shape, at its place: the Tab overlay's slot, or its own panel at its tallest, so a best-clear line never moves it
function S.tm_box(shape,sw,sh,get)
 if shape=="tab"then local x,y,_,_,w,h=S.tab_slot(sw,sh,get);return x,y,w,h end
 local w,h=S.size("tm",nil,nil,true);local x,y=S.place("tm",get,sw,sh,w,h);return x,y,w,h
end
-- What the Move screen shows for kind, every place read as the HUD reads it through get: first the box, in the shape and place it usually shows,
-- then an outline wherever it shows instead, each {x,y,w,h,label,say,strip}, strip marking a Tracker Panel whose bottom 50 shows only with a best clear.
-- below is how far down an unmoved squad starts under this mission's Special Condition with the Tab overlay up, where that is known.
function S.move_boxes(kind,o,tab_key,layout,n,sw,sh,get,below)
 local main,other=S.tm_shapes(o,tab_key,kind=="squad");local out={}
 local SAY={["With The Tab Overlay"]="with the Tab overlay up",["Without The Tab Overlay"]="without the Tab overlay"}
 local function add(x,y,w,h,label,strip)out[#out+1]={x=x,y=y,w=w,h=h,label=label,say=SAY[label],strip=strip}end
 if kind=="tm"then
  for _,shape in ipairs({main,other})do local x,y,w,h=S.tm_box(shape,sw,sh,get);add(x,y,w,h,shape=="tab"and "With The Tab Overlay"or "Without The Tab Overlay",shape=="plain")end
 elseif kind=="tm_esc"then local w,h=S.size("tm_esc",nil,nil,true);local x,y=S.place("tm_esc",get,sw,sh,w,h);add(x,y,w,h,nil,true)
 else
  local extra=o.extra and S.EXTRA[layout]==true;local w,h=S.size("squad",layout,n,true,extra)
  local px,py,pf=S.squad_place(get,sw,sh,w,h,nil,extra);local tx,ty,tf=S.squad_place(get,sw,sh,w,h,below,extra)
  local plain,tab={px,py,S.squad_wide(sw,px,w,pf,layout,extra)or w*pf,h*pf,"Without The Tab Overlay"},{tx,ty,S.squad_wide(sw,tx,w,tf,layout,extra)or w*tf,h*tf,"With The Tab Overlay"}
  if main=="tab"then add(unpack(tab));if other then add(unpack(plain))end else add(unpack(plain));if other then add(unpack(tab))end end
 end
 -- an outline where the box already is says nothing
 local keep,b={out[1]},out[1]
 for i=2,#out do local g=out[i];if math.abs(g.x-b.x)>.5 or math.abs(g.y-b.y)>.5 or math.abs(g.w-b.w)>.5 or math.abs(g.h-b.h)>.5 then keep[#keep+1]=g end end
 return keep
end
function S.commas(n)local s=string.format("%.0f",n or 0);local r=s:reverse():gsub("(%d%d%d)","%1,"):reverse();return (r:gsub("^,",""))end
function S.clock(s)s=math.max(0,math.floor(s));return string.format("%d:%02d",math.floor(s/60),s%60)end
-- a name cut to n characters, never through the middle of one
function S.cut(s,n)
 s=tostring(s or "");local count,i=0,1
 while i<=#s do local b=s:byte(i);local len=b>=240 and 4 or b>=224 and 3 or b>=192 and 2 or 1;count=count+1
  if count>n then return s:sub(1,i-1).."…"end;i=i+len end
 return s
end
local CATS={{"horde_melee","Melee Horde"},{"horde_ranged","Ranged Horde"},{"elite","Elite"},{"special","Special"},{"boss","Boss"}}
S.CATS=CATS
-- Bests from the saved history, worked out once a mission, again once it is over and again when the server's time for it arrives: the fastest clear and the most kills on this map, difficulty and mode.
local function bests(src,deps,c)
 local cache,final,backend=src.cache,src.final==true,src.backend==true
 if cache.mission==src.m and cache.basis==src.basis and cache.final==final and cache.backend==backend then return cache end
 cache.mission,cache.basis,cache.final,cache.backend,cache.clear,cache.kills,cache.clear_clock=src.m,src.basis,final,backend,nil,nil,nil
 local history=src.tracker and src.tracker.data and src.tracker.data.run_history;local skip=src.exclude
 -- a finished mission is already saved, so its bests are the ones from before it
 if skip then local kept={};for _,run in ipairs(history or {})do if run.id~=skip then kept[#kept+1]=run end end;history=kept end
 local maps=deps.Times.build(history,c.mode,src.basis)[tostring(c.difficulty)]
 local best=maps and maps[c.mission_name];local t=best and best.completion_time
 -- the server's times and the mission clock's cannot be compared, so a best is set only beside a time from the same clock
 cache.clear=t and (t.source=="backend")==backend and t.seconds or nil
 -- with the server's time in and no best the server timed, the mission clock's best stays, set against this mission's own mission clock
 if not cache.clear and t and backend and t.source~="backend"then cache.clear,cache.clear_clock=t.seconds,true end
 for _,run in ipairs(src.tracker and deps.runs(src.tracker)or {})do local rc=run.context or {}
  if (skip==nil or run.id~=skip)and rc.mission_name==c.mission_name and rc.mode==c.mode and tostring(rc.difficulty)==tostring(c.difficulty)and type(run.kills)=="number"then cache.kills=math.max(cache.kills or 0,run.kills)end
 end
 return cache
end
function S.warm(src,deps)if src.m and src.m.context then bests(src,deps,src.m.context)end end
local function this_mission(src,deps,c,counts)
 local m=src.m;local t={title=deps.title(src.tracker,c)};if deps.parts then t.mission,t.difficulty=deps.parts(src.tracker,c)end
 local own=counts.personal or {};t.downs,t.deaths=own.downs or 0,own.deaths or 0
 for i=#(m.lethality_events or {}),1,-1 do local e=m.lethality_events[i]
  if e.personal then local s=e.sources and e.sources[1];t.last_down=s and s.label;break end
 end
 local segs=m.combat_timeline and m.combat_timeline.segments
 if segs and #segs>0 then t.streak=segs[#segs].streak and segs[#segs].streak.current or 0;local best=0;for _,s in ipairs(segs)do best=math.max(best,s.streak and s.streak.best or 0)end;t.streak_best=best end
 for _,s in ipairs(segs or {})do if s.health_streak then t.health_streak_best=math.max(t.health_streak_best or 0,s.health_streak.best or 0)end end
 if segs and segs[#segs]and segs[#segs].health_streak then t.health_streak=segs[#segs].health_streak.current end
 t.kills=type(m.kills)=="number"and m.kills or 0;t.cats={}
 local k=m.kill_categories or {};for i,e in ipairs(CATS)do t.cats[i]={e[2],k[e[1]]or 0}end
 local b=bests(src,deps,c);t.best_clear,t.kills_best=b.clear,b.kills
 if b.clear_clock then local ct=m.completion_time;t.clock_seconds=ct and ct.source=="mission_clock"and ct.seconds or nil;if not t.clock_seconds then t.best_clear=nil end end
 t.full=m.full~=false;t.final=src.final==true;t.won=m.completion_time~=nil
 return t
end
-- Extra Stats' figures for a row. A saved match from before one was kept leaves it nil, drawn as a dash; melee and ranged split the lesser enemies and elites.
local function extras(src,r,id,you,kills,field,deps)
 local team,party,live=src.team,src.party,not src.saved
 if team and team.shield_partition or not team and live then r.boss=team and deps.Team.summary(team,id,"boss")[field]or 0 end
 if team and team.hit_counts or not team and live then local p=team and team.members and team.members[id];local n=p and p.hits;r.weak,r.crit=n and n.weakspot or 0,n and n.critical or 0 end
 r.lesser,r.monst=(kills.horde_melee or 0)+(kills.horde_ranged or 0),kills.boss or 0
 if party and party.fixed_roles or not party and live then r.melee=(kills.trash_fixed_melee or 0)+(kills.elite_melee or 0);r.ranged=(kills.trash_fixed_ranged or 0)+(kills.elite_ranged or 0)end
 local cats=you and src.m.kill_categories;if cats then if cats.horde_melee or cats.horde_ranged then r.lesser=(cats.horde_melee or 0)+(cats.horde_ranged or 0)end;r.monst=cats.boss or r.monst end
end
-- the Support page's figures, kept on the mission as support[character id]
S.SUPPORT={"revives","saves","coherency","blocked","dodged","blitzes","abilities"}
local TOP={"damage","kills","elites","specials","boss","weak","crit","lesser","monst","melee","ranged","revives","saves","coherency","coherency_share","blocked","dodged","blitzes","abilities"}
local KINDS={"lesser","elites","specials","monst"}
local function support(src,r,id)
 local all=src.m.support;local mine=all and all[id];local none=(all or not src.saved)and 0 or nil
 for _,f in ipairs(S.SUPPORT)do r[f]=mine and mine[f]or none end
 -- time in coherency as a share of the time alive in the mission; a match saved before that was kept shows its time
 r.tracked=mine and mine.tracked or nil
 if r.tracked and r.tracked>0 then r.coherency_share=math.min(1,(r.coherency or 0)/r.tracked)elseif not src.saved and (r.tracked or 0)==0 then r.coherency_share=0 end
end
-- a name cleaned to nothing counts as no name
local function named(deps,s)s=deps.clean(s);if s~="" then return s end end
local function squad(src,deps,c,counts)
 local m,team,party=src.m,src.team,src.party;local me=tostring(c.character)
 local roster=c.operative_roster or {};local rows={}
 if not next(roster)then roster={[me]={name=c.character_name,class=c.class,personal=true}}end
 local total=team and deps.Team.summary(team,nil,"total");local field=src.overkill and "reported"or "useful"
 for id,p in pairs(roster)do id=tostring(id);local you=p.personal==true or id==me
  local pk=party and party.members and party.members[id];local kills=pk and pk.kills or {}
  local inc=you and counts.personal or counts.members and counts.members[id]and counts.members[id].counts or {}
  local dmg=team and deps.Team.summary(team,id,"total")[field]or 0
  local r={id=id,you=you,left=p.left==true,name=named(deps,p.name)or "Unknown",class=deps.class_names[p.class]or p.class or "",arch=p.class,damage=dmg,
   kills=kills.total or 0,elites=kills.elite or 0,specials=kills.special or 0,downs=inc.downs or 0,deaths=inc.deaths or 0}
  -- your own row counts as This Mission does
  if you then local cats=m.kill_categories or {};r.kills=type(m.kills)=="number"and m.kills or r.kills;r.elites=cats.elite or r.elites;r.specials=cats.special or r.specials end
  extras(src,r,id,you,kills,field,deps);support(src,r,id)
  -- the table's kinds bar is each kind's share of this player's damage, where the match kept it
  r.kind_damage=team and deps.Team.kinds(team,id,field)or nil
  r.share=total and total[field]>0 and dmg/total[field]or 0
  -- each down and death with its time and what did it, and who they picked up, for the hover on their Downs, Deaths and Revives
  local o=type(m.timing_origin)=="number"and m.timing_origin*1000 or 0;r.falls={}
  for _,e in ipairs(m.lethality_events or {})do if (you and e.personal==true)or (not you and e.victim~=nil and tostring(e.victim)==id)then local s=e.sources and e.sources[1]
   r.falls[#r.falls+1]={t=type(e.at)=="number"and math.max(0,(e.at-o)/1000)or nil,died_t=type(e.died_at)=="number"and math.max(0,(e.died_at-o)/1000)or nil,outcome=e.outcome,what=s and s.label or nil,n=#r.falls+1}end end
  -- untimed ones after the timed, in recorded order, as the End Screen card has them
  table.sort(r.falls,function(a,b)if (a.t==nil)~=(b.t==nil)then return b.t==nil end;if a.t and a.t~=b.t then return a.t<b.t end;return a.n<b.n end)
  for _,f in ipairs(r.falls)do f.n=nil end
  r.lifted={};for target,n in pairs(m.pickup_pairs and m.pickup_pairs[you and me or id]or {})do local q=roster[target]or roster[tostring(target)]
   r.lifted[#r.lifted+1]={name=q and named(deps,q.name)or (tostring(target)==me and named(deps,c.character_name))or "A teammate",n=n}end
  table.sort(r.lifted,function(a,b)if a.n~=b.n then return a.n>b.n end;return a.name<b.name end)
  rows[#rows+1]=r
 end
 table.sort(rows,function(a,b)if a.you~=b.you then return a.you end;if a.left~=b.left then return b.left end;if a.damage~=b.damage then return a.damage>b.damage end;return a.id<b.id end)
 for i=#rows,5,-1 do rows[i]=nil end
 local top={};for _,f in ipairs(TOP)do local n=0;for _,r in ipairs(rows)do n=math.max(n,r[f]or 0)end;top[f]=n end
 for _,r in ipairs(rows)do r.top={};for f,n in pairs(top)do r.top[f]=n>0 and r[f]==n end end
 -- the squad's total of each kind, for the key under the Squad Table
 rows.totals={};for _,f in ipairs(KINDS)do local n=0;for _,r in ipairs(rows)do n=n+r[f]end;rows.totals[f]=n end
 return rows
end
-- src: m (the live or just finished mission), tracker (holds the history), team and party (the squad tables), basis, overkill, cache, and for a finished one final, exclude and backend, once the server has timed it.
function S.model(src,deps)
 local m=src.m;if not m or not m.context then return nil end
 local c=m.context;local counts=deps.incident_counts(m)or {}
 return {tm=this_mission(src,deps,c,counts),squad=squad(src,deps,c,counts)}
end
-- what the record line says at a given clock, or nil when there is no best to chase
function S.record(tm,seconds)
 seconds=tm.clock_seconds or seconds
 if not tm.full or not tm.best_clear or not seconds or tm.final and not tm.won then return nil end
 local left=tm.best_clear-seconds
 if tm.final and left>0 then return "New Best Clear",S.clock(left).." under your old best clear",true end
 if left>0 then return "Record In Reach",S.clock(math.ceil(left)).." to beat your best clear",true end
 return "Best Clear Passed",S.clock(-left).." over your best clear",false
end
return S
