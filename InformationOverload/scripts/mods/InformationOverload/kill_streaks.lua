-- Kills Before Taking A Hit and Kills Before Losing Health form one feature.
-- Shared collection supplies observations; per-segment state is never module-global.
local Hit=(function()
-- Kills Before Taking A Hit: pure metric, with state owned by each timeline segment.
local H={field="streak",title="Kills Before Taking A Hit"}
H.tip={H.title,"Taking damage resets it, even a hit to Toughness alone.","A down, a death, a reconnect or a gap in observation resets it too.","Blocks and dodges do not."}
function H.new()
 return {current=0,best=0,resets=0,definition="local credited kills since positive incoming damage or absorbed/broken Toughness report; blocks/dodges excluded; down/death resets"}
end
function H.kill(segment)
 local s=segment[H.field];s.current=s.current+1;s.best=math.max(s.best,s.current)
end
function H.reset(segment)
 local s=segment[H.field];s.current=0;s.resets=s.resets+1
end
function H.best(run)
 local best
 for _,s in ipairs(run and run.combat_timeline and run.combat_timeline.segments or {})do best=math.max(best or 0,s[H.field].best or 0)end
 return best
end
-- Reconstruct from the existing shared chronology; health-only resets do not reset this metric.
function H.replay(segment)
 if not segment.streak_events then return nil end
 local current,best=0,0
 for _,e in ipairs(segment.streak_events)do
  if e[3]=="kill"then current=current+1;best=math.max(best,current)
  elseif e[3]=="reset"then current=0 end
 end
 return {current=current,best=best,complete=(segment.coverage.streak_events_dropped or 0)==0}
end
-- The caller supplies its selected accepted history, as before.
function H.best_by_map(runs,best_streak)
 local out={}
 for _,run in ipairs(runs or {})do
  if not run.discarded and not run.data_only and not run.stats_excluded and not run.hidden_contributions then
   local map=run.context and run.context.mission_name
   if map then
    local value=best_streak(run)
    if value~=nil then local row=out[map]or {best=0,recorded_matches=0};out[map]=row;row.best=math.max(row.best,value);row.recorded_matches=row.recorded_matches+1 end
   end
  end
 end
 return out
end
return H
end)()
local Health=(function()
-- Kills Before Losing Health: independent metric; old segments remain unrecorded.
local H={field="health_streak",title="Kills Before Losing Health"}
H.tip={H.title,"Health damage or corruption resets it; Toughness-only hits do not.","A down, a death, a reconnect or a gap in observation resets it too."}
function H.new()
 return {current=0,best=0,resets=0,definition="local credited kills since health damage or corruption increase; Toughness-only hits excluded; down/death resets"}
end
function H.kill(segment)
 local s=segment[H.field];if s then s.current=s.current+1;s.best=math.max(s.best,s.current)end
end
function H.reset(segment)
 local s=segment[H.field];if not s then return end
 s.current=0;s.resets=s.resets+1;return true
end
function H.resets_with_hit(cause)
 return cause=="knocked_down"or cause=="died"or cause=="observation_gap"
end
function H.best(run)
 local best
 for _,s in ipairs(run and run.combat_timeline and run.combat_timeline.segments or {})do
  if s[H.field]then best=math.max(best or 0,s[H.field].best or 0)end
 end
 return best
end
return H
end)()
local K={hit=Hit,health=Health}
K.install=function(mod,api,C,Timeline,timeline,local_unit)
    -- Authority setters catch each loss; clients observe replicated health changes.
    local function health_snapshot(health)
        local own=local_unit()
        if not own or health._unit~=own or not api.enabled()or not api.tracker().mission then return end
        return {damage=health:damage_taken(),permanent=health:permanent_damage_taken()}
    end
    local function health_changed(health,before)
        if before and (health:damage_taken()>before.damage or health:permanent_damage_taken()>before.permanent)then
            local data,t=timeline();if data then Timeline.reset_health(data,t,"health_loss")end
        end
    end
    local health_hook_failed=false
    local function health_contained(ok,value)
        if not ok and not health_hook_failed then health_hook_failed=true;mod:error("I/O collector health: %s",tostring(value))end
        if ok then return value end
    end
    for _,spec in ipairs({{"PlayerUnitHealthExtension","_set_damage"},{"PlayerUnitHealthExtension","_set_permanent_damage"},{"PlayerHuskHealthExtension","fixed_update"}})do
        mod:hook(spec[1],spec[2],function(func,health,...)
            local before=health_contained(pcall(health_snapshot,health))
            local result=func(health,...)
            health_contained(pcall(health_changed,health,before))
            return result
        end)
    end
end
return K
