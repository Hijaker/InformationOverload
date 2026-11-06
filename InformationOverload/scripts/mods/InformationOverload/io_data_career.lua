-- Information Overload: shared drawing and figures for Classes, Streaks, Deaths and Speedrunning.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local Records=mod:io_dofile(base.."records")
local H=mod:io_dofile(base.."history_presentation")
local Times=mod:io_dofile(base.."mission_times")
local Grouping=mod:io_dofile(base.."enemy_grouping")
local Enemies=mod:io_dofile(base.."enemy_catalog")
local Hyper=mod:io_dofile(base.."hyper_critical")
local C,DASH,commas=D.c,Overview.dash,Overview.commas
local K={dash=DASH}
local okM,Missions=pcall(require,"scripts/settings/mission/mission_templates")
local okZ,Zones=pcall(require,"scripts/settings/zones/zones")
local function num(n)return (string.format("%.1f",n):gsub("%.0$",""))end
function K.share(n,total)if type(n)~="number"or type(total)~="number"or total<=0 then return nil end;return num(100*n/total).."%"end
local function pct(w,g)if not g or g<=0 then return DASH end;return num(100*w/g).."%"end
local function count(n)return type(n)=="number"and n>0 and tostring(n)or DASH end
function K.weapon(id)local f=mod.io_weapon_name;if type(f)=="function"then local ok,name=pcall(f,id);if ok and type(name)=="string"then return name end end;return id and tostring(id)or DASH end
function K.open_run(view,id)return function()view.io_params=view.io_params or {};view.io_params.run=id;view.io_tab="overview";view:_go("run")end end
function K.parts(label)local out={};for p in tostring(label):gmatch("[^/]+")do out[#out+1]=p:gsub("^%s+",""):gsub("%s+$","")end;return out end
-- drawing
function K.fit(view,text,size,maxw)
 text=tostring(text);if view:_w(text,size)<=maxw then return text end
 local n=#text;while n>1 and view:_w(text:sub(1,n).."...",size)>maxw do n=n-1 end;while n>0 and (text:byte(n+1)or 0)>=128 and (text:byte(n+1)or 0)<192 do n=n-1 end;return text:sub(1,n):gsub("%s+$","").."..."
end
-- parts drawn with a chevron between them, the way the crumbs are
function K.label(view,cv,parts,x,y,h,size,c,font)
 if type(parts)~="table"then parts={parts}end
 for i,p in ipairs(parts)do local w=view:_w(p,size,font);cv:text(p,x,y,w+6,h,size,c,"left",font);x=x+w
  if i<#parts then x=x+6;cv:chevron(x,y+h/2-4,"right",8,C.muted);x=x+12 end
 end
 return x
end
function K.empty(view,cv,title)view:_card(cv,D.left,D.row2,D.width,92,title or "No Missions Recorded Yet")end
function K.dropdown(view,base,popup,id,x,y,w,label,value,current,options,pick)
 local open=view.dd==id
 view:_ctl(base,"base",x,y,w,34,function()view.dd=not open and id or nil end,{open=open})
 local lw=view:_w(label,16);base:text(label,x+12,y,lw+4,34,16,C.label);base:pick(value,K.fit(view,value,16,w-lw-56),x+20+lw,y,w-lw-56)
 base:chevron(x+w-24,y+13,"down",10,C.value)
 if not open or #options==0 then return end
 local pw,py=math.max(w,260),y+38;local per=math.max(1,math.floor((D.bottom-py)/30));local cols=math.ceil(#options/per)
 for c=1,cols do local cx=x-(c-1)*pw;local h=math.min(per,#options-(c-1)*per)*30+2;view:_panel(popup,cx,py,pw,h)end
 for i,o in ipairs(options)do local cx=x-math.floor((i-1)/per)*pw;local oy=py+1+((i-1)%per)*30
  if (i-1)%per>0 then popup:rect(cx+1,oy,pw-2,1,C.line)end
  if o.h then popup:text(K.fit(view,o.h,14,pw-24),cx+12,oy,pw-24,30,14,C.gold)
  else local on=o.value==current;local lx=cx+12+18*(o.ind or 0)
   if on then popup:rect(cx+1,oy,pw-2,30,C.on);popup:rect(cx+1,oy,3,30,C.sel)end
   popup:text(K.fit(view,o.label,16,cx+pw-(o.n and 140 or 12)-lx),lx,oy,cx+pw-lx-12,30,16,on and C.gold_hi or C.value)
   if o.n then popup:text(o.n,cx+pw-132,oy,120,30,14,C.muted,"right")end
   view:_hit("popup",cx+1,oy,pw-2,30,function()view.dd=nil;pick(o.value)end,{bg=C.fill_h})
  end
 end
end
function K.tabs(view,cv,list,current,set)
 local tx=100;for _,t in ipairs(list)do local w=view:_w(t[2],16)+30;local sel=current==t[1]
  view:_ctl(cv,"base",tx,D.row2,w,34,function()set(t[1])end,{sel=sel});cv:text(t[2],tx,D.row2,w,34,16,sel and C.gold_hi or C.value,"center");tx=tx+w+8 end
end
function K.seg(view,cv,x,y,label,list,current,set)
 local lw=view:_w(label,16);cv:text(label,x,y,lw+4,34,16,C.label);x=x+lw+10
 for _,t in ipairs(list)do local w=view:_w(t[2],16)+24;local sel=current==t[1]
  view:_ctl(cv,"base",x,y,w,34,function()set(t[1])end,{sel=sel});cv:text(t[2],x,y,w,34,16,sel and C.gold_hi or C.value,"center");x=x+w+2 end
end
local function value(view,cv,v,edge,y,h,size,dim)
 if type(v)=="table"then
  cv:text(tostring(v.n),edge-350,y,300,h,size,C.value,"right")
  if v.p then cv:text(v.p,edge-44,y,44,h,14,C.muted)end
 else cv:text(tostring(v),edge-400,y,400,h,size,(dim or v==DASH)and C.muted or C.value,"right")end
end
-- rows: {label|parts, value, fn=, big=, head=}; returns the height used
function K.rows(view,cv,x,y,w,rows)
 local ry=y
 for _,r in ipairs(rows)do local h=r.big and 30 or 26
  if r.fn then view:_jump(cv,x+8,ry+(h-22)/2,r.fn)end
  if r.head then K.label(view,cv,r.head,x+36,ry,h,16,C.value)
  else K.label(view,cv,r[1],x+36,ry,h,16,C.label);if r[2]~=nil then value(view,cv,r[2],x+w-13,ry,h,r.big and 20 or 16)end end
  ry=ry+h
 end
 return ry-y
end
function K.rows_h(rows)local h=0;for _,r in ipairs(rows)do h=h+(r.big and 30 or 26)end;return h end
function K.card(view,cv,x,y,w,title,sub,rows,jump)
 local h=52+K.rows_h(rows);view:_card(cv,x,y,w,h,title,nil,jump)
 if sub then K.label(view,cv,K.parts(sub),x+46+view:_w(title,20),y+13,30,14,C.muted)end
 K.rows(view,cv,x,y+45,w,rows);return h
end
-- cols: {label, right edge} or {label, left x, "left", width}; rows: {grp=label} or {label|parts, cells..., fn=, ind=}
function K.table(view,cv,x,y,w,cols,rows)
 for i,c in ipairs(cols)do
  if i==1 then cv:text(c[1],x+10,y,300,30,14,C.muted)
  elseif c[3]=="left"then cv:text(c[1],c[2],y,c[4],30,14,C.muted)
  else cv:text(c[1],c[2]-300,y,300,30,14,C.muted,"right")end
 end
 cv:rect(x,y+29,w,1,C.frame,true);y=y+30
 for _,r in ipairs(rows)do
  if r.grp then K.label(view,cv,r.grp,x+10,y,28,14,C.gold);cv:rect(x,y+27,w,1,C.line,true);y=y+28
  else
   if r.fn then view:_hit("base",x,y,w,32,r.fn,{bg=C.row_h})end
   K.label(view,cv,r[1],x+10+(r.ind and 18 or 0),y,32,16,r.ind and C.muted or C.label)
   for i=2,#cols do local c=cols[i];local v=r[i]
    if c[3]=="left"then cv:text(K.fit(view,v or "",16,c[4]),c[2],y,c[4],32,16,C.value)else value(view,cv,v==nil and DASH or v,c[2],y,32,16,c[3]=="dim")end
   end
   cv:rect(x,y+31,w,1,C.line,true);y=y+32
  end
 end
 return y
end
-- streaks: the same records the old Streaks screen read
local MODE={{"win","Wins In A Row"},{"loss","Losses In A Row"},{"undowned","Wins Without A Down"},{"death_free","Wins Without A Death"},{"unpounced","Wins Without A Pounce"},
 {"unnetted","Wins Without A Net"},{"uncharged","Wins Without A Mutant Catch"},{"kill_run","Kills Without A Down"}}
local TEAM={{"psyker_no_detonations","Games With No Psyker Detonations"},{"psyker_detonations","Games With Psyker Detonations"},{"field_improv_games","Games With No Field Improvisation Veterans"},{"field_improv_vets","Veterans Without Field Improvisation In A Row"}}
local COMBAT={{"head_combined","Headshots In A Row (Combined)"},{"head_melee","Melee Headshots In A Row"},{"head_ranged","Ranged Headshots In A Row"},{"kills","Kills In A Row"},{"dodges","Melee Dodges In A Row"}}
function K.streaks(tracker,patch,mode,class)
 patch=patch or "Unknown patch"
 local record=class and tracker:class_mode_streak(patch,mode,class)or tracker:mode_streak(patch,mode);local cur,best=record.current or {},record.best or {}
 local mine,team={},{}
 local function add(list,label,c,b)if (tonumber(c)or 0)>0 or (tonumber(b)or 0)>0 then list[#list+1]={label,count(c),count(b)}end end
 for _,p in ipairs(MODE)do add(mine,p[2],cur[p[1]],best[p[1]])end
 if mode=="non-havoc"then local m=tracker:maelstrom_streak(patch,class);add(mine,"Maelstrom Wins In A Row",m.current.win,m.best.win);add(mine,"Maelstrom Losses In A Row",m.current.loss,m.best.loss)end
 if class=="psyker"then add(mine,"Games Without A Peril Detonation",cur.personal_peril_safe,best.personal_peril_safe)end
 for _,p in ipairs(TEAM)do add(team,p[2],cur[p[1]],best[p[1]])end
 local top=Nav.summary(tracker,{patch=patch,mode=mode,class=class}).best
 local active=tracker.mission and tracker.mission.context and tracker.mission.context.mode==mode and (not class or tracker.mission.context.class==class)
 for _,p in ipairs(COMBAT)do mine[#mine+1]={p[2],active and count(tracker.current[p[1]])or DASH,count(top[p[1]])}end
 return mine,team
end
function K.streak_table(view,cv,y,mine,team)
 local rows={};for _,r in ipairs(mine)do rows[#rows+1]=r end
 if #team>0 then rows[#rows+1]={grp="About Your Teammates"};for _,r in ipairs(team)do rows[#rows+1]=r end end
 return K.table(view,cv,D.left,y,D.width,{{"Streak"},{"Current",1122},{"Best",D.right-10}},rows)
end
-- classes
function K.played(tracker,patch,mode)
 local list={};for _,class in ipairs(Nav.classes)do local row=Nav.class_missions(tracker,patch,mode,class);if row.games>0 then list[#list+1]={id=class,name=Overview.class_names[class]or class,games=row.games,wins=row.wins}end end
 return list
end
local function streak_pair(c,b)return ((tonumber(c)or 0)>0 and tostring(c)or DASH).." Now, Best "..((tonumber(b)or 0)>0 and tostring(b)or DASH)end
function K.class_overview(tracker,scope,class)
 local patch,mode=scope.patch,scope.mode;local key=patch or "Unknown patch";local m={}
 local gm=Nav.class_missions(tracker,patch,mode,class)
 m.results={{"Games",tostring(gm.games)},{"Wins",tostring(gm.wins)},{"Win Rate",pct(gm.wins,gm.games)}}
 local function pair(label,c,b)if (tonumber(c)or 0)>0 or (tonumber(b)or 0)>0 then m.results[#m.results+1]={label,streak_pair(c,b)}end end
 local win=tracker:class_win_streak(key,mode,class);local general=tracker:class_mode_streak(key,mode,class)
 pair("Win Streak",win.current,win.best);pair("Loss Streak",general.current.loss,general.best.loss)
 if mode=="non-havoc"then local ms=tracker:maelstrom_streak(key,class);pair("Maelstrom Win Streak",ms.current.win,ms.best.win);pair("Maelstrom Loss Streak",ms.current.loss,ms.best.loss)end
 local high={kills=0,damage=0,categories={}};local src={}
 for _,each in ipairs(Nav.modes())do local stats=Nav.class_missions(tracker,patch,each,class);local runs=Nav.mission_sources(tracker,patch,each,stats,class)
  for _,k in ipairs({"kills","damage"})do if stats[k]>high[k]then high[k]=stats[k];src[k]=runs[k]end end
  for id,n in pairs(stats.categories or {})do if n>(high.categories[id]or 0)then high.categories[id]=n;src[id]=runs[id]end end
 end
 m.bests={}
 if high.kills>0 then m.bests[#m.bests+1]={"Most Kills In A Mission",commas(high.kills),run=src.kills}end
 if high.damage>0 then local share=src.damage and Nav.damage_share(tracker,src.damage)
  m.bests[#m.bests+1]={"Most Damage In A Mission",commas(high.damage)..(share and " ("..num(share).."% Of Team Damage)"or ""),run=src.damage}end
 m.kills={};for _,p in ipairs({{"horde_melee","Melee Horde"},{"horde_ranged","Ranged Horde"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"}})do local n=high.categories[p[1]]or 0
  if n>0 then m.kills[#m.kills+1]={p[2],commas(n),run=src[p[1]]}end end
 m.other={};local total,dh,hex=0,0,0
 for id,e in pairs(tracker:class_bosses(key,mode,class))do if id~="hexbound_ritual"then total=total+(e.count or 0);if id=="hexbound_daemonhost"then hex=hex+(e.count or 0)elseif id:find("daemonhost",1,true)then dh=dh+(e.count or 0)end end end
 if total>0 then m.other[#m.other+1]={"Total Bosses Killed",tostring(total)}end
 if dh>0 then m.other[#m.other+1]={"Daemonhosts Killed",tostring(dh)}end
 if mode=="havoc"and hex>0 then m.other[#m.other+1]={"Hexbound Daemonhosts Killed",tostring(hex)}end
 if (gm.clutch_wins or 0)>0 then m.other[#m.other+1]={"Missions Won With A Clutch",tostring(gm.clutch_wins)};m.other[#m.other+1]={"Most Clutches In One Win",tostring(gm.clutch_episodes or 0)}
  for _,p in ipairs({{"full","Full Clutch","Full Clutches"},{"semi","Semi-Clutch","Semi-Clutches"}})do local n=gm[p[1].."_clutch_wins"]or 0
   if n>0 then m.other[#m.other+1]={"Missions Won With A "..p[2],tostring(n)};m.other[#m.other+1]={"Most "..p[3].." In One Win",tostring(gm[p[1].."_clutch_episodes"]or 0)}end end
 end
 if (gm.failed_clutches_game or 0)>0 then m.other[#m.other+1]={"Most Failed Clutches In One Loss",tostring(gm.failed_clutches_game)}end
 m.hyper={};if class=="broker"then local s=Hyper.summary(tracker,patch)
  if s and (s.highest or 0)>0 then m.hyper={{"Most Hyper-Critical Kills In A Mission",tostring(s.highest)},{"Average Hyper-Critical Kills Per Mission",num(s.average or 0)}}end end
 m.perils={};if class=="psyker"then
  local context=tracker.mission and tracker.mission.context
  if not context or context.class~="psyker"or patch and context.patch~=patch then context=nil
   local history=tracker.data.run_history or {};for i=#history,1,-1 do local run=history[i];local c=run.context
    if c and c.class=="psyker"and (not patch or c.patch==patch)and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium"then context=c;break end end
  end
  local best=Nav.summary(tracker,{patch=patch,class=class}).best.psyker_safe_missions or 0;local now=context and tracker:mission_row(context).psyker_safe_current or 0
  if best>0 or now>0 then m.perils={{"Missions Without A Peril Detonation (Best)",tostring(best)},{"Missions Without A Peril Detonation (Current)",tostring(now)}}end
 end
 local runs={};for _,run in ipairs(Overview.runs(tracker))do local c=run.context
  if c.mode==mode and c.class==class and (not patch or c.patch==patch)then runs[#runs+1]=run end end
 m.bars={};for i=math.min(40,#runs),1,-1 do local run=runs[i]
  local mo,d=tostring(run.started_at or ""):match("^%d+%-(%d+)%-(%d+)");m.bars[#m.bars+1]={id=run.id,win=run.victory==true,damage=(Records.run_mission_damage(run)),date=d and d.."/"..mo or ""}end
 return m
end
-- damage records for one class: Overall, By Armour, By Enemy, By Weapon
local KINDS={{"single_hit","Biggest Single-Target Hit"},{"melee_cleave","Biggest Melee Cleave"},{"explosive_hit","Biggest Explosion"}}
K.kinds=KINDS
K.armour_names={unarmored="Unarmoured",armored="Flak",berserker="Maniac",super_armor="Carapace",resistant="Unyielding",disgustingly_resilient="Infested",unknown="Unknown"}
function K.class_damage(tracker,scope,class)
 local m={overall={},armour={},enemy={},weapon={}};local weapons,armour,enemies={}, {}, {}
 for _,row in pairs(tracker.data.rows or {})do local c=row.context or {}
  if not row.aggregate and c.class==class and c.mode==scope.mode and (not scope.patch or c.patch==scope.patch)then
   for _,k in ipairs(KINDS)do local id=k[1];local n=row.best and row.best[id]
    if n and n>0 and not (id=="single_hit"and tracker:is_class_grenade(c))then
     local src=row.best_weapons and row.best_weapons[id]or c;local old=m.overall[id]
     if not old or n>old.value then m.overall[id]={value=n,class=src.class or class,weapon=src.weapon,enemy=src.enemy,run=row.best_runs and row.best_runs[id]}end
     if c.weapon then local w=weapons[c.weapon]or {id=c.weapon,cat=c.category,rec={}};weapons[c.weapon]=w;if not w.rec[id]or n>w.rec[id].value then w.rec[id]={value=n,run=row.best_runs and row.best_runs[id]}end end
    end
   end
   for a,bucket in pairs(row.armour_best or {})do for _,k in ipairs(KINDS)do local n=bucket.best and bucket.best[k[1]]
    if n and n>0 then armour[a]=armour[a]or {};if not armour[a][k[1]]or n>armour[a][k[1]].value then armour[a][k[1]]={value=n}end end end end
   for enemy,hit in pairs(row.enemy_hits or {})do if type(hit)=="table"and (hit.damage or 0)>0 and (not enemies[enemy]or hit.damage>enemies[enemy].damage)then enemies[enemy]=hit end end
  end
 end
 for _,a in ipairs(Nav.armours)do if armour[a]then m.armour[#m.armour+1]={label=K.armour_names[a]or a,rec=armour[a]}end end
 local groups={};for _,e in pairs(Enemies.catalog())do groups[e.label]=e.group end
 local order={normal=1,elite=2,special=3,boss=4};local names={normal="Trash Enemies",elite="Elites",special="Specials",boss="Bosses"}
 for enemy,hit in pairs(enemies)do local g=groups[enemy];m.enemy[#m.enemy+1]={label=tostring(enemy),group=names[g]or "Other",order=order[g]or 9,hit=hit}end
 table.sort(m.enemy,function(a,b)if a.order~=b.order then return a.order<b.order end;return a.label<b.label end)
 for _,w in pairs(weapons)do w.label=K.weapon(w.id);m.weapon[#m.weapon+1]=w end
 table.sort(m.weapon,function(a,b)if a.cat~=b.cat then return tostring(a.cat)<tostring(b.cat)end;return a.label<b.label end)
 return m
end
-- deaths: his grouping of what downed or killed the player
local SUB={ranged="Ranged",bruiser="Bruiser",horde="Horde",melee="Melee",monstrosity="Monstrosities",captain="Captains",daemonhost="Daemonhosts"}
local function title(s)return (tostring(s):gsub("(%f[%w])(%l)",function(_,c)return c:upper()end))end
local function group_label(id)for _,g in ipairs(Grouping.groups)do if g.id==id then return g.label end end;return title(Grouping.label(id))end
function K.deaths(tracker,scope)
 local data=Grouping.build(tracker,scope.patch,scope.mode,Enemies);local all=data.all;local m={all=all,games=data.games,groups={},enemies={},opts={}}
 local function pairs3(b)return {downs={n=b.downs,p=K.share(b.downs,all.downs)},deaths={n=b.deaths,p=K.share(b.deaths,all.deaths)},total={n=b.total,p=K.share(b.total,all.total)}}end
 local best=Grouping.best(data)
 if best then m.lethal={parts=K.parts(title(best.label)),downs=best.downs,deaths=best.deaths,total=best.total}end
 local order={normal=1,elite=2,special=3,boss=4,environment=5,unknown=6}
 for id,g in pairs(data.groups)do local subs=Grouping.subgroups[id]
  if subs and id~="boss"then for _,s in ipairs(subs)do local b=g.subgroups[s.id];if b and b.total>0 then m.groups[#m.groups+1]={parts={group_label(id),s.label},v=pairs3(b),total=b.total}end end
  elseif g.total>0 then local row={parts={group_label(id)},v=pairs3(g),total=g.total,subs={}}
   for _,s in ipairs(subs or {})do local b=g.subgroups[s.id];if b and b.total>0 then row.subs[#row.subs+1]={parts={s.label},v=pairs3(b)}end end
   m.groups[#m.groups+1]=row
  end
  for sub,b in pairs(g.subgroups or {})do for eid,e in pairs(b.enemies or {})do if e.total>0 then
   m.enemies[#m.enemies+1]={key=id.."|"..tostring(sub).."|"..tostring(eid),label=tostring(e.label or eid):lower()=="unknown cause"and "Unknown Cause"or e.label or tostring(eid),group=id,sub=sub,go=order[id]or 9,parts={group_label(id),subs and SUB[sub]or nil},v=pairs3(e),e=e}
  end end end
 end
 table.sort(m.groups,function(a,b)if a.total~=b.total then return a.total>b.total end;return table.concat(a.parts)<table.concat(b.parts)end)
 local suborder={};for gid,subs in pairs(Grouping.subgroups)do for i,s in ipairs(subs)do suborder[gid.."|"..s.id]=i end end
 table.sort(m.enemies,function(a,b)if a.go~=b.go then return a.go<b.go end;local x,y=suborder[a.group.."|"..tostring(a.sub)]or 9,suborder[b.group.."|"..tostring(b.sub)]or 9
  if x~=y then return x<y end;if a.e.total~=b.e.total then return a.e.total>b.e.total end;return a.label<b.label end)
 m.opts={{value="all",label="All Enemies"}};local seen,subs={},{}
 for _,e in ipairs(m.enemies)do subs[e.group]=subs[e.group]or {n=0};if not subs[e.group][e.sub]then subs[e.group][e.sub]=true;subs[e.group].n=subs[e.group].n+1 end end
 local plain={ranged=true,bruiser=true,horde=true,melee=true}
 for _,e in ipairs(m.enemies)do
  if not seen[e.group]then seen[e.group]=true;m.opts[#m.opts+1]={value="g:"..e.group,label=group_label(e.group)}end
  local split=Grouping.subgroups[e.group]and SUB[e.sub]and (subs[e.group].n>1 or plain[e.sub])
  if split and not seen[e.group.."|"..e.sub]then seen[e.group.."|"..e.sub]=true;m.opts[#m.opts+1]={value="s:"..e.group.."|"..e.sub,label=SUB[e.sub],ind=1,parts={group_label(e.group),SUB[e.sub]}}end
  m.opts[#m.opts+1]={value="e:"..e.key,label=e.label,ind=split and 2 or 1}
 end
 return m
end
-- speedrunning: his fastest clears, grouped by zone
local function zone(c)
 local mission=okM and type(Missions)=="table"and Missions[c.mission_name];local id=mission and mission.zone_id or "unknown"
 local z=okZ and type(Zones)=="table"and Zones[id];local key=z and z.name
 local label=key and type(Localize)=="function"and Localize(key)or "Unknown Area";if label==key or tostring(label):find("<unlocalized",1,true)then label="Unknown Area"end
 local short=label:match('"([^"}]+)"')or label:match('“([^”]+)”');if short then label='"'..short..'"'end
 return id,label
end
function K.speed(tracker,scope)
 local opts=mod.io_display_options and mod.io_display_options()or {};local basis=opts.boss_map_timing and "boss"or "victory"
 local history={};for _,run in ipairs(tracker.data.run_history or {})do local c=run.context;if c and (scope.diff=="all"or Overview.diff_label(c)==scope.diff)and (scope.all_patches or not scope.patch or c.patch==scope.patch)then history[#history+1]=run end end
 local built=Times.build(history,scope.mode,basis);local maps={}
 if scope.mode=="havoc"and scope.diff=="all"then local key;for k in pairs(built)do if not key or (tonumber(k)or 0)>(tonumber(key)or 0)then key=k end end;maps=key and built[key]or {}
 else for _,list in pairs(built)do for map,run in pairs(list)do if not maps[map]or Times.faster(run,maps[map])then maps[map]=run end end end end
 local zones,list={},{}
 for key,run in pairs(maps)do local id,label=zone(run.context);local z=zones[id];if not z then z={label=label,maps={}};zones[id]=z;list[#list+1]=z end
  z.maps[#z.maps+1]={key=key,run=run,name=tracker:run_mission_name(run.context),time=Times.format(run.completion_time.seconds)}end
 table.sort(list,function(a,b)return a.label<b.label end);for _,z in ipairs(list)do table.sort(z.maps,function(a,b)return a.name<b.name end)end
 return list
end
function K.speed_rows(run)
 local c=run.context;local rows={{"Fastest Clear",Times.format(run.completion_time.seconds),big=true},{"Date",run.started_at and H.timestamp(run.started_at)or DASH}}
 local mods={};for _,name in pairs(c.modifiers or {})do if type(name)=="string"and name~=""and not name:find("Fading",1,true)then mods[#mods+1]=name end end;table.sort(mods)
 if #mods>0 then rows[#rows+1]={"Modifiers",table.concat(mods,", ")}end
 if run.average_time then rows[#rows+1]={"Average Time",Times.format(run.average_time)}end
 return rows
end
return K
