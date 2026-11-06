local B={}
B.captains={renegade_captain=true,cultist_captain=true}
B.monsters={chaos_spawn=true,chaos_beast_of_nurgle=true,chaos_plague_ogryn=true}
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
 local boss=extension(unit,"boss_system")
 local weakened=B.monsters[id] and boss and type(boss.is_weakened)=="function" and boss:is_weakened()==true or false
 return id,nil,weakened
end
return B
