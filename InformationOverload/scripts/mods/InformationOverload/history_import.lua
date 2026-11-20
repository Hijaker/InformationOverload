local I={}
local DATE="^%d%d%d%d%-%d%d%-%d%d"
local function when(run)local s=run.started_at;return type(s)=="string"and s:match(DATE)and s or nil end
-- a match brought in from Power DI or added by Import Match History takes a number after this PC's own but sits among them by date
function I.placed(run)return type(run.imported)=="table"or run.import_added==true end
-- Matches go in number order, except those placed by date, so streaks replay in the order matches were played.
function I.order(history)
 local own,imported={},{}
 for _,run in ipairs(history)do if I.placed(run)then imported[#imported+1]=run else own[#own+1]=run end end
 table.sort(own,function(a,b)return (a.id or 0)<(b.id or 0)end)
 table.sort(imported,function(a,b)local x,y=when(a)or "~",when(b)or "~";if x~=y then return x<y end;return (a.id or 0)<(b.id or 0)end)
 local out,j={},1
 for _,run in ipairs(own)do local at=when(run)
  while at and imported[j]and when(imported[j])and when(imported[j])<at do out[#out+1]=imported[j];j=j+1 end
  out[#out+1]=run
 end
 for k=j,#imported do out[#out+1]=imported[k]end
 for i,run in ipairs(out)do history[i]=run end
 return history
end
function I.read(storage,pause)
 assert(not storage.unavailable and storage.a,"Import failed: saving is off.");assert(storage.a.list,"Local folder scanning is unavailable")
 -- a copied match_history folder also holds its patch's file of lines, which is no match
 local files={};for _,path in ipairs(storage.a.list("Import/"))do if not ("/"..path):match("[/\\]lines%-%d+%.json$")then files[#files+1]=path end end;table.sort(files)
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
 assert(count>0,"No Match History files were found in the Import folder")
 local history={};for _,entry in pairs(byid)do history[#history+1]=entry.run end
 return I.order(history)
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
-- With merge, a match this PC knows is left out instead, as is one of a mission it holds (Delete Match's rule), and what is left is all new.
function I.renumber(storage,history,current,seq,pause,merge)
 local KEY="lifetime_records_v1";local floor,known,unread,missions=seq or 0,{},{},{}
 local function top(id)floor=math.max(floor,tonumber(id)or 0)end
 local function key(run)local c=run.context or {};return table.concat({tostring(c.character),tostring(c.patch),tostring(run.started_at),tostring(c.mission_instance)},"|")end
 local function mission(run)local c=run.context or {};if type(c.mission_instance)=="string"and c.mission_instance~=""then return table.concat({c.mission_instance,tostring(c.character),tostring(c.class),tostring(c.patch)},"|")end end
 local function mark(run)local m=run.completion_markers;return type(m)=="table"and m.end_screen or nil end
 local function know(id,run,m)id=tonumber(id);if not id then return end;local k=key(run);known[k]=known[k]or {};table.insert(known[k],{id=id,parts=run.merged_segment_ids,mark=m});local mk=mission(run);if mk then missions[mk]=true end end
 local function lost(list)for _,r in ipairs(list or {})do if r.key==KEY and r.match then top(r.id)end end end
 for _,run in ipairs(current or {})do top(run.id);know(run.id,run,mark(run))end
 lost(storage.manifest and storage.manifest.missing);lost(storage.skipped)
 for _,b in ipairs(storage.backups and storage:backups()or {})do lost(b.missing)
  local entry=b.entries and b.entries[KEY];if entry and not entry.history_present then top(b.seq and b.seq.lifetime)end
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
 if merge then
  -- known as numbering knows it, without one match standing for one other; find reads the backups of its patch, so their missions are known too
  local function held(run)local timed=type(run.started_at)=="string"and run.started_at~="Time unavailable"
   for _,e in ipairs(find(run))do if e.id==run.id or timed then return true end end
   local mk=mission(run);return mk and missions[mk]or false
  end
  local gone={}
  for _,run in ipairs(history)do if held(run)then gone[run.id]=true;for _,id in ipairs(run.merged_segment_ids or {})do gone[id]=true end end end
  local new={};for _,run in ipairs(history)do if not gone[run.id]then new[#new+1]=run end end
  for i=#history,1,-1 do history[i]=new[i]end
  map,part={},{};for _,run in ipairs(history)do for _,id in ipairs(run.merged_segment_ids or {})do if id~=run.id then part[id]=true end end end
 end
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
 I.order(history);return n
end
-- Import Match History keeps every match on this PC and adds the folder's new ones, numbered after this PC's and placed among them by date.
-- Gives the history with them, the numbers it added, a merged match's parts included, and how many matches that is; nil when none are new.
function I.merge(storage,history,current,seq,pause)
 I.renumber(storage,history,current,seq,pause,true)
 if not history[1]then return nil end
 local ids,listed,part,n={},{},{},0
 local function list(id)if not listed[id]then listed[id]=true;ids[#ids+1]=id end end
 for _,run in ipairs(history)do for _,id in ipairs(run.merged_segment_ids or {})do if id~=run.id then part[id]=true end end end
 local out={};for _,run in ipairs(current or {})do out[#out+1]=run end
 for _,run in ipairs(history)do run.import_added=true;out[#out+1]=run;list(run.id);if not part[run.id]then n=n+1 end
  for _,id in ipairs(run.merged_segment_ids or {})do list(id)end
 end
 return I.order(out),ids,n
end
return I
