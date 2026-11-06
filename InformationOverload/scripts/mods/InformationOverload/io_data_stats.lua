-- Information Overload: figures and chart pieces shared by Trends, Records and Weapons.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Records=mod:io_dofile(base.."records")
local Team=mod:io_dofile(base.."team_damage")
local Times=mod:io_dofile(base.."mission_times")
local H=mod:io_dofile(base.."history_presentation")
local C,rgba,DASH=D.c,D.rgba,Overview.dash
local K={dash=DASH,class_names=Overview.class_names}
K.c={bar=rgba(112,128,101),bar_h=rgba(142,160,128),win=rgba(221,183,99),loss=rgba(205,120,96),mate1=rgba(84,96,78),mate2=rgba(62,72,58),
 k1=rgba(74,163,107),k2=rgba(74,140,196),k3=rgba(184,134,42),k4=rgba(168,116,208),k5=rgba(208,100,78),down=rgba(224,164,143),death=rgba(196,88,63),
 grid=rgba(169,191,153,.11),band=rgba(169,191,153,.035),ref=rgba(216,229,207,.5),track=rgba(169,191,153,.1),blue=rgba(74,136,207),amber=rgba(185,138,46),
 meter=rgba(150,166,136),surf=rgba(10,14,10),head=rgba(13,17,13)}
K.ARM={{"unarmored","Unarmoured"},{"armored","Flak"},{"berserker","Maniac"},{"super_armor","Carapace"},{"resistant","Unyielding"},{"disgustingly_resilient","Infested"}}
K.ARM_NAME={unknown="Unknown"};for _,a in ipairs(K.ARM)do K.ARM_NAME[a[1]]=a[2]end
local commas=Overview.commas
function K.exact(n)return commas(math.floor(n+.5))end
K.mod=Overview.compact
local function trim(x)return (string.format("%.2f",x):gsub("0+$",""):gsub("%.$",""))end
function K.tick(v)if v==0 then return "0"elseif v>=1e6 then return trim(v/1e6).."M"elseif v>=1e3 then return trim(v/1e3).."K"end;return trim(v)end
function K.pc(f,d)return (string.format("%."..(d or 1).."f",f*100):gsub("%.0+$","")).."%"end
function K.plural(n,a,b)return n.." "..(n==1 and a or b or a.."s")end
function K.dm(day)return day:sub(9,10).."/"..day:sub(6,7)end
function K.dmy(day)return day:sub(9,10).."/"..day:sub(6,7).."/"..day:sub(1,4)end
function K.date(run)return run.started_at and H.timestamp(run.started_at)or DASH end
function K.mmss(s)local m=math.floor(s/60);return string.format("%d:%02d",m,math.floor(s-m*60))end
function K.nice(max,n)
 if not (max>0)then max=1 end
 local raw=max/(n or 4);local mag=10^math.floor(math.log10(raw));local q=raw/mag
 local step=(q<=1 and 1 or q<=2 and 2 or q<=2.5 and 2.5 or q<=5 and 5 or 10)*mag
 local top=math.ceil(max/step-1e-9)*step;local ticks={}
 for i=0,math.floor(top/step+1e-9)do ticks[#ticks+1]=i*step end
 return top,ticks
end
local function civil(day)local y,m,d=day:match("^(%d+)%-(%d+)%-(%d+)");y,m,d=tonumber(y),tonumber(m),tonumber(d);if m<=2 then y=y-1 end
 local era=math.floor(y/400);local yoe=y-era*400;local mp=(m+9)%12;local doy=math.floor((153*mp+2)/5)+d-1;return era*146097+yoe*365+math.floor(yoe/4)-math.floor(yoe/100)+doy end
local function uncivil(z)local era=math.floor(z/146097);local doe=z-era*146097;local yoe=math.floor((doe-math.floor(doe/1460)+math.floor(doe/36524)-math.floor(doe/146096))/365)
 local y=yoe+era*400;local doy=doe-(365*yoe+math.floor(yoe/4)-math.floor(yoe/100));local mp=math.floor((5*doy+2)/153);local d=doy-math.floor((153*mp+2)/5)+1;local m=mp<10 and mp+3 or mp-9
 if m<=2 then y=y+1 end;return string.format("%04d-%02d-%02d",y,m,d)end
function K.days(first,last)local out={};if not first then return out end;for z=civil(first),civil(last)do out[#out+1]=uncivil(z)end;return out end
function K.scoped(view)
 local tracker=view:_tracker();local s=view.scope;if not tracker or not s then return {}end
 local out={};for _,run in ipairs(Overview.runs(tracker))do local c=run.context
  if c.mode==s.mode and (s.diff=="all"or Overview.diff_label(c)==s.diff)and (s.all_patches or not s.patch or c.patch==s.patch)then out[#out+1]=run end end
 return out
end
function K.chron(view)local list=K.scoped(view);local out={};for i=#list,1,-1 do out[#out+1]=list[i]end;return out end
local function basis()local o=mod.io_display_options and mod.io_display_options()or {};return o.boss_map_timing and "boss"or "victory"end
function K.clear_time(run)
 local t=run.victory and Times.completion(run);if not t or type(t.seconds)~="number"then return nil end
 if t.source=="mission_clock"then local marks=run.completion_markers or {};local chosen=basis()=="boss"and marks.boss_death or marks.victory_request or marks.victory_transition
  return chosen and Times.marker(run,chosen)or nil end
 return t.seconds
end
local INFO=setmetatable({},{__mode="k"})
-- a saved mission's team damage is in its match file, so K.warm reads those a draw at a time into one table every page shares
mod.io_team_share=mod.io_team_share or setmetatable({},{__mode="k"})
local function share(run)
 local c=run.context;local o={};local data=run.team_damage and Team.from_run(run)
 if data and data.basis~="local_attack_snapshots"then
  local ops,total,me={},0,nil
  for id,p in pairs(data.members or {})do if id~="unknown_operative"then local u=Team.summary(data,id,"total").useful
   if u>0 or p.personal then ops[#ops+1]={id=id,v=u,me=p.personal==true or id==tostring(c.character)};total=total+u;if ops[#ops].me then me=ops[#ops]end end end end
  table.sort(ops,function(a,b)if a.me~=b.me then return a.me end;return a.v>b.v end)
  if total>0 and me then o.team={ops=ops,total=total,mine=me.v,share=me.v/total}end
  if me then local arm={};local p=data.members[me.id]
   for _,groups in pairs(p.groups or {})do for key,b in pairs(groups)do if key~="void_shield"and (b.reported or 0)>0 then
    local a=arm[key]or {t=key,dmg=0,useful=0,over=0,unc=key=="unknown"};arm[key]=a;a.dmg=a.dmg+(b.reported or 0);a.useful=a.useful+(b.useful or 0);a.over=a.over+(b.overkill or 0)end end end
   if next(arm)then o.armour=arm end end
 end
 return o
end
function K.info(run)
 local o=INFO[run]
 if not o then
  local c=run.context;o={win=run.victory==true,kills=type(run.kills)=="number"and run.kills or nil,day=H.date_key(run)or "0000-00-00",cls=c.class}
  local dmg,hits=Records.run_mission_damage(run);if dmg then o.dmg=dmg;o.fb=hits end
  local kc=run.kill_categories
  if type(kc)=="table"then local t={mh=kc.horde_melee or 0,rh=kc.horde_ranged or 0,el=kc.elite or 0,sp=kc.special or 0,bo=kc.boss or 0};t.sum=t.mh+t.rh+t.el+t.sp+t.bo
   t.no=o.kills and math.max(0,o.kills-t.sum)or 0;t.all=t.sum+t.no;o.types=t end
  -- a saved mission whose summary has a share of yours waits for K.warm to read its file; one without has none to read
  local mt=getmetatable(run)
  if mt and mt.io_damage_total~=nil and rawget(run,"team_damage")==nil then o.waiting=mt.io_team_damage_total~=nil or nil
  else local s=share(run);o.team,o.armour=s.team,s.armour end
  INFO[run]=o
 end
 if o.waiting then local s=mod.io_team_share[run];if s then o.team,o.armour,o.waiting=s.team,s.armour,nil end end
 return o
end
local function read(run)local ok,s=pcall(share,run);if not ok then mod:error("I/O team share: %s",tostring(s));s={}end;mod.io_team_share[run]=s;K.info(run)end
-- reads at most one match file a draw, asks for another draw while any wait, and returns how many still wait
function K.warm(view,runs)
 local left,wait=1,0
 for _,run in ipairs(runs)do if K.info(run).waiting then
  if left>0 then left=left-1;read(run)else wait=wait+1 end
 end end
 if wait>0 then view.io_dirty=true end
 return wait
end
-- reads ahead what K.warm would, one match file a call, for the hub to run so the open panel reads none; true once none waits,
-- and a history found with none waiting is not walked again until it grows; handed the match Run Slots just read, it reads that one or none
local warmed=setmetatable({},{__mode="k"})
function K.prewarm(runs,at)runs=runs or {};if warmed[runs]==#runs then return true end
 if at then if Overview.accepted(at)and K.info(at).waiting then read(at)end;return false end
 for _,run in ipairs(runs)do if Overview.accepted(run)and K.info(run).waiting then read(run);return false end end;warmed[runs]=#runs;return true end
function K.open_run(view,id)return function()view.io_params=view.io_params or {};view.io_params.run=id;view.io_tab="overview";view:_go("run")end end
function K.tabs(view,cv,list,cur,pick,y)
 local x=100;for _,t in ipairs(list)do local sel=cur==t[1];local lw=view:_w(t[2],16);local nw=t[3]and view:_w(t[3],14)+10 or 0;local w=lw+nw+30
  view:_ctl(cv,"base",x,y or D.row2,w,34,function()pick(t[1])end,{sel=sel});cv:text(t[2],x+15,y or D.row2,lw+4,34,16,sel and C.gold_hi or C.value)
  if t[3]then cv:text(t[3],x+15+lw+8,y or D.row2,nw,34,14,sel and C.gold or C.muted)end;x=x+w+8 end
 return x
end
function K.seg(view,cv,xr,y,list,cur,pick)
 local ws,total={},0;for i,o in ipairs(list)do ws[i]=view:_w(o[2],14)+22;total=total+ws[i]end
 local x=xr-total;cv.z=4;cv:rect(x-1,y-1,total+2,28,C.frame)
 for i,o in ipairs(list)do local on=o[1]==cur;cv.z=5;cv:rect(x,y,ws[i]-(i<#list and 1 or 0),26,on and C.fill_s or C.fill)
  cv:text(o[2],x,y,ws[i],26,14,on and C.gold_hi or C.label,"center")
  if not on then view:_hit("base",x,y,ws[i],26,function()pick(o[1])end,{bg=C.fill_h})end;x=x+ws[i]end
 return xr-total
end
function K.dd(view,cv,popup,id,x,y,w,label,value,options,pick,gold)
 local open=view.dd==id
 view:_ctl(cv,"base",x,y,w,34,function()view.dd=not open and id or nil end,{open=open})
 local lw=view:_w(label,16);cv:text(label,x+12,y,lw+4,34,16,C.label);cv:pick(value,value,x+20+lw,y,w-lw-56,gold)
 cv:chevron(x+w-24,y+13,"down",10,C.value)
 if not open then return end
 local pw=math.max(w,260);local px=math.min(x,D.right-pw);local py=y+38;local h=#options*30+2
 view:_panel(popup,px,py,pw,h)
 for i,o in ipairs(options)do local oy=py+1+(i-1)*30;local on=o.value==o.current
  if i>1 then popup:rect(px+1,oy,pw-2,1,C.line)end
  if on then popup:rect(px+1,oy,pw-2,30,C.on);popup:rect(px+1,oy,3,30,C.sel)end
  popup:text(o.label,px+12,oy,pw-100,30,16,on and C.gold_hi or C.value)
  if o.n then popup:text(o.n,px+pw-92,oy,80,30,14,C.muted,"right")end
  view:_hit("popup",px+1,oy,pw-2,30,function()view.dd=nil;pick(o.value)end,{bg=C.fill_h})
 end
end
function K.legend(view,cv,x,y,items)
 for _,it in ipairs(items)do
  if it[1]=="ln"then cv:rect(x,y+8,16,2,it[2],true);x=x+24
  elseif it[1]=="tk"then cv:rect(x+4,y+2,2,14,it[2],true);x=x+16
  elseif it[1]=="dot"then cv:rect(x+1,y+4,10,10,it[2],true);x=x+19
  else cv:rect(x,y+3,12,12,it[2],true);x=x+19 end
  local w=view:_w(it[3],14);cv:text(it[3],x,y,w+4,18,14,C.label);x=x+w+20
 end
 return x
end
function K.stats(view,cv,x,y,list)
 for _,s in ipairs(list)do local kw=view:_w(s[1],14);local vw=view:_w(s[2],20);local sw=s[3]and view:_w(s[3],14)+8 or 0
  cv:text(s[1],x,y,kw+4,18,14,C.muted);cv:text(s[2],x,y+20,vw+4,26,20,C.value)
  if s[3]then cv:text(s[3],x+vw+8,y+22,sw+4,24,14,C.muted)end;x=x+math.max(kw,vw+sw)+28 end
end
function K.table(view,cv,x,y,w,cols,rows,o)
 o=o or {};local rh=o.rh or 32
 cv:rect(x,y,w,30,K.c.head,true)
 for _,c in ipairs(cols)do if c[3]=="l"then cv:text(c[1],x+c[2],y,300,30,14,c.on and C.gold_hi or C.muted)else cv:text(c[1],x+c[2]-300,y,300,30,14,c.on and C.gold_hi or C.muted,"right")end
  if c.sort then local tw=view:_w(c[1],14);view:_hit("base",c[3]=="l"and x+c[2]or x+c[2]-tw,y,tw,30,c.sort,{under=C.value})end end
 cv:rect(x,y+29,w,1,C.frame,true);local ry=y+30;local sc=cv.sc
 -- a row outside the scrolled window draws only its rule, which keeps the sheet's height, and measures no text
 for _,r in ipairs(rows)do
  if r.grp then cv:text(r.grp,x+10,ry+4,400,26,14,C.gold);cv:rect(x,ry+29,w,1,C.frame,true);ry=ry+30
  elseif sc and (ry+sc.dy+rh<=sc.y0 or ry+sc.dy>=sc.y1)then cv:rect(x,ry+rh-1,w,1,C.line,true);ry=ry+rh
  else
   if r.act then view:_hit("base",x,ry,w,rh,r.act,{bg=C.row_h})end
   if r.under then r.under(ry)end
   for i,c in ipairs(cols)do local v=r[i];if v~=nil then
    local text,small,col=v,nil,i==1 and C.label or C.value;if type(v)=="table"then text,small,col=v[1],v[2],v[3]or col end
    local sw=small and view:_w(small,14)+8 or 0
    if c[3]=="l"then local tw=math.min(view:_w(text,16),(c.max or 500));cv:text(text,x+c[2],ry,tw+6,rh,16,col)
     if small then cv:text(small,x+c[2]+tw+8,ry,sw,rh,14,C.muted)end
    else if small then cv:text(small,x+c[2]-sw,ry,sw,rh,14,C.muted,"right")end;cv:text(text,x+c[2]-sw-300,ry,300,rh,16,col,"right")end
   end end
   cv:rect(x,ry+rh-1,w,1,C.line,true);ry=ry+rh
  end
 end
 return ry-y
end
function K.table_h(rows,rh)local h=30;for _,r in ipairs(rows)do h=h+(r.grp and 30 or rh or 32)end;return h end
function K.view_of(view,id)view.io_chart_view=view.io_chart_view or {};return view.io_chart_view[id]or "chart"end
function K.card(view,cv,x,y,w,h,id,title,sub,jump)
 view:_card(cv,x,y,w,h,title,sub,jump)
 if id then local cur=K.view_of(view,id);return K.seg(view,cv,x+w-13,y+13,{{"chart","Chart"},{"table","Table"}},cur,function(v)view.io_chart_view[id]=v end)end
 return x+w-13
end
function K.axis_y(cv,x0,x1,yof,ticks,fmt)for _,v in ipairs(ticks)do local yy=yof(v);cv:rect(x0,yy,x1-x0,1,v==0 and C.axis or K.c.grid,true);cv:text(fmt(v),x0-110,yy-9,100,18,14,C.muted,"right")end end
function K.day_axis(cv,list,x0,sw,ytop,ybot,ylab)
 local groups={};for i,r in ipairs(list)do local d=K.info(r).day;local g=groups[#groups];if g and g.day==d then g.b=i else groups[#groups+1]={day=d,a=i,b=i}end end
 local last=-1e9
 for k,g in ipairs(groups)do local xa,xb=x0+sw*(g.a-1),x0+sw*g.b;local cx=(xa+xb)/2
  if k%2==1 then cv:rect(xa,ytop,xb-xa,ybot-ytop,K.c.band)end
  if cx-21>=last+5 then cv:text(K.dm(g.day),cx-30,ylab-9,60,18,14,C.muted,"center");last=cx+21 end
 end
end
function K.stack(cv,x,yb,w,parts,scale)local acc=0;local k=0
 for _,p in ipairs(parts)do if p[1]>0 then local y0=yb-scale(acc)-(k>0 and 2 or 0);local y1=yb-scale(acc+p[1]);acc=acc+p[1];if y0-y1>=.5 then cv:rect(x,y1,w,y0-y1,p[2],true)end;k=k+1 end end
end
function K.hstack(cv,x,y,h,parts,scale)local acc=0;local k=0
 for _,p in ipairs(parts)do if p[1]>0 then local xa=x+scale(acc)+(k>0 and 2 or 0);local xb=x+scale(acc+p[1]);acc=acc+p[1];if xb-xa>=.5 then cv:rect(xa,y,xb-xa,h,p[2],true)end;k=k+1 end end
end
function K.dot(cv,cx,cy,r,c)cv:rect(cx-r-1,cy-r-1,2*r+2,2*r+2,K.c.surf,true);cv:rect(cx-r,cy-r,2*r,2*r,c,true)end
function K.empty(view,cv,y,title)view:_card(cv,D.left,y,D.width,92,title);return y+102 end
return K
