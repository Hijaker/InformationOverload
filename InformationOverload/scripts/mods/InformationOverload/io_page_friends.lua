-- Information Overload: Friends, your record with Steam friends and the players you track.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local P=mod:io_dofile(base.."io_data_people")
local C,F=D.c,D.font
local L,R,W=D.left,D.col2,D.col
local function empty(view,cv,tracked)
 local lines={"Steam friends and players you track show up here after a mission together, with their own records, attacks, classes and lethality."}
 local h=110+(tracked>0 and 36 or 0)
 view:_card(cv,D.left,D.row2,D.width,h,"No Friend Stats Yet");cv.z=5
 cv:text(lines[1],136,D.row2+40,1120,24,16,C.label,"left",F.medium)
 local a="To track someone, open a mission from Match History and press";local aw=view:_w(a,16,F.medium)
 cv:text(a,136,D.row2+64,aw+6,24,16,C.label,"left",F.medium);local kw=view:_w("Track",14)+14
 cv.z=5;cv:edges(136+aw+6,D.row2+65,kw,22,1,C.frame);cv:text("Track",136+aw+6,D.row2+65,kw,22,14,C.value,"center")
 cv:text("next to their name.",136+aw+12+kw,D.row2+64,400,24,16,C.label,"left",F.medium)
 if tracked>0 then cv:text(P.plural(tracked,"player").." tracked. Their stats start with the next mission together.",136,D.row2+100,1120,24,16,C.label,"left",F.medium)end
end
-- chips laid from the left, wrapping at the right: where each sits and how many fit in two rows
local function lay(ws)local tx,ty,at=D.left,D.row2,{}
 for i,w in ipairs(ws)do if tx+w>D.right then if ty>D.row2 then return at,i-1 end;tx,ty=D.left,ty+40 end;at[i]={tx,ty};tx=tx+w+6 end
 return at,#ws
end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 view:_scope(cv,popup,m,nil,true)
 local s=view.scope
 local list,tracked=P.friends(tracker,s.patch,s.mode)
 if #list==0 then view.io_crumbs={{"Friends"}};empty(view,cv,tracked);return end
 local f=list[1];for _,x in ipairs(list)do if x.id==view.io_friend then f=x end end;view.io_friend=f.id
 view.io_crumbs={{"Friends",f~=list[1]and function()view.io_friend=list[1].id end or nil},{f.name}}
 local function pick(id)view.io_friend=id;if view.scroll then view.scroll.friends=0 end end
 local ws,si={},1;for i,x in ipairs(list)do ws[i]=math.min(260,view:_w(x.name,16)+28);if x==f then si=i end end
 local at,fit=lay(ws);local chips,cw,rest=list,ws
 -- past two rows the last chip is +N More, listing the rest; a friend picked from them takes the last name chip
 if fit<#list then
  for k=fit,1,-1 do chips,cw={},{};for i=1,k do chips[i],cw[i]=list[i],ws[i]end;if si>k then chips[k],cw[k]=f,ws[si]end
   cw[k+1]=view:_w("+"..(#list-k).." More",16)+28;at,fit=lay(cw);if fit>k then break end end
  local on={};for _,x in ipairs(chips)do on[x]=true end;rest={};for _,x in ipairs(list)do if not on[x]then rest[#rest+1]=x end end
 end
 for i,x in ipairs(chips)do local tx,ty,w,sel=at[i][1],at[i][2],cw[i],x==f
  view:_ctl(cv,"base",tx,ty,w,34,function()pick(x.id)end,{sel=sel});cv:text(view:_fit(x.name,16,w-20),tx,ty,w,34,16,sel and C.gold_hi or C.value,"center")end
 local last=at[#at]
 if rest then local tx,ty,w,open=last[1],last[2],cw[#cw],view.dd=="friends"
  view:_ctl(cv,"base",tx,ty,w,34,function()view.dd=not open and "friends"or nil end,{open=open});cv:text("+"..#rest.." More",tx,ty,w,34,16,C.value,"center")
  if open then local opts={};for i,x in ipairs(rest)do opts[i]={value=x.id,label=x.name}end;view:_options(popup,tx,ty+38,260,opts,pick)end
 end
 local y0=last[2]+44
 view:_sheet(cv,y0)
 local y=y0;local h1=52+#f.info*26;local h2=52+#f.clutch*26;local h=math.max(h1,h2)
 view:_card(cv,L,y,W,h,view:_fit(f.name,20,W-150),"With You");view:_card(cv,R,y,W,h,"Clutches");cv.z=5
 view:_rows(cv,L,y+45,W,f.info);view:_rows(cv,R,y+45,W,f.clutch);y=y+h+10
 local E=f.enemies
 h=52+math.max(1,#E)*30+(#E>0 and 6 or 0)
 view:_card(cv,L,y,D.width,h,"What Downed Them");cv.z=5
 local ry=y+45
 if #E==0 then cv:text("Nothing has downed them in a mission with you.",L+36,ry,800,26,14,C.muted,"left",F.medium)end
 for _,e in ipairs(E)do cv:text(e.n,L+36,ry,500,30,16,C.value)
  local how={};if (e.down or 0)>0 then how[#how+1]="Downed "..P.times(e.down)end;if (e.death or 0)>0 then how[#how+1]="Killed "..P.times(e.death)end
  if #how==0 then how[1]="Caught "..P.times(e.count)end
  cv:text(table.concat(how,", "),L+D.width-413,ry,400,30,14,C.muted,"right",F.medium);cv:rect(L+25,ry+29,D.width-38,1,C.line,true);ry=ry+30 end
 view:_sheet_end(cv)
end
