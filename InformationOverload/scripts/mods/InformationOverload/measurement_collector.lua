-- Always-on Peril and engagement distance, plus the existing normal BLO shot observer.
return function(mod,api,C,helpers)
 local E=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/mission_measurements")
 local Resource=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/resource_timeline")
 local defs=require("scripts/settings/damage/damage_settings")
 local mission,state,resources,previous,clock,accum=nil,nil,nil,{},nil,0
 local function active()
  if not api.enabled()then return end
  local m=api.tracker().mission;if not m or m.history_recorded then return end
  if m~=mission then
   mission=m;previous={};clock=nil;accum=0
   m.measurements=m.measurements or E.from_legacy(m.experimental)
   state=E.new(m.measurements);m.measurements=state.data
   resources=Resource.new(state.data.peril_timeline);state.data.peril_timeline=resources.data
   state.data.distance_definitions=state.data.distance_definitions or {close=defs.ranged_close,far=defs.ranged_far,comparison="distance < close",curve="sqrt(clamp((distance-close)/(far-close),0,1))",basis="resolved report positions; calculation input fallback separately labelled"}
   state.data.distance_class=m.context and m.context.class
  end
  return state
 end
 local X={}
 function X.attack(action,category)
  if category~="ranged"and category~="explosion"then return end
  local s=active();if not s or action._player_unit~=helpers.local_unit()then return end
  local c=helpers.context(action,category);if not c then return end
  local id=table.concat({tostring(c.weapon or "unknown"),tostring(c.weapon_mark or ""),tostring(c.blitz or "")},":")
  if not s.data.weapons[id]then local n=0;for _ in pairs(s.data.weapons)do n=n+1 end;if n>=32 then return end
   s.data.weapons[id]={label=c.weapon_name or (mod.io_weapon_name and mod.io_weapon_name(c.weapon))or "Unknown weapon"}
  end
  return {weapon=id}
 end
 function X.calculate(args)
  if args[17]~="ranged"and args[17]~="explosion"then return end
  if not active()or (args[35]or args[34])~=helpers.local_unit()then return end
  return {snapshot={category=args[17]},distance=args[29]}
 end
 function X.distance_report(category,killed,distance,useful)
  if category~="ranged"and category~="explosion"then return false end
  local s=active();if not s then return false end
  E.distance(s,{category=category},killed,distance,useful,distance~=nil);return true
 end
 function X.confirm(entry,damage,killed,distance,useful,attack,weakspot,counted)
  if not entry then return end;local s=active();if not s then return end
  local snapshot={category=entry.snapshot.category,weapon=attack and attack.weapon}
  E.distance(s,snapshot,killed,distance or entry.distance,useful,distance~=nil,counted)
 end
 function X.close_attack()end
 function X.finish(m)
  if m==mission then mission=nil;state=nil;resources=nil;previous={};clock=nil;accum=0 end
 end
 function X.tick(dt)
  local s=active();if not s then return end;accum=accum+dt
  if accum<.1 or not helpers.peril_players then return end
  local now=C.clock;local elapsed=clock and math.max(0,now-clock)or 0;local current={}
  local tm=Managers.time;local t=tm and tm:has_timer("gameplay")and tm:time("gameplay")or nil
  for _,p in ipairs(helpers.peril_players())do
   local old=previous[p.id]
   if old and old.unit==p.unit and elapsed<=1 then E.peril(s,p.id,p.personal,old.value,elapsed)end
   if t then Resource.sample(resources,p.id,p.personal,p.unit,t,p.value)end
   current[p.id]={unit=p.unit,value=p.value}
  end
  for id in pairs(resources.units)do if not current[id]then resources.units[id]=nil end end
  previous=current;clock=now;accum=0
 end
 -- BLO is a normal record; retain its shot callback without experimental ammo research.
 local failed=false
 local function pack(...)return {n=select("#",...),...}end
 local function spent(func,action,dt,t,charge,config)
  local results=pack(func(action,dt,t,charge,config))
  local ok,err=pcall(api.observe_blo_shot,action,t)
  if not ok and not failed then failed=true;mod:error("I/O BLO shot: %s",tostring(err))end
  return unpack(results,1,results.n)
 end
 for _,class in ipairs({"ActionShoot","ActionShootHitScan","ActionShootPellets","ActionShootProjectile","ActionFlamerGas","ActionFlamerGasBurst"})do mod:hook(class,"_spend_ammunition",spent)end
 return X
end
