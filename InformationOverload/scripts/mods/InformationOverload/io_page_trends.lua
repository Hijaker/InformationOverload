-- Information Overload: Trends, the scope's missions as charts and tables.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_stats")
local G=mod:io_dofile(base.."enemy_grouping")
local E=mod:io_dofile(base.."enemy_catalog")
local Times=mod:io_dofile(base.."mission_times")
local C,KC,DASH,CN=D.c,K.c,K.dash,K.class_names
local TABS={{"results","Results"},{"damage","Damage"},{"kills","Kills"},{"deaths","Deaths"},{"times","Clear Times"},{"share","Team Share"},{"classes","Classes"}}
local X,W,CX,CW=D.left,D.width,D.left+25,D.width-50
local function name_of(tracker,r)return tracker:run_mission_name(r.context)end
local function result(r)return r.victory and "Victory"or "Defeat"end
local function vcard(view,cv,y,id,title,sub,chart_h,chart,tabled,jump)
 local tbl=K.view_of(view,id)=="table";local cols,rows
 if tbl then cols,rows=tabled()end
 local h=tbl and 46+K.table_h(rows)+14 or chart_h
 local left=K.card(view,cv,X,y,W,h,id,title,sub,jump)
 if tbl then K.table(view,cv,X+25,y+46,W-38,cols,rows)else chart(y,left)end
 return y+h+10
end
local function legend_right(view,cv,y,text)local w=view:_w(text,14);cv:text(text,X+W-13-w-4,y,w+4,18,14,C.label)end
local function hits(view,list,x0,sw,top,h,below)for i,r in ipairs(list)do local fn=K.open_run(view,r.id);view:_hit("base",x0+sw*(i-1),top,sw,h,fn,{bg=C.row_h});if below then view:_hit("base",x0+sw*(i-1),top+h,sw,below,fn)end end end
-- the shade under the win-rate line, in 1-unit columns merged where the line runs flat
local function area(cv,xa,sw,pts,yy,yB)
 local z=cv.z;cv.z=6;local xb=xa+sw*(#pts-1);local x,rx,rt=xa
 while x<xb do local w=math.min(1,xb-x);local f=(x+w/2-xa)/sw;local i=math.min(#pts-1,math.floor(f));local a=pts[i+1].rate;local t=yy(a+(pts[i+2].rate-a)*(f-i))
  if rt and math.abs(t-rt)>.5 then cv:rect(rx,rt,x-rx,yB-rt,C.gold,false,.09);rx=nil end
  if not rx then rx,rt=x,t end;x=x+w end
 if rx then cv:rect(rx,rt,xb-rx,yB-rt,C.gold,false,.09)end;cv.z=z
end
local function results(view,cv,ms,y,tracker)
 local n=#ms;local roll=view.io_trend_roll or 5;local won,wins,pts=0,0,{}
 for i,r in ipairs(ms)do local win=K.info(r).win;if win then won=won+1 end
  local a=roll>0 and math.max(1,i-roll+1)or 1;local w2=0;if roll>0 then for k=a,i do if K.info(ms[k]).win then w2=w2+1 end end else w2=won end;pts[i]={rate=w2/(i-a+1),win=win}end
 y=vcard(view,cv,y,"winrate","Win Rate Over Time",(view.scope.mode=="havoc"and "Havoc"or "Non-Havoc").." · "..K.plural(n,"Mission"),318,function(cy,left)
  if roll then K.seg(view,cv,left-8,cy+13,{{5,"Last 5"},{10,"Last 10"},{0,"All So Far"}},roll,function(v)view.io_trend_roll=v end)end
  K.legend(view,cv,X+25,cy+46,{{"ln",C.gold,roll>0 and "Win Rate Over The Last "..roll.." Missions"or "Win Rate Over Every Mission So Far"},{"sq",KC.win,"Win"},{"sq",KC.loss,"Loss"}})
  legend_right(view,cv,cy+46,won.." Of "..n.." Won · "..K.pc(won/n,0))
  local top=cy+70;local x0,x1=CX+52,CX+CW-50;local yT,yB,yChip=top+14,top+176,top+190;local sw=(x1-x0)/n
  local function yy(v)return yB-(yB-yT)*v end
  K.day_axis(cv,ms,x0,sw,yT-8,yB,top+230)
  K.axis_y(cv,x0,x1,yy,{0,.25,.5,.75,1},function(v)return math.floor(v*100+.5).."%"end)
  if n>1 then area(cv,x0+sw*.5,sw,pts,yy,yB)end
  for i,p in ipairs(pts)do local cx=x0+sw*(i-.5)
   if i>1 then cv:line(x0+sw*(i-1.5),yy(pts[i-1].rate),cx,yy(p.rate),2,C.gold)end
   cv:rect(cx-6,yChip,12,12,p.win and KC.win or KC.loss,true)
  end
  for i,p in ipairs(pts)do K.dot(cv,x0+sw*(i-.5),yy(p.rate),4,C.gold)end
  cv:text(K.pc(pts[n].rate,0),x0+sw*(n-.5)+10,yy(pts[n].rate)-9,60,18,14,C.value)
  hits(view,ms,x0,sw,yT-8,yB-yT+8,yChip+18-yB)
 end,function()
  local rows,w={},0;for i,r in ipairs(ms)do if K.info(r).win then w=w+1 end
   table.insert(rows,1,{K.date(r),name_of(tracker,r),CN[r.context.class]or DASH,result(r),{K.pc(w/i,0),w.." Of "..i},act=K.open_run(view,r.id)})end
  return {{"Date",10,"l"},{"Map",250,"l"},{"Class",600,"l"},{"Result",750,"l"},{"Win Rate So Far",W-48}},rows
 end)
 local first,last=K.info(ms[1]).day,K.info(ms[n]).day;local days=K.days(first,last);local per={};for _,d in ipairs(days)do per[d]={w=0,l=0}end
 for _,r in ipairs(ms)do local f=K.info(r);local d=per[f.day];if d then if f.win then d.w=d.w+1 else d.l=d.l+1 end end end
 return vcard(view,cv,y,"perday","Missions Per Day",nil,236,function(cy)
  K.legend(view,cv,X+25,cy+46,{{"sq",KC.win,"Wins"},{"sq",KC.loss,"Losses"}})
  local top=cy+70;local max=1;for _,d in ipairs(days)do max=math.max(max,per[d].w+per[d].l)end
  local nt,ticks=K.nice(max,math.min(max,4));local x0,x1=CX+52,CX+CW-12;local yT,yB=top+12,top+128;local sw=(x1-x0)/#days;local bw=math.min(24,sw*.55)
  local function scale(v)return (yB-yT)*v/nt end
  K.axis_y(cv,x0,x1,function(v)return yB-scale(v)end,ticks,function(v)return tostring(math.floor(v+.5))end)
  local lastx=-1e9
  for i,d in ipairs(days)do local cx=x0+sw*(i-.5)
   if cx-21>=lastx+5 then cv:text(K.dm(d),cx-30,top+141,60,18,14,C.muted,"center");lastx=cx+21 end
   K.stack(cv,cx-bw/2,yB,bw,{{per[d].w,KC.win},{per[d].l,KC.loss}},scale)
  end
 end,function()
  local rows={};for i=#days,1,-1 do local d=days[i];local p=per[d];if p.w+p.l>0 then rows[#rows+1]={K.dmy(d),tostring(p.w+p.l),tostring(p.w),tostring(p.l)}end end
  return {{"Day",10,"l"},{"Missions",500},{"Wins",800},{"Losses",W-48}},rows
 end)
end
local function damage(view,cv,ms,y,tracker)
 local rec,max,best,sum,n={},0,nil,0,0
 for i,r in ipairs(ms)do local f=K.info(r);if f.dmg then rec[#rec+1]=r;if not best or f.dmg>max then max=f.dmg;best=i end;if not f.fb then sum=sum+f.dmg;n=n+1 end end end
 if #rec==0 then return K.empty(view,cv,y,"No Damage Recorded Yet")end
 local avg=n>0 and sum/n or nil
 y=vcard(view,cv,y,"dmg","Damage Per Mission","Yours",352,function(cy)
  K.stats(view,cv,X+36,cy+46,{{"Most",K.exact(max)},{"Average",avg and K.exact(avg)or DASH,avg and "Over "..K.plural(n,"Mission")},{"Missions",tostring(#rec)}})
  K.legend(view,cv,X+25,cy+100,{{"sq",KC.win,"Most Damage"},{"sq",KC.bar,"Other Missions"},{"ln",KC.ref,"Average"}})
  local top=cy+124;local nt,ticks=K.nice(max*1.08,5);local x0,x1=CX+58,CX+CW-12;local yT,yB=top+14,top+186;local sw=(x1-x0)/#ms;local bw=math.min(24,sw*.6)
  local function yy(v)return yB-(yB-yT)*v/nt end
  K.day_axis(cv,ms,x0,sw,yT-6,yB,top+210);K.axis_y(cv,x0,x1,yy,ticks,K.tick)
  for i,r in ipairs(ms)do local v=K.info(r).dmg;local cx=x0+sw*(i-.5)
   if v then cv:rect(cx-bw/2,yy(v),bw,yB-yy(v),i==best and KC.win or KC.bar,true)else cv:rect(cx-4,yB-4,8,2,C.muted,true)end end
  if avg then cv:rect(x0,yy(avg),x1-x0,1,KC.ref,true)end
  local bx=x0+sw*(best-.5);cv:text(K.exact(max),math.max(x0,math.min(bx-80,x1-160)),yy(max)-27,160,18,14,C.gold_hi,"center")
  hits(view,ms,x0,sw,yT-6,yB-yT+6,8)
 end,function()
  local rows={};for i=#ms,1,-1 do local r=ms[i];local f=K.info(r);rows[#rows+1]={K.date(r),name_of(tracker,r),CN[r.context.class]or DASH,result(r),f.dmg and (f.fb and {K.exact(f.dmg),"Weapon Hits"}or K.exact(f.dmg))or {DASH,nil,C.muted},act=K.open_run(view,r.id)}end
  return {{"Date",10,"l"},{"Map",250,"l"},{"Class",600,"l"},{"Result",750,"l"},{"Damage",W-48}},rows
 end)
 local wait=K.warm(view,ms);local agg,with,tot={},0,0
 for _,r in ipairs(ms)do local a=K.info(r).armour;if a then with=with+1;for key,x in pairs(a)do local g=agg[key]or {t=K.ARM_NAME[key]or key,v=0,dmg=0,over=0,unc=x.unc};agg[key]=g;g.v=g.v+(x.unc and x.dmg or x.useful);g.dmg=g.dmg+x.dmg;g.over=g.over+x.over end end end
 local list={};for _,g in pairs(agg)do list[#list+1]=g;tot=tot+g.v end
 if #list==0 then return y end
 local top=0;for _,g in ipairs(list)do g.share=tot>0 and g.v/tot or 0;top=math.max(top,g.share)end
 table.sort(list,function(a,b)if a.unc~=b.unc then return b.unc end;return a.share>b.share end)
 return vcard(view,cv,y,"armour","Your Useful Damage By Armour","Overkill Left Out, "..(wait>0 and "Counting "..K.plural(wait,"More Mission")or K.plural(with,"Mission")),46+#list*28+14,function(cy)
  local x0,x1=CX+130,CX+CW-150
  for i,a in ipairs(list)do local yc=cy+46+(i-1)*28+14;local bx=x0+(x1-x0)*a.share/top
   cv:text(a.t,CX,yc-13,128,26,16,a.unc and C.muted or C.label);cv:rect(x0,yc-8,x1-x0,16,KC.track,true);cv:rect(x0,yc-8,math.max(1,bx-x0),16,a.unc and KC.bar or C.gold,true)
   local pw=view:_w(K.pc(a.share),14);cv:text(K.pc(a.share),bx+10,yc-9,pw+4,18,14,C.value);cv:text(K.mod(a.v),bx+18+pw,yc-9,100,18,14,C.muted)
  end
 end,function()
  local rows={};for _,a in ipairs(list)do rows[#rows+1]={a.unc and {a.t,"No Armour Split"}or a.t,K.pc(a.share),K.exact(a.v),a.unc and DASH or K.pc(a.dmg>0 and a.over/a.dmg or 0)}end
  return {{"Armour",10,"l"},{"Share",500},{"Useful Damage",800},{"Overkill %",W-48}},rows
 end)
end
local KT={{"mh","Melee Horde","k1"},{"rh","Ranged Horde","k2"},{"el","Elites","k3"},{"sp","Specials","k4"},{"bo","Bosses","k5"},{"no","No Type","bar"}}
local function kills(view,cv,ms,y,tracker)
 local with={};local untyped=false;for _,r in ipairs(ms)do local t=K.info(r).types;if t then with[#with+1]=r;if t.no>0 then untyped=true end end end
 if #with==0 then return K.empty(view,cv,y,"No Kills By Type Yet")end
 local kt={};for _,k in ipairs(KT)do if k[1]~="no"or untyped then kt[#kt+1]=k end end
 y=vcard(view,cv,y,"kills","Kills By Enemy Type",#with==#ms and "Every Mission"or #with.." Of "..#ms.." Missions Have Types",312,function(cy)
  local items={};for _,k in ipairs(kt)do items[#items+1]={"sq",KC[k[3]],k[2]}end;K.legend(view,cv,X+25,cy+46,items)
  local top=cy+70;local max,bi=0,1;for i,r in ipairs(with)do local a=K.info(r).types.all;if a>max then max=a;bi=i end end
  local nt,ticks=K.nice(max*1.08,4);local x0,x1=CX+52,CX+CW-12;local yT,yB=top+14,top+200;local sw=(x1-x0)/#with;local bw=math.min(24,sw*.6)
  local function scale(v)return (yB-yT)*v/nt end
  K.day_axis(cv,with,x0,sw,yT-6,yB,top+224);K.axis_y(cv,x0,x1,function(v)return yB-scale(v)end,ticks,K.tick)
  for i,r in ipairs(with)do local t=K.info(r).types;local parts={};for _,k in ipairs(KT)do parts[#parts+1]={t[k[1]],KC[k[3]]}end;K.stack(cv,x0+sw*(i-.5)-bw/2,yB,bw,parts,scale)end
  local bx=x0+sw*(bi-.5);cv:text(K.exact(max),math.min(bx-60,x1-120),yB-scale(max)-27,120,18,14,C.value,"center")
  hits(view,with,x0,sw,yT-6,yB-yT+6,8)
 end,function()
  local cols={{"Date",10,"l"},{"Map",90,"l",max=300}};local step=(W-48-430)/#kt
  for i,k in ipairs(kt)do cols[#cols+1]={k[2],math.floor(430+step*(i-.5))}end;cols[#cols+1]={"All",W-48}
  local rows={};for i=#with,1,-1 do local r=with[i];local t=K.info(r).types;local row={K.dm(K.info(r).day),name_of(tracker,r),act=K.open_run(view,r.id)};for _,k in ipairs(kt)do row[#row+1]=K.exact(t[k[1]])end;row[#row+1]=K.exact(t.all);rows[#rows+1]=row end
  return cols,rows
 end)
 local tot,sum={},0;for _,k in ipairs(KT)do tot[k[1]]=0 end;for _,r in ipairs(with)do local t=K.info(r).types;for _,k in ipairs(KT)do tot[k[1]]=tot[k[1]]+t[k[1]]end end;for _,k in ipairs(KT)do sum=sum+tot[k[1]]end
 local rows={};for _,k in ipairs(kt)do rows[#rows+1]={k[2],K.exact(tot[k[1]]),sum>0 and K.pc(tot[k[1]]/sum)or DASH,string.format("%.1f",tot[k[1]]/#with),key=KC[k[3]]}end
 local h=80+K.table_h(rows)+14
 view:_card(cv,X,y,W,h,"Kill Mix",K.exact(sum).." Kills Over "..K.plural(#with,"Mission"))
 if sum>0 then local parts={};for _,k in ipairs(KT)do parts[#parts+1]={tot[k[1]],KC[k[3]]}end;K.hstack(cv,X+25,y+46,22,parts,function(v)return (W-50)*v/sum end)end
 for _,r in ipairs(rows)do local c=r.key;r.under=function(ry)cv:rect(X+35,ry+10,12,12,c,true)end end
 K.table(view,cv,X+25,y+80,W-38,{{"Enemy Type",30,"l"},{"Kills",620},{"Share",800},{"Per Mission",W-48}},rows)
 return y+h+10
end
local SUBW={ranged="Ranged",bruiser="Bruiser",horde="Horde",melee="Melee",monstrosity="Monstrosity",captain="Captain",daemonhost="Daemonhost"}
local function deaths(view,cv,ms,y,tracker)
 local data=G.build(tracker,not view.scope.all_patches and view.scope.patch or nil,view.scope.mode,E,nil)
 local list={}
 if data then for gid,g in pairs(data.groups)do if gid~="unknown"then for sub,s in pairs(g.subgroups or {})do for _,e in pairs(s.enemies)do if e.total>0 then
  list[#list+1]={e=e.label,g=G.label(gid),sub=sub~=gid and sub or nil,d=e.downs,x=e.deaths,t=e.total}end end end end end end
 table.sort(list,function(a,b)if a.t~=b.t then return a.t>b.t end;if a.x~=b.x then return a.x>b.x end;return a.e<b.e end)
 if #list==0 then return K.empty(view,cv,y,"Nothing Has Downed You Yet")end
 local games=data.games>0 and data.games or nil
 return vcard(view,cv,y,"deaths","What Downed Or Killed You",(view.scope.mode=="havoc"and "Havoc"or "Non-Havoc")..", Every Mission",124+#list*24+12,function(cy)
  K.stats(view,cv,X+36,cy+46,{{"Downs",tostring(data.all.downs),games and string.format("%.1f Per Game",data.all.downs/games)},{"Deaths",tostring(data.all.deaths),games and string.format("%.1f Per Game",data.all.deaths/games)}})
  K.legend(view,cv,X+25,cy+100,{{"sq",KC.down,"Downs"},{"sq",KC.death,"Deaths"}});legend_right(view,cv,cy+100,"Worst First")
  local x0,x1=CX+196,CX+CW-60;local max=5;for _,e in ipairs(list)do max=math.max(max,e.t)end
  local function scale(v)return (x1-x0)*v/max end
  for i,e in ipairs(list)do local yc=cy+124+(i-1)*24+12
   cv:text(e.e,CX,yc-12,190,24,16,C.label);K.hstack(cv,x0,yc-7,14,{{e.d,KC.down},{e.x,KC.death}},scale);cv:text(tostring(e.t),x0+scale(e.t)+10,yc-9,60,18,14,C.value)
  end
 end,function()
  local rows={};for _,e in ipairs(list)do rows[#rows+1]={e.e,e.g..(e.sub and SUBW[e.sub]and ", "..SUBW[e.sub]or ""),tostring(e.d),tostring(e.x),tostring(e.t)}end
  return {{"Enemy",10,"l"},{"Group",320,"l"},{"Downs",800},{"Deaths",950},{"Together",W-48}},rows
 end)
end
-- a clear time follows the Boss Maps switch and a time typed in, so it is worked out each draw rather than kept
local function times(view,cv,ms,y,tracker)
 local done,by,maps,tm={},{},{},{};local backend_maps={}
 -- a backend time counts here only where Speedrunning counts it, so a late join adds none
 local function counted(r)local t=r.victory and Times.completion(r);return t and t.source=="backend"and Times.counts(r,t)end
 for _,r in ipairs(ms)do if counted(r)then backend_maps[r.context.mission_name]=true end end
 for _,r in ipairs(ms)do local t=K.clear_time(r);local b=t and Times.completion(r).source=="backend";if t and (not b or counted(r))and (not backend_maps[r.context.mission_name]or b)then tm[r]=t;done[#done+1]=r;local name=name_of(tracker,r);local m=by[name];if not m then m={map=name,runs={},fast=t,backend=b};by[name]=m;maps[#maps+1]=m end;m.runs[#m.runs+1]=r;m.fast=math.min(m.fast,t)end end
 if #done==0 then return K.empty(view,cv,y,"No Clear Times Yet")end
 -- different maps are ranked by their seconds, as map lengths differ far more than the server's times and the mission clock's do
 table.sort(maps,function(a,b)return a.fast<b.fast end)
 local best=maps[1].fast;local fast;for _,r in ipairs(done)do if tm[r]==best then fast=r end end
 local ch=#maps*35+6+30;local bm=(mod.io_display_options and mod.io_display_options()or {}).boss_map_timing
 y=vcard(view,cv,y,"times","Clear Time By Map",next(backend_maps)and "Wins Only, Backend Times Where Recorded"or bm and "Wins Only, To The Boss Death On Boss Maps"or "Wins Only, To The Victory Sequence",70+ch+10,function(cy)
  K.legend(view,cv,X+25,cy+46,{{"dot",C.gold,"Fastest On The Map"},{"dot",KC.bar_h,"Slower Clears"}})
  legend_right(view,cv,cy+46,K.plural(#done,"Clear").." On "..K.plural(#maps,"Map")..", Fastest First")
  local top=cy+70+6;local x0,x1=CX+250,CX+CW-96;local maxT=0;for _,r in ipairs(done)do maxT=math.max(maxT,tm[r])end
  local span=math.ceil(maxT*1.03/300)*300;local step=span>1800 and 600 or 300;local function sx(s)return x0+(x1-x0)*s/span end
  for s=0,span,step do cv:rect(sx(s),top,1,#maps*35,s==0 and C.axis or KC.grid,true);cv:text(s==0 and "0"or (s/60).." min",sx(s)-40,top+#maps*35+8,80,18,14,C.muted,"center")end
  for i,m in ipairs(maps)do local yc=top+(i-1)*35+17
   cv:text(m.map,CX,yc-13,240,26,16,C.value);cv:rect(x0,yc,sx(m.fast)-x0,1,KC.grid,true)
   for _,r in ipairs(m.runs)do local t=tm[r];local cx=sx(t);local isf=t==m.fast
    K.dot(cv,cx,yc,isf and 6 or 4,isf and C.gold or KC.bar_h);view:_hit("base",cx-12,yc-12,24,24,K.open_run(view,r.id),{bg=C.row_h})end
   cv:text((m.backend and Times.format or K.mmss)(m.fast),sx(m.fast)-114,yc-9,100,18,14,m.fast==best and C.gold or C.value,"right")
   if m.fast==best and #m.runs==1 then cv:text("Fastest Of All",sx(m.fast)+14,yc-9,160,18,14,C.muted)end
  end
 end,function()
  local rows={};for _,m in ipairs(maps)do local rs={};for _,r in ipairs(m.runs)do rs[#rs+1]=r end;table.sort(rs,function(a,b)return tm[a]<tm[b]end)
   for _,r in ipairs(rs)do local t=tm[r];rows[#rows+1]={m.map,K.date(r),CN[r.context.class]or DASH,t==m.fast and {(m.backend and Times.format or K.mmss)(t),"Fastest"}or (m.backend and Times.format or K.mmss)(t),act=K.open_run(view,r.id)}end end
  return {{"Map",10,"l"},{"Date",400,"l"},{"Class",650,"l"},{"Clear Time",W-48}},rows
 end)
 local t=tm[fast];local backend=Times.completion(fast).source=="backend"
 view:_card(cv,X,y,W,100,backend and "Your Fastest Backend Mission Time"or "Your Fastest Clear",name_of(tracker,fast).." · "..K.date(fast),K.open_run(view,fast.id))
 cv:text((backend and Times.format or K.mmss)(t),CX+12,y+48,CW-24,32,22,C.gold_hi)
 return y+110
end

local function share(view,cv,ms,y,tracker)
 local wait=K.warm(view,ms);local with={};for _,r in ipairs(ms)do if K.info(r).team then with[#with+1]=r end end
 if #with==0 then return K.empty(view,cv,y,wait>0 and "Counting Missions"or "No Team Damage Yet")end
 local function ratio(rs)local m,t=0,0;for _,r in ipairs(rs)do local x=K.info(r).team;m=m+x.mine;t=t+x.total end;return t>0 and m/t or 0 end
 local bestv,above=0,0;for _,r in ipairs(with)do local s=K.info(r).team.share;bestv=math.max(bestv,s);if s>.25 then above=above+1 end end
 y=vcard(view,cv,y,"share","Your Share Of Useful Team Damage",wait>0 and "Counting "..K.plural(wait,"More Mission")or #with==#ms and "Every Mission"or #with.." Of "..#ms.." Missions",358,function(cy)
  K.stats(view,cv,X+36,cy+46,{{"Share, All Missions",K.pc(ratio(with))},{"Best Mission",K.pc(bestv)},{"Above A Quarter",above.." Of "..#with}})
  K.legend(view,cv,X+25,cy+100,{{"sq",C.gold,"You"},{"sq",KC.mate1,"Each Teammate"},{"ln",KC.ref,"Even Four-Way Split, 25%"}})
  local top=cy+124;local x0,x1=CX+52,CX+CW-12;local yT,yB=top+14,top+192;local sw=(x1-x0)/#with;local bw=math.min(24,sw*.6)
  local function scale(v)return (yB-yT)*v end
  K.day_axis(cv,with,x0,sw,yT-6,yB,top+216);K.axis_y(cv,x0,x1,function(v)return yB-scale(v)end,{0,.25,.5,.75,1},function(v)return math.floor(v*100+.5).."%"end)
  for i,r in ipairs(with)do local t=K.info(r).team;local parts={{t.share,C.gold}};local k=0
   for _,o in ipairs(t.ops)do if not o.me then k=k+1;parts[#parts+1]={o.v/t.total,k%2==1 and KC.mate1 or KC.mate2}end end
   K.stack(cv,x0+sw*(i-.5)-bw/2,yB,bw,parts,scale)end
  cv:rect(x0,yB-scale(.25),x1-x0,1,KC.ref,true)
  hits(view,with,x0,sw,yT-6,yB-yT+6,8)
 end,function()
  local rows={};for i=#with,1,-1 do local r=with[i];local t=K.info(r).team;rows[#rows+1]={K.dm(K.info(r).day),name_of(tracker,r),CN[r.context.class]or DASH,K.exact(t.mine),K.exact(t.total),K.pc(t.share),act=K.open_run(view,r.id)}end
  return {{"Date",10,"l"},{"Map",90,"l"},{"Class",420,"l"},{"Your Useful Damage",760},{"Team Useful Damage",980},{"Your Share",W-48}},rows
 end)
 local byc,order={},{};for _,r in ipairs(with)do local c=r.context.class;if not byc[c]then byc[c]={c=c,rs={}};order[#order+1]=byc[c]end;table.insert(byc[c].rs,r)end
 for _,c in ipairs(order)do c.avg=ratio(c.rs);c.best=0;for _,r in ipairs(c.rs)do c.best=math.max(c.best,K.info(r).team.share)end end
 table.sort(order,function(a,b)return a.avg>b.avg end)
 return vcard(view,cv,y,"classshare","Share By Class",nil,46+#order*28+26+10,function(cy)
  local x0,x1=CX+130,CX+CW-170;local max=.5;for _,c in ipairs(order)do max=math.max(max,c.avg)end;local function sx(v)return x0+(x1-x0)*v/max end
  local top=cy+46;cv:rect(sx(.25),top,1,#order*28,KC.ref,true);cv:text("25%",sx(.25)-30,top+#order*28+4,60,18,14,C.muted,"center")
  for i,c in ipairs(order)do local yc=top+(i-1)*28+14
   view:_hit("base",X+12,yc-14,W-24,28,function()view:_go("classes")end,{bg=C.row_h})
   cv:text(CN[c.c]or c.c,CX,yc-13,128,26,16,C.label);cv:rect(x0,yc-8,sx(c.avg)-x0,16,C.gold,true)
   local pw=view:_w(K.pc(c.avg),14);cv:text(K.pc(c.avg),sx(c.avg)+10,yc-9,pw+4,18,14,C.value);cv:text(K.plural(#c.rs,"Mission"),sx(c.avg)+18+pw,yc-9,120,18,14,C.muted)
  end
 end,function()
  local rows={};for _,c in ipairs(order)do rows[#rows+1]={CN[c.c]or c.c,tostring(#c.rs),K.pc(c.avg),K.pc(c.best),act=function()view:_go("classes")end}end
  return {{"Class",10,"l"},{"Missions",500},{"Share",800},{"Best Mission",W-48}},rows
 end)
end
local ORDER={veteran=1,zealot=2,psyker=3,ogryn=4,adamant=5,broker=6,cryptic=7}
local function classes(view,cv,ms,y,tracker)
 local by,rows={},{}
 for _,r in ipairs(ms)do local c=r.context.class;local x=by[c];if not x then x={c=c,runs={},g=0,w=0,ds={},ks={}};by[c]=x;rows[#rows+1]=x end
  local f=K.info(r);x.runs[#x.runs+1]=r;x.g=x.g+1;if f.win then x.w=x.w+1 end;if f.dmg and not f.fb then x.ds[#x.ds+1]=f.dmg end;if f.kills then x.ks[#x.ks+1]=f.kills end end
 local function avg(t)if #t==0 then return nil end;local s=0;for _,v in ipairs(t)do s=s+v end;return s/#t end
 for _,x in ipairs(rows)do x.avgD=avg(x.ds);x.avgK=avg(x.ks)end
 table.sort(rows,function(a,b)if a.g~=b.g then return a.g>b.g end;return (ORDER[a.c]or 9)<(ORDER[b.c]or 9)end)
 local maxD,maxK=0,0;for _,x in ipairs(rows)do maxD=math.max(maxD,x.avgD or 0);maxK=math.max(maxK,x.avgK or 0)end
 local go=function()view:_go("classes")end
 y=vcard(view,cv,y,"classes","Class Comparison",view.scope.mode=="havoc"and "Havoc"or "Non-Havoc",46+26+#rows*32+2+12,function(cy,left)
  local kw=view:_w("Win",14)+view:_w("Loss",14)+58;K.legend(view,cv,left-kw-12,cy+16,{{"sq",KC.win,"Win"},{"sq",KC.loss,"Loss"}})
  local top=cy+46;local cw=CW-102;local cols={g=CX+150,wr=CX+178,d=CX+178+math.floor((352-178)*(cw-178)/(704-178)),k=CX+178+math.floor((550-178)*(cw-178)/(704-178)),m=CX+cw}
  local function wid(w)return math.floor(w*(cw-178)/(704-178))end
  cv:text("Class",CX,top,100,20,14,C.muted);cv:text("Games",cols.g-100,top,100,20,14,C.muted,"right");cv:text("Win Rate",cols.wr,top,150,20,14,C.muted)
  cv:text("Average Damage",cols.d,top,200,20,14,C.muted);cv:text("Average Kills",cols.k,top,200,20,14,C.muted);cv:text("Last Missions",cols.m,top,110,20,14,C.muted)
  cv:rect(CX,top+25,CW,1,C.axis,true)
  local function cell(x,w,v,max,label,n,yc)local room=n and 110 or 60;local bw=math.max(0,(w-room)*v/(max>0 and max or 1))
   cv:rect(x,yc-7,w-room,14,KC.track,true);if bw>0 then cv:rect(x,yc-7,bw,14,C.gold,true)end
   local lw=view:_w(label,14);cv:text(label,x+bw+8,yc-9,lw+4,18,14,C.value);if n then cv:text("Over "..n,x+bw+16+lw,yc-9,80,18,14,C.muted)end end
  for i,x in ipairs(rows)do local yy=top+26+(i-1)*32;local yc=yy+16
   view:_hit("base",CX-6,yy,CW+12,32,go,{bg=C.row_h})
   cv:text(CN[x.c]or x.c,CX,yy,140,32,16,C.value);cv:text(tostring(x.g),cols.g-60,yy,60,32,16,C.value,"right")
   cell(cols.wr,wid(148),x.w/x.g,1,K.pc(x.w/x.g,0),nil,yc)
   if x.avgD then cell(cols.d,wid(172),x.avgD,maxD,K.mod(x.avgD),#x.ds,yc)end
   if x.avgK then cell(cols.k,wid(130),x.avgK,maxK,tostring(math.floor(x.avgK+.5)),#x.ks,yc)end
   local show={};for _,r in ipairs(x.runs)do show[#show+1]=r end;local from=math.max(1,#show-5)
   for k=from,#show do cv:rect(cols.m+(k-from)*17,yc-6,12,12,K.info(show[k]).win and KC.win or KC.loss,true)end
   cv:rect(CX,yy+31,CW,1,KC.grid,true)
  end
 end,function()
  local out={};for _,x in ipairs(rows)do out[#out+1]={CN[x.c]or x.c,tostring(x.g),tostring(x.w),K.pc(x.w/x.g),x.avgD and {K.exact(x.avgD),"Over "..#x.ds}or DASH,x.avgK and {string.format("%.1f",x.avgK),"Over "..#x.ks}or DASH,act=go}end
  return {{"Class",10,"l"},{"Games",300},{"Wins",450},{"Win Rate",600},{"Average Damage",900},{"Average Kills",W-48}},out
 end)
 local any=false;for _,x in ipairs(rows)do for _,r in ipairs(x.runs)do if K.info(r).dmg then any=true end end end
 if not any then return y end
 return vcard(view,cv,y,"classdots","Damage Per Mission By Class","One Dot Per Mission",70+4+#rows*26+28+10,function(cy)
  K.legend(view,cv,X+25,cy+46,{{"dot",KC.win,"Win"},{"dot",KC.loss,"Loss"},{"tk",C.value,"Average"}})
  local top=cy+74;local x0,x1=CX+118,CX+CW-110;local mx=0;for _,x in ipairs(rows)do for _,r in ipairs(x.runs)do mx=math.max(mx,K.info(r).dmg or 0)end end
  local nt,ticks=K.nice(mx*1.02,5);local function sx(v)return x0+(x1-x0)*v/nt end
  for _,v in ipairs(ticks)do cv:rect(sx(v),top,1,#rows*26,v==0 and C.axis or KC.grid,true);cv:text(K.tick(v),sx(v)-40,top+#rows*26+8,80,18,14,C.muted,"center")end
  for i,x in ipairs(rows)do local yc=top+(i-1)*26+13
   cv:text(CN[x.c]or x.c,CX,yc-13,110,26,16,C.value)
   if x.avgD then cv:rect(sx(x.avgD)-1,yc-9,2,18,C.value,true);cv:text("Avg "..K.mod(x.avgD),x1+16,yc-9,100,18,14,C.muted)end
   for _,r in ipairs(x.runs)do local f=K.info(r);if f.dmg then local cx=sx(f.dmg);K.dot(cv,cx,yc,4,f.win and KC.win or KC.loss);view:_hit("base",cx-10,yc-10,20,20,K.open_run(view,r.id),{bg=C.row_h})end end
  end
 end,function()
  local out={};for _,x in ipairs(rows)do local rs={};for _,r in ipairs(x.runs)do if K.info(r).dmg then rs[#rs+1]=r end end;table.sort(rs,function(a,b)return K.info(a).dmg>K.info(b).dmg end)
   for _,r in ipairs(rs)do local f=K.info(r);out[#out+1]={CN[x.c]or x.c,K.dm(f.day),name_of(tracker,r),result(r),f.fb and {K.exact(f.dmg),"Weapon Hits"}or K.exact(f.dmg),act=K.open_run(view,r.id)}end end
  return {{"Class",10,"l"},{"Date",200,"l"},{"Map",320,"l"},{"Result",750,"l"},{"Damage",W-48}},out
 end)
end
local DRAW={results=results,damage=damage,kills=kills,deaths=deaths,times=times,share=share,classes=classes}
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 if view.io_params and view.io_params.trends then view.io_trend_tab=view.io_params.trends;view.io_params.trends=nil end
 local tab=view.io_trend_tab;if not DRAW[tab]then tab="results";view.io_trend_tab=tab end
 -- Deaths counts every difficulty, so on that tab Difficulty is dimmed
 view:_scope(cv,popup,m,true,tab=="deaths")
 local label;for _,t in ipairs(TABS)do if t[1]==tab then label=t[2]end end
 view.io_crumbs={{"Trends",tab~="results"and function()view.io_trend_tab="results"end or nil},{label}}
 K.tabs(view,cv,TABS,tab,function(v)view.io_trend_tab=v;if view.scroll then view.scroll.trends=0 end end)
 local ms=K.chron(view)
 view:_sheet(cv,D.sheet)
 if #ms==0 and tab~="deaths"then K.empty(view,cv,D.sheet,"No Missions In This View")
 else DRAW[tab](view,cv,ms,D.sheet,tracker)end
 view:_sheet_end(cv)
end
