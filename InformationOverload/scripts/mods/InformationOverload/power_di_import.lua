-- Import From Power DI: reads the missions Power DI saved through the game's save system, one at a time over frames, and adds the finished ones to Match History.
-- Power DI's files are only ever loaded, never written. Progress shows on the Settings row; finding nothing to import shows in I/O's own popup on Settings, the rest in the game's side notification, never in chat.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
-- the two popups that say there is nothing to import, a line each
local NOTICE={
 none={"No Power DI missions found.","Power DI's files belong in AppData\\Roaming\\Fatshark\\Darktide."},
 known={"Every completed Power DI mission is already imported."},
}
local SAID={
 done="I/O Import Complete",
 cancelled="The Power DI import was cancelled, so nothing was changed.",
 failed="The Power DI import failed, so nothing was changed.",
 none="None of the Power DI missions could be imported.",
}
local LIFETIME="lifetime_records_v1"
-- what the job may take of a frame, in ms
local BUDGET=3
-- a collector step, in KB of allocation it stands for: it starts at 64 and doubles or halves to keep a step near half a millisecond
local GC_FIRST,GC_MIN,GC_MAX=64,16,1024
local DATE="^%d%d%d%d%-%d%d%-%d%d"
-- E holds what the main file owns: the tracker's data, the hub replay, the rebuild, the commit and the clock
return function(E)
 local J={SAID=SAID,NOTICE=NOTICE}
 local storage,Backup=E.storage,E.Backup
 local job,last,notice
 -- what an old backup holds, read once a session; a backup made since lists its missions in the catalog
 local legacy={}
 local function revision()local p=E.policy();return type(p)=="table"and p.revision or nil end
 -- a load given up mid-way is still polled until the game finishes it, then closed, before the next one starts
 local drain={}
 local Convert
 local function convert()Convert=Convert or mod:io_dofile(base.."power_di_convert");return Convert end
 local function poll(token)
  local ok,p=pcall(SaveSystem.progress,token)
  if not ok then pcall(SaveSystem.close,token);return true end
  if p and p.done then pcall(SaveSystem.close,token);return true,p end
 end
 local function drain_step()for i=#drain,1,-1 do if poll(drain[i])then table.remove(drain,i)end end end
 -- once a mission's table is let go, the rest of each frame spent waiting on a load goes to the collector a step at a time, until two
 -- cycles end, the second begun after the table was let go, so the heap comes down steadily rather than in a burst; never a full collect
 local function sweep(active)
  if not active.owed then return end
  local n=active.gc_n or GC_FIRST
  while E.now()-active.slice<BUDGET do
   local t=E.now();local ended=collectgarbage("step",n);local took=E.now()-t
   active.gc_steps=active.gc_steps+1
   if took<.25 then n=math.min(n*2,GC_MAX)elseif took>.75 then n=math.max(math.floor(n/2),GC_MIN)end
   if ended then active.owed=active.owed-1;if active.owed<=0 then active.owed=nil;break end end
  end
  active.gc_n=n
 end
 -- inside the job's coroutine: one load in flight, polled once a frame; nil when the file is missing or unreadable
 local function load(active,name)
  while drain[1]do sweep(active);coroutine.yield()end
  local token=SaveSystem.auto_load(name);active.token=token
  while true do
   local done,p=poll(token)
   if done then active.token=nil;local data=p and not p.error and p.data;p=nil;return type(data)=="table"and data or nil end
   sweep(active);coroutine.yield()
  end
 end
 local function known_set(pause)
  local known={}
  local saved=storage:get(Backup.POWERDI)
  for id in pairs(type(saved)=="table"and type(saved.sessions)=="table"and saved.sessions or {})do known[id]=true end
  local function add(runs)for _,run in ipairs(runs or {})do
   local c=run.context;if type(c)=="table"and c.mission_instance~=nil then known[c.mission_instance]=true end
   if type(run.imported)=="table"and run.imported.session~=nil then known[run.imported.session]=true end
  end end
  add(E.data().run_history)
  -- a match only a backup holds comes back with its restore, so it is not imported again either
  for _,b in ipairs(storage.backups and storage:backups()or {})do
   if type(b.instances)=="table"then for _,id in ipairs(b.instances)do known[id]=true end
   else local key=tostring(b.made).."|"..tostring(b.seq and b.seq.lifetime)
    -- its own matches read a file at a time, so no frame holds more than one read
    if not legacy[key]then local held={};local entry=type(b.entries)=="table"and b.entries[LIFETIME]
     for _,desc in ipairs(type(entry)=="table"and entry.history or {})do pause()
      local ok,run=pcall(storage.read,storage,desc.file);local c=ok and type(run)=="table"and run.context
      if type(c)=="table"and c.mission_instance~=nil then held[#held+1]=c.mission_instance end
     end
     legacy[key]=held
    end
    for _,id in ipairs(legacy[key])do known[id]=true end
   end
  end
  return known
 end
 -- a mission converts in a coroutine of its own, so a fault in one is caught without a pcall the pauses would have to cross
 local function convert_one(active,data,pause,danger)
  local opts={patch_fallback=E.patch and E.patch()or nil,danger=danger}
  local co=coroutine.create(function(d)return convert().run(d,opts,pause)end)
  local ok,run,why=coroutine.resume(co,data);data=nil
  while ok and coroutine.status(co)~="dead"do coroutine.yield();active.slice=E.now();ok,run,why=coroutine.resume(co)end
  if not ok then E.info("Power DI import: a mission could not be converted: %s",tostring(run));return nil end
  if type(run)~="table"then return nil,why end
  return run
 end
 local function main(active)
  local function pause()if E.now()-active.slice>=BUDGET then coroutine.yield()end end
  local index=load(active,"power_di")
  local scan=convert().scan(index);index=nil
  if type(scan)~="table"or scan.missing or #(scan.ids or {})==0 then return "none"end
  local known=known_set(pause)
  -- Power DI keeps its list long after a mission's own file is gone, so only missions whose file is still there are offered; where the
  -- folder cannot be looked at, each is offered and one with no file is just skipped
  local folder=E.save_folder and E.save_folder()
  -- and what each file weighs, for the result
  local sizes={};active.sizes=folder and sizes or nil
  local function present(id)if not folder then return true end;pause();local f=folder(convert().file_name(id)..".sav")
   if f then local ok,n=pcall(f.seek,f,"end");f:close();sizes[id]=ok and tonumber(n)or nil;return true end;return false end
  local todo,held={},false;for i,id in ipairs(scan.ids)do if i%50==0 then pause()end;if known[id]then held=true elseif present(id)then todo[#todo+1]=id end end
  -- nothing left to bring in: "already imported" only when some are, else no files were found
  if #todo==0 then return held and "known"or "none"end
  -- the unfinished ones are counted the same way, only those whose file is still there
  local m=0;if scan.unfinished then for i,id in ipairs(scan.unfinished)do if i%50==0 then pause()end;if present(id)then m=m+1 end end else m=scan.incomplete or 0 end
  active.todo,active.n,active.m=todo,#todo,m
  active.stage="confirm";repeat coroutine.yield()until active.go
  active.stage="run";active.i=0;active.runs={}
  local C=convert()
  for i,id in ipairs(todo)do pause()
   -- one Power DI table alive at a time: its cached reports go as it loads, and it is let go before the next load
   local data=load(active,C.file_name(id))
   if data then C.drop_heavy(data)
    local info=type(data.info)=="table"and data.info or {}
    if info.session_id==id and (info.outcome=="won"or info.outcome=="lost")then
     local run=convert_one(active,data,pause,scan.danger and scan.danger[id])
     if run then active.runs[#active.runs+1]=run end
    end
    info=nil;active.owed=2
   end
   data=nil;active.i=i
  end
  return "save"
 end
 -- the highest number anything on this PC still holds, so a number is never given to two matches, and one nothing holds is given again
 local function floor_of(d)return Backup.top(storage,d,E.baseline and E.baseline())end
 local function when(run)local s=run.started_at;return type(s)=="string"and s:match(DATE)and s or nil end
 -- the imported matches take the next numbers in date order, then sit among the others by date, so streaks replay in the order the missions were played
 local function place(existing,fresh)
  local out,j={},1
  for _,run in ipairs(existing)do local at=when(run)
   while at and fresh[j]and when(fresh[j])and when(fresh[j])<at do out[#out+1]=fresh[j];j=j+1 end
   out[#out+1]=run
  end
  for k=j,#fresh do out[#out+1]=fresh[k]end
  return out
 end
 local function save(active)
  local function pause()if E.now()-active.slice>=BUDGET then coroutine.yield()end end
  local d=active.base
  local seen={};local saved=storage:get(Backup.POWERDI)
  for id in pairs(type(saved)=="table"and type(saved.sessions)=="table"and saved.sessions or {})do seen[id]=true end
  for _,run in ipairs(d.run_history or {})do local c=run.context;if type(c)=="table"and c.mission_instance~=nil then seen[c.mission_instance]=true end end
  local fresh={}
  for _,run in ipairs(active.runs)do local id=run.imported and run.imported.session;if id~=nil and not seen[id]then seen[id]=true;fresh[#fresh+1]=run end end
  if #fresh==0 then return nil end
  -- what the imported missions' own files weigh, unknown when one could not be measured
  local bytes=active.sizes and 0;for _,run in ipairs(fresh)do local n=bytes and active.sizes[run.imported.session];bytes=n and bytes+n or nil end;active.pdi_bytes=bytes
  table.sort(fresh,function(a,b)local x,y=when(a)or "",when(b)or "";if x~=y then return x<y end;return tostring(a.imported.session)<tostring(b.imported.session)end)
  local top=floor_of(d);local sessions={}
  for i,run in ipairs(fresh)do run.id=top+i;E.trim(run);sessions[i]=run.imported.session;pause()end
  local copy={};for k,v in pairs(d)do copy[k]=v end
  copy.run_history=place(d.run_history or {},fresh);copy.run_sequence=top+#fresh;pause()
  local updated,baseline=E.rebuild(copy,pause)
  return updated,baseline,sessions
 end
 local function report(active,result)
  E.info("Power DI Import: %s, %d of %d missions converted, %d slices, longest slice %.1f ms, save/finalize %.1f ms over %d frames, longest of them %.1f ms, %d collector steps, elapsed %.1f ms",
   result,active.runs and #active.runs or 0,active.n or 0,active.slices,active.peak,active.fin,active.fin_frames,active.fin_peak,active.gc_steps,E.now()-active.started)
 end
 -- a frame's time on the job, the save's frames counted apart too
 local function spent(active,ms,finalize)
  active.slices=active.slices+1;active.peak=math.max(active.peak,ms)
  if finalize then active.fin=active.fin+ms;active.fin_frames=active.fin_frames+1;active.fin_peak=math.max(active.fin_peak,ms)end
 end
 -- whether the history in use grew from the one it saved, or else still holds any of the sessions it added
 local function stands(base,ids)
  if E.current(base)==E.data()then return true end
  local want={};for _,s in ipairs(ids or {})do want[s]=true end
  for _,run in ipairs(E.data().run_history or {})do local s=type(run.imported)=="table"and run.imported.session;if s~=nil and want[s]then return true end end
  return false
 end
 -- the commit ended: saved, stopped before its catalog took it, or failed
 local function finish(active,h)
  if h.ok then
   -- a Restore or Reset that ran it out has taken the imports back out already; a match deleted meanwhile leaves them in
   if not stands(h.data,active.ids)then return report(active,"complete, then taken out by a Restore or Reset")end
   report(active,"complete");last={imported=active.sessions,ids=active.ids,base=h.data,pdi_bytes=active.pdi_bytes,io_bytes=h.wrote};return E.notify(SAID.done)end
  if h.job.abort then report(active,"cancelled");return E.notify(SAID.cancelled)end
  report(active,"failed: "..tostring(h.err));return E.notify(SAID.failed)
 end
 -- a commit under way asked to stop runs out at once: before its catalog commit what it set goes back, after it the import stands
 local function stop(active)
  local h=active.commit;local began=E.now()
  if not h.done and storage.job==h.job then storage:settle()end
  spent(active,E.now()-began,true);return finish(active,h)
 end
 local function cancel(said)
  local active=job;job=nil
  if active and active.token then drain[#drain+1]=active.token;active.token=nil end
  if active and active.commit then return stop(active)end
  if said then E.notify(said)end
 end
 function J.request()
  if job then return false,"A Power DI import is already running."end
  if E.busy()then return false,"Finish the current mission and resolve any pending result first."end
  if E.other and E.other()then return false,"A match history import is already running."end
  notice=nil
  if not SaveSystem then notice="none";return true end
  job={stage="index",base=E.data(),policy=revision(),started=E.now(),slices=0,peak=0,fin=0,fin_frames=0,fin_peak=0,gc_steps=0}
  job.co=coroutine.create(main)
  return true
 end
 function J.confirm()
  local active=job;if not active or active.stage~="confirm"then return false end
  if E.busy()then cancel(SAID.cancelled);return false end
  -- it leaves the asking stage at once, so the Settings page drawn before the job's next step does not open the popup again
  active.go=true;active.stage="run";return true
 end
 function J.cancel()if job then cancel()end end
 -- the row's Abort: a running import stops at once and changes nothing; once its commit is under way it is left to finish
 function J.abort()local active=job;if not active or active.commit or (active.stage~="run"and active.stage~="save")then return false end;cancel(SAID.cancelled);return true end
 -- a fault in a frame's step goes to the log, and the import it stopped to the side notification
 function J.fault(err)E.info("Power DI import: %s",tostring(err));if job then cancel(SAID.failed)end end
 function J.busy()return job~=nil end
 function J.dismiss()notice=nil end
 -- the panel closing: an import still reading the list or waiting on its popup ends, as its popup can only open on Settings; one running goes on
 function J.leave()notice=nil;if job and (job.stage=="index"or job.stage=="confirm")then cancel()end end
 function J.status()
  local active=job
  if active then return {stage=active.stage,i=active.i or 0,n=active.n or 0,m=active.m or 0,held=active.commit~=nil}end
  if notice then return {stage="said",said=notice,lines=NOTICE[notice]}end
  -- the result shows while its matches are in the history in use, so a Restore or Reset since takes it away and a match deleted does not
  if last then if stands(last.base,last.ids)then last.base=E.data()else last=nil end end
  if last then return {stage="done",imported=last.imported,pdi_bytes=last.pdi_bytes,io_bytes=last.io_bytes}end
 end
 -- the commit, a held storage job stepped here a few milliseconds a frame; a mission, or the mod switched off, stops it
 local function commit_step(active)
  local h=active.commit
  if not h.done and storage.job==h.job then
   if not E.enabled()or E.busy()then job=nil;return stop(active)end
   active.slice=E.now()
   -- a Counting change stops it too, and the save starts again below
   if revision()~=active.policy then storage:settle()else storage:step(BUDGET/1000)end
   spent(active,E.now()-active.slice,true)
   if not h.done and storage.job==h.job then return end
  end
  -- stopped before its catalog took it, by a Counting change or another save: saved again while its history is still the one in use
  if not h.ok and h.job.abort and (active.again or 0)<3 then local cur=E.current(active.base)
   if E.enabled()and not E.busy()and cur==E.data()then active.again=(active.again or 0)+1;active.commit,active.co=nil,nil;active.base,active.policy=cur,revision();return end
  end
  job=nil;return finish(active,h)
 end
 function J.step()
  drain_step()
  local active=job;if not active then return end
  if active.commit then return commit_step(active)end
  if not E.enabled()or E.busy()then return cancel(SAID.cancelled)end
  -- the hub replay hands on the same matches recounted; anything else that replaced them (a Reset, Restore, Delete or Import) ends the import
  local cur=E.current(active.base)
  if cur~=E.data()then return cancel(SAID.cancelled)end
  if cur~=active.base or revision()~=active.policy then active.base,active.policy=cur,revision();if active.stage=="save"then active.co=nil end end
  if active.stage=="confirm"and not active.go then return end
  -- the save waits for the hub replay and for any save under way, so its commit can start as it ends
  if active.stage=="save"then
   if not E.idle()or storage.job then return end
   active.co=active.co or coroutine.create(save)
  end
  active.slice=E.now()
  local stage=active.stage
  local ok,a,b,c=coroutine.resume(active.co,active)
  spent(active,E.now()-active.slice,stage=="save")
  if not ok then E.info("Power DI import: %s",tostring(a));report(active,"failed");return cancel(SAID.failed)end
  if coroutine.status(active.co)~="dead"then return end
  if stage~="save"then
   if a=="save"then active.stage="save";active.co=nil;return end
   job=nil;if NOTICE[a]then notice=a;return end;return E.notify(SAID.failed)
  end
  active.co=nil
  -- the popup counted missions, so none brought in is a failure, not nothing found
  if a==nil then job=nil;report(active,"nothing loaded");return E.notify(SAID.none)end
  local known={};local saved=storage:get(Backup.POWERDI)
  for id in pairs(type(saved)=="table"and type(saved.sessions)=="table"and saved.sessions or {})do known[id]=true end
  for _,id in ipairs(c)do known[id]=true end
  -- the backup, the history and the imported list in one commit, from the next frame on
  active.sessions=#c;active.ids=c;active.commit=E.commit_begin(a,b,{sessions=c,known={sessions=known}})
 end
 return J
end
