-- Count only dedicated execution reports with a verified Haymaker buff.
local H={}
local prefixes={"weapon_trait_bespoke_ogryn_club_p2","weapon_trait_bespoke_combatknife_p1","weapon_trait_bespoke_dual_shivs_p1"}
local templates={}
for i=1,#prefixes do
 templates[2*i-1]=prefixes[i].."_heavy_chained_hits_increases_killing_blow_chance_parent"
 templates[2*i]=prefixes[i].."_heavy_chained_hits_increases_killing_blow_chance_child"
end
function H.equipped(buff)
 if not buff or type(buff.has_buff_using_buff_template)~="function"then return false end
 for i=1,6 do
  if buff:has_buff_using_buff_template(templates[i])then return true end
 end
 return false
end
function H.signature(profile,result,kind)
 return profile and profile.name=="killing_blow"and result=="died"and kind=="melee"
end
function H.record(m,id,personal,measurement)
 m.haymaker=m.haymaker or {};local row=m.haymaker[id]
 if not row then row={selected=true,kills=0,personal=personal==true};m.haymaker[id]=row end
 row.kills=row.kills+1;H.contribution(row,measurement)
end

function H.contribution(row,measurement)
 if measurement and measurement.health_known and type(measurement.useful)=="number"and measurement.useful>0 then
  row.execution_damage=(row.execution_damage or 0)+measurement.useful
  row.damage_kills=(row.damage_kills or 0)+1
 end
end
function H.lines(run,id)
 local row=run and run.haymaker and run.haymaker[id]
 if row and row.selected and (row.kills or 0)>0 then
  local out={"Haymaker Kills: "..row.kills}
  -- Do not present a partially observed sum as the complete contribution.
  if row.damage_kills==row.kills and (row.execution_damage or 0)>0 then out[#out+1]="Haymaker Execution Damage: "..string.format("%.1f",row.execution_damage):gsub("%.0$","")end
  return out
 end
 return {}
end
return H
