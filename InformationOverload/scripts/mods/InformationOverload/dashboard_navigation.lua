local MissionRecords=get_mod("information_overload"):io_dofile("InformationOverload/scripts/mods/InformationOverload/records")
local N={}
function N.show_leave_abuse()
 local mod=type(get_mod)=="function"and get_mod("information_overload")
 return not mod or not mod.get or mod:get("show_leave_abuse")~=false
end
function N.modes()
 local mod=type(get_mod)=="function" and get_mod("information_overload")
 local selected=mod and type(mod.get)=="function" and mod:get("preferred_mode")
 return selected=="non-havoc"and {"non-havoc","havoc"}or {"havoc","non-havoc"}
end
N.classes={"veteran","zealot","psyker","ogryn","adamant","broker","cryptic"}
N.armours={"unarmored","armored","berserker","super_armor","resistant","disgustingly_resilient","unknown"}
function N.patches(tracker)
    local seen,list={},{}
    local function add(p) if p and not seen[p] then seen[p]=true;list[#list+1]=p end end
    for _,row in pairs(tracker.data.rows or {}) do add(row.context.patch) end
    for _,run in ipairs(tracker.data.run_history or {}) do add(run.context.patch) end
    for p in pairs(tracker.data.blo_global or {}) do add(p) end
    table.sort(list,function(a,b)
        local aa={a:match("^(%d+)%.(%d+)%.(%d+)$")};local bb={b:match("^(%d+)%.(%d+)%.(%d+)$")}
        if #aa==3 and #bb==3 then for i=1,3 do if tonumber(aa[i])~=tonumber(bb[i]) then return tonumber(aa[i])<tonumber(bb[i]) end end end
        return a<b
    end);return list
end
function N.summary(tracker,filters,armour)
    local result={best={},sources={},record_runs={}}
    for _,row in pairs(tracker.data.rows or {}) do
        local c=row.context;local matches=true
        for k,v in pairs(filters or {}) do if v and c[k]~=v then matches=false end end
        if matches and ((filters.category or filters.weapon) and not row.aggregate or not filters.category and not filters.weapon and row.aggregate) then
            local bucket=armour and row.armour_best and row.armour_best[armour]
            local values=armour and (bucket and bucket.best or {}) or row.best
            local sources=armour and (bucket and bucket.sources or {}) or row.best_weapons or {}
            for k,v in pairs(values) do if v>(result.best[k] or -1) then
                result.best[k]=v;result.sources[k]=sources[k] or c
                result.record_runs[k]=not armour and row.best_runs and row.best_runs[k]
            end end
        end
    end
    return result
end
function N.has_weapon_data(tracker,patch,screen,weapon)
 if screen=="pbb"then return (N.summary(tracker,{patch=patch,class="ogryn",weapon=weapon}).best.pbb_ammo_mission or 0)>0 end
 if screen=="blo"then
  local data=tracker.data.blo_weapons and tracker.data.blo_weapons[patch]and tracker.data.blo_weapons[patch][weapon]
  local bucket=data and data.blo_global and data.blo_global[tostring(patch)]and data.blo_global[tostring(patch)].base
  return bucket and ((bucket.shots or 0)>0 or (bucket.best or 0)>0 or (bucket.procs or 0)>0)or false
 end
 return true
end
-- Most Damage In A Mission is useful damage, overkill left out, read from what a saved match keeps resident: summary navigation must never materialise a match's file-backed details.
local function useful(run)return (MissionRecords.run_useful(run))end
function N.damage_share(tracker,id)
 for _,run in ipairs(tracker.data.run_history or {})do if run.id==id then
  local own,team=MissionRecords.run_useful(run)
  if own and team and team>0 then return own/team*100 end
  return
 end end
end
function N.class_missions(tracker,patch,mode,class)
 local groups=tracker.data.class_overview;local saved=groups and groups[patch]and groups[patch][mode]and groups[patch][mode][class];if saved then
  -- the saved overview keeps reported damage, so the best comes from the matches alone
  local copy={};for key,value in pairs(saved)do copy[key]=value end;copy.damage=0
  for _,run in ipairs(tracker.data.run_history or {})do local c=run.context or {};if c.patch==patch and c.mode==mode and c.class==class and not run.stats_excluded and not run.data_only then copy.damage=math.max(copy.damage,useful(run)or 0)end end
  return copy
 end
 local result={games=0,wins=0,kills=0,damage=0,clutch_wins=0,clutch_episodes=0,categories={}}
 for _,run in ipairs(tracker.data.run_history or {})do local c=run.context
  if (not patch or c.patch==patch)and c.mode==mode and c.class==class and not c.training_history_test and c.difficulty~="psykhanium"and not run.stats_excluded and c.difficulty~="TEST ONLY"and not run.data_only and type(run.victory)=="boolean"then
   result.games=result.games+1;if run.victory then result.wins=result.wins+1 end
   result.kills=math.max(result.kills,run.kills or 0)
   result.damage=math.max(result.damage,useful(run)or 0)
   for kind,n in pairs(run.kill_categories or {})do result.categories[kind]=math.max(result.categories[kind]or 0,n)end
   if run.victory and run.clutches and run.clutches.seen then result.clutch_wins=result.clutch_wins+1;result.clutch_episodes=math.max(result.clutch_episodes,run.clutches.episodes or 0)end
  end
 end
 return result
end
function N.overall_missions(tracker,patch,mode)
 local result={games=0,wins=0,kills=0,damage=0,clutch_wins=0,clutch_episodes=0,failed_clutches_game=0,categories={}}
 for _,class in ipairs(N.classes)do local row=N.class_missions(tracker,patch,mode,class)
  result.games=result.games+row.games;result.wins=result.wins+row.wins
  for _,key in ipairs({"kills","damage","clutch_episodes","failed_clutches_game","full_clutch_episodes","semi_clutch_episodes"})do result[key]=math.max(result[key]or 0,row[key]or 0)end
  for _,key in ipairs({"clutch_wins","full_clutch_wins","semi_clutch_wins"})do result[key]=(result[key]or 0)+(row[key]or 0)end
  for id,n in pairs(row.categories or {})do result.categories[id]=math.max(result.categories[id]or 0,n)end
 end
 return result
end
function N.mission_sources(tracker,patch,mode,stats,class)
 local sources={};local wins,best=0,0
 for _,run in ipairs(tracker.data.run_history or {})do local c=run.context
  if c and not run.stats_excluded and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium"and c.difficulty~="TEST ONLY"and (not patch or c.patch==patch)and c.mode==mode and (not class or c.class==class)and type(run.victory)=="boolean"then
   if run.victory then wins=wins+1 else wins=0 end
   if wins>best then best=wins;sources.win=run.id end
   if run.kills==stats.kills and stats.kills>0 then sources.kills=run.id end
   local d=useful(run)
   if d==stats.damage and stats.damage>0 then sources.damage=run.id end
   for id,n in pairs(run.kill_categories or {})do if n>0 and n==stats.categories[id]then sources[id]=run.id end end
  end
 end
 sources.win_value=best;return sources
end
function N.incident_outcome_summary(tracker,patch,mode,outcome)
 local result={best={},sources={},record_runs={}}
 local credits;local function credit(id,name)credits=credits or tracker.record_credits(tracker.data.rows);local c=credits[id];return c and c[name]end
 local order=tracker.reach_order
 local function record(id,value,run,source)
  if type(value)=="number"and value>(result.best[id]or 0)then result.best[id]=value;result.sources[id]=source or {class=run.context.class};result.record_runs[id]=run.id end
 end
 for _,run in ipairs(tracker.data.run_history or {})do local c=run.context
  if not run.stats_excluded and c and (not patch or c.patch==patch)and (not mode or c.mode==mode)and not c.training_history_test and c.difficulty~="psykhanium"and type(run.victory)=="boolean"and not run.data_only and (not outcome or run.victory==(outcome=="win"))then
   local stats=tracker.incident_counts and tracker.incident_counts(run)or run.incidents or {}
   for _,field in ipairs({"downs","pounces","nets","mutant_charges","deaths","pickups","friendly_fire","lethal_kicks","murders","suicides"})do
    local own=field=="mutant_charges"and "mutant_charges_mission"or "personal_"..field.."_mission"
    record(own,stats.personal and stats.personal[field],run)
    record("team_"..field.."_mission",stats.team and stats.team[field],run)
    local name,who="teammate_"..field.."_mission",c.operative_identities
    for _,id in ipairs(order(stats.members,field,credit,who,run.id,name))do local p,identity=stats.members[id],who and who[id];record(name,p.counts and p.counts[field],run,{class=p.class,friend_name=identity and identity.friend_name})end
   end
   record("players_left_mission",run.players_left,run)
   for _,kind in ipairs({"total","real","weakened"})do local name="teammate_boss_"..kind.."_mission"
    for _,id in ipairs(order(run.boss_operatives,kind,credit,nil,run.id,name))do local p=run.boss_operatives[id];if not p.personal then record(name,p[kind],run,{class=p.class,friend_name=p.friend_name})end end
   end
   local team,own,weak,own_weak,rituals=0,0,0,0,0
   for id,e in pairs(run.boss_kills or {})do if id=="hexbound_ritual"then rituals=rituals+(e.count or 0)else team=team+(e.count or 0);own=own+(e.personal or 0);weak=weak+(e.weakened or 0);own_weak=own_weak+(e.personal_weakened or 0)end end
   for id,n in pairs({team_boss_total_mission=team,team_boss_real_mission=team-weak,team_boss_weakened_mission=weak,personal_boss_total_mission=own,personal_boss_real_mission=own-own_weak,personal_boss_weakened_mission=own_weak,team_ritual_stops_mission=rituals})do record(id,n,run)end
  end
 end
 return result
end
return N
