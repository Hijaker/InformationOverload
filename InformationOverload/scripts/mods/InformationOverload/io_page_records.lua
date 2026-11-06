-- Information Overload: Records, the biggest hits and the most in one mission.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_stats")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local E=mod:io_dofile(base.."enemy_catalog")
local C,DASH,CN=D.c,K.dash,K.class_names
local KINDS={{"single_hit","Biggest Single-Target Hit"},{"melee_cleave","Biggest Melee Cleave"},{"explosive_hit","Biggest Explosion"}}
local DETAILS={{"overall","Overall"},{"armour","By Armour"},{"enemy","By Enemy"},{"weapon","By Weapon"}}
local GROUPS={{"normal","Trash Enemies"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"},{"other","Other"}}
local ND={{"downs","Downs"},{"pounces","Pox Hound Pounces"},{"nets","Trapper Nets"},{"mutant_charges","Mutant Catches"},{"deaths","Deaths"},{"pickups","Pickups"},{"friendly_fire","Friendly Fire Damage"}}
local RES={{"all","All Missions"},{"win","Wins"},{"loss","Losses"}}
local X,W=D.left,D.width
local function weapon(id)local ok,name=pcall(mod.io_weapon_name or tostring,id);return ok and type(name)=="string"and name~="Unknown weapon"and name or nil end
local function rows_of(tracker,s,class)
 local out={};for _,row in pairs(tracker.data.rows or {})do local c=row.context
  if c.mode==s.mode and (not s.patch or c.patch==s.patch)and (not class or c.class==class)then out[#out+1]=row end end
 return out
end
local function best(tracker,rows,key,armour,pick)
 local v,src,run
 for _,row in ipairs(rows)do if not row.aggregate and (key~="single_hit"or not tracker:is_class_grenade(row.context))and (not pick or pick(row))then
  local bucket=armour and row.armour_best and row.armour_best[armour];local n=armour and bucket and bucket.best[key]or not armour and row.best[key]
  if n and n>(v or 0)then v=n;src=armour and bucket.sources and bucket.sources[key]or row.best_weapons and row.best_weapons[key]or row.context;run=not armour and row.best_runs and row.best_runs[key]or nil end
 end end
 if v then return {v=v,src=src or {},run=run}end
end
local function damage_cards(view,cv,tracker,rows,det,class,y)
 if det=="overall"then
  local any=false
  for _,k in ipairs(KINDS)do local b=best(tracker,rows,k[1])
   if b then any=true;local src=b.src;local list={{"Class",CN[src.class]or DASH},{"Weapon",weapon(src.weapon)},{"Enemy",src.enemy and tostring(src.enemy)}}
    local shown={};for _,r in ipairs(list)do if r[2]then shown[#shown+1]=r end end
    local h=45+30+#shown*24+12;view:_card(cv,X,y,W,h,k[2],nil,b.run and K.open_run(view,b.run))
    cv:text("Damage",X+36,y+45,300,30,16,C.label);cv:text(K.exact(b.v),X+W-313,y+45,300,30,20,C.value,"right")
    for i,r in ipairs(shown)do local ry=y+75+(i-1)*24;cv:text(r[1],X+36,ry,300,24,16,C.label);cv:text(r[2],X+W-713,ry,700,24,16,C.value,"right")end
    y=y+h+10
   end
  end
  if not any then y=K.empty(view,cv,y,"No Damage Records Yet")end
  return y
 end
 local cols={{"Armour",10,"l"},{"Biggest Single-Target Hit",540},{"Biggest Melee Cleave",820},{"Biggest Explosion",W-10}}
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
local function nondamage(view,cv,tracker,s,res,y)
 local sum=Nav.incident_outcome_summary(tracker,s.patch,s.mode,res~="all"and res or nil)
 if not sum then return K.empty(view,cv,y,"No Non-Damage Records Yet")end
 local b,src,runs=sum.best,sum.sources,sum.record_runs
 local function cell(id,text)local n=b[id];if not n or n<=0 then return {DASH,nil,C.muted}end;return text or (id:find("friendly_fire",1,true)and K.exact(n)or tostring(n))end
 local function top(own_id,other_id)local own,other=b[own_id]or 0,b[other_id]or 0;local n=math.max(own,other);if n<=0 then return {DASH,nil,C.muted}end
  local me=own>=other;local source=src[me and own_id or other_id]or {};local who=me and " (You)"or source.friend_name and " ("..source.friend_name..")"or ""
  local num=own_id:find("friendly_fire",1,true)and K.exact(n)or tostring(n);return num.." · "..(CN[source.class]or "Unknown Class")..who end
 local list={}
 for _,f in ipairs(ND)do local own=f[1]=="mutant_charges"and "mutant_charges_mission"or "personal_"..f[1].."_mission";local team="team_"..f[1].."_mission"
  if (b[own]or 0)>0 or (b[team]or 0)>0 or (b["teammate_"..f[1].."_mission"]or 0)>0 then list[#list+1]={f[2],cell(own),top(own,"teammate_"..f[1].."_mission"),cell(team),act=runs[own]and K.open_run(view,runs[own])or nil}end end
 for _,p in ipairs({{"total","Total Bosses"},{"real","Real Bosses"}})do local own="personal_boss_"..p[1].."_mission";local team="team_boss_"..p[1].."_mission"
  if (b[team]or 0)>0 then list[#list+1]={p[2],cell(own),top(own,"teammate_boss_"..p[1].."_mission"),cell(team),act=runs[team]and K.open_run(view,runs[team])or nil}end end
 if #list==0 then return K.empty(view,cv,y,"No Non-Damage Records Yet")end
 y=y+K.table(view,cv,X,y,W,{{"Most In One Mission",10,"l"},{"You",470},{"Top Operative",940},{"Team",W-10}},list)+10
 local n=b.team_ritual_stops_mission
 if n and n>0 then local L=D.col;view:_card(cv,X,y,L,76,"Team Records")
  local run=runs.team_ritual_stops_mission;view:_rows(cv,X,y+45,L,{{"Most Rituals Stopped In A Mission",tostring(n),run}},run and K.open_run(view,run))
  y=y+86 end
 return y
end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 view:_scope(cv,popup,m,nil,true)
 local s=view.scope;local tab=view.io_rec_tab=="nd"and "nd"or "damage"
 local reset=function()if view.scroll then view.scroll.records=0 end end
 K.tabs(view,cv,{{"damage","Damage"},{"nd","Non-Damage"}},tab,function(v)view.io_rec_tab=v;reset()end)
 local draw
 do
  if tab=="damage"then
   local played,seen={},{};for _,row in pairs(tracker.data.rows or {})do local c=row.context;if c.mode==s.mode and (not s.patch or c.patch==s.patch)and CN[c.class]and not seen[c.class]then seen[c.class]=true;played[#played+1]=c.class end end
   local order={veteran=1,zealot=2,psyker=3,ogryn=4,adamant=5,broker=6,cryptic=7};table.sort(played,function(a,b)return (order[a]or 9)<(order[b]or 9)end)
   local cls=view.io_rec_class;if cls and not seen[cls]then cls=nil;view.io_rec_class=nil end
   local rows=rows_of(tracker,s,cls)
   local dets={};for _,d in ipairs(DETAILS)do local keep=d[1]=="overall"
    if d[1]=="armour"then for _,row in ipairs(rows)do if row.armour_best and next(row.armour_best)then keep=true end end
    elseif d[1]=="enemy"then for _,row in ipairs(rows)do if row.aggregate and row.enemy_hits and next(row.enemy_hits)then keep=true end end
    elseif d[1]=="weapon"then if cls then for _,row in ipairs(rows)do if not row.aggregate then keep=true end end end end
    if keep then dets[#dets+1]=d end end
   local det=view.io_rec_detail or "overall";local label;for _,d in ipairs(dets)do if d[1]==det then label=d[2]end end;if not label then det="overall";label="Overall"end
   local copts={{value="all",current=cls or "all",label="All Classes"}};for _,c in ipairs(played)do copts[#copts+1]={value=c,current=cls or "all",label=CN[c]}end
   K.dd(view,cv,popup,"rcls",800,D.row2,200,"Class:",cls and CN[cls]or "All",copts,function(v)view.io_rec_class=v~="all"and v or nil end)
   local dopts={};for _,d in ipairs(dets)do dopts[#dopts+1]={value=d[1],current=det,label=d[2]}end
   K.dd(view,cv,popup,"rdet",D.right-280,D.row2,280,"Detail:",label,dopts,function(v)view.io_rec_detail=v;reset()end)
   -- a crumb is a link only where it leads somewhere; at the page's start they all lead back to it
   local top=(cls or det~="overall")and function()view.io_rec_class=nil;view.io_rec_detail=nil end or nil
   view.io_crumbs={{"Records",top},{"Damage",top},{cls and CN[cls]or "All Classes",det~="overall"and function()view.io_rec_detail=nil end or nil},{label}}
   draw=function()damage_cards(view,cv,tracker,rows,det,cls,D.sheet)end
  else
   local res=view.io_rec_result or "all";local label="All Missions";for _,r in ipairs(RES)do if r[1]==res then label=r[2]end end
   local opts={};for _,r in ipairs(RES)do opts[#opts+1]={value=r[1],current=res,label=r[2]}end
   K.dd(view,cv,popup,"rres",D.right-280,D.row2,280,"Result:",label,opts,function(v)view.io_rec_result=v end)
   view.io_crumbs={{"Records",function()view.io_rec_tab="damage"end},{"Non-Damage",res~="all"and function()view.io_rec_result=nil end or nil},{label}}
   draw=function()nondamage(view,cv,tracker,s,res,D.sheet)end
  end
 end
 view:_sheet(cv,D.sheet);draw();view:_sheet_end(cv)
end
