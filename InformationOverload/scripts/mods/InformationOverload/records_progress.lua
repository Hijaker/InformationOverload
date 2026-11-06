-- Existing progress/streak/overview reducers composed into Records.
return function(Records,copy)
local mode_fields={undowned={event="knocked_down",label="Games without a down"},death_free={event="died",label="Games without a death"},unpounced={event="dog_pounced",label="Games without a pounce"},unnetted={event="trapper_netted",label="Games without a net"},uncharged={event="mutant_charged",label="Games without a Mutant catch"}}
Records.mode_streak_fields=mode_fields
function Records:mode_streak(patch,mode)
    patch=patch or "Unknown patch"
    self.data.mode_streaks=self.data.mode_streaks or {};local groups=self.data.mode_streaks
    groups[patch]=groups[patch] or {};groups[patch][mode]=groups[patch][mode] or {best={},current={}}
    return groups[patch][mode]
end
function Records:class_win_streak(patch,mode,class)
 self.data.class_win_streaks=self.data.class_win_streaks or {}
 local groups=self.data.class_win_streaks;groups[patch]=groups[patch] or {};groups[patch][mode]=groups[patch][mode] or {}
 local classes=groups[patch][mode];classes[class]=classes[class] or {current=0,best=0};return classes[class]
end
function Records:initialize_class_win_streaks()
 if self.data.class_win_streaks_initialized then return end
 for _,run in ipairs(self.data.run_history or {}) do local c=run.context
  if c and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium" and c.difficulty~="TEST ONLY" and type(run.victory)=="boolean" then
   local row=self:class_win_streak(c.patch,c.mode,c.class);row.current=run.victory and row.current+1 or 0;row.best=math.max(row.best,row.current)
  end
 end
 -- Retain older recorded bests even when the saved history is shorter.
 for _,row in pairs(self.data.rows or {}) do local c=row.context;if row.aggregate and c.difficulty~="psykhanium" and c.difficulty~="TEST ONLY" then local result=self:class_win_streak(c.patch,c.mode,c.class);result.best=math.max(result.best,row.best.win_streak or 0) end end
 self.data.class_win_streaks_initialized=true;self.dirty=true
end
function Records:complete_class_win_streak(m,victory)
 local c=m.context;if c.difficulty=="psykhanium" or c.training_history_test then return end
 local row=self:class_win_streak(c.patch,c.mode,c.class);row.current=victory and row.current+1 or 0;row.best=math.max(row.best,row.current);self.dirty=true
end
function Records:class_mode_streak(patch,mode,class)
 self.data.class_mode_streaks=self.data.class_mode_streaks or {};local groups=self.data.class_mode_streaks;groups[patch]=groups[patch] or {};groups[patch][mode]=groups[patch][mode] or {};local classes=groups[patch][mode];classes[class]=classes[class] or {best={},current={}};return classes[class]
end
function Records:initialize_class_mode_streaks()
 if self.data.class_mode_streaks_initialized then return end
 for _,run in ipairs(self.data.run_history or {}) do local c=run.context
  if c and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium" and c.difficulty~="TEST ONLY" and type(run.victory)=="boolean" then
   local exploded=run.exploded;local members=run.team_psykers and run.team_psykers.members
   if exploded==nil and members and members[tostring(c.character)]~=nil then exploded=members[tostring(c.character)]>0 end
   self:complete_mode_streak({context=c,failed=run.failed or {},team_psykers=run.team_psykers,field_improvisation=run.field_improvisation,exploded=exploded,legacy_controls=not c.combat_tracking_v56},run.victory,true)
  end
 end
 for _,row in pairs(self.data.rows or {}) do if row.aggregate then local c=row.context;local record=self:class_mode_streak(c.patch,c.mode,c.class);record.best.win=math.max(record.best.win or 0,row.best.win_streak or 0);record.best.loss=math.max(record.best.loss or 0,row.best.loss_streak or 0);for id,d in pairs(Records.mode_streak_fields) do local field=({undowned="undowned_wins",death_free="death_free_games",unpounced="unpounced_wins",unnetted="unnetted_wins",uncharged="uncharged_wins"})[id];record.best[id]=math.max(record.best[id] or 0,row.best[field] or 0) end;record.best.personal_peril_safe=math.max(record.best.personal_peril_safe or 0,row.best.psyker_safe_missions or 0) end end
 self.data.class_mode_streaks_initialized=true;self.dirty=true
end
function Records:complete_mode_streak(m,victory,class_scope)
    local record=class_scope and self:class_mode_streak(m.context.patch,m.context.mode,m.context.class) or self:mode_streak(m.context.patch,m.context.mode)
    local current,best=record.current,record.best
    current.win= victory and (current.win or 0)+1 or 0;current.loss=not victory and (current.loss or 0)+1 or 0
    best.win=math.max(best.win or 0,current.win);best.loss=math.max(best.loss or 0,current.loss)
    for id,definition in pairs(mode_fields) do
        if not (class_scope and m.legacy_controls and victory) then current[id]=victory and not (m.failed and m.failed[definition.event]) and (current[id] or 0)+1 or 0;best[id]=math.max(best[id] or 0,current[id]) end
    end
    local vets=m.field_improvisation and m.field_improvisation.veterans
    if vets then
        local missing,with=0,0
        for _,vet in pairs(vets) do if vet.has then with=with+1 else missing=missing+1 end end
        if missing+with>0 then
            current.field_improv_games=with==0 and missing>0 and (current.field_improv_games or 0)+1 or 0
            current.field_improv_vets=missing>0 and (current.field_improv_vets or 0)+missing or 0
            best.field_improv_games=math.max(best.field_improv_games or 0,current.field_improv_games)
            best.field_improv_vets=math.max(best.field_improv_vets or 0,current.field_improv_vets)
            record.field_improv_missing_total=(record.field_improv_missing_total or 0)+missing
        end
    end
    if class_scope and m.context.class=="psyker" and not m.context.crystalline_will and m.exploded~=nil then
        current.personal_peril_safe=not m.exploded and (current.personal_peril_safe or 0)+1 or 0;best.personal_peril_safe=math.max(best.personal_peril_safe or 0,current.personal_peril_safe)
    end
    local psykers=m.team_psykers
    if psykers and (psykers.detonated or psykers.present) then
        current.psyker_no_detonations=not psykers.detonated and (current.psyker_no_detonations or 0)+1 or 0
        current.psyker_detonations=psykers.detonated and (current.psyker_detonations or 0)+1 or 0
        best.psyker_no_detonations=math.max(best.psyker_no_detonations or 0,current.psyker_no_detonations)
        best.psyker_detonations=math.max(best.psyker_detonations or 0,current.psyker_detonations)
    end
    self.dirty=true
end
function Records:observe_team_psykers(present)
    local m=self.mission;if not m then return end
    m.team_psykers=m.team_psykers or {seen=false,detonated=false}
    if m.team_psykers.present~=(present==true) or present and not m.team_psykers.seen then self.dirty=true end
    m.team_psykers.present=present==true
    if present then m.team_psykers.seen=true end
end
function Records:team_psyker_detonation(personal,id)
    local m=self.mission;if not m then return end
    m.team_psykers=m.team_psykers or {present=false}
    m.team_psykers.seen=true;m.team_psykers.detonated=true
    if id then m.team_psykers.members=m.team_psykers.members or {};m.team_psykers.members[id]=(m.team_psykers.members[id] or 0)+1 end
    -- Another operative can never reset the local-only personal record.
    if personal then self:psyker_explosion() end
    self:mode_streak(m.context.patch,m.context.mode).current.psyker_no_detonations=0
    self:class_mode_streak(m.context.patch,m.context.mode,m.context.class).current.psyker_no_detonations=0
    self.dirty=true
end
-- The enemies a burst has killed are kept live only, by unit, so two of one type both count and none reach a save.
local burst_targets=setmetatable({},{__mode="k"})
-- These totals are committed only with an accepted full/partial result.
function Records:class_event(id,damage,killed,clock,target,tags)
 local m=self.mission;if not m then return end
 m.class_events=m.class_events or {};local e=m.class_events[id] or {damage=0,kills=0,bursts={}};m.class_events[id]=e
 local burst=e.bursts[#e.bursts]
 if not burst or clock-(burst.at or 0)>1 then burst={at=clock,damage=0,kills=0};e.bursts[#e.bursts+1]=burst end
 local live=burst_targets[e];if not live or live.burst~=burst then live={burst=burst,units={}};burst_targets[e]=live end
 burst.at=clock;damage=math.max(0,damage);burst.damage=burst.damage+damage;e.damage=e.damage+damage
 if killed and (not target or not live.units[target]) then
  burst.kills=burst.kills+1;e.kills=e.kills+1;tags=tags or {}
  for _,kind in ipairs({"elite","special"}) do if tags[kind] then burst[kind]=(burst[kind] or 0)+1;e[kind]=(e[kind] or 0)+1 end end
  if target then live.units[target]=true end
 end
 self.dirty=true
end
function Records:complete_class_events(m)
 self.data.class_events=self.data.class_events or {};local groups=self.data.class_events
 local patch=m.context.patch;groups[patch]=groups[patch] or {};local modes=groups[patch];modes[m.context.mode]=modes[m.context.mode] or {};local classes=modes[m.context.mode];classes[m.context.class]=classes[m.context.class] or {};local records=classes[m.context.class]
 for id,e in pairs(m.class_events or {}) do
  local r=records[id] or {total_kills=0,damage_game=0,kills_game=0,damage_burst=0,kills_burst=0};records[id]=r
  r.difficulties=r.difficulties or {};local d=tostring(m.context.difficulty);local scoped=r.difficulties[d] or {total_kills=0,damage_game=0,kills_game=0,damage_burst=0,kills_burst=0};r.difficulties[d]=scoped
  scoped.total_kills=scoped.total_kills+e.kills;scoped.damage_game=math.max(scoped.damage_game,e.damage);scoped.kills_game=math.max(scoped.kills_game,e.kills)
  for _,kind in ipairs({"elite","special"}) do scoped[kind.."_total"]=(scoped[kind.."_total"] or 0)+(e[kind] or 0);scoped[kind.."_game"]=math.max(scoped[kind.."_game"] or 0,e[kind] or 0) end
  for _,burst in ipairs(e.bursts) do scoped.damage_burst=math.max(scoped.damage_burst,burst.damage);scoped.kills_burst=math.max(scoped.kills_burst,burst.kills);for _,kind in ipairs({"elite","special"}) do scoped[kind.."_burst"]=math.max(scoped[kind.."_burst"] or 0,burst[kind] or 0) end end
  r.total_kills=r.total_kills+e.kills;r.damage_game=math.max(r.damage_game,e.damage);r.kills_game=math.max(r.kills_game,e.kills)
  for _,kind in ipairs({"elite","special"}) do r[kind.."_total"]=(r[kind.."_total"] or 0)+(e[kind] or 0);r[kind.."_game"]=math.max(r[kind.."_game"] or 0,e[kind] or 0) end
  for _,burst in ipairs(e.bursts) do for _,kind in ipairs({"elite","special"}) do r[kind.."_burst"]=math.max(r[kind.."_burst"] or 0,burst[kind] or 0) end;r.damage_burst=math.max(r.damage_burst,burst.damage);r.kills_burst=math.max(r.kills_burst,burst.kills) end
 end
 self.dirty=true
end
function Records:maelstrom_streak(patch,class)
 self.data.maelstrom_streaks=self.data.maelstrom_streaks or {};local groups=self.data.maelstrom_streaks;groups[patch]=groups[patch] or {overall={current={},best={}},classes={}};local group=groups[patch]
 if not class then return group.overall end;group.classes[class]=group.classes[class] or {current={},best={}};return group.classes[class]
end
function Records:complete_maelstrom(m,victory)
 if m.context.mode~="non-havoc" or not m.context.maelstrom then return end
 for _,row in ipairs({self:maelstrom_streak(m.context.patch),self:maelstrom_streak(m.context.patch,m.context.class)})do row.current.win=victory and (row.current.win or 0)+1 or 0;row.current.loss=not victory and (row.current.loss or 0)+1 or 0;row.best.win=math.max(row.best.win or 0,row.current.win);row.best.loss=math.max(row.best.loss or 0,row.current.loss)end;self.dirty=true
end
function Records:initialize_maelstrom_streaks()
 if self.data.maelstrom_streaks_initialized then return end
 for _,run in ipairs(self.data.run_history or {})do if not run.data_only and not run.context.training_history_test and type(run.victory)=="boolean"then self:complete_maelstrom({context=run.context},run.victory)end end
 self.data.maelstrom_streaks_initialized=true
end
function Records:running_tallies(patch,mode)
    self.data.running_tallies=self.data.running_tallies or {}
    local groups=self.data.running_tallies;patch=patch or "Unknown patch"
    groups[patch]=groups[patch] or {};groups[patch][mode]=groups[patch][mode] or {psyker_total=0,psyker_detonating=0,repeats={},enemies={}}
    local tally=groups[patch][mode];tally.repeats=tally.repeats or {};tally.enemies=tally.enemies or {};tally.psyker_total=tally.psyker_total or 0;tally.psyker_detonating=tally.psyker_detonating or 0
    return tally
end
function Records:complete_tallies(m,victory)
    if Records.departure_finalize then Records.departure_finalize(m,m.ended_clock)end
    local tally=self:running_tallies(m.context.patch,m.context.mode)
    for _,count in pairs(m.team_psykers and m.team_psykers.members or {}) do
        tally.psyker_total=tally.psyker_total+1
        if count>0 then tally.psyker_detonating=tally.psyker_detonating+1 end
        for n=2,count do tally.repeats[tostring(n)]=(tally.repeats[tostring(n)] or 0)+1 end
    end
    for _,e in ipairs(m.lethality_events or {}) do for _,source in ipairs(e.sources) do
     local target=tally.enemies[source.enemy] or {label=source.label,personal=0,team=0};tally.enemies[source.enemy]=target;if not target.outcomes then target.legacy_combined=target.team or 0;target.legacy_personal=target.personal or 0 end;target.group=source.group;target.horde_type=source.horde_type or target.horde_type;target.team=target.team+1;if e.personal then target.personal=target.personal+1 end
     target.outcomes=target.outcomes or {};target.outcomes[e.outcome]=(target.outcomes[e.outcome] or 0)+1
     local field=e.personal and "personal_classes" or "teammate_classes";target[field]=target[field] or {};local class=e.class or "unknown";local counts=target[field][class];if type(counts)~="table" then counts={} end;target[field][class]=counts;counts[e.outcome]=(counts[e.outcome] or 0)+1
     local scope=e.personal and "personal_outcomes" or "teammate_outcomes";target[scope]=target[scope] or {};target[scope][e.outcome]=(target[scope][e.outcome] or 0)+1
    end end
    for enemy,counts in pairs(m.enemy_lethality or {}) do
        local target=tally.enemies[enemy] or {label=counts.label,personal=0,team=0};tally.enemies[enemy]=target
        target.personal=target.personal+counts.personal;target.team=target.team+counts.team
    end
    if m.context.mode=="havoc"then
     tally.leave_abuse=tally.leave_abuse or {}
     for _,list in ipairs({m.leave_abuse or {},m.failed_leave_abuse or {}})do for _,entry in pairs(list)do
      local n=entry.tally_count or 0
      if entry.steam_id and n>0 then local row=tally.leave_abuse[entry.steam_id]or {name=entry.steam_name,count=0,failed=0};tally.leave_abuse[entry.steam_id]=row
       row.name=entry.steam_name or row.name;row.count=row.count+n;if list==m.failed_leave_abuse then row.failed=row.failed+n end
      end
     end end
    end
    if victory and m.context.mode=="havoc"then
     tally.leave_abuse=tally.leave_abuse or {}
     for _,entry in pairs(m.clutches_by_bot or {})do if entry.steam_id then local row=tally.leave_abuse[entry.steam_id]or {name=entry.steam_name,count=0,failed=0};tally.leave_abuse[entry.steam_id]=row
      row.name=entry.steam_name or row.name;row.bot_clutches=(row.bot_clutches or 0)+entry.count
     end end
    end
    self.dirty=true
end

function Records:class_overview(patch,mode,class)
 self.data.class_overview=self.data.class_overview or {};local groups=self.data.class_overview;groups[patch]=groups[patch]or {};groups[patch][mode]=groups[patch][mode]or {}
 local bucket=groups[patch][mode][class];if not bucket then bucket={games=0,wins=0,kills=0,damage=0,clutch_wins=0,clutch_episodes=0,failed_clutches_game=0,full_clutch_wins=0,semi_clutch_wins=0,full_clutch_episodes=0,semi_clutch_episodes=0,categories={}};groups[patch][mode][class]=bucket end;return bucket
end
function Records:record_class_overview(run)
 local c=run.context;if not c or c.training_history_test or c.difficulty=="psykhanium"or c.difficulty=="TEST ONLY"or run.data_only or type(run.victory)~="boolean"then return end
 local s=self:class_overview(c.patch,c.mode,c.class);s.games=s.games+1;if run.victory then s.wins=s.wins+1 end
 if not run.victory then s.failed_clutches_game=math.max(s.failed_clutches_game or 0,run.clutches and run.clutches.attempts or 0)end
 s.kills=math.max(s.kills,run.kills or 0);s.damage=math.max(s.damage,Records.run_damage_total(run))
 for kind,n in pairs(run.kill_categories or {})do s.categories[kind]=math.max(s.categories[kind]or 0,n)end
 if run.victory and run.clutches and run.clutches.seen then s.clutch_wins=s.clutch_wins+1;s.clutch_episodes=math.max(s.clutch_episodes,run.clutches.episodes or 0)
  for _,kind in ipairs({"full","semi"})do local n=run.clutches[kind.."_episodes"]or 0;if n>0 then local wins=kind.."_clutch_wins";local episodes=kind.."_clutch_episodes";s[wins]=(s[wins]or 0)+1;s[episodes]=math.max(s[episodes]or 0,n)end end
 end
 self.dirty=true
end
function Records:initialize_class_overview()
 if self.data.class_overview_initialized then return end
 for _,run in ipairs(self.data.run_history or {})do self:record_class_overview(run)end
 self.data.class_overview_initialized=true;self.dirty=true
end
function Records:record_ally_overview(run)
 local c=run.context;if not c or c.training_history_test or c.difficulty=="psykhanium"or c.difficulty=="TEST ONLY"or run.data_only or type(run.victory)~="boolean"then return end
 local tally=self:running_tallies(c.patch,c.mode);tally.allies=tally.allies or {}
 local people=run.operative_clutches
 if not people then people={};for _,person in pairs(c.operative_roster or {})do if person.steam_id and not person.personal then people[person.steam_id]=person end end end
 for _,p in pairs(people)do if p.steam_id then
  local row=tally.allies[p.steam_id]or {name=p.steam_name,games=0,wins=0,classes={},clutch_wins=0,clutch_episodes=0,failed_clutches_game=0};tally.allies[p.steam_id]=row;row.name=p.steam_name or row.name;row.personal=p.personal==true
  local class_id=p.class or "unknown";local class=row.classes[class_id]or {games=0,wins=0};row.classes[class_id]=class
  row.games=row.games+1;class.games=class.games+1;if run.victory then row.wins=row.wins+1;class.wins=class.wins+1 end
  local clutch=p.clutches
  if clutch then
   if run.victory and clutch.seen then row.clutch_wins=row.clutch_wins+1;class.clutch_wins=(class.clutch_wins or 0)+1
    if (clutch.episodes or 0)>row.clutch_episodes then row.clutch_episodes=clutch.episodes;row.clutch_record_class=p.class end
    for _,kind in ipairs({"full","semi"})do local n=clutch[kind.."_episodes"]or 0;if n>0 then row[kind.."_clutch_wins"]=(row[kind.."_clutch_wins"]or 0)+1;if n>(row[kind.."_clutch_episodes"]or 0)then row[kind.."_clutch_episodes"]=n;row[kind.."_clutch_record_class"]=p.class end end end
   elseif not run.victory and (clutch.attempts or 0)>row.failed_clutches_game then row.failed_clutches_game=clutch.attempts;row.failed_clutch_record_class=p.class end
  end
 end end
 self.dirty=true
end
function Records:initialize_ally_overview()
 if self.data.ally_overview_initialized then return end
 for _,run in ipairs(self.data.run_history or {})do self:record_ally_overview(run)end
 self.data.ally_overview_initialized=true;self.dirty=true
end
function Records:cache_class_run(run)
    local c=run.context
    if c.training_history_test or c.difficulty=="psykhanium" or c.difficulty=="TEST ONLY" then return end
    local row=self:rows_for(c)[1]
    local values={kills_mission=run.kills,total_damage_mission=Records.run_damage_total(run)}
    for name,value in pairs(values) do if value>(row.best[name] or -1) or value==row.best[name] and not (row.best_weapons and row.best_weapons[name]) then
        row.best[name]=value;row.best_weapons=row.best_weapons or {};row.best_weapons[name]=copy(c)
        row.best_runs=row.best_runs or {};row.best_runs[name]=run.id;self.dirty=true
    end end
end


end
