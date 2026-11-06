-- Information Overload: the Psykhanium's mission comparison, melee hits and damage per armour for each loadout taken into a counted match, kept on disk and moved by each match saved or deleted.
local mod=get_mod("information_overload")
local Overview=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_overview")
local S={KEY="psyk_summary_v1"}
-- Raise it when an update counts differently; a summary saved under another number is counted again.
S.COUNT_VERSION=2
local ARMOUR={"unarmored","armored","berserker","super_armor","resistant","disgustingly_resilient"}
local function copy(v)if type(v)~="table"then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
S.copy=copy
function S.loadout(run)local c=run and run.context or {};local L=c.operative_loadouts;return L and (L[tostring(c.character)]or L[c.character_name])or {}end
-- blessings and perks in name order, so the same ones in other slots are one loadout
local function sorted(s,sep)if type(s)~="string"then return ""end;local t={};for x in (s..sep):gmatch("(.-)"..sep:gsub("%p","%%%0"))do t[#t+1]=x end;table.sort(t);return table.concat(t,sep)end
function S.key(weapon,blessings,perks)return tostring(weapon).."|"..sorted(blessings,", ").."|"..sorted(perks," / ")end
function S.hits(run)
 local g=run and run.damage and run.damage.melee or {};local out={}
 for _,a in ipairs(ARMOUR)do local b=g[a];out[a]={dmg=b and b.total or 0,n=b and b.hits or 0}end
 local all=g.all;out.all={dmg=all and all.total or 0,n=all and all.hits or 0};return out
end
-- The matches Overview counts, unsorted.
function S.counted(data)local out={};for _,run in ipairs(data and data.run_history or {})do if Overview.accepted(run)then out[#out+1]=run end end;return out end
-- Which matches a summary holds, as a count and two sums of their numbers, so a change it missed shows without opening a file.
local function sig(runs)local n,a,b=0,0,0;for _,run in ipairs(runs)do local id=tonumber(run.id)or 0;n=n+1;a=a+id;b=b+id*id end;return n,a,b end
function S.matches(sum,runs)local n,a,b=sig(runs);return type(sum)=="table"and sum.version==S.COUNT_VERSION and sum.count==n and sum.ids==a and sum.sq==b end
function S.ready(sum,data)return S.matches(sum,S.counted(data))end
function S.new()return {version=S.COUNT_VERSION,count=0,ids=0,sq=0,loadouts={},weapons={}}end
function S.loaded(v)return type(v)=="table"and v.version==S.COUNT_VERSION and type(v.loadouts)=="table"and type(v.weapons)=="table"and v or nil end
local function bump(map,key,h,diff,sign)
 local e=map[key]or {runs=0,dmg=0,n=0,arm={},diffs={}};map[key]=e
 e.runs=e.runs+sign;e.dmg=e.dmg+sign*h.all.dmg;e.n=e.n+sign*h.all.n
 e.diffs[diff]=(e.diffs[diff]or 0)+sign;if e.diffs[diff]<=0 then e.diffs[diff]=nil end
 for _,a in ipairs(ARMOUR)do local v=h[a]
  if v.n~=0 or v.dmg~=0 then local b=e.arm[a]or {dmg=0,n=0};e.arm[a]=b;b.dmg=b.dmg+sign*v.dmg;b.n=b.n+sign*v.n;if sign<0 and b.n<=0 then e.arm[a]=nil end end
 end
 if e.runs<=0 then map[key]=nil end
end
-- sign 1 counts a match in and -1 takes it off; its file is read before anything changes, so a failed read changes nothing.
function S.add(sum,run,sign)
 local lo=S.loadout(run);local h=lo.melee and S.hits(run)
 local id=tonumber(run.id)or 0;sum.count=sum.count+sign;sum.ids=sum.ids+sign*id;sum.sq=sum.sq+sign*id*id
 if h then local diff=Overview.diff_label(run.context);bump(sum.loadouts,S.key(lo.melee,lo.melee_blessings,lo.melee_perks),h,diff,sign);bump(sum.weapons,lo.melee,h,diff,sign)end
 return sum
end
-- Takes off the counted matches that left and adds the ones that came; false when sum did not hold the matches before, or too many moved to read at once.
function S.move(sum,before,after)
 if not S.matches(sum,before)then return false end
 local was,now,gone,came={},{},{},{}
 for _,r in ipairs(before)do was[r]=true end;for _,r in ipairs(after)do now[r]=true;if not was[r]then came[#came+1]=r end end
 for _,r in ipairs(before)do if not now[r]then gone[#gone+1]=r end end
 if #gone+#came>8 then return false end
 for _,r in ipairs(gone)do S.add(sum,r,-1)end;for _,r in ipairs(came)do S.add(sum,r,1)end
 return S.matches(sum,after)and #gone+#came
end
-- A full count, a few matches a call; it waits at a match whose file cannot be read, since a delete later takes that match's hits off.
function S.job(data)local runs=S.counted(data);local goal=S.new();goal.count,goal.ids,goal.sq=sig(runs);return {runs=runs,i=0,sum=S.new(),goal=goal}end
function S.step(job,more)
 repeat local run=job.runs[job.i+1];if not run then return true end
  local ok,err=pcall(S.add,job.sum,run,1)
  if not ok then if job.told~=job.i then job.told=job.i;mod:error("I/O Psykhanium summary, match %s: %s",tostring(run.id),tostring(err))end;return false end;job.i=job.i+1
 until not more()
 return job.i>=#job.runs
end
-- The bench loadout's own missions when it has any, else every loadout of the same weapon.
function S.pick(sum,weapon,blessings,perks)
 if not sum or not weapon then return nil end
 local e=sum.loadouts[S.key(weapon,blessings,perks)];if e then return e,true end
 e=sum.weapons[weapon];if e then return e,false end
end
function S.diffs(e)local out={};for l in pairs(e and e.diffs or {})do out[#out+1]=l end;table.sort(out,function(a,b)if e.diffs[a]~=e.diffs[b]then return e.diffs[a]>e.diffs[b]end;return a<b end);return out end
-- The one copy the main file keeps. sum is nil while it is counted again in the hub.
function S.keeper(storage)
 local k={sum=S.loaded(storage:get(S.KEY))}
 function k.store(sum)k.sum=sum;k.job=nil;storage:set(S.KEY,sum)end
 function k.get(data)if S.ready(k.sum,data)then return k.sum end;return nil,k.job and {done=k.job.i,total=#k.job.runs}end
 function k.drop()k.store(nil)end
 -- After a change to the history: follows it, or drops the summary to be counted again.
 function k.follow(before,after)
  if not k.sum then return end
  local ok,moved=pcall(S.move,k.sum,before,after)
  if not ok then mod:error("I/O Psykhanium summary: %s",tostring(moved))end
  if not (ok and moved)then k.drop()elseif moved>0 then k.store(k.sum)end
 end
 -- For a change the caller saves with its own flush: the moved summary goes into storage now, and done(saved) keeps it or puts the old one back.
 function k.stage(before,after)
  if not k.sum then return function()end end
  local c=copy(k.sum);local ok,moved=pcall(S.move,c,before,after);if not ok then mod:error("I/O Psykhanium summary: %s",tostring(moved))end;c=ok and moved and c or nil;storage:set(S.KEY,c)
  return function(saved)if saved then k.sum=c;k.job=nil else storage:set(S.KEY,k.sum)end end
 end
 -- true once counted, and while the count waits at a match that cannot be read, so the warm-ups queued behind it still run
 function k.step(data,more)
  if S.ready(k.sum,data)then k.job=nil;return true end
  if k.job and not S.matches(k.job.goal,S.counted(data))then k.job=nil end
  k.job=k.job or S.job(data)
  if not S.step(k.job,more)then return k.job.told==k.job.i end
  k.store(k.job.sum);return true
 end
 return k
end
return S
