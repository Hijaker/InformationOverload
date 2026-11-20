-- A finished Power DI mission as an I/O match. Power DI keeps the game's own reports (attack results, spawns, player states, interactions),
-- so they go through I/O's own reducers in the order Power DI stored them: the squad tally, party kills, kill credit, downs and pickups.
-- What Power DI never saw (attack grouping, hit zones, the server's clear time, account ids) is left out; a win's clear time is only estimated.
-- It never saw a captain's weapon either, so a captain stays out of the boss kills, as live I/O leaves out one whose weapon it cannot read,
-- and it kept no melee dodge, so dodges are left unset and the Support page shows a dash.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Team=mod:io_dofile(base.."team_damage")
local Party=mod:io_dofile(base.."party_records")
local Grouping=mod:io_dofile(base.."enemy_grouping")
local Catalog=mod:io_dofile(base.."enemy_catalog")
local Times=mod:io_dofile(base.."mission_times")
local BossIdentity=mod:io_dofile(base.."boss_identity")
local Convert={}

local function load(path)local ok,v=pcall(require,path);if ok and type(v)=="table"then return v end end
local function localized(key)
 if type(key)~="string"or type(Localize)~="function"then return end
 local ok,label=pcall(Localize,key)
 if ok and type(label)=="string"and label~=""and label~=key and not label:find("<unlocalized",1,true)then return label end
end
local function copy(v)if type(v)~="table"then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end

function Convert.file_name(session_id)return (tostring(session_id):lower():gsub("[%p%c%s]","_"))end

local FINISHED={won=true,lost=true}
function Convert.scan(index)
 local list=type(index)=="table"and index.sessions_index
 if type(list)~="table"then return {ids={},incomplete=0,missing=true}end
 local sessions=type(index.sessions)=="table"and index.sessions or {}
 local ids,unfinished,incomplete,seen,danger={},{},0,{},{}
 for _,id in ipairs(list)do if type(id)=="string"and id~="local"and not seen[id]then seen[id]=true
  -- Expeditions, Survival and the shooting range are no missions I/O records, so they count in neither number
  local s=sessions[id];local m=type(s)=="table"and type(s.mission)=="table"and s.mission.game_mode_name
  if m and m~="coop_complete_objective"and m~="coop"and m~="havoc"then elseif type(s)=="table"and FINISHED[s.outcome]then ids[#ids+1]=id
   local md=type(s.mission_data)=="table"and s.mission_data;if md and tonumber(md.resistance)then danger[id]={challenge=tonumber(md.challenge),resistance=tonumber(md.resistance)}end
  else incomplete=incomplete+1;unfinished[#unfinished+1]=id end
 end end
 return {ids=ids,unfinished=unfinished,incomplete=incomplete,danger=danger}
end

function Convert.drop_heavy(data)
 if type(data)~="table"then return end
 data.datasets,data.reports,data.dataset_template_hash_lookup,data.report_template_hash_lookup=nil,nil,nil,nil
end

-- the game's names for a challenge and resistance, from its own table where it loads, else the pairs its missions use
local DANGER={[1]="sedition",[2]="uprising",[3]="malice",[4]="heresy",[5]="damnation"}
local function danger_name(challenge,resistance)
 local Danger=load("scripts/utilities/danger")
 if Danger and type(Danger.danger_by_difficulty)=="function"then
  local ok,d=pcall(Danger.danger_by_difficulty,challenge,resistance)
  if ok and type(d)=="table"and type(d.name)=="string"and d.name~="undefined"then return d.name end
 end
 if challenge==5 and resistance==5 then return "auric"end
 return DANGER[challenge]
end
-- the mission's modifiers as a match names them while played: each circumstance and its mutators by their game label, a name the game
-- cannot say left out
local function modifiers(chosen)
 local templates=load("scripts/settings/circumstance/circumstance_templates")or {}
 local mutators=load("scripts/settings/mutator/mutator_templates")or {}
 local out,maelstrom={},false
 for _,id in ipairs(chosen)do
  local t=templates[id];local ui=type(t)=="table"and t.ui or {}
  if type(ui.icon)=="string"and ui.icon:find("maelstrom",1,true)then maelstrom=true end
  local label=localized(type(t)=="table"and t.display_name or ui.display_name);if label then out[id]=label end
  for _,m in ipairs(type(t)=="table"and type(t.mutators)=="table"and t.mutators or {})do
   local mt=mutators[m];local l=type(mt)=="table"and localized(mt.display_name or mt.name);if l then out[m]=l end
  end
 end
 return out,maelstrom
end

local DOT={bleeding="Bleed",burning="Burn",phosphor_burning="Burn",warpfire="Soulblaze",toxin_variant_1="Toxin",toxin_variant_2="Toxin",toxin_variant_3="Toxin"}
local STATE_EVENT={knocked_down="knocked_down",pounced="dog_pounced",netted="trapper_netted",mutant_charged="mutant_charged",dead="died",hogtied="died"}
local INCIDENT={knocked_down="downs",dog_pounced="pounces",trapper_netted="nets",mutant_charged="mutant_charges",died="deaths",pickup="pickups",suicides="suicides",murders="murders"}
local STANDING={walking=true,jumping=true,dodging=true,sliding=true,sprinting=true,idle=true}
local UP={walking=true,jumping=true,falling=true,dodging=true,sliding=true,sprinting=true,idle=true}
local DOWNED={knocked_down=true,dead=true,hogtied=true}
local BLAST={barrel_explosion=true,barrel_explosion_close=true,fire_barrel_explosion=true,fire_barrel_explosion_close=true,
 poxwalker_explosion=true,poxwalker_explosion_close=true,poxwalker_explosion_mild=true,poxwalker_explosion_close_mild=true}
local BARREL={barrel_explosion=true,barrel_explosion_close=true,fire_barrel_explosion=true,fire_barrel_explosion_close=true,liquid_area_fire_burning_barrel=true}
local UNOWNED={grenadier_liquid_fire_burning="fire",renegade_flamer_liquid_fire_burning="fire",cultist_flamer_liquid_fire_burning="fire",liquid_area_fire_burning="fire",
 burning="fire",horde_flame_impact="fire",flamer_implosion="fire",cultist_grenadier_gas="gas",toxic_gas="gas",toxic_gas_mutator="gas",
 toxin_variant_3="renegade_wizard",renegade_wizard_z_catapult="renegade_wizard",netted_tick="renegade_netgunner"}
local HAZARD={fire={enemy="fire",label="Fire"},gas={enemy="toxic_gas",label="Toxic Gas"}}
local SAVES={revive="revives",pull_up="saves",remove_net="saves",rescue="saves"}
local CAPTAINS=BossIdentity.captains
-- the enemies that pin a player and the state each puts them in, from the game's behaviour trees; a net is no pin a kill saves from
local PINNER={chaos_hound="pounced",chaos_hound_mutator="pounced",chaos_armored_hound="pounced",cultist_mutant="mutant_charged",chaos_spawn="grabbed",
 chaos_beast_of_nurgle="consumed",chaos_daemonhost="warp_grabbed",chaos_daemonhost_torment="warp_grabbed",chaos_mutator_daemonhost="warp_grabbed"}
local PINNED={pounced=true,mutant_charged=true,grabbed=true,consumed=true,warp_grabbed=true}
local NO_TAGS={}
local function kind_of(b)local tags=b.tags or NO_TAGS;return (b.is_boss or tags.monster or tags.captain)and "boss"or tags.special and "special"or tags.elite and "elite"or "horde"end
local function group_of(b)local k=kind_of(b);return k=="horde"and "normal"or k end
local function ms(t)return type(t)=="number"and math.floor(t*1000+.5)or nil end
local function list(v)return type(v)=="table"and v or {}end
-- a datasource's rows in order, one that is no table skipped, so a malformed row costs itself and not the mission
local function rows(v)local t,i=list(v),0;return function()while true do i=i+1;local e=t[i];if e==nil then return nil end;if type(e)=="table"then return i,e end end end end
-- Power DI's rows run on the gameplay clock until the result reaches the client, which I/O's own matches put 7 seconds after the victory on most maps
-- and longer where the outro is; I/O's clock starts when the intro ends, 6.5 seconds in. A late join's clock still runs from the mission's start.
local RESULT_AFTER={km_heresy=8,fm_cargo=8.5,fm_resurgence=8.5,spillway=9.4}
local INTRO=6.5
-- the longest a mission goes with no row of any kind while the player is in it
local AWAY=30
-- the fields a row names a player's unit in, for the first and last row of each unit
local UNIT_FIELDS={"player_unit_uuid","attacking_unit_uuid","attacked_unit_uuid","interactor_unit_uuid","interactee_unit_uuid","unit_uuid","coherency_player_unit_uuid"}

-- each operative's rise in a count numbered, so a tie goes to whoever reached it first, as Records.mark_reached numbers them
local function mark_reached(people,person,field)
 local n=0;for _,p in pairs(people)do if type(p)=="table"and type(p.reached)=="table"then for _,v in pairs(p.reached)do if type(v)=="number"and v>n then n=v end end end end
 person.reached=type(person.reached)=="table"and person.reached or {};person.reached[field]=n+1
end

-- a stored profile's item, read as the live item reads, its traits and perks from the gear it was rolled with
local function item(slot)
 if type(slot)~="table"then return nil end
 local master=type(slot.__master_item)=="table"and slot.__master_item or slot
 local gear=type(slot.__gear)=="table"and type(slot.__gear.masterDataInstance)=="table"and slot.__gear.masterDataInstance.overrides or {}
 return setmetatable({traits=gear.traits or master.traits,perks=gear.perks or master.perks,gear_id=slot.__gear_id},{__index=master})
end
local function loadout(profile,Loadouts)
 local slots=type(profile.loadout)=="table"and profile.loadout or {}
 local primary,secondary=item(slots.slot_primary),item(slots.slot_secondary)
 local out
 if Loadouts and type(Loadouts.capture)=="function"then
  local proxy={loadout={slot_primary=primary,slot_secondary=secondary,slot_attachment_1=item(slots.slot_attachment_1),slot_attachment_2=item(slots.slot_attachment_2),slot_attachment_3=item(slots.slot_attachment_3)},
   archetype=profile.archetype,talents=profile.talents,selected_nodes=profile.selected_nodes}
  local ok,v=pcall(Loadouts.capture,proxy);if ok and type(v)=="table"then out=v end
 end
 out=out or {}
 out.melee_template=out.melee_template or primary and type(primary.weapon_template)=="string"and primary.weapon_template or nil
 out.ranged_template=out.ranged_template or secondary and type(secondary.weapon_template)=="string"and secondary.weapon_template or nil
 out.melee=out.melee or primary and localized(primary.display_name)or nil
 out.ranged=out.ranged or secondary and localized(secondary.display_name)or nil
 local a=profile.archetype;out.archetype=out.archetype or type(a)=="table"and a.name or nil
 return out
end

-- opts: patch_fallback, the patch for a mission whose game version is unreadable; danger, the challenge and resistance Power DI's list holds
-- for the session; pause, called every thousand rows, outside any pcall
function Convert.run(data,opts,pause)
 opts=opts or {}
 local info=type(data)=="table"and data.info
 if type(info)~="table"then return nil,"no info"end
 if not FINISHED[info.outcome]then return nil,"unfinished"end
 if type(info.session_id)~="string"or info.session_id==""or info.session_id=="local"then return nil,"no session"end
 local ds=type(data.datasources)=="table"and data.datasources
 if not ds then return nil,"no datasources"end
 local mission=type(info.mission)=="table"and info.mission or {}
 local md=type(info.mission_data)=="table"and info.mission_data or {}
 local game_mode=mission.game_mode_name
 if game_mode and game_mode~="coop_complete_objective"and game_mode~="coop"and game_mode~="havoc"then return nil,"not a mission"end
 local mission_name=mission.name or md.map
 if type(mission_name)~="string"or mission_name:find("prologue",1,true)then return nil,"no mission"end
 local dated,started_at=pcall(os.date,"%Y-%m-%d %H:%M:%S",info.start_time)
 if type(info.start_time)~="number"or not dated or type(started_at)~="string"then return nil,"no start time"end

 local Breeds=load("scripts/settings/breed/breeds")or {}
 local spawns=list(ds.UnitSpawnerManager);local profiles=list(ds.PlayerProfiles)
 local n=0;local function step()n=n+1;if pause and n%1000==0 then pause()end end

 -- the player's own units are the ones whose weapons were wielded locally; a respawn is the same character
 local mine={}
 for _,e in rows(ds.VisualLoadoutSystem)do if type(e.event)=="string"and e.event:sub(-6)=="_local"and e.player_unit_uuid then mine[e.player_unit_uuid]=true end end
 local own_profile
 for u in pairs(mine)do if type(profiles[u])=="table"then own_profile=profiles[u];break end end
 if not own_profile then return nil,"no local player"end
 local own_id=tostring(own_profile.character_id)
 local function member(u)
  local p=u and profiles[u];if type(p)~="table"or p.character_id==nil then return nil end
  local a=p.archetype;return tostring(p.character_id),type(a)=="table"and a.name or a,tostring(p.character_id)==own_id
 end
 local function is_player(u)local s=u and spawns[u];return type(s)=="table"and s.unit_template_name=="player_character"end
 -- an enemy is a minion with a breed; a report naming no unit is an enemy unknown, as I/O treats one, but a unit Power DI never saw spawn is a barrel or prop ("lu_"), no enemy
 local function enemy(u)
  local s=u and spawns[u];if type(s)~="table"then return nil,nil,u==nil end
  if s.unit_template_name~="minion"then return nil,nil,false end
  local b=Breeds[s.unit_name];if type(b)~="table"or b.breed_type~="minion"then return nil,nil,true end
  return s,b,false
 end
 local function label(id)local l=Catalog.name(id);if l=="Unknown enemy"then local b=Breeds[id];l=b and localized(b.display_name)or l end;return l end
 -- a monster spawned well under the health the game gives its kind at the mission's challenge, or under the strongest of its kind seen,
 -- is weakened, as Maelstrom's are
 local health=(load("scripts/settings/difficulty/minion_difficulty_settings")or {}).health
 -- a save whose mission_data never arrived takes the pair from Power DI's list, which keeps the same session's info
 local listed=type(opts.danger)=="table"and opts.danger or {}
 local challenge=tonumber(md.challenge)or tonumber(listed.challenge)or tonumber(info.difficulty)
 local strongest={}
 for _,s in pairs(spawns)do step()
  if type(s)=="table"and s.unit_template_name=="minion"and BossIdentity.monsters[s.unit_name]and type(s.max_health)=="number"and s.max_health>(strongest[s.unit_name]or 0)then strongest[s.unit_name]=s.max_health end
 end
 local function weakened(s,b)
  if not (s and b and BossIdentity.monsters[b.name])or b.ignore_weakened_boss_name or type(s.max_health)~="number"then return false end
  local steps=type(health)=="table"and health[b.name];local full=type(steps)=="table"and challenge and steps[math.min(#steps,math.max(1,challenge))]
  return s.max_health<.7*math.max(type(full)=="number"and full or 0,strongest[b.name]or 0)
 end

 local victory=info.outcome=="won"
 local spawn_at
 for u in pairs(mine)do local s=spawns[u];if type(s)=="table"and type(s.time)=="number"then spawn_at=math.min(spawn_at or s.time,s.time)end end
 local from_start=spawn_at==nil or spawn_at<=5
 -- a mission crashed out of and rejoined: Power DI brings back the rows from before the crash and marks the session resumed, but keeps
 -- nothing while the game is closed, so a stretch with no rows at all that the player's own unit spawns again at the end of is a rejoin.
 -- Power DI also marks a session resumed with no gap, so the flag alone is none.
 local away={}
 if info.resumed==true and spawn_at then
  local times={}
  for _,source in pairs(ds)do if type(source)=="table"then for _,e in pairs(source)do step()
   local t=type(e)=="table"and e.time;if type(t)=="number"and t>=spawn_at and t<=86400 then times[#times+1]=t end
  end end end
  table.sort(times)
  for i=2,#times do local a,b=times[i-1],times[i]
   if b-a>AWAY then for u in pairs(mine)do local s=spawns[u];if type(s)=="table"and type(s.time)=="number"and s.time>=a and s.time<=b+AWAY then away[#away+1]={a,b};break end end end
  end
 end
 local rejoined=#away>0
 local full=from_start and not rejoined
 -- how much of a span the player was away for
 local function gone(a,b)local n=0;for _,g in ipairs(away)do n=n+math.max(0,math.min(b,g[2])-math.max(a,g[1]))end;return n end

 local havoc,rank,faction=game_mode=="havoc",nil,nil
 local chosen={};if type(md.circumstance)=="string"and md.circumstance~=""then chosen[1]=md.circumstance end
 for key,on in pairs(list(md.flags))do if type(key)=="string"and on then
  local circ=key:match("^havoc%-circ%-(.+)$");if circ then chosen[#chosen+1]=(circ:gsub("maelstrom_plus","havoc"))end
  local r=key:match("^havoc%-rank%-(%d+)$");if r then rank=r;havoc=true end
  local f=key:match("^havoc%-faction%-(.+)$");if f then faction=f;havoc=true end
  if key:find("^havoc%-")then havoc=true end
 end end
 local difficulty=havoc and (rank or "havoc-rank-unverified")or danger_name(challenge,tonumber(md.resistance)or tonumber(listed.resistance))or tostring(info.difficulty or "unknown-difficulty")
 local patch=type(info.game_version)=="string"and info.game_version:match("^(%d+%.%d+%.%d+)")or opts.patch_fallback
 if type(patch)~="string"then return nil,"no patch"end
 local mods,maelstrom=modifiers(chosen)

 local own_class=type(own_profile.archetype)=="table"and own_profile.archetype.name or "unknown-class"
 local Loadouts;do local ok,v=pcall(mod.io_dofile,mod,base.."operative_loadout");if ok and type(v)=="table"then Loadouts=v end end
 local context={mission_instance=info.session_id,mission_name=mission_name,
  mission_display_name=localized(mission.mission_name)or mission_name,
  mode=havoc and "havoc"or "non-havoc",patch=patch,difficulty=tostring(difficulty),class=own_class,
  character=own_id,character_name=own_profile.name,solo=false,grenade=false,explosive=false,category="melee",
  circumstance=type(md.circumstance)=="string"and md.circumstance or nil,modifiers=mods,maelstrom=maelstrom or nil,havoc_faction=faction,
  combat_tracking_v56=true,detail_capture={pickups=true,friendly_fire=true,friendly_fire_sources=1,team_damage=true},
  teammates={},operative_roster={},operative_identities={},operative_loadouts={}}
 local first_spawn={}
 for u,p in pairs(profiles)do if type(p)=="table"and p.character_id~=nil then
  local id,class,personal=member(u);local s=spawns[u];local t=type(s)=="table"and s.time or nil
  if t and (first_spawn[id]==nil or t<first_spawn[id])then first_spawn[id]=t end
  if type(p.name)=="string"then context.teammates[p.name]=class or true end
  context.operative_identities[id]={name=p.name,class=class,human=true,personal=personal}
  local row=context.operative_roster[id]or {name=p.name,class=class,level=p.current_level,personal=personal,present=true};context.operative_roster[id]=row
  if not context.operative_loadouts[id]or personal and mine[u]then context.operative_loadouts[id]=loadout(p,Loadouts)end
 end end
 for id,row in pairs(context.operative_roster)do row.late_join=first_spawn[id]~=nil and first_spawn[id]>5 or nil end
 if not context.operative_roster[own_id]then context.operative_roster[own_id]={name=own_profile.name,class=own_class,personal=true,present=true}end
 local own_loadout=context.operative_loadouts[own_id]or {}
 context.weapon=own_loadout.melee_template or own_loadout.ranged_template or "unknown-weapon"
 if not own_loadout.melee_template and own_loadout.ranged_template then context.category="ranged"end
 step()

 local run={started_at=started_at,victory=victory,full=full,resumed=rejoined or nil,segments=rejoined and #away+1 or nil,
  run_kind=rejoined and "rejoined"or full and "full"or (havoc and "partial_unknown"or "late_join"),
  imported={from="power_di",session=info.session_id,version=info.power_di_version},
  kills=0,exploded=false,failed={},players_left=0,context=context,
  incidents={personal={},team={},members={}}}
 -- a win's clear time, estimated: from I/O's 0:00 to the victory, found back from the last row Power DI kept
 if victory then
  local stop=0
  for _,source in pairs(ds)do if type(source)=="table"then for _,e in pairs(source)do step()
   local t=type(e)=="table"and e.time;if type(t)=="number"and t>stop and t<=86400 then stop=t end
  end end end
  local s=stop-(RESULT_AFTER[mission_name]or 7)-INTRO
  if s>0 then run.completion_time={seconds=math.floor(s*1000+.5)/1000,source=Times.ESTIMATE}end
 end

 -- the squad tally, party kills and the player's own kill credit, report by report in stored order
 local team=Team.new();team.data.minutes.origin_ms=0
 local party=Party.new();for id,p in pairs(context.operative_roster)do Party.register(party,id,p.class,p.personal)end
 local seeded,credited,last_attack,boss_credit={},{},{},{}
 local damage={dot_version=1}
 local function add_damage(group,armour,amount,budget)
  for _,key in ipairs({"all",armour})do local s=group[key]or {total=0,useful=0,overkill=0,hits=0};group[key]=s
   s.total=s.total+amount;s.hits=s.hits+1
   if type(budget)=="number"and budget>0 then local u=math.min(amount,budget);s.useful=s.useful+u;s.overkill=s.overkill+amount-u end end
 end
 local boss_kills,boss_operatives,boss_blow={},{},{}
 local function boss_id(b,profile)
  if CAPTAINS[b.name]then return nil end
  if b.name=="chaos_mutator_daemonhost"then return profile=="default"and "hexbound_ritual"or "hexbound_daemonhost"end
  return b.name
 end
 local function boss_label(id)
  if id=="hexbound_ritual"then return "Hexbound Daemonhost - Ritual stopped"end
  if id=="hexbound_daemonhost"then return "Hexbound Daemonhost - Defeated"end
  return label(id)
 end
 local function personal_boss(id,token,weak)
  if id=="hexbound_ritual"or boss_credit[token]then return end;boss_credit[token]=true
  local e=boss_kills[id]or {label=boss_label(id),count=0};boss_kills[id]=e;e.personal=(e.personal or 0)+1
  if weak then e.personal_weakened=(e.personal_weakened or 0)+1 end
 end
 for _,e in rows(ds.AttackReportManager)do step()
  local target,attacker=e.attacked_unit_uuid,e.attacking_unit_uuid
  local result,amount,attack,profile=e.attack_result,e.damage,e.attack_type,e.damage_profile_name
  local at=ms(e.time)
  local _,ab=enemy(attacker)
  if ab and (attack=="melee"or attack=="ranged")and kind_of(ab)~="boss"then last_attack[attacker]=attack end
  local s,b,unknown=enemy(target)
  local unit=s and target or nil
  local id,class,personal=member(attacker)
  -- the player's own kill credit: every kill reported, damage or not, once a target
  if result=="died"and mine[attacker]and (s or unknown)and not (unit and credited[unit])then
   if unit then credited[unit]=true end
   run.kills=run.kills+1
   if b then local k=kind_of(b);local cat=k=="horde"and (Grouping.trash_ranged(b.name,b.ranged,last_attack[unit])and "horde_ranged"or "horde_melee")or k
    run.kill_categories=run.kill_categories or {};run.kill_categories[cat]=(run.kill_categories[cat]or 0)+1
    if k=="boss"then local bid=boss_id(b,profile);if bid and bid~="hexbound_ritual"then personal_boss(bid,unit,weakened(s,b))end end
   end
   Team.kill(team,own_id,at)
  end
  if (s or unknown)and type(amount)=="number"and amount==amount and amount>0 and amount<math.huge then
   local armour=b and b.armor_type or "unknown"
   if b and result=="toughness_absorbed"then armour="void_shield"end
   if unit and not seeded[unit]then seeded[unit]=true;Team.seed(team,unit,nil,s.max_health)end
   local category=DOT[profile]or attack or "unknown"
   local kind=b and kind_of(b)
   if id then
    if result=="died"then
     if not unit then
      if Party.kill(party,{actor=id,class=class,personal=personal,target={}})and not personal then Team.kill(team,id,at)end
     elseif b then
      local k=kind;if k=="horde"then k=Grouping.trash_ranged(b.name,b.ranged,last_attack[unit])and "horde_ranged"or "horde_melee"end
      local group=group_of(b);local enemy_id,enemy_label=b.name,label(b.name)
      if group=="boss"then local bid=boss_id(b,profile);if bid and bid~="hexbound_ritual"and bid~="hexbound_daemonhost"then enemy_id,enemy_label=bid,boss_label(bid)end end
      if Party.kill(party,{actor=id,class=class,personal=personal,target=unit,kind=k,
       fixed_kind=group=="normal"and (b.ranged and "trash_fixed_ranged"or "trash_fixed_melee")or group=="elite"and (b.ranged and "elite_ranged"or "elite_melee")or nil,
       enemy=enemy_id,label=enemy_label,group=group,subgroup=Grouping.classify(enemy_id,group,b.ranged,last_attack[unit])})and not personal then Team.kill(team,id,at)end
     end
    end
    Party.hit(party,{actor=id,class=class,personal=personal,target=unit,damage=amount,category=category,armour=armour,enemy=b and label(b.name)or "Unknown Enemy"})
   end
   local r=Team.hit(team,{target=unit,actor=id,class=class,personal=personal,boss=kind=="boss",kind=kind,profile=profile or "unknown",
    enemy=b and label(b.name)or "Unknown Enemy",armour=armour,category=category,damage=amount,result=result,maximum=s and s.max_health,
    weakspot=unit~=nil and e.hit_weakspot==true,critical=unit~=nil and e.is_critical_strike==true,at=at})
   -- the player's own hits as their weapon tally keeps them, reported damage against the health the squad tally had left
   if personal and armour~="void_shield"then
    local budget=r and r.health_before
    local dot=DOT[profile];local groups={"total",dot and "dot"or attack=="melee"and "melee"or "ranged"}
    if dot then groups[#groups+1]="dot_"..dot:lower()end
    for _,g in ipairs(groups)do damage[g]=damage[g]or {};add_damage(damage[g],armour,amount,budget)end
    if not dot and (attack=="melee"or attack=="ranged")then
     damage.weapons=damage.weapons or {};local w=damage.weapons[attack]or {};damage.weapons[attack]=w;w.unknown=w.unknown or {}
     add_damage(w.unknown,armour,amount,budget)
    end
   end
  end
  -- who dealt a boss its killing blow
  if result=="died"and id and b and kind_of(b)=="boss"and unit and not boss_blow[unit]then
   local bid=boss_id(b,profile)
   if bid and bid~="hexbound_ritual"and not (b.name=="chaos_mutator_daemonhost"and profile=="default")then
    boss_blow[unit]=true
    local weak=weakened(s,b);local kind=weak and "weakened"or "real"
    local row=boss_operatives[id]or {class=class,personal=personal,total=0,real=0,weakened=0};boss_operatives[id]=row
    row.total=row.total+1;row[kind]=row[kind]+1
    mark_reached(boss_operatives,row,"total");mark_reached(boss_operatives,row,kind)
    if personal then personal_boss(bid,unit,weak)end
   end
  end
 end
 -- every boss the client saw die, from the deaths Power DI kept
 local dead={}
 for _,e in rows(ds.MinionDeathManager)do step()
  local u=e.unit_uuid;local s,b=enemy(u)
  if s and b and kind_of(b)=="boss"and not dead[u]then dead[u]=true
   local bid=boss_id(b,e.damage_profile_name)
   if bid then local entry=boss_kills[bid]or {label=boss_label(bid),count=0};boss_kills[bid]=entry;entry.count=entry.count+1
    if weakened(s,b)then entry.weakened=(entry.weakened or 0)+1 end end
  end
 end
 local operatives=boss_operatives
 if next(boss_kills)then run.boss_kills=boss_kills end
 if next(operatives)then run.boss_operatives=operatives end
 run.team_damage=Team.results(team)
 run.party_records,run.enemy_kill_counts=Party.export(party)
 if damage.total then run.damage=damage end
 team,party=nil,nil

 -- downs, deaths, pickups and friendly fire: player states, interactions and the hits on players, in time order
 local events={}
 for i,e in rows(ds.PlayerUnitStatus)do if type(e.time)=="number"then events[#events+1]={e.time,0,i,e}end end
 local function pinner(u)local s=u and spawns[u];return type(s)=="table"and s.unit_template_name=="minion"and PINNER[s.unit_name]or nil end
 for i,e in rows(ds.AttackReportManager)do local t=e.attacked_unit_uuid
  if type(e.time)=="number"and (profiles[t]or e.attack_result=="died"and (t==nil or pinner(t)))then events[#events+1]={e.time,1,i,e}end
 end
 for i,e in rows(ds.InteracteeSystem)do if type(e.time)=="number"and (e.event=="interaction_started"or e.event=="interaction_stopped")then events[#events+1]={e.time,2,i,e}end end
 for i,e in rows(ds.MinionDeathManager)do if type(e.time)=="number"and pinner(e.unit_uuid)then events[#events+1]={e.time,3,i,e}end end
 table.sort(events,function(a,b)if a[1]~=b[1]then return a[1]<b[1]end;if a[2]~=b[2]then return a[2]<b[2]end;return a[3]<b[3]end)
 local stats=run.incidents
 local states,transitions,sources,env,fatal_hits,helpers,picked={},{},{},{},{},{},{}
 local lethality,active={},{}
 local ff_pairs,pickup_pairs,pickup_states,support={},{},{},{}
 local clock=0
 local function incident(event,personal,id,class)
  local field=INCIDENT[event];stats.team[field]=(stats.team[field]or 0)+1
  if event=="pickup"and not personal and not id then stats.unattributed_pickups=(stats.unattributed_pickups or 0)+1 end
  if personal then stats.personal[field]=(stats.personal[field]or 0)+1;if event=="died"then run.failed.died=true;run.failed.knocked_down=true end
  elseif id then local p=stats.members[id]or {class=class,counts={}};stats.members[id]=p;p.counts[field]=(p.counts[field]or 0)+1;p.class=class or p.class;mark_reached(stats.members,p,field)end
 end
 local function lethality_state(victim,class,personal,state,list_,replace,at)
  local index=active[victim];local e=index and lethality[index]
  if not e then e={victim=victim,class=class,personal=personal,outcome=state=="knocked_down"and "down"or "direct_death",sources=copy(list_ or {})};lethality[#lethality+1]=e;active[victim]=#lethality
  elseif state~="knocked_down"and e.outcome=="down"then e.outcome="down_to_death"end
  e.class=class or e.class
  if type(at)=="number"then e.at=e.at or at;if state~="knocked_down"then e.died_at=e.died_at or at end end
  if replace then for i=#e.sources,1,-1 do if e.sources[i].group~="environment"then table.remove(e.sources,i)end end end
  if #e.sources==0 and list_ and #list_>0 then e.sources=copy(list_)end
  if list_ and #list_>0 and list_[1].enemy~="unknown_cause"then for i=#e.sources,1,-1 do if e.sources[i].enemy=="unknown_cause"then table.remove(e.sources,i)end end end
  for _,source in ipairs(list_ or {})do local found=source.enemy=="unknown_cause"and #e.sources>0;for _,old in ipairs(e.sources)do if old.enemy==source.enemy then found=true end end;if not found then e.sources[#e.sources+1]=copy(source)end end
 end
 local function incapacitated(id,class,personal,state)
  local source=sources[id];local out={}
  if source and (source.counted or source.deadline>=clock)then source.counted=true
   out[#out+1]={enemy=source.enemy,label=source.label,group=source.group,horde_type=source.horde_type,attack_type=source.attack_type,subgroup=source.subgroup,attack_inferred=source.attack_inferred}end
  local en=env[id];if en and (en.counted or en.deadline>=clock)then en.counted=true;out[#out+1]={enemy=en.enemy,label=en.label,group="environment"}end
  if #out==0 then out={{enemy="unknown_cause",label="Unknown cause",group="unknown"}}end
  lethality_state(id,class,personal,state or "knocked_down",out,false,ms(clock))
 end
 local function just_down(id)
  local t,st=transitions[id],states[id]
  return t and clock-t.at<=.25 and t.previous~="dead"and (st=="knocked_down"or st=="dead")and st or nil
 end
 local function supporter(id)
  local r=support[id];if not r then r={revives=0,saves=0,blocked=0,coherency=0,tracked=0,blitzes=0,abilities=0};support[id]=r end
  return r
 end
 local function bump(u,field)local id=member(u);if id then local r=supporter(id);r[field]=r[field]+1 end end
 -- a kill of the enemy pinning a teammate, while it pins or just after, is a save for the killer, as live I/O counts it. The enemy is the one
 -- of the pinning kind seen hitting that teammate as the pin began or during it, or any of that kind where none was seen.
 local pins,hits,saved,fallen,blind={},{},{},{},{}
 local function pin_of(unit)
  local state=pinner(unit);if not state or saved[unit]then return end
  local guess,gid
  for vid,p in pairs(pins)do if p.state==state and not p.done and (not p.stop or clock-p.stop<=1.5)then
   if p.units[unit]then return p,vid end
   if not next(p.units)and (not guess or p.start<guess.start)then guess,gid=p,vid end
  end end
  return guess,gid
 end
 -- a kill naming no enemy is kept for a pinning enemy that dies with no report of its own
 local function pin_kill(unit,attacker)
  if unit==nil then if attacker then blind[#blind+1]={attacker=attacker,at=clock}end;return end
  local p,vid=pin_of(unit);if not p then return end
  p.done=true;saved[unit]=true
  if attacker and member(attacker)~=vid then bump(attacker,"saves")end
 end
 -- a blast a player set off that downs or kills: their own is a suicide, a teammate's that kills is a murder
 local blasts={}
 local function blast_outcome(victim,state)
  local b=blasts[victim];if not b or b.counted or b.deadline<clock then return end
  local outcome=b.self and DOWNED[state]and "suicides"or not b.self and (state=="dead"or state=="hogtied")and "murders"
  if not outcome then return end
  b.counted=true;incident(outcome,b.personal,not b.personal and b.id or nil,b.class)
  ff_pairs[b.id]=ff_pairs[b.id]or {};local row=ff_pairs[b.id][victim]or {damage=0,murders=0,suicides=0};ff_pairs[b.id][victim]=row;row[outcome]=row[outcome]+1
 end
 for _,ev in ipairs(events)do step()
  local kind,e=ev[2],ev[4];clock=ev[1]
  if kind==1 then
   local victim=member(e.attacked_unit_uuid)
   if not victim then pin_kill(e.attacked_unit_uuid,e.attacking_unit_uuid)
   else
    local attacker=e.attacking_unit_uuid;local id,class,personal=member(attacker)
    local amount=e.damage;local result=e.attack_result;local name=e.damage_profile_name or ""
    local _,b=enemy(attacker);local s=attacker and spawns[attacker]
    if not (type(s)=="table"and s.unit_template_name=="minion")then b=nil end
    if b and PINNER[b.name]then hits[victim]=hits[victim]or {};hits[victim][attacker]=clock;local p=pins[victim];if p and not p.stop and p.state==PINNER[b.name]then p.units[attacker]=true end end
    local fatal=result=="knock_down"or result=="died"
    local landed=result=="toughness_absorbed"or result=="toughness_absorbed_melee"or result=="toughness_broken"
    local fall=name:find("fall",1,true)or name:find("kill_volume",1,true)or name=="default"and not id and fatal
    if result=="blocked"then bump(e.attacked_unit_uuid,"blocked")end
    if b and (type(amount)=="number"and amount>0 or fatal or landed)then
     if fatal then fatal_hits[victim]=clock end
     local previous=sources[victim]
     if not (previous and previous.counted)then
      if CAPTAINS[b.name]then sources[victim]=nil
      else
       local group=group_of(b);local saved={enemy=b.name,label=label(b.name),group=group,horde_type=b.ranged and "ranged"or "melee",deadline=clock+10}
       if group~="boss"and group~="elite"then saved.attack_type=(e.attack_type=="melee"or e.attack_type=="ranged")and e.attack_type or nil end
       saved.subgroup=Grouping.classify(b.name,group,b.ranged,saved.attack_type)
       saved.attack_inferred=group=="normal"and (b.name=="cultist_assault"or b.name=="renegade_assault"or b.name=="renegade_rifleman")and not saved.attack_type or nil
       sources[victim]=saved
      end
     end
    elseif fatal and not fall and (id or name~="knocked_down_tick")then
     sources[victim]=id and id~=victim and not BLAST[name]and not BARREL[name]and {enemy="teammate",label="Teammate",group="environment",deadline=clock+10}or nil
    end
    if BARREL[name]then env[victim]={enemy="barrels",label="Barrels",deadline=clock+10}end
    local from=not b and not id and UNOWNED[name]
    if from and HAZARD[from]and (fatal or (landed or type(amount)=="number"and amount>0)and just_down(victim))then env[victim]={enemy=HAZARD[from].enemy,label=HAZARD[from].label,deadline=clock+2}
    elseif from and not HAZARD[from]and (fatal or landed or type(amount)=="number"and amount>0)then local previous=sources[victim]
     if not (previous and previous.counted)then local group=from=="renegade_wizard"and "boss"or "special"
      sources[victim]={enemy=from,label=label(from),group=group,subgroup=Grouping.classify(from,group,from=="renegade_netgunner",nil),deadline=clock+10}end
    end
    if (name:find("kill_volume",1,true)or name:find("damage_volume_instakill",1,true)or name:find("fall",1,true))and not b and not (env[victim]and env[victim].deadline>=clock)then env[victim]={enemy="falls",label="Falls",deadline=clock+10}end
    if name:find("poxwalker_explosion",1,true)and not (sources[victim]and sources[victim].counted)then sources[victim]={enemy="chaos_poxwalker_bomber",label=label("chaos_poxwalker_bomber"),group="special",deadline=clock+10}end
    local _,vclass,vpersonal=member(e.attacked_unit_uuid)
    -- the hit that downs arrives a moment after the down; a cause that soon names a down still unknown
    if fatal or b or from then local st=just_down(victim);local i=st and active[victim];local le=i and lethality[i]
     if le then for _,src in ipairs(le.sources)do if src.enemy=="unknown_cause"then incapacitated(victim,vclass,vpersonal,st);break end end end end
    if result=="died"then incapacitated(victim,vclass,vpersonal,"dead")end
    local self_barrel=id and id==victim and BARREL[name]
    if id and type(amount)=="number"and amount>0 and (id~=victim or self_barrel)then
     local source=name=="liquid_area_fire_burning_barrel"and "barrel_fire"or BARREL[name]and "barrel_explosion"or "other"
     stats.team.friendly_fire=(stats.team.friendly_fire or 0)+amount
     if personal then stats.personal.friendly_fire=(stats.personal.friendly_fire or 0)+amount
     else local p=stats.members[id]or {class=class,counts={}};stats.members[id]=p;p.class=class or p.class;p.counts.friendly_fire=(p.counts.friendly_fire or 0)+amount;mark_reached(stats.members,p,"friendly_fire")end
     ff_pairs[id]=ff_pairs[id]or {};local row=ff_pairs[id][victim]or {damage=0,murders=0,suicides=0};ff_pairs[id][victim]=row
     row.damage=row.damage+amount;row.damage_sources=row.damage_sources or {version=1};row.damage_sources[source]=(row.damage_sources[source]or 0)+amount
    end
    if id and (BLAST[name]or name=="liquid_area_fire_burning_barrel")and (id~=victim or self_barrel)then
     local old=blasts[victim]
     if not (old and old.counted and DOWNED[states[victim]])then blasts[victim]={id=id,class=class,personal=personal,self=id==victim,deadline=clock+10}end
    end
    if result=="died"then blast_outcome(victim,"dead")end
   end
  elseif kind==3 then
   local p,vid=pin_of(e.unit_uuid);if p then fallen[#fallen+1]={unit=e.unit_uuid,pin=p,victim=vid,at=clock}end
  elseif kind==2 then
   local victim=member(e.interactee_unit_uuid)
   if e.event=="interaction_started"and victim and (e.interaction_type=="revive"or e.interaction_type=="rescue")then
    local actor=e.interactor_unit_uuid;local old=helpers[victim]
    if old and old.deadline>clock and old.actor~=actor then helpers[victim]={ambiguous=true,deadline=clock+4}else helpers[victim]={actor=actor,deadline=clock+4}end
   elseif e.event=="interaction_stopped"and e.result=="success"and SAVES[e.interaction_type]and e.interactor_unit_uuid~=e.interactee_unit_uuid then
    bump(e.interactor_unit_uuid,SAVES[e.interaction_type])
   end
  else
   local u=e.player_unit_uuid;local id,class,personal=member(u);local state=e.state_name
   if id and state and states[id]~=state then
    local previous=states[id];states[id]=state;transitions[id]={previous=previous,at=clock}
    if (DOWNED[previous]or previous==nil and active[id])and STANDING[state]then sources[id]=nil;env[id]=nil;active[id]=nil;blasts[id]=nil end
    if state=="knocked_down"or state=="hogtied"then picked[id]=nil;helpers[id]=nil end
    if PINNED[previous]and pins[id]then pins[id].stop=clock end
    if PINNED[state]then local p={state=state,start=clock,units={}};pins[id]=p
     for unit,t in pairs(hits[id]or {})do if t>=clock-1 and pinner(unit)==state then p.units[unit]=true end end
    end
    blast_outcome(id,state)
    local event=STATE_EVENT[state]
    local seen=previous~=nil or from_start
    if state=="dead"and (previous=="falling"or previous=="ledge_hanging_falling"or previous=="catapulted")and not (fatal_hits[id]and clock-fatal_hits[id]<=1)then
     if not (env[id]and env[id].deadline>=clock)then env[id]={enemy="falls",label="Falls",deadline=clock+10}end
    end
    if (state=="knocked_down"or state=="dead")and seen then incapacitated(id,class,personal,state)end
    if event and event~=STATE_EVENT[previous]and seen then
     if personal and event~="died"then run.failed[event]=true end
     incident(event,personal,not personal and id or nil,class)
    end
    -- a pickup: who revived or rescued them, a bot's crediting nobody
    if (previous=="knocked_down"or previous=="hogtied")and UP[state]then
     local pending=helpers[id];local actor=pending and pending.deadline>=clock and not pending.ambiguous and pending.actor
     local aid,aclass,apersonal=member(actor)
     if not picked[id]then incident("pickup",false,nil);picked[id]=true end
     if aid then active[id]=nil
      stats.unattributed_pickups=math.max(0,(stats.unattributed_pickups or 0)-1)
      if apersonal then stats.personal.pickups=(stats.personal.pickups or 0)+1
      else local p=stats.members[aid]or {class=aclass,counts={}};stats.members[aid]=p;p.counts.pickups=(p.counts.pickups or 0)+1;mark_reached(stats.members,p,"pickups")end
      pickup_pairs[aid]=pickup_pairs[aid]or {};pickup_pairs[aid][id]=(pickup_pairs[aid][id]or 0)+1
      pickup_states[aid]=pickup_states[aid]or {};local row=pickup_states[aid][id]or {};pickup_states[aid][id]=row;row[previous]=(row[previous]or 0)+1
     elseif actor and is_player(actor)then active[id]=nil
      stats.unattributed_pickups=math.max(0,(stats.unattributed_pickups or 0)-1);stats.bot_pickups=(stats.bot_pickups or 0)+1
     end
    end
   end
  end
 end
 events=nil
 -- a pinning enemy that died with no report naming it goes to the one player whose kills named no enemy around then
 for _,f in ipairs(fallen)do if not saved[f.unit]and not f.pin.done then
  local who;for _,k in ipairs(blind)do if not k.used and math.abs(k.at-f.at)<=1 then if who==nil then who=k.attacker elseif who~=k.attacker then who=false end end end
  if who and member(who)~=f.victim then
   for _,k in ipairs(blind)do if not k.used and k.attacker==who and math.abs(k.at-f.at)<=1 then k.used=true;break end end
   f.pin.done=true;saved[f.unit]=true;bump(who,"saves")
  end
 end end
 for _,e in ipairs(lethality)do e.sources=e.sources or {}end
 if #lethality>0 then run.lethality_events=lethality end
 if next(ff_pairs)then run.friendly_fire_pairs=ff_pairs end
 if next(pickup_pairs)then run.pickup_pairs=pickup_pairs;run.pickup_states=pickup_states end

 -- the Support page: blitzes and abilities from charges spent, time alive and in coherency from the coherency reports
 for _,e in rows(ds.PlayerAbilities)do step()
  if type(e.charge_delta)=="number"and e.charge_delta<0 then
   if e.ability_type=="combat_ability"then bump(e.player_unit_uuid,"abilities")elseif e.ability_type=="grenade_ability"then bump(e.player_unit_uuid,"blitzes")end
  end
 end
 local last=0
 for _,e in rows(ds.PlayerUnitStatus)do if type(e.time)=="number"and e.time>last then last=e.time end end
 for _,e in rows(ds.AttackReportManager)do if type(e.time)=="number"and e.time>last then last=e.time end end
 -- a unit lives from its spawn to its death or the same character's next spawn; Power DI writes no coherency exit for a unit that dies.
 -- On a late join or a rejoin Power DI gives every teammate already there spawn time 0, a unit a rejoin left behind included, so a unit is
 -- counted from its own first row in any datasource, the player's own spawn at the earliest, and one with no rows not at all.
 local alive,born,ends,open,spans={},{},{},{},{}
 local first,final
 local function scan_rows()first,final={},{};local ours={};for u in pairs(profiles)do if member(u)then ours[u]=true end end
  for _,source in pairs(ds)do for _,e in rows(source)do step();local t=e.time
   if type(t)=="number"and t<=86400 then for _,f in ipairs(UNIT_FIELDS)do local u=e[f]
    if u~=nil and ours[u]then if first[u]==nil or t<first[u]then first[u]=t end;if final[u]==nil or t>final[u]then final[u]=t end end
   end end
  end end
 end
 if not full then scan_rows()end
 for u in pairs(profiles)do local s=spawns[u];if member(u)and type(s)=="table"and type(s.time)=="number"then
  if full then born[u]=s.time elseif first[u]then born[u]=math.max(s.time,spawn_at or s.time,first[u])end
 end end
 for _,e in rows(ds.PlayerUnitStatus)do local u=e.player_unit_uuid
  if born[u]and e.state_name=="dead"and type(e.time)=="number"and e.time>=born[u]and (ends[u]==nil or e.time<ends[u])then ends[u]=e.time end
 end
 -- two units of one character that still start together: the one whose rows end first ends at its last row
 local function earlier(u,v)local a,b=final[u]or born[u],final[v]or born[v];if a~=b then return a<b end;return tostring(u)<tostring(v)end
 local lives={}
 for u,t in pairs(born)do local id=member(u);local stop=math.min(ends[u]or last,last)
  for v,t2 in pairs(born)do if v~=u and member(v)==id then
   if t2>t and t2<stop then stop=t2
   elseif t2==t then if not final then scan_rows()end;if earlier(u,v)then stop=math.min(stop,final[u]or t)end end
  end end
  ends[u]=math.max(t,stop);lives[id]=lives[id]or {};lives[id][#lives[id]+1]={t,ends[u]}
 end
 -- a character's time alive is the union of its units' lives, less the time the player was away
 for id,list_ in pairs(lives)do table.sort(list_,function(x,y)return x[1]<y[1]end)
  local total,a,b=0,nil,nil
  for _,s in ipairs(list_)do if a==nil or s[1]>b then if a then total=total+b-a-gone(a,b)end;a,b=s[1],s[2]else b=math.max(b,s[2])end end
  if a then total=total+b-a-gone(a,b)end;alive[id]=total
 end
 local function close(u,o,t)local a=open[u]and open[u][o];if not a then return end;open[u][o]=nil
  local b=math.min(t,ends[u]or last,ends[o]or last);if b>a then local id=member(u);spans[id]=spans[id]or {};spans[id][#spans[id]+1]={a,b}end
 end
 for _,e in rows(ds.HuskCoherencyExtension)do step()
  local u,o=e.player_unit_uuid,e.coherency_player_unit_uuid
  if member(u)and o and o~=u and type(e.time)=="number"then
   if e.event=="enter"then open[u]=open[u]or {};open[u][o]=open[u][o]or e.time elseif e.event=="exit"then close(u,o,e.time)end
  end
 end
 for u,partners in pairs(open)do for o in pairs(partners)do close(u,o,last)end end
 -- a character's time in coherency is the union of its units' spans, so two partners at once count once, less the time the player was away
 for id,list_ in pairs(spans)do table.sort(list_,function(x,y)return x[1]<y[1]end)
  local total,a,b=0,nil,nil
  for _,s in ipairs(list_)do if a==nil or s[1]>b then if a then total=total+b-a-gone(a,b)end;a,b=s[1],s[2]else b=math.max(b,s[2])end end
  if a then total=total+b-a-gone(a,b)end;supporter(id).coherency=total
 end
 for id,r in pairs(support)do r.tracked=alive[id]or 0;r.coherency=math.min(r.coherency,r.tracked)end
 if next(support)then run.support=support end
 return run
end

return Convert
