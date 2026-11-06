-- Information Overload: Team, the bosses, clutches and fun stats of everyone you played with.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local P=mod:io_dofile(base.."io_data_people")
local C=D.c
local TABS={{"bosses","Bosses"},{"clutches","Clutches"},{"fun","Fun"}}
local function table_rows(view,cv,y,h1,h2,rows)
 local x,w=D.left,D.width
 cv:text(h1,x+10,y,400,30,14,C.muted);cv:text(h2,x+w-410,y,400,30,14,C.muted,"right");cv:rect(x,y+29,w,1,C.frame,true)
 for i,r in ipairs(rows)do local ry=y+30+(i-1)*32
  cv:text(r[1],x+10,ry,700,32,16,C.label);cv:text(r[2],x+w-410,ry,400,32,16,C.value,"right");cv:rect(x,ry+31,w,1,C.line,true)
 end
 return y+30+#rows*32
end
local function note(cv,x,y,text)cv:text(text,x,y,1100,24,14,C.muted,"left",D.font.medium)end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 view:_scope(cv,popup,m,nil,true)
 local s=view.scope;local mode=s.mode;local mn=mode=="havoc"and "Havoc"or "Non-Havoc"
 local t=P.team(tracker,s.patch,mode)
 view.io_team_tab=view.io_team_tab or "bosses";local tab=view.io_team_tab
 local name="Bosses";for _,e in ipairs(TABS)do if e[1]==tab then name=e[2]end end
 view.io_crumbs={{"Team",tab~="bosses"and function()view.io_team_tab="bosses"end or nil},{name}}
 local tx=100;for _,e in ipairs(TABS)do local w=view:_w(e[2],16)+28;local sel=tab==e[1]
  view:_ctl(cv,"base",tx,D.row2,w,34,function()view.io_team_tab=e[1];if view.scroll then view.scroll.team=0 end end,{sel=sel});cv:text(e[2],tx,D.row2,w,34,16,sel and C.gold_hi or C.value,"center");tx=tx+w+6 end
 view:_sheet(cv,D.sheet-2)
 local y=D.sheet-2;cv.z=5
 if tab=="bosses"then
  if #t.bosses==0 and #t.rituals==0 then view:_card(cv,D.left,y,D.width,92,"No Boss Kills Yet")
  else note(cv,102,y,"Bosses killed by your teams in "..mn.." missions.");y=y+30
   if #t.bosses>0 then y=table_rows(view,cv,y,"Boss","Killed",t.bosses)+10 end
   if #t.rituals>0 then y=table_rows(view,cv,y,"Ritual","Rituals Stopped",t.rituals)end
  end
 elseif tab=="clutches"then
  if #t.clutches==0 then view:_card(cv,D.left,y+2,D.width,92,"No Clutches Yet")
  else local col={D.sheet+2,D.sheet+2};local x2={D.left,D.col2}
   for i,p in ipairs(t.clutches)do local c=(i-1)%2+1;local h=52+#p.rows*26
    if c==1 and i>1 then local top=math.max(col[1],col[2]);col[1],col[2]=top,top end
    local cy=col[c];view:_card(cv,x2[c],cy,D.col,h,p.name);cv.z=5;view:_rows(cv,x2[c],cy+45,D.col,p.rows);col[c]=cy+h+10
   end
   y=math.max(col[1],col[2])
   if t.quiet>0 then note(cv,102,y,t.quiet.." other teammates have no clutch wins and are not listed.")end
  end
 else
  local x,w=D.left,D.width;local open=view.io_team_fun~=false;local items={}
  local function add(kind,a,b,c)items[#items+1]={kind,a,b,c}end
  if open then
   for _,r in ipairs(t.fun)do add("row",r[1],r[2],r[3])end
   add("head","Leave Abuse")
   if not t.named then local n=0;for _,e in ipairs(t.leave)do n=n+(tonumber(e[2]:match("^%d+"))or 0)end;add("row","Leaves To Escape",tostring(n));add("note","Names are hidden while Name Leave Abusers is off in Settings › Display.")
   elseif #t.leave==0 then add("note","No leave abuse recorded.")else for _,e in ipairs(t.leave)do add("row",e[1],e[2])end end
   add("head","Clutch By Bot")
   if #t.bots==0 then add("note","No clutches by bots recorded.")else for _,e in ipairs(t.bots)do add("row",e[1],e[2])end end
  end
  local h=52+26+14;for _,it in ipairs(items)do h=h+(it[1]=="head"and 31 or it[1]=="note"and 24 or 26)end
  view:_card(cv,x,y+2,w,h,"Fun","Team-Wide, Not Records");cv.z=5
  local ry=y+2+45
  view:_hit("base",x+25,ry,w-50,26,function()view.io_team_fun=not open end,{bg=C.row_h})
  cv:chevron(open and x+37 or x+39,open and ry+11 or ry+9,open and "down"or "right",open and 6 or 8,C.value);cv:text((open and "Hide"or "Show").." Fun Stats",x+52,ry,300,26,16,C.value)
  cv:text(#t.fun==1 and "1 Line"or #t.fun.." Lines",x+w-313,ry,300,26,14,C.muted,"right");ry=ry+26
  for _,it in ipairs(items)do
   if it[1]=="row"then if it[4]then view:_jump(cv,x+8,ry+2,P.open_run(view,it[4]))end
    cv:text(it[2],x+36,ry,700,26,16,C.label);cv:text(it[3],x+w-413,ry,400,26,16,C.value,"right");ry=ry+26
   elseif it[1]=="head"then cv:text(it[2],x+36,ry+5,300,26,16,C.gold);ry=ry+31
   else note(cv,x+36,ry,it[2]);ry=ry+24 end
  end
 end
 view:_sheet_end(cv)
end
