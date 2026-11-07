local B={}
B.captains={renegade_captain=true,cultist_captain=true}
B.monsters={chaos_spawn=true,chaos_beast_of_nurgle=true,chaos_plague_ogryn=true}
local function weakened_monster(unit,breed,extension)
 if breed.ignore_weakened_boss_name then return false end
 local boss=extension(unit,"boss_system")
 if boss and type(boss.is_weakened)=="function" and boss:is_weakened()==true then return true end

 local state=Managers and Managers.state
 local game_mode_manager=state and state.game_mode
 local game_mode=game_mode_manager and game_mode_manager:game_mode()
 local havoc=game_mode and game_mode:extension("havoc")
 local difficulty=state and state.difficulty
 if not havoc or not difficulty then return false end

 local modifier=havoc:get_modifier_value("modify_monster_health")
 local health=extension(unit,"health_system")
 local max_health=health and health:max_health()
 if type(modifier)~="number" or type(max_health)~="number" or max_health<=0 then return false end

 -- The base boss flag omits the Havoc HP bonus. Use the HUD's Havoc baseline.
 local base_health=difficulty:get_minion_max_health(breed.name)
 if type(base_health)~="number" or base_health<=0 then return false end
 return math.floor(max_health)<math.floor(base_health*(1+modifier)+0.000001)
end
function B.captain_weapon(slots,wielded)
 local hammer=slots and slots.slot_powermaul~=nil
 local sword=slots and slots.slot_power_sword~=nil
 if hammer and not sword then return "hammer_captain","Hammer-captain" end
 if sword and not hammer then return "sword_captain","Sword-captain" end
 if wielded=="slot_powermaul" then return "hammer_captain","Hammer-captain" end
 if wielded=="slot_power_sword" then return "sword_captain","Sword-captain" end
end
function B.identify(unit,breed,extension)
 if not breed then return end
 local id=breed.name
 if B.captains[id] then
  local loadout=extension(unit,"visual_loadout_system")
  local slots=loadout and type(loadout.inventory_slots)=="function" and loadout:inventory_slots()
  local wielded=loadout and type(loadout.wielded_slot_name)=="function" and loadout:wielded_slot_name()
  return B.captain_weapon(slots,wielded)
 end
 local weakened=B.monsters[id] and weakened_monster(unit,breed,extension) or false
 return id,nil,weakened
end
return B
