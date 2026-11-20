-- Information Overload: Weapons, per-weapon figures from the weapon hits the mod could match.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_stats")
local E=mod:io_dofile(base.."enemy_catalog")
local Overview=mod:io_dofile(base.."io_overview")
local Patch=mod:io_dofile(base.."game_patch")
local History=mod:io_dofile(base.."history_recalculation")
local WeaponTemplates=require("scripts/settings/equipment/weapon_templates/weapon_templates")
local C,KC,DASH,CN,rgba,F=D.c,K.c,K.dash,K.class_names,D.rgba,D.font
local X,W,L,R,HW=D.left,D.width,D.left,D.col2,D.col
local FEW=20
local C1,C2=KC.amber,KC.blue
local SLOTN={melee="Melee",ranged="Ranged",blitz="Blitz"}
local DOTS={
 {"bleed","Bleed",CN},
 {"burn","Burn",{veteran=true,zealot=true,ogryn=true,cryptic=true}},
 {"soulblaze","Soulblaze",{psyker=true}},
 {"toxin","Toxin",{broker=true}},
}
local DOT_NAMES={}
for _,dot in ipairs(DOTS)do DOT_NAMES[dot[1]]=dot[2];SLOTN[dot[1]]="Damage Over Time"end
local SPECIAL={{"all","All Hits"},{"regular","Without Special"},{"special","Special Only"}}
local RANGED_SPECIAL={{"regular","Regular Attack"},{"special","Special Only"}}
local INFERNO={{"all","All Loadouts"},{"with","With Inferno"},{"without","Without Inferno"}}
local ARMX={};for _,a in ipairs(K.ARM)do ARMX[#ARMX+1]=a end;ARMX[#ARMX+1]={"unknown","Unknown"}
local GROUPS={{"normal","Trash Enemies"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"},{"lieutenant","Lieutenants"},{"other","Other"}}
local DTABS={{"hit","Per Hit"},{"enemy","By Enemy"},{"bless","Blessings"}}
local function weapon(id)local ok,name=pcall(mod.io_weapon_name or tostring,id);return ok and type(name)=="string"and name~="Unknown weapon"and name or nil end
local function clean(s)return type(s)=="string"and (s:gsub("{#[^}]*}",""):gsub("%s+"," "):gsub("^ ",""):gsub(" $",""))or ""end
-- a weapon's blessings or perks in name order, so the same ones in other slots are one; perks part on the game's " / ", as a perk's own text can hold a comma
local function sorted(s,sep)sep=sep or ",";local t={};for b in (s..sep):gmatch("(.-)"..sep)do b=b:match("^%s*(.-)%s*$");if b~=""then t[#t+1]=b end end;table.sort(t);return table.concat(t,", "),t end
local Icons=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/weapon_icons")
local function icon_of(w)return Icons.of(w.name,w.tmpl)end
local Slots=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/run_slots")
local function per(x)return x.h>0 and x.t/x.h or 0 end
local function useful_per(x)return x.h>0 and x.u/x.h or 0 end
local function pct(a,b)return b and b>0 and math.floor(100*a/b+.5).."%"or DASH end
local function overkill(x)return pct(x.o,x.u+x.o)end
local function add(dst,key,b,run)if (b.hits or 0)<=0 then return end;local t=dst[key]or {h=0,t=0,u=0,o=0,pts={}};dst[key]=t
 t.h=t.h+b.hits;t.t=t.t+(b.total or 0);t.u=t.u+(b.useful or 0);t.o=t.o+(b.overkill or 0);if run then t.pts[#t.pts+1]={run=run,h=b.hits,t=b.total or 0}end end
local function sums(d)local s={h=0,t=0,u=0,o=0};for _,x in pairs(d)do s.h=s.h+x.h;s.t=s.t+x.t;s.u=s.u+x.u;s.o=s.o+x.o end;return s end
local function entry(key,slot,name)
 return {key=key,slot=slot,name=name,cls={},clist={},ms={},used=0,left=0,sets={},slist={},d={},best={},blist={},clv={},mh={}}
end
local function use(w,run)
 local class=run.context.class or "unknown"
 if not w.cls[class]then w.cls[class]=true;w.clist[#w.clist+1]=CN[class]or class end
 w.ms[#w.ms+1]=run
end
local function add_run(w,set,run,d)
 local h,total=0,0
 for armour,b in pairs(d or {})do
  if armour~="all"and armour~="void_shield"and b.hits>0 then
   add(w.d,armour,b,run)
   if set then add(set.d,armour,b)end
   h=h+b.hits;total=total+b.total
  end
 end
 if h>0 then w.used=w.used+1;w.mh[run]={h,total}else w.left=w.left+1 end
end
local function special_mode(view,key)
 local ranged=key and key:find("^ranged:")
 local selected=view.io_weap_special_key==key and view.io_weap_special
 if selected and (selected~="all"or not ranged)then return selected end
 return ranged and "regular"or "all"
end
local function has_special(w)
 local template=w.tmpl or ""
 if w.slot=="ranged"then
  if w.special_hits or template:match("^forcestaff_") or template=="ogryn_gauntlet_p1_m1"then return true end
  local definition=WeaponTemplates[template]
  for _,action in pairs(definition and definition.actions or {})do
   if action.kind=="sweep"or action.kind=="melee_explosive"then return true end
  end
  return false
 end
 return template:match("^forcesword_") or template:match("^thunderhammer_")
  or template:match("^powersword_") or template:match("^chain") or template:match("^eviscerator_")
  or template:match("^powermaul_") or template:match("^ogryn_powermaul_")
  or template=="ogryn_gauntlet_p1_m1"
end
-- key, label, the weapon its best hits name, the tactical talent that equips it, and that talent's title
local BLITZES={{"brain_burst","Brain Burst","psyker_smite","psyker_brain_burst_improved","loc_talent_psyker_brain_burst_improved"},{"smite","Smite","psyker_chain_lightning","psyker_grenade_chain_lightning","loc_ability_psyker_chain_lightning"}}
local BLITZ_NAMES={};for _,blitz in ipairs(BLITZES)do BLITZ_NAMES[blitz[1]]=blitz[2]end
-- a match counts for a blitz its loadout's talents name, or one it hit with
local function taken(lo,data,best,blitz)
 local d=data.weapons and data.weapons[blitz[1]]
 if d and next(d.all)then return true end
 for _,t in ipairs(type(lo)=="table"and type(lo.talents)=="table"and lo.talents or {})do if type(t)=="table"and t.id==blitz[4]then return true end end
 -- a loadout saved before its talents were kept names the blitz by the talent's title alone
 if type(lo)=="table"and lo.talents==nil and type(lo.blitz)=="string"and lo.blitz==Localize(blitz[5])then return true end
 for _,e in ipairs(best)do local x=e.context;if e.name=="single_hit"and x and x.weapon==blitz[3]then return true end end
 return false
end
-- a match saved before hits were split filed thrown grenades and blitzes with its ranged hits, so its ranged total is the weapon's only when no other
-- ranged attack has a damage entry among its best hits (a dodge names whatever was held); one with no best hits cannot say; its melee total holds only
-- melee blows, a ranged weapon's bash among them
local function alone(best,slot,t)
 if slot=="melee"then return true end
 if not t or not best[1]then return false end
 for _,e in ipairs(best)do local x=e.context
  if e.name=="damage"and x and type(x.weapon)=="string"and x.category~="melee"and x.category~="dot"and (x.grenade or x.weapon~=t)then return false end
 end
 return true
end
local function build(view)
 local class=view.io_weap_class or "all"
 local cohort=view.io_soulblaze_cohort or "all"
 local map,list,used={},{},{}
 for _,run in ipairs(K.scoped(view))do
  local c=run.context
  local L=c.operative_loadouts;local lo=L and (L[tostring(c.character)]or c.character_name and L[c.character_name])
  -- a match saved before loadouts were kept names only the weapon of the slot it was played in, by its template, and not its blessings
  local old=not lo and (c.category=="melee"or c.category=="ranged")and type(c.weapon)=="string"and not c.grenade and weapon(c.weapon)
  if old then lo={[c.category]=old,[c.category.."_template"]=c.weapon}end
  local data=Slots.get(run)
  local best=History.entries(run.contributions,"best",true)
  local took={};if c.class=="psyker"then for _,blitz in ipairs(BLITZES)do took[blitz[1]]=taken(lo,data,best,blitz)end end
  if c.class then
   local keys=used[c.class]or {};used[c.class]=keys
   for _,slot in ipairs({"melee","ranged"})do
    local name=lo and lo[slot]
    if type(name)=="string"and name~=""then keys[slot..":"..name]=true end
   end
   for _,dot in ipairs(DOTS)do
    if dot[3][c.class]and next(data[dot[1]]or {})then keys[dot[1]]=true end
   end
   for _,blitz in ipairs(BLITZES)do if took[blitz[1]]then keys[blitz[1]]=true end end
  end
  if class=="all"or c.class==class then
  local tmpl={}
  if type(lo)=="table"then
   for _,e in ipairs(best)do local x=e.context;if x and x.weapon and not x.grenade and lo[x.category]and not tmpl[x.category]and weapon(x.weapon)==lo[x.category]then tmpl[x.category]=x.weapon end end
  end
  for _,blitz in ipairs(BLITZES)do
   if took[blitz[1]]then
    local damage=data.weapons and data.weapons[blitz[1]]
    local row=map[blitz[1]]
    if not row then row=entry(blitz[1],"blitz",blitz[2]);map[blitz[1]]=row;list[#list+1]=row end
    use(row,run);add_run(row,nil,run,damage and damage.all)
    for _,e in ipairs(best)do local x=e.context
     if e.name=="single_hit"and x and x.weapon==blitz[3]and x.enemy then
      local b=row.best[x.enemy]
      if not b then b={e=x.enemy,v=0,pts={}};row.best[x.enemy]=b;row.blist[#row.blist+1]=b end
      b.pts[#b.pts+1]={v=e.value,run=run}
      if e.value>b.v then b.v=e.value;b.run=run end
     end
    end
   end
  end
  for _,dot in ipairs(DOTS)do
   local key,name,classes=dot[1],dot[2],dot[3]
   local damage=data[key]
   if classes[c.class] and next(damage or {})then
    local row=map[key]
    if not row then row=entry(key,key,name);map[key]=row;list[#list+1]=row end
    local include=true
    if key=="soulblaze"and cohort~="all"then
     local template=lo and lo.ranged_template
     local ranged_name=lo and lo.ranged
     local group
     if template then group=template=="forcestaff_p2_m1"and "with"or "without"
     elseif type(ranged_name)=="string"and ranged_name~=""then
      local inferno=weapon("forcestaff_p2_m1")
      group=(ranged_name==inferno or ranged_name:find("Inferno Force Staff",1,true))and "with"or "without"
     end
     include=cohort==group
    end
    if include then use(row,run);add_run(row,nil,run,damage)end
   end
  end
  if type(lo)=="table"then
   local kb;for _,e in ipairs(best)do if e.name=="kills"and e.context and (not kb or e.value>kb.value)then kb=e end end
   for _,slot in ipairs({"melee","ranged"})do local name=lo[slot]
    if type(name)=="string"and name~=""then
     local key=slot..":"..name;local w=map[key]
     if not w then w=entry(key,slot,name);map[key]=w;list[#list+1]=w end
     use(w,run);w.tmpl=w.tmpl or lo[slot.."_template"]or tmpl[slot]
     local bk=sorted(clean(lo[slot.."_blessings"]));local set=not old and w.sets[bk]or nil;if not set and not old then set={key=bk,b={},ms=0,d={},perks={}};for b in bk:gmatch("[^,]+")do set.b[#set.b+1]=b:match("^%s*(.-)%s*$")end;w.sets[bk]=set;w.slist[#w.slist+1]=set end
     if set then set.ms=set.ms+1;local pk,each=sorted(clean(lo[slot.."_perks"])," / ");if pk~=""and pk~="None"and pk~="Not available"then set.perks[pk]=each end end
     local modes=data.weapons and data.weapons[slot]
     w.special_hits=w.special_hits or modes and next(modes.special)~=nil
     local mode=slot=="ranged"and "regular"or "all"
     if key==view.io_weap then mode=special_mode(view,key)end
     -- a match saved before hits were split by attack keeps them all under its slot, so it counts for all hits but not for special ones;
     -- a force staff's were left out of that older count, as they were before the split
     local legacy=not modes and mode~="special"and not (slot=="ranged"and ((w.tmpl or ""):find("forcestaff",1,true)or name:find("Force Staff",1,true)))and alone(best,slot,lo[slot.."_template"]or tmpl[slot])
     local damage=modes and modes[mode]or legacy and data[slot]or nil
     local flamer=slot=="ranged"and (w.tmpl=="flamer_p1_m1"or (not w.tmpl and name:find("Flamer",1,true)))
     -- its own burn where the match keeps it, or else every burn in the match
     local burn=data.burn_flamer or data.burn
     if flamer and mode=="regular"and (modes or legacy)and next(burn or {})then damage=Slots.combine({damage,burn})end
     add_run(w,set,run,damage)
     local t=lo[slot.."_template"]or tmpl[slot]
     if t and (mode=="all"or slot=="ranged"and mode=="regular")then for _,e in ipairs(best)do local x=e.context
      if x and x.weapon==t and x.enemy and type(e.value)=="number"and e.value>0 and (slot~="ranged"or x.category=="ranged") and (e.name=="single_hit"or e.name=="explosive_hit"or e.name=="explosive_single_hit")then local kind=e.name=="explosive_hit"and "x"or e.name=="explosive_single_hit"and "xh"or "s";local k=tostring(x.enemy)..kind
       local b=w.best[k];if not b then b={e=tostring(x.enemy),kind=kind,v=0,pts={}};w.best[k]=b;w.blist[#w.blist+1]=b end
       b.pts[#b.pts+1]={v=e.value,run=run};if e.value>b.v then b.v=e.value;b.run=run end
      elseif slot=="melee"and x and x.weapon==t and e.name=="melee_cleave"then w.clv[#w.clv+1]={t=x.enemy and tostring(x.enemy)or DASH,v=e.value,run=run}end
     end
      if kb and kb.context.weapon==t and (slot~="ranged"or kb.context.category=="ranged")and (not w.k or kb.value>w.k.v)then w.k={v=kb.value,run=run}end
     end
    end
   end
  end
 end
 end
 for _,w in ipairs(list)do w.tot=sums(w.d);for _,s in ipairs(w.slist)do s.tot=sums(s.d)end
  table.sort(w.slist,function(a,b)if a.ms~=b.ms then return a.ms>b.ms end;return a.tot.h>b.tot.h end);table.sort(w.clv,function(a,b)return a.v>b.v end)end
 table.sort(list,function(a,b)local da,db=DOT_NAMES[a.slot],DOT_NAMES[b.slot];if da or db then if da and db then return da<db end;return db~=nil end;local x,y=a.tot.h>0,b.tot.h>0;if x~=y then return x end;if a.tot.h~=b.tot.h then return a.tot.h>b.tot.h end;if #a.ms~=#b.ms then return #a.ms>#b.ms end;return a.name<b.name end)
 return list,used
end
local function sub_line(w)return table.concat(w.clist,", ").." · "..SLOTN[w.slot].." · "..K.plural(#w.ms,"Mission")end
local function figure(view,cv,x,y,label,value,sub,size)
 cv:rect(x,y,2,58,rgba(185,138,46,.55),true);cv:text(label,x+10,y,200,18,14,C.label);cv:text(value,x+10,y+18,200,28,size or 24,C.value)
 if sub then cv:text(sub,x+10,y+46,200,18,14,C.muted)end
end
local function open(view,w,tab)return function()view.io_weap=w.key;view.io_weap_tab=tab or "hit";view.io_weap_from=nil;view.io_weap_from_tab=nil;if view.scroll then view.scroll.weapons=0 end end end
-- a weapon opened from another weapon's page keeps the weapon and tab it came from, so Back returns there
local function jump(view,from,w,tab)local go=open(view,w,tab);return function()local was=view.io_weap_tab;go();view.io_weap_from=from.key;view.io_weap_from_tab=was end end
local function card_h(w)return w.tot.h>0 and 318 or 100 end
local function wcard(view,cv,w,x,y)
 local h=card_h(w);local ic=icon_of(w);view:_card(cv,x,y,HW,h,view:_fit(w.name,20,ic and HW-247 or HW-72),nil,nil,open(view,w,"hit"))
 if ic then cv:texture(ic,x+HW-195,y+9,149,56,C.label,true)end
 cv:text(ic and view:_fit(sub_line(w),14,HW-239)or sub_line(w),x+36,y+44,HW-50,20,14,C.label)
 local T=w.tot
 if T.h>0 then local fw=(HW-36-16)/3
  figure(view,cv,x+36,y+68,"Hits",K.exact(T.h),K.plural(w.used,"Mission"));figure(view,cv,x+36+fw,y+68,"Damage",K.mod(T.t),(T.u+T.o>0 and overkill(T).." Overkill"or "Overkill unmeasured"));figure(view,cv,x+36+2*fw,y+68,"Per Hit",K.exact(per(T)),"Total Damage")
  cv:text("Damage Per Hit, By Armour",x+36,y+138,300,20,14,C.gold)
  local max=1;for _,a in ipairs(K.ARM)do local d=w.d[a[1]];if d then max=math.max(max,per(d))end end
  local bx,bw=x+140,HW-140-130
  for i,a in ipairs(K.ARM)do local d=w.d[a[1]];local ry=y+160+(i-1)*20
   cv:text(a[2],x+36,ry,100,20,14,C.label);cv:rect(bx,ry+6,bw,8,KC.track,true)
   if d then local few=d.h<FEW;cv:rect(bx,ry+6,math.max(3,per(d)/max*bw),8,C1,true,few and .35 or 1)
    local hw=view:_w(K.exact(d.h),14);cv:text(K.exact(d.h),x+HW-14-hw-2,ry,hw+4,20,14,C.muted);cv:text(K.exact(per(d)),x+HW-14-hw-108,ry,100,20,16,few and C.muted or C.value,"right")
   else cv:text(DASH,x+HW-114,ry,100,20,14,C.muted,"right")end
  end
 end
 local bl={};for _,s in ipairs(w.slist)do if s.key~=""then bl[#bl+1]=s.key end end
 if #bl>0 then local head=#bl>1 and #bl.." Blessing Sets"or "Blessings";local hw=view:_w(head,14);cv:text(head,x+36,y+h-30,hw+4,20,14,C.gold);cv:text(view:_fit(table.concat(bl,"  |  "),14,HW-62-hw),x+44+hw,y+h-30,HW-60-hw,20,14,C.muted)end
 return h
end
local function highlights(view,cv,list,y)
 local meas={};for _,w in ipairs(list)do if not DOT_NAMES[w.slot]and w.tot.h>=50 then meas[#meas+1]=w end end
 if #meas<2 then return y end
 local function top(f)local b,v;for _,w in ipairs(meas)do local x=f(w);if x and (not v or x>v)then b,v=w,x end end;return b,v end
 local tiles={}
 local w,v=top(function(w)return w.tot.h end);tiles[#tiles+1]={"Most Hits",K.exact(v).." Hits",w.name,open(view,w),w}
 w,v=top(function(w)return per(w.tot)end);tiles[#tiles+1]={"Hardest Per Hit",K.exact(v).." Per Hit",w.name,open(view,w),w}
 w,v=top(function(w)local c=w.d.super_armor;return c and c.h>=FEW and per(c)or nil end);if w then tiles[#tiles+1]={"Best Into Carapace",K.exact(v).." Per Hit",w.name,open(view,w),w}end
 local ks;for _,x in ipairs(list)do if not DOT_NAMES[x.slot]and x.k and (not ks or x.k.v>ks.k.v)then ks=x end end
 if ks then tiles[#tiles+1]={"Kills In A Row",tostring(ks.k.v),"Ended On "..ks.name,K.open_run(view,ks.k.run.id),ks}end
 local tw=(W-10*(#tiles-1))/#tiles
 for i,t in ipairs(tiles)do local tx=X+(i-1)*(tw+10)
  cv.z=4;cv:rect(tx,y,tw,72,C.card);cv.z=5;cv:edges(tx,y,tw,72,1,C.frame);cv:rect(tx,y,2,72,C.gold,true)
  view:_hit("base",tx,y,tw,72,t[4],{bg=C.card_h,edge=C.hover})
  local ic=icon_of(t[5]);if ic then cv:texture(ic,tx+tw-122,y+8,112,42,C.label,true)end
  cv:text(t[1],tx+12,y+6,tw-20,18,14,C.label);cv:text(t[2],tx+12,y+24,tw-20,26,20,C.value);cv:text(view:_fit(t[3],14,tw-22),tx+12,y+50,tw-20,18,14,C.gold)
 end
 return y+82
end
local function cards(view,cv,list,y)
 local yl,yr=y,y
 local dots=false
 for _,w in ipairs(list)do
  if not dots and DOT_NAMES[w.slot]then yl=math.max(yl,yr);yr=yl;dots=true end
  if yl<=yr then yl=yl+wcard(view,cv,w,L,yl)+10 else yr=yr+wcard(view,cv,w,R,yr)+10 end end
 return math.max(yl,yr)
end
local function compare(view,cv,list,y)
 local meas={};for _,w in ipairs(list)do if w.tot.h>0 then meas[#meas+1]=w end end
 local cols={{"all","All"}};for _,a in ipairs(K.ARM)do cols[#cols+1]=a end
 local sort=view.io_wsort or "all"
 local function cell(w,a)if a=="all"then return w.tot end;return w.d[a]end
 local function val(w,a)local x=cell(w,a);return x and x.h>0 and per(x)or nil end
 table.sort(meas,function(a,b)local da,db=DOT_NAMES[a.slot],DOT_NAMES[b.slot];if da or db then if da and db then return da<db end;return db~=nil end;return (val(a,sort)or -1)>(val(b,sort)or -1)end)
 local cmax={};for _,c in ipairs(cols)do local m=1;for _,w in ipairs(meas)do m=math.max(m,val(w,c[1])or 0)end;cmax[c[1]]=m end
 local h=46+30+#meas*41+14
 view:_card(cv,X,y,W,h,"Damage Per Hit, Every Weapon")
 local tx,tw=X+25,W-38;local nw=330;local cw=(tw-nw)/#cols;local hy=y+46
 cv:rect(tx,hy,tw,30,KC.head,true);cv:text("Weapon",tx+10,hy,200,30,14,C.muted)
 for i,c in ipairs(cols)do local cx=tx+nw+i*cw;local on=c[1]==sort;local lw=view:_w(c[2],14)
  cv:text(c[2],cx-8-lw-4,hy,lw+4,30,14,on and C.gold_hi or C.muted,"right");view:_hit("base",cx-8-lw,hy,lw,30,function()view.io_wsort=c[1]end,{under=C.value})end
 cv:rect(tx,hy+29,tw,1,C.frame,true)
 for r,w in ipairs(meas)do local ry=hy+30+(r-1)*41
  view:_hit("base",tx,ry,nw,41,open(view,w),{bg=C.row_h})
  -- a long name comes down a size or two, then is cut, so it keeps its one line above the class
  local ns=15;while ns>13 and view:_w(w.name,ns)>nw-14 do ns=ns-1 end
  cv:text(view:_fit(w.name,ns,nw-14),tx+10,ry+3,nw-14,20,ns,C.value);cv:text(view:_fit(table.concat(w.clist,", ").." · "..SLOTN[w.slot],13,nw-14),tx+10,ry+21,nw-14,18,13,C.muted)
  for i,c in ipairs(cols)do local x0=tx+nw+(i-1)*cw;local v=val(w,c[1]);local x=cell(w,c[1])
   if v then local few=x.h<FEW;if not few then cv:rect(x0+2,ry,cw-2,40,rgba(185,138,46,.06+.6*v/cmax[c[1]]),true)end
    cv:text(K.exact(v),x0,ry+3,cw-8,20,16,few and C.muted or C.value,"right");cv:text(K.exact(x.h),x0,ry+21,cw-8,16,12,C.muted,"right")
   else cv:text(DASH,x0,ry,cw-8,40,16,C.muted,"right")end
  end
  cv:rect(tx,ry+40,tw,1,C.line,true)
 end
 return y+h+10
end
local function chips(view,cv,x,y,list,dashed,hi)
 for _,s in ipairs(list)do local w=view:_w(s,14)+16;local on=hi and hi[s]
  cv.z=4;cv:rect(x,y,w,22,on and C.fill_s or C.fill);cv.z=5;cv:edges(x,y,w,22,1,on and C.sel or dashed and C.line or C.frame)
  cv:text(s,x,y,w,22,14,on and C.gold_hi or dashed and C.label or C.value,"center");x=x+w+6 end
 return x
end
local function banner(view,cv,w,y,compared)
 local sets=w.slist;local rows=compared and 1 or math.max(1,#sets)
 local h=70+rows*28+6;view:_card(cv,X,y,W,h,w.name);cv:text(sub_line(w),X+36,y+42,600,20,14,C.label)
 -- the side by side below draws two of the sets with hits, so the heading counts those two and names any other set with hits; a set with no hits has nothing to compare
 if compared then local left=#compared-2;cv:text("2 Blessing Sets",X+36,y+70,200,22,14,C.gold)
  cv:text("Compared Below"..(left>0 and " · "..left.." More Not Compared"or ""),X+36+view:_w("2 Blessing Sets",14)+10,y+70,500,22,14,C.muted)
 else for i,s in ipairs(sets)do local sy=y+70+(i-1)*28;local x=X+36
  if #sets>1 then cv:text("Set "..string.char(64+i),x,sy,50,22,14,C.gold);x=x+50 end
  x=chips(view,cv,x,sy,s.b);local pk={};for p in pairs(s.perks)do pk[#pk+1]="Perks: "..p end;table.sort(pk);chips(view,cv,x,sy,pk,true)
 end end
 local T=w.tot
 local dot=DOT_NAMES[w.slot]
 if T.h>0 then local fx=X+W-16-(dot and 450 or 400)
  figure(view,cv,fx,y+30,"Hits",K.exact(T.h),K.plural(w.used,"Mission"),22);figure(view,cv,fx+100,y+30,"Damage",K.mod(T.t,true),K.exact(T.t),22)
  if dot then
   figure(view,cv,fx+200,y+30,"Damage Per Mission",K.exact(T.t/w.used),nil,22)
  else figure(view,cv,fx+200,y+30,"Per Hit",K.exact(per(T)),"Total Damage",22)end
  figure(view,cv,fx+(dot and 350 or 300),y+30,"Overkill",overkill(T),T.u+T.o>0 and K.mod(T.o)or nil,22)
 end
 return y+h+10
end
local function step_of(max)local _,ticks=K.nice(max,4);return ticks end
local function hit_tab(view,cv,w,y,tracker)
 y=banner(view,cv,w,y)
 if w.tot.h<=0 then view:_card(cv,X,y,W,92,"No Hit Numbers For This Weapon");y=y+102
 else
  local rows={};for _,a in ipairs(ARMX)do if w.d[a[1]]then rows[#rows+1]={a[2],w.d[a[1]]}end end
  local max=0;for _,r in ipairs(rows)do max=math.max(max,per(r[2]));for _,p in ipairs(r[2].pts)do if p.h>0 then max=math.max(max,per(p))end end end
  local ticks=step_of(max);local top=ticks[#ticks];local cx=X+25;local x0,x1=cx+150,cx+940;local function sx(v)return x0+(x1-x0)*v/top end
  local h=46+30+#rows*48+26+30;view:_card(cv,X,y,W,h,"Damage Per Hit, By Armour",K.plural(w.used,"Mission")..", "..K.exact(w.tot.h).." Hits, Total Damage")
  local hy=y+46;cv:text("Armour",cx,hy,100,20,14,C.muted);cv:text("Damage Per Hit",x0,hy,200,20,14,C.muted);cv:text("Average",cx+1010-200,hy,200,20,14,C.muted,"right");cv:text("Overkill",cx+1140-200,hy,200,20,14,C.muted,"right")
  local gy=hy+26;for _,v in ipairs(ticks)do cv:rect(sx(v),gy,1,#rows*48,KC.grid,true);cv:text(K.tick(v),sx(v)-40,gy+#rows*48+4,80,18,14,C.muted,"center")end
  for i,r in ipairs(rows)do local d=r[2];local yc=gy+(i-1)*48+24;local few=d.h<FEW
   cv:text(r[1],cx,yc-22,140,22,16,C.value);cv:text(K.plural(d.h,"Hit"),cx,yc,140,20,14,C.muted)
   cv:rect(x0,yc-8,math.max(2,sx(per(d))-x0),16,C1,true,few and .35 or 1)
   cv:text(K.exact(per(d)),cx+1010-200,yc-12,200,24,18,few and C.muted or C.value,"right")
   cv:rect(cx+1030,yc-4,60,8,KC.track,true);cv:rect(cx+1030,yc-4,math.max(2,60*(d.u+d.o>0 and d.o/(d.u+d.o) or 0)),8,KC.meter,true)
   cv:text(overkill(d),cx+1140-200,yc-10,200,20,16,C.value,"right")
   if w.used>1 then local placed={}
    for _,p in ipairs(d.pts)do if p.h>0 then local px=sx(per(p));local py
      for _,off in ipairs({0,-11,11,-18,18})do local ok=true;for _,q in ipairs(placed)do if math.abs(q[1]-px)<11 and math.abs(q[2]-(yc+off))<11 then ok=false end end;if ok then py=yc+off;break end end
      -- with every place near it taken, a mission joins the nearest square, which then shows how many it holds
      if py then placed[#placed+1]={px,py,{p}}else local near,nd;for _,q in ipairs(placed)do local dd=math.abs(q[1]-px)+math.abs(q[2]-yc);if not nd or dd<nd then near,nd=q,dd end end;local l=near[3];l[#l+1]=p end end end
    -- each square answers for the part of its row nearest to it, so close ones are picked one at a time; the one under the pointer grows, turns gold and says which mission it is
    local tr=view:_tracker();local cols={};table.sort(placed,function(a,b)if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
    for _,q in ipairs(placed)do local c=cols[#cols];if c and q[1]-c.x0<11 then c[#c+1]=q;c.x1=q[1]else cols[#cols+1]={q,x0=q[1],x1=q[1]}end end
    for ci,c in ipairs(cols)do local prev,nxt=cols[ci-1],cols[ci+1]
     local left=prev and math.max((prev.x1+c.x0)/2,c.x0-40)or c.x0-40;local right=nxt and math.min((c.x1+nxt.x0)/2,c.x1+40)or c.x1+40
     table.sort(c,function(a,b)return a[2]<b[2]end)
     for qi,q in ipairs(c)do local top=qi>1 and (c[qi-1][2]+q[2])/2 or yc-24;local bot=qi<#c and (q[2]+c[qi+1][2])/2 or yc+24
      local l=q[3];table.sort(l,function(a,b2)return per(a)>per(b2) end);local p=l[1];local rc=p.run.context or {};local key="dot|"..r[1].."|"..tostring(p.run.id);local on=view.io_hkey==key
      K.dot(cv,q[1],q[2],on and 7 or 4,on and C.gold_hi or C.value)
      local tip
      if #l==1 then tip={tr and tr:run_mission_name(rc)or "Mission",K.dm(K.info(p.run).day).." · "..Overview.diff_label(rc),"Per Hit: "..K.exact(per(p)),"Hits: "..K.exact(p.h),"","Click to open the mission"}
      else cv:text(tostring(#l),q[1]+8,q[2]-19,40,14,12,on and C.gold_hi or C.value);tip={#l.." Missions Here"}
       for i=1,math.min(5,#l)do local x=l[i];tip[#tip+1]=(tr and tr:run_mission_name(x.run.context or {})or "Mission")..", "..K.dm(K.info(x.run).day)..": "..K.exact(per(x)).." Per Hit"end
       if #l>5 then tip[#tip+1]="And "..(#l-5).." More"end;tip[#tip+1]="";tip[#tip+1]="Click to open the highest"end
      view:_hit("base",left,top,right-left,bot-top,K.open_run(view,p.run.id),nil,nil,tip,key)
     end
    end
   end
  end
  K.legend(view,cv,X+36,y+h-28,w.used>1 and {{"sq",C1,"All Missions"},{"dot",C.value,"One Mission, Moved Up Or Down Only When Close"}}or {{"sq",C1,"Its One Mission"}})
  y=y+h+10
 end
 local share={};for _,a in ipairs(ARMX)do local d=w.d[a[1]];if d then share[#share+1]={a[2],d.h}end end;table.sort(share,function(a,b)return a[2]>b[2]end)
 local yl=y
 if #share>0 then local tot=w.tot.h;local mx=share[1][2]/tot;local lh=46+#share*28+12
  view:_card(cv,L,y,HW,lh,"Where Your Hits Landed","All Missions")
  for i,s in ipairs(share)do local ry=y+46+(i-1)*28;local f=s[2]/tot;cv:text(s[1],L+25,ry,100,28,14,C.label);cv:rect(L+129,ry+9,math.max(3,f/mx*(HW-240)),10,C1,true);cv:text(math.floor(100*f+.5).."%",L+HW-113,ry,100,28,16,C.value,"right")end
  yl=y+lh+10 end
 local rows={};local runs={};for _,r in ipairs(w.ms)do runs[#runs+1]=r end;table.sort(runs,function(a,b)return tostring(a.started_at)>tostring(b.started_at)end)
 for _,run in ipairs(runs)do local m=w.mh[run];local hh,total=m and m[1]or 0,m and m[2]or 0
  rows[#rows+1]={{K.dm(K.info(run).day),nil,C.muted},tracker:run_mission_name(run.context),hh>0 and K.exact(hh)or {"Left Out",nil,C.muted},hh>0 and K.exact(total/hh)or {DASH,nil,C.muted},act=K.open_run(view,run.id)}end
 local x=#share>0 and R or L;local mh=46+K.table_h(rows)+12
 view:_card(cv,x,y,HW,mh,"Missions");K.table(view,cv,x+13,y+46,HW-26,{{"Date",10,"l"},{"Map",80,"l",max=300},{"Hits",HW-26-110},{"Per Hit",HW-36}},rows)
 return math.max(yl,y+mh+10)
end
local function enemy_tab(view,cv,w,y,tracker)
 y=banner(view,cv,w,y)
 if #w.blist==0 then view:_card(cv,X,y,W,92,"No Hits By Enemy");return y+102 end
 local group={};for _,e in pairs(E.catalog())do group[e.label]=e.group end
 local order={};for i,g in ipairs(GROUPS)do order[g[1]]=i end
 for _,b in ipairs(w.blist)do b.g=b.e:find("^Lt ")and "lieutenant"or group[b.e]or "other"end
 local list={};for _,b in ipairs(w.blist)do list[#list+1]=b end
 table.sort(list,function(a,b)if a.g~=b.g then return order[a.g]<order[b.g]end;return a.v>b.v end)
 local ng=0;local last;for _,b in ipairs(list)do if b.g~=last then ng=ng+1;last=b.g end end
 local max=0;for _,b in ipairs(list)do max=math.max(max,b.v)end;local ticks=step_of(max);local top=ticks[#ticks]
 local cx=X+25;local x0,x1=cx+200,cx+980;local function sx(v)return x0+(x1-x0)*v/top end
 local body=ng*34+#list*30;local h=46+26+body+30
 view:_card(cv,X,y,W,h,"Biggest Hit On Each Enemy",K.plural(#list,"Enemy Type","Enemy Types"))
 local hy=y+46;cv:text("Enemy",cx,hy,100,20,14,C.muted);cv:text("Biggest Single Hit",x0,hy,200,20,14,C.muted);cv:text("Best",cx+1060-200,hy,200,20,14,C.muted,"right");cv:text("Missions",cx+1140-200,hy,200,20,14,C.muted,"right")
 local gy=hy+26;for _,v in ipairs(ticks)do cv:rect(sx(v),gy,1,body,KC.grid,true);cv:text(K.tick(v),sx(v)-40,gy+body+4,80,18,14,C.muted,"center")end
 local ry=gy;last=nil
 for _,b in ipairs(list)do
  if b.g~=last then local label;for _,g in ipairs(GROUPS)do if g[1]==b.g then label=g[2]end end;cv:text(label,cx,ry+4,300,26,14,C.gold);cv:rect(cx,ry+30,1140,1,C.frame,true);ry=ry+34;last=b.g end
  local yc=ry+15;if b.run then view:_hit("base",cx-6,ry,1152,30,K.open_run(view,b.run.id),{bg=C.row_h})end
  local nw=view:_w(b.e,16);cv:text(b.e,cx,ry,nw+4,30,16,C.value);if b.kind=="x"or b.kind=="xh"then cv:text(b.kind=="xh"and "Explosion Hit"or "Explosion",cx+nw+8,ry,100,30,14,C.muted)end
  cv:rect(x0,yc-6,math.max(3,sx(b.v)-x0),12,C1,true)
  for _,p in ipairs(b.pts)do K.dot(cv,sx(p.v),yc,3,C.value)end
  cv:text(K.exact(b.v),cx+1060-200,ry,200,30,16,C.value,"right");cv:text(tostring(#b.pts),cx+1140-200,ry,200,30,14,C.muted,"right")
  ry=ry+30
 end
 y=y+h+10
 if #w.clv>0 then local rows={}
  for i=1,math.min(6,#w.clv)do local c=w.clv[i];rows[#rows+1]={c.t,K.exact(c.v),{tracker:run_mission_name(c.run.context),nil,C.muted},{K.dm(K.info(c.run).day),nil,C.muted},act=K.open_run(view,c.run.id)}end
  local ch=46+K.table_h(rows)+12;view:_card(cv,X,y,W,ch,"Biggest Cleaves","One Swing Through Several Enemies")
  K.table(view,cv,X+25,y+46,W-38,{{"Enemies Hit",10,"l",max=560},{"Damage",700},{"Mission",720,"l",max=300},{"Date",W-48}},rows)
  y=y+ch+10
 end
 return y
end
local function bless_tab(view,cv,w,y,list)
 local sets={};for _,s in ipairs(w.slist)do if s.tot.h>0 then sets[#sets+1]=s end end
 y=banner(view,cv,w,y,#sets>=2 and sets)
 if #sets<2 then
  local others={};for _,o in ipairs(list)do if o~=w then local n=0;for _,s in ipairs(o.slist)do if s.tot.h>0 then n=n+1 end end;if n>=2 then others[#others+1]=o end end end
  local h=others[1]and 92+44 or 76;view:_card(cv,X,y,W,h,"One Set Of Blessings So Far")
  if others[1]then cv:text("Weapons With Two Sets In This Scope",X+36,y+46,500,20,14,C.muted);local bx=X+36
   for _,o in ipairs(others)do local bw=view:_w(o.name,16)+30;if bx+bw<=X+W-20 then view:_ctl(cv,"base",bx,y+76,bw,34,jump(view,w,o,"bless"));cv:text(o.name,bx,y+76,bw,34,16,C.value,"center");bx=bx+bw+8 end end end
  return y+h+10
 end
 local A,B=sets[1],sets[2];local inA,inB={},{};for _,b in ipairs(A.b)do inA[b]=true end;for _,b in ipairs(B.b)do inB[b]=true end
 local hiA,hiB={},{};for _,b in ipairs(A.b)do if not inB[b]then hiA[b]=true end end;for _,b in ipairs(B.b)do if not inA[b]then hiB[b]=true end end
 local rows={};for _,a in ipairs(ARMX)do if A.d[a[1]]or B.d[a[1]]then rows[#rows+1]={a[2],A.d[a[1]],B.d[a[1]]}end end
 local max=0;for _,r in ipairs(rows)do if r[2]then max=math.max(max,per(r[2]))end;if r[3]then max=math.max(max,per(r[3]))end end
 local ticks=step_of(max);local top=ticks[#ticks];local cx=X+25;local x0,x1=cx+150,cx+1060;local function sx(v)return x0+(x1-x0)*v/top end
 local h=46+64+26+#rows*56+30;view:_card(cv,X,y,W,h,"Blessing Sets Side By Side","Total Damage Per Hit With Each Set")
 for i,s in ipairs({A,B})do local ky=y+46+(i-1)*30;local col=i==1 and C1 or C2;cv:rect(X+36,ky+6,14,10,col,true);cv:text("Set "..string.char(64+i),X+58,ky,50,22,14,C.gold)
  local x=chips(view,cv,X+110,ky,s.b,false,i==1 and hiA or hiB);local pk={};for p in pairs(s.perks)do pk[#pk+1]=p end;table.sort(pk)
  cv:text(K.plural(s.ms,"Mission").." · "..K.exact(s.tot.h).." Hits"..(pk[1]and " · "..table.concat(pk,"; ")or ""),x+4,ky,600,22,14,C.muted)end
 local hy=y+46+64;cv:text("Armour",cx,hy,100,20,14,C.muted);cv:text("Damage Per Hit",x0,hy,200,20,14,C.muted)
 local gy=hy+26;for _,v in ipairs(ticks)do cv:rect(sx(v),gy,1,#rows*56,KC.grid,true);cv:text(K.tick(v),sx(v)-40,gy+#rows*56+4,80,18,14,C.muted,"center")end
 for i,r in ipairs(rows)do local ry=gy+(i-1)*56;cv:text(r[1],cx,ry,140,56,16,C.value)
  for j=1,2 do local d=r[j+1];local by=ry+(j==1 and 12 or 28)
   if d then local few=d.h<FEW;cv:rect(x0,by,math.max(3,sx(per(d))-x0),14,j==1 and C1 or C2,true,few and .35 or 1);cv:text(K.exact(per(d)),sx(per(d))+8,by-2,100,18,14,few and C.muted or C.value)
   else cv:text("No Hits",x0+6,by-2,100,18,14,C.muted)end
  end
 end
 return y+h+10
end
local NULL={}
local function int(n)return math.floor((n or 0)+.5)end
local function f1(n)return tonumber(string.format("%.1f",n))end
-- as the page: overkill over the damage whose split was measured, nil when none was
local function overkill_share(x)return x.u+x.o>0 and 100*x.o/(x.u+x.o)or nil end
local function csv(v)v=tostring(v==nil and ""or v);if v:find('[",\n]')then return '"'..v:gsub('"','""')..'"'end;return v end
local function jstr(s)return '"'..tostring(s):gsub('[%c"\\]',function(c)return c=='"'and '\\"'or c=="\\"and "\\\\"or c=="\n"and "\\n"or string.format("\\u%04x",c:byte())end)..'"'end
-- pretty JSON in key order; objects are {_o={key,value,...}} and short arrays of plain values stay on one line
local function json(v,ind)
 local t=type(v);if v==NULL then return "null"elseif t=="string"then return jstr(v)elseif t=="boolean"then return tostring(v)
 elseif t=="number"then return v==math.floor(v)and string.format("%d",v)or tostring(v)end
 local pad=ind.."  ";local p={}
 if v._o then local o=v._o;if #o==0 then return "{}"end;for i=1,#o,2 do p[#p+1]=pad..jstr(o[i])..": "..json(o[i+1],pad)end;return "{\n"..table.concat(p,",\n").."\n"..ind.."}"end
 if #v==0 then return "[]"end
 local flat=true;for i,x in ipairs(v)do p[i]=json(x,pad);if type(x)=="table"and x~=NULL then flat=false end end
 return flat and "["..table.concat(p,", ").."]"or "[\n"..pad..table.concat(p,",\n"..pad).."\n"..ind.."]"
end
local function scope_of(view)
 local s=view.scope;local diff=s.mode=="havoc"and "All Havoc"or "All"
 if s.diff~="all"then diff=tostring(s.diff);for _,d in ipairs(view.model and view.model.diffs or {})do if d.value==s.diff then diff=d.label end end end
 return Overview.mode_names[s.mode]or DASH,diff,s.all_patches and "All Patches"or s.patch and Patch.display(s.patch)or DASH
end
local function note(w)
 if w.tot.h>0 then return w.left>0 and w.left.." left out: no hits logged"or ""end
 return "No measured hits in this selection."
end
-- the export's rows, from the same measured figures the page draws
local function sheet(view,list,tracker)
 local mode,diff,patch=scope_of(view)
 local arm={{"weapon","slot","class","blessings","perks","missions","armour","hits","damage","useful","overkill","useful_per_hit","overkill_pct","note"}}
 local ene={{"weapon","slot","enemy","enemy_group","kind","biggest_hit","missions","from_mission","date"}}
 local ws={};local js={_o={"exported_from","Information Overload "..tostring(mod.version or ""),"scope",{_o={"mode",mode,"difficulty",diff,"patch",patch,"weapon_special",#list==1 and (list[1].key==view.io_weap and special_mode(view,list[1].key)or list[1].slot=="ranged"and "regular")or "all","class",CN[view.io_weap_class]or "All Classes","soulblaze_inferno",view.io_soulblaze_cohort or "all"}},"weapons",ws}}
 local group={};for _,e in pairs(E.catalog())do group[e.label]=e.group end
 local order,gname={},{};for i,g in ipairs(GROUPS)do order[g[1]]=i;gname[g[1]]=g[2]end
 for _,w in ipairs(list)do
  local sl=SLOTN[w.slot]:lower();local bl,pk,seen,builds={},{},{},{}
  for _,s in ipairs(w.slist)do bl[#bl+1]=table.concat(s.b," + ");local ps={}
   for p,each in pairs(s.perks)do if not seen[p]then seen[p]=true;pk[#pk+1]=p end;for _,one in ipairs(each)do ps[#ps+1]=one end end
   table.sort(ps);builds[#builds+1]={_o={"blessings",s.b,"perks",ps,"missions",s.ms}}end
  table.sort(pk);local nt=note(w)
  local row={w.name,sl,table.concat(w.clist,", "),table.concat(bl," | "),table.concat(pk," | "),#w.ms}
  local function line(label,x)local r={};for i,v in ipairs(row)do r[i]=v end;local share=overkill_share(x);for _,v in ipairs({label,int(x.h),int(x.t),int(x.u),int(x.o),int(useful_per(x)),share and string.format("%.1f",share)or "",nt})do r[#r+1]=v end;arm[#arm+1]=r end
  local o={_o={"name",w.name,"slot",sl,"class",w.clist,"missions",#w.ms,"builds",builds}}
  if w.tot.h>0 then local by={_o={}};local T=w.tot
   for _,a in ipairs(ARMX)do local x=w.d[a[1]];if x then line(a[2],x);local b=by._o;b[#b+1]=a[2]:lower();b[#b+1]={_o={"hits",int(x.h),"damage",int(x.t),"useful_per_hit",int(useful_per(x)),"overkill_pct",overkill_share(x)and f1(overkill_share(x))or NULL}}end end
   line("All",T);local ms={_o={"hits",int(T.h),"damage",int(T.t),"useful",int(T.u),"overkill",int(T.o),"useful_per_hit",int(useful_per(T)),"by_armour",by}}
   if w.left>0 then local m=ms._o;m[#m+1]="left_out";m[#m+1]={{_o={"missions",w.left,"reason","No hits were logged for it."}}}end
   local q=o._o;q[#q+1]="measured";q[#q+1]=ms
  else local r={};for i,v in ipairs(row)do r[i]=v end;for _=1,7 do r[#r+1]=""end;r[#r+1]=nt;arm[#arm+1]=r;local q=o._o;q[#q+1]="measured";q[#q+1]=NULL;q[#q+1]="measured_note";q[#q+1]=nt end
  local best={};for _,b in ipairs(w.blist)do best[#best+1]=b;b.g=b.e:find("^Lt ")and "lieutenant"or group[b.e]or "other"end
  table.sort(best,function(a,b)if a.g~=b.g then return order[a.g]<order[b.g]end;return a.v>b.v end)
  local big={_o={}}
  for _,b in ipairs(best)do local r=b.run
   ene[#ene+1]={w.name,sl,b.e,gname[b.g]or b.g,b.kind=="x"and "explosion"or b.kind=="xh"and "explosion hit"or "single hit",int(b.v),#b.pts,r and tracker:run_mission_name(r.context)or "",r and K.info(r).day or ""}
   local g=big._o;g[#g+1]=b.e..(b.kind=="x"and " (explosion)"or b.kind=="xh"and " (explosion hit)"or "");g[#g+1]=int(b.v)end
  local q=o._o;q[#q+1]="biggest_hit_by_enemy";q[#q+1]=big;ws[#ws+1]=o
 end
 return arm,ene,js
end
local function cut(view,s,size,w)
 if view:_w(s,size,F.medium)<=w then return s end;local lo,hi=0,#s
 while lo<hi do local m=math.floor((lo+hi+1)/2);if view:_w(s:sub(1,m).."…",size,F.medium)<=w then lo=m else hi=m-1 end end
 while lo>0 and s:byte(lo+1)and s:byte(lo+1)>=128 and s:byte(lo+1)<192 do lo=lo-1 end;return s:sub(1,lo).."…"
end
local FMTS={{"arm","By Armour (CSV)"},{"ene","By Enemy (CSV)"},{"json","Everything (JSON)"}}
local function export_button(view,cv)
 local x,y=D.right-254,D.top;local on=view.io_exporting
 view:_ctl(cv,"base",x,y,254,34,function()view.io_exporting=not on or nil end,{open=on})
 cv:rect(x+18,y+10,2,9,C.value,true);cv:chevron(x+14,y+14,"down",8,C.value);cv:rect(x+13,y+22,12,2,C.value,true)
 cv:text("Export Data Sheet",x+34,y,212,34,16,C.value)
end
-- the export sheet, drawn in the page area in place of the cards: format, scope, file name, a preview and Save
local function export(view,popup,list,one,tracker)
 local special=one and special_mode(view,one.key)or "all"
 local cohort=view.io_soulblaze_cohort or "all"
 local soul_only=#list==1 and list[1].slot=="soulblaze"
 local dot_only=#list==1 and DOT_NAMES[list[1].slot]
 local enemy_available=(special=="all"or special=="regular"and one and one.slot=="ranged")and not dot_only
 local fmt=view.io_exp_fmt or "arm"
 if fmt=="ene"and not enemy_available then fmt="arm"end
 local ek=fmt.."|"..(one and one.key or "s:"..tostring(view.io_weap_slot or "all"))
 local cache=view.io_wcache and view.io_wcache.exp or {};local hit=cache[ek];local text,rows
 if hit then text,rows=hit[1],hit[2]
 else local arm,ene,js=sheet(view,list,tracker)
  if fmt=="json"then text=json(js,"");rows=#list==1 and "1 Weapon"or ""
  else local t=fmt=="arm"and arm or ene;local out={};for i,r in ipairs(t)do local c={};for j,v in ipairs(r)do c[j]=csv(v)end;out[i]=table.concat(c,",")end;text=table.concat(out,"\n");rows=(#t-1).." Rows"end
  cache[ek]={text,rows}
 end
 local slug=one and (one.name:lower():gsub("[^a-z0-9]+","_"):gsub("^_",""):gsub("_$",""))or "weapons"
 if special~="all"and not dot_only then slug=slug.."_"..special end
 if cohort~="all"and (soul_only or not one and (view.io_weap_slot or "all")=="all")then
  slug=slug.."_inferno_"..cohort
 end
 local fname="information_overload_"..slug..(fmt=="json"and ".json"or "_"..(fmt=="arm"and "armour"or "enemies")..".csv")
 local bx,by,bw,bh=D.left,D.sheet,D.width,D.bottom-D.sheet;local ix,iw=bx+36,bw-72
 view:_card(popup,bx,by,bw,bh,view:_fit("Export Data Sheet"..(one and ": "..one.name or ""),20,iw-20))
 local x,y=ix,by+56
 for _,f in ipairs(FMTS)do if f[1]~="ene"or enemy_available then local fw=view:_w(f[2],14)+24;local on=f[1]==fmt
  popup.z=3;popup:rect(x,y,fw,32,on and C.fill_s or C.fill);popup.z=4;popup:edges(x,y,fw,32,1,on and C.sel or C.frame)
  popup:text(f[2],x,y,fw,32,14,on and C.gold_hi or C.label,"center");if not on then view:_hit("base",x,y,fw,32,function()view.io_exp_fmt=f[1]end,{bg=C.fill_h})end;x=x+fw-1 end end
 local mode,diff,patch=scope_of(view);local meta={}
 for _,s in ipairs({rows,#list~=1 and #list.." Weapons"or ""})do if s~=""then meta[#meta+1]=s end end;meta[#meta+1]=mode..", "..diff..", "..(view.scope.all_patches and patch or "Patch "..patch)
 popup:text(view:_fit(table.concat(meta," · "),14,ix+iw-x-14),x+14,y,ix+iw-x-14,32,14,C.muted)
 popup:text(view:_fit(fname,14,iw),ix,by+98,iw,22,14,C.gold)
 local py,ph=by+124,bh-124-90;popup.z=3;popup:rect(ix,py,iw,ph,rgba(0,0,0,.45));popup.z=4;popup:edges(ix,py,iw,ph,1,C.frame)
 local n,p=0,1;while n<math.floor((ph-16)/20)and p<=#text do local e=text:find("\n",p,true)or #text+1;local l=text:sub(p,e-1);p=e+1
  if l~=""then popup:text(cut(view,l,13,iw-26),ix+12,py+8+n*20,iw-24,20,13,C.value,"left",F.medium)end;n=n+1 end
 popup:text("Saved next to the match files, for a breakpoint calculator or a spreadsheet. Only measured numbers go in.",ix,py+ph+8,iw,22,14,C.muted)
 local yb=by+bh-54
 view:_ctl(popup,"base",bx+bw-24-214,yb,120,34,function()view.io_exporting=nil end);popup:text("Cancel",bx+bw-24-214,yb,120,34,16,C.value,"center")
 view:_ctl(popup,"base",bx+bw-24-86,yb,86,34,function()
  local st=mod.io_storage;local ok,wrote=false,false;if st and st.a and st.a.write then ok,wrote=pcall(st.a.write,fname,text);if not ok then mod:error("I/O data sheet: %s",tostring(wrote))end end
  if ok and wrote then view.io_exporting=nil;mod.io_notify("Data Sheet Saved.")else mod.io_notify("The data sheet could not be saved.")end
 end,{sel=true});popup:text("Save",bx+bw-24-86,yb,86,34,16,C.gold_hi,"center")
end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 view:_scope(cv,popup,m,true)
 if view.io_params and view.io_params.weapon then view.io_weap=view.io_params.weapon;view.io_weap_from=nil;view.io_weap_from_tab=nil;view.io_weap_class=nil;view.io_params.weapon=nil end
 local s=view.scope;local active=special_mode(view,view.io_weap)
 local ck=table.concat({active,view.io_soulblaze_cohort or "all",view:_revision(),#(tracker.data.run_history or {}),tostring(s.mode),tostring(s.diff),tostring(s.patch),tostring(s.all_patches),active~="all"and view.io_weap or "",view.io_weap_class or "all"},"|")
 local wcs=mod.io_wcache or setmetatable({},{__mode="k"});mod.io_wcache=wcs
 local wc=view.io_wcache;if wc==nil and not view.io_wheld then wc=wcs[tracker.data]end
 if not wc or wc.key~=ck then view.io_wcache=nil
  -- match files not read yet are read one a draw, so a cold page never reads them all at once
  if not Slots.warm(K.scoped(view))then view.io_dirty=true;view.io_crumbs={{"Weapons"}};view:_card(cv,D.left,D.sheet,D.width,92,"Reading Missions");return end
  local list,used=build(view)
  wc={key=ck,list=list,used=used,exp={}}
  if active=="all"and (view.io_soulblaze_cohort or "all")=="all"and (view.io_weap_class or "all")=="all"then wcs[tracker.data]=wc end end
 view.io_wcache=wc;view.io_wheld=true
 local list=wc.list
 local reset=function()if view.scroll then view.scroll.weapons=0 end end
 local function all()view.io_weap=nil;view.io_weap_from=nil;view.io_weap_from_tab=nil end
 local w;if view.io_weap then for _,x in ipairs(list)do if x.key==view.io_weap then w=x end end end
 local function filter(id,x,width,label,choices,value,pick)
  local options,selected={}
  for _,choice in ipairs(choices)do
   options[#options+1]={value=choice[1],current=value,label=choice[2]}
   if choice[1]==value then selected=choice[2]end
  end
  K.dd(view,cv,popup,id,x,D.row2,width,label,selected,options,function(v)pick(v);reset()end,true)
 end
 local function class_filter(key)
  local current=view.io_weap_class or "all"
  local classes={}
  for cls,keys in pairs(wc.used)do
   local count=0
   for weapon_key in pairs(keys)do if weapon_key:find(":",1,true)then count=count+1 end end
   if (key and keys[key])or (not key and next(keys))or cls==current then
    classes[#classes+1]={value=cls,current=current,label=CN[cls]or cls,n=not key and tostring(count)or nil}
   end
  end
  if current~="all"and not wc.used[current]then
   classes[#classes+1]={value=current,current=current,label=CN[current]or current,n=not key and "0"or nil}
  end
  table.sort(classes,function(a,b)return a.label<b.label end)
  table.insert(classes,1,{value="all",current=current,label="All Classes"})
  K.dd(view,cv,popup,"weapon_class",D.right-265,D.row2,265,"Class:",CN[current]or "All Classes",classes,
   function(v)view.io_weap_class=v~="all"and v or nil;reset()end,true)
 end
 local function special_filter(x,w)
  filter("weapon_special",x,265,"Hits:",w.slot=="ranged"and RANGED_SPECIAL or SPECIAL,special_mode(view,w.key),function(v)view.io_weap_special=v;view.io_weap_special_key=w.key end)
 end
 local draw,elist
 if view.io_weap and not w then
  local name=BLITZ_NAMES[view.io_weap]or (view.io_weap:gsub("^%a+:",""))
  view.io_crumbs={{"Weapons",all},{name}}
  class_filter(view.io_weap)
  local cls=CN[view.io_weap_class]
  draw=function(y)view:_card(cv,X,y,W,136,"Not Used "..(cls and "By "..cls.." "or "").."In "..(view.scope.mode=="havoc"and "Havoc"or "Non-Havoc"),name)
   view:_ctl(cv,"base",X+36,y+56,220,34,all);cv:text("All Weapons",X+36,y+56,220,34,16,C.value,"center")end
 elseif w then
  local tab=view.io_weap_tab;local label;for _,t in ipairs(DTABS)do if t[1]==tab then label=t[2]end end;if not label then tab,label="hit","Per Hit";view.io_weap_tab=tab end
  local soul=w.slot=="soulblaze"
  local selected=special_mode(view,w.key)
  local filtered=selected=="special"or w.slot~="ranged"and selected=="regular"
  local dot=DOT_NAMES[w.slot]
  local tabs=dot and {DTABS[1]}or w.slot=="blitz" and {DTABS[1],DTABS[2]}or filtered and {DTABS[1],DTABS[3]}or DTABS
  if dot or (filtered and tab=="enemy")or (w.slot=="blitz"and tab=="bless")then tab,label="hit","Per Hit";view.io_weap_tab=tab end
  K.tabs(view,cv,tabs,tab,function(v)view.io_weap_tab=v;reset()end)
  if soul then
   filter("soulblaze_loadout",D.right-840,300,"Staff:",INFERNO,view.io_soulblaze_cohort or "all",function(v)view.io_soulblaze_cohort=v end)
  elseif has_special(w)then special_filter(D.right-805,w)end
  class_filter(w.key)
  export_button(view,cv);elist={w}
  local from=view.io_weap_from~=w.key and view.io_weap_from
  -- the weapon a link came from stands above this one, so the step up goes back to it on the tab the link was on
  if from then local ft=view.io_weap_from_tab
   view.io_crumbs={{"Weapons",function()all();reset()end},{(from:gsub("^%a+:","")),function()all();view.io_weap,view.io_weap_tab=from,ft;reset()end},{w.name},{label}}
  else view.io_crumbs={{"Weapons",function()all();reset()end},{w.name,tab~="hit"and function()view.io_weap_tab="hit"end or nil},{label}}end
  draw=function(y)if tab=="enemy"then enemy_tab(view,cv,w,y,tracker)elseif tab=="bless"then bless_tab(view,cv,w,y,list)else hit_tab(view,cv,w,y,tracker)end end
 else
  local lt=view.io_weap_list=="compare"and "compare"or "cards";local slot=view.io_weap_slot or "all"
  local counts={all=0}
  for _,x in ipairs(list)do
   if not DOT_NAMES[x.slot]or x.tot.h>0 then counts[x.slot]=(counts[x.slot]or 0)+1;counts.all=counts.all+1 end
  end
  if DOT_NAMES[slot]and not counts[slot]then slot="all";view.io_weap_slot=slot end
  local shown={};for _,x in ipairs(list)do if (slot=="all"or x.slot==slot)and (not DOT_NAMES[x.slot]or x.tot.h>0)then shown[#shown+1]=x end end
  K.tabs(view,cv,{{"cards","Weapons",tostring(#shown)},{"compare","Compare"}},lt,function(v)view.io_weap_list=v;reset()end)
  local opts={{value="all",current=slot,label="All Slots",n=tostring(counts.all)},
   {value="melee",current=slot,label="Melee",n=tostring(counts.melee or 0)},
   {value="ranged",current=slot,label="Ranged",n=tostring(counts.ranged or 0)}}
  for _,dot in ipairs(DOTS)do
   if counts[dot[1]]then opts[#opts+1]={value=dot[1],current=slot,label=dot[2],n=tostring(counts[dot[1]])}end
  end
  local sl=slot=="all"and "All Slots"or DOT_NAMES[slot]or SLOTN[slot]
  class_filter()
  K.dd(view,cv,popup,"wslot",D.right-445,D.row2,170,"Slot:",sl,opts,function(v)view.io_weap_slot=v;reset()end,true);export_button(view,cv);elist=shown
  view.io_crumbs={{"Weapons",lt=="compare"and function()view.io_weap_list="cards"end or nil},{lt=="compare"and "Compare"or "All Weapons"}}
  draw=function(y)
   if #shown==0 then view:_card(cv,X,y,W,92,view.io_weap_class and view.io_weap_class~="all"and "No Weapon Data For This Class In This Scope"or "No Weapon Data In This Scope");return end
   if lt=="compare"then compare(view,cv,shown,y)else cards(view,cv,shown,highlights(view,cv,shown,y))end
  end
 end
 if elist and view.io_exporting then local c=view.io_crumbs;local last=c[#c];c[#c]={last[1],function()view.io_exporting=nil end};c[#c+1]={"Export Data Sheet"}
  local fine,e=pcall(export,view,cv,elist,w,tracker);if not fine then view.io_exporting=nil;mod:error("I/O export: %s",tostring(e))end;return end
 view:_sheet(cv,D.sheet)
 draw(D.sheet)
 view:_sheet_end(cv)
end
