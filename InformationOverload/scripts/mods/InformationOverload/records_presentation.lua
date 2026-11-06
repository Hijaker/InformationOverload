-- Records presentation/query methods.
return function(Records)
function Records.run_damage_info(run)
 local mt=getmetatable(run)
 if mt and mt.io_damage_total~=nil and rawget(run,"damage")==nil and rawget(run,"team_damage")==nil then
  return mt.io_damage_total,mt.io_team_damage_total,mt.io_damage_reported
 end
 local data=rawget(run,"team_damage");local own,team,found=0,0,false
 local character=tostring(run.context and run.context.character)
 for id,member in pairs(data and data.members or {})do if id~="unknown_operative"then
  local total=0;for _,groups in pairs(member.groups or {})do for armour,bucket in pairs(groups)do
   if armour~="void_shield"then total=total+(bucket.reported or 0)end
  end end
  team=team+total
  if member.personal==true or tostring(id)==character then own=own+total;found=true end
 end end
 if found then return own,team,own end
 local total=rawget(run,"damage");total=total and total.total;local damage=total and total.all
 return damage and math.max(0,(damage.total or 0)-(total.void_shield and total.void_shield.total or 0))or 0,nil,damage and damage.total
end
function Records.run_damage_total(run)local total=Records.run_damage_info(run);return total end
-- the player's own useful damage, then the squad's, shields left out; the player's is nil for a run with no squad tally, and a saved run keeps both resident
function Records.run_useful(run)
 local mt=getmetatable(run)
 if mt and mt.io_damage_useful~=nil and rawget(run,"team_damage")==nil then return mt.io_damage_useful or nil,mt.io_team_damage_useful or nil end
 local data=rawget(run,"team_damage");if type(data)~="table"then return nil end
 local character,own,team,found=tostring(run.context and run.context.character),0,0,false
 for id,member in pairs(data.members or {})do if id~="unknown_operative"then
  local sum=0;for _,groups in pairs(member.groups or {})do for armour,bucket in pairs(groups)do if armour~="void_shield"then sum=sum+(bucket.useful or 0)end end end
  team=team+sum;if member.personal==true or tostring(id)==character then own=own+sum;found=true end
 end end
 return found and own or nil,team
end
-- the player's own damage over a whole mission as the pages show it: useful damage, overkill left out; a match saved before squad damage was
-- kept has no useful figure and keeps the damage its weapon hits recorded, the second value saying so; nil for a match with neither
function Records.run_mission_damage(run)
 local useful=Records.run_useful(run);if useful then return useful,false end
 local own,_,reported=Records.run_damage_info(run);if reported~=nil then return own,true end
end

function Records:run_mission_name(c)
    if c.psykhanium_log and c.mission_display_name then return c.mission_display_name end
    if Records.mission_display_name and c.mission_name then local label=Records.mission_display_name(c.mission_name);if label and label~="Unknown mission" then return label end end
    local label=c.mission_display_name
    if type(label)=="string" and label~="" and not label:find("<unlocalized",1,true) and not label:match("^[%w]+_[%w_]+$") then return label end
    return "Unknown mission"
end

end
