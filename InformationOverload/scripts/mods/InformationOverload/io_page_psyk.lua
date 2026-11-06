-- Information Overload: the Psykhanium Weapon Bench, its saved sessions and the same loadout in missions.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local P=mod:io_dofile(base.."io_data_people")
local Overview=mod:io_dofile(base.."io_overview")
local B=mod:io_dofile(base.."io_bench_dps")
local C,F,DASH=D.c,D.font,P.dash
-- session A and session B, in every mark that tells the two apart
local AB={D.rgba(185,138,46),D.rgba(74,136,207)}
local B10_TIP={"Best 10 Seconds","The best ten seconds of reported damage, shields left out.","It never spans a reconnect."}
local L,LW,R,RW=D.left,740,850,D.right-850
local SHOW=P.ARMOUR
local function n0(v)return v and v>0 and P.commas(v)or DASH end
local function fit(view,t,size,w,font)if not t or view:_w(t,size,font)<=w then return t end;while #t>1 and view:_w(t.."…",size,font)>w do repeat local b=t:byte(-1);t=t:sub(1,-2)until #t==0 or b<128 or b>=192 end;return t:gsub("[%s,]+$","").."…"end
local function shrink(view,t,size,w)while size>11 and view:_w(t,size)>w do size=size-1 end;return size end
local function per(b)return b and b.n>0 and b.dmg/b.n or nil end
local function strip(s)return s and (s:gsub(" [IVX]+,",","):gsub(" [IVX]+$",""))or nil end
local function popup(title,body,label,fn)
 if not (Managers.event and Managers.event.trigger)then return fn()end
 Managers.event:trigger("event_show_ui_popup",{title_text_unlocalized=title,description_text_unlocalized=body,
  options={{text=label,no_localization=true,close_on_pressed=true,callback=function()if mod.io_current()then fn()end end},{text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back"}}})
end
local function frame(cv,x,y,w,h,labels,drawn)
 cv.z=5;cv:edges(x,y,w,h,1,C.frame)
 for i=1,3 do cv:rect(x+1,y+h*i/4,w-2,1,C.line)end
 for i,l in ipairs(labels or {})do cv:text(l,x+(i-1)*w/(#labels-1)-40,y+h+6,80,18,13,i==#labels and C.value or C.muted,"center")end
 if not drawn then cv:text(DASH,x,y,w,h,22,C.muted,"center")end
end
local function tip(view,x,y,w,h,lines)if view._tip then view:_tip("base",x,y,w,h,lines)end end
local function live_tl()local ss=mod.io_psykhanium and mod.io_psykhanium();local m=ss and ss.mission;return m and m.combat_timeline end
local function nice(v)local p=10^math.floor(math.log10(math.max(1,v)));local m=v/p;return (m<=1 and 1 or m<=2 and 2 or m<=2.5 and 2.5 or m<=5 and 5 or 10)*p end
local function tick(v)if v>=1000 then return (string.format("%.2f",v/1000):gsub("0+$",""):gsub("%.$","")).."K"end;return tostring(math.floor(v+.5))end
-- four steps up to the frame's top, one on each rule, labelled on the left
local function scale(cv,x,y,h,vmax)local step=nice(vmax*1.1/4);for i=0,4 do cv:text(tick(step*i),x-62,y+h-h*i/4-9,56,18,13,C.muted,"right")end;return step*4 end
local function spark(cv,sp,x,y,c)for i=2,#sp do cv:line(x+(i-2)*56/(#sp-1),y+33-sp[i-1]*22,x+(i-1)*56/(#sp-1),y+33-sp[i]*22,1.3,c)end end
local function trace(cv,run,X,Y,c,t)for i=2,#run do local p,q=run[i-1],run[i];cv:line(X(p[1]),Y(p[2]),X(q[1]),Y(q[2]),t or 2,c)end end
-- the last minute: the 2 second window every quarter second, the best 10 seconds when they fall in it, and a dot at now
local function live_graph(cv,tl,best,fx,fy,fw,fh)
 local runs,t0,now=B.live(tl,60,2,.25);local vmax=1
 for _,r in ipairs(runs)do for _,p in ipairs(r)do vmax=math.max(vmax,p[2])end end
 local top=scale(cv,fx,fy,fh,vmax)
 local function X(t)return fx+(t-t0)/60000*fw end;local function Y(v)return fy+fh-math.min(1,v/top)*fh end
 cv.z=5
 if best and best.dps>0 and best.segment==#tl.segments and best.last_ms>t0 then local xa,xb=math.max(fx,X(best.last_ms-10000)),X(best.last_ms)
  cv:rect(xa,fy+1,xb-xa,fh-2,D.rgba(221,183,99,.07));cv:rect(xa,Y(best.dps)-1,xb-xa,2,C.gold)
  if xb-xa>110 then cv:text("Best 10 Seconds",xa,fy+4,xb-xa,18,13,C.gold,"center",F.medium)end
 end
 local bw=math.max(1,fw*.25/60)
 for _,r in ipairs(runs)do for _,p in ipairs(r)do local px=X(p[1]);if p[2]>0 then cv:rect(px-bw/2,Y(p[2]),bw,fy+fh-Y(p[2]),D.rgba(221,183,99,.09))end end;trace(cv,r,X,Y,C.gold)end
 local r=runs[#runs];local p=r and r[#r]
 if p and p[1]==now then cv:rect(X(now)-3,Y(p[2])-3,6,6,C.value)end
 return #runs>0
end
local function fig(cv,x,y,label,value,cap,gold)
 cv:rect(x,y+2,2,cap and 62 or 46,gold and C.gold or C.frame)
 cv:text(label,x+12,y,170,20,14,C.label);cv:text(value,x+12,y+20,170,30,22,C.value)
 if cap then cv:text(cap,x+12,y+48,170,18,13,gold and C.gold or C.muted,"left",F.medium)end
end
local function dps_card(view,cv,popup_cv,s,y,data)
 local x,w=L,LW;local tgt=view.io_psyk_tgt or "all"
 local opts={{value="all",label="All Targets",n=P.plural(s.hits,"Hit"),current=tgt}}
 for _,a in ipairs(SHOW)do local b=s.arm[a[1]];opts[#opts+1]={value=a[1],label=a[2],n=P.plural(b.n,"Hit"),dis=b.n==0,current=tgt}end
 local shown="All Targets";for _,o in ipairs(opts)do if o.value==tgt then shown=o.label end end
 P.select(view,cv,popup_cv,"psyk_tgt",x+w-243,y+11,230,"Target:  "..shown,opts,function(v)view.io_psyk_tgt=v end)
 local wh=tgt=="all"and s.dps and s.dps.wh
 -- the session's hits carry no armour, so a single target keeps the dash
 local tl=s.live and tgt=="all"and live_tl();if tl and not B.has_events(tl)then tl=nil end
 local d=tl and B.live_digest(tl);local now,l10,b10,cap=DASH,DASH,DASH
 if d then now,l10,b10=P.commas(B.window(tl,2)),P.commas(B.window(tl,10)),P.commas(d.best.dps)
  local prev=0;for _,o in ipairs(data.saved)do local c=o.weapon==s.weapon and B.cached(o.run);if c and c.best.dps>prev then prev=c.best.dps end end
  cap=d.best.dps>=prev and (prev>0 and "Bench Best For This Loadout"or "This Session")or "Saved Best "..P.commas(prev)
 end
 local cols={{"Now",now},{"Last 10 Seconds",l10},{"Best 10 Seconds",b10,cap,true},{"While Hitting",wh and P.commas(wh)or DASH,wh and "Over "..P.mss(s.dur)}}
 local cx={x+37,x+169,x+317,x+497}
 for i,c in ipairs(cols)do if i>1 then cv:rect(cx[i]-21,y+46,1,64,C.frame)end
  cv:text(c[1],cx[i],y+46,150,22,14,C.label);cv:text(c[2],cx[i],y+68,150,30,22,c[2]==DASH and C.muted or c[4]and C.gold or C.value)
  if c[3]then local room=cx[i+1]and cx[i+1]-cx[i]-28 or 180;local size=shrink(view,c[3],14,room);cv:text(fit(view,c[3],size,room,F.medium),cx[i],y+96,room+6,18,size,c[4]and C.gold or C.muted,"left",F.medium)end end
 tip(view,cx[3]-8,y+46,cx[4]-cx[3]-14,70,B10_TIP)
 local fx,fy,fw,fh=x+82,y+126,w-105,190;local ok,drawn=true,false
 if d then ok,drawn=pcall(live_graph,cv,tl,d.best,fx,fy,fw,fh);if not ok then mod:error("I/O bench graph: %s",tostring(drawn));drawn=false end end
 frame(cv,fx,fy,fw,fh,{"-60 s","-45 s","-30 s","-15 s","Now"},drawn)
end
local function session_card(view,cv,s,data,y)
 local x,w=R,RW
 local best=s.best and P.commas(s.best)or DASH
 fig(cv,x+37,y+50,"Damage",n0(s.dmg));fig(cv,x+233,y+50,"Hits",n0(s.hits))
 fig(cv,x+37,y+108,"Per Hit",s.hits>0 and P.commas(s.dmg/s.hits)or DASH);fig(cv,x+233,y+108,"Best Hit",best)
 local yy=y+184;cv:rect(x+37,yy,w-50,1,C.frame,true);yy=yy+6
 local same=data.same or {runs=0,diffs={}};local m=same.data
 cv:text(same.own==false and "Same Weapon In Missions"or "Same Loadout In Missions",x+37,yy,300,26,16,C.gold)
 local head=same.runs>0 and P.plural(same.runs,"Run")or "No Runs Yet";local full=head..", "..table.concat(same.diffs," And ")
 if same.runs>0 and view:_w(full,13)<=w-250 then head=full elseif same.runs>0 and #same.diffs>0 then head=head..", "..same.diffs[1]..(#same.diffs>1 and " And More"or "")end
 if view:_w(head,13)>w-250 then head=P.plural(same.runs,"Run")end;if data.counting then head="Counting Missions"end
 cv:text(head,x+w-313,yy+1,300,26,13,C.muted,"right",F.medium);yy=yy+26
 local function line(l,v)cv:text(l,x+37,yy,250,26,16,C.label);cv:text(v,x+w-313,yy,300,26,16,C.value,"right");yy=yy+26 end
 local hits,dmg=0,0;if m then for _,a in ipairs(SHOW)do local b=m.arm[a[1]];if b then hits=hits+b.n;dmg=dmg+b.dmg end end end
 line("Per Hit",hits>0 and P.commas(dmg/hits)or DASH);line("Melee Hits",hits>0 and P.commas(hits)or DASH)
 local top=data.single
 if top then cv:text("Best Single Hit",x+37,yy,250,24,16,C.label);cv:text(P.commas(top.v),x+w-313,yy,300,24,16,C.gold,"right")
  local cap=top.enemy and "On "..top.enemy..(top.diff and ", "..top.diff or "")or top.diff;if cap then cv:text(fit(view,cap,13,w-200,F.medium),x+37,yy+21,w-200,18,13,C.muted,"left",F.medium)end end
 local tl=s.live and live_tl();local lh=tl and B.last_hit(tl)
 yy=y+316;cv.z=5;cv:edges(x+37,yy,w-63,42,1,C.frame);cv:text("Last Hit",x+51,yy,100,42,16,C.label);cv:text(lh and P.commas(lh)or DASH,x+51+view:_w("Last Hit",16)+12,yy,100,42,20,lh and C.value or C.muted)
end
-- the best single hit any mission recorded with the bench's weapon, matched by the name the loadout shows; worked out again only when the history moves
mod.io_bench_single=mod.io_bench_single or {}
local function single_best(tracker,weapon)
 local data=tracker and tracker.data or {};local rows=data.rows;if type(rows)~="table"or not weapon then return nil end
 local c=mod.io_bench_single
 if c.rows~=rows or c.seq~=data.run_sequence or c.weapon~=weapon then c={rows=rows,seq=data.run_sequence,weapon=weapon};local names={}
  for _,row in pairs(rows)do local x=row.context or {};local v=not row.aggregate and row.best and row.best.single_hit
   if type(v)=="number"and v>0 and x.weapon~=nil and (not c.top or v>c.top.v)then
    local n=names[x.weapon];if n==nil then local ok,r=pcall(mod.io_weapon_name,x.weapon);n=ok and r or false;names[x.weapon]=n end
    if n==weapon then local src=row.best_weapons and row.best_weapons.single_hit;local e=src and src.enemy;
     c.top={v=v,enemy=type(e)=="string"and e~=""and e~="Unknown enemy"and e~="Unknown"and e or nil,diff=Overview.diff_label(x)}end
   end
  end
  mod.io_bench_single=c
 end
 return c.top
end
local function armour_card(view,cv,data,cur,y)
 local x,w=L,LW;local tx,cw=x+236,80;local rows=data.rows or {}
 cv:text("Melee Loadout",x+33,y+46,300,24,14,C.muted)
 local hs=14;for _,a in ipairs(SHOW)do hs=math.min(hs,shrink(view,a[2],14,cw-6))end
 for i,a in ipairs(SHOW)do cv:text(a[2],tx+(i-1)*cw-4,y+46,cw-2,24,hs,C.muted,"right")end
 cv:rect(x+25,y+70,w-50,1,C.frame,true)
 local top={}
 for _,a in ipairs(SHOW)do local t=0;for _,s in ipairs(rows)do local b=s.mis;local v=per(b and b.arm[a[1]]);if v and v>t then t=v end end;top[a[1]]=t end
 local yy=y+71
 for _,s in ipairs(rows)do local mine=s==cur;local b=s.mis
  if mine then cv:rect(x+26,yy,2,46,C.gold,true)end
  cv:text(fit(view,s.weapon,15,196),x+33,yy+4,200,22,15,C.value);cv:text(fit(view,(mine and ""or s.op..", ")..(strip(s.blessings)or DASH),13,196,F.medium),x+33,yy+23,200,18,13,C.muted,"left",F.medium)
  for i,a in ipairs(SHOW)do local cx=tx+(i-1)*cw;local mu=per(b and b.arm[a[1]]);local bv=per(s.arm[a[1]])
   if mu then cv.z=5;cv:rect(cx,yy+1,cw-2,44,D.rgba(185,138,46,.06+.5*mu/math.max(1,top[a[1]])))end
   if bv then cv:text(P.commas(bv),cx,yy+4,cw-8,22,16,C.value,"right")end
   if mu then cv:text(P.commas(mu),cx,yy+23,cw-8,18,13,C.muted,"right",F.medium)
    local lines={s.weapon.." vs "..a[2]};if bv then lines[2]="Bench: "..P.commas(bv).." Per Hit, "..P.plural(s.arm[a[1]].n,"Hit")end
    lines[#lines+1]="Missions: "..P.commas(mu).." Per Hit, "..P.plural(b.arm[a[1]].n,"Hit");tip(view,cx,yy+1,cw-2,44,lines)end
  end
  cv:rect(x+25,yy+46,w-50,1,C.line,true);yy=yy+46
 end
 local gap,gv
 local cb=cur.mis
 for _,s in ipairs(rows)do if s.weapon~=cur.weapon then local b=s.mis
  for _,a in ipairs(SHOW)do local o,c=per(b and b.arm[a[1]]),per(cb and cb.arm[a[1]])
   if o and c and c>0 and o/c>=1.5 and (not gv or o/c>gv)then gv=o/c;gap={s.weapon,a[2],o,c}end end end end
 if gap then yy=yy+10;cv:rect(x+37,yy,w-74,32,C.fill);cv:rect(x+37,yy,2,32,C.gold)
  cv:text(gap[1].." hits "..gap[2].." "..string.format("%.1f",gv).." times as hard as "..cur.weapon..", "..P.commas(gap[3]).." against "..P.commas(gap[4]).." per hit.",x+51,yy,w-100,32,14,C.value)end
 if data.counting then yy=yy+10;cv:rect(x+37,yy,w-74,32,C.fill);cv:rect(x+37,yy,2,32,C.frame);cv:text(data.counting,x+51,yy,w-100,32,14,C.muted)end
end
local function saved_card(view,cv,data,y)
 local x,w=R,RW;local ticks=view.io_psyk_ticks
 local list={};if data.live then list[1]=data.live end;for _,s in ipairs(data.saved)do list[#list+1]=s end
 local runs={};for _,s in ipairs(data.saved)do runs[#runs+1]=s.run end;B.warm(view,runs)
 -- best 10 seconds and shape for each row; the gold flag goes to the highest of each weapon's sessions
 local fig,top,many={},{},{}
 for _,s in ipairs(list)do local d
  if s.live then local tl=live_tl();d=tl and B.has_events(tl)and B.live_digest(tl)else d=B.cached(s.run)end
  fig[s]=d;local v=d and d.best.dps or 0;many[s.weapon]=(many[s.weapon]or 0)+1;top[s.weapon]=math.max(top[s.weapon]or 0,v)
 end
 -- two ticked sessions compare as A and B; Delete swaps the ticks for its own, as many saved sessions as wanted, gone for good after one confirmation
 -- Delete mode is a plain value on the view so Back, right click and forward step through it; the sessions marked live beside it
 if view.io_psyk_deleting then view.io_psyk_del=view.io_psyk_del or {}else view.io_psyk_del=nil end
 local del=view.io_psyk_del
 if del then
  local doomed={};for _,s in ipairs(data.saved)do if del[s.id]then doomed[#doomed+1]=s end end
  P.button(view,cv,x+w-103,y+11,90,32,"Cancel",function()view.io_psyk_deleting=nil end)
  local lab="Delete "..#doomed;local bw=view:_w(lab,16)+32
  P.button(view,cv,x+w-113-bw,y+11,bw,32,lab,function()
   local event=Managers.event;if not event or not mod.io_delete_match then return end
   local n=#doomed;local one=n==1
   event:trigger("event_show_ui_popup",{title_text_unlocalized=one and "Delete Session"or "Delete Sessions",
    description_text_unlocalized=one and "Delete the saved session "..doomed[1].weapon.."?"or "Delete these "..n.." saved sessions?",options={
    {text="Delete",no_localization=true,close_on_pressed=true,callback=function()
     for _,s in ipairs(doomed)do local ok,reason=mod.io_delete_match(s.run.id,"logs");if not ok then mod:echo("%s",reason or "The session could not be deleted.");break end end
     local kept={};for _,id in ipairs(view.io_psyk_ticks)do if not del[id]then kept[#kept+1]=id end end;view.io_psyk_ticks=kept;view.io_psyk_deleting=nil;view:_refresh()end},
    {text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back"}}})
  end,{dis=#doomed==0,danger=#doomed>0})
 else
  P.button(view,cv,x+w-103,y+11,90,32,"Compare",function()view.io_psyk_view="compare"end,{dis=#ticks~=2})
  P.button(view,cv,x+w-191,y+11,80,32,"Delete",function()view.io_psyk_deleting=true;view.io_psyk_del={}end,{dis=#data.saved==0})
 end
 cv:text("Loadout",x+41,y+52,180,36,14,C.muted);cv:text("Shape",x+227,y+52,60,36,14,C.muted)
 cv:text("While",x+w-183,y+48,80,18,14,C.muted,"right");cv:text("Hitting",x+w-183,y+65,80,18,14,C.muted,"right")
 cv:text("Best 10",x+w-93,y+48,80,18,14,C.muted,"right");cv:text("Seconds",x+w-93,y+65,80,18,14,C.muted,"right")
 cv:rect(x+12,y+88,w-24,1,C.frame,true)
 local yy=y+89
 if #list==0 then cv:text("No saved sessions yet.",x+36,yy+6,300,26,14,C.muted,"left",F.medium)end
 for _,s in ipairs(list)do local ti;for i,id in ipairs(ticks)do if id==s.id then ti=i end end
  local tip={s.weapon,s.op..", "..(s.blessings or DASH),"Duration: "..P.mss(s.dur)}
  if del then local on=del[s.id]
   -- the live session has nothing saved yet, so it takes no tick while deleting
   if not s.live then view:_hit("base",x+12,yy,w-24,44,function()del[s.id]=not on or nil end,{bg=C.row_h},nil,tip)end
   cv.z=5;if not s.live then cv:edges(x+16,yy+15,14,14,1,on and C.bad or C.hover);if on then cv:rect(x+19,yy+18,8,8,C.bad)end end;ti=nil
  else
   view:_hit("base",x+12,yy,w-24,44,function()
    if ti then table.remove(ticks,ti)else ticks[#ticks+1]=s.id;if #ticks>2 then table.remove(ticks,1)end end end,{bg=C.row_h},nil,tip)
   cv.z=5;cv:edges(x+16,yy+15,14,14,1,ti and C.sel or C.hover);if ti then cv:rect(x+19,yy+18,8,8,C.gold)end
  end
  local nx=x+41;if ti then cv:rect(nx,yy+5,16,16,AB[ti],nil,.4);cv:text(ti==1 and "A"or "B",nx,yy+5,16,16,13,C.value,"center");nx=nx+22 end
  cv:text(fit(view,s.weapon,15,x+216-nx),nx,yy+4,x+220-nx,20,15,C.value)
  local sub={};if s.live then sub[1]="This Session"end;sub[#sub+1]=s.op;local b=strip(s.blessings);if b then sub[#sub+1]=(b:match("^[^,]+"))end;sub[#sub+1]=P.mss(s.dur)
  cv:text(fit(view,table.concat(sub,", "),13,176,F.medium),x+41,yy+23,180,18,13,C.muted,"left",F.medium)
  local d=fig[s];local sp=d and d.spark
  local ok,err=true,nil;if sp then ok,err=pcall(spark,cv,sp,x+227,yy,ti and AB[ti]or C.label);if not ok then mod:error("I/O session shape: %s",tostring(err))end end;if not (sp and ok)then cv:text(DASH,x+227,yy,56,44,16,C.muted,"left")end
  local b=d and d.best.dps;local gold=b and b>0 and many[s.weapon]>1 and b>=top[s.weapon]
  cv:text(s.dps and s.dps.wh and P.commas(s.dps.wh)or DASH,x+w-183,yy,80,44,16,C.value,"right");cv:text(b and P.commas(b)or DASH,x+w-93,yy,80,44,16,not b and C.muted or gold and C.gold or C.value,"right")
  cv:rect(x+12,yy+43,w-24,1,C.line,true);yy=yy+44
 end
end
local function compare(view,cv,data)
 local byid={};if data.live then byid[data.live.id]=data.live end;for _,s in ipairs(data.saved)do byid[s.id]=s end
 local a,b=byid[view.io_psyk_ticks[1]],byid[view.io_psyk_ticks[2]]
 if not a or not b then view.io_psyk_view=nil;return false end
 view.io_crumbs={{"Psykhanium",function()view.io_psyk_view=nil end},{"Compare Sessions"}}
 for k,s in ipairs({a,b})do local bx=k==1 and D.left or D.col2
  cv.z=4;cv:rect(bx,D.top,D.col,44,C.fill);cv.z=5;cv:edges(bx,D.top,D.col,44,1,C.frame);cv:corners(bx-1,D.top-1,D.col+2,46,C.corner)
  cv:rect(bx+12,D.top+12,20,20,AB[k],nil,.4);cv:text(k==1 and "A"or "B",bx+12,D.top+12,20,20,14,C.value,"center")
  cv:text(s.weapon,bx+44,D.top+1,540,22,16,C.value);cv:text(s.op..(s.live and ", This Session"or "")..", "..(s.blessings or DASH)..", "..P.mss(s.dur),bx+44,D.top+21,540,20,13,C.muted,"left",F.medium)
 end
 view:_sheet(cv,D.top+54);local y=D.top+54;cv.z=5
 view:_card(cv,D.left,y,D.width,290,"Damage Per Second Over Each Session","Session Time, 6 Second Window");cv.z=5
 local function digest_of(s)if s.live then local tl=live_tl();return tl and B.has_events(tl)and B.live_digest(tl)or nil end;B.read(s.run);return B.cached(s.run)end
 local da,db=digest_of(a),digest_of(b);local tmax=math.max(60,a.dur,b.dur)
 local function graph()
  local vmax,shown=1,false;for _,d in ipairs({da or {runs={}},db or {runs={}}})do for _,r in ipairs(d.runs)do for _,p in ipairs(r)do if p[1]<=tmax then vmax=math.max(vmax,p[2])end end end end
  local fx,fy,fw,fh=164,y+56,1100,200;local top=scale(cv,fx,fy,fh,vmax)
  local function X(t)return fx+t/tmax*fw end;local function Y(v)return fy+fh-math.min(1,v/top)*fh end
  -- at most about 300 points a trace, each the mean of the seconds it stands for
  for _,e in ipairs({{db,AB[2]},{da,AB[1]}})do if e[1]then for _,r in ipairs(e[1].runs)do local n=0;for _,p in ipairs(r)do if p[1]<=tmax then n=n+1 end end
   local k,pts=math.max(1,math.ceil(n/300)),{};for i=1,n,k do local st,sv,m=0,0,0;for j=i,math.min(n,i+k-1)do st=st+r[j][1];sv=sv+r[j][2];m=m+1 end;pts[#pts+1]={st/m,sv/m}end
   if #pts>1 then trace(cv,pts,X,Y,e[2]);shown=true end end end end
  for k,c in ipairs(AB)do local lx=D.right-150+(k-1)*70;cv:rect(lx,y+26,18,2,c);cv:text(k==1 and "A"or "B",lx+24,y+13,30,30,14,C.label)end
  return shown
 end
 local drawn=graph()
 frame(cv,164,y+56,1100,200,{"0:00",P.mss(tmax)},drawn);y=y+300
 local function f(v,fn)return v and (fn or P.commas)(v)or DASH end
 local function pc(x1,x2)if not x1 or not x2 or x1==0 then return ""end;local p=math.floor((x2/x1-1)*100+.5);return (p>0 and "+"or "")..p.."%"end
 local rows={{"Duration",a.dur,b.dur,P.mss,true},{"Damage",a.dmg,b.dmg,nil,true},{"Hits",a.hits,b.hits,nil,true},{"Per Hit",a.hits>0 and a.dmg/a.hits or nil,b.hits>0 and b.dmg/b.hits or nil},
  {"DPS While Hitting",a.dps and a.dps.wh,b.dps and b.dps.wh},{"Best 10 Seconds",da and da.best.dps,db and db.best.dps},{"Best Hit",a.best,b.best}}
 local h=52+30+#rows*32;view:_card(cv,100,y,560,h,"Session");cv.z=5
 local hx={300,400,520};cv:text("A",100+hx[1]-100,y+46,100,30,14,C.muted,"right");cv:text("B",100+hx[2]-100,y+46,100,30,14,C.muted,"right");cv:text("B Against A",100+hx[3]-130,y+46,130,30,14,C.muted,"right")
 cv:rect(125,y+75,510,1,C.frame,true)
 for i,r in ipairs(rows)do local ry=y+76+(i-1)*32;cv:text(r[1],136,ry,200,32,16,C.label)
  cv:text(f(r[2],r[4]),100+hx[1]-150,ry,150,32,16,C.value,"right");cv:text(f(r[3],r[4]),100+hx[2]-150,ry,150,32,16,C.value,"right")
  if not r[5]then cv:text(pc(r[2],r[3]),100+hx[3]-150,ry,150,32,16,C.value,"right")end;cv:rect(125,ry+31,510,1,C.line,true)end
 local x2,w2=670,D.right-670;local h2=52+30+#SHOW*32;view:_card(cv,x2,y,w2,h2,"Per Hit By Armour");cv.z=5
 cv:text("Armour",x2+36,y+46,150,30,14,C.muted);cv:text("A",x2+200,y+46,100,30,14,C.muted,"right");cv:text("B",x2+300,y+46,100,30,14,C.muted,"right");cv:text("B Against A",x2+w2-163,y+46,140,30,14,C.muted,"right")
 cv:rect(x2+25,y+75,w2-50,1,C.frame,true)
 local am=1;for _,ar in ipairs(SHOW)do am=math.max(am,per(a.arm[ar[1]])or 0,per(b.arm[ar[1]])or 0)end
 for i,ar in ipairs(SHOW)do local ry=y+76+(i-1)*32;local va,vb=per(a.arm[ar[1]]),per(b.arm[ar[1]])
  cv:text(ar[2],x2+36,ry,150,32,16,C.label);cv:text(f(va),x2+200,ry,100,32,16,C.value,"right");cv:text(f(vb),x2+300,ry,100,32,16,C.value,"right")
  cv:rect(x2+415,ry+10,math.max(1,90*(va or 0)/am),5,AB[1]);cv:rect(x2+415,ry+17,math.max(1,90*(vb or 0)/am),5,AB[2])
  cv:text(pc(va,vb),x2+w2-163,ry,140,32,16,C.value,"right");cv:rect(x2+25,ry+31,w2-50,1,C.line,true)end
 view:_sheet_end(cv);return true
end
return function(view,cv,popup_cv)
 local tracker=view:_tracker()
 local data=P.psyk(tracker or {data={}})
 view.io_psyk_ticks=view.io_psyk_ticks or {}
 local valid={};if data.live then valid[data.live.id]=true end;for _,s in ipairs(data.saved)do valid[s.id]=true end
 for i=#view.io_psyk_ticks,1,-1 do if not valid[view.io_psyk_ticks[i]]then table.remove(view.io_psyk_ticks,i)end end
 if view.io_psyk_view=="compare"and #view.io_psyk_ticks==2 and compare(view,cv,data)then return end
 view.io_psyk_view=nil
 view.io_crumbs=view.io_psyk_deleting and {{"Psykhanium"},{"Weapon Bench",function()view.io_psyk_deleting=nil end},{"Delete Sessions"}}or {{"Psykhanium"},{"Weapon Bench"}}
 local s=data.live;local cur=s or data.saved[1]
 if cur then local nw=math.min(view:_w(cur.weapon,16),400)
  cv:text(cur.weapon,112,D.top,nw+6,34,16,C.value)
  local sub=cur.op..", "..(P.class_names[cur.cls]or tostring(cur.cls))..", Melee Slot"
  if cur.blessings then sub=sub.."  ·  "..cur.blessings:gsub(", "," / ")end;if cur.perks and cur.perks~="None"then sub=sub.."  ·  "..cur.perks:gsub("{#[^}]*}",""):gsub(" / ",", ")end
  cv:text(sub,124+nw,D.top+1,1020-nw-124,34,14,C.label)
 end
 local live_hits=s and s.hits or 0;local inside=mod.io_is_training and mod.io_is_training()
 if inside then
 P.button(view,cv,1034,D.top,120,34,"Save Session",function()popup("Save Session","Move this session to Saved Sessions and start a new one?","Save",function()
  local run=mod.io_capture_psykhanium and mod.io_capture_psykhanium();if run and mod.io_save_psykhanium_log(run,s.weapon)then mod.io_reset_psykhanium()end end)end,{dis=not s or live_hits<5})
 P.button(view,cv,1164,D.top,126,34,"Reset Session",function()popup("Reset Session","Clear the session under way? Saved sessions are kept.","Reset",function()if mod.io_reset_psykhanium then mod.io_reset_psykhanium()end end)end,{dis=live_hits==0,danger=true})
 end
 if not cur then local y=inside and D.top+54 or D.top;view:_card(cv,D.left,y,D.width,112,"No Bench Sessions Yet")
  cv:text("Hit the training targets in the Psykhanium and your session shows up here.",D.left+36,y+48,D.width-72,22,16,C.label)
  cv:text("Save a session to keep it and compare loadouts.",D.left+36,y+72,D.width-72,22,16,C.label);return end
 local blank=s or {id="none",weapon=cur.weapon,op=cur.op,arm={},hits=0,dmg=0,dur=0}
 if not s then for _,a in ipairs(SHOW)do blank.arm[a[1]]={dmg=0,n=0}end end
 view:_sheet(cv,D.top+44);local y=D.top+44
 -- outside the Psykhanium there is no session under way, so only the saved ones show
 if s or inside then
 view:_card(cv,L,y,LW,374,"Damage Per Second","Last 60 Seconds, 2 Second Window");view:_card(cv,R,y,RW,374,"This Session")
 cv:text("Session",R+RW-160,y+11,100,30,14,C.label,"right");cv:text(blank.dur>0 and P.mss(blank.dur)or DASH,R+RW-58,y+11,45,30,16,C.value,"right")
 data.single=single_best(tracker,blank.weapon)
 cv.z=5;dps_card(view,cv,popup_cv,blank,y,data);session_card(view,cv,blank,data,y)
 y=y+384
 end
 local rh=82+#(data.rows or {})*46+((#(data.rows or {})>1 or data.counting)and 52 or 16)
 -- Corner brackets sit 1px outside the card, so fill to 11px above the bottom to stay clear of the scrollbar.
 local sh=99+math.max(1,(data.live and 1 or 0)+#data.saved)*44+12;local h=math.max(math.min(316,D.bottom-11-y),rh,sh)
 view:_card(cv,L,y,LW,h,"Damage Per Hit By Armour","Bench Over Mission Average");view:_card(cv,R,y,RW,h,"Saved Sessions")
 cv.z=5;armour_card(view,cv,data,cur,y);saved_card(view,cv,data,y)
 view:_sheet_end(cv)
end
