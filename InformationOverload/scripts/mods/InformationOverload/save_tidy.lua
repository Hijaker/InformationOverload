-- Information Overload: saves from before 1.0.4 tidied once, a little at a time on the Mourningstar. Research blocks nothing reads any
-- more leave every saved match first, which reads no file; then each match is cut and packed as a match is when it saves, one match a
-- step, its file read a slice a step. Each batch goes with the next save, and what is left goes after a relaunch.
-- trackers() gives each history's records by its saved name; a batch marks them changed, so the next save writes them
return function(storage,Saved,trackers,log)
 local D={}
 local RETIRED=Saved.RETIRED
 -- the parts the cut changes, and team damage, which it leaves as it is: those a match leaves in its file go into memory as cut, so
 -- the save writes them that way, and until it does the match's damage figures read from them as they did from its line
 local PARTS={"party_records","combat_timeline","damage","team_damage","enemy_kill_counts","contributions","timing_diagnostics"}
 local IN_FILE={party_records=true,combat_timeline=true,damage=true,team_damage=true}
 local KEYS={"lifetime_records_v1","psykhanium_logs_v1","solo_records_v1"}
 -- a SoloPlay history saves in one go, so its matches go one a save
 local BATCH={lifetime_records_v1=16,psykhanium_logs_v1=16,solo_records_v1=1}
 local held,failed,count={},setmetatable({},{__mode="k"}),{dropped=0,cut=0}
 local function history(key)local t=trackers()[key];local data=t and t.data;return type(data)=="table"and type(data.run_history)=="table"and data.run_history or {}end
 local function changed(key)local t=trackers()[key];if t then t.dirty=true end end
 -- the fields a saved match left in its file
 local function in_file(run)local mt=getmetatable(run);return mt and mt.io_fields end
 local function retired(f)for _,k in ipairs(RETIRED)do if f[k]then return true end end end
 local function uncut(run)return (tonumber(rawget(run,"trim_version"))or 0)<Saved.VERSION end
 -- cut on a copy of its parts, and only a cut that finished goes back on the match, so one that fails leaves it as it was
 local function cut(run)
  local t={};for _,k in ipairs(PARTS)do t[k]=run[k]end
  Saved.trim(t)
  for _,k in ipairs(PARTS)do if IN_FILE[k]then if t[k]~=nil then rawset(run,k,t[k])end elseif run[k]~=t[k]then run[k]=t[k]end end
  run.trim_version=t.trim_version
 end
 -- the match's file read over several steps, the read, the decode and the unpacking each a step of their own, and held for the cut
 local function read(run)
  local mt=getmetatable(run);local file=mt and mt.io_file and mt.io_file()
  if not file or not storage.read_sliced then return end
  local value=storage:read_sliced(file,coroutine.yield)
  if type(value)=="table"and mt.io_file()==file then storage:hold_details(file,value)end
 end
 local current
 local function step()
  for _,key in ipairs(KEYS)do local n=0
   for _,run in ipairs(history(key))do local f=in_file(run)
    if f and retired(f)then for _,k in ipairs(RETIRED)do if f[k]then run[k]=nil end end;n=n+1;if n>=BATCH[key]then break end end
   end
   if n>0 then count.dropped=count.dropped+n;changed(key);return true end
  end
  for _,key in ipairs(KEYS)do
   for _,run in ipairs(history(key))do
    if type(run)=="table"and not failed[run]and uncut(run)then
     current=run;read(run)
     -- a match whose file cannot be read is passed by until the next launch, which tells the player about it
     local ok=pcall(cut,run);storage:release_details();current=nil
     if ok then count.cut=count.cut+1;held[key]=(held[key]or 0)+1 else failed[run]=true end
     if (held[key]or 0)>=BATCH[key]then held[key]=0;changed(key);return true end
     return false
    end
   end
   if (held[key]or 0)>0 then held[key]=0;changed(key);return true end
  end
  D.done=true
  if log and count.dropped+count.cut>0 then log(count.dropped,count.cut)end
  return false
 end
 local job
 -- one step; true when it left matches for the next save. D.busy while a file is part read, so the next step comes straight after
 function D.step()
  if D.done then return false end
  job=job or coroutine.create(step)
  local ok,more=coroutine.resume(job)
  if coroutine.status(job)=="suspended"then D.busy=true;return false end
  job,D.busy=nil,false
  if ok then return more end
  -- a file that fails to read fails its match alone
  if current then failed[current]=true;storage:release_details();current=nil;return false end
  error(more,0)
 end
 return D
end
