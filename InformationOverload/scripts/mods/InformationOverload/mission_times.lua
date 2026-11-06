local F={}
function F.parse(text)
 if type(text)~="string"then return end
 local m,s=text:match("^%s*(%d+):(%d%d%.?%d*)%s*$")
 if not m or tonumber(s)>=60 then return end
 local n=tonumber(m)*60+tonumber(s);if n>0 and n<=86400 then return n end
end
function F.format(n)local ms=math.floor(math.max(0,n)*1000+.5);return string.format("%d:%02d.%03d",math.floor(ms/60000),math.floor(ms/1000)%60,ms%1000)end
function F.backend(run)
 local d=run.timing_diagnostics;local b=d and d.backend;local c=run.context or {}
 if not b or not c.mission_instance or b.session_id~=c.mission_instance then return end
 for _,field in ipairs({"game_mode_completion_time_seconds","play_time_seconds"})do local n=b[field]
  if type(n)=="number"and n==n and n>0 and n<=86400 then return {seconds=n,source="backend",field=field}end
 end
end
function F.completion(run)return F.backend(run)or run.completion_time end
local function partial40(run)local c=run.context or {};return run.full==false and c.mode=="havoc"and tonumber(c.difficulty)==40 end
-- a backend time counts only for a run the clock or a typed time could count for, and never for one Counting leaves out
function F.counts(run,t)
 if t.source=="backend"then return (run.full==true or partial40(run))and not run.stats_excluded end
 return run.full==true and t.source=="mission_clock"or t.source=="manual"and partial40(run)
end
-- of one map's clears, one the server timed ranks ahead of one the mission clock or a typed time gave, as their seconds cannot be compared
function F.faster(a,b)
 local x,y=a.completion_time,b.completion_time
 if (x.source=="backend")~=(y.source=="backend")then return x.source=="backend"end
 return x.seconds<y.seconds
end
function F.marker(run,n)return type(n)=="number"and math.max(0,n-(run.timing_origin or 0))or nil end
function F.build(history,mode,basis)
 local out={};local totals={}
 for _,run in ipairs(history or {})do local c=run.context or {};local t=F.completion(run)
  if t and t~=run.completion_time then run=setmetatable({completion_time=t},{__index=run})end
  if t and t.source=="mission_clock"then
   local marks=run.completion_markers or {};local chosen=basis=="boss"and marks.boss_death or marks.victory_request or marks.victory_transition
   if chosen then run=setmetatable({completion_time={seconds=F.marker(run,chosen),source="mission_clock"}},{__index=run});t=run.completion_time else t=nil end
  end
  if c.mode==mode and run.victory==true and not run.data_only and not run.discarded and not run.hidden_contributions and not c.training_history_test and t and type(t.seconds)=="number"and t.seconds>0 and t.seconds<=86400 and F.counts(run,t)then
   local difficulty=tostring(c.difficulty);local map=c.mission_name
   if map then
    totals[difficulty]=totals[difficulty]or {};out[difficulty]=out[difficulty]or {}
    local total=totals[difficulty][map]
    -- Backend durations and the old intro/outro-derived times use different origins.
    -- Prefer backend samples for this map; never mix their averages or bests.
    if not total or t.source=="backend"and total.source~="backend"then total={sum=0,count=0,source=t.source};totals[difficulty][map]=total;out[difficulty][map]=nil end
    if total.source~="backend"or t.source=="backend"then
     total.sum=total.sum+t.seconds;total.count=total.count+1;local old=out[difficulty][map]
     if not old or t.seconds<old.completion_time.seconds then out[difficulty][map]=run end
    end
   end
  end
 end
 for difficulty,maps in pairs(out)do for map,run in pairs(maps)do local total=totals[difficulty][map];maps[map]=setmetatable({average_time=total.sum/total.count,time_samples=total.count},{__index=run})end end
 return out
end
return F
