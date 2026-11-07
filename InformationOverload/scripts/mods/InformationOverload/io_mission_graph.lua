-- Information Overload: a mission's own damage over time, on its page's Overview and Damage tabs.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Timeline=mod:io_dofile(base.."combat_timeline")
local TeamDamage=mod:io_dofile(base.."team_damage")
local C,F,commas,fmt=D.c,D.font,Overview.commas,Overview.compact
local G={}
local FAINT,FILL,GAP,BEST=D.rgba(221,183,99,.22),D.rgba(221,183,99,.08),D.rgba(169,191,153,.05),D.rgba(221,183,99,.09)
local ALL_LINE=D.rgba(216,229,207,.38)
-- not "Damage Over Time", the DoT kind on the same page
local TITLE="Damage Over The Mission"
local function mss(t)t=math.max(0,math.floor(t+.5));return string.format("%d:%02d",math.floor(t/60),t%60)end
local function nice(v)local p=10^math.floor(math.log10(math.max(1,v)));local m=v/p;return (m<=1 and 1 or m<=2 and 2 or m<=2.5 and 2.5 or m<=5 and 5 or 10)*p end
local function tick(v)if v>=1e6 then return (string.format("%.2f",v/1e6):gsub("0+$",""):gsub("%.$","")).."M"elseif v>=1000 then return (string.format("%.2f",v/1000):gsub("0+$",""):gsub("%.$","")).."K"end;return tostring(math.floor(v+.5))end
-- the player's own downs and deaths, and the final boss, in seconds from the mission's start
local function events(tl,o,boss)
 local out,last={},{}
 for _,s in ipairs(tl.segments)do local so=s.mission_origin_ms
  for _,e in ipairs(s.streak_events or {})do local k=e[3]=="reset"and (e[4]=="knocked_down"and "down"or e[4]=="died"and "death")
   if k then local t=(e[1]-so)/1000;if not last[k]or t-last[k]>1 then out[#out+1]={t=t,k=k};last[k]=t end end
  end
 end
 if type(boss)=="number"then out[#out+1]={t=(boss*1000-o)/1000,k="boss"}end
 table.sort(out,function(a,b)return a.t<b.t end);return out
end
-- one row a bucket from the start to the end; a bucket the game never reported and nobody watched is a gap, not a zero
-- one kind of the player's hits, sorted as the Damage tab's squad tally sorts them: Melee, Ranged, all damage over time or one kind of it
local function keeper(cat)
 if not cat or cat=="total"then return nil end
 return function(e,s)local k=TeamDamage.category({profile=s.profiles and s.profiles[e[4]],category=s.attack_types and s.attack_types[e[5]]})
  if cat=="dot"then return k:sub(1,4)=="dot_"end;return k==cat end
end
local function build(tl,width,keep,shift)
 local rows,spans,i0,t1={},{},(shift or 0)>0 and -1 or 0,0
 for si,b in ipairs(Timeline.buckets(tl,width,keep,shift))do local s=tl.segments[si];local o=b.origin_ms
  for _,r in ipairs(b.rows)do local row=rows[r.index]or {rep=0,use=0};rows[r.index]=row;row.rep=row.rep+r.reported;row.use=row.use+r.useful;i0=math.min(i0,r.index);t1=math.max(t1,(r.index+1)*width)end
  local iv=type(s.intervals)=="table"and #s.intervals>0 and s.intervals or {{s.start_ms,s.last_ms}}
  for _,v in ipairs(iv)do spans[#spans+1]={(v[1]-o)/1000,(v[2]-o)/1000}end
  t1=math.max(t1,(s.last_ms-o)/1000)
 end
 local n=math.max(1,math.ceil((t1-i0*width)/width));local seen={}
 for _,v in ipairs(spans)do local f=math.floor(v[1]/width);for i=math.max(i0,f),math.min(i0+n-1,math.max(f,math.ceil(v[2]/width)-1))do seen[i]=true end end
 local sh=(shift or 0)/1000;local out={width=width,t0=i0*width+sh,t1=(i0+n)*width+sh,n=n,i0=i0,rep=0,use=0,vmax=1,bars={}}
 for k=1,n do local i=i0+k-1;local r=rows[i]
  if r then out.bars[k]=r;out.rep=out.rep+r.rep;out.use=out.use+r.use;out.vmax=math.max(out.vmax,r.rep)elseif seen[i]then out.bars[k]={rep=0,use=0}end
 end
 return out
end
-- the mission's 0:00 in seconds, read as Times.marker reads it, so the graph and the page's rows keep one clock
function G.origin(run)return type(run.timing_origin)=="number"and run.timing_origin or 0 end
local cache=setmetatable({},{__mode="k"})
-- built once a timeline and width, and again only when it changes; keyed by the timeline and holding nothing of it, so a released match file takes its entry with it
function G.series(run,width,cat)
 local tl=run and run.combat_timeline
 if type(tl)~="table"or type(tl.segments)~="table"or #tl.segments==0 then return nil end
 -- a segment without its events, clock or coverage, as some older match files keep, is left out
 local use,n,o={},0,math.floor(G.origin(run)*1000+.5)
 for _,s in ipairs(tl.segments)do if type(s)=="table"and type(s.events)=="table"and type(s.start_ms)=="number"and type(s.last_ms)=="number"and type(s.coverage)=="table"then
  use[#use+1]=s;n=n+#s.events end end
 if #use==0 then return nil end
 local boss=run.completion_markers and run.completion_markers.boss_death
 local c=cache[tl];if not c or c.n~=n or c.o~=o or c.boss~=boss then c={n=n,o=o,boss=boss};cache[tl]=c end
 if c.broken then return nil end
 local key=cat and cat~="total"and cat..width or width
 if c[key]==nil then
  -- one clock for the whole run, the page's: a part kept on another origin or none, as a late join keeps, is placed on it and the time before it is a gap
  for i,s in ipairs(use)do if s.mission_origin_ms~=o then use[i]=setmetatable({mission_origin_ms=o},{__index=s})end end
  local data={segments=use}
  local keep=keeper(cat);local bk="best"..tostring(cat or "total")
  -- the best ten seconds first, so a bucket starts where it does and holds it whole, the tallest of them, rather than cutting it in two
  local ok,s=pcall(function()
   if c[bk]==nil then local b=Timeline.best_window(data,10,keep);local seg=b.segment and use[b.segment]
    c[bk]=b.damage>0 and seg and {damage=b.damage,from=b.first_ms-seg.mission_origin_ms,t0=(b.first_ms-seg.mission_origin_ms)/1000}or false end
   local best=c[bk];local s=build(data,width,keep,best and best.from%(width*1000)or 0);if s.rep<=0 then return false end
   if not c.events then c.events=events(data,o,boss)end
   s.events,s.best=c.events,best;return s end)
  if not ok then c.broken=true;mod:error("I/O mission graph: %s",tostring(s));return nil end;c[key]=s end
 return c[key]or nil
end
local function frame(cv,s,x,y,w,h)
 cv:edges(x,y,w,h,1,C.frame);for i=1,3 do cv:rect(x+1,y+h*i/4,w-2,1,C.line)end
 local step=nice(s.vmax*1.1/4);for i=0,4 do cv:text(tick(step*i),x-62,y+h-h*i/4-9,56,18,13,C.muted,"right")end
 for i=0,4 do cv:text(mss(s.t0+(s.t1-s.t0)*i/4),x+w*i/4-40,y+h+6,80,18,13,i==4 and C.value or C.muted,"center")end
 return step*4
end
local function marker(cv,k,x,y)
 if k=="down"then for i=0,4 do cv:rect(x-6+i*1.2,y-5+i*2,12-i*2.4,2,C.bad,true)end
 elseif k=="death"then cv:line(x-5,y-5,x+5,y+5,2.5,C.bad);cv:line(x+5,y-5,x-5,y+5,2.5,C.bad)
 else for i=-3,3 do local hw=7-math.abs(i)*2;cv:rect(x-hw,y+i*2-1,hw*2,2,C.gold,true)end end
end
local NAMES={down="Down",death="Death",boss="Final Boss Death"}
local OWN="Downs and deaths shown are only your own."
-- each mark keeps 15 px from the one before it, and a crowd at the end is moved back so none leaves the strip
local function strip(cv,s,x,y,w)cv:rect(x,y,w,1,C.line)
 local at,ks={},{};for _,e in ipairs(s.events)do if e.t>=s.t0 and e.t<=s.t1 then local mx=x+(e.t-s.t0)/(s.t1-s.t0)*w;if #at>0 then mx=math.max(mx,at[#at]+15)end;at[#at+1]=mx;ks[#ks+1]=e.k end end
 for i=#at,1,-1 do at[i]=math.max(x,math.min(at[i],i==#at and x+w or at[i+1]-15))end
 for i,mx in ipairs(at)do marker(cv,ks[i],mx,y)end
end
-- the marks, then a note that the downs and deaths are the player's own
local function key(view,cv,x,y)for _,k in ipairs({"down","death","boss"})do marker(cv,k,x+6,y+10);cv:text(NAMES[k],x+18,y,200,20,13,C.muted,"left",F.medium);x=x+18+view:_w(NAMES[k],13,F.medium)+30 end
 cv:text(OWN,x,y,400,20,13,C.muted,"left",F.medium)end
-- the tip for one bucket: its span, its damage and anything that happened in it, its time cut to the second so it falls inside the span
local function tip(view,s,k,x,y,w,h)
 if not view._tip then return end
 local b=s.bars[k];local a=s.t0+(k-1)*s.width;local lines={mss(a).." To "..mss(a+s.width)}
 if b then lines[#lines+1]="Damage: "..commas(b.rep);lines[#lines+1]="Useful: "..commas(b.use)else lines[#lines+1]="Not Recorded"end
 for _,e in ipairs(s.events)do if e.t>=a and e.t<a+s.width then lines[#lines+1]=NAMES[e.k]..": "..mss(math.floor(e.t))end end
 view:_tip("base",x,y,w,h,lines)
end
local function gaps(cv,s,X,y,h)
 local k=1;while k<=s.n do if not s.bars[k]then local j=k;while j<s.n and not s.bars[j+1]do j=j+1 end
  local a,b=X(s.t0+(k-1)*s.width),X(s.t0+j*s.width);cv:rect(a,y+1,b-a,h-2,GAP);if b-a>70 then cv:text("No Data",a,y,b-a,h,13,C.muted,"center",F.medium)end;k=j+1 else k=k+1 end end
end
-- Your Damage is the Damage tab's own figure for the player when the match has one
local function figures(view,cv,s,x,y,w,reported)
 local list={{"Your Damage",fmt(reported or s.rep)},{"Useful",fmt(s.use)},{"Best 10 Seconds",s.best and fmt(s.best.damage)or Overview.dash}}
 local fx=x+w-30;for i=#list,1,-1 do local l,v=list[i][1],list[i][2];local vw=math.max(view:_w(v,18),view:_w(l,13,F.medium))
  cv:text(v,fx-300,y+10,300,24,18,i==3 and C.gold or C.value,"right");cv:text(l,fx-300,y+32,300,18,13,C.muted,"right",F.medium);fx=fx-vw-34 end
end
G.overview_h=310
-- Overview: a wide card of ten second bars, useful in gold and the rest faint on top, with the downs, deaths and boss under it
function G.overview(view,cv,run,x,y,w,reported)
 local s=G.series(run,10);if not s then return nil end
 local h=G.overview_h;view:_card(cv,x,y,w,h,TITLE,"Every 10 Seconds");cv.z=5;figures(view,cv,s,x,y,w,reported)
 local px,py,pw,ph=x+86,y+66,w-120,150;local top=frame(cv,s,px,py,pw,ph)
 local function X(t)return px+(t-s.t0)/(s.t1-s.t0)*pw end
 local bw=pw/s.n;gaps(cv,s,X,py,ph)
 for k=1,s.n do local b=s.bars[k];local bx=px+(k-1)*bw+.5
  if b and b.rep>0 then local hr,hu=math.min(1,b.rep/top)*ph,math.min(1,b.use/top)*ph
   if hr>hu then cv:rect(bx,py+ph-hr,math.max(1,bw-1.5),hr-hu,FAINT)end;if hu>0 then cv:rect(bx,py+ph-hu,math.max(1,bw-1.5),hu,C.gold)end end
  tip(view,s,k,bx,py,bw,ph)
 end
 strip(cv,s,px,py+ph+38,pw);key(view,cv,px,py+ph+58)
 return h
end
G.damage_h=420
G.WIDTHS={{10,"10 Seconds"},{30,"30 Seconds"},{60,"1 Minute"}}
-- Damage tab: a line for useful damage and a faint one for all of it, a width switch, and the best ten seconds marked
-- cur, the Detail picked: a kind of damage draws the player's own hits of that kind, and another operative no graph, as only the player's own hits
-- are kept over time
function G.damage(view,cv,run,st,cur)
 local cat,kind="total",nil
 if cur then if cur.id~=nil then if not cur.you then return nil end elseif cur.value then cat=cur.value:sub(6);kind=cat~="total"and cur.label or nil end end
 st.gw=st.gw or 10;local s=G.series(run,st.gw,cat);if not s then return nil end
 local h=G.damage_h
 return {wide=true,h=h,draw=function(x,y,w)
  view:_card(cv,x,y,w,h,TITLE,kind and "Your Own Damage · "..kind or "Your Own Damage");cv.z=5
  local ox=x+w-26
  for i=#G.WIDTHS,1,-1 do local v,l=G.WIDTHS[i][1],G.WIDTHS[i][2];local bw=view:_w(l,14)+26;local on=v==st.gw;ox=ox-bw
   view:_ctl(cv,"base",ox,y+12,bw,28,function()st.gw=v end,{sel=on});cv:text(l,ox,y+12,bw,28,14,on and C.gold_hi or C.value,"center");ox=ox-6 end
  cv:text("Per",ox-108,y+12,100,28,14,C.muted,"right",F.medium)
  local px,py,pw,ph=x+90,y+70,w-126,236;local top=frame(cv,s,px,py,pw,ph)
  local function X(t)return px+(t-s.t0)/(s.t1-s.t0)*pw end;local function Y(v)return py+ph-math.min(1,v/top)*ph end
  gaps(cv,s,X,py,ph)
  if s.best then local a,b=math.max(px,X(s.best.t0)),math.min(px+pw,X(s.best.t0+10));cv:rect(a-4,py+1,b-a+8,ph-2,BEST)
   -- the label sits right of the band, or left of it when the band is near the plot's end
   if b+210<=px+pw then cv:text("Best 10 Seconds",b+10,py+4,200,18,13,C.gold,"left",F.medium)else cv:text("Best 10 Seconds",a-210,py+4,200,18,13,C.gold,"right",F.medium)end end
  local bw=pw/s.n;local prev
  for k=1,s.n do local b=s.bars[k];local cx=X(s.t0+(k-.5)*s.width)
   if b then if b.use>0 then cv:rect(px+(k-1)*bw,Y(b.use),bw,py+ph-Y(b.use),FILL)end
    if prev then cv:line(prev[1],Y(prev[2]),cx,Y(b.rep),1.4,ALL_LINE);cv:line(prev[1],Y(prev[3]),cx,Y(b.use),2,C.gold)
    -- a bucket with nothing watched either side gets a short flat stroke, so it still shows
    elseif not s.bars[k+1]then local a,z=cx-math.max(3,bw/4),cx+math.max(3,bw/4);cv:line(a,Y(b.rep),z,Y(b.rep),1.4,ALL_LINE);cv:line(a,Y(b.use),z,Y(b.use),2,C.gold)end
    prev={cx,b.rep,b.use}else prev=nil end
   tip(view,s,k,px+(k-1)*bw,py,bw,ph)
  end
  strip(cv,s,px,py+ph+52,pw)
  local kx,ky=x+36,y+h-34;for _,e in ipairs({{C.gold,"Useful Damage"},{ALL_LINE,"All Damage"}})do cv:rect(kx,ky+9,18,3,e[1]);cv:text(e[2],kx+26,ky,200,20,13,C.muted,"left",F.medium);kx=kx+26+view:_w(e[2],13,F.medium)+40 end
  key(view,cv,kx+20,ky)
 end}
end
return G
