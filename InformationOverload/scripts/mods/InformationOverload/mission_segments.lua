-- Combine separately saved, non-overlapping observations of one mission.
local M={}
local function copy(v)if type(v)~="table"then return v end;local mt=getmetatable(v);if mt and mt.io_materialize then v=mt.io_materialize(v)end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function same(a,b)
 local x,y=a.context or {},b.context or {}
 return x.mission_instance and x.mission_instance~=""and x.mission_instance==y.mission_instance and x.character==y.character and x.class==y.class and x.patch==y.patch
end
local function counts(a,b)
 local out=copy(a or {});for k,v in pairs(b or {})do
  if type(v)=="table"then out[k]=counts(type(out[k])=="table"and out[k]or {},v)
  elseif type(v)=="number"then if k=="version"then out[k]=math.max(type(out[k])=="number"and out[k]or 0,v)else out[k]=(type(out[k])=="number"and out[k]or 0)+v end
  else out[k]=v end
 end;return out
end
local function append(a,b)local out=copy(a or {});for _,v in ipairs(b or {})do out[#out+1]=copy(v)end;return out end
local function maximum(a,b)local out=copy(a or {});for k,v in pairs(b or {})do if type(v)=="number"then out[k]=math.max(type(out[k])=="number"and out[k]or 0,v)else out[k]=copy(v)end end;return out end
function M.merge(first,last)
 assert(same(first,last),"Mission identity mismatch")
 local out=copy(last);out.started_at=first.started_at or last.started_at;out.resumed=true;out.interrupted=last.interrupted or nil;out.data_only=nil;out.full=false;out.run_kind=last.interrupted and "early_leave"or "rejoined";out.segments=(first.segments or 1)+(last.segments or 1)
 -- the rejoined part saw no start, and the mission's clock runs on across the rejoin, so it keeps the first part's 0:00
 if out.timing_origin==nil and type(first.timing_origin)=="number"then out.timing_origin=first.timing_origin end
 out.timing_diagnostics=copy(last.timing_diagnostics or first.timing_diagnostics)
 if out.timing_diagnostics and not out.timing_diagnostics.backend and first.timing_diagnostics then out.timing_diagnostics.backend=copy(first.timing_diagnostics.backend)end
 -- a marker either part saw keeps its first time on that clock, so a boss killed before the leave keeps its Final Boss Death
 local marks=copy(first.completion_markers or {})
 for k,v in pairs(last.completion_markers or {})do
  if type(v)~="number"then if marks[k]==nil then marks[k]=v end
  elseif type(marks[k])~="number"or v<marks[k]then marks[k]=v;marks[k.."_basis"]=last.completion_markers[k.."_basis"]end
 end
 out.completion_markers=next(marks)and marks or nil
 if M.timeline_merge then out.combat_timeline=copy(M.timeline_merge(first.combat_timeline,last.combat_timeline))end
 if M.measurements_merge then out.measurements=M.measurements_merge(first.measurements,last.measurements)end
 if M.experimental_merge then out.experimental=M.experimental_merge(first.experimental,last.experimental)end
 out.merged_segment_ids=append(first.merged_segment_ids or {first.id},last.merged_segment_ids or {last.id})
 if (first.context and first.context.detail_capture or {}).friendly_fire_sources~=1 or (last.context and last.context.detail_capture or {}).friendly_fire_sources~=1 then
  if out.context.detail_capture then out.context.detail_capture.friendly_fire_sources=nil end
 end
 for _,field in ipairs({"damage","incidents","friendly_fire_pairs","pickup_pairs","hyper_critical","haymaker","class_events","boss_kills","boss_operatives","enemy_lethality","operative_clutches","clutches","field_improvisation","leave_abuse","failed_leave_abuse"})do if first[field]or last[field]then out[field]=counts(first[field],last[field])end end
 -- the order teammates reached their counts in runs on across the rejoin rather than being added up
 local function reached(a,b,people)
  local top=0;for _,p in pairs(a or {})do if type(p)=="table"and type(p.reached)=="table"then for _,v in pairs(p.reached)do if type(v)=="number"and v>top then top=v end end end end
  for id,p in pairs(people or {})do local x,y=a and a[id],b and b[id];x=type(x)=="table"and x.reached;y=type(y)=="table"and y.reached
   if type(p)=="table"and (x or y)then local at={};for k,v in pairs(x or {})do at[k]=v end;for k,v in pairs(y or {})do at[k]=top+v end;p.reached=at end
  end
 end
 reached(first.incidents and first.incidents.members,last.incidents and last.incidents.members,out.incidents and out.incidents.members)
 reached(first.boss_operatives,last.boss_operatives,out.boss_operatives)
 for id,e in pairs(out.class_events or {})do local a,b=first.class_events and first.class_events[id],last.class_events and last.class_events[id];e.bursts=append(a and a.bursts,b and b.bursts)end
 if out.damage then out.damage.dot_version=math.max(first.damage and first.damage.dot_version or 0,last.damage and last.damage.dot_version or 0)end
 if (first.enemy_kill_counts or last.enemy_kill_counts)and M.party_merge then out.enemy_kill_counts=M.party_merge(first.enemy_kill_counts,last.enemy_kill_counts)end
 if (first.party_records or last.party_records)and M.party_merge then out.party_records=M.party_merge(first.party_records,last.party_records)end
 if first.team_damage or last.team_damage then
  out.team_damage=copy(last.team_damage or first.team_damage);out.team_damage.members=counts(first.team_damage and first.team_damage.members,last.team_damage and last.team_damage.members)
  -- weakspots and crits are whole only when each part that dealt damage counted them
  out.team_damage.hit_counts=(not first.team_damage or first.team_damage.hit_counts)and (not last.team_damage or last.team_damage.hit_counts)or nil
  out.team_damage.kinds=(not first.team_damage or first.team_damage.kinds)and (not last.team_damage or last.team_damage.kinds)or nil
 end
 for _,field in ipairs({"barrel_pops","lethality_events","departure_events","all_departures"})do if first[field]or last[field]then out[field]=append(first[field],last[field])end end
 -- The player's own leave in the first part ends in this rejoin, so it is not a departure.
 local own=0;for i=1,#(first.all_departures or {})do local e=out.all_departures[i];if e.personal and not e.returned then e.returned=true;own=1 end end
 out.kill_categories=counts(first.kill_categories,last.kill_categories);out.support=(first.support or last.support)and counts(first.support,last.support)or nil;out.kills=(first.kills or 0)+(last.kills or 0);out.players_left=math.max(0,(first.players_left or 0)-own)+(last.players_left or 0)
 out.failed=copy(first.failed or {});for k,v in pairs(last.failed or {})do if v then out.failed[k]=v end end;out.exploded=first.exploded or last.exploded
 -- An interrupted active clutch is not a verified successful episode.
 local function closed(clutch)if clutch then clutch.active=nil;clutch.active_kind=nil;clutch.standing=false;clutch.seen=last.victory and (clutch.episodes or 0)>0 or false end end
 closed(out.clutches);for _,p in pairs(out.operative_clutches or {})do closed(p.clutches)end
 out.records=maximum(first.records,last.records)
 -- Per-mission incident totals are not maxima; the merged incidents hold them.
 for k in pairs(out.records)do if type(k)=="string"and k:find("_mission$")and (k:find("^personal_")or k:find("^team_")or k:find("^teammate_")or k=="players_left_mission"or k=="mutant_charges_mission"or k=="clutch_episodes_mission")then out.records[k]=nil end end
 if first.records and first.records.pbb_ammo_mission or last.records and last.records.pbb_ammo_mission then out.records.pbb_ammo_mission=(first.records and first.records.pbb_ammo_mission or 0)+(last.records and last.records.pbb_ammo_mission or 0)end
 out.records.kills_mission=out.kills
 local all=out.damage and out.damage.total and out.damage.total.all;local shield=out.damage and out.damage.total and out.damage.total.void_shield
 if all then out.records.total_damage_mission=math.max(0,(all.total or 0)-(shield and shield.total or 0))end
 if first.contributions or last.contributions then
  -- a saved part may keep its record entries packed; they are read back before the two are joined
  local function part(c,field)if not c then return nil end;if M.entries and (field=="best"or field=="armour")then return M.entries(c,field)end;return c[field]end
  out.contributions={version=1};for _,field in ipairs({"best","armour","blo_contexts","increments","kill_segments"})do out.contributions[field]=append(part(first.contributions,field),part(last.contributions,field))end
 end
 for _,field in ipairs({"operative_roster","operative_identities","operative_loadouts","teammates"})do local values=copy(first.context and first.context[field]or {});for k,v in pairs(last.context and last.context[field]or {})do values[k]=copy(v)end;if next(values)then out.context[field]=values end end
 if first.performance or last.performance then
  out.performance=counts(first.performance,last.performance)
  for k,v in pairs(out.performance)do if type(v)=="number"and (k:find("max",1,true)or k:find("peak",1,true))then out.performance[k]=math.max(first.performance and first.performance[k]or 0,last.performance and last.performance[k]or 0)end end
  out.performance.lua_heap_kb_start=first.performance and first.performance.lua_heap_kb_start or last.performance and last.performance.lua_heap_kb_start;out.performance.lua_heap_kb_last=last.performance and last.performance.lua_heap_kb_last or first.performance and first.performance.lua_heap_kb_last
 end
 -- the joined match is a saved match, kept as one is when it saves
 if M.trim then M.trim(out)end
 return out
end
function M.coalesce(data,pause)
 local history=data.run_history or {};local changed=0
 for i=#history,1,-1 do
  if pause then pause()end
  local last=history[i]
  if last and type(last.victory)=="boolean"and not last.data_only and not last.merged_segment_ids then
   for j=i-1,1,-1 do local first=history[j]
    if first.interrupted and not first.hidden_contributions and first.victory~=true and same(first,last)then
     last=M.merge(first,last);history[i]=last;table.remove(history,j);i=i-1;changed=changed+1
    end
   end
  end
 end
 return changed
end
return M
