local T={}
local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function valid(n)return type(n)=="number"and n==n and n>=0 and n<math.huge end
local function bucket()return {reported=0,useful=0,overkill=0,unknown=0}end
local dots={Bleed="dot_bleed",Burn="dot_burn",Soulblaze="dot_soulblaze",Toxin="dot_toxin",bleeding="dot_bleed",burning="dot_burn",phosphor_burning="dot_burn",warpfire="dot_soulblaze",toxin_variant_1="dot_toxin",toxin_variant_2="dot_toxin",toxin_variant_3="dot_toxin"}
function T.category(e)
 return dots[e.profile]or dots[e.category]or (e.category=="melee"and "melee")or ((e.category=="ranged"or e.category=="explosion")and "ranged")or "other"
end
local function add(data,id,class,personal,category,armour,reported,useful,overkill,unknown)
 data.members=data.members or {};local p=data.members[id]or {class=class,personal=personal,groups={}};data.members[id]=p;p.class=class or p.class;p.personal=personal==true
 p.groups[category]=p.groups[category]or {};local b=p.groups[category][armour]or bucket();p.groups[category][armour]=b
 b.reported=b.reported+reported;b.useful=b.useful+useful;b.overkill=b.overkill+overkill;b.unknown=b.unknown+unknown
end
function T.new(saved)return {data=saved and copy(saved)or {version=1,members={},boss_recorded=true,shield_partition=true,hit_counts=true,basis="scoreboard_health_cache"},health=setmetatable({},{__mode="k"}),shield_health=setmetatable({},{__mode="k"}),observed_health=setmetatable({},{__mode="k"})}end
function T.seed(s,unit,hp,maximum)if unit and s.health[unit]==nil and valid(maximum)and maximum>0 then s.health[unit]=maximum end end
function T.hit(s,e)
 if not valid(e.damage)or e.damage<=0 then return end

 local useful,overkill,unknown=0,0,e.damage;local budget
 local health_known=e.target and s.observed_health[e.target]==true and valid(s.health[e.target])or false
 local shield=e.armour=="void_shield"
 if e.target and shield then
  local hp=s.shield_health[e.target]
  if hp==nil and valid(e.shield_hp)then hp=e.shield_hp+e.damage;if valid(e.shield_maximum)then hp=math.min(hp,e.shield_maximum)end end
  if hp then useful=math.min(e.damage,math.max(0,hp));overkill=e.damage-useful;unknown=0;s.shield_health[e.target]=math.max(0,hp-useful)end
 elseif e.target and (e.result=="damaged"or e.result=="died")then
  s.shield_health[e.target]=nil
  local hp=s.health[e.target]
  if hp==nil then hp=valid(e.hp)and e.hp+e.damage or valid(e.maximum)and e.maximum or e.damage;if valid(e.maximum)then hp=math.min(hp,e.maximum)end end
  budget=hp;useful=math.min(e.damage,math.max(0,hp));overkill=e.damage-useful;unknown=0
  s.health[e.target]=e.result=="died"and nil or math.max(0,hp-useful)
  s.observed_health[e.target]=e.result~="died"or nil
 end
 add(s.data,e.actor or "unknown_operative",e.class,e.personal,T.category(e),e.armour or "unknown",e.damage,useful,overkill,unknown)
 -- weakspots and crits are counted per hit report on an enemy, as the server sends one for every hit
 if e.actor and (e.weakspot or e.critical)then local p=s.data.members[e.actor];local n=p.hits or {weakspot=0,critical=0};p.hits=n;if e.weakspot then n.weakspot=n.weakspot+1 end;if e.critical then n.critical=n.critical+1 end end
 if e.boss and e.actor then local p=s.data.members[e.actor];p.boss=p.boss or bucket();p.boss.reported=p.boss.reported+e.damage;p.boss.useful=p.boss.useful+useful;p.boss.overkill=p.boss.overkill+overkill;p.boss.unknown=p.boss.unknown+unknown;if shield then p.boss_void_shield=p.boss_void_shield or bucket();for field,value in pairs({reported=e.damage,useful=useful,overkill=overkill,unknown=unknown})do p.boss_void_shield[field]=p.boss_void_shield[field]+value end end end
 return {total=e.damage,useful=unknown==0 and useful or nil,health_before=budget,health_known=health_known}
end
function T.results(s)return copy(s.data)end
function T.from_run(run)
 if run.team_damage then return run.team_damage end
 local test=run.compact_damage_test
 if test and test.version==2 then
  local data={version=1,members={},basis="scoreboard_health_cache",from_test=true}
  for _,r in ipairs(test.concurrent or {})do add(data,r.actor or "unknown_operative",r.class,r.personal,T.category({category=r.category,profile=r.profile}),r.armour or "unknown",r.total or 0,(r.verified_useful or 0)+(r.estimated_useful or 0),(r.verified_overkill or 0)+(r.estimated_overkill or 0),r.unknown or 0)end
  return data
 end
 -- Adapt the personal source to the same display schema. No save is modified.
 if not run.damage then return end
 local c=run.context or {};local id=tostring(c.character);local data={version=1,members={},basis="local_attack_snapshots"}
 local function saved(name,key)
  local b=run.damage[name]and run.damage[name][key];if not b then return bucket()end
  local reported=b.total or 0;local useful=b.useful or 0;local overkill=b.overkill or 0
  return {reported=reported,useful=useful,overkill=overkill,unknown=math.max(0,reported-useful-overkill)}
 end
 local keys={};for key in pairs(run.damage.total or {})do if key~="all"then keys[key]=true end end
 for _,groups in pairs(run.damage)do if type(groups)=="table"then for key in pairs(groups)do if key~="all"then keys[key]=true end end end end
 for key in pairs(keys)do
  local assigned=bucket();local dots=bucket()
  for _,kind in ipairs({"melee","ranged","dot_bleed","dot_burn","dot_soulblaze","dot_toxin","dot_other"})do
   local v=saved(kind,key);if v.reported>0 then add(data,id,c.class,true,kind,key,v.reported,v.useful,v.overkill,v.unknown)end
   for field in pairs(assigned)do assigned[field]=assigned[field]+v[field];if kind:sub(1,4)=="dot_"then dots[field]=dots[field]+v[field]end end
  end
  local dot=saved("dot",key);local rest=bucket();for field in pairs(rest)do rest[field]=math.max(0,dot[field]-dots[field])end
  if rest.reported>0 then add(data,id,c.class,true,"dot_other",key,rest.reported,rest.useful,rest.overkill,rest.unknown);for field in pairs(assigned)do assigned[field]=assigned[field]+rest[field]end end
  local all=saved("total",key);for field in pairs(rest)do rest[field]=math.max(0,all[field]-assigned[field])end
  if rest.reported>0 then add(data,id,c.class,true,"other",key,rest.reported,rest.useful,rest.overkill,rest.unknown)end
 end
 return data
end
function T.summary(data,player,category,armour)
 local out=bucket();if not data then return out end
 for id,p in pairs(data.members or {})do if (not player or player==id)and id~="unknown_operative"then
  if category=="boss"and data.shield_partition then for field in pairs(out)do out[field]=out[field]+math.max(0,(p.boss and p.boss[field]or 0)-(p.boss_void_shield and p.boss_void_shield[field]or 0))end end
  for kind,groups in pairs(p.groups or {})do if not category or category=="total"or kind==category or category=="dot"and kind:sub(1,4)=="dot_"then
   for key,b in pairs(groups)do if key~="void_shield"and (not armour or key==armour)then for field in pairs(out)do out[field]=out[field]+(b[field]or 0)end end end
  end end
 end end;return out
end
function T.armours(data)
 local set={};for id,p in pairs(data and data.members or {})do if id~="unknown_operative"then for _,g in pairs(p.groups or {})do for key,b in pairs(g)do if key~="void_shield"and (b.useful or 0)>0 then set[key]=true end end end end end;return set
end
return T
