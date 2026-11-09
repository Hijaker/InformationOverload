-- Existing mission transactions, composed into the shared Records facade.
return function(Records,copy,deep_copy,checkpoint_copy,key,_,survival_events)
function Records:boundary()
    for _,child in pairs(self.blo_weapon_trackers or {}) do child:boundary() end
    -- Unresolved attacks are discarded, not incorrectly interpreted as misses.
    self:finish_blo(true)
    self:finish_selected_blo(true)
    self:finish_blo_trial()
    self.pending, self.queue = {}, {}
    for name in pairs(self.current) do self.current[name] = 0 end
    self.session_key = nil
    self.mission = nil
end

-- Mission streaks persist between sessions; combat streaks above do not.
-- Only the mission-level aggregate row is updated, never a weapon/mark row.
function Records:begin_mission(c, participated_from_start)
    if not self:accept(c) then return false end
    local before=checkpoint_copy(self.data)
    c=copy(c);c.combat_tracking_v56=true;c.detail_capture={pickups=true,friendly_fire=true,friendly_fire_sources=1,barrel_pops=true,team_damage=true}
    local timestamp
    if os and os.date then timestamp=os.date("%Y-%m-%d %H:%M:%S") end
    -- A verified interrupted session may later resume this observed segment.
    self:mission_row(c)
    self.mission = {started_at=timestamp,context = copy(c), full = participated_from_start == true, exploded = false, failed = {},
        data_before=before,
        team_psykers={seen=false,present=false,detonated=false}, incidents={personal={},team={},members={}}, kills=0, ammo = {}, ammo_seen = {}}
    return true
end

function Records:pbb_ammo(c, actual_added, event_id, source)
    local m = self.mission
    if not m or not c or c.excluded or c.class ~= "ogryn" or source ~= "pbb"
        or key(c, true) ~= key(m.context, true) then return false end
    local amount = tonumber(actual_added)
    if not amount or not (amount > 0) then return false end
    assert(event_id ~= nil, "Ammo returns need a stable deduplication ID")
    local weapon_key = key(c, false)
    local event_key = tostring(event_id) .. "|" .. weapon_key
    if m.ammo_seen[event_key] then return false end
    m.ammo_seen[event_key] = true
    m.ammo[weapon_key] = (m.ammo[weapon_key] or 0) + amount
    -- Publish the record as it grows; loss/partial participation never erases
    -- ammo actually regenerated. Every new mission starts a fresh accumulator.
    return self:best(c, "pbb_ammo_mission", m.ammo[weapon_key])
end

function Records:psyker_explosion()
    local m = self.mission
    if not m or m.context.class ~= "psyker" or m.context.crystalline_will then return false end
    m.exploded = true
    self:class_mode_streak(m.context.patch,m.context.mode,m.context.class).current.personal_peril_safe=0
    self:mission_row(m.context).psyker_safe_current = 0
    self.dirty = true
    return true
end

function Records:add_training_snapshot(source)
    if not source or not source.mission or source.mission.context.difficulty~="psykhanium" then return false end
    local m=deep_copy(source.mission)
    m.context.training_history_test=true
    m.context.mission_display_name="Psykhanium snapshot"
    m.history_recorded=nil;m.record_updates={};m.full=false
    self:save_run(m,false,true)
    return true
end
function Records:save_run(m,victory,training_test)
    if Records.departure_finalize then Records.departure_finalize(m,m.ended_clock)end
    if m.history_recorded or (not training_test and m.context.difficulty=="psykhanium") or m.context.difficulty=="TEST ONLY" then return end
    m.contributions=Records.capture_contributions and Records.capture_contributions(self,m)or m.contributions
    m.history_recorded=true
    self.data.run_sequence=(self.data.run_sequence or 0)+1
    self.data.run_history=self.data.run_history or {}
    local timestamp=m.started_at or "Time unavailable"
    local saved_context=deep_copy(m.context)
    saved_context.test_build=nil
    self.data.run_history[#self.data.run_history+1]={id=self.data.run_sequence,started_at=timestamp,timing_origin=m.timing_origin,completion_time=deep_copy(m.completion_time),completion_markers=deep_copy(m.completion_markers),timing_diagnostics=deep_copy(m.timing_diagnostics),
        combat_timeline=deep_copy(m.combat_timeline),experimental=deep_copy(m.experimental),measurements=deep_copy(m.measurements),incidents=deep_copy(m.incidents),friendly_fire_pairs=deep_copy(m.friendly_fire_pairs),pickup_pairs=deep_copy(m.pickup_pairs),pickup_states=deep_copy(m.pickup_states),team_psykers=deep_copy(m.team_psykers),enemy_lethality=deep_copy(m.enemy_lethality),lethality_events=deep_copy(m.lethality_events),barrel_pops=deep_copy(m.barrel_pops),team_damage=deep_copy(m.team_damage),party_records=deep_copy(m.party_records),enemy_kill_counts=deep_copy(m.enemy_kill_counts),psyk_dps=deep_copy(m.psyk_dps),hyper_critical=deep_copy(m.hyper_critical),haymaker=deep_copy(m.haymaker),class_events=deep_copy(m.class_events),boss_kills=deep_copy(m.boss_kills),boss_operatives=deep_copy(m.boss_operatives),clutches=deep_copy(m.clutches),operative_clutches=deep_copy(m.operative_clutches),clutches_by_bot=not m.data_only and victory and deep_copy(m.clutches_by_bot)or nil,leave_abuse=deep_copy(m.leave_abuse),failed_leave_abuse=deep_copy(m.failed_leave_abuse),kill_categories=deep_copy(m.kill_categories),support=deep_copy(m.support),players_left=m.players_left,all_departures=deep_copy(m.all_departures),departure_events=deep_copy(m.departure_events),segments=m.segments,resumed=m.resumed,contributions=deep_copy(m.contributions),run_kind=m.interrupted and "early_leave"or m.resumed and "rejoined"or not m.full and (m.context.mode=="havoc"and "partial_unknown"or "late_join")or "full",field_improvisation=deep_copy(m.field_improvisation),failed=deep_copy(m.failed),exploded=m.exploded,kills=m.kills,records=deep_copy(m.record_values),damage=deep_copy(m.damage),context=saved_context,victory=victory,data_only=m.data_only,interrupted=m.interrupted,full=m.full}
    -- a saved burst keeps its totals; who it hit and when only matter while it runs
    for _,e in pairs(self.data.run_history[#self.data.run_history].class_events or {})do for _,burst in ipairs(e.bursts or {})do burst.targets=nil;burst.at=nil end end
    self:cache_class_run(self.data.run_history[#self.data.run_history])
    local run_id=self.data.run_sequence
    for _,update in ipairs(m.enemy_updates or {}) do local hit=update.row.enemy_hits and update.row.enemy_hits[update.enemy];if hit and hit.damage==update.value then hit.run_id=run_id end end
    for _,update in ipairs(m.record_updates or {}) do
        if update.row.best[update.name]==update.value then update.row.best_runs[update.name]=run_id end
    end
    -- a mission brought back from its checkpoint names its rows by key
    for _,update in ipairs(m.enemy_update_keys or {}) do local row=self.data.rows[update.key];local hit=row and row.enemy_hits and row.enemy_hits[update.enemy];if hit and hit.damage==update.value then hit.run_id=run_id end end
    for _,update in ipairs(m.record_update_keys or {}) do
        local row=self.data.rows[update.key];if row and row.best and row.best[update.name]==update.value then row.best_runs=row.best_runs or {};row.best_runs[update.name]=run_id end
    end
    self.dirty=true
end
function Records:finish_mission(completed, victory, explicitly_count_partial)
    local m = self.mission
    if not m then return false end
    self.mission = nil -- repeated completion callbacks cannot double-count.
    if not completed or (victory ~= true and victory ~= false) or not (m.full or explicitly_count_partial == true) then return false end
    self:finalize_distinct_incidents(m)
    if m.interrupted then
        m.departed_players=m.departed_players or {};local own=tostring(m.context.character)
        for _,operative in pairs(m.context.operative_roster or {}) do if operative.personal and operative.account_id then own=operative.account_id;break end end
        if not m.departed_players[own] then m.departed_players[own]=true;m.players_left=(m.players_left or 0)+1 end
    end
    if not m.data_only then
     local function finalize(clutch)
      if not clutch then return end
      if victory and clutch.active and clutch.active_kind=="full"then clutch.full_episodes=(clutch.full_episodes or 0)+1;clutch.episodes=(clutch.episodes or 0)+1;clutch.active=nil end
      if victory then clutch.seen=(clutch.episodes or 0)>0 end
     end
     finalize(m.clutches);for _,person in pairs(m.operative_clutches or {})do if person.clutches~=m.clutches then finalize(person.clutches)end end
     if not victory and m.clutches then self:best(m.context,"personal_failed_clutches_mission",m.clutches.attempts or 0)end
    end
    self:complete_incidents(m)
    if not m.data_only then self:complete_mode_streak(m,victory);self:complete_mode_streak(m,victory,true);self:complete_class_win_streak(m,victory);self:complete_maelstrom(m,victory);self:complete_tallies(m,victory);self:complete_class_events(m);self:complete_boss_records(m);if victory and m.clutches and m.clutches.seen then self:best(m.context,"clutch_episodes_mission",m.clutches.episodes or 0)end;self:best(m.context,"players_left_mission",m.players_left or 0) end
    self:record_class_overview({context=m.context,victory=victory,data_only=m.data_only,kills=m.kills,damage=m.damage,team_damage=m.team_damage,kill_categories=m.kill_categories,clutches=m.clutches})
    self:record_ally_overview({context=m.context,victory=victory,data_only=m.data_only,operative_clutches=m.operative_clutches})
    self:save_run(m,victory)
    local row = self:mission_row(m.context)
    row.win_current = victory and (row.win_current or 0) + 1 or 0
    row.loss_current = not victory and (row.loss_current or 0) + 1 or 0
    row.best.win_streak = math.max(row.best.win_streak or 0, row.win_current)
    row.best.loss_streak = math.max(row.best.loss_streak or 0, row.loss_current)
    self.dirty = true
    if m.context.class == "psyker" and not m.context.crystalline_will and not m.exploded and not m.data_only then
        row.psyker_safe_current = (row.psyker_safe_current or 0) + 1
        row.best.psyker_safe_missions = math.max(row.best.psyker_safe_missions or 0, row.psyker_safe_current)
    end
    if not victory then
        for _,definition in pairs(survival_events) do row[definition.current]=0 end
        row.death_free_current=0
        return true
    end
    row.death_free_current=not m.failed.died and (row.death_free_current or 0)+1 or 0
    row.best.death_free_games=math.max(row.best.death_free_games or 0,row.death_free_current)
    for event, definition in pairs(survival_events) do
        if not m.failed[event] then
            row[definition.current] = (row[definition.current] or 0) + 1
            row.best[definition.best] = math.max(row.best[definition.best] or 0, row[definition.current])
        end
    end
    self.dirty = true
    return true
end

function Records:accept(c)
    if not c or c.excluded or (c.mode ~= "havoc" and c.mode ~= "non-havoc") then return false end
    for _, field in ipairs({"patch", "difficulty", "class", "character", "category", "weapon"}) do
        if c[field] == nil then return false end
    end
    if type(c.character_name) == "string" and c.character_name ~= "" then
        self.data.character_names = self.data.character_names or {}
        if self.data.character_names[c.character] ~= c.character_name then
            self.data.character_names[c.character] = c.character_name
            self.dirty = true
        end
    end
    local new_key = key(c, true)
    if self.session_key and self.session_key ~= new_key then self:boundary() end
    self.session_key = new_key
    return true
end


end
