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
-- Each operative's useful damage and kills by minute of the mission, counted with the totals: minute 0 starts at minutes.origin_ms on the
-- gameplay clock the downs and deaths are timed on. A mission keeps them in tables by minute; a saved match packs each operative's into a
-- string: its first minute and how many follow, then each series at the fewest base-91 digits its largest needs.
local SERIES={"useful","kills"}
local DIGIT,VALUE={},{};for c=33,126 do if c~=34 and c~=47 and c~=92 then DIGIT[#DIGIT+1]=string.char(c);VALUE[c]=#DIGIT-1 end end
local BASE=#DIGIT
local function put(out,n,w)for i=w-1,0,-1 do out[#out+1]=DIGIT[math.floor(n/BASE^i)%BASE+1]end end
local function encode(m)
 local out={};put(out,m.first,2);put(out,#m.useful,2)
 for _,field in ipairs(SERIES)do local top,w=0,1;for _,v in ipairs(m[field])do top=math.max(top,v)end;while top>=BASE^w do w=w+1 end
  put(out,w,1);for _,v in ipairs(m[field])do put(out,v,w)end end
 return table.concat(out)
end
local function decode(text)
 local at=1;local function get(w)local n=0;for _=1,w do n=n*BASE+(VALUE[text:byte(at)]or 0);at=at+1 end;return n end
 local m={first=get(2)};local n=get(2);for _,field in ipairs(SERIES)do local w,list=get(1),{};for i=1,n do list[i]=get(w)end;m[field]=list end
 return m
end
-- an operative's minutes as whole numbers from their first minute with any to their last: useful damage is rounded on its running total, so
-- the minutes add up to the total rounded once, then put right by the point two parts rounded apart can leave against the squad tally's figure
local function whole(p,data,id)
 if type(p)=="string"then return decode(p)end
 if type(p)~="table"then return nil end
 local a,b;for _,field in ipairs(SERIES)do for i,v in pairs(p[field]or {})do if v~=0 then a=math.min(a or i,i);b=math.max(b or i,i)end end end
 if not a then return nil end
 local m,run,done,top={first=a-1,useful={},kills={}},0,0,1
 for i=a,b do run=run+(p.useful and p.useful[i]or 0);local r=math.floor(run+.5);local j=#m.useful+1;m.useful[j]=r-done;done=r;m.kills[j]=p.kills and p.kills[i]or 0;if m.useful[j]>m.useful[top]then top=j end end
 local gap=math.floor(T.summary(data,id,"total").useful+.5)-done;if gap~=0 and math.abs(gap)<=1 and m.useful[top]+gap>=0 then m.useful[top]=m.useful[top]+gap end
 return m
end
local function live(text)local p={useful={},kills={}};local m=text and decode(text);for _,field in ipairs(SERIES)do for i,v in ipairs(m and m[field]or {})do if v~=0 then p[field][m.first+i]=v end end end;return p end
-- at is the gameplay clock in whole milliseconds, as a down's time is kept; without one it goes in the last minute counted
local function tally(s,id,at,field,n)
 local w=s.data.minutes;if type(w)~="table"or not id or not w.origin_ms or n==0 then return end
 local i=at and math.max(0,math.floor((at-w.origin_ms)/60000))or s.minute or 0;s.minute=i
 local p=w.members[id];if type(p)~="table"then p=live(p);w.members[id]=p end
 p[field][i+1]=(p[field][i+1]or 0)+n
end
function T.new(saved)return {data=saved and copy(saved)or {version=1,members={},boss_recorded=true,shield_partition=true,hit_counts=true,kinds=true,basis="scoreboard_health_cache",minutes={version=1,members={}}},health=setmetatable({},{__mode="k"}),shield_health=setmetatable({},{__mode="k"}),observed_health=setmetatable({},{__mode="k"})}end
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
 if e.actor and not shield then tally(s,e.actor,e.at,"useful",useful)end
 -- weakspots and crits are counted per hit report on an enemy, as the server sends one for every hit
 if e.actor and (e.weakspot or e.critical)then local p=s.data.members[e.actor];local n=p.hits or {weakspot=0,critical=0};p.hits=n;if e.weakspot then n.weakspot=n.weakspot+1 end;if e.critical then n.critical=n.critical+1 end end
 if e.kind and e.actor and not shield then local p=s.data.members[e.actor];p.kinds=p.kinds or {};local k=p.kinds[e.kind]or bucket();p.kinds[e.kind]=k
  k.reported=k.reported+e.damage;k.useful=k.useful+useful;k.overkill=k.overkill+overkill;k.unknown=k.unknown+unknown end
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
-- a member's damage by enemy kind, in the scoreboard's names; nil for a match recorded before it was kept
function T.kinds(data,player,field)
 if not data or not data.kinds then return nil end
 local p=data.members and data.members[player];local k=p and p.kinds;field=field or "useful"
 local function n(kind)return k and k[kind]and k[kind][field]or 0 end
 return {lesser=n("horde"),elites=n("elite"),specials=n("special"),monst=n("boss")}
end
function T.armours(data)
 local set={};for id,p in pairs(data and data.members or {})do if id~="unknown_operative"then for _,g in pairs(p.groups or {})do for key,b in pairs(g)do if key~="void_shield"and (b.useful or 0)>0 then set[key]=true end end end end end;return set
end
-- a kill, as the squad cards count it, in its minute
function T.kill(s,id,at)tally(s,id,at,"kills",1)end
-- packed as a match saves; packing twice is packing once
function T.pack_minutes(data)
 local w=type(data)=="table"and data.minutes;if type(w)~="table"or type(w.members)~="table"then return data end
 for id,p in pairs(w.members)do if type(p)~="string"then local m=whole(p,data,id);w.members[id]=m and encode(m)or nil end end
 return data
end
-- the mission clock's figures from either shape: each operative's useful damage and kills a minute, minute k at [k+1], over count minutes
-- from minute 0 to the last anyone has a figure in; start is the seconds minute 0 begins after the match's 0:00 (origin, its timing_origin),
-- 0 unless the minutes were counted from another; nil for a match from before they were kept
function T.minutes(data,origin)
 local w=type(data)=="table"and data.minutes;if type(w)~="table"or type(w.members)~="table"then return nil end
 local got,n={},0
 for id,p in pairs(w.members)do local m=whole(p,data,id);if m then got[id]=m;n=math.max(n,m.first+#m.useful)end end
 local out={version=w.version,origin_ms=w.origin_ms,count=n,start=0,members={}}
 if type(w.origin_ms)=="number"then out.start=(w.origin_ms-math.floor((type(origin)=="number"and origin or 0)*1000+.5))/1000 end
 for id,m in pairs(got)do local p={};for _,field in ipairs(SERIES)do local list={};for i=1,n do list[i]=m[field][i-m.first]or 0 end;p[field]=list end;out.members[id]=p end
 return out
end
-- two saved parts of one mission, added minute by minute on the first part's 0:00, the later moved by whole minutes if it counted from another;
-- none when a part with a squad tally kept none
function T.merge_minutes(a,b)
 local x,y=type(a)=="table"and a.minutes,type(b)=="table"and b.minutes
 if a and not x or b and not y or not (x or y)then return nil end
 local o=x and x.origin_ms or nil;if o==nil and y then o=y.origin_ms end
 local out={version=(x or y).version,origin_ms=o,members={}}
 for _,part in ipairs({{a,x},{b,y}})do local data,w=part[1],part[2]
  if w then local shift=type(w.origin_ms)=="number"and type(o)=="number"and math.floor((w.origin_ms-o)/60000+.5)or 0
   for id,p in pairs(w.members or {})do local m=whole(p,data,id)
    if m then local t=out.members[id]or {useful={},kills={}};out.members[id]=t
     for _,field in ipairs(SERIES)do for i,v in ipairs(m[field])do local k=math.max(1,m.first+i+shift);t[field][k]=(t[field][k]or 0)+v end end end
   end end
 end
 return out
end
return T
