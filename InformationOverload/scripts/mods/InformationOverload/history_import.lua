local I={}
function I.read(storage,pause)
 assert(storage.a.list,"Local folder scanning is unavailable")
 local files=storage.a.list("reconstruction_import/");table.sort(files)
 local byid={};local count=0
 for _,path in ipairs(files)do
  if pause then pause()end
  -- spread over frames, a big file is read, decoded and unpacked over several slices
  local full=pause and storage.read_sliced and storage:read_sliced(path,pause)or nil
  local run=assert(storage.history_load and storage:history_load({file=path},full)or full or storage:read(path),"Unreadable import file")
  assert(type(run.id)=="number"and run.id>0 and run.id%1==0 and type(run.context)=="table"and (run.context.mode=="havoc"or run.context.mode=="non-havoc")and type(run.context.patch)=="string"and type(run.context.class)=="string","The folder contains a file that is not a saved match")
  -- SoloPlay and the Psykhanium keep histories of their own; a Psykhanium trial Match History keeps hidden is its own
  local c=run.context;assert(c.solo~=true and not c.psykhanium_log and not c.training_history_test and (c.difficulty~="psykhanium"or run.hidden_contributions),"The folder holds a SoloPlay or Psykhanium match, and Import only brings in online matches")
  local old=byid[run.id]
  if old then
   local a,b=old.run.context,run.context
   assert(a.patch==b.patch and a.character==b.character and a.class==b.class and a.mission_instance==b.mission_instance,"Conflicting matches share the same record number")
  else count=count+1 end
  -- Native match filenames sort by monotonically increasing snapshot revision.
  local revision=tonumber(path:match("%-(%d+)%.json$"))
  if old then
   if revision and old.revision then
    if revision==old.revision then assert(storage.equal and storage.equal(old.run,run)or old.path==path,"Conflicting copies of a match revision")end
   else assert(storage.equal and storage.equal(old.run,run),"Conflicting match copies have no snapshot revision")end
  end
  if not old or revision and (not old.revision or revision>old.revision)then byid[run.id]={run=run,path=path,revision=revision}end
 end
 assert(count>0,"No Match History files were found in reconstruction_import")
 local history={};for _,entry in pairs(byid)do history[#history+1]=entry.run end
 table.sort(history,function(a,b)return a.id<b.id end);return history
end
function I.rebuild(R,H,data,policy,history,M,legacy,pause)
 local source={schema=R.schema or 1,rows={},run_history=history or data.run_history or {},run_sequence=0,friend_tracking=H.clone(data.friend_tracking),friend_tracking_revision=data.friend_tracking_revision,history_policy_revision=(data.history_policy_revision or 0)+1,character_names=H.clone(data.character_names)}
 for _,run in ipairs(source.run_history)do source.run_sequence=math.max(source.run_sequence,run.id or 0)end
 -- new stats groups, the old damage reset and a pending leave are placed by this PC's match numbers, so only a rebuild keeps them
 if not history then source.run_sequence=math.max(source.run_sequence,data.run_sequence or 0);for _,k in ipairs({"history_patch_carries","history_damage_reset_after","self_leave_pending"})do source[k]=H.clone(data[k])end end
 local rows={};for _,run in ipairs(source.run_history)do rows[#rows+1]=run end;source.run_history=rows
 source.record_credits=R.record_credits and R.record_credits(data.rows)
 return I.replay(R,H,M,source,policy,H.legacy(R,legacy),pause)
end
-- Rebuilds a source from its own matches; Rebuild, Import and Restore pass the baseline of statistics from before match history.
function I.replay(R,H,M,source,policy,baseline,pause)
 local rows=source.run_history
 local absorbed={};for _,run in ipairs(rows)do for _,id in ipairs(run.merged_segment_ids or {})do if id~=run.id then absorbed[id]=true end end end
 local keep={};for _,run in ipairs(rows)do if not absorbed[run.id]then keep[#keep+1]=run end end;source.run_history=keep
 if M then M.coalesce(source,pause)end
 baseline=baseline or {schema=R.schema or 1,rows={},run_sequence=0,history_legacy_patches={}}
 local rebuilt=H.rebuild(R,baseline,source,policy,true,pause);return rebuilt,baseline
end
-- A match this PC knows, in its history or a backup, takes the number it has here and any End Screen moment only the catalog holds.
-- Matches new to this PC keep their numbers unless one is at or below the highest this PC has used, a missing match file's included; then all are numbered after it, in order.
-- So a restore never meets one match under two numbers, or two matches under one.
function I.renumber(storage,history,current,seq,pause)
 local KEY="lifetime_records_v1";local floor,known,unread=seq or 0,{},{}
 local function top(id)floor=math.max(floor,tonumber(id)or 0)end
 local function key(run)local c=run.context or {};return table.concat({tostring(c.character),tostring(c.patch),tostring(run.started_at),tostring(c.mission_instance)},"|")end
 local function mark(run)local m=run.completion_markers;return type(m)=="table"and m.end_screen or nil end
 local function know(id,run,m)id=tonumber(id);if not id then return end;local k=key(run);known[k]=known[k]or {};table.insert(known[k],{id=id,parts=run.merged_segment_ids,mark=m})end
 local function lost(list)for _,r in ipairs(list or {})do if r.key==KEY and r.match then top(r.id)end end end
 for _,run in ipairs(current or {})do top(run.id);know(run.id,run,mark(run))end
 lost(storage.manifest and storage.manifest.missing);lost(storage.skipped)
 for _,b in ipairs(storage.backups and storage:backups()or {})do top(b.seq and b.seq.lifetime);lost(b.missing)
  local entry=b.entries and b.entries[KEY]
  for _,desc in ipairs(entry and entry.history or {})do top(desc.id);local p=tostring(desc.patch);unread[p]=unread[p]or {};table.insert(unread[p],desc)end
 end
 -- a backup's match files are read only for a match the history does not hold, and only those of its patch
 local function find(run)local k=key(run)
  if not known[k]then for _,p in ipairs({tostring(run.context.patch),"nil"})do
   for _,desc in ipairs(unread[p]or {})do if pause then pause()end;local ok,v=pcall(storage.read,storage,desc.file);if ok and type(v)=="table"then know(desc.id,v,desc.end_screen or mark(v))end end;unread[p]=nil
  end end
  return known[k]or {}
 end
 -- a merged match's parts are dropped by the replay, so only the whole match is looked for
 local part,map,taken={},{},{}
 for _,run in ipairs(history)do for _,id in ipairs(run.merged_segment_ids or {})do if id~=run.id then part[id]=true end end end
 -- its own number first; another only by a start time, which "Time unavailable" is not
 for pass=1,2 do for _,run in ipairs(history)do if not part[run.id]and not map[run.id]then
  local timed=pass==2 and type(run.started_at)=="string"and run.started_at~="Time unavailable"
  for _,e in ipairs(find(run))do if not taken[e.id]and (e.id==run.id or timed)then map[run.id]=e;taken[e.id]=true;break end end
 end end end
 local moved={}
 for _,run in ipairs(history)do local e,ids=map[run.id],run.merged_segment_ids
  if e and ids and e.parts and #e.parts==#ids and ids[#ids]==run.id and e.parts[#ids]==e.id then for i,id in ipairs(ids)do moved[id]=e.parts[i]end end
 end
 local shift=false
 for _,run in ipairs(history)do if not map[run.id]and not moved[run.id]and run.id<=floor then shift=true end end
 for id in pairs(part)do if not moved[id]and id<=floor then shift=true end end
 local function to(id)return map[id]and map[id].id or moved[id]or shift and id+floor or id end
 local n=0
 for _,run in ipairs(history)do local e,id=map[run.id],to(run.id)
  if run.merged_segment_ids then local ids={};for i,x in ipairs(run.merged_segment_ids)do ids[i]=to(x)end;run.merged_segment_ids=ids end
  if e and e.mark~=nil and mark(run)==nil then run.completion_markers=run.completion_markers or {};run.completion_markers.end_screen=e.mark end
  if not e and not part[run.id]and id~=run.id then n=n+1 end;run.id=id
 end
 table.sort(history,function(a,b)return a.id<b.id end);return n
end
return I
