-- Hypotheses, not an assertion about the game's stacking rules.
local P={}
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
function P.evaluate(base,reductions,amplification)
 if not finite(base)or base<0 or not finite(amplification or 0)or (amplification or 0)<-1 then return end
 local sum,product=0,1
 for _,dr in ipairs(reductions or {})do if not finite(dr)or dr<0 or dr>1 then return end;sum=sum+dr;product=product*(1-dr)end
 local amp=1+(amplification or 0)
 return {additive=base*math.max(0,1-sum)*amp,multiplicative=base*product*amp}
end
-- Factors below are the game's resolved statistics, which may already combine
-- several buffs. Alternate models across these factors do not undo that stacking.
function P.from_snapshot(snapshot)
 local stats=snapshot.target_stats or {};local reductions,amplification={},0
 local keys={"damage_taken_multiplier","damage_taken_modifier"}
 if snapshot.category=="melee"then keys[#keys+1]="melee_damage_taken_multiplier";keys[#keys+1]="melee_damage_taken_modifier"elseif snapshot.category=="ranged"then keys[#keys+1]="ranged_damage_taken_multiplier"end
 for _,name in ipairs(keys)do local n=stats[name];if finite(n)then if n<1 then reductions[#reductions+1]=1-math.max(0,n)elseif n>1 then amplification=amplification+n-1 end end end
 local models=P.evaluate(100,reductions,amplification)
 return {status="unvalidated_partial_model",reference_damage=100,reference_is_weapon_baseline=false,factors="resolved_stat_fields_not_individual_buffs",health_dependent=snapshot.health_dependent==true,additive=models and models.additive,multiplicative=models and models.multiplicative,excludes="Armour; other conditional target modifiers; attacker bonus buckets; damage-specific multipliers"}
end
function P.from_declarations(snapshot,base)
 local reductions,amplification,excluded={},0,0;local eligible={damage_taken_multiplier=true,damage_taken_modifier=true}
 if snapshot.category=="melee"then eligible.melee_damage_taken_multiplier=true;eligible.melee_damage_taken_modifier=true elseif snapshot.category=="ranged"then eligible.ranged_damage_taken_multiplier=true end
 local samples=0
 for _,buff in pairs(snapshot.protection_declarations or {})do
  if buff.dynamic_multiplier or buff.has_overrides then excluded=excluded+1
  else
   for stat,value in pairs(buff.declared or {})do if eligible[stat]then
    local kind=(buff.types or {})[stat];local factor=kind=="multiplicative_multiplier"and value or kind=="additive_multiplier"and 1+value or nil
    if finite(factor)and factor>=0 then for _=1,math.min(64,buff.stat_stacks or 1)do if factor<1 then reductions[#reductions+1]=1-factor else amplification=amplification+factor-1 end;samples=samples+1 end else excluded=excluded+1 end
   end end
  end
  if next(buff.conditional or {})then excluded=excluded+1 end
 end
 local model=P.evaluate(base or 100,reductions,amplification)
 return {status="unvalidated_partial_model",reference_damage=base or 100,reference_is_weapon_baseline=false,factors="static_per_buff_declarations",factor_count=samples,excluded_buffs=excluded,health_dependent=snapshot.health_dependent==true,additive=model and model.additive,multiplicative=model and model.multiplicative,excludes="Conditional/overridden/dynamic buffs; source-specific multipliers; shared attacker bonus buckets; armour"}
end
function P.ehp(health,multiplier)
 if not finite(health)or health<=0 or not finite(multiplier)or multiplier<=0 then return end
 return health/multiplier
end
return P
