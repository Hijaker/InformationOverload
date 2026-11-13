-- Existing saved kill counts; health samples come only from new observations.
local B={}
local mod=type(get_mod)=="function"and get_mod("information_overload")
local Party;local function enemy_kills(p)if not Party and mod and mod.io_dofile then Party=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/party_records")end;return Party and Party.kills(p)or p.enemy_kills or {}end
function B.build(runs,group,role,scope)
 local out={selected=0,games=0,health_games=0,health_merged_excluded=0,enemies={}}
 local function enemy(id,label)local e=out.enemies[id];if not e then e={label=label or "Unknown enemy",kills=0,health={},health_samples=0};out.enemies[id]=e end;return e end
 local function health(data)
  if data.segments then for _,segment in ipairs(data.segments)do health(segment)end;return end
  for id,e in pairs(data.enemies or {})do local row=enemy(id,e.label);for value,count in pairs(e.health or {})do row.health[value]=(row.health[value]or 0)+count;row.health_samples=row.health_samples+count end end
 end
 for _,run in ipairs(runs or {})do
  if type(run.victory)=="boolean"and not run.data_only and not run.discarded and not run.hidden_contributions and not run.stats_excluded then
   out.selected=out.selected+1
   local counts=run.enemy_kill_counts or run.party_records
   if counts then out.games=out.games+1
    for _,p in pairs(counts.members or {})do if scope~="personal"or p.personal then
     for _,k in pairs(enemy_kills(p))do local subgroup=tostring(k.subgroup or "");local ranged=subgroup=="ranged";local melee=subgroup=="melee"or subgroup=="bruiser"or subgroup=="horde"
      if (not group or group=="all"or k.group==group)and (not role or role=="all"or role=="ranged"and ranged or role=="melee"and melee)then
       local row=enemy(k.enemy,k.label);row.kills=row.kills+(k.count or 0)
      end
     end
    end end
   end
   if run.experimental and not run.experimental.segments then out.health_games=out.health_games+1;health(run.experimental)elseif run.experimental then out.health_merged_excluded=out.health_merged_excluded+1 end
  end
 end
 return out
end
function B.lines(data,single)
 local list={};for _,e in pairs(data.enemies)do if e.kills>0 then list[#list+1]=e end end
 table.sort(list,function(a,b)if a.kills~=b.kills then return a.kills>b.kills end;return a.label<b.label end)
 local lines={};for _,e in ipairs(list)do
  lines[#lines+1]=e.label..": "..(single and tostring(e.kills).." kills"or string.format("%.1f kills/game",e.kills/math.max(1,data.games)))
  local lo,hi;for value in pairs(e.health)do local n=tonumber(value);if n then lo=math.min(lo or n,n);hi=math.max(hi or n,n)end end
  lines[#lines+1]="Health: "..(lo and (lo==hi and string.format("%.0f",lo)or string.format("%.0f–%.0f",lo,hi))or "Not recorded").." · EHP: Not recorded"
 end
 if #lines==0 then lines[1]="Not recorded"end
 lines[#lines+1]="Kill coverage: "..data.games.."/"..data.selected.." selected games"
 lines[#lines+1]="Health: observed targets only; experimental"
 if data.health_merged_excluded>0 then lines[#lines+1]="Rejoined health samples excluded to avoid duplicates"end
 return lines
end
return B
