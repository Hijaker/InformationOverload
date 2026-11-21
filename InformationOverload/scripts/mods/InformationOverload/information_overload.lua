local mod = get_mod("information_overload")
-- chat lines go out under [I/O] rather than the mod id; io_notify slides a message in from the right
local echo=mod.echo;mod.echo=function(self,...)rawset(self,"get_name",function()return "I/O"end);local ok,e=pcall(echo,self,...);rawset(self,"get_name",nil);if not ok then error(e)end end
function mod.io_notify(text)if Managers.event then Managers.event:trigger("event_add_notification_message","default",text,nil,UISoundEvents and UISoundEvents.default_click)end end

mod.io_weapon_name = mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/weapon_names")
local Patch = mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/game_patch")
local Storage=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/data_storage")
local Records = mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/records")
Storage.run_damage_info=Records.run_damage_info
Storage.run_useful=Records.run_useful
Storage.line_parts=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/warm_parts").all
local storage=Storage.bind(mod,Patch)
local PartyRecords=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")
local MissionSegments=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_segments")
MissionSegments.party_merge=PartyRecords.merge
MissionSegments.timeline_merge=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/combat_timeline").merge;MissionSegments.minutes_merge=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage").merge_minutes
MissionSegments.measurements_merge=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_measurements").merge
local HistoryRecalculation=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/history_recalculation")
Records.capture_contributions=HistoryRecalculation.capture;Records.capture_discarded=HistoryRecalculation.discarded;Records.patch_carry=Patch.carry
Records.departure_finalize=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/departure_tracking").finalize
-- what a saved match keeps, as it saves and when two saved parts of one mission are joined
local Saved=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/saved_match")(mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/combat_timeline"),PartyRecords,HistoryRecalculation,mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage"),mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/barrel_tracking"))
MissionSegments.entries=HistoryRecalculation.entries;MissionSegments.trim=Saved.trim;MissionSegments.barrel_events=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/barrel_tracking").events
local Missions = require("scripts/settings/mission/mission_templates")
local SpecialRules = require("scripts/settings/ability/special_rules_settings").special_rules
local function localized(key)
    if type(key)~="string" then return end
    local label=Localize(key)
    if type(label)=="string" and label~="" and label~=key and not label:find("<unlocalized",1,true) then return label end
end
local fallback_class_name=Records.class_name
Records.class_name=function(id) return localized("loc_class_"..tostring(id).."_name") or fallback_class_name(id) end
Records.mission_display_name=function(id)
    local template=Missions[id]
    return template and localized(template.mission_name) or "Unknown mission"
end
local RecoveryDelta=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/recovery_delta")
local saved = mod.io_data_get("lifetime_records_v1")
local recovery=mod.io_data_get("unfinished_run_v1")
if recovery and recovery.progress_delta and recovery.data_before then
 saved=RecoveryDelta.apply(recovery.data_before,recovery.progress_delta,saved and saved.run_history)
 mod.io_data_set("lifetime_records_v1",saved)
end
local normalized=Patch.normalize_saved(saved)
local previous
for _,run in ipairs(saved and saved.run_history or {}) do
    local p=Patch.normalize(run.context and run.context.patch);if p then previous=p end
end
if not previous then
    for _,row in pairs(saved and saved.rows or {}) do
        local p=Patch.normalize(row.context and row.context.patch)
        if p then
            local function order(v)
                local a,b,c=v:match("^(%d+)%.(%d+)%.(%d+)$")
                return string.format("%08d%08d%08d",tonumber(a),tonumber(b),tonumber(c))
            end
            if not previous or order(p)>order(previous) then previous=p end
        end
    end
end
local game_patch, update_patch=Patch.bind(mod,previous)
local tracker = Records.new(saved)
-- a match the main history saves may yet be joined by the next part of its mission; SoloPlay's and the Psykhanium's are never joined
Records.trim_saved=function(run,t)return Saved.trim(run,t==tracker and Saved.joinable(run))end
local history_policy=mod.io_data_get("history_policy_v1")or {late_join=true,rejoined=true,early_leave=true}
local saved_baseline=mod.io_data_get("history_baseline_v1")
local history_baseline=saved_baseline or HistoryRecalculation.baseline(tracker.data)
if storage.release_details then storage:release_details()end
-- The baseline is frozen; writing it back each launch would replace one that failed to read for good.
if not saved_baseline then mod.io_data_set("history_baseline_v1",history_baseline)end
local history_rebuilt_sequence=tracker.data.run_sequence or 0
local history_policy_dirty=false
-- a Counting change whose records were not saved before a crash is counted again under the setting
if (tonumber(history_policy.revision)or 0)>(tracker.data.history_policy_revision or 0)then tracker.data.history_policy_revision=history_policy.revision;tracker.dirty=true;history_policy_dirty=true end
local segment_checked_sequence
function mod.io_apply_patch(old,new,policy)
 tracker:finish_blo_trial();storage:inherit(old,new,policy);Patch.carry(tracker.data,old,new,policy);tracker.data.history_patch_carries=tracker.data.history_patch_carries or {};table.insert(tracker.data.history_patch_carries,{old=old,new=new,policy=HistoryRecalculation.clone(policy),after_run=tracker.data.run_sequence or 0});tracker.dirty=true;mod.io_data_set("lifetime_records_v1",tracker.data);storage:flush()
end
local function migrate_controls(tracker)
if not tracker.data.control_tracking_v55 then
    for _,row in pairs(tracker.data.rows) do
        for _,id in ipairs({"unpounced_wins","unnetted_wins","uncharged_wins"}) do row.best[id]=nil;if row.best_runs then row.best_runs[id]=nil end;if row.best_weapons then row.best_weapons[id]=nil end end
        row.unpounced_current,row.unnetted_current,row.uncharged_current=0,0,0
    end
    tracker.data.mode_streaks={}
    for _,run in ipairs(tracker.data.run_history or {}) do if not run.data_only and not run.context.training_history_test and type(run.victory)=="boolean" then
        local record=tracker:mode_streak(run.context.patch,run.context.mode);local c,b=record.current,record.best
        c.win=run.victory and (c.win or 0)+1 or 0;c.loss=not run.victory and (c.loss or 0)+1 or 0;b.win=math.max(b.win or 0,c.win);b.loss=math.max(b.loss or 0,c.loss)
    end end
    tracker.data.control_tracking_v55=true;tracker.dirty=true
end
end
migrate_controls(tracker)
local unfinished=mod.io_data_get("unfinished_run_v1")
if type(unfinished)=="table" and type(unfinished.data_before)=="table" then
    Patch.normalize_saved(unfinished.data_before)
    local before=Records.new(unfinished.data_before);migrate_controls(before)
    unfinished.data_before=before.data;mod.io_data_set("unfinished_run_v1",unfinished,false)
end
tracker.dirty=tracker.dirty or normalized
local lifetime_tracker = tracker
local collectors
local Revision=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/cache_revision")
local Averages=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/history_averages")
local TeamDamage=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage")
local overview_cache=mod.io_data_get("history_overview_cache_v1")
local prepare_job
local cache_signature
-- a match number given again after the match that had it went belongs to another match, so a row kept for that number is used only while
-- it was made from the match file the number names now; checked once each time the history changes
local function fresh_rows()
 local c=overview_cache;if not (c and c.version==Averages.CACHE_VERSION and c.rows)then return nil end
 -- a match still saving has no file yet, so the check waits for it rather than pass its row
 local sig=cache_signature();if c.checked~=sig then local tokens=c.tokens or {};local all=true
  for _,run in ipairs(tracker.data.run_history or {})do local id=tostring(run.id);local ref=storage.history_refs[run]
   if c.rows[id]~=nil and tokens[id]~=nil then if not ref then all=false elseif tokens[id]~=ref.desc.file then c.rows[id]=nil;if c.extremes then c.extremes[id]=nil end end end end
  if all then c.checked=sig end
 end
 return c.rows
end
mod.io_overview_cache=function()return fresh_rows()or prepare_job and prepare_job.out.rows or nil end
local revisions=Revision.new(mod.io_data_get("cache_revision_v1"),"0.5.32",tostring(APPLICATION_SETTINGS and APPLICATION_SETTINGS.game_version or game_patch()))
local function hub_ready()
 local manager=Managers.state and Managers.state.mission
 local name=manager and manager:mission_name()
 return name and Missions[name]and Missions[name].is_hub==true
end
function cache_signature()
 return tostring(tracker.data.run_sequence or 0)..":"..tostring(tracker.data.history_policy_revision or 0)
end
-- Only expose a complete projection for the currently committed history.
mod.io_extrema_cache=function()
 if overview_cache and overview_cache.version==Averages.CACHE_VERSION and overview_cache.signature==cache_signature()
  and not tracker.data.history_cache_rebuild_required then return overview_cache.extremes end
end
local function store_revision()mod.io_data_set("cache_revision_v1",revisions.state)end
local PsykSummary=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/psyk_summary")
local psyk=PsykSummary.keeper(storage)
mod.io_psyk_summary=function(data)return psyk.get(data or tracker.data)end
local solo_tracker=Records.new(mod.io_data_get("solo_records_v1"))
local solo_recount=HistoryRecalculation.recount_needed(solo_tracker.data)
local solo_recovered=mod.io_data_get("solo_unfinished_v1")
if type(solo_recovered)=="table" and solo_recovered.context and solo_recovered.context.solo then
    solo_recovered.data_only=true;solo_recovered.interrupted=true
    solo_tracker.mission=solo_recovered;solo_tracker:finish_mission(true,false,true)
    mod.io_data_set("solo_records_v1",solo_tracker.data,false);mod.io_data_set("solo_unfinished_v1",nil,false)
end
local psykhanium_logs=Records.new(mod.io_data_get("psykhanium_logs_v1"))
-- Move earlier explicit training snapshots into the dedicated log history.
local old_history=tracker.data.run_history or {}
for i=#old_history,1,-1 do
    local run=old_history[i]
    if run.context and run.context.training_history_test then
        psykhanium_logs.data.run_sequence=(psykhanium_logs.data.run_sequence or 0)+1
        run.id=psykhanium_logs.data.run_sequence;run.context.psykhanium_log=true
        psykhanium_logs.data.run_history=psykhanium_logs.data.run_history or {}
        table.insert(psykhanium_logs.data.run_history,1,run);table.remove(old_history,i)
        tracker.dirty=true;psykhanium_logs.dirty=true
    end
end
-- records an older build counted again, without the entries under their newer names, are counted again
if HistoryRecalculation.recount_needed(tracker.data)then tracker.data.history_cache_rebuild_required=true;tracker.dirty=true end
if solo_recount then
    local source={};for k,v in pairs(solo_tracker.data)do source[k]=v end;source.history_policy_revision=(source.history_policy_revision or 0)+1
    solo_tracker.data=HistoryRecalculation.rebuild(Records,HistoryRecalculation.legacy(Records,nil),source,history_policy,true);solo_tracker.blo_weapon_trackers={};solo_tracker.dirty=true
end
local solo_active=false
mod.io_solo_history=function() return solo_tracker end
mod.io_psykhanium_logs=function() return psykhanium_logs end
local psykhanium_session, psykhanium_manager
mod.io_psykhanium = function() return psykhanium_session end
local last_shot = setmetatable({}, {__mode = "k"})
local blo_chances = setmetatable({}, {__mode="k"})
local blo_boosted=setmetatable({},{__mode="k"})
mod.records = tracker -- Integration API for the next collectors; not a global.

-- a match's exclusion flag follows the policy and a save does not compare it, so it is set here rather than taken from the file
local function follow_policy(data,pause)for i,run in ipairs(data.run_history or {})do if pause and i%500==0 then pause()end;run.stats_excluded=not HistoryRecalculation.enabled(run,history_policy)or nil end end
follow_policy(tracker.data)
local FriendStats=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/friend_stats")
local friend_summaries=mod.io_data_get("friend_summaries_v1")or {}
local friend_signature,friend_people
mod.io_friend_stats=function()
 local signature=tostring(tracker.data.run_sequence)..":"..FriendStats.scope(mod)..":"..tostring(tracker.data.friend_tracking_revision or 0)
 if friend_signature==signature then
  local changed=false;for id,file in pairs(friend_summaries)do local name=FriendStats.display_name(id,file.name);if file.name~=name then file.name=name;changed=true end end
  if changed then mod.io_data_set("friend_summaries_v1",friend_summaries)end
  return friend_summaries,friend_people
 end
 local updated,people,changed=FriendStats.refresh(tracker,friend_summaries,FriendStats.scope(mod));friend_summaries=updated;friend_people=people;friend_signature=signature
 if changed then mod.io_data_set("friend_summaries_v1",friend_summaries)end
 return friend_summaries,people
end
mod.io_friend_action=function(id,action,name)
 tracker.data.friend_tracking=tracker.data.friend_tracking or {tracked={}};local p=tracker.data.friend_tracking;p.tracked=p.tracked or {}
 -- what was kept under the account key before the Steam id turned up moves onto the Steam id, so track and untrack act on one entry
 mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/player_identity").learn(tracker.data)
 local known=mod.io_identity or {};local acc=tostring(id):match("^account:(.+)$");if acc and known.ids and known.ids[acc]then id=known.ids[acc]end
 acc=known.acc and known.acc[tostring(id)];if acc then for _,t in ipairs({p.tracked,p.aliases})do local old="account:"..acc;if t[old]~=nil then if t[id]==nil then t[id]=t[old]end;t[old]=nil end end end
 if action=="track"then p.tracked[id]=name or true elseif action=="untrack"then p.tracked[id]=nil end
 tracker.data.friend_tracking_revision=(tracker.data.friend_tracking_revision or 0)+1;tracker.dirty=true;mod.io_friend_stats()
end
mod.io_friend_rows=function(patch,mode)
 local cache=mod.io_friend_stats();return FriendStats.rows(tracker,cache,patch,mode,FriendStats.scope(mod))
end
-- each part of the frame runs on its own, so one that fails leaves the rest running; its error is told once
local slow_trace=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/slow_trace").new(mod,function()
 local m=tracker.mission;local marks=m and m.completion_markers or {}
 return "active="..tostring(m~=nil).." mission="..tostring(m and m.context and m.context.mission_name)
  .." clock="..tostring(m and m.last_observed_clock).." checkpoint="..tostring(storage.job~=nil).." boss="..tostring(marks.boss_death)
end)
mod.io_slow_trace=slow_trace
local told={}
local function frame(tag,fn,...)
    local began=slow_trace.start()
    local ok,err=pcall(fn,...)
    slow_trace.finish(tag,began)
    if not ok and not told[tag]then told[tag]=true;mod:error("I/O %s: %s",tag,tostring(err))end
    return ok
end
local function saved_ok(ok)
    if ok==false and not storage.warned then storage.warned=true;mod:echo("Could not save the data files. Previous saved data is retained.")
        -- where it failed, for a report: a path inside the save folder, never the player's own folders
        local why=storage.a and storage.a.failure or storage.error
        local root=storage.a and storage.a.root;if why and root then local i=why:find(root,1,true);while i do why=why:sub(1,i-1)..why:sub(i+#root);i=why:find(root,1,true)end end
        if why then mod:info("I/O save failed: %s",why)end
    elseif ok then storage.warned=nil end
end
-- the records a SoloPlay match set, by the key of their rows, so a match brought back from its checkpoint names its match on them as the co-op one does
local function solo_credit_keys(m)
    local rows,key_of=solo_tracker.data.rows or {},{}
    for k in pairs(m.recovery_rows or {})do if rows[k]then key_of[rows[k]]=k end end
    local function keyed(refs,kept,field)
        local top,out={},{}
        local function add(k,id,value)
            if type(k)~="string"or id==nil or type(value)~="number"then return end
            top[k]=top[k]or {};local t=top[k][id]
            if not t then t={key=k,[field]=id,value=value};top[k][id]=t;out[#out+1]=t elseif value>t.value then t.value=value end
        end
        for _,u in ipairs(kept or {})do add(u.key,u[field],u.value)end
        for _,u in ipairs(refs or {})do add(key_of[u.row],u[field],u.value)end
        return out[1]and out or nil
    end
    return keyed(m.record_updates,m.record_update_keys,"name"),keyed(m.enemy_updates,m.enemy_update_keys,"enemy")
end
local click_job,click_rest,result_kept
local function save(force,checkpoint_only,sliced)
    if not force and (tracker.mission or solo_tracker.mission) then return end
    if hub_ready()and not tracker.mission and not (collectors and collectors.partial_pending and collectors:partial_pending())and segment_checked_sequence~=(tracker.data.run_sequence or 0)then
     segment_checked_sequence=tracker.data.run_sequence or 0
     local counted=PsykSummary.counted(tracker.data);local merged=MissionSegments.coalesce(tracker.data)
     if merged>0 then history_policy_dirty=true;tracker.dirty=true;tracker.data.history_policy_revision=(tracker.data.history_policy_revision or 0)+1;friend_signature=nil;psyk.follow(counted,PsykSummary.counted(tracker.data))end
    end
    if hub_ready()and HistoryRecalculation and not tracker.mission and not (collectors and collectors.partial_pending and collectors:partial_pending())and (history_policy_dirty or history_rebuilt_sequence~=(tracker.data.run_sequence or 0)and (tracker.data.history_rebuild_version==1 or history_policy.late_join==false or history_policy.rejoined==false or history_policy.early_leave==false))and not tracker.data.history_cache_rebuild_required then
     tracker.data.history_cache_rebuild_required=true;tracker.dirty=true
    end
    if collectors and collectors.checkpoint then frame("Checkpoint",collectors.checkpoint,collectors) end
    local solo_checkpoint,ok
    if solo_tracker.mission then
        local function clone(value) if type(value)~="table" then return value end;local copy={};for k,v in pairs(value) do copy[k]=clone(v) end;return copy end
        solo_checkpoint={}
        for _,field in ipairs({"started_at","context","full","exploded","failed","damage","record_values","replay_best","replay_armour","replay_kill_segments","replay_blo_contexts","replay_blo_best","kills","incidents","friendly_fire_pairs","pickup_pairs","pickup_states","team_psykers","field_improvisation","enemy_lethality","hyper_critical","haymaker","class_events","clutches","clutch_bot_recovered","operative_clutches","kill_categories","leave_hits","departure_snapshot","departure_events","all_departures","segments","resumed","bot_links","bot_candidates","bot_appearances","bot_pickup_events","last_departure","last_observed_clock","ended_clock","ended_wall","measurements","boss_seen","boss_credit_seen","boss_operative_seen","boss_operatives","boss_kills","departed_players","players_left","lethality_events","lethality_active","enemy_kill_counts","timing_origin","completion_time","completion_markers","timing_diagnostics","barrel_pops","team_damage","party_records","support","psyk_dps","recovery_rows","experimental"}) do solo_checkpoint[field]=clone(solo_tracker.mission[field]) end
        solo_checkpoint.record_update_keys,solo_checkpoint.enemy_update_keys=solo_credit_keys(solo_tracker.mission)
    end
    -- setting it marks the catalog changed, so with no SoloPlay match under way every 15 s hub save would build the catalog again
    if solo_checkpoint or mod.io_data_get("solo_unfinished_v1")~=nil then mod.io_data_set("solo_unfinished_v1",solo_checkpoint,false)end
    if solo_tracker.dirty then mod.io_data_set("solo_records_v1",solo_tracker.data,false);solo_tracker.dirty=false end
    if psykhanium_logs.dirty then mod.io_data_set("psykhanium_logs_v1",psykhanium_logs.data,false);psykhanium_logs.dirty=false end
    if tracker.dirty then
        mod.io_data_set("lifetime_records_v1", tracker.data, false)
        tracker.dirty = false
    end
    if force then
        if tracker.mission then if revisions:prepare()then store_revision()end
        elseif not (collectors and collectors:partial_pending())then if revisions:commit(cache_signature())then store_revision()end end
        -- a save away from the Mourningstar leaves the records for the next one, but never while a checkpoint is on disk, as its commit removes
        -- the checkpoint and a crash before the next save would lose the finished match's wins, records and streaks
        local mode=checkpoint_only and tracker.mission~=nil and true or not hub_ready()and not storage.journal_active and "history"or false
        -- until the save holding a finished match commits, a crash brings back the checkpoint on disk instead, so that save is spread over
        -- frames only once the checkpoint holds the mission as it ended; a SoloPlay checkpoint never does, so a SoloPlay match saves in one go
        if tracker.mission then result_kept=nil elseif sliced and(storage.journal_active and not result_kept or storage.dirty and storage.dirty.solo_records_v1 and not solo_tracker.mission)then sliced=nil end
        -- a spread save asked for while a click's own save runs goes once that is done
        if sliced and click_job and storage.job==click_job then click_rest=true else ok=storage:flush(mode,sliced);saved_ok(ok)end
    end
    -- worked out after the flush, so changed friend stats go with the next save
    if hub_ready()and mod.io_friend_stats then frame("Friends",mod.io_friend_stats) end
    return ok
end
-- What the player just set is saved on its own first, spread over frames, so a crash in the longer save of everything
-- else, such as the records a Counting change marks, cannot lose it; that save follows once it is done. A setting
-- clicked just before goes first with it.
local first_keys={}
local function save_click(...)
 -- a held import still saving keeps going: the keys stay marked and the save after it takes them, where settling here would restart it
 if storage.job and storage.job.hold then return end
 -- in a mission, or with a reset, restore, import or new stats group still to save, everything is saved at once as before
 local whole=not storage.settle or tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending()or storage.staged_backups or storage.prune
 for _ in pairs(storage.inheritances or {})do whole=true end
 if whole then save(true);return end
 -- a mission that ended is let go from its checkpoint only by the save that holds its match, so that goes as one save
 if storage.journal_active or storage.dirty.unfinished_run_v1 or storage.dirty.solo_unfinished_v1 then save(true,nil,true);return end
 storage:settle()
 for _,key in ipairs({...})do first_keys[key]=true end
 local rest,only={},{}
 for key in pairs(storage.dirty)do if first_keys[key]then only[key]=true else rest[key]=true end end
 storage.dirty=only
 local ok=storage:flush(false,true);click_job=storage.job
 for key in pairs(rest)do storage:touch(key)end
 click_rest=true
 if ok~=nil then saved_ok(ok)end
end

local display_options=mod.io_data_get("display_options_v1")or {numbers="compact"}
if display_options.default_class and display_options.default_class~="best"and display_options.default_class~="worst"and display_options.default_class~="favorite"then display_options.favorite_class=display_options.favorite_class or display_options.default_class;display_options.default_class="favorite"end
-- no Settings row sets split_enemies, so a value from Personal Records is dropped
display_options.split_enemies=nil
mod.io_display_options=function()return display_options end
mod.io_set_display_option=function(key,value)display_options[key]=value;mod.io_data_set("display_options_v1",display_options);save_click("display_options_v1")end
mod.io_history_policy=function()return history_policy end
-- what counts changed: statistics are rebuilt in the hub, and the saved revision makes a relaunch before then rebuild too
local function policy_changed()
 tracker.data.history_policy_revision=(tracker.data.history_policy_revision or 0)+1;tracker.dirty=true;history_policy_dirty=true
 history_policy.revision=tracker.data.history_policy_revision;mod.io_data_set("history_policy_v1",history_policy);save_click("history_policy_v1")
end
mod.io_toggle_history_policy=function(key)history_policy[key]=history_policy[key]==false;policy_changed()end

local function context(action, allow_training_blo, global_blo)
    local mission_manager = Managers.state.mission
    local game_mode_manager = Managers.state.game_mode
    local player_manager = Managers.player
    if not mission_manager or not game_mode_manager or not player_manager then return nil, "managers unavailable" end
    local player = player_manager:local_player_safe(1)
    if not player or player.player_unit ~= action._player_unit then return nil, "not local player" end
    local mission_name = mission_manager:mission_name()
    local mission = mission_name and Missions[mission_name]
    if not mission or mission.is_hub then return nil, "hub or unknown mission" end
    local game_mode_name = game_mode_manager:game_mode_name()
    local training = mod.io_is_training()
    local solo=mod.io_is_solo()
    if training and not global_blo and mod:get("disable_psykhanium_tracking")==true then return nil,"Psykhanium tracking disabled" end
    local allow_training = allow_training_blo and training
    -- Fail closed outside actual co-op/Havoc missions. Never count training/hub.
    if not solo and not allow_training and game_mode_name ~= "coop" and game_mode_name ~= "coop_complete_objective" and game_mode_name ~= "havoc" then
        return nil, "excluded mode: " .. tostring(game_mode_name)
    end
    if mission_name:find("prologue") or (not allow_training and training) then return nil, "training or prologue" end
    local profile = player:profile()
    local archetype = profile and profile.archetype
    local weapon = action._weapon_template and action._weapon_template.name or "unknown-weapon"
    local difficulty_manager = Managers.state.difficulty
    local havoc_data = difficulty_manager and difficulty_manager:get_parsed_havoc_data()
    local havoc = havoc_data ~= nil or game_mode_name == "havoc"
    local difficulty = difficulty_manager and difficulty_manager:get_initial_resistance() or "unknown-difficulty"
    if not havoc and difficulty_manager and difficulty_manager.get_danger_settings then
        local danger = difficulty_manager:get_danger_settings()
        if danger and danger.name and danger.name ~= "undefined" then difficulty = danger.name end
    end
    if havoc then difficulty = havoc_data and havoc_data.havoc_rank or "havoc-rank-unverified" end
    if allow_training then havoc=false;difficulty="psykhanium" end
    local wt=action._weapon_template or {}
    local grenade=wt.is_grenade_ability_weapon==true or wt.ammo_template=="grenade"
    for _,keyword in ipairs(wt.keywords or {}) do if keyword=="grenade" then grenade=true end end
    local mission_instance
    local connection=Managers.connection
    if connection and type(connection.matched_game_session_id)=="function"then local id=connection:matched_game_session_id();if id then mission_instance=tostring(id)end end
    return {
        mission_instance=mission_instance,
        mission_name=mission_name,
        mission_display_name=Records.mission_display_name(mission_name),
        grenade=grenade,
        solo=solo,
        mode = havoc and "havoc" or "non-havoc",
        patch = game_patch(),
        difficulty = tostring(difficulty), class = archetype and archetype.name or "unknown-class",
        character_name = profile and profile.name,
        character = player:character_id() or "unknown-character", category = "ranged",
        weapon = weapon, explosive = weapon:find("thumper") ~= nil or weapon:find("gauntlet") ~= nil,
    }
end

-- SoloPlay uses real mission names/Havoc data in an offline singleplay session.
-- Classify the environment before considering difficulty or Havoc metadata.
mod.io_is_training=function()
    local state=Managers.state or {}
    local name=state.mission and state.mission:mission_name()
    local mode=state.game_mode and state.game_mode:game_mode_name()
    local mission=name and Missions[name]
    if not mission or mission.is_hub or mode=="hub" or mode=="prologue_hub" or name:find("prologue") then return false end
    if mode=="training_grounds" or mode=="shooting_range" or (name and (name:find("training") or name:find("shooting_range"))) then return true end
    return false
end
mod.io_is_solo=function()
    local state=Managers.state or {};local name=state.mission and state.mission:mission_name();local mission=name and Missions[name]
    if not mission or mission.is_hub or name:find("prologue") then return false end
    local solo=get_mod("SoloPlay")
    if solo and type(solo.is_soloplay)=="function" and (not solo.is_enabled or solo:is_enabled()) then
        local active=solo.is_soloplay()
        if active then return true end
    end
    return false
end

local function training_tracker()
    local manager=Managers.state and Managers.state.mission
    if not psykhanium_session or psykhanium_manager~=manager then psykhanium_session,psykhanium_manager=Records.new(),manager end
    return psykhanium_session
end

local function observe_blo(action, t)
    if not mod:is_enabled() or mod:get("capture_blo")==false then return end
    if action._unit_data_extension and action._unit_data_extension.is_resimulating then return end
    local talents = action._talent_extension
    if not talents or not (talents:has_special_rule(SpecialRules.ogryn_leadbelcher)
        or talents:has_special_rule(SpecialRules.ogryn_leadbelcher_improved)) then return end
    local c, reason = context(action, true, true)
    if not c then return end
    local buffs=ScriptUnit.has_extension(action._player_unit,"buff_system")
    c.blo_variant=buffs and "base" or "unknown"
    for _,buff in pairs(buffs and buffs._buffs_by_index or {}) do
        if buff._template_name=="ogryn_blo_melee" then c.blo_talent_selected=true end
    end
    c.blo_variant=blo_boosted[action]==true and "boosted" or c.blo_variant
    c.blo_chance=blo_chances[action]
    local shot_number = action._action_component and action._action_component.num_shots_fired or 0
    local token = tostring(t) .. ":" .. tostring(shot_number)
    if last_shot[action] == token then return end
    last_shot[action] = token
    local blo_tracker=mod.io_is_solo() and solo_tracker or tracker
    blo_tracker:blo(c, action._leadbelcher_shot == true)
end

-- Normal BLO shot observations share the measurement collector ammunition wrapper.
local function capture_blo_chance(action,is_melee,is_ranged,chance)
    if not is_ranged or (action._unit_data_extension and action._unit_data_extension.is_resimulating) then return end
    local buffs=action._buff_extension
    if not buffs then return end
    local stats=buffs:stat_buffs()
    blo_boosted[action]=false
    for _,buff in pairs(buffs._buffs_by_index or {}) do
        if buff._template_name=="ogryn_blo_melee_active_buff" then blo_boosted[action]=true;break end
    end
    local value=(chance or 0)+(stats.leadbelcher_chance_bonus or 0)
    if buffs:has_keyword("guaranteed_leadbelcher") then value=1 end
    blo_chances[action]=math.max(0,math.min(1,value))
end
-- Inherited methods are cached on concrete classes; hook their copies too.
for _,class in ipairs({"ActionWeaponBase","ActionShoot","ActionShootProjectile","ActionShootHitScan","ActionShootPellets"}) do
    mod:hook_safe(class,"_check_for_lucky_strike",capture_blo_chance)
end


local hub_wait=0
local rebuild_job
-- what each finished replay put in place of the data it rebuilt, so an import begun on that data can start again on the new
local replayed=setmetatable({},{__mode="k"})
-- A damage reset or a new stats group edits the data in place, so either one restarts a replay under way.
local function rebuild_inputs()local d=tracker.data;return cache_signature()..":"..tostring(d.history_damage_reset_after)..":"..#(d.history_patch_carries or {})end
-- a held frame on a loading screen goes unseen
local function loading_screen()local ui=Managers.ui;return ui and ui.view_active and ui:view_active("loading_view")or false end
-- a replay that failed is not tried again until what it reads changes, or it would fail and redo its work every frame
local cache_failed
local function update_derived_cache(dt)
 if storage.job and storage.job.hold then return end
 local hidden=loading_screen()
 if not (hub_ready()or hidden)or tracker.mission or collectors and collectors:partial_pending()then hub_wait=0;rebuild_job=nil;return end
 if not hidden then hub_wait=hub_wait+dt end
 if cache_failed and cache_failed==rebuild_inputs()then return end
 if not hidden and hub_wait<3 then return end
 if revisions:commit(cache_signature())then store_revision()end
 -- The history replay and the Averages rows run a few milliseconds a frame, so a long history never freezes the hub, and
 -- on a loading screen, where no one sees a frame held, they run thirty a frame, so most of it is done before the hub.
 local os=Mods and Mods.lua and Mods.lua.os;local stop=os and os.clock()+(hidden and .03 or .004)
 if prepare_job and prepare_job.signature~=cache_signature()then prepare_job=nil end
 if prepare_job then
  if not Averages.prepare_step(prepare_job,stop and function()return os.clock()<stop end)then return end
  overview_cache=prepare_job.out;prepare_job=nil
  overview_cache.version=Averages.CACHE_VERSION;overview_cache.signature=cache_signature();mod.io_data_set("history_overview_cache_v1",overview_cache)
  revisions:commit(cache_signature());revisions:stamp();store_revision()
  -- its save is spread over frames, on a loading screen too, where one written in one go held a frame some 130 ms
  friend_signature=nil;save(true,nil,true)
  return
 end
 if rebuild_job and (rebuild_job.signature~=rebuild_inputs()or rebuild_job.data~=tracker.data)then rebuild_job=nil end
 if not rebuild_job then
  if revisions:valid()and not tracker.data.history_cache_rebuild_required and overview_cache and overview_cache.version==Averages.CACHE_VERSION then return end
  -- Coalesce and rebuild only at rest. History files retain all source facts.
  local counted=PsykSummary.counted(tracker.data);local coalesced=MissionSegments.coalesce(tracker.data)
  if coalesced>0 then tracker.data.history_policy_revision=(tracker.data.history_policy_revision or 0)+1 end
  segment_checked_sequence=tracker.data.run_sequence or 0
  -- The replay yields between runs; nothing may pcall between here and that yield, or it cannot leave the coroutine.
  local job={data=tracker.data,signature=rebuild_inputs(),counted=counted}
  job.co=coroutine.create(function()return HistoryRecalculation.rebuild(Records,history_baseline,job.data,history_policy,nil,function()if job.stop and os.clock()>=job.stop then coroutine.yield()end end)end)
  rebuild_job=job
 end
 rebuild_job.stop=stop
 local ok,data=coroutine.resume(rebuild_job.co)
 if not ok then rebuild_job=nil;error(data,0)end
 if coroutine.status(rebuild_job.co)~="dead"then return end
 local counted=rebuild_job.counted;replayed[rebuild_job.data]=data;rebuild_job=nil;tracker.data=data
 -- the replay sets each match's exclusion flag in place, so the summary follows the matches it moved
 psyk.follow(counted,PsykSummary.counted(tracker.data))
 -- and a friend's summary that counted a match the replay now leaves out is counted again
 local dropped;for _,run in ipairs(data.run_history or {})do if run.stats_excluded then local key=tostring(run.id);for id,file in pairs(friend_summaries)do if file.matches and file.matches[key]then friend_summaries[id]=nil;dropped=true end end end end
 if dropped then friend_signature=nil;mod.io_data_set("friend_summaries_v1",friend_summaries)end
 tracker.data.history_cache_rebuild_required=nil;tracker.blo_weapon_trackers={};tracker.dirty=true
 history_rebuilt_sequence=tracker.data.run_sequence or 0;history_policy_dirty=false
 prepare_job=Averages.prepare_job(tracker.data.run_history,TeamDamage,Records,overview_cache and overview_cache.version==Averages.CACHE_VERSION and overview_cache or nil,function(run)
  local ref=storage.history_refs[run];return ref and ref.desc.file or tostring(run)
 end)
 prepare_job.signature=cache_signature()
end
-- Opening the Psykhanium tab reads every saved log; read them here a few a second instead. A missing or out of date
-- mission summary is counted again here too, a few milliseconds a frame, once the history replay above is done.
local People,Slots,Social,Stats,BossWarm,bench_wait
-- the history and screens the hub warm-up last finished on, and those the boss read last came round the list on
local bench_done,boss_round=setmetatable({},{__mode="v"}),setmetatable({},{__mode="v"})
local function bench_same(s,d,sc,se)local h=d.run_history;return h~=nil and s.h==h and s.n==#h and s.seq==d.run_sequence and s.rev==d.history_policy_revision and s.sc==sc and s.se==se end
local function bench_set(s,d,sc,se)local h=d.run_history;s.h,s.n,s.seq,s.rev,s.sc,s.se=h,#h,d.run_sequence,d.history_policy_revision,sc,se end
-- the Squad Social records read the same match files, so with the screen on they are read ahead too, not one a frame under the cursor
local function social_warm()
 if mod:get("screen_social")==false then return true end
 Social=Social or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/social_record")
 local done,n=Social.warm(tracker.data.run_history or {});return done>=n
end
-- Trends Damage and Team Share read each match file's share, so it is read ahead too
local function share_warm(at)Stats=Stats or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_data_stats");return Stats.prewarm(tracker.data.run_history,at)end
-- the Psykhanium summary is counted again only when the history or the summary changes; checking it walks every match
local psyk_seen={}
local function psyk_step(more)
 local d=tracker.data;local s=psyk_seen;local n=#(d.run_history or {})
 if s.data==d and s.n==n and s.seq==d.run_sequence and s.rev==d.history_policy_revision and s.sum==psyk.sum then return true end
 local busy=psyk.job
 if not psyk.step(d,more)then return false end
 s.data,s.n,s.seq,s.rev,s.sum=d,n,d.run_sequence,d.history_policy_revision,psyk.sum
 if busy and storage.release_details then storage:release_details()end
 return not busy
end
local function warm_bench(dt)
 if hub_wait<3 then return end
 if not rebuild_job and not prepare_job then local os=Mods and Mods.lua and Mods.lua.os;local stop=os and os.clock()+.003
  if not psyk_step(function()return stop and os.clock()<stop end)then return end end
 bench_wait=(bench_wait or 0)+dt;if bench_wait<.2 then return end;bench_wait=0
 People=People or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_data_people")
 -- the Weapons page reads each match's damage by armour from what is read here, a match at a time
 if People.warm()then Slots=Slots or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/run_slots");local d=tracker.data;local h=d.run_history
  -- once all of it is in, the history is not walked again until it or the screens change
  local sc,se=mod:get("screen_social"),mod:get("screen_endscreen")
  if bench_same(bench_done,d,sc,se)then return end
  local a,at=Slots.warm(h);local b=share_warm(at);local c=social_warm();local e=true
  -- the End Screen's Boss Damage average reads each match's boss damage, so a match that saved before it kept that has it read ahead too
  -- it reads a slice a call, so it counts as done only after a whole round of the list on the same history
  if se~=false then BossWarm=BossWarm or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/warm_parts")
   if BossWarm.boss_warm(h)then e=h~=nil and bench_same(boss_round,d,sc,se);if h then bench_set(boss_round,d,sc,se)end else e=false end end
  if h and a and b and c and e then bench_set(bench_done,d,sc,se)end
 end
end
-- On a loading screen a held frame goes unseen, so the match files the hub would read a match at a time are read there,
-- and the modules that read them load there, rather than holding hub frames.
local function warm_hidden()
 if not loading_screen()or rebuild_job or prepare_job then return end
 local os=Mods and Mods.lua and Mods.lua.os;if not os then return end;local stop=os.clock()+.03
 local function more()return os.clock()<stop end
 if not psyk_step(more)then return end
 People=People or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_data_people")
 Slots=Slots or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/run_slots")
 -- the three read ahead side by side, so each match file is decoded once for all of them, the share before Squad Social while Run Slots' file is still held
 while more()do if People.warm()then local h=tracker.data.run_history;local a,at=Slots.warm(h);local b=share_warm(at);local c=social_warm();if a and b and c then return end end end
end
-- a match saves into folders named for its patch and class; they are made in the background as it starts, as making one at the save holds the game
local prepared=setmetatable({},{__mode="k"})
local function prepare_folders(t,key)
    local m=t and t.mission;if not m or prepared[m]or not (m.context and m.context.patch)or not storage.prepare_run then return end
    prepared[m]=true;storage:prepare_run(m.context,key)
end
local elapsed = 0
local warm_off,dt_now=false,0
local function update_stats()
    elapsed=elapsed+dt_now
    -- In a mission the checkpoint runs a minute apart, a couple of milliseconds a frame.
    -- a held job, a Power DI import's commit, is stepped by its owner
    if storage.job then if not storage.job.hold then local ok=storage:step();if ok=="baseline"then save(true,true,true)else saved_ok(ok)end end
    elseif not collectors or not collectors.recovery_ready or collectors:recovery_ready()then
        if click_rest or elapsed>=(tracker.mission and 60 or 15)then elapsed=0;click_rest=nil;click_job=nil;save(true,true,true)
        -- from a mission's first calm moment its recovery baseline is built over frames, so the checkpoint written as it ends need not build it
        elseif tracker.mission and storage.prepare_baseline then storage:prepare_baseline(tracker.mission.data_before)end
    end
end
-- saves from before 1.0.4 are tidied a little at a time on the Mourningstar, while nothing else is saving or reading the history
local SaveTidy=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/save_tidy")(storage,Saved,
 function()return {lifetime_records_v1=tracker,psykhanium_logs_v1=psykhanium_logs,solo_records_v1=solo_tracker}end,
 function(dropped,cut)if mod.info then mod:info("I/O tidied older saves: research left %d matches, and %d were packed",dropped,cut)end end)
local tidy_wait=0
local function tidy(dt)
 if SaveTidy.done then return end
 -- the open panel holds the match it shows, which a step would let go; a part read is dropped when the tidy has to wait
 if not hub_ready()or hub_wait<3 or mod.io_view_open or tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending()or rebuild_job or prepare_job
  or not storage.ready or storage.job or storage.pending or storage.journal_active or tracker.dirty or solo_tracker.dirty or psykhanium_logs.dirty then tidy_wait=0;if SaveTidy.busy then SaveTidy.drop()end;return end
 tidy_wait=tidy_wait+dt;if tidy_wait<.5 and not SaveTidy.busy then return end;tidy_wait=0
 if SaveTidy.step()then click_rest=true end
end
local tidy_off=false
mod.update = function(dt)
    dt_now=dt
    if mod.io_step_history_import then mod.io_step_history_import()end
    -- a Power DI import that faults is dropped, rather than faulting every frame; its fault goes to the log, never chat
    if mod.io_step_powerdi then local began=slow_trace.start();local ok,err=pcall(mod.io_step_powerdi);slow_trace.finish("Power DI",began);if not ok then pcall(mod.io_powerdi_fault,err)end end
    -- switched off, only a save already under way is finished
    if not mod:is_enabled()then if storage.job then frame("Save",update_stats)end;return end
    local manager = Managers.state and Managers.state.mission
    local name = manager and manager:mission_name()
    local training = mod.io_is_training()
    solo_active=mod.io_is_solo()
    if training and mod:get("disable_psykhanium_tracking")~=true then
        training_tracker()
    else psykhanium_session, psykhanium_manager = nil, nil end
    local mission_template=name and Missions[name]
    frame("Patch",update_patch,(not name or mission_template and mission_template.is_hub or training)and not (collectors and collectors:partial_pending()))
    if collectors then frame("Collectors",collectors.update,collectors,dt)end
    -- the scoreboard's cursor goes as soon as the board does
    if mod.io_scoreboard and mod.io_scoreboard.input then frame("Scoreboard",mod.io_scoreboard.input.tick)end
    frame("Folders",function()prepare_folders(tracker,"lifetime_records_v1");prepare_folders(solo_tracker,"solo_records_v1");prepare_folders(psykhanium_session,"psykhanium_logs_v1")end)
    if not frame("History",update_derived_cache,dt)then rebuild_job=nil;prepare_job=nil;cache_failed=rebuild_inputs()end
    -- the warm-ups are only a head start, so one that fails stops until the next mission rather than failing every frame
    if not warm_off and not (frame("Warm-up",warm_bench,dt)and frame("Warm-up",warm_hidden))then warm_off=true end
    if not tidy_off and not frame("Tidy",tidy,dt)then tidy_off=true end
    frame("Save",update_stats)
end
-- sliced, from leaving a mission whose result is already in its checkpoint: the save spreads over frames as the end screen comes up, rather
-- than taking back the one already spreading and writing it all in one frame
local function boundary(sliced)
    warm_off=false
    if collectors then frame("Collectors",collectors.boundary,collectors)end
    if mod.io_scoreboard then mod.io_scoreboard.state.t0=nil;if mod.io_scoreboard.input then pcall(mod.io_scoreboard.input.release)end end
    frame("Mission end",tracker.boundary,tracker); last_shot = setmetatable({}, {__mode = "k"}); frame("Save",save,true,nil,sliced and result_kept==true or nil)
end
-- off the hub every save leaves the shared records for the hub, so a quit with no mission under way writes them
mod.on_unload = function() local playing=tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending();boundary();if storage.pending and not playing then saved_ok(storage:flush())end end
-- switched off, I/O's hooks no longer run, so each screen puts the game's own widgets back here, and the mod list its plain name
-- a mission under way is kept as data only, as I/O never sees how it ends, so it counts no loss and breaks no streak
mod.on_disabled = function() local m=tracker.mission;if m and not m.context.solo then m.data_only=true end;boundary();for _,s in pairs(mod.io_screens or {})do if type(s)=="table"and s.off then pcall(s.off)end end;if mod.io_options_name then pcall(mod.io_options_name.off)end end
mod.on_game_state_changed = function(status, state)
    if state == "StateGameplay" and status == "exit" then
        boundary(true); psykhanium_session, psykhanium_manager = nil, nil
    end
end
local ImportedRecords=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/imported_records")
mod.on_setting_changed = function(id)
    -- Imported Matches Count For Records changes which matches hold records, so it rebuilds them as a Counting switch does
    if id==ImportedRecords.KEY then return policy_changed() end
    if id~="disable_psykhanium_tracking" and id~="capture_blo" then return end
    -- Only the Psykhanium changes what is tracked live; a mission keeps its run and only closes the open BLO chain.
    if mod.io_is_training() then boundary()
    elseif id=="capture_blo" then for _,t in ipairs({tracker,solo_tracker}) do t:finish_blo(true);t:finish_selected_blo(true);for _,child in pairs(t.blo_weapon_trackers or {}) do child:finish_blo(true);child:finish_selected_blo(true) end end end
    if id=="disable_psykhanium_tracking" then psykhanium_session,psykhanium_manager=nil,nil end
end

mod.io_reset_psykhanium=function()
    if not psykhanium_session then return false end
    if collectors then collectors:boundary() end
    psykhanium_session=Records.new()
    return true
end
mod.io_capture_psykhanium=function()
    if psykhanium_session and psykhanium_session.mission and collectors then psykhanium_session.mission.team_damage=collectors:damage_snapshot(psykhanium_session.mission)end
    local frozen=Records.new()
    if not frozen:add_training_snapshot(psykhanium_session) then return end
    local run=frozen.data.run_history[1]

    return run
end
mod.io_save_psykhanium_log=function(run,name)
    name=type(name)=="string" and name:gsub("^%s+",""):gsub("%s+$","") or ""
    if not run or name=="" then mod:echo("Enter a name to save the Psykhanium log.");return false end
    run.context.mission_display_name=name;run.context.psykhanium_log=true

    psykhanium_logs.data.run_sequence=(psykhanium_logs.data.run_sequence or 0)+1
    run.id=psykhanium_logs.data.run_sequence
    psykhanium_logs.data.run_history=psykhanium_logs.data.run_history or {}
    table.insert(psykhanium_logs.data.run_history,run);mod.io_data_set("psykhanium_logs_v1",psykhanium_logs.data);psykhanium_logs.dirty=false;save_click("psykhanium_logs_v1");return true
end
local api = {
    -- spread over frames, as the player is watching, once save finds the checkpoint on disk holds the mission as it ended
    mission_finished = function() save(true,nil,true) end,
    -- a mission's checkpoint as it ended, its result in it, written in one go before its match is saved
    keep_result = function() if tracker.mission then result_kept=save(true,true)==true end end,
    -- the End Screen's moment rides on the next full save, so the match just saved is not written again for it
    end_screen_marked = function(t) local key=t==tracker and "lifetime_records_v1" or t==solo_tracker and "solo_records_v1";if key and storage.touch then storage:touch(key) end;mod.io_history_touched=(mod.io_history_touched or 0)+1 end,
    recovery_delta = function(m) return RecoveryDelta.capture(m.data_before,tracker.data,m.recovery_rows) end,
    in_hub = function()
        local manager=Managers.state and Managers.state.mission
        local name=manager and manager:mission_name()
        return name and Missions[name] and Missions[name].is_hub==true
    end,
    observe_blo_shot = observe_blo,
    dashboard_tracker = function() return tracker end,
    tracker = function() return psykhanium_session or (solo_active and solo_tracker) or tracker end,
    context = function(action)
        local c,reason=context(action,psykhanium_session~=nil)
        if c then solo_active=c.solo==true;if c.difficulty~="psykhanium" then psykhanium_session,psykhanium_manager=nil,nil end end
        return c,reason
    end,
    enabled = function() local old=get_mod("personal_records");if old and old.is_enabled and old:is_enabled()then if not mod.io_legacy_conflict_warned then mod:echo("Collection paused: disable Personal Records before testing this version.");mod.io_legacy_conflict_warned=true end;return false end;return mod:is_enabled() and not (mod:get("disable_psykhanium_tracking")==true and mod.io_is_training()) end,
    debug = function() return false end,
    save = function(force,sliced) if not psykhanium_session then save(force==true,nil,sliced==true) end end,
}
local finish=Records.finish_mission
Records.finish_mission=function(self,...)
 local m=self.mission;local count=#(self.data.run_history or {});local counted=self==tracker and PsykSummary.counted(self.data)
 local result=finish(self,...)
 if result and m and self==tracker and #(self.data.run_history or {})>count then
  local merged=MissionSegments.coalesce(self.data)
  segment_checked_sequence=self.data.run_sequence or 0
  if merged>0 then history_policy_dirty=true;self.dirty=true;self.data.history_policy_revision=(self.data.history_policy_revision or 0)+1;friend_signature=nil end
  local saved=self.data.run_history[#self.data.run_history];saved.stats_excluded=not HistoryRecalculation.enabled(saved,history_policy)or nil
  psyk.follow(counted,PsykSummary.counted(self.data))
 end
 return result
end
-- each part loads on its own, so one that fails to load leaves the rest working
local function part(tag,fn)local ok,v=pcall(fn);if ok then return v end;mod:error("I/O %s: %s",tag,tostring(v))end
collectors = part("Collectors",function()return mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/collectors")(mod, api)end)
mod.io_collectors = collectors
-- ##### Public read-only surface ##########################################
-- Other mods read Information Overload's live numbers through mod.io_public.
-- Nothing here writes, saves, or returns a table this mod owns: every value
-- returned is built fresh, and a reader keeps the ones it built for its own
-- mod alone. A slot number is never accepted as identity.
local FrontendContract=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/frontend_contract")
mod.io_public = {
    version = 2,
    capabilities = { live = collectors ~= nil, roster = true, history = true, events = true, frontend_contract = FrontendContract.version },
}
do
    -- the kinds and armour keys the squad table files damage under, with the names the pages give them; void shields are in no total
    local CATEGORIES = { total = "Total", melee = "Melee", ranged = "Ranged", other = "Other", boss = "Bosses", dot = "Damage Over Time",
        dot_bleed = "Bleed", dot_burn = "Burn", dot_soulblaze = "Soulblaze", dot_toxin = "Toxin", dot_other = "Other Damage Over Time" }
    local ARMOURS = { unarmored = "Unarmoured", armored = "Flak", resistant = "Unyielding", disgustingly_resilient = "Infested",
        super_armor = "Carapace", berserker = "Maniac", unknown = "Unknown" }
    -- as the pages name them (io_overview's class_names)
    local CLASSES = { veteran = "Veteran", zealot = "Zealot", psyker = "Psyker", ogryn = "Ogryn", adamant = "Arbitrator", broker = "Hive Scum", cryptic = "Skitarius" }
    -- who another player is outside the game, which no other mod is given
    local PRIVATE = { steam_id = true, steam_name = true, account_id = true, account = true, friend_name = true }
    local function scrub(v) if type(v) ~= "table" then return end
        for k, x in pairs(v) do if PRIVATE[k] then v[k] = nil else scrub(x) end end
    end
    local EMPTY = {}
    -- a match also keys some of its tables by account id, and names players by it: each account id it holds, mapped to that
    -- player's character id where the match knows it
    local function accounts(row)
        local map = {}
        local function note(acct, char) if type(acct) == "string" and acct ~= char and map[acct] == nil then map[acct] = char and tostring(char) or false end end
        for id, p in pairs(row.context and row.context.operative_roster or EMPTY) do if type(p) == "table" then note(p.account_id, id) end end
        for _, list in ipairs({ row.all_departures or EMPTY, row.departure_events or EMPTY }) do
            for _, e in ipairs(list) do if type(e) == "table" then note(e.player, e.character_id) end end
        end
        for key, p in pairs(row.operative_clutches or EMPTY) do if type(p) == "table" then note(key, p.character_id) end end
        for key in pairs(row.context and row.context.departure_summary or EMPTY) do note(key, nil) end
        return map
    end
    -- every account id swapped for its character id, as a key or a value, at any depth; one with no character id goes
    local function swap(v, map)
        if type(v) ~= "table" then return end
        local moves
        for k, x in pairs(v) do
            if type(x) == "string" and map[x] ~= nil then v[k] = map[x] or nil else swap(x, map) end
            if type(k) == "string" and map[k] ~= nil then moves = moves or {}; moves[#moves + 1] = k end
        end
        for _, k in ipairs(moves or EMPTY) do local x = v[k]; v[k] = nil; local to = map[k]; if to and v[to] == nil then v[to] = x end end
    end

    local function live_mission()
        if not mod.io_current() then return nil, "stale" end
        -- only the live counting starts a mission, so without it there is none to read
        if not collectors then return nil, "unavailable" end
        if not api.enabled() then return nil, "not recording" end
        local m = api.tracker().mission
        if not m or not m.context then return nil, "no mission" end
        return m
    end

    -- the live squad damage table, read in place and never handed out
    local function live_team(m)
        local team = collectors:live_squad(m)
        if type(team) ~= "table" then return nil, "not yet counted" end
        return team
    end

    -- Accepts a character id string, a player object, a unit, or nil/true for
    -- "me". A number is rejected rather than read as a slot.
    local function id_from_unit(unit)
        local spawn = Managers.state and Managers.state.player_unit_spawn
        local player = spawn and spawn.owner and spawn:owner(unit)
        if not player then
            local players = Managers.player and Managers.player.players and Managers.player:players()
            for _, p in pairs(players or {}) do
                if p.player_unit == unit then player = p; break end
            end
        end
        if not player then return nil end
        local id = type(player.character_id) == "function" and player:character_id()
        return id and tostring(id)
    end

    local function resolve_id(player)
        if player == nil or player == true then return nil end
        if type(player) == "string" then return player end
        if type(player) == "table" then
            if type(player.character_id) == "function" then
                local id = player:character_id()
                if id then return tostring(id) end
            end
            if player.player_unit ~= nil then return id_from_unit(player.player_unit) end
            return nil
        end
        if type(player) == "userdata" then return id_from_unit(player) end
        return nil
    end

    local function in_roster(m, id)
        for rid in pairs(m.context.operative_roster or {}) do
            if tostring(rid) == id then return true end
        end
        return false
    end

    -- the local player, as the scoreboard tells it: marked personal, or the mission's own character
    local function is_me(m, id, p)
        return p.personal == true or id == tostring(m.context.character)
    end

    -- the local player: the roster's own row, else the squad table's
    local function personal_id(m, team)
        for id, p in pairs(m.context.operative_roster or {}) do
            if is_me(m, tostring(id), p) then return tostring(id) end
        end
        for id, p in pairs(team and team.members or {}) do
            if p.personal == true then return tostring(id) end
        end
    end

    local function find_run(run_id)
        for _, r in ipairs(tracker.data.run_history or {}) do
            if tostring(r.id) == tostring(run_id) then return r end
        end
    end

    -- ##### Events
    -- Other mods' handlers, each called in its own pcall with a table of its own, so one that fails or changes what it is
    -- given touches nothing else; a handler that fails is told once.
    local handlers, next_handle, told = {}, 0, {}
    local EVENTS = { mission_start = true, mission_end = true }
    local function fire(event, build)
        local list = {}
        for handle, h in pairs(handlers) do if h.event == event then list[#list + 1] = handle end end
        table.sort(list)
        for _, handle in ipairs(list) do local h = handlers[handle]
            if h then local ok, err = pcall(h.fn, build())
                if not ok and not told[handle] then told[handle] = true
                    -- an error value whose own text raises stays inside here too
                    local said, text = pcall(tostring, err)
                    mod:error("I/O: another mod's %s handler failed: %s", event, said and type(text) == "string" and text or "(an error that could not be shown)")
                end
            end
        end
    end
    -- the trackers that record what is being played, not one a history recount builds
    local function live_tracker(t) return t == tracker or t == solo_tracker or (psykhanium_session ~= nil and t == psykhanium_session) end
    local function about(c) return { name = c.mission_name, display_name = c.mission_display_name, difficulty = c.difficulty, mode = c.mode,
        solo = c.solo == true, training = c.difficulty == "psykhanium" } end
    local begin = Records.begin_mission
    Records.begin_mission = function(self, ...)
        local result = begin(self, ...)
        local m = self.mission
        if result and live_tracker(self) and m and m.context and m.context.difficulty ~= "psykhanium" and next(handlers) then local c = m.context; fire("mission_start", function() return about(c) end) end
        return result
    end
    local finish = Records.finish_mission
    Records.finish_mission = function(self, completed, victory, ...)
        local m = self.mission; local before = self.data.run_sequence or 0
        local result = finish(self, completed, victory, ...)
        if result and m and m.context and m.context.difficulty ~= "psykhanium" and live_tracker(self) and next(handlers) then
            local now = self.data.run_sequence or 0; local saved = now > before
            fire("mission_end", function()
                local info = about(m.context)
                info.victory = victory == true
                info.saved = saved
                info.id = self == tracker and saved and now or nil
                return info
            end)
        end
        return result
    end

    function mod.io_public.on(event, fn)
        if not mod.io_current() then return nil, "stale" end
        if not EVENTS[event] then return nil, "unknown event" end
        if type(fn) ~= "function" then return nil, "not a function" end
        next_handle = next_handle + 1; handlers[next_handle] = { event = event, fn = fn }
        return next_handle
    end
    function mod.io_public.off(handle)
        if not mod.io_current() then return nil, "stale" end
        if handlers[handle] then handlers[handle] = nil; return true end
        return false
    end

    -- ##### Revision
    -- Two numbers that only go up: the first when anything the live calls read has changed since it was last asked, the second
    -- when the finished matches have. Reading them allocates nothing, so a script can ask every frame and rebuild only on a change.
    local live_revision, history_revision, last = 0, 0, {}
    local function weak() return setmetatable({}, { __mode = "k" }) end
    local seen_name, seen_class, seen_personal, seen_present, seen_left = weak(), weak(), weak(), weak(), weak()
    local function differs(slot, value) if last[slot] ~= value then last[slot] = value; return true end return false end
    function mod.io_public.revision()
        if not mod.io_current() then return nil, "stale" end
        local t = api.tracker(); local m = t.mission
        local changed = differs(1, m)
        local dealt, kills, roster, present, left, who, hits = 0, 0, 0, 0, 0, false, 0
        if m and m.context and collectors then
            local team, party = collectors:live_squad(m)
            for _, p in pairs(team and team.members or EMPTY) do for _, groups in pairs(p.groups or EMPTY) do for _, b in pairs(groups) do dealt = dealt + (b.reported or 0) end end
                if p.hits then hits = hits + (p.hits.weakspot or 0) + (p.hits.critical or 0) end end
            for _, p in pairs(party and party.members or EMPTY) do kills = kills + (p.kills and p.kills.total or 0) end
            -- a name or class can arrive after the row does, so each row's are kept to compare against
            for _, p in pairs(m.context.operative_roster or EMPTY) do roster = roster + 1; if p.present then present = present + 1 end; if p.left then left = left + 1 end
                if seen_name[p] ~= p.name or seen_class[p] ~= p.class or seen_personal[p] ~= p.personal or seen_present[p] ~= p.present or seen_left[p] ~= p.left then
                    seen_name[p], seen_class[p], seen_personal[p], seen_present[p], seen_left[p] = p.name, p.class, p.personal, p.present, p.left; who = true end end
        end
        local inc = m and m.incidents; local ti, pi, cur = inc and inc.team, inc and inc.personal, t.current
        if differs(2, dealt) then changed = true end;if differs(3, kills) then changed = true end
        if differs(4, roster) then changed = true end;if differs(5, present) then changed = true end
        if differs(6, m and type(m.kills) == "number" and m.kills or 0) then changed = true end
        if differs(7, ti and ti.downs or 0) then changed = true end;if differs(8, ti and ti.deaths or 0) then changed = true end
        if differs(9, pi and pi.downs or 0) then changed = true end;if differs(10, pi and pi.deaths or 0) then changed = true end
        if differs(11, cur and cur.head_combined or 0) then changed = true end;if differs(12, cur and cur.head_melee or 0) then changed = true end
        if differs(13, cur and cur.head_ranged or 0) then changed = true end;if differs(14, cur and cur.kills or 0) then changed = true end
        if differs(15, cur and cur.dodges or 0) then changed = true end
        if differs(16, left) then changed = true end;if who then changed = true end;if differs(18, hits) then changed = true end
        if changed then live_revision = live_revision + 1 end
        local d = tracker.data
        -- a recount, Rebuild, Import or Restore lands a new data table
        local h1, h2, h3, h4, h5 = differs(30, #(d.run_history or EMPTY)), differs(31, d.run_sequence or 0), differs(32, d.history_policy_revision or 0), differs(33, mod.io_times_revision or 0), differs(34, d)
        -- the history's times are worked out on the Boss timing setting, so changing it is a new history to a reader
        local h6, h7 = differs(35, mod.io_history_touched or 0), differs(36, mod.io_display_options and mod.io_display_options().boss_map_timing == true)
        if h1 or h2 or h3 or h4 or h5 or h6 or h7 then history_revision = history_revision + 1 end
        return live_revision, history_revision
    end

    -- the display names the pages use, for scripts that show them
    function mod.io_public.names()
        if not mod.io_current() then return nil, "stale" end
        local out = { armour = {}, category = {}, class = {} }
        for k, v in pairs(ARMOURS) do out.armour[k] = v end
        for k, v in pairs(CATEGORIES) do out.category[k] = v end
        for k, v in pairs(CLASSES) do out.class[k] = v end
        return out
    end

    -- Active mission context, or a table saying no mission is under way, written into out with every field set or cleared.
    local function fill_mission(out)
        local m = api.tracker().mission
        if not m or not m.context then
            out.active, out.in_hub = false, api.in_hub() == true
            out.training, out.solo, out.name, out.display_name, out.difficulty, out.mode, out.patch, out.full, out.tracked_seconds = nil, nil, nil, nil, nil, nil, nil, nil, nil
            return out
        end
        local c = m.context
        out.active, out.in_hub = true, false
        out.training, out.solo = mod.io_is_training(), mod.io_is_solo() == true
        out.name, out.display_name = c.mission_name, c.mission_display_name
        out.difficulty, out.mode, out.patch = c.difficulty, c.mode, c.patch
        out.full = m.full ~= false
        out.tracked_seconds = collectors and collectors:tracked_seconds() or nil
        return out
    end
    function mod.io_public.mission()
        if not mod.io_current() then return nil, "stale" end
        return fill_mission({})
    end

    -- One operative's damage this mission. player: character id, player object
    -- or unit; nil/true means the local player.
    -- opts: { overkill = true } reads reported instead of useful;
    -- { category = "melee" }; { armour = "armored" }.
    function mod.io_public.player_damage(player, opts)
        if type(opts) ~= "table" then opts = nil end
        local m, why = live_mission()
        if not m then return nil, why end
        local category = opts and opts.category or "total"
        local armour = opts and opts.armour
        if not CATEGORIES[category] then return nil, "unknown category" end
        if armour ~= nil and not ARMOURS[armour] then return nil, "unknown armour" end
        -- boss damage is kept as one figure, not split by armour
        if armour ~= nil and category == "boss" then return nil, "unsupported" end
        local team
        team, why = live_team(m)
        if not team then return nil, why end
        local id = resolve_id(player)
        if not id and (player == nil or player == true) then id = personal_id(m, team) end
        if not id or id == "unknown_operative" or not (in_roster(m, id) or team.members and team.members[id]) then
            return { reported = 0, useful = 0, overkill = 0, unknown = 0, share = 0, found = false }
        end
        local field = opts and opts.overkill and "reported" or "useful"
        local mine = TeamDamage.summary(team, id, category, armour)
        local all = TeamDamage.summary(team, nil, category, armour)
        local value = mine[field] or 0
        return {
            reported = mine.reported or 0, useful = mine.useful or 0,
            overkill = mine.overkill or 0, unknown = mine.unknown or 0,
            share = (all[field] or 0) > 0 and value / all[field] or 0,
            found = true,
        }
    end

    -- Character id of the local player, as this mod understands it, so a
    -- consumer can check its own "who is me" mapping instead of assuming slot 1.
    function mod.io_public.whoami()
        local m, why = live_mission()
        if not m then return nil, why end
        local id = personal_id(m, (live_team(m)))
        if id then return id end
        return nil, "local player not in the squad yet"
    end

    -- Who is in this mission, identity fields stripped.
    -- The local player's runs in progress, as the Streaks page counts them.
    function mod.io_public.streaks()
        local m, why = live_mission()
        if not m then return nil, why end
        local t = api.tracker(); local cur = t.current or EMPTY; local c = m.context
        -- read in place: the tracker's own lookup would make the entry it looks for
        local s = t.data.class_mode_streaks; s = s and s[c.patch]; s = s and s[c.mode]; s = s and s[c.class]
        return {
            headshots = cur.head_combined or 0, melee_headshots = cur.head_melee or 0, ranged_headshots = cur.head_ranged or 0,
            kills = cur.kills or 0, dodges = cur.dodges or 0,
            kills_without_a_down = s and s.current and s.current.kill_run or 0,
        }
    end

    function mod.io_public.roster()
        local m, why = live_mission()
        if not m then return nil, why end
        local out = {}
        for id, p in pairs(m.context.operative_roster or {}) do
            out[tostring(id)] = {
                name = p.name, class = p.class,
                personal = is_me(m, tostring(id), p),
                present = p.present == true, left = p.left == true,
            }
        end
        return out
    end

    -- Every operative in the mission as a render-ready row, plus kills.
    function mod.io_public.squad(opts)
        if type(opts) ~= "table" then opts = nil end
        local m, why = live_mission()
        if not m then return nil, why end
        local team, party = collectors:live_squad(m)
        if type(team) ~= "table" then return nil, "not yet counted" end
        local field = opts and opts.overkill and "reported" or "useful"
        local total = TeamDamage.summary(team, nil, "total")[field] or 0
        local own = m.kill_categories or {}
        local counts = Records.incident_counts(m)
        local c = m.context
        local roster = c.operative_roster or {}
        -- before the roster's first sample the local player is a row on their own, as on the scoreboard
        if not next(roster) and c.character then roster = { [tostring(c.character)] = { name = c.character_name, class = c.class, personal = true } } end
        local rows = {}
        for id, p in pairs(roster) do
            id = tostring(id)
            local bucket = TeamDamage.summary(team, id, "total")
            local member = party and party.members and party.members[id] or {}
            local kills = member.kills or {}
            local hits = team.members and team.members[id] and team.members[id].hits
            local row = {
                id = id, name = p.name, class = p.class,
                personal = is_me(m, id, p), left = p.left == true,
                damage = {
                    reported = bucket.reported or 0, useful = bucket.useful or 0,
                    overkill = bucket.overkill or 0, unknown = bucket.unknown or 0,
                    share = total > 0 and (bucket[field] or 0) / total or 0,
                    boss = TeamDamage.summary(team, id, "boss")[field] or 0,
                },
                kills = {
                    total = kills.total or 0, boss = kills.boss or 0,
                    elite = kills.elite or 0, special = kills.special or 0,
                    lesser = (kills.horde_melee or 0) + (kills.horde_ranged or 0),
                    melee = (kills.trash_fixed_melee or 0) + (kills.elite_melee or 0),
                    ranged = (kills.trash_fixed_ranged or 0) + (kills.elite_ranged or 0),
                },
                hits = { weakspot = hits and hits.weakspot or 0, critical = hits and hits.critical or 0 },
            }
            -- the local player's kills are This Mission's own count, as the scoreboard shows them
            if row.personal then
                local k = row.kills
                if type(m.kills) == "number" then k.total = m.kills end
                k.boss, k.elite, k.special = own.boss or k.boss, own.elite or k.elite, own.special or k.special
                if own.horde_melee or own.horde_ranged then k.lesser = (own.horde_melee or 0) + (own.horde_ranged or 0) end
            end
            local inc = row.personal and counts.personal or counts.members and counts.members[id] and counts.members[id].counts or {}
            row.downs, row.deaths = inc.downs or 0, inc.deaths or 0
            rows[#rows + 1] = row
        end
        table.sort(rows, function(a, b)
            if a.personal ~= b.personal then return a.personal end
            if a.damage[field] ~= b.damage[field] then return a.damage[field] > b.damage[field] end
            return a.id < b.id
        end)
        return rows
    end

    -- a match's damage figures; a squad table with no row of yours means you dealt none, which is 0, not unknown
    local function damage_of(r)
        local own_useful, team_useful = Records.run_useful(r)
        local own, _, reported = Records.run_damage_info(r)
        local own_reported = reported ~= nil and own or nil
        if team_useful ~= nil then own_useful, own_reported = own_useful or 0, own_reported or 0 end
        return own_useful, team_useful, own_reported
    end

    -- a match's time as the pages give it: the server's ahead of the clock, and a clock win timed on the basis Settings has now
    local Times
    local function seconds_of(r)
        Times = Times or mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_times")
        local t = Times.completion(r)
        -- an imported match's estimate is never given here, whatever Imported Matches Count For Records says
        if t and t.source == Times.ESTIMATE then return nil end
        if r.victory and t and t.source == "mission_clock" then
            local marks, boss = r.completion_markers or {}, mod.io_display_options().boss_map_timing
            local chosen = boss and Times.boss_death(r) or marks.victory_request or marks.victory_transition or marks.win_condition ~= marks.boss_death and marks.win_condition
            return chosen and Times.marker(r, chosen) or nil
        end
        return t and t.seconds or nil
    end

    -- a finished match as a list shows it, from what the match keeps in memory, so a list of every match reads nothing from disk
    local function slim(r)
        local c, k = r.context or {}, r.kill_categories or {}
        local own_useful, team_useful, own_reported = damage_of(r)
        return {
            id = r.id, victory = r.victory, full = r.full ~= false, run_kind = r.run_kind, started_at = r.started_at,
            seconds = seconds_of(r), imported = type(r.imported) == "table",
            mission = c.mission_name, display_name = c.mission_display_name, difficulty = c.difficulty, mode = c.mode, patch = c.patch,
            class = c.class, character = c.character ~= nil and tostring(c.character) or nil, character_name = c.character_name,
            kills = { total = type(r.kills) == "number" and r.kills or 0, elite = k.elite or 0, special = k.special or 0, boss = k.boss or 0 },
            damage = { own_useful = own_useful, team_useful = team_useful, own_reported = own_reported },
        }
    end

    -- Finished missions, newest first, a page at a time: opts.from counts from the newest (1 is the newest), opts.count how many;
    -- with neither, every one. Each match is a small copy of its own; history_match gives one in full.
    function mod.io_public.history(opts)
        if not mod.io_current() then return nil, "stale" end
        if type(opts) ~= "table" then opts = nil end
        local from = math.max(1, math.floor(tonumber(opts and opts.from) or 1))
        local count = opts and opts.count ~= nil and math.max(0, math.floor(tonumber(opts.count) or 0)) or math.huge
        local runs = tracker.data.run_history or {}
        local out = { total = 0, excluded = 0, matches = {} }
        for i = #runs, 1, -1 do local r = runs[i]
            if FrontendContract.accepted(r) then out.total = out.total + 1
                if out.total >= from and #out.matches < count then out.matches[#out.matches + 1] = slim(r) end
            else out.excluded = out.excluded + 1 end
        end
        return out
    end

    -- One finished mission in full, as the frontend contract shapes it; reads that match's file alone.
    function mod.io_public.history_match(run_id)
        if not mod.io_current() then return nil, "stale" end
        local run = find_run(run_id)
        if not run then return nil, "no such match" end
        if not FrontendContract.accepted(run) then return nil, "excluded" end
        local ok, built = pcall(FrontendContract.build, { run })
        if not ok or not built.matches[1] then return nil, "unreadable match" end
        local row = built.matches[1]
        local map = accounts(row); scrub(row); swap(row, map)
        return row
    end

    -- One finished mission's damage figures, by id, with the acceptance test history() uses.
    function mod.io_public.run_damage(run_id)
        if not mod.io_current() then return nil, "stale" end
        local run = find_run(run_id)
        if not run then return nil, "no such match" end
        local own_useful, team_useful, own_reported = damage_of(run)
        local countable = FrontendContract.accepted(run)
        return {
            own_useful = own_useful, team_useful = team_useful, own_reported = own_reported,
            run_kind = run.run_kind,
            excluded = not countable or nil,
            countable = countable,
        }
    end

    -- ##### Readers
    -- One mod's own way in: the same calls, each handing back the table it built last time until revision() moves, so a script can
    -- ask every frame and make no garbage. Each reader keeps its own tables, so what one mod does to them reaches no other mod.
    local ME, NOBODY, NONE, REV, ORDER = {}, {}, {}, {}, {}
    -- a key a table can be filed under: not nil, and not NaN, which is not even equal to itself
    local function fileable(k) return k ~= nil and k == k end
    function mod.io_public.reader()
        if not mod.io_current() then return nil, "stale" end
        local P = mod.io_public
        local R, live, past, at_mission, ms, names = {}, {}, {}, nil, nil, nil
        -- store[a][b], each made once and kept, so a change of revision makes no new tables
        local function shelf(store, a, b)
            local s = store[a]; if not s then s = {}; store[a] = s end
            if b == nil then return s end
            local t = s[b]; if not t then t = {}; s[b] = t end
            return t
        end
        -- the table answer kept under key while rev is the revision it was built at; a nil and its reason are never kept, and a
        -- shelf with a cap keeps that many answers, the oldest going first
        local function asked(s, key)
            local order = s[ORDER]; if not order then order = {}; s[ORDER] = order end
            for i = #order, 1, -1 do if order[i] == key then table.remove(order, i); break end end
            order[#order + 1] = key
            return order
        end
        local function keep(s, key, rev, cap, fn, a, b)
            local revs = s[REV]; if not revs then revs = {}; s[REV] = revs end
            if revs[key] == rev then local v = s[key]; if v ~= nil then if cap then asked(s, key) end; return v end end
            local r, why = fn(a, b)
            if type(r) ~= "table" then return r, why end
            if cap then local order = asked(s, key); if #order > cap then local old = table.remove(order, 1); s[old], revs[old] = nil, nil end end
            s[key], revs[key] = r, rev
            return r, why
        end
        -- the live revision while the live calls can answer, else nil, and the plain call gives its own reason; a new mission lets
        -- go of the players who are not in it
        local function live_rev()
            local m = live_mission(); if not m then return nil end
            if m ~= at_mission then at_mission = m
                local roster, kept = m.context.operative_roster or EMPTY, live.player_damage
                for id in pairs(kept or EMPTY) do if id ~= ME and id ~= NOBODY and roster[id] == nil then kept[id] = nil end end
            end
            return (P.revision())
        end
        local function past_rev() local l, h = P.revision(); if l == nil then return nil end; return h end
        function R.revision() return P.revision() end
        function R.whoami() return P.whoami() end
        function R.names()
            if not mod.io_current() then return nil, "stale" end
            names = names or P.names(); return names
        end
        -- the same table every time, brought up to date as it is asked for, since its tracked_seconds counts up between revisions
        function R.mission()
            if not mod.io_current() then return nil, "stale" end
            ms = ms or {}; return fill_mission(ms)
        end
        function R.squad(opts)
            local rev = live_rev(); if not rev then return P.squad(opts) end
            return keep(shelf(live, "squad"), type(opts) == "table" and opts.overkill and "reported" or "useful", rev, nil, P.squad, opts)
        end
        function R.roster() local rev = live_rev(); if not rev then return P.roster() end;return keep(shelf(live, "roster"), 1, rev, nil, P.roster) end
        function R.streaks() local rev = live_rev(); if not rev then return P.streaks() end;return keep(shelf(live, "streaks"), 1, rev, nil, P.streaks) end
        function R.player_damage(player, opts)
            local rev = live_rev(); if not rev then return P.player_damage(player, opts) end
            local o = type(opts) == "table" and opts or nil
            local id = resolve_id(player) or (player == nil or player == true) and ME or NOBODY
            -- read as the plain call reads them: a false armour is an armour of its own, which it refuses
            local cat, arm = o and o.category or "total", o and o.armour
            if arm == nil then arm = NONE end
            if not (fileable(cat) and fileable(arm)) then return P.player_damage(player, opts) end
            return keep(shelf(shelf(live, "player_damage", id), cat, arm), o and o.overkill and "reported" or "useful", rev, nil, P.player_damage, player, opts)
        end
        function R.history(opts)
            local rev = past_rev(); if not rev then return P.history(opts) end
            local o = type(opts) == "table" and opts or nil
            local from = math.max(1, math.floor(tonumber(o and o.from) or 1))
            local count = o and o.count ~= nil and math.max(0, math.floor(tonumber(o.count) or 0)) or -1
            if not (fileable(from) and fileable(count)) then return P.history(opts) end
            return keep(shelf(past, "history"), from .. ":" .. count, rev, 16, P.history, opts)
        end
        -- full matches are large, so a reader keeps its last few
        function R.history_match(run_id) local rev = past_rev(); if not rev then return P.history_match(run_id) end;return keep(shelf(past, "history_match"), tostring(run_id), rev, 8, P.history_match, run_id) end
        function R.run_damage(run_id) local rev = past_rev(); if not rev then return P.run_damage(run_id) end;return keep(shelf(past, "run_damage"), tostring(run_id), rev, 64, P.run_damage, run_id) end
        return R
    end
end
part("Scoreboard",function()mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/scoreboard_hud")(mod,collectors,api)end)
part("Mission timer",function()mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_timer_hud")(mod,collectors,mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_times"))end)
part("Social fetches",function()mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/social_fetches")(mod)end)
-- The screens I/O adds to, each left out if it fails to load; Scoreboard and Tracker are scoreboard_hud's, so their entries only name them.
mod.io_screens={scoreboard={id="scoreboard",name="Scoreboard",place="Mission",icon="scoreboard",rows={
 {key="hide_game_scoreboard",label="Remove Game's Scoreboard",help="Remove the game's own end of mission scoreboard and prompt.",kind="toggle",default=true}}},tracker={id="tracker",name="Tracker",place="Mission",icon="speed",rows={}}}
do
 local function screen(id,path)local ok,m=pcall(function()return mod:io_dofile(path)(mod,api,collectors)end);if ok and m then mod.io_screens[id]=m else mod:error("I/O %s: %s",id,tostring(m))end end
 screen("charselect","InformationOverload/scripts/mods/InformationOverload/screen_charselect")
 screen("social","InformationOverload/scripts/mods/InformationOverload/screen_social")
 screen("board","InformationOverload/scripts/mods/InformationOverload/screen_board")
 screen("havoc","InformationOverload/scripts/mods/InformationOverload/screen_havoc")
 screen("endscreen","InformationOverload/scripts/mods/InformationOverload/screen_endscreen")
end
mod.io_api = api
save(true) -- Repair confirmed saved segment pairs before the first dashboard view.
-- after a mods reload a popup still up belongs to the old load, so its answers do nothing
function mod.io_current()return get_mod("information_overload")==mod end
local HistoryDeletion=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/history_deletion")
-- deleting matches, Reset, Restore and Delete Backups wait while a Power DI import runs, as each would change the history or the backups its batches add to
local POWERDI_RUNNING="A Power DI import is running. Wait for it to finish or Abort it first."
mod.io_delete_match=function(id,source)
 if not mod.io_current()then return false end
 if mod.io_powerdi_busy and mod.io_powerdi_busy()then return false,POWERDI_RUNNING end
 if tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending()then
  return false,"Finish the current mission and resolve any pending result before deleting a match."
 end
 local target=source=="solo"and solo_tracker or source=="logs"and psykhanium_logs or tracker
 local key=source=="solo"and "solo_records_v1"or source=="logs"and "psykhanium_logs_v1"or "lifetime_records_v1"
 tracker:finish_blo_trial()
 local updated,baseline=HistoryDeletion.prepare(Records,HistoryRecalculation,target.data,id,history_policy,source=="logs",target==tracker and history_baseline or nil)
 if not updated then return false,baseline end
 local prior=target.data;local old_baseline=history_baseline;local old_friends=friend_summaries
 storage:set(key,updated)
 local psyk_done=target==tracker and psyk.stage(PsykSummary.counted(prior),PsykSummary.counted(updated))
 local forget;if target==tracker then storage:set("history_baseline_v1",baseline);storage:set("friend_summaries_v1",{});forget=HistoryDeletion.remember(storage,prior,updated)end
 local unforget=HistoryDeletion.forget(storage,source=="solo"and "solo"or source=="logs"and "logs"or "lifetime",prior,updated)
 local ok,err=storage:flush()
 if psyk_done then psyk_done(ok)end
 if not ok then
  storage:set(key,prior);unforget()
  if target==tracker then storage:set("history_baseline_v1",old_baseline);storage:set("friend_summaries_v1",old_friends);forget()end
  return false,"The match could not be deleted because saving failed."
 end
 target.data=updated;target.blo_weapon_trackers={};target.dirty=false
 if target==tracker then
  history_baseline=baseline;history_rebuilt_sequence=updated.run_sequence or 0;history_policy_dirty=false;segment_checked_sequence=updated.run_sequence or 0
  friend_summaries={};friend_signature=nil;friend_people=nil;mod.io_friend_stats();storage:flush()
 end
 storage:release_details();return true
end
local HistoryImport=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/history_import")
local Backup=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/statistics_backup")
do
local job
local function busy()
 return tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending()
end
-- Match History's Delete: the matches go in one rebuild, and the history they were in is kept as a backup in the same commit
mod.io_delete_matches=function(ids)
 if not mod.io_current()then return false end
 if mod.io_powerdi_busy and mod.io_powerdi_busy()then return false,POWERDI_RUNNING end
 if busy()then return false,"Finish the current mission and resolve any pending result before deleting matches."end
 tracker:finish_blo_trial()
 local updated,baseline=HistoryDeletion.prepare(Records,HistoryRecalculation,tracker.data,ids,history_policy,false,history_baseline)
 if not updated then return false,baseline end
 local prior,old_baseline,old_friends=tracker.data,history_baseline,friend_summaries
 local backup,seq=Backup.deleted(storage,{lifetime=prior},os and os.date and os.date("%Y-%m-%d %H:%M:%S"),ids)
 if backup==nil then return false,seq end
 -- a delete never lowers the counter: the backup holds every number it took, siblings and missing files included
 local hi=0;for _,id in ipairs(ids)do hi=math.max(hi,tonumber(id)or 0)end
 updated.run_sequence=math.max(prior.run_sequence or 0,updated.run_sequence or 0,hi)
 storage:set("lifetime_records_v1",updated)
 local psyk_done=psyk.stage(PsykSummary.counted(prior),PsykSummary.counted(updated))
 storage:set("history_baseline_v1",baseline);storage:set("friend_summaries_v1",{});local forget=HistoryDeletion.remember(storage,prior,updated)
 local ok=storage:flush()
 if psyk_done then psyk_done(ok)end
 if not ok then
  storage:unstage();storage:set("lifetime_records_v1",prior);storage:set("history_baseline_v1",old_baseline);storage:set("friend_summaries_v1",old_friends);forget()
  return false,"The matches could not be deleted because saving failed."
 end
 tracker.data=updated;tracker.blo_weapon_trackers={};tracker.dirty=false
 history_baseline=baseline;history_rebuilt_sequence=updated.run_sequence or 0;history_policy_dirty=false;segment_checked_sequence=updated.run_sequence or 0
 friend_summaries={};friend_signature=nil;friend_people=nil;mod.io_friend_stats();storage:flush()
 storage:release_details();return true
end
-- One frame: an import's backup of the history it adds to lands in the same commit as the history with them.
-- Import Match History passes {merged,n}: its backup names the matches it adds by number.
-- A Power DI import passes {sessions,known}: its backup names the sessions it adds, and the list of imported sessions lands in the same commit.
local function commit(updated,baseline,import)
 local old,old_baseline,old_friends=tracker.data,history_baseline,friend_summaries
 local backup
 local pdi=import and import.sessions and import or nil;local old_known
 if pdi then
  local seq
  -- a later batch of the same import adds to the backup its first batch made
  if pdi.extend then backup=Backup.powerdi_more(storage,pdi.extend,pdi.sessions)end
  -- a new backup names this batch's first mission, so a mark to pick up names it too
  if backup==nil and pdi.known and pdi.known.resume then pdi.known.resume={first=pdi.sessions[1]}end
  if backup==nil then backup,seq=Backup.powerdi(storage,{lifetime=old},os and os.date and os.date("%Y-%m-%d %H:%M:%S"),pdi.sessions)end
  if backup==nil then return false,seq end
  old_known=storage:get(Backup.POWERDI);storage:set(Backup.POWERDI,pdi.known)
 elseif import then
  local seq;backup,seq=Backup.import(storage,{lifetime=old},os and os.date and os.date("%Y-%m-%d %H:%M:%S"),import.merged,import.n)
  if backup==nil then return false,seq end
 end
 -- an import carries the counter on from the highest number anything still holds, so numbers a restore took back out are given again;
 -- any other commit keeps every number it has used
 if import then updated.run_sequence=math.max(updated.run_sequence or 0,Backup.top(storage,updated,baseline))
 else updated.run_sequence=math.max(updated.run_sequence or 0,Backup.floor(storage,"lifetime"))end
 local cleared={}
 storage:set("lifetime_records_v1",updated);storage:set("history_baseline_v1",baseline);storage:set("friend_summaries_v1",cleared)
 -- memory follows the catalog the moment it commits; a held commit does it from inside the save, before the save's next pause
 local followed=false
 local function follow()followed=true
  -- a player tracked or untracked while a held commit ran over frames stays as the player left them, and saves next
  local live=tracker.data;local kept=live~=updated and live.friend_tracking_revision~=updated.friend_tracking_revision
  if kept then updated.friend_tracking=live.friend_tracking;updated.friend_tracking_revision=live.friend_tracking_revision end
  tracker.data=updated;tracker.blo_weapon_trackers={};tracker.dirty=kept;history_baseline=baseline;history_rebuilt_sequence=updated.run_sequence or 0;history_policy_dirty=false;segment_checked_sequence=updated.run_sequence or 0
  friend_summaries={};friend_signature=nil;friend_people=nil;follow_policy(updated,function()storage:pause(true)end)
 end
 if storage.job and storage.job.hold then storage.job.on_commit=follow end
 local committed=storage:flush()
 if storage.job and storage.job.hold then storage.job.on_commit=nil end
 -- once memory followed, the catalog took it, whatever the save's tidying after said
 committed=committed or followed
 -- what it set goes back, but not what something else set while a held commit ran over frames
 if not committed then if import then storage:unstage()end;local function back(key,mine,was)if storage:get(key)==mine then storage:set(key,was)end end
  if pdi then back(Backup.POWERDI,pdi.known,old_known)end;back("lifetime_records_v1",updated,old);back("history_baseline_v1",baseline,old_baseline);back("friend_summaries_v1",cleared,old_friends);return false,"Reconstruction could not be saved."end
 if not followed then follow()end
 -- past its catalog commit a held commit stands, so a fault in the tidying after is logged rather than reported as a failure
 local function tidy_up()storage:pause();mod.io_friend_stats();psyk.drop();storage:flush()end
 if storage.job and storage.job.hold then local done,err=storage:try(tidy_up);if not done and mod.info then mod:info("I/O commit: after its catalog committed: %s",tostring(err))end else tidy_up()end
 storage:release_details()
 if pdi or not import then return true end
 return true,Backup.matches(import.n).." added from the Import folder."
end
local NOTHING_NEW="No new matches were found in the Import folder."
-- the folder's matches this PC holds in no history or backup, added to a copy of its history; nil when none are new
local function merge_folder(data,pause)
 local merged,ids,n=HistoryImport.merge(storage,HistoryImport.read(storage,pause),data.run_history,Backup.top(storage,data,history_baseline),pause)
 if not merged then return nil end
 local copy={};for k,v in pairs(data)do copy[k]=v end;copy.run_history=merged
 return copy,{merged=ids,n=n}
end
local PowerDI
mod.io_reconstruct_history=function(import_folder)
 if job then return false,"A match history import is already running."end
 if PowerDI and PowerDI.busy()then return false,"A Power DI import is already running."end
 if busy()then return false,"Finish the current mission and resolve any pending result first."end
 tracker:finish_blo_trial()
 local added
 local ok,updated,baseline=pcall(function()
  local data=tracker.data
  if import_folder then data,added=merge_folder(data);if not data then return nil end end
  return HistoryImport.rebuild(Records,HistoryRecalculation,data,history_policy,nil,MissionSegments,history_baseline)
 end)
 if not ok then return false,(tostring(updated):gsub("^.-:%d+: ",""))end
 if not updated then return true,NOTHING_NEW end
 return commit(updated,baseline,added)
end
local function now()return slow_trace.start()or 0 end
local function begin(started)
 local data=tracker.data
 local active={data=data,sequence=data.run_sequence,revision=data.history_policy_revision,policy=history_policy,
  started=started,stage="read",slices=0,read=0,rebuild=0,peak=0,over=0}
 active.thread=coroutine.create(function()
  local function pause()if now()-active.slice_start>=3 then coroutine.yield()end end
  local copy,added=merge_folder(data,pause)
  if not copy then return nil end
  active.added,active.matches=added,added.n
  active.stage="rebuild"
  coroutine.yield()
  return HistoryImport.rebuild(Records,HistoryRecalculation,copy,active.policy,nil,MissionSegments,history_baseline,pause)
 end)
 return active
end
mod.io_start_history_import=function()
 if job then return false,"A match history import is already running."end
 if PowerDI and PowerDI.busy()then return false,"A Power DI import is already running."end
 if busy()then return false,"Finish the current mission and resolve any pending result first."end
 tracker:finish_blo_trial()
 job=begin(now())
 return true
end
mod.io_step_history_import=function()
 local active=job
 if not active then return end
 -- the hub replay rebuilds the same matches, so an import waits for it and starts again on what it gives
 if mod:is_enabled()and not busy()then
  if rebuild_job then return end
  local d=active.data;while replayed[d]and d~=tracker.data do d=replayed[d]end
  -- and a rejoin merged or a Counting change edits the matches in place, so it starts again on those too
  if d==tracker.data and history_policy==active.policy and (d~=active.data or d.run_sequence==active.sequence and d.history_policy_revision~=active.revision)then active=begin(active.started);job=active end
 end
 if not mod:is_enabled()or busy()or tracker.data~=active.data or tracker.data.run_sequence~=active.sequence
  or tracker.data.history_policy_revision~=active.revision or history_policy~=active.policy then
  job=nil;mod:echo("Match history import cancelled because the active game or history changed.");return
 end
 active.slice_start=now()
 local stage=active.stage
 local ok,updated,baseline=coroutine.resume(active.thread)
 local spent=now()-active.slice_start
 active[stage]=active[stage]+spent;active.slices=active.slices+1;active.peak=math.max(active.peak,spent);if spent>3 then active.over=active.over+1 end
 if ok and coroutine.status(active.thread)~="dead"then return end
 job=nil
 local save_ms=0
 if ok and not updated then
  mod:info("Match History Import: complete, nothing new, %d slices, read %.1f ms, elapsed %.1f ms",active.slices,active.read,now()-active.started)
  mod:echo("%s",NOTHING_NEW);return
 end
 if ok then
  -- a player tracked or untracked while it ran stays as the player left them
  updated.friend_tracking=HistoryRecalculation.clone(tracker.data.friend_tracking);updated.friend_tracking_revision=tracker.data.friend_tracking_revision
  local began=now()
  ok,updated=commit(updated,baseline,active.added)
  save_ms=now()-began
 end
 mod:info("Match History Import: %s, %d matches, %d slices, %d of them over 3 ms, read %.1f ms, rebuild %.1f ms, longest slice %.1f ms, save/finalize %.1f ms in one frame, elapsed %.1f ms",
  ok and "complete"or "failed",active.matches or 0,active.slices,active.over,active.read,active.rebuild,active.peak,save_ms,now()-active.started)
 if ok then mod:echo("%s",updated or "Statistics rebuilt.")else mod:echo("%s",(tostring(updated):gsub("^.-:%d+: ","")))end
end
-- the bytes a commit wrote for the imported matches: their own files, and each patch's lines file shared out by its matches; nil when one was not written
local function written_for(sizes,sessions)
 local want,mine={}, {};for _,s in ipairs(sessions or {})do want[s]=true end
 for _,run in ipairs(tracker.data.run_history or {})do local s=type(run.imported)=="table"and run.imported.session;if s~=nil and want[s]then mine[tostring(run.id)]=true end end
 local entry=storage.manifest and storage.manifest.entries and storage.manifest.entries.lifetime_records_v1;if not entry then return nil end
 local total,count,ours=0,{},{}
 for _,d in ipairs(entry.history or {})do local p=tostring(d.patch);count[p]=(count[p]or 0)+1
  if mine[tostring(d.id)]then local n=sizes[d.file];if not n then return nil end;total=total+n;ours[p]=(ours[p]or 0)+1 end
 end
 for p,k in pairs(ours)do local l=entry.history_lines and entry.history_lines[p];local n=l and sizes[l.file];if n then total=total+n*k/count[p]end end
 return math.floor(total+.5)
end
-- Import From Power DI adds to the history rather than replacing it, rebuilt as Rebuild Statistics does and saved in one commit with its backup
PowerDI=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/power_di_import")({storage=storage,Backup=Backup,
 data=function()return tracker.data end,baseline=function()return history_baseline end,
 current=function(d)while replayed[d]and d~=tracker.data do d=replayed[d]end;return d end,
 busy=busy,other=function()return job~=nil end,idle=function()return rebuild_job==nil end,
 enabled=function()return mod:is_enabled()end,policy=function()return history_policy end,
 patch=function()return game_patch()end,trim=function(run)Records.trim_saved(run)end,
 -- the game's save folder, where Power DI's files sit, opened read-only to see which are still there; nil where it cannot be reached
 save_folder=function()local lua=Mods and Mods.lua;local io,os=lua and lua.io,lua and lua.os;local app=os and os.getenv and os.getenv("APPDATA")
  if not io or not io.open or type(app)~="string"or app==""then return nil end;local dir=app:gsub("\\","/").."/Fatshark/Darktide/"
  return function(name)return io.open(dir..name,"rb")end end,
 rebuild=function(d,pause)
  local updated,baseline=HistoryImport.rebuild(Records,HistoryRecalculation,d,history_policy,nil,MissionSegments,history_baseline,pause)
  -- a player tracked or untracked while it ran stays as the player left them
  updated.friend_tracking=HistoryRecalculation.clone(tracker.data.friend_tracking);updated.friend_tracking_revision=tracker.data.friend_tracking_revision
  return updated,baseline
 end,
 commit=commit,notify=function(text)mod.io_notify(text)end,now=now,
 -- the same commit as a held storage job, stepped a few milliseconds a frame by the import, which is told what it wrote for the imported matches
 commit_begin=function(updated,baseline,import)local h={data=updated}
  h.job=storage:hold(function()h.ok,h.err=commit(updated,baseline,import);if h.ok then h.wrote=written_for(h.job.sizes or {},import.sessions)end;h.done=true end)
  return h end,
 info=function(...)if mod.info then mod:info(...)end end})
mod.io_powerdi_request=PowerDI.request
mod.io_powerdi_confirm=PowerDI.confirm
mod.io_powerdi_cancel=PowerDI.cancel
mod.io_powerdi_abort=PowerDI.abort
mod.io_powerdi_fault=PowerDI.fault
mod.io_powerdi_status=PowerDI.status
mod.io_powerdi_busy=PowerDI.busy
mod.io_powerdi_resumable=PowerDI.resumable
mod.io_powerdi_said=PowerDI.SAID
mod.io_powerdi_dismiss=PowerDI.dismiss
mod.io_powerdi_leave=PowerDI.leave
mod.io_step_powerdi=PowerDI.step
mod.io_powerdi_release=PowerDI.release
end
mod.dashboard_model=part("Dashboard",function()return mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/dashboard_model")end)
part("Views",function()mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_register")(mod)end)

local reset_popup_token
local function reset_allowed(doing)
    local manager=Managers.state and Managers.state.mission
    local name=manager and manager:mission_name()
    local mission=name and Missions[name]
    if name and not (mission and mission.is_hub) and not name:find("training") and not name:find("shooting_range") then
        mod:echo("Return to the hub or Psykhanium before %s.",doing);return false
    end
    return true
end
local function confirm(doing,title,body,label,fn)
    if not reset_allowed(doing) then return end
    local event=Managers.event
    if not event then mod:echo("The confirmation could not be shown, so nothing changed.");return end
    local token={};reset_popup_token=token
    event:trigger("event_show_ui_popup",{title_text_unlocalized="Information Overload: "..title,description_text_unlocalized=body,options={
        {text=label,no_localization=true,close_on_pressed=true,callback=function()if not mod.io_current()or reset_popup_token~=token or not reset_allowed(doing) then return end;reset_popup_token=nil;fn()end},
        {text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back",callback=function() if reset_popup_token==token then reset_popup_token=nil end end},
    }})
end
local function statistics()return {lifetime=tracker.data,solo=solo_tracker.data,logs=psykhanium_logs.data,baseline=history_baseline,friends=friend_summaries}end
mod.io_backups=function()return storage.backups and storage:backups()or {}end
mod.io_request_reset=function()
    if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
    confirm("resetting records","Reset Statistics","Move all saved Information Overload statistics across every patch, character and weapon into a backup? Settings are kept.\n\nRestore Latest Backup in Settings › Data brings them back.","Yes, reset",function()
        if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
        boundary();if collectors then collectors:forget_partial()end
        local fresh,err=Backup.reset(storage,Records,HistoryRecalculation,statistics(),os and os.date and os.date("%Y-%m-%d %H:%M:%S"))
        if not fresh then mod:echo("%s",err);return end
        tracker=fresh.lifetime;history_baseline=fresh.baseline;history_rebuilt_sequence=tracker.data.run_sequence or 0;history_policy_dirty=false;friend_summaries={};friend_signature=nil;lifetime_tracker=tracker;mod.records=tracker
        solo_tracker=fresh.solo;psykhanium_logs=fresh.logs
        psykhanium_session,psykhanium_manager=nil,nil
        psyk.drop();save(true)
        mod:echo(fresh.kept and "All statistics moved into a backup." or "There were no statistics to move, so no backup was made.")
    end)
end
-- matches played on this PC since a backup was made, which restoring it keeps
mod.io_played_since=function(b)
    if type(b)~="table"then return 0 end
    -- by the missions the backup's history held where it lists them, else by number; imports and hidden data are no matches played
    local held;if type(b.instances)=="table"then held={};for _,id in ipairs(b.instances)do held[id]=true end end
    local seq=type(b.seq)=="table"and tonumber(b.seq.lifetime)or 0;local n=0
    for _,run in ipairs(tracker.data.run_history or {})do
        if type(run.imported)~="table"and not run.data_only and not run.hidden_contributions then
            local c=type(run.context)=="table"and run.context.mission_instance
            if held and c~=nil then if not held[c]then n=n+1 end elseif (tonumber(run.id)or 0)>seq then n=n+1 end
        end
    end
    return n
end
-- of a backup's Power DI missions, those still in the history, which restoring it takes out
mod.io_powerdi_held=function(b)
    local want={};for _,id in ipairs(type(b)=="table"and b.powerdi or {})do want[id]=true end;local n=0
    for _,run in ipairs(tracker.data.run_history or {})do local s=type(run.imported)=="table"and run.imported.session;if s~=nil and want[s]then n=n+1 end end
    return n
end
-- what restoring does to the matches, for the confirm and the Settings row alike
mod.io_restore_effect=function(list,all)
    -- a backup a Power DI import made takes the matches it imported back out
    -- and one Import Match History made takes the matches it added back out
    local taken,added,gone=0,0,0;for i=all and 1 or #list,#list do taken=taken+#(list[i].powerdi or {});added=added+(list[i].added or 0);gone=gone+#(list[i].deleted or {})end
    local out=taken>0 and added>0 and "The matches imported from Power DI and added from the Import folder are"or taken>0 and (taken==1 and "The match imported from Power DI is"or "The "..taken.." matches imported from Power DI are")
     or added>0 and (added==1 and "The match added from the Import folder is"or "The "..added.." matches added from the Import folder are")
    -- and one Match History's Delete made brings the deleted matches back
    local back=gone>0 and (gone==1 and "The deleted match comes back"or "The "..gone.." deleted matches come back")
    return out and out.." taken back out"..(back and ", "..back:sub(1,1):lower()..back:sub(2)or "")..", matches played since are kept."
     or back and back..", matches played since are kept."or "Matches played since the reset are kept."
end
mod.io_request_restore=function(all)
    if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
    local list=mod.io_backups();if not list[1]then mod:echo("There are no backups to restore.");return end
    if tracker.mission or solo_tracker.mission or collectors and collectors:partial_pending()then mod:echo("Finish the current mission and resolve any pending result first.");return end
    local body="Bring back "..Backup.describe(list,all).."?\n"..mod.io_restore_effect(list,all)
    confirm("restoring a backup",all and #list>1 and "Restore All Backups"or "Restore Latest Backup",body.."\nStatistics are rebuilt from all of them.","Restore",function()
        if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
        tracker:finish_blo_trial()
        -- a held Power DI batch still saving is settled first, so the backups and history read here include it
        if storage.settle then storage:settle()end
        local merged,brought=Backup.restore(storage,{R=Records,H=HistoryRecalculation,M=MissionSegments,I=HistoryImport},history_policy,statistics(),all)
        if not merged then mod:echo("%s",brought);return end
        tracker.data=merged.lifetime;follow_policy(tracker.data);tracker.blo_weapon_trackers={};tracker.dirty=false;solo_tracker.data=merged.solo;solo_tracker.blo_weapon_trackers={};solo_tracker.dirty=false;psykhanium_logs.data=merged.logs;psykhanium_logs.dirty=false
        history_baseline=merged.baseline;history_rebuilt_sequence=merged.lifetime.run_sequence or 0;history_policy_dirty=false;segment_checked_sequence=history_rebuilt_sequence
        friend_summaries={};friend_signature=nil;friend_people=nil;mod.io_friend_stats();psyk.drop();storage:flush();storage:release_details()
        mod:echo("Backup restored.")
    end)
end
mod.io_request_delete_backups=function()
    if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
    local list=mod.io_backups();if not list[1]then mod:echo("There are no backups to delete.");return end
    confirm("deleting backups","Delete Backups","Delete "..(#list==1 and "the backup"or "all "..#list.." backups").." for good? Your current statistics are kept.\n\nThis cannot be undone.","Yes, delete",function()
        if mod.io_powerdi_busy and mod.io_powerdi_busy()then mod:echo("%s",POWERDI_RUNNING);return end
        local ok,err=Backup.delete(storage,tracker.data.run_history);mod:echo("%s",ok and "Backups deleted." or err)
    end)
end
mod:command("io_reset", "Move all saved statistics into a backup, after a confirmation", mod.io_request_reset)
mod:command("io_restore", "Bring back the latest backup, after a confirmation", function()mod.io_request_restore(false)end)

mod.version="1.1.1"


-- Draft integration seam for the data interface; no UI/navigation changes.
mod.io_frontend_data=function(runs,filters)
 return FrontendContract.build(runs or tracker.data.run_history or {},filters)
end
local AnalysisExport=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/analysis_export")
mod:command("io_analysis_export","Export accepted Match History and observed measurements",function()
 local runs=tracker.data.run_history or {}
 local export=AnalysisExport.build(runs)
 if mod.io_api and mod.io_api.tracker then local live=mod.io_api.tracker().mission;if live and (live.measurements or live.experimental) then export.live_observation=AnalysisExport.live(live.measurements or live.experimental,live.context);export.live_observation.combat_timeline=live.combat_timeline end end
 local a=storage.a;if storage.unavailable or not a then mod:echo("Measurements export failed: saving is off.");return end
 local stem="exports/playstyle-"..tostring(os.time());local path=stem..".json";local index=1;while a.read(path)do path=stem.."-"..index..".json";index=index+1 end
 a.failure=nil;local ok=a.write(path,a.json.encode(export));if ok then mod:echo("Measurements export saved: InformationOverload/%s",path)else mod:echo("Measurements export failed: %s",a.failure or "could not write "..path)end
end)
mod:command("io_intro", "Play the first-open intro and the End Screen tip again", function()
    mod:set("intro_seen",nil);mod:set("endscreen_debrief_tip_seen",nil);mod.io_intro_broken=nil
    mod:echo("The intro plays the next time Information Overload opens, and I/O's tip shows on the next End Screen.")
end)
mod:command("io_help", "List the available Information Overload commands", function()
    mod:echo("/io_dashboard - open or close the dashboard")
    mod:echo("/io_reset - move all saved statistics into a backup, after a confirmation")
    mod:echo("/io_restore - bring back the latest backup, after a confirmation")
    mod:echo("/io_intro - play the intro again the next time it opens")
    mod:echo("/io_analysis_export - export Match History and observed measurements")
    mod:echo("/io_help - show this list")
    mod:echo("A match you don't want counted can be deleted from Match History.")
end)

local MissionTimes=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_times")
-- a Havoc 40 win merged from a rejoin has no clock of its own, so Match History offers its time to be typed in
mod.io_manual_time_allowed=function(run)
 return run and run.victory==true and run.full==false and not run.data_only and run.context and run.context.mode=="havoc"and tonumber(run.context.difficulty)==40
  and not MissionTimes.backend(run)and (run.completion_time==nil or run.completion_time.source=="manual"or run.completion_time.source==MissionTimes.ESTIMATE)or false
end
mod.io_offer_manual_time=function(id,done)
 local popup_id;local error_text="Enter the full mission completion time as minutes:seconds, for example 18:42."
 local context={title_text_unlocalized="Havoc 40 completion time",description_text_unlocalized=error_text,options={
  {template_type="terminal_input_field",keyboard_title="loc_popup_button_confirm",max_length=8,width=512},
  {template_type="text",no_localization=true,update=function()return error_text,Color.text_default(255,true)end},
  {text="Save Time",no_localization=true,callback=function(text)
    local seconds=MissionTimes.parse(text);if not seconds then error_text="Use minutes:seconds, for example 18:42.";return end
    local run;for _,r in ipairs(tracker.data.run_history or {})do if r.id==id then run=r;break end end
    if mod.io_current()and mod.io_manual_time_allowed(run)then run.completion_time={seconds=seconds,source="manual"};mod.io_times_revision=(mod.io_times_revision or 0)+1;tracker.dirty=true
     -- kept on its own too, so it is saved before the records that hold the match
     local typed=mod.io_data_get("manual_times_v1")or {};typed[tostring(run.id)]={started_at=run.started_at,seconds=seconds};mod.io_data_set("manual_times_v1",typed)
     save_click("manual_times_v1");if done then done()end end
    if popup_id then Managers.ui:event_remove_ui_popup(popup_id)end
   end},
  {text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back"}
 }}
 Managers.event:trigger("event_show_ui_popup",context,function(id)popup_id=id end)
end
-- a time typed in before a crash whose match was not saved with it goes back on the match
do local typed=mod.io_data_get("manual_times_v1")
 for _,run in ipairs(type(typed)=="table"and tracker.data.run_history or {})do local t=typed[tostring(run.id)]
  if type(t)=="table"and t.started_at==run.started_at and tonumber(t.seconds)and mod.io_manual_time_allowed(run)and not (run.completion_time and run.completion_time.seconds==t.seconds)then
   run.completion_time={seconds=t.seconds,source="manual"};tracker.dirty=true
  end
 end
end
-- Havoc is independently optional and consumes no combat observations.
-- Keep its lifecycle wiring here; implementation and state belong to its modules.
do
    local havoc = mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/havoc_board")(mod, {
        dashboard_tracker = function() return tracker end,
    })
    mod.io_havoc = havoc.api
    local update, disabled, unload = mod.update, mod.on_disabled, mod.on_unload
    local setting_changed, game_state_changed = mod.on_setting_changed, mod.on_game_state_changed
    mod.update = function(dt)
        if update then update(dt) end
        frame("Havoc board", havoc.update, dt)
    end
    mod.on_disabled = function(...)
        havoc.stop()
        if disabled then return disabled(...) end
    end
    mod.on_unload = function(...)
        havoc.stop()
        if mod.io_powerdi_release then pcall(mod.io_powerdi_release)end
        if unload then return unload(...) end
    end
    mod.on_setting_changed = function(id, ...)
        if id == "havoc_board" or id == "screen_havoc" then havoc.stop() end
        if setting_changed then return setting_changed(id, ...) end
    end
    mod.on_game_state_changed = function(status, state, ...)
        havoc.game_state_changed(status, state)
        if game_state_changed then return game_state_changed(status, state, ...) end
    end
end
do local ok,e=pcall(function()return mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/options_name")(mod)end);if ok then mod.io_options_name=e else mod:error("I/O options name: %s",tostring(e))end end
