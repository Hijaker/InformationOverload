-- Information Overload: saves from before 1.0.4 tidied once, a little at a time on the Mourningstar. Research blocks nothing reads any
-- more leave every saved match first, which reads no file; then each match is cut and packed as a match is when it saves, one match a
-- step, its file read a slice a step. Each batch goes with the next save, and what is left goes after a relaunch.
-- trackers() gives each history's records by its saved name; a batch marks them changed, so the next save writes them
return function(storage,Saved,trackers,log)
 local D={}
 local RETIRED=Saved.RETIRED
 -- the parts the cut changes, and team damage, which it leaves as it is: those a match leaves in its file go into memory as cut, so
 -- the save writes them that way, and until it does the match's damage figures read from them as they did from its line
 local PARTS={"party_records","combat_timeline","damage","team_damage","enemy_kill_counts","contributions","timing_diagnostics","barrel_pops"}
 local IN_FILE={party_records=true,combat_timeline=true,damage=true,team_damage=true,barrel_pops=true}
 local KEYS={"lifetime_records_v1","psykhanium_logs_v1","solo_records_v1"}
 -- a SoloPlay history saves in one go, so its matches go one a save
 local BATCH={lifetime_records_v1=16,psykhanium_logs_v1=16,solo_records_v1=1}
 local held,failed,count={},setmetatable({},{__mode="k"}),{dropped=0,cut=0}
 local function history(key)local t=trackers()[key];local data=t and t.data;return type(data)=="table"and type(data.run_history)=="table"and data.run_history or {}end
 local function changed(key)local t=trackers()[key];if t then t.dirty=true end end
 -- the fields a saved match left in its file
 local function in_file(run)local mt=getmetatable(run);return mt and mt.io_fields end
 local function retired(f)for _,k in ipairs(RETIRED)do if f[k]then return true end end end
 local function same(a,b)
  if a==b then return true end;if type(a)~="table"or type(b)~="table"then return false end
  for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
 end
 -- The next part of a mission is the next match the main history saves, so a match may yet be joined while no match played after it
 -- has saved. Until then it stays in the shapes an older build joins, and the first launch after, it is packed.
 local function joinable(key,list,i,run)
  if key~="lifetime_records_v1"or not Saved.joinable(run)then return false end
  for j=i+1,#list do local later=list[j];if type(later)=="table"and not later.data_only then return false end end;return true
 end
 -- What a match needs: one never cut is cut whole, and one cut before the last change in shape is cut again where a changed part is in
 -- its file. One where that part is only in its line is cut in memory, and left as it is, stamp and all, when that changes nothing, so
 -- its file is not written again for the stamp alone. One kept for a join that can no longer come is cut whole.
 local function need(key,list,i,run)
  local v=tonumber(rawget(run,"trim_version"))or 0;local join=joinable(key,list,i,run)
  if v<1 then return "whole",join end
  if join then return nil end
  if v<Saved.VERSION then local f=in_file(run)
   for _,k in ipairs(Saved.CHANGED)do if IN_FILE[k]and (f and f[k]or rawget(run,k)~=nil)then return "whole",false end end
   return "line",false
  end
  if rawget(run,"trim_joinable")then return "whole",false end
 end
 -- cut on a copy of its parts, with whether the next part of its mission may yet join it, and only a cut that finished goes back on the
 -- match, so one that fails leaves it as it was
 local function cut(run,join)
  local t={};for _,k in ipairs(PARTS)do t[k]=run[k]end
  Saved.trim(t,join)
  for _,k in ipairs(PARTS)do if IN_FILE[k]then if t[k]~=nil then rawset(run,k,t[k])end elseif run[k]~=t[k]then run[k]=t[k]end end
  run.trim_version=t.trim_version;if run.trim_joinable~=t.trim_joinable then run.trim_joinable=t.trim_joinable end
 end
 -- the changed parts a match keeps in its line, cut in memory; true when that changed any
 local function cut_line(run)
  local t,moved={},false;for _,k in ipairs(Saved.CHANGED)do if not IN_FILE[k]then t[k]=run[k]end end
  Saved.trim(t,false)
  for _,k in ipairs(Saved.CHANGED)do if not IN_FILE[k]and not same(run[k],t[k])then run[k]=t[k];moved=true end end
  if moved then run.trim_version=t.trim_version end;return moved
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
  for _,key in ipairs(KEYS)do local list=history(key)
   for i,run in ipairs(list)do
    local work,join;if type(run)=="table"and not failed[run]then work,join=need(key,list,i,run)end
    local ok,moved=true,true
    if work=="line"then ok,moved=pcall(cut_line,run);if not ok then failed[run]=true end
    elseif work then current=run;read(run)
     -- a match whose file cannot be read is passed by until the next launch, which tells the player about it
     ok=pcall(cut,run,join);storage:release_details();current=nil;if not ok then failed[run]=true end
    end
    if work and (not ok or moved)then
     if ok then count.cut=count.cut+1;held[key]=(held[key]or 0)+1 end
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
 -- a read cut short is let go rather than held until the tidy can go on, and its match is read again from the start
 function D.drop()job,D.busy,current=nil,false,nil end
 return D
end
