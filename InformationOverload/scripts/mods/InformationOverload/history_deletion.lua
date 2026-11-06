-- Deletion works on array membership first; rebuilding consumes the surviving
-- saved contributions. The source tracker is not changed until storage commits.
local D={}
function D.prepare(R,H,data,id,policy,logs,legacy)
 local selected
 for _,run in ipairs(data.run_history or {})do if run.id==id then selected=run;break end end
 if not selected then return nil,"This match is no longer in history."end
 local c=selected.context or {};local removed=0;local history={}
 for _,run in ipairs(data.run_history or {})do
  local rc=run.context or {}
  local same=run==selected or not logs and type(c.mission_instance)=="string"and c.mission_instance~=""and rc.mission_instance==c.mission_instance and rc.character==c.character and rc.class==c.class and rc.patch==c.patch
  if same then removed=removed+1 else history[#history+1]=run end
 end
 local source={};for k,v in pairs(data)do source[k]=v end;source.run_history=history
 source.history_policy_revision=(data.history_policy_revision or 0)+1
 -- Patches with no saved matches exist only in the baseline, so their part of it is kept.
 local baseline=H.legacy(R,legacy)
 if logs then return source,baseline,removed end
 local rebuilt=H.rebuild(R,baseline,source,policy,true)
 -- H.rebuild shares read-only source rows. Outcome policy remains a view filter.
 rebuilt.history_policy_revision=source.history_policy_revision
 return rebuilt,baseline,removed
end
return D
