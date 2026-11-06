-- Information Overload: the bench's damage per second, read from a session's combat timeline. Shield hits are left out, as the timeline's own windows leave them.
local mod=get_mod("information_overload")
local Timeline=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/combat_timeline")
local B={}
-- Kept on mod because io_dofile reruns this file for every page.
mod.io_bench_live=mod.io_bench_live or setmetatable({},{__mode="k"})
mod.io_bench_runs=mod.io_bench_runs or setmetatable({},{__mode="k"})
local function shield(e)return math.floor(e[7]/4)%2==1 end
local function last(tl)local segs=tl and tl.segments;return segs and segs[#segs]end
function B.has_events(tl)for _,s in ipairs(tl and tl.segments or {})do if #s.events>0 then return true end end;return false end
-- damage per second over the w seconds up to the last heartbeat, read back from the newest hit
function B.window(tl,w)
 local s=last(tl);if not s then return 0 end
 local ev,from,sum=s.events,s.last_ms-w*1000,0
 for i=#ev,1,-1 do local e=ev[i];if e[1]<=from then break end;if not shield(e)then sum=sum+e[2]end end
 return sum/w
end
function B.last_hit(tl)
 local segs=tl and tl.segments or {};local seen=0
 for si=#segs,1,-1 do local ev=segs[si].events
  for i=#ev,1,-1 do local e=ev[i];if not shield(e)then return e[2]end;seen=seen+1;if seen>=2000 then return nil end end
 end
end
-- the w second window every step over the last span seconds, one run per observed stretch, never before the segment began
function B.live(tl,span,w,step)
 local s=last(tl);if not s then return {}end
 local now,wm,sm=s.last_ms,w*1000,step*1000;local t0=now-span*1000
 local ev=s.events;local lo=#ev+1
 while lo>1 and ev[lo-1][1]>t0-wm do lo=lo-1 end
 local iv=s.intervals or {{s.start_ms,now}};local k=#iv
 while k>1 and iv[k-1][2]>=t0 do k=k-1 end
 local times,t={},math.ceil(math.max(t0,s.start_ms)/sm)*sm
 while t<now do times[#times+1]=t;t=t+sm end;times[#times+1]=now
 local runs,cur,a,b,sum={},nil,lo,lo,0
 for _,t in ipairs(times)do
  while b<=#ev and ev[b][1]<=t do local e=ev[b];if not shield(e)then sum=sum+e[2]end;b=b+1 end
  while a<b and ev[a][1]<=t-wm do local e=ev[a];if not shield(e)then sum=sum-e[2]end;a=a+1 end
  while k<#iv and iv[k][2]<t do k=k+1 end
  if t>=iv[k][1]and t<=iv[k][2]then if not cur or cur.k~=k then cur={k=k};runs[#runs+1]=cur end;cur[#cur+1]={t,sum/w}else cur=nil end
 end
 return runs,t0,now
end
-- one point a second over a 6 second window, the whole session from its first hit; a later segment follows on from the one before, and a gap in observation breaks the run
function B.series(tl,w,step)
 w,step=w or 6,step or 1;local wm,sm,runs,off=w*1000,step*1000,{},0
 for _,s in ipairs(tl and tl.segments or {})do local ev=s.events
  if #ev>0 then local from,to=ev[1][1],math.min(s.last_ms,ev[#ev][1]+wm);local run,a,b,sum=nil,1,1,0;local iv=s.intervals or {{s.start_ms,s.last_ms}};local k=1
   for t=from+sm,to,sm do
    while b<=#ev and ev[b][1]<=t do local e=ev[b];if not shield(e)then sum=sum+e[2]end;b=b+1 end
    while a<b and ev[a][1]<=t-wm do local e=ev[a];if not shield(e)then sum=sum-e[2]end;a=a+1 end
    while k<#iv and iv[k][2]<t do k=k+1 end
    if t>=iv[k][1]and t<=iv[k][2]then if not run then run={};runs[#runs+1]=run end;run[#run+1]={off+(t-from)/1000,sum/w}else run=nil end
   end
   off=off+(to-from)/1000
  end
 end
 return runs,off
end
-- the shape for a saved row: the series averaged into n bins, scaled to its own peak
function B.spark(runs,n)
 local all={};for _,r in ipairs(runs)do for _,p in ipairs(r)do all[#all+1]=p[2]end end
 if #all<2 then return nil end
 local out,mx={},0
 for i=0,n-1 do local a=math.floor(i*#all/n)+1;local b=math.max(a,math.floor((i+1)*#all/n));local sum=0
  for j=a,b do sum=sum+all[j]end;out[i+1]=sum/(b-a+1);mx=math.max(mx,out[i+1])end
 for i,v in ipairs(out)do out[i]=mx>0 and v/mx or 0 end
 return out
end
local function digest(tl)local runs,dur=B.series(tl);return {best=Timeline.best_window(tl,10),runs=runs,dur=dur,spark=B.spark(runs,28)}end
-- the session under way, worked out again only when a hit lands
function B.live_digest(tl)
 local s=last(tl);if not s then return nil end
 local c=mod.io_bench_live[tl]
 if not c or c.segs~=#tl.segments or c.n~=#s.events then local ok,made=pcall(digest,tl)
  if not ok then mod:error("I/O bench: %s",tostring(made));made={broken=true}end;c=made;c.segs=#tl.segments;c.n=#s.events;mod.io_bench_live[tl]=c end
 return not c.broken and c or nil
end
-- a saved session decodes its file once; one that cannot be read keeps the dash
function B.read(run)
 local c=mod.io_bench_runs[run];if c then return c end
 local ok,made=pcall(function()local tl=run.combat_timeline;return tl and B.has_events(tl)and digest(tl)or {none=true}end)
 if not ok then mod:error("I/O bench: %s",tostring(made));made={none=true}end
 mod.io_bench_runs[run]=made;return made
end
function B.cached(run)local c=mod.io_bench_runs[run];return c and not c.none and c or nil end
-- reads at most one saved session a draw, and asks for another draw while any wait
function B.warm(view,runs)
 local left=1
 for _,run in ipairs(runs)do if not mod.io_bench_runs[run]then if left==0 then view.io_dirty=true;return end;left=0;B.read(run)end end
end
return B
