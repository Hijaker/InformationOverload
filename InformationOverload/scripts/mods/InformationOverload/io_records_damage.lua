-- Information Overload: the biggest hits, as the Records page's Damage tab draws them and the Classes page's Damage tab for one class.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_stats")
local E=mod:io_dofile(base.."enemy_catalog")
local Overview=mod:io_dofile(base.."io_overview")
local C,DASH,CN=D.c,K.dash,K.class_names
local M={}
local KINDS={{"single_hit","Biggest Single-Target Hit"},{"melee_cleave","Biggest Melee Cleave"},{"explosive_hit","Biggest Explosion"}}
local DETAILS={{"overall","Overall"},{"armour","By Armour"},{"enemy","By Enemy"},{"weapon","By Weapon"}}
local GROUPS={{"normal","Trash Enemies"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"},{"other","Other"}}
local X,W=D.left,D.width
local function weapon(id)local ok,name=pcall(mod.io_weapon_name or tostring,id);return ok and type(name)=="string"and name~="Unknown weapon"and name or nil end
local function rows_of(tracker,s,class)
 local out={};for _,row in pairs(tracker.data.rows or {})do local c=row.context
  if c.mode==s.mode and (not s.patch or c.patch==s.patch)and (not class or c.class==class)then out[#out+1]=row end end
 return out
end
local function best(tracker,rows,key,armour,pick)
 local v,src,run,named,metric
 local metrics=key=="explosive_hit"and {key,"explosive_single_hit"}or {key}
 -- a tie goes to the row that names its weapon over one from a match that never saved it
 for _,row in ipairs(rows)do if not row.aggregate and (key~="single_hit"or not tracker:is_class_grenade(row.context))and (not pick or pick(row))then
  local bucket=armour and row.armour_best and row.armour_best[armour]
  for _,stat in ipairs(metrics)do
   local n=armour and bucket and bucket.best and bucket.best[stat]or not armour and row.best[stat]
   if n and (n>(v or 0)or n==v and row.context.weapon and not named)then v=n;named=row.context.weapon;src=armour and bucket.sources and bucket.sources[stat]or row.best_weapons and row.best_weapons[stat]or row.context;run=not armour and row.best_runs and row.best_runs[stat]or nil;metric=stat end
  end
 end end
 if v then return {v=v,src=src or {},run=run,metric=metric}end
end

-- Overall: a tile for each record with what set it, the mission it was set in, which opens it, and its best against each armour type; the three
-- tiles share their heights so each part lines up across them
local TW,LH,MH,AH=390,26,100,24
local function run_of(tracker,id)if id==nil then return end;for _,r in ipairs(tracker.data.run_history or {})do if r.id==id then return r end end end
-- a value over at most two lines, the second cut to fit, with whether it was cut
local function wrap(view,s,size,w)
 if view:_w(s,size)<=w then return {s}end
 local line,n,words="",0,{};for word in s:gmatch("%S+")do words[#words+1]=word end
 for i,word in ipairs(words)do local try=line==""and word or line.." "..word;if line~=""and view:_w(try,size)>w then break end;line,n=try,i end
 -- a first word wider than the line, as in a language written without spaces, breaks where it fits
 if view:_w(line,size)>w then local cut="";for ch in line:gmatch("[%z\1-\127\194-\244][\128-\191]*")do if view:_w(cut..ch,size)>w then break end;cut=cut..ch end
  if cut~=""then table.insert(words,n+1,line:sub(#cut+1));line=cut end end
 local rest=table.concat(words," ",n+1);local first=view:_fit(line,size,w)
 if rest==""then return {first},first~=line end
 local second=view:_fit(rest,size,w);return {first,second},first~=line or second~=rest
end
local function what_of(view,b)
 local out={};if not b then return out end
 local src=b.src;for _,r in ipairs({{"Class",CN[src.class]or DASH},{"Weapon",weapon(src.weapon)},{"Enemy",src.enemy and tostring(src.enemy)~=""and tostring(src.enemy)or nil}})do
  if r[2]then local lines,cut=wrap(view,r[2],18,TW-142);out[#out+1]={r[1],lines,cut and r[2]or nil}end end
 if b.metric=="explosive_single_hit"then out[#out+1]={"Basis",{"Single target"}}end
 return out
end
local function what_h(what)local h=0;for _,r in ipairs(what)do h=h+LH+(#r[2]-1)*22 end;return h end
-- every armour type any record has a figure for, in one order for all three tiles
local function armour_rows(tracker,rows)
 local list={}
 for _,a in ipairs(K.ARM)do local r={a[2]};local any=false
  for i,k in ipairs(KINDS)do local b=best(tracker,rows,k[1],a[1]);if b then any=true;r[i+1]=b.v end end
  if any then list[#list+1]=r end end
 return list
end
-- a record set in the mission being played has no mission saved until that mission ends; a mission rejoined after a restart
-- carries its records as keys only
local function this_mission(tracker,k,b)local m=tracker.mission;if not m then return end
 for _,list in ipairs({m.record_updates or {},m.record_update_keys or {}})do for _,u in ipairs(list)do if u.name==k[1]and u.value==b.v then return true end end end end
local function tile(view,cv,tracker,k,b,what,wh,arm,i,x,y,th)
 view:_card(cv,x,y,TW,th,b and b.metric=="explosive_single_hit"and "Biggest Explosion Hit"or k[2])
 cv:text(b and K.exact(b.v)or DASH,x+36,y+44,TW-54,56,50,b and C.value or C.muted)
 local ry=y+108
 for _,r in ipairs(what)do local h=LH+(#r[2]-1)*22
  cv:text(r[1],x+36,ry,88,LH,16,C.label);for j,l in ipairs(r[2])do cv:text(l,x+124,ry+(j-1)*22,TW-142,LH,18,C.value)end
  if r[3]then view:_tip("base",x+124,ry,TW-142,h,{r[1],r[3]})end
  ry=ry+h
 end
 -- the mission the record was set in
 local my=y+108+wh+14;cv:rect(x+1,my,TW-2,1,C.frame)
 local now=b and this_mission(tracker,{b.metric or k[1]},b);local run=b and not now and run_of(tracker,b.run)
 if run then local c=run.context or {}
  for j,r in ipairs({{"Map",tracker:run_mission_name(c)},{"Difficulty",Overview.diff_label(c)},{"Date",K.date(run)}})do local yy=my+10+(j-1)*LH
   cv:text(r[1],x+36,yy,88,LH,16,C.label);cv:text(view:_fit(r[2],16,TW-176),x+124,yy,TW-176,LH,16,C.value)end
  local jx,jy=x+TW-40,my+38;cv.z=4;cv:rect(jx,jy,22,22,C.fill);cv.z=5;cv:edges(jx,jy,22,22,1,C.frame);cv:chevron(jx+9,jy+6,"right",8,C.value)
  view:_hit("base",x+1,my+1,TW-2,#arm>0 and MH-1 or MH-2,K.open_run(view,run.id),{bg=C.fill_h,edge=C.hover})
 elseif b then cv:text(now and "Set in this mission"or b.run==nil and "Mission not recorded"or "No longer in Match History",x+36,my+10,TW-54,LH,16,C.muted)end
 -- its best against each armour type, a bar against this record, gold where the whole record landed on that armour; a figure past the record,
 -- left by a Counting switch that cleared the record, gets no bar
 if #arm==0 then return end
 local ay,top=my+MH,b and b.v;cv:rect(x+1,ay,TW-2,1,C.frame)
 cv:text("By Armour",x+36,ay+8,TW-54,LH,16,C.gold)
 for j,r in ipairs(arm)do local yy,v=ay+38+(j-1)*AH,r[i+1];local whole=v and top and v==top
  cv:text(r[1],x+36,yy,104,AH,16,C.label)
  if v then cv:text(K.exact(v),x+154,yy,70,AH,16,whole and C.gold or C.value,"right")
   if top and top>0 and v<=top then cv:rect(x+238,yy+9,130,6,C.fill);cv:rect(x+238,yy+9,math.max(2,130*v/top),6,whole and C.gold or C.corner)end
  else cv:text(DASH,x+154,yy,70,AH,16,C.muted,"right")end
 end
end
local function damage_cards(view,cv,tracker,rows,det,class,y)
 if det=="overall"then
  local recs,any={},false;for i,k in ipairs(KINDS)do recs[i]=best(tracker,rows,k[1]);any=any or recs[i]~=nil end
  if not any then return K.empty(view,cv,y,"No Damage Records Yet")end
  local arm={};for _,row in ipairs(rows)do if row.armour_best and next(row.armour_best)then arm=armour_rows(tracker,rows);break end end
  local whats,wh={},0;for i=1,#KINDS do whats[i]=what_of(view,recs[i]);wh=math.max(wh,what_h(whats[i]))end
  local th=108+wh+14+MH+(#arm>0 and 38+#arm*AH+12 or 0)
  for i,k in ipairs(KINDS)do tile(view,cv,tracker,k,recs[i],whats[i],wh,arm,i,X+(i-1)*(TW+10),y,th)end
  return y+th+10
 end
 local cols={{"Armour",10,"l"},{"Biggest Single-Target Hit",540},{"Biggest Melee Cleave",820},{"Biggest Explosion / Hit",W-10}}
 if det=="armour"then
  local list={};for _,a in ipairs(K.ARM)do local row={a[2]};local any=false
   for i,k in ipairs(KINDS)do local b=best(tracker,rows,k[1],a[1]);if b then any=true;row[i+1]=K.mod(b.v)else row[i+1]={DASH,nil,C.muted}end end
   if any then list[#list+1]=row end end
  if #list==0 then return K.empty(view,cv,y,"No Damage Records Yet")end
  return y+K.table(view,cv,X,y,W,cols,list)+10
 end
 if det=="enemy"then
  local hits={};for _,row in ipairs(rows)do if row.aggregate then for enemy,hit in pairs(row.enemy_hits or {})do local old=hits[enemy];if not old or hit.damage>old.damage then hits[enemy]={damage=hit.damage,weapon=hit.weapon,class=hit.class or row.context.class,run=hit.run_id}end end end end
  local group={};for _,e in pairs(E.catalog())do group[e.label]=e.group end
  local by={};for enemy,hit in pairs(hits)do local g=group[enemy]or "other";by[g]=by[g]or {};table.insert(by[g],{e=enemy,hit=hit})end
  local list={}
  for _,g in ipairs(GROUPS)do local items=by[g[1]];if items then table.sort(items,function(a,b)return a.e<b.e end);list[#list+1]={grp=g[2]}
   for _,it in ipairs(items)do local h=it.hit;local act=h.run and K.open_run(view,h.run)or nil;local r={it.e,K.exact(h.damage),CN[h.class]or DASH,weapon(h.weapon)or DASH,act=act}
    if act then r.under=function(ry)cv:chevron(X+W-22,ry+12,"right",8,C.value)end end;list[#list+1]=r end end end
  if #list==0 then return K.empty(view,cv,y,"No Damage Records Yet")end
  return y+K.table(view,cv,X,y,W,{{"Enemy",10,"l"},{"Biggest Hit",470},{"Class",490,"l"},{"Weapon",620,"l",max=520}},list)+10
 end
 local cats={{"melee","Melee"},{"ranged","Ranged"}};local list={}
 for _,cat in ipairs(cats)do local leaf={};local seen={}
  for _,row in ipairs(rows)do local c=row.context;if not row.aggregate and c.category==cat[1]and c.weapon and not seen[c.weapon]then seen[c.weapon]=true;leaf[#leaf+1]=c.weapon end end
  if #leaf>0 then
   local named={};for _,id in ipairs(leaf)do named[#named+1]={id=id,name=weapon(id)or id}end;table.sort(named,function(a,b)return a.name<b.name end)
   local function line(label,pick)local r={label};local any=false;for i,k in ipairs(KINDS)do local b=best(tracker,rows,k[1],nil,pick);if b then any=true end;r[i+1]=b and K.exact(b.v)or {DASH,nil,C.muted}end;return any and r end
   local all=line("All "..cat[1].." weapons",function(row)return row.context.category==cat[1]end)
   if all then list[#list+1]={grp=cat[2]};list[#list+1]=all
    for _,w in ipairs(named)do local r=line(w.name,function(row)return row.context.category==cat[1]and row.context.weapon==w.id end);if r then list[#list+1]=r end end end
  end
 end
 if #list==0 then return K.empty(view,cv,y,"No Damage Records Yet")end
 cols[1]={"Weapon",10,"l",max=480}
 return y+K.table(view,cv,X,y,W,cols,list)+10
end
-- the details there are figures for: Overall always, By Armour and By Enemy where a row holds them, By Weapon for one class
local function details(rows,cls)
 local dets={};for _,d in ipairs(DETAILS)do local keep=d[1]=="overall"
  if d[1]=="armour"then for _,row in ipairs(rows)do if row.armour_best and next(row.armour_best)then keep=true end end
  elseif d[1]=="enemy"then for _,row in ipairs(rows)do if row.aggregate and row.enemy_hits and next(row.enemy_hits)then keep=true end end
  elseif d[1]=="weapon"then if cls then for _,row in ipairs(rows)do if not row.aggregate then keep=true end end end end
  if keep then dets[#dets+1]=d end end
 return dets
end
M.KINDS,M.rows_of,M.details,M.cards=KINDS,rows_of,details,damage_cards
return M
