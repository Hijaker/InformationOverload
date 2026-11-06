-- Compact, reconstructable maxima and kill counters. No persisted hit ledger.
local P={}
local function copy(v)if type(v)~="table"then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function member(data,id,class,personal)
 local p=data.members[id];if not p then p={class=class,personal=personal,kills={total=0,boss=0,elite=0,special=0,horde_melee=0,horde_ranged=0},best={},armour={},enemy={},weapons={},quality={}};data.members[id]=p end;p.class=class or p.class;p.personal=personal==true or p.personal==true;return p
end
function P.new(saved,counts)local data=copy(saved or {version=2,fixed_roles=true,members={}});for id,p in pairs(counts and counts.members or {})do local m=member(data,id,p.class,p.personal);m.enemy_kills=copy(p.enemy_kills)end;return {data=data,killed=setmetatable({},{__mode="k"}),swings={}}end
function P.register(s,id,class,personal)if id then return member(s.data,id,class,personal)end end
function P.kill(s,e)
 if not e.actor or not e.target or s.killed[e.target]then return false end
 s.killed[e.target]=true;local p=member(s.data,e.actor,e.class,e.personal);p.kills.total=p.kills.total+1
 local kind=e.kind;if kind then p.kills[kind]=(p.kills[kind]or 0)+1 end;if e.fixed_kind then p.kills[e.fixed_kind]=(p.kills[e.fixed_kind]or 0)+1 end
 if e.enemy then p.enemy_kills=p.enemy_kills or {};local key=e.enemy..":"..tostring(e.subgroup or e.group);local k=p.enemy_kills[key]or {enemy=e.enemy,label=e.label,group=e.group,subgroup=e.subgroup,count=0};p.enemy_kills[key]=k;k.count=k.count+1 end;return true
end
local function peak(bucket,key,n,e)
 if not bucket[key]or n>bucket[key].value then bucket[key]={value=n,weapon=e.weapon,enemy=e.enemy,armour=e.armour,category=e.category,hits=e.hits,targets=e.targets,group_basis=e.group_basis}end
end
local function record(p,key,n,e)
 peak(p.best,key,n,e)
 if e.armour then p.armour[e.armour]=p.armour[e.armour]or {};peak(p.armour[e.armour],key,n,e)end
 if e.enemy then p.enemy[e.enemy]=p.enemy[e.enemy]or {};peak(p.enemy[e.enemy],key,n,e)end
 if e.weapon then p.weapons[e.weapon]=p.weapons[e.weapon]or {};peak(p.weapons[e.weapon],key,n,e)end
end
function P.hit(s,e)
 if not e.actor or e.armour=="void_shield"or type(e.damage)~="number"or e.damage<=0 or e.damage~=e.damage or e.damage>=math.huge then return end
 local p=member(s.data,e.actor,e.class,e.personal)
 if e.category~="melee"and e.category~="ranged"and e.category~="explosion"then return end

 record(p,"single_hit",e.damage,e)
 if e.category=="explosion"then record(p,"explosive_single_hit",e.damage,e)end
 if e.category=="melee"then

  if not e.group then return end
  local g=s.swings[e.actor]
  if not g or g.key~=e.group then g={key=e.group,first_clock=e.clock,total=0,hits=0,targets=0,seen=setmetatable({},{__mode="k"}),armour={},enemy={},names={}};s.swings[e.actor]=g end
  if e.clock and g.first_clock and e.clock-g.first_clock>.4 then return end

  g.total=g.total+e.damage;g.hits=g.hits+1;if e.target and not g.seen[e.target]then g.targets=g.targets+1;g.seen[e.target]=true end
  if e.enemy then g.names[e.enemy]=true end;local names={};for name in pairs(g.names)do names[#names+1]=name end;table.sort(names)
  local item={weapon=e.weapon,category="melee",enemy=table.concat(names,", "),hits=g.hits,targets=g.targets,group_basis="replicated_action"}
  peak(p.best,"melee_cleave",g.total,item)
  if e.weapon then p.weapons[e.weapon]=p.weapons[e.weapon]or {};peak(p.weapons[e.weapon],"melee_cleave",g.total,item)end
  if e.armour then g.armour[e.armour]=(g.armour[e.armour]or 0)+e.damage;p.armour[e.armour]=p.armour[e.armour]or {};item.armour=e.armour;peak(p.armour[e.armour],"melee_cleave",g.armour[e.armour],item);item.armour=nil end
  if e.enemy then g.enemy[e.enemy]=(g.enemy[e.enemy]or 0)+e.damage;p.enemy[e.enemy]=p.enemy[e.enemy]or {};item.enemy=e.enemy;peak(p.enemy[e.enemy],"melee_cleave",g.enemy[e.enemy],item)end
 end
end
function P.results(s)return copy(s.data)end
function P.checkpoint(s)
 local data={};for k,v in pairs(s.data)do if k~="members"then data[k]=v end end;data.members={};local counts={members={}}
 for id,p in pairs(s.data.members or {})do local m={};for k,v in pairs(p)do if k~="enemy_kills"then m[k]=v end end;data.members[id]=m;if p.enemy_kills then counts.members[id]={personal=p.personal,class=p.class,enemy_kills=p.enemy_kills}end end
 return data,counts
end
function P.export(s)
 local data=copy(s.data);local counts={members={}}
 for id,p in pairs(data.members or {})do if p.enemy_kills then counts.members[id]={personal=p.personal,class=p.class,enemy_kills=p.enemy_kills};p.enemy_kills=nil end end
 return data,counts
end
local function maxima(a,b)for key,e in pairs(b or {})do if not a[key]or e.value>a[key].value then a[key]=copy(e)end end end
function P.merge(a,b)
 local result=copy(a or {version=2,fixed_roles=true,members={}})
 if a and b and (a.fixed_roles~=nil or b.fixed_roles~=nil)then result.fixed_roles=a.fixed_roles==true and b.fixed_roles==true end
 for id,p in pairs(b and b.members or {})do local target=member(result,id,p.class,p.personal)
  for _,field in ipairs({"kills","quality"})do for key,n in pairs(p[field]or {})do target[field][key]=(target[field][key]or 0)+n end end
  for key,k in pairs(p.enemy_kills or {})do target.enemy_kills=target.enemy_kills or {};local old=target.enemy_kills[key];if old then old.count=old.count+k.count else target.enemy_kills[key]=copy(k)end end
  maxima(target.best,p.best);for _,field in ipairs({"armour","enemy","weapons"})do for key,records in pairs(p[field]or {})do target[field][key]=target[field][key]or {};maxima(target[field][key],records)end end
 end;return result
end
return P

