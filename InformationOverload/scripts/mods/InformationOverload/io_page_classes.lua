-- Information Overload: the Classes page, one class at a time.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local K=mod:io_dofile(base.."io_data_career")
local X=mod:io_dofile(base.."io_class_tabs")
local C,DASH,commas=D.c,K.dash,Overview.commas
local TABS={{"overview","Overview"},{"damage","Damage"},{"streaks","Streaks"}}
local MORE={{"blitz","Blitz",2},{"pbb","PBB"},{"blo","BLO"},{"cw","Crystalline Will"}}
local DETAILS={{"overall","Overall"},{"armour","By Armour"},{"enemy","By Enemy"},{"weapon","By Weapon"}}
local L,R,W=D.left,D.col2,D.col
local function linked(view,list)local out={};for _,r in ipairs(list)do out[#out+1]={r[1],r[2],fn=r.run and K.open_run(view,r.run)or nil}end;return out end
local function chart(view,cv,y,name,mode,bars)
 local x,w=D.left,D.width;view:_card(cv,x,y,w,221,"Missions As "..name,mode.." · Oldest First")
 local lw=view:_w("Compare Classes",14)+35;local lx=x+w-13-lw
 view:_ctl(cv,"base",lx,y+13,lw,26,function()view.io_params=view.io_params or {};view.io_params.trends="classes";view:_go("trends")end,{hv={bg=C.fill_s,edge=C.sel}})
 cv:text("Compare Classes",lx+10,y+13,lw,26,14,C.value);cv:chevron(lx+lw-19,y+22,"right",8,C.value)
 local n=#bars;local x0,top,zone=x+25,y+67,90;local axis=top+zone;local sw=math.min(64,(w-50)/math.max(n,1));local bw=math.min(24,sw*.62);local max=0
 for _,b in ipairs(bars)do if b.damage and b.damage>max then max=b.damage end end
 cv:rect(x0,axis,sw*n,1,C.axis,true);local step=math.max(1,math.ceil(44/sw));local peak
 for i,b in ipairs(bars)do local cx=x0+sw*(i-.5)
  if b.damage and max>0 then local h=math.max(1,zone*b.damage/max);cv:rect(cx-bw/2,axis-h,bw,h,b.win and C.gold or C.bad,true);if b.damage==max and not peak then peak={cx,axis-h}end
  else cv:rect(cx-4,axis-4,8,2,C.muted,true)end
  if (n-i)%step==0 then cv:text(b.date,cx-30,axis+4,60,18,14,C.muted,"center")end
  if b.id then view:_hit("base",x0+sw*(i-1),top-4,sw,zone+6,K.open_run(view,b.id),{bg=C.row_h})end
 end
 if peak then local cx=math.min(math.max(peak[1],x0+30),x0+sw*n-30);cv:text(Overview.compact(max),cx-60,peak[2]-21,120,16,14,C.value,"center")end
 local ky=y+193;cv:rect(x+36,ky+3,12,12,C.gold,true);cv:text("Win",x+55,ky,60,18,14,C.label)
 local lx2=x+55+view:_w("Win",14)+16;cv:rect(lx2,ky+3,12,12,C.bad,true);cv:text("Loss",lx2+19,ky,60,18,14,C.label)
 cv:text("Bar Height: Your Damage",lx2+19+view:_w("Loss",14)+16,ky,300,18,14,C.label)
end
local function overview(view,cv,tracker,cls,name)
 local m=K.class_overview(tracker,view.scope,cls)
 local mode=Overview.mode_names[view.scope.mode]or DASH;local y=D.sheet
 if #m.bars>0 then chart(view,cv,y,name,mode,m.bars);y=y+231 end
 local col={y,y}
 local function place(side,title,sub,rows)if #rows==0 then return end;if side==nil then side=col[1]<=col[2]and 1 or 2 end
  local h=K.card(view,cv,side==1 and L or R,col[side],W,title,sub,rows);col[side]=col[side]+h+10 end
 place(1,"Results",mode,m.results)
 place(2,"Mission Bests","Both Modes",linked(view,m.bests))
 place(1,"Most Kills By Type In A Mission","Both Modes",linked(view,m.kills))
 place(2,"Bosses And Clutches",mode,m.other)
 place(nil,"Hyper-Critical",nil,m.hyper)
 place(nil,"Perils Of The Warp",nil,m.perils)
end
local function damage(view,cv,popup,tracker,cls)
 local m=K.class_damage(tracker,view.scope,cls)
 local has={overall=true,armour=#m.armour>0,enemy=#m.enemy>0,weapon=#m.weapon>0};local opts={}
 for _,d in ipairs(DETAILS)do if has[d[1]]then opts[#opts+1]={value=d[1],label=d[2]}end end
 local det=has[view.io_cls_det or ""]and view.io_cls_det or "overall";local label="Overall";for _,o in ipairs(opts)do if o.value==det then label=o.label end end
 K.dropdown(view,cv,popup,"io_cdet",D.right-280,D.row2,280,"Detail:",label,det,opts,function(v)view.io_cls_det=v;if view.scroll then view.scroll[view.page]=0 end end)
 view:_sheet(cv,D.sheet);local y=D.sheet
 local function fmt(r)return r and commas(r.value)or DASH end
 if det=="overall"then
  for _,k in ipairs(K.kinds)do local r=m.overall[k[1]]
   if r then local rows={{"Damage",commas(r.value),big=true},{"Class",Overview.class_names[r.class]or DASH}}
    if r.weapon then rows[#rows+1]={"Weapon",K.weapon(r.weapon)}end;if r.enemy then rows[#rows+1]={"Enemy",tostring(r.enemy)}end
    y=y+K.card(view,cv,D.left,y,D.width,k[2],nil,rows,r.run and K.open_run(view,r.run)or nil)+10
   end
  end
  if y==D.sheet then view:_card(cv,D.left,y,D.width,92,"No Damage Records Yet")end
 elseif det=="armour"then
  local rows={};for _,a in ipairs(m.armour)do rows[#rows+1]={a.label,fmt(a.rec.single_hit),fmt(a.rec.melee_cleave),fmt(a.rec.explosive_hit)}end
  K.table(view,cv,D.left,y,D.width,{{"Armour"},{K.kinds[1][2],760},{K.kinds[2][2],1020},{K.kinds[3][2],D.right-10}},rows)
 elseif det=="enemy"then
  local rows,last={},nil
  for _,e in ipairs(m.enemy)do if e.group~=last then rows[#rows+1]={grp=e.group};last=e.group end;local h=e.hit
   rows[#rows+1]={e.label,commas(h.damage),Overview.class_names[h.class]or DASH,h.weapon and K.weapon(h.weapon)or DASH,fn=h.run_id and K.open_run(view,h.run_id)or nil}end
  K.table(view,cv,D.left,y,D.width,{{"Enemy"},{"Biggest Hit",680},{"Class",720,"left",150},{"Weapon",890,"left",D.right-900}},rows)
 else
  local rows,last={},nil
  for _,w in ipairs(m.weapon)do local cat=w.cat=="melee"and "Melee"or w.cat=="ranged"and "Ranged"or "Other";if cat~=last then rows[#rows+1]={grp=cat};last=cat end
   rows[#rows+1]={K.fit(view,w.label,16,480),fmt(w.rec.single_hit),fmt(w.rec.melee_cleave),fmt(w.rec.explosive_hit)}end
  K.table(view,cv,D.left,y,D.width,{{"Weapon"},{K.kinds[1][2],760},{K.kinds[2][2],1020},{K.kinds[3][2],D.right-10}},rows)
 end
 view:_sheet_end(cv)
end
-- the extra tabs' figures, kept until the model is rebuilt or the scope or class changes
local function extras(view,tracker,cls)
 local s,c=view.scope,view.io_cls_x
 if c and c.model==view.model and c.patch==s.patch and c.mode==s.mode and c.cls==cls then return c.x end
 local ok,x=pcall(X.build,tracker,s.patch,s.mode,cls);if not ok then mod:error("I/O class tabs: %s",tostring(x));x={}end
 view.io_cls_x={model=view.model,patch=s.patch,mode=s.mode,cls=cls,x=x};return x
end
local DRAW={}
function DRAW.blitz(view,cv,list)
 local hit,kills=false,false;for _,b in ipairs(list)do hit=hit or b.hit~=nil;kills=kills or b.game~=nil or b.total~=nil end
 local keys={};if hit then keys[#keys+1]={"hit","Biggest Explosion"}end;if kills then keys[#keys+1]={"game","Most Kills In A Mission"};keys[#keys+1]={"total","Total Kills"}end
 local edges,cols,rows={760,1020,D.right-10},{{"Blitz"}},{};for i,k in ipairs(keys)do cols[i+1]={k[2],edges[3-#keys+i]}end
 for _,b in ipairs(list)do local r={b.label,fn=b.run and K.open_run(view,b.run)or nil};for i,k in ipairs(keys)do r[i+1]=b[k[1]]and commas(b[k[1]])or nil end;rows[#rows+1]=r end
 K.table(view,cv,D.left,D.sheet,D.width,cols,rows)
end
function DRAW.pbb(view,cv,p)
 local top=p.value and {{"Most Ammo Returned In A Mission, Any Weapon",commas(p.value),fn=p.run and K.open_run(view,p.run)or nil}}or {}
 local rows={};for _,w in ipairs(p.list)do rows[#rows+1]={K.fit(view,w.label,16,700),w.value and commas(w.value)or nil,fn=w.run and K.open_run(view,w.run)or nil}end
 local y=D.sheet;local ty=y+45+K.rows_h(top);local h=ty-y+(#rows>0 and 30+32*#rows or 0)+10
 view:_card(cv,D.left,y,D.width,h,"Point-Blank Barrage");K.rows(view,cv,D.left,y+45,D.width,top)
 if #rows>0 then K.table(view,cv,D.left+26,ty,D.width-39,{{"Weapon"},{"Most Ammo Returned In A Mission",D.right-13}},rows)end
end
function DRAW.blo(view,cv,cards)
 local y=D.sheet
 for _,c in ipairs(cards)do y=y+K.card(view,cv,D.left,y,D.width,c.label,nil,c.rows)+10 end
end
function DRAW.cw(view,cv,rows)K.card(view,cv,L,D.sheet,W,"Crystalline Will",Overview.mode_names[view.scope.mode],rows)end
return function(view,cv,popup)
 local tracker=view:_tracker();local model=view.model
 if not tracker or not model or model.empty then K.empty(view,cv);return end
 view:_scope(cv,popup,model,nil,true);local s=view.scope
 if view.io_params and view.io_params.class then view.io_cls=view.io_params.class;view.io_params.class=nil end
 local played=K.played(tracker,s.patch,s.mode)
 if #played==0 then view.io_crumbs={{"Classes"}};view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 local cur=played[1];local opts={}
 for _,c in ipairs(played)do opts[#opts+1]={value=c.id,label=c.name,n=c.games..(c.games==1 and " Game"or " Games")};if c.id==view.io_cls then cur=c end end
 local cls,name=cur.id,cur.name
 K.dropdown(view,cv,popup,"io_ccls",D.right-250,D.top,250,"Class:",name,cls,opts,function(v)view.io_cls=v;if view.scroll then view.scroll[view.page]=0 end end)
 local x=extras(view,tracker,cls);local list={TABS[1],TABS[2]}
 for _,t in ipairs(MORE)do if x[t[1]]then list[#list+1]=t end;if t[3]then list[#list+1]=TABS[3]end end
 local tab=view.io_cls_tab or "overview";local tl;for _,t in ipairs(list)do if t[1]==tab then tl=t[2]end end;if not tl then tab,tl="overview","Overview"end
 local function set(v)view.io_cls_tab=v;if view.scroll then view.scroll[view.page]=0 end end
 K.tabs(view,cv,list,tab,set)
 local up=tab~="overview"and function()set("overview")end or nil
 view.io_crumbs={{"Classes",up},{name,up},{tl}}
 if tab=="damage"then damage(view,cv,popup,tracker,cls)
 elseif DRAW[tab]then view:_sheet(cv,D.sheet);DRAW[tab](view,cv,x[tab]);view:_sheet_end(cv)
 elseif tab=="streaks"then
  local mine,team=K.streaks(tracker,s.patch,s.mode,cls)
  view:_sheet(cv,D.sheet);K.streak_table(view,cv,D.sheet,mine,team);view:_sheet_end(cv)
 else view:_sheet(cv,D.sheet);overview(view,cv,tracker,cls,name);view:_sheet_end(cv)end
end
