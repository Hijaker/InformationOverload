-- Information Overload: shared drawing helpers and Match History figures for the mission pages.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Records=mod:io_dofile(base.."records")
local H=mod:io_dofile(base.."history_presentation")
local Times=mod:io_dofile(base.."mission_times")
local C,DASH=D.c,Overview.dash
local M={dash=DASH}
local Identity=mod:io_dofile(base.."player_identity")
local FriendsStats=mod:io_dofile(base.."friend_stats")
local Roster=mod:io_dofile(base.."operative_roster")
-- Category membership follows the game's Havoc table, not names or icon artwork.
local havoc_ok,HavocTemplates=pcall(require,"scripts/settings/circumstance/templates/havoc_circumstance_template")
local function havoc_modifier(id)
 return havoc_ok and type(HavocTemplates)=="table"and HavocTemplates[id]~=nil
end
M.class_order={"veteran","zealot","psyker","ogryn","adamant","broker","cryptic"}
M.fmt=Overview.compact
function M.one(n)if type(n)~="number"then return DASH end;local s=string.format("%.1f",n);local i,f=s:match("^(%d+)(%.%d)$");return i and Overview.commas(tonumber(i))..f or s end
-- a dropdown anywhere on the page; options are {value,label,current,n,ind} or {head=label}
function M.dropdown(view,cv,popup,id,x,y,w,label,value,options,pick)
 local open=view.dd==id
 view:_ctl(cv,"base",x,y,w,34,function()view.dd=not open and id or nil end,{open=open})
 local lw=view:_w(label,16);local room=w-lw-56;local full=value
 if view:_w(value,16)>room then local s=value;while #s>1 and view:_w(s.."...",16)>room do repeat local b=s:byte(-1);s=s:sub(1,-2)until #s==0 or b<128 or b>=192 end;value=s.."..."end
 cv:text(label,x+12,y,lw+4,34,16,C.label);cv:pick(full,value,x+20+lw,y,room)
 cv:chevron(x+w-24,y+13,"down",10,C.value)
 if not open then return end
 local pw=math.max(w,260);for _,o in ipairs(options)do if o.label then pw=math.max(pw,view:_w(o.label,16)+(o.ind and 30 or 12)+(o.n and 140 or 44))end end;pw=math.min(pw,D.width)
 local px,py=math.min(x,D.right-pw),y+38;local h=#options*30+2
 view:_panel(popup,px,py,pw,h)
 for i,o in ipairs(options)do local oy=py+1+(i-1)*30
  if i>1 then popup:rect(px+1,oy,pw-2,1,C.line)end
  if o.head then popup:text(o.head,px+12,oy,pw-24,30,14,C.muted)
  else
   if o.value==o.current then popup:rect(px+1,oy,pw-2,30,C.on);popup:rect(px+1,oy,3,30,C.sel)end
   popup:text(view:_fit(o.label,16,pw-(o.n and 140 or 44)-(o.ind and 18 or 0)),px+(o.ind and 30 or 12),oy,pw-(o.n and 140 or 44),30,16,o.value==o.current and C.gold_hi or C.value)
   if o.n then popup:text(o.n,px+pw-132,oy,120,30,14,C.muted,"right")end
   view:_hit("popup",px+1,oy,pw-2,30,function()view.dd=nil;pick(o.value)end,{bg=C.fill_h})
  end
 end
end
-- label/value rows; r={l,v,ind=,head=,note=}
function M.open_run(view,id)
 view.io_params=view.io_params or {};view.io_params.run=id;view.io_tab="overview"
 if view.scroll then view.scroll.run=0 end
 view:_go("run")
end
local function kv_value(view,cv,x,y,w,value,source_id,dim)
 cv:text(tostring(value),x,y,source_id and math.max(1,w-14)or w,26,16,source_id and C.gold_hi or dim and C.muted or C.value,"right")
 if source_id then cv:chevron(x+w-9,y+9,"right",7,C.gold_hi)end
 if source_id then view:_hit("base",x,y,w,26,function()M.open_run(view,source_id)end,{under=C.gold_hi})end
end
function M.kv(view,cv,x,y,w,rows)
 for i,r in ipairs(rows)do local ry=y+(i-1)*26
  if r.head then cv:text(r.head,x+36,ry,w-60,26,16,C.gold)
  elseif r.note then cv:text(r.note,x+36,ry,w-60,26,14,C.muted,"left",D.font.medium)
  else
   local ix=r.ind and 18 or 0;cv:text(r.l,x+36+ix,ry,w-240-ix,26,16,C.label)
   if r.parts then
    kv_value(view,cv,x+w-413,ry,190,r.parts[1]and r.parts[1].v or DASH,r.parts[1]and r.parts[1].source_id)
    kv_value(view,cv,x+w-213,ry,190,r.parts[2]and r.parts[2].v or DASH,r.parts[2]and r.parts[2].source_id)
   else kv_value(view,cv,x+w-413,ry,400,r.v==nil and DASH or r.v,r.source_id,r.dim)end
  end
 end
 return #rows*26
end
-- a table: cols={{label,edge}} where edge is the right edge from x (nil = left-aligned first column); cells may be {text,sub=}
function M.table_h(n)return 30+n*32 end
function M.table(view,cv,x,y,w,cols,rows)
 cv:rect(x+25,y,w-50,30,C.fill,true)
 for i,c in ipairs(cols)do if c[2]then cv:text(c[1],x+c[2]-200,y,190,30,14,C.muted,"right")else cv:text(c[1],x+35,y,300,30,14,C.muted)end end
 cv:rect(x+25,y+29,w-50,1,C.frame,true)
 for r,row in ipairs(rows)do local ry=y+30+(r-1)*32
  for i,c in ipairs(cols)do local cell=row[i];local s=type(cell)=="table"and cell[1]or cell;s=s==nil and DASH or tostring(s)
   if c[2]then
    local cx=x+c[2]-300;local source=type(cell)=="table"and cell.source_id
    cv:text(s,cx,ry,source and 272 or 290,32,16,s==DASH and C.muted or source and C.gold_hi or C.value,"right")
    if source then cv:chevron(cx+280,ry+12,"right",7,C.gold_hi)end
    if source then view:_hit("base",cx,ry,290,32,function()M.open_run(view,source)end,{under=C.gold_hi})end
   else local lim=math.max(120,(cols[2]and cols[2][2]or w)-120);cv:text(view:_fit(s,16,lim-2),x+35,ry,lim,32,16,C.label)
    if type(cell)=="table"and cell.sub then local tw=view:_w(s,16);cv:text(cell.sub,x+43+tw,ry,200,32,14,C.muted,"left",D.font.medium)end
   end
  end
  cv:rect(x+25,ry+31,w-50,1,C.line,true)
 end
 return 30+#rows*32
end
-- two columns of cards; card={h=,wide=,col=,draw=function(x,y,w)}
function M.layout(view,cards,y0)
 local L,R,W=D.left,D.col2,D.col;local cols={y0,y0}
 for _,c in ipairs(cards)do
  if c.wide then local top=math.max(cols[1],cols[2]);c.draw(L,top,D.width);cols[1]=top+c.h+(c.gap or 10);cols[2]=cols[1]
  else local i=c.col or (cols[1]<=cols[2]and 1 or 2);c.draw(i==1 and L or R,cols[i],W);cols[i]=cols[i]+c.h+10 end
 end
 return math.max(cols[1],cols[2])
end
function M.section(view,cv,x,y,w,title,lead,right)
 local tw=view:_w(title,20);cv:text(title,x,y,tw+6,32,20,C.gold)
 if lead then cv:text(lead,x+tw+14,y+2,600,32,14,C.muted,"left",D.font.medium)end
 if right then local rw=view:_w(right[2],16);cv:text(right[2],x+w-rw-4,y,rw+4,32,16,C.value);local lw=view:_w(right[1],16);cv:text(right[1],x+w-rw-lw-14,y,lw+4,32,16,C.label)end
 cv:rect(x,y+35,w,1,C.frame,true)
end
-- Match History rows
local function basis()local o=mod.io_display_options and mod.io_display_options()or {};return o.boss_map_timing and "boss"or "victory"end
local function clear_time(run)
 local t=run.victory and Times.completion(run);if not t or type(t.seconds)~="number"then return nil end
 if t.source=="mission_clock"then local marks=run.completion_markers or {};local chosen=basis()=="boss"and marks.boss_death or marks.victory_request or marks.victory_transition;return chosen and Times.marker(run,chosen)or nil end
 return t.seconds
end
local zone_of
do local ok,Missions=pcall(require,"scripts/settings/mission/mission_templates");local ok2,Zones=pcall(require,"scripts/settings/zones/zones")
 zone_of=function(c)
  if not ok or not ok2 or type(Missions)~="table"or type(Zones)~="table"then return nil end
  local mission=Missions[c.mission_name];local zone=mission and Zones[mission.zone_id];local key=zone and zone.name;if not key then return nil end
  local lok,label=pcall(Localize,key);if not lok or type(label)~="string"or label==key or label:find("<unlocalized",1,true)then return nil end
  return (label:match('"([^"}]+)"')or label:match('“([^”]+)”')or label)
 end
end
-- the key Played With files a teammate under, or nil for you, a bot or a row with no name
local function mate_key(c,id,row)
 if row.personal or tostring(id)==tostring(c.character)then return nil end
 local name=row.name;if type(name)~="string"or name==""or name:find("[BOT]",1,true)or row.human==false or row.is_bot then return nil end
 return Identity.key(row)or "name:"..name
end
-- each player as their newest match in any mode has them (the runs come newest first), so the filter gives one player one name whatever it shows;
-- a Steam id or Steam name that match did not save is taken from the key or the newest match that did
-- and as tracked when any match has them a friend or a tracked player, so one player sits in one group whatever mode is shown
local function newest_mates(runs,tracked)
 local best,steam,known={},{},{}
 for _,run in ipairs(runs)do local c=run.context
  for id,row in pairs(c.operative_roster or {})do local k=mate_key(c,id,row)
   if k then best[k]=best[k]or row;steam[k]=steam[k]or row.steam_name
    local key=Identity.key(row);if not known[k]and key and (FriendsStats.is_friend(key,row)or Identity.lookup(tracked,key))then known[k]=true end
   end
  end
 end
 local out={}
 for k,row in pairs(best)do local who={};for f,v in pairs(row)do who[f]=v end
  who.steam_id=who.steam_id or not k:find(":",1,true)and k or nil;who.steam_name=who.steam_name or steam[k];out[k]=who
 end
 return out,known
end
local function day_number(s)local y,m,d=tostring(s or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");if not y then return nil end;return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=12})/86400 end
function M.history(tracker,scope)
 Identity.learn(tracker.data)
 local tracked=tracker.data.friend_tracking and tracker.data.friend_tracking.tracked or {}
 local runs=Overview.runs(tracker);local everyone,known=newest_mates(runs,tracked)
 local out={};local today=os.time({year=tonumber(os.date("%Y")),month=tonumber(os.date("%m")),day=tonumber(os.date("%d")),hour=12})/86400
 for _,run in ipairs(runs)do local c=run.context
  if c.mode==scope.mode and (scope.diff=="all"or Overview.diff_label(c)==scope.diff)and (not scope.patch or c.patch==scope.patch)then
   -- the player's own useful damage, as Most Damage In A Mission counts it, so none for a match with no squad tally
   local own=Records.run_useful(run);local reported=own;local ts=tostring(run.started_at or "")
   local day=ts:match("^(%d%d%d%d%-%d%d%-%d%d)");local dn=day_number(day)
   local r={run=run,id=run.id,ts=ts,day=day,age=dn and today-dn or nil,map=tracker:run_mission_name(c),mapid=c.mission_name or "?",zone=zone_of(c),
    diff=H.difficulty_short(c):gsub("Auric Maelstrom","Auric M."),win=run.victory==true,partial=run.full==false,cls=c.class,kills=type(run.kills)=="number"and run.kills or nil,
    dmg=reported~=nil and own or nil,secs=clear_time(run),team={},mates={},mate_rows={},tracked_mates={},mods={},mod_plain={},mod_havoc={}}
   local y,mo,d,hm=ts:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d:%d%d)");r.date=d and d.."/"..mo or DASH;r.clock=hm or ""
   for id,row in pairs(c.operative_roster or {})do if not row.personal and tostring(id)~=tostring(c.character)then
    if row.class then r.team[row.class]=true end
    local player_key=mate_key(c,id,row)
    if player_key then
     r.mates[player_key]=true;r.mate_rows[player_key]=everyone[player_key];r.tracked_mates[player_key]=known[player_key]
    end
   end end
   for id,label in pairs(c.modifiers or {})do if id~="mutator_increased_difficulty"and id~="mutator_highest_difficulty"and type(label)=="string"and label~=""and not label:find("<unlocalized",1,true)then r.mods[label]=true;local parent=label:match("^(.-) %([^()]+%)$");if parent then r.mods[parent]=true else r.mod_plain[label]=true end;if havoc_modifier(id)then r.mod_havoc[parent or label]=true end end end
   out[#out+1]=r
  end
 end
 return out
end
function M.blank_filters()return {res="all",date="all",cls="all",team={},mods={},maps={},kinds={},players={}}end
function M.filter_count(f)local n=0;for _,k in ipairs({"res","date","cls"})do if f[k]~="all"then n=n+1 end end;for _,k in ipairs({"team","mods","maps","kinds","players"})do if next(f[k])then n=n+1 end end;return n end
local function kind(r)return r.partial and "partial"or "full"end
-- each filter on its own, so the panel can count what one list would leave with the others as they are
local CHECK={
 res=function(r,f)return not (f.res=="win"and not r.win or f.res=="loss"and r.win)end,
 date=function(r,f)
  if f.date=="7"and not (r.age and r.age<7)or f.date=="30"and not (r.age and r.age<30)then return false end
  return not (f.date:sub(1,2)=="d:"and r.day~=f.date:sub(3))
 end,
 cls=function(r,f)return f.cls=="all"or r.cls==f.cls end,
 team=function(r,f)for c in pairs(f.team)do if not r.team[c]then return false end end;return true end,
 mods=function(r,f,mode)if mode=="havoc"then for m in pairs(f.mods)do if not r.mods[m]then return false end end end;return true end,
 maps=function(r,f)return not f.maps[r.mapid]end,
 kinds=function(r,f)return not f.kinds[kind(r)]end,
 players=function(r,f)for n in pairs(f.players)do if not r.mates[n]then return false end end;return true end,
}
local ORDER={"res","date","cls","team","mods","maps","kinds","players"}
-- skip leaves one filter out
function M.keep(r,f,mode,skip)
 for _,k in ipairs(ORDER)do if k~=skip and not CHECK[k](r,f,mode)then return false end end
 return true
end
local SORT={new=function(r)return 0 end,old=function(r)return 0 end,dmg=function(r)return -(r.dmg or -1)end,kills=function(r)return -(r.kills or -1)end,fast=function(r)return r.secs or 1e9 end}
M.sorts={{"new","Newest"},{"old","Oldest"},{"dmg","Highest Damage"},{"kills","Most Kills"},{"fast","Fastest"}}
function M.apply(rows,f,mode,sort)
 local out={};for _,r in ipairs(rows)do if M.keep(r,f,mode)then out[#out+1]=r end end
 local key=SORT[sort]or SORT.new
 table.sort(out,function(a,b)local x,y=key(a),key(b);if x~=y then return x<y end;if a.ts~=b.ts then if sort=="old"then return a.ts<b.ts end;return a.ts>b.ts end;return (a.id or 0)>(b.id or 0)end)
 return out
end
-- the filter panel's lists come from all of the scope's runs, and each count is of the runs the other filters leave: a list you pick
-- one of, or leave things out of, is counted as if it were not set, and a list where all the picks must hold counts what one more
-- pick would leave; an option the rest leave nothing for stays, at 0. Worked out again only when the runs or the filters change.
local last
-- Played With names each player as the mission page does, from their newest match in any mode, and those under Tracked Players by Steam name
local named
local function mate_labels(rows,tracked)
 if named and named.rows==rows then return named.labels end;local labels={}
 for _,r in ipairs(rows)do for k,who in pairs(r.mate_rows or {})do if labels[k]==nil then labels[k]=Roster.name(who,tracked[k],Records)end end end
 named={rows=rows,labels=labels};return labels
end
local function sig(f)local out={f.res,f.date,f.cls}
 for _,k in ipairs({"team","mods","maps","kinds","players"})do local keys={};for v in pairs(f[k])do keys[#keys+1]=tostring(v)end;table.sort(keys);out[#out+1]=k..":"..table.concat(keys,"\1")end
 return table.concat(out,"\2")
end
function M.options(rows,mode,patch_label,f,include_remaining)
 f=f or M.blank_filters()
 local key=sig(f)..mode..patch_label..tostring(include_remaining==true)
 if last and last.rows==rows and last.key==key then return last.o end
 local base={};for _,list in ipairs({"res","date","cls","team","mods","maps","kinds","players"})do
  local skip=(list=="res"or list=="date"or list=="cls"or list=="maps"or list=="kinds")and list or nil;local kept={}
  for _,r in ipairs(rows)do if M.keep(r,f,mode,skip)then kept[#kept+1]=r end end;base[list]=kept end
 local function count(list,p)local n=0;for _,r in ipairs(base[list])do if p(r)then n=n+1 end end;return n end
 local function any(p)for _,r in ipairs(rows)do if p(r)then return true end end end
 local o={}
 o.res={{v="all",label="All Results",n=#base.res}};for _,e in ipairs({{"win","Wins",true},{"loss","Losses",false}})do local p=function(r)return r.win==e[3]end;if any(p)then o.res[#o.res+1]={v=e[1],label=e[2],n=count("res",p)}end end
 o.date={{v="all",label="All Dates",n=#base.date}}
 for _,e in ipairs({{"7","Last 7 Days"},{"30","Last 30 Days"}})do local d=tonumber(e[1]);local p=function(r)return r.age and r.age<d end;if any(p)then o.date[#o.date+1]={v=e[1],label=e[2],n=count("date",p)}end end
 o.date[#o.date+1]={v="patch",label="This Patch ("..patch_label..")",n=#base.date}
 local days,seen={},{};for _,r in ipairs(rows)do if r.day and not seen[r.day]then seen[r.day]=0;days[#days+1]=r.day end end
 for _,r in ipairs(base.date)do if r.day then seen[r.day]=seen[r.day]+1 end end
 table.sort(days,function(a,b)return a>b end);for _,d in ipairs(days)do o.date[#o.date+1]={v="d:"..d,label=H.date_label(d),n=seen[d],ind=true}end
 o.cls={{v="all",label="All Classes",n=#base.cls}};o.team={}
 for _,c in ipairs(M.class_order)do local p=function(r)return r.cls==c end;if any(p)then o.cls[#o.cls+1]={v=c,label=Overview.class_names[c],n=count("cls",p)}end
  p=function(r)return r.team[c]end;if any(p)then o.team[#o.team+1]={v=c,label=Overview.class_names[c],n=count("team",p)}end end
 local tracked={};for _,r in ipairs(rows)do for name in pairs(r.tracked_mates or {})do tracked[name]=true end end
 local function names(field)local set={};for _,r in ipairs(rows)do for k in pairs(r[field])do set[k]=0 end end;for _,r in ipairs(base[field=="mates"and "players"or "mods"])do for k in pairs(r[field])do set[k]=set[k]+1 end end
  local labels=field=="mates"and mate_labels(rows,tracked)or {}
  local list={};for k,n in pairs(set)do list[#list+1]={v=k,label=labels[k]or k,n=n}end;table.sort(list,function(a,b)local x,y=a.label:lower(),b.label:lower();if x==y then return a.v<b.v end;return x<y end);return list end
 local primary,remaining={},{}
 for _,p in ipairs(names("mates"))do local list=tracked[p.v]and primary or remaining;list[#list+1]=p end
 o.players={}
 if include_remaining and #primary>0 and #remaining>0 then o.players[#o.players+1]={head="Tracked Players"}end
 for _,p in ipairs(primary)do o.players[#o.players+1]=p end
 if include_remaining then
  if #primary>0 and #remaining>0 then o.players[#o.players+1]={head="Remaining"}end
  for _,p in ipairs(remaining)do o.players[#o.players+1]=p end
 end
 o.mods=mode=="havoc"and names("mods")or nil
 if o.mods then
  local groups={};for _,o in ipairs(o.mods)do
   local parent,sub=o.label:match("^(.-) %(([^()]+)%)$");parent=parent or o.label
   local g=groups[parent];if not g then g={};groups[parent]=g end
   if sub then g[#g+1]={v=o.v,label=sub,n=o.n,ind=true} else g.parent=o end
  end
  local ordered={};for name in pairs(groups)do ordered[#ordered+1]=name end;table.sort(ordered,function(a,b)return a:lower()<b:lower()end)
  local sections={havoc={},other={}}
  for _,name in ipairs(ordered)do local havoc=false;for _,r in ipairs(rows)do if r.mod_havoc and r.mod_havoc[name]then havoc=true;break end end
   local list=havoc and sections.havoc or sections.other;list[#list+1]=name
  end
  o.mods={};for _,section in ipairs({{"Havoc Modifiers",sections.havoc},{"Sub-Modifiers",sections.other}})do
   if #section[2]>0 then o.mods[#o.mods+1]={head=section[1]}end
   for _,name in ipairs(section[2])do local g=groups[name];o.mods[#o.mods+1]=g.parent
   -- A plain parent is itself a variant only when it occurs without a suffix.
   local plain=false;for _,r in ipairs(rows)do if r.mod_plain and r.mod_plain[name]then plain=true;break end end
   if #g+(plain and 1 or 0)>1 then
    table.sort(g,function(a,b)return a.label:lower()<b.label:lower()end)
    for _,child in ipairs(g)do o.mods[#o.mods+1]=child end
   end
   end
  end
 end
 local zones,maps={},{};for _,r in ipairs(rows)do local z=r.zone or "";if not maps[r.mapid]then maps[r.mapid]={v=r.mapid,label=r.map,n=0,z=z,ind=r.zone~=nil};zones[z]=true end end
 for _,r in ipairs(base.maps)do maps[r.mapid].n=maps[r.mapid].n+1 end
 local zl={};for z in pairs(zones)do zl[#zl+1]=z end;table.sort(zl)
 o.maps={};for _,z in ipairs(zl)do local list={};for _,m in pairs(maps)do if m.z==z then list[#list+1]=m end end;table.sort(list,function(a,b)return a.label<b.label end)
  if z~=""then o.maps[#o.maps+1]={head=z}end;for _,m in ipairs(list)do o.maps[#o.maps+1]=m end end
 o.kinds={};for _,k in ipairs({{"full","Full"},{"partial","Partial"}})do local p=function(r)return kind(r)==k[1]end;if any(p)then o.kinds[#o.kinds+1]={v=k[1],label=k[2],n=count("kinds",p)}end end
 last={rows=rows,key=key,o=o}
 return o
end
return M
