-- Information Overload: what a saved match keeps. The mission being played and its checkpoint keep everything; as a match saves, what
-- nothing reads leaves it and the large parts its pages read are packed, each by the module that owns that part, which reads it back.
-- Older saves are brought to the same shape once, in the background (save_tidy.lua).
return function(Timeline,Party,History)
 local S={VERSION=1}
 -- research blocks no longer recorded; the 9 Oct damage test also drew the squad's damage on the few matches older than team damage
 S.RETIRED={"experimental","talent_calibration","compact_damage_test","hyperviolence_poc","performance","damage_diagnostics","talent_test"}
 local MARKED={knocked_down=true,died=true}
 -- every hit packed, and of the streak events the downs and deaths the mission graph marks; the streaks stay as they were counted
 local function timeline(t)
  if type(t)~="table"or type(t.segments)~="table"then return t end
  for _,s in ipairs(t.segments)do if type(s)=="table"then
   if type(s.streak_events)=="table"then local keep={};for _,e in ipairs(s.streak_events)do if type(e)=="table"and e[3]=="reset"and MARKED[e[4]]then keep[#keep+1]=e end end;s.streak_events=keep end
   Timeline.pack(s)
  end end
  return t
 end
 -- of the timing record, the server's clear time; the clock samples were for working out mission timing
 local function timing(d)if type(d)~="table"then return d end;return d.backend and {backend=d.backend}or nil end
 -- damage tallies without their count of hits to health, which nothing reads
 local function damage(t,depth)
  if type(t)~="table"or depth>6 then return end
  if t.health_hits~=nil and t.total~=nil then t.health_hits=nil end
  for _,v in pairs(t)do damage(v,depth+1)end
 end
 -- a match cut and packed, and stamped so the tidy of older saves passes it by
 function S.trim(run)
  run.party_records=Party.trim(run.party_records)
  run.enemy_kill_counts=Party.pack_counts(run.enemy_kill_counts)
  run.combat_timeline=timeline(run.combat_timeline)
  run.contributions=History.pack(run.contributions)
  run.timing_diagnostics=timing(run.timing_diagnostics)
  damage(run.damage,0)
  for _,k in ipairs(S.RETIRED)do if run[k]~=nil then run[k]=nil end end
  run.trim_version=S.VERSION
  return run
 end
 return S
end
