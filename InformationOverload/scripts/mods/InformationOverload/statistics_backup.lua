-- Reset moves the saved statistics into a backup and Restore brings backups back; each lands in one catalog commit, so a crash leaves it done or not done.
local B={}
B.KEYS={"lifetime_records_v1","solo_records_v1","psykhanium_logs_v1","history_baseline_v1","friend_summaries_v1"}
-- the Power DI sessions already imported, kept apart from the history so a deleted import stays deleted
B.POWERDI="powerdi_imported_v1"
-- the ones the player deleted from Match History, written by history_deletion.lua's D.remember
B.POWERDI_DELETED="powerdi_deleted_v1"
-- matches deleted for good from their own page, written by history_deletion.lua's D.forget
B.DELETED="history_deleted_v1"
local SETS={lifetime="lifetime_records_v1",solo="solo_records_v1",logs="psykhanium_logs_v1",baseline="history_baseline_v1"}
local function count(d)local n=0;for _,run in ipairs(d and d.run_history or {})do if not run.hidden_contributions then n=n+1 end end;return n end
local function held(d)return d and (next(d.rows or {})or next(d.run_history or {}))and true or false end
local function empty(d)return not held(d)and not next(d and d.history_patch_carries or {})and not (d and d.history_damage_reset_after)end
-- Rows and tallies from before match history existed cannot be rebuilt from matches.
local function legacy(b)return b and (next(b.rows or {})or next(b.history_legacy_patches or {})or next(b.boss_tallies or {})or next(b.blo_global or {})or (b.run_sequence or 0)>0)and true or false end
local function same(a,b)local x,y=a.context or {},b.context or {};return x.mission_instance==y.mission_instance and x.character==y.character and x.patch==y.patch and a.started_at==b.started_at end
local function store(storage,s)for k,key in pairs(SETS)do storage:set(key,s[k])end;storage:set("friend_summaries_v1",s.friends or {})end
-- the save before a reset or import may be the first into Loaded Data/, so its folders are made by one mkdir, not one at a time as it writes
local function prepare(storage)if storage.prepare_folders then storage:prepare_folders()end end
-- the missions a backup holds, by session, so a Power DI import can skip them without opening it
local function instances(d)local out={};for _,run in ipairs(d and d.run_history or {})do local c=run.context;if type(c)=="table"and c.mission_instance~=nil then out[#out+1]=c.mission_instance end end;return out end
local function day(s)local y,m,d=tostring(s or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");return y and d.."/"..m.."/"..y or "an unknown day"end
function B.matches(n)return n==1 and "1 match"or tostring(n or 0).." matches"end
-- "the backup from 27/10/2026, 42 matches" or "all 3 backups, 120 matches"
function B.describe(list,all)
 if all and #list>1 then local n=0;for _,b in ipairs(list)do n=n+(b.matches or 0)end;return "all "..#list.." backups, "..B.matches(n)end
 local b=list[#list]or {};return "the backup from "..day(b.made)..", "..B.matches(b.matches)
end
-- The highest match number anything on this PC still holds: the history, its patch carries, the baseline, a missing match file, and every
-- backup's history and imported numbers, or for a backup from before match history the numbers it used. An import numbers after it, so a number nothing holds any more is given again.
function B.top(storage,d,baseline)
 local n=tonumber(baseline and baseline.run_sequence)or 0
 local function up(id)n=math.max(n,tonumber(id)or 0)end
 for _,run in ipairs(d and d.run_history or {})do up(run.id);for _,id in ipairs(run.merged_segment_ids or {})do up(id)end end
 for _,c in ipairs(d and d.history_patch_carries or {})do up(c.after_run)end;up(d and d.history_damage_reset_after)
 local function lost(list)for _,r in ipairs(list or {})do if r.key==SETS.lifetime and r.match then up(r.id)end end end
 lost(storage.manifest and storage.manifest.missing);lost(storage.skipped)
 for _,b in ipairs(storage.backups and storage:backups()or {})do lost(b.missing);for _,id in ipairs(b.merged or {})do up(id)end
  local e=b.entries and b.entries[SETS.lifetime];for _,desc in ipairs(e and e.history or {})do up(desc.id)end
  if e and not e.history_present then up(b.seq and b.seq.lifetime)end
 end
 return n
end
-- The highest match number a backup used: the counters carry on from it, so a number is never reused.
function B.floor(storage,k)local n=0;for _,b in ipairs(storage.backups and storage:backups()or {})do n=math.max(n,b.seq and b.seq[k]or 0)end;return n end
function B.reset(storage,R,H,state,now)
 if not storage.stash then return nil,"Saving is off, so nothing was reset."end
 store(storage,state);prepare(storage);if not storage:flush()then return nil,"Your statistics could not be saved, so nothing was reset."end
 local seq={};for _,k in ipairs({"lifetime","solo","logs"})do seq[k]=math.max(state[k]and state[k].run_sequence or 0,B.floor(storage,k))end
 local out={lifetime=R.new(),solo=R.new(),logs=R.new()}
 for k,n in pairs(seq)do out[k].data.run_sequence=n;out[k].data.counted_entries=3 end
 local life=out.lifetime.data;life.history_policy_revision=(state.lifetime.history_policy_revision or 0)+1
 -- Tracked Players are a setting, so they stay with the names given them, and the new revision has friend stats follow.
 life.friend_tracking=H.clone(state.lifetime.friend_tracking);life.friend_tracking_revision=(state.lifetime.friend_tracking_revision or 0)+1
 local baseline=H.baseline(life);baseline.run_sequence=0
 local kept=held(state.lifetime)or held(state.solo)or held(state.logs)or legacy(state.baseline)
 storage:stash(B.KEYS,kept and {made=now,matches=count(state.lifetime)+count(state.solo),logs=count(state.logs),seq=seq,instances=instances(state.lifetime)}or nil)
 store(storage,{lifetime=out.lifetime.data,solo=out.solo.data,logs=out.logs.data,baseline=baseline})
 if not storage:flush()then storage:unstage();store(storage,state);return nil,"Saving failed, so nothing was reset."end
 out.baseline=baseline;out.kept=kept;return out
end
-- An import keeps the history it adds to as a backup made in the same commit, naming what it brought in, so restoring it takes them back out:
-- a Power DI import its missions by session, Import Match History its matches by number. Returns the highest number this PC has used.
local function added(storage,state,now,field,list,n)
 if not storage.stash then return nil,"Saving is off, so nothing was imported."end
 storage:set(SETS.lifetime,state.lifetime);prepare(storage);if not storage:flush()then return nil,"Your statistics could not be saved, so nothing was imported."end
 local seq=math.max(state.lifetime.run_sequence or 0,B.floor(storage,"lifetime"))
 local info={made=now,matches=count(state.lifetime),logs=0,seq={lifetime=seq},[field]=list,added=n,instances=instances(state.lifetime)}
 storage:stash({SETS.lifetime,"friend_summaries_v1"},info);return info,seq
end
function B.import(storage,state,now,ids,n)return added(storage,state,now,"merged",ids,n)end
function B.powerdi(storage,state,now,sessions)return added(storage,state,now,"powerdi",sessions)end
-- deleting matches from Match History keeps the history they were in, so restoring it brings them back
function B.deleted(storage,state,now,ids)return added(storage,state,now,"deleted",ids)end
local function imported(run,drop,ids)return drop and type(run.imported)=="table"and drop[run.imported.session]or ids and ids[run.id]or false end
-- Sets go oldest first, the current statistics last. Matches join by number; a dataset only one set holds anything of is taken whole, so a restore into an empty reset gives back exactly what was saved, and otherwise its statistics are rebuilt from every match.
-- drop names Power DI sessions and ids the numbers of matches Import Match History added; those matches leave every set, and their statistics are rebuilt without them.
function B.merge(d,policy,sets,drop,ids,gone)
 local R,H=d.R,d.H;local now=sets[#sets];local out={}
 for _,s in ipairs(sets)do if held(s.lifetime)and legacy(s.baseline)then
  assert(not out.baseline,"Two sets of statistics from before match history cannot be combined, so nothing was restored.");out.baseline=s.baseline
 end end
 out.baseline=out.baseline or now.baseline or {schema=R.schema or 1,rows={},run_sequence=0,history_legacy_patches={}}
 for _,k in ipairs({"lifetime","solo","logs"})do
  local full,seq,rev,history,seen={},0,0,{},{};local dropped=false
  for _,s in ipairs(sets)do local x=s[k]
   if x then seq=math.max(seq,x.run_sequence or 0);rev=math.max(rev,x.history_policy_revision or 0)
    for _,run in ipairs(x.run_history or {})do local id=run.id or 0;seq=math.max(seq,id)
     local lost=gone and type(gone[k])=="table"and gone[k][tostring(id)]
     if (k=="lifetime"and imported(run,drop,ids))or (lost and lost==tostring(run.started_at))then dropped=true
     elseif seen[id]then assert(same(seen[id],run),"Two different matches share number "..tostring(id)..", so nothing was restored.")else seen[id]=run;history[#history+1]=run end
    end
    if not empty(x)then full[#full+1]=x end
   end
  end
  -- by number, with imported and added matches among them by date, as the import placed them
  if d.I and d.I.order then d.I.order(history)else table.sort(history,function(a,b)return (a.id or 0)<(b.id or 0)end)end
  local data
  if (#full>1 or dropped)and k~="logs"then
   local source={schema=R.schema or 1,rows={},run_history=history,run_sequence=seq,record_credits={}};local carries,known,names={},{},{}
   for _,s in ipairs(sets)do for id,by in pairs(R.record_credits and R.record_credits(s[k]and s[k].rows)or {})do source.record_credits[id]=by end end
   for _,s in ipairs(sets)do local x=s[k]or {}
    for _,c in ipairs(x.history_patch_carries or {})do local id=tostring(c.old).."|"..tostring(c.new).."|"..tostring(c.after_run);if not known[id]then known[id]=true;carries[#carries+1]={c=c,i=#carries}end end
    if x.history_damage_reset_after then source.history_damage_reset_after=math.max(source.history_damage_reset_after or 0,x.history_damage_reset_after)end
    for id,name in pairs(x.character_names or {})do names[id]=name end
    if x.self_leave_pending~=nil then source.self_leave_pending=x.self_leave_pending end
   end
   table.sort(carries,function(a,b)local x,y=a.c.after_run or 0,b.c.after_run or 0;if x~=y then return x<y end;return a.i<b.i end)
   if next(names)then source.character_names=names end
   if carries[1]then source.history_patch_carries={};for i,e in ipairs(carries)do source.history_patch_carries[i]=e.c end end
   data=d.I.replay(R,H,d.M,source,policy,k=="lifetime"and out.baseline or nil)
  else
   data={};for key,v in pairs(full[#full]or now[k]or {schema=R.schema or 1,rows={}})do data[key]=v end
   if k=="logs"then data.run_history=history end
  end
  data.run_sequence=seq;data.history_policy_revision=rev+1
  -- Tracked Players: a later set wins, so the current list keeps its own and gains the backups' others; an account key a match ties to a Steam id folds onto it, so a person is one entry.
  if k=="lifetime"then local ft,frev,ids={tracked={},aliases={}},0,{}
   for _,run in ipairs(history)do for _,set in ipairs({run.context and run.context.operative_roster or {},run.operative_clutches or {}})do for _,p in pairs(set)do if p.steam_id and p.account_id then ids["account:"..tostring(p.account_id)]=tostring(p.steam_id)end end end end
   for _,s in ipairs(sets)do local f=s.lifetime and s.lifetime.friend_tracking or {};frev=math.max(frev,s.lifetime and s.lifetime.friend_tracking_revision or 0)
    -- one in this set's baseline and gone from its list was untracked since, so an older set does not bring them back
    local was,is=s.baseline and s.baseline.friend_tracking and s.baseline.friend_tracking.tracked or {},{};for id in pairs(f.tracked or {})do is[ids[id]or id]=true end
    for id in pairs(was)do if not is[ids[id]or id]then ft.tracked[ids[id]or id]=nil end end
    for id,v in pairs(f.tracked or {})do ft.tracked[ids[id]or id]=v end;for id,v in pairs(f.aliases or {})do ft.aliases[ids[id]or id]=v end
   end
   if next(ft.tracked)or next(ft.aliases)then data.friend_tracking=ft end;data.friend_tracking_revision=frev+1
  end
  out[k]=data
 end
 return out
end
-- Restored backups leave the list; their missing match files go back on the missing list, so one that turns up again is read on the next launch.
function B.restore(storage,d,policy,state,all)
 local list=storage.backups and storage:backups()or {};if not list[1]then return nil,"There are no backups to restore."end
 local first=all and 1 or #list;local brought=0;local drop,ids
 local ok,merged,carry=pcall(function()
  local sets,carry={},{}
  for i=first,#list do local values,lost=storage:backup_load(list[i]);brought=brought+(list[i].matches or 0)
   for _,id in ipairs(list[i].powerdi or {})do drop=drop or {};drop[id]=true end
   for _,id in ipairs(list[i].merged or {})do ids=ids or {};ids[id]=true end
   -- Lost lifetime records are rebuilt from the matches, so only a lifetime with match history can do without them.
   local life=(list[i].entries or {}).lifetime_records_v1
   for _,r in ipairs(lost)do assert(r.match or r.key=="lifetime_records_v1"and life and life.history_present,"Part of the backup could not be read, so nothing was restored.");if r.match then carry[#carry+1]=r end end
   for _,r in ipairs(list[i].missing or {})do carry[#carry+1]=r end
   local s={};for k,key in pairs(SETS)do s[k]=values[key]end;sets[#sets+1]=s
  end
  sets[#sets+1]=state
  local gone=storage:get(B.DELETED)
  return B.merge(d,policy,sets,drop,ids,type(gone)=="table"and gone or nil),carry
 end)
 if not ok then return nil,(tostring(merged):gsub("^.-:%d+: ",""))end
 local keep={};for i=1,first-1 do keep[i]=list[i]end
 storage:stage(keep,carry[1]and carry or nil);store(storage,merged)
 -- the missions taken back out are forgotten as imported, so the next Power DI import brings them in again
 local known=storage:get(B.POWERDI)
 if drop and type(known)=="table"then local left={};for id in pairs(known.sessions or {})do if not drop[id]then left[id]=true end end;storage:set(B.POWERDI,{sessions=left})end
 -- and one the player deleted is no longer remembered as deleted when the import that brought it is undone or the restore brings it back
 local gone=storage:get(B.POWERDI_DELETED);local ungone=false
 if type(gone)=="table"and type(gone.sessions)=="table"then
  local back={};for _,run in ipairs(merged.lifetime and merged.lifetime.run_history or {})do if type(run.imported)=="table"and run.imported.session~=nil then back[run.imported.session]=true end end
  local left={};for id in pairs(gone.sessions)do if (drop and drop[id])or back[id]then ungone=true else left[id]=true end end;if ungone then storage:set(B.POWERDI_DELETED,{sessions=left})end
 end
 if not storage:flush()then storage:unstage();store(storage,state);if drop and type(known)=="table"then storage:set(B.POWERDI,known)end;if ungone then storage:set(B.POWERDI_DELETED,gone)end;return nil,"Saving failed, so nothing was restored."end
 return merged,brought
end
-- A Power DI import only a backup held goes with it, so the next import brings it in again; one the player deleted from the history stays deleted.
function B.delete(storage,history)
 if not (storage.backups and storage:backups()[1])then return nil,"There are no backups to delete."end
 -- a held import still saving is settled first, so its own undo has put the imported list back before it is read here
 if storage.settle then storage:settle()end
 local known=storage:get(B.POWERDI);local changed=false
 if type(known)=="table"and type(known.sessions)=="table"then
  local gone=storage:get(B.POWERDI_DELETED);local here,held,left={},{},{}
  for id in pairs(type(gone)=="table"and type(gone.sessions)=="table"and gone.sessions or {})do here[id]=true end
  for _,run in ipairs(history or {})do if type(run.imported)=="table"and run.imported.session~=nil then here[run.imported.session]=true end end
  for _,b in ipairs(storage:backups())do for _,id in ipairs(b.instances or {})do held[id]=true end end
  for id in pairs(known.sessions)do if held[id]and not here[id]then changed=true else left[id]=true end end
  if changed then storage:set(B.POWERDI,{sessions=left})end
 end
 local forgot=storage:get(B.DELETED);if type(forgot)=="table"and next(forgot)then storage:set(B.DELETED,{})end
 if not storage:delete_backups()then if changed then storage:set(B.POWERDI,known)end;if type(forgot)=="table"and next(forgot)then storage:set(B.DELETED,forgot)end;return nil,"Saving failed, so the backups were not deleted."end
 return true
end
return B
