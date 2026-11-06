-- Replicated Hyper-Critical execution reports use the default damage profile,
-- preserving the triggering melee critical flag. Ordinary weapon kills retain
-- their weapon damage profile; they must never be counted as executions.
local H={}
function H.selected(profile)
 local value=profile and profile.talents and profile.talents.broker_passive_melee_crit_instakill
 if type(value)=="table"then value=value.tier end
 if value==nil then return nil end
 return value==true or type(value)=="number"and value>0
end
function H.register(m,id,profile,personal)
 local selected=H.selected(profile);if selected==nil then return end
 m.hyper_critical=m.hyper_critical or {};local row=m.hyper_critical[id]
 if not row then row={selected=selected,kills=0,personal=personal==true};m.hyper_critical[id]=row end
 row.selected=row.selected or selected;return row
end
function H.signature(profile,result,attack_type,critical)
 return profile and profile.name=="default"and result=="died"and attack_type=="melee"and critical==true
end

function H.contribution(row,measurement)
 if measurement and measurement.health_known and type(measurement.useful)=="number"and measurement.useful>0 then
  row.execution_damage=(row.execution_damage or 0)+measurement.useful
  row.damage_kills=(row.damage_kills or 0)+1
 end
end
function H.lines(run,id)
 local row=run and run.hyper_critical and run.hyper_critical[id]
 if row and row.selected and (row.kills or 0)>0 then
  local out={"Hyper-Critical Kills: "..row.kills}
  -- Do not present a partially observed sum as the complete contribution.
  if row.damage_kills==row.kills and (row.execution_damage or 0)>0 then out[#out+1]="Hyper-Critical Execution Damage: "..string.format("%.1f",row.execution_damage):gsub("%.0$","")end
  return out
 end
 return {}
end
function H.summary(tracker,patch)
 local out={games=0,total=0,highest=0}
 for _,run in ipairs(tracker.data.run_history or {})do
  local c=run.context or {};local row=run.hyper_critical and run.hyper_critical[tostring(c.character)]
  if c.class=="broker"and (not patch or c.patch==patch)and not run.data_only and not run.hidden_contributions and not c.training_history_test and c.difficulty~="psykhanium"and type(run.victory)=="boolean"and row and row.selected then
   out.games=out.games+1;out.total=out.total+(row.kills or 0);out.highest=math.max(out.highest,row.kills or 0)
  end
 end
 out.average=out.games>0 and out.total/out.games or 0;return out
end
return H
