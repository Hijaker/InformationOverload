-- Deletion works on array membership first; rebuilding consumes the surviving
-- saved contributions. The source tracker is not changed until storage commits.
local D={}
-- id is one match's number or a list of them; each takes any other part of its own mission with it
function D.prepare(R,H,data,id,policy,logs,legacy)
 local want={};for _,v in ipairs(type(id)=="table"and id or {id})do want[v]=true end
 local selected={}
 for _,run in ipairs(data.run_history or {})do if want[run.id]then selected[#selected+1]=run end end
 if not selected[1]then return nil,type(id)=="table"and #id>1 and "These matches are no longer in history."or "This match is no longer in history."end
 local removed=0;local history={}
 for _,run in ipairs(data.run_history or {})do
  local rc=run.context or {};local same=false
  for _,s in ipairs(selected)do local c=s.context or {}
   if run==s or not logs and type(c.mission_instance)=="string"and c.mission_instance~=""and rc.mission_instance==c.mission_instance and rc.character==c.character and rc.class==c.class and rc.patch==c.patch then same=true;break end
  end
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
-- A Power DI match the player deletes is remembered, so Delete Backups never lets the next import bring it back; returns the undo.
D.POWERDI_DELETED="powerdi_deleted_v1"
function D.remember(storage,before,after)
 local function each(d,fn)for _,run in ipairs(d and d.run_history or {})do local i=run.imported;if type(i)=="table"and i.session~=nil then fn(i.session)end end end
 local left,out,changed={},{},false;each(after,function(id)left[id]=true end)
 local old=storage:get(D.POWERDI_DELETED)
 for id in pairs(type(old)=="table"and type(old.sessions)=="table"and old.sessions or {})do out[id]=true end
 each(before,function(id)if not left[id]and not out[id]then out[id]=true;changed=true end end)
 if not changed then return function()end end
 storage:set(D.POWERDI_DELETED,{sessions=out})
 return function()storage:set(D.POWERDI_DELETED,old or {sessions={}})end
end
-- A match deleted from its own page is deleted for good, so restoring an older backup that holds it leaves it out; by number and start time,
-- so a later match given the same number is not caught. Delete Backups forgets the list, as no backup can bring them back any more.
D.HISTORY_DELETED="history_deleted_v1"
function D.forget(storage,set,before,after)
 local left,out,changed={},{},false;for _,run in ipairs(after and after.run_history or {})do left[run.id or 0]=true end
 local old=storage:get(D.HISTORY_DELETED);old=type(old)=="table"and old or nil
 for k,v in pairs(old or {})do if type(v)=="table"then out[k]={};for id,at in pairs(v)do out[k][id]=at end end end
 out[set]=out[set]or {}
 for _,run in ipairs(before and before.run_history or {})do if run.id and not left[run.id]then out[set][tostring(run.id)]=tostring(run.started_at);changed=true end end
 if not changed then return function()end end
 storage:set(D.HISTORY_DELETED,out)
 return function()storage:set(D.HISTORY_DELETED,old or {})end
end
return D
