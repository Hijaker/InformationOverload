-- Display-only denominators from the same accepted Match History scope.
local S={}
local I=get_mod("information_overload"):io_dofile("InformationOverload/scripts/mods/InformationOverload/player_identity")
local cache=setmetatable({},{__mode="k"})
function S.get(tracker,patch,mode,player)
 local data=tracker.data;local revision=tostring(data.run_sequence)..":"..tostring(data.history_policy_revision)..":"..tostring(#(data.run_history or {}))
 local c=cache[tracker];if not c or c.revision~=revision or c.data~=data then c={revision=revision,data=data,values={}};cache[tracker]=c end
 local key=tostring(patch)..":"..tostring(mode)..":"..tostring(player or "personal")
 if c.values[key]then return c.values[key]end
 local total={downs=0,deaths=0};local measured=false;if player then I.learn(data)end
 for _,run in ipairs(data.run_history or {})do local ctx=run.context
  if ctx and ctx.patch==patch and ctx.mode==mode and not run.stats_excluded and not run.data_only and type(run.victory)=="boolean"and run.incidents then
   local counts=tracker.incident_counts(run)
   if not player then
    local own=counts.personal;if own then measured=true;total.downs=total.downs+(own.downs or 0);total.deaths=total.deaths+(own.deaths or 0)end
   else
    local victims={}
    for id,p in pairs(ctx.operative_roster or {})do if I.matches(p,player)then victims[id]=true end end
    for _,p in pairs(run.operative_clutches or {})do if I.matches(p,player)and p.character_id then victims[p.character_id]=true end end
    for id in pairs(victims)do local member=counts.members and counts.members[id];local own=member and member.counts
     if own then measured=true;total.downs=total.downs+(own.downs or 0);total.deaths=total.deaths+(own.deaths or 0)end
    end
   end
  end
 end
 total.total=total.downs+total.deaths;total.measured=measured;c.values[key]=total;return total
end
function S.line(label,value,total)
 local text=label..": "..tostring(value or "Not recorded")
 if type(value)=="number"and type(total)=="number"and total>0 then
  text=text.." - "..string.format("%.1f",100*value/total):gsub("%.0$","").."%"
 end
 return text
end
return S
