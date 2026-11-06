-- Read-only release-facing projection. Saved Match History remains authoritative.
local F={version=1}
local function copy(v)if type(v)~='table'then return v end;local mt=getmetatable(v);if mt and mt.io_materialize then v=mt.io_materialize(v)end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local fields={'id','context','victory','full','run_kind','started_at','completion_time','completion_markers','timing_origin','segments','resumed','records','damage','team_damage','party_records','enemy_kill_counts','boss_kills','boss_operatives','incidents','friendly_fire_pairs','pickup_pairs','team_psykers','field_improvisation','hyper_critical','haymaker','class_events','clutches','operative_clutches','kill_categories','all_departures','departure_events','combat_timeline','measurements'}
local function experimental(v)
 if not v then return end
 if v.segments then local out={segments={}};for _,s in ipairs(v.segments)do out.segments[#out.segments+1]=experimental(s)or {status='not_recorded'}end;return out end
 return {status=v.status,peril=copy(v.peril),peril_timeline=copy(v.peril_timeline),engagement_distance=copy(v.engagement_distance),distance_definitions=copy(v.distance_definitions)}
end
function F.accepted(run)return type(run.victory)=='boolean'and not run.data_only and not run.discarded and not run.hidden_contributions and not run.stats_excluded end
function F.build(runs,filters)
 local out={contract_version=F.version,filters=copy(filters or {}),matches={},excluded=0,deferred={'allied_peril_validation','general_modifier_snapshots','universal_projectile_linkage','talent_blessing_calculations','ehp'}}
 for _,run in ipairs(runs or {})do
  if F.accepted(run)then
   local row={};for _,k in ipairs(fields)do row[k]=copy(run[k])end;row.experimental=experimental(run.experimental)
   row.availability={combat_timeline=run.combat_timeline~=nil,team_damage=run.team_damage~=nil,party_records=run.party_records~=nil,measurements=run.measurements~=nil,experimental=run.experimental~=nil}
   out.matches[#out.matches+1]=row
  else out.excluded=out.excluded+1 end
 end
 return out
end
return F
