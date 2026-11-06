-- Local report chronology. No game globals, no per-event buff scans.
-- Times are integer milliseconds on the gameplay clock; segments never bridge a reconnect.
local mod=get_mod("information_overload")
local KillStreaks=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/kill_streaks")
local HitStreak,HealthStreak=KillStreaks.hit,KillStreaks.health
local T={version=2,max_events=250000}
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<math.huge end
function T.new(t,origin)
 if not finite(t)then return nil end
 return {version=2,segments={{clock="gameplay",start_ms=math.floor(t*1000+.5),last_ms=math.floor(t*1000+.5),mission_origin_ms=finite(origin)and math.floor(origin*1000+.5)or nil,events={},sequence=0,streak_events={},intervals={{math.floor(t*1000+.5),math.floor(t*1000+.5)}},profiles={},attack_types={},results={},coverage={reports=0,dropped=0,clock_errors=0,streak_events_dropped=0,observation_gaps=0},health_streak=HealthStreak.new(),streak=HitStreak.new()}}}
end
local function segment(data)return data.segments[#data.segments]end
local intern_cache=setmetatable({},{__mode="k"})
local function intern(values,value)
 value=tostring(value or "unknown")
 local cache=intern_cache[values]
 if not cache then cache={};for i,v in ipairs(values)do cache[v]=i end;intern_cache[values]=cache end
 if cache[value]then return cache[value]end
 values[#values+1]=value;cache[value]=#values;return #values
end
function T.touch(data,t,origin)
 local s=segment(data)
 if not finite(t)or t*1000+.5<s.last_ms then s.coverage.clock_errors=s.coverage.clock_errors+1;return end
 s.last_ms=math.floor(t*1000+.5)
 if finite(origin)then s.mission_origin_ms=math.floor(origin*1000+.5)end
 return s.last_ms
end
-- Only frame heartbeats establish continuous observed spans; reports alone do not.
function T.heartbeat(data,t,origin)
 local s=segment(data)
 if not finite(t)then return end
 local ms=math.floor(t*1000+.5)
 if ms<s.last_ms then
  s.coverage.clock_errors=s.coverage.clock_errors+1
  local fresh=T.new(t,origin);local next_segment=fresh.segments[1]
  next_segment.boundary="clock_reset";data.segments[#data.segments+1]=next_segment
  return
 end
 T.touch(data,t,origin)
 s.intervals=s.intervals or {{ms,ms}}
 local interval=s.intervals[#s.intervals]
 if ms-interval[2]>1000 then
  s.coverage.observation_gaps=(s.coverage.observation_gaps or 0)+1
  s.intervals[#s.intervals+1]={ms,ms}
  T.reset(data,t,"observation_gap")
 else interval[2]=ms end
end
function T.hit(data,t,e)
 local s=segment(data);local ms=T.touch(data,t)
 if not ms or not finite(e.damage)or e.damage<0 then return false end
 s.coverage.reports=s.coverage.reports+1
 if #s.events>=T.max_events then s.coverage.dropped=s.coverage.dropped+1;return false end
 local useful=finite(e.useful)and e.useful>=0 and e.useful or false
 local flags=(e.weakspot and 1 or 0)+(e.critical and 2 or 0)+(e.shield and 4 or 0)
 -- Stable tuple schema: ms, reported damage, useful-or-false, profile, attack type, result, flags.
 s.sequence=(s.sequence or 0)+1
 s.events[#s.events+1]={ms,e.damage,useful,intern(s.profiles,e.profile),intern(s.attack_types,e.attack_type),intern(s.results,e.result),flags,s.sequence}
 return true
end
local function streak_event(data,t,kind,cause)
 local s=segment(data);s.streak_events=s.streak_events or {}
 local ms=t~=nil and T.touch(data,t)or s.last_ms
 if not ms then return end
 if #s.streak_events>=T.max_events then s.coverage.streak_events_dropped=(s.coverage.streak_events_dropped or 0)+1;return end
 s.sequence=(s.sequence or 0)+1
 s.streak_events[#s.streak_events+1]={ms,s.sequence,kind,cause or "unknown"}
end
-- Compatibility entry points; each metric owns its saved field and reduction rules.
function T.kill(data,t)
 local s=segment(data);HealthStreak.kill(s);HitStreak.kill(s);streak_event(data,t,"kill")
end
function T.reset_health(data,t,cause)
 if HealthStreak.reset(segment(data))then streak_event(data,t,"health_reset",cause)end
end
function T.reset(data,t,cause)
 if HealthStreak.resets_with_hit(cause)then T.reset_health(data,t,cause)end
 HitStreak.reset(segment(data));streak_event(data,t,"reset",cause)
end
function T.merge(a,b)
 if not a then return b end;if not b then return a end
 local out={version=2,segments={}}
 -- Input tables are read only; parent history merger deep-copies the result.
 for _,data in ipairs({a,b})do for _,s in ipairs(data.segments or {})do out.segments[#out.segments+1]=s end end
 return out
end
-- Derive compact graph rows on demand, never store a duplicate bucket truth.
-- keep, when given, picks which hits count
function T.buckets(data,width,keep)
 width=width or 10;assert(finite(width)and width>0,"Positive bucket width required")
 local out={}
 for si,s in ipairs(data.segments or {})do
  local rows={};local origin=s.mission_origin_ms or s.start_ms
  for _,e in ipairs(s.events)do
   if math.floor(e[7]/4)%2==0 and (not keep or keep(e,s))then
    local index=math.floor((e[1]-origin)/(width*1000))
    local row=rows[index]or {index=index,reported=0,useful=0,useful_unknown_reports=0,reports=0};rows[index]=row
    row.reported=row.reported+e[2];row.reports=row.reports+1
    if e[3]==false then row.useful_unknown_reports=row.useful_unknown_reports+1 else row.useful=row.useful+e[3]end
   end
  end
  local sorted={};for _,row in pairs(rows)do sorted[#sorted+1]=row end;table.sort(sorted,function(a,b)return a.index<b.index end)
  out[#out+1]={segment=si,origin_ms=origin,width_seconds=width,rows=sorted,intervals=s.intervals,capture_error_free=s.coverage.dropped==0 and s.coverage.clock_errors==0 and (s.coverage.unresolved_target_reports or 0)==0}
 end
 return out
end
-- Half-open ten-second windows, reported damage excluding shields. Segment-local only.
function T.best_window(data,seconds,keep)
 seconds=seconds or 10;assert(finite(seconds)and seconds>0,"Positive window required")
 local best={damage=0,seconds=seconds,dps=0,complete=true,completeness_basis="tracked_capture_errors_only; inspect observation intervals"}
 for si,s in ipairs(data.segments or {})do
  if s.coverage.dropped>0 or s.coverage.clock_errors>0 or (s.coverage.unresolved_target_reports or 0)>0 or (s.coverage.observation_gaps or 0)>0 then best.complete=false end
  local events={};for _,e in ipairs(s.events)do if math.floor(e[7]/4)%2==0 and (not keep or keep(e,s))then events[#events+1]=e end end
  local first,sum=1,0
  for i,e in ipairs(events)do
   sum=sum+e[2]
   while first<=i and e[1]-events[first][1]>=seconds*1000 do sum=sum-events[first][2];first=first+1 end
   if sum>best.damage then best.damage=sum;best.dps=sum/seconds;best.segment=si;best.first_ms=events[first][1];best.last_ms=e[1]end
  end
 end
 return best
end
-- Existing query API retained for mission pages, exports and integrations.
function T.best_by_map(runs)return HitStreak.best_by_map(runs,T.best_streak)end
function T.replay_streak(s)return HitStreak.replay(s)end
function T.best_health_streak(run)return HealthStreak.best(run)end
function T.best_streak(run)return HitStreak.best(run)end
return T
