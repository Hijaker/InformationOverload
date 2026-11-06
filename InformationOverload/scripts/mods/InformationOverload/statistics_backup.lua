-- Reset moves the saved statistics into a backup and Restore brings backups back; each lands in one catalog commit, so a crash leaves it done or not done.
local B={}
B.KEYS={"lifetime_records_v1","solo_records_v1","psykhanium_logs_v1","history_baseline_v1","friend_summaries_v1"}
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
local function day(s)local y,m,d=tostring(s or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");return y and d.."/"..m.."/"..y or "an unknown day"end
function B.matches(n)return n==1 and "1 match"or tostring(n or 0).." matches"end
-- "the backup from 27/10/2026, 42 matches" or "all 3 backups, 120 matches"
function B.describe(list,all)
 if all and #list>1 then local n=0;for _,b in ipairs(list)do n=n+(b.matches or 0)end;return "all "..#list.." backups, "..B.matches(n)end
 local b=list[#list]or {};return "the backup from "..day(b.made)..", "..B.matches(b.matches)
end
-- The highest match number a backup used: the counters carry on from it, so a number is never reused.
function B.floor(storage,k)local n=0;for _,b in ipairs(storage.backups and storage:backups()or {})do n=math.max(n,b.seq and b.seq[k]or 0)end;return n end
function B.reset(storage,R,H,state,now)
 if not storage.stash then return nil,"Saving is off, so nothing was reset."end
 store(storage,state);prepare(storage);if not storage:flush()then return nil,"Your statistics could not be saved, so nothing was reset."end
 local seq={};for _,k in ipairs({"lifetime","solo","logs"})do seq[k]=math.max(state[k]and state[k].run_sequence or 0,B.floor(storage,k))end
 local out={lifetime=R.new(),solo=R.new(),logs=R.new()}
 for k,n in pairs(seq)do out[k].data.run_sequence=n end
 local life=out.lifetime.data;life.history_policy_revision=(state.lifetime.history_policy_revision or 0)+1
 -- Tracked Players are a setting, so they stay with the names given them, and the new revision has friend stats follow.
 life.friend_tracking=H.clone(state.lifetime.friend_tracking);life.friend_tracking_revision=(state.lifetime.friend_tracking_revision or 0)+1
 local baseline=H.baseline(life);baseline.run_sequence=0
 local kept=held(state.lifetime)or held(state.solo)or held(state.logs)or legacy(state.baseline)
 storage:stash(B.KEYS,kept and {made=now,matches=count(state.lifetime)+count(state.solo),logs=count(state.logs),seq=seq}or nil)
 store(storage,{lifetime=out.lifetime.data,solo=out.solo.data,logs=out.logs.data,baseline=baseline})
 if not storage:flush()then storage:unstage();store(storage,state);return nil,"Saving failed, so nothing was reset."end
 out.baseline=baseline;out.kept=kept;return out
end
-- Import keeps the matches it replaces as a backup made in the same commit, and returns the highest number they used.
function B.import(storage,state,now)
 if not storage.stash then return nil,"Saving is off, so nothing was imported."end
 storage:set(SETS.lifetime,state.lifetime);prepare(storage);if not storage:flush()then return nil,"Your statistics could not be saved, so nothing was imported."end
 local lost=false;for _,r in ipairs(storage.manifest and storage.manifest.missing or {})do if r.key==SETS.lifetime and r.match then lost=true end end
 local seq=math.max(state.lifetime.run_sequence or 0,B.floor(storage,"lifetime"))
 local info=(held(state.lifetime)or lost)and {made=now,matches=count(state.lifetime),logs=0,seq={lifetime=seq},import=true}or false
 storage:stash({SETS.lifetime,"friend_summaries_v1"},info or nil);return info,seq
end
-- Sets go oldest first, the current statistics last. Matches join by number; a dataset only one set holds anything of is taken whole, so a restore into an empty reset gives back exactly what was saved, and otherwise its statistics are rebuilt from every match.
function B.merge(d,policy,sets)
 local R,H=d.R,d.H;local now=sets[#sets];local out={}
 for _,s in ipairs(sets)do if held(s.lifetime)and legacy(s.baseline)then
  assert(not out.baseline,"Two sets of statistics from before match history cannot be combined, so nothing was restored.");out.baseline=s.baseline
 end end
 out.baseline=out.baseline or now.baseline or {schema=R.schema or 1,rows={},run_sequence=0,history_legacy_patches={}}
 for _,k in ipairs({"lifetime","solo","logs"})do
  local full,seq,rev,history,seen={},0,0,{},{}
  for _,s in ipairs(sets)do local x=s[k]
   if x then seq=math.max(seq,x.run_sequence or 0);rev=math.max(rev,x.history_policy_revision or 0)
    for _,run in ipairs(x.run_history or {})do local id=run.id or 0;seq=math.max(seq,id)
     if seen[id]then assert(same(seen[id],run),"Two different matches share number "..tostring(id)..", so nothing was restored.")else seen[id]=run;history[#history+1]=run end
    end
    if not empty(x)then full[#full+1]=x end
   end
  end
  table.sort(history,function(a,b)return (a.id or 0)<(b.id or 0)end)
  local data
  if #full>1 and k~="logs"then
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
 local first=all and 1 or #list;local brought=0
 local ok,merged,carry=pcall(function()
  local sets,carry={},{}
  for i=first,#list do local values,lost=storage:backup_load(list[i]);brought=brought+(list[i].matches or 0)
   -- Lost lifetime records are rebuilt from the matches, so only a lifetime with match history can do without them.
   local life=(list[i].entries or {}).lifetime_records_v1
   for _,r in ipairs(lost)do assert(r.match or r.key=="lifetime_records_v1"and life and life.history_present,"Part of the backup could not be read, so nothing was restored.");if r.match then carry[#carry+1]=r end end
   for _,r in ipairs(list[i].missing or {})do carry[#carry+1]=r end
   local s={};for k,key in pairs(SETS)do s[k]=values[key]end;sets[#sets+1]=s
  end
  sets[#sets+1]=state
  return B.merge(d,policy,sets),carry
 end)
 if not ok then return nil,(tostring(merged):gsub("^.-:%d+: ",""))end
 local keep={};for i=1,first-1 do keep[i]=list[i]end
 storage:stage(keep,carry[1]and carry or nil);store(storage,merged)
 if not storage:flush()then storage:unstage();store(storage,state);return nil,"Saving failed, so nothing was restored."end
 return merged,brought
end
function B.delete(storage)
 if not (storage.backups and storage:backups()[1])then return nil,"There are no backups to delete."end
 if not storage:delete_backups()then return nil,"Saving failed, so the backups were not deleted."end
 return true
end
return B
