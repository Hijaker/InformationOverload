-- Information Overload: the Classes page's Blitz, PBB, BLO and Crystalline Will figures, read from what is already saved.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Nav=mod:io_dofile(base.."dashboard_navigation")
local Model=mod:io_dofile(base.."dashboard_model")
local Overview=mod:io_dofile(base.."io_overview")
local K=mod:io_dofile(base.."io_data_career")
local commas=Overview.commas
local X={}
-- the same blitz ids the old class tree listed
X.blitz_ids={psyker={"brain_burst","assail"},ogryn={"ogryn_grenade_friend_rock","ogryn_grenade_frag","ogryn_grenade_box"},veteran={"grenade_frag","grenade_krak"},zealot={"grenade_shock","grenade_fire"},adamant={"grenade_adamant"},broker={"missile_launcher"},cryptic={"grenade_arc"}}
local KILLS={brain_burst=true,assail=true,ogryn_grenade_friend_rock=true}
local function events(tracker,patch,mode,class)local e=tracker.data.class_events;e=e and e[patch];e=e and e[mode];e=e and e[class];return type(e)=="table"and e or {}end
local function run(s,key)local r=s.record_runs and s.record_runs[key];return r or nil end
function X.blitz(tracker,patch,mode,class)
 local list,ev={},events(tracker,patch,mode,class)
 for _,id in ipairs(X.blitz_ids[class]or {})do
  local s=Nav.summary(tracker,{patch=patch,class=class,weapon=id,mode=mode});local hit=(s.best.explosive_hit or 0)>0 and s.best.explosive_hit or nil
  local e=KILLS[id]and type(ev[id])=="table"and ev[id]or nil;if e and (e.kills_game or 0)<=0 and (e.total_kills or 0)<=0 then e=nil end
  if hit or e then list[#list+1]={id=id,label=K.weapon(id),hit=hit,run=hit and run(s,"explosive_hit"),game=e and e.kills_game,total=e and e.total_kills}end
 end
 return list
end
function X.pbb(tracker,patch)
 local all=Nav.summary(tracker,{patch=patch,class="ogryn"});local n=all.best.pbb_ammo_mission or 0;local list,seen={}, {}
 for _,row in pairs(tracker.data.rows or {})do local c=row.context or {};local w=c.weapon
  if not row.aggregate and c.class=="ogryn"and c.patch==patch and w and not seen[w]and (row.best and row.best.pbb_ammo_mission or 0)>0 then seen[w]=true
   local s=Nav.summary(tracker,{patch=patch,class="ogryn",weapon=w});list[#list+1]={id=w,label=K.weapon(w),value=s.best.pbb_ammo_mission,run=run(s,"pbb_ammo_mission")}end
 end
 table.sort(list,function(a,b)return a.label<b.label end)
 if n<=0 and #list==0 then return nil end
 return {value=n>0 and n or nil,run=n>0 and run(all,"pbb_ammo_mission")or nil,list=list}
end
local prefix=Model.blo_prefix
X.prefix=prefix
local function blo_rows(store,patch)
 local p=store.blo_global and store.blo_global[tostring(patch)];local bucket=p and p.base;if not bucket then return nil end
 local rows={{"Best Burst Limiter Override Streak",tostring(bucket.best or 0)}}
 local shots=bucket.shots or 0;if shots>0 then rows[#rows+1]={"Procs",commas(bucket.procs or 0).." / "..commas(shots).." Shots"}end
 local counts=prefix(bucket);local lengths={}
 for n,v in pairs(counts)do if v>0 then lengths[#lengths+1]=n end end;table.sort(lengths)
 for _,n in ipairs(lengths)do rows[#rows+1]={n..(n==1 and " Proc"or " Procs"),commas(counts[n])}end
 return rows
end
local function same(a,b)if #a~=#b then return false end;for i=1,#a do if a[i][1]~=b[i][1]or a[i][2]~=b[i][2]then return false end end;return true end
-- reads only: tracker:blo_buckets would create buckets and mark the tracker dirty
function X.blo(tracker,patch)
 if not patch then return nil end
 local cards={};local weapons=tracker.data.blo_weapons and tracker.data.blo_weapons[patch]or {}
 for id,store in pairs(weapons)do if type(store)=="table"and Nav.has_weapon_data(tracker,patch,"blo",id)then local rows=blo_rows(store,patch);if rows then cards[#cards+1]={label=K.weapon(id),rows=rows}end end end
 table.sort(cards,function(a,b)return a.label<b.label end)
 local p=tracker.data.blo_global and tracker.data.blo_global[tostring(patch)];local b=p and p.base
 local all=b and ((b.shots or 0)>0 or (b.best or 0)>0 or (b.procs or 0)>0)and blo_rows(tracker.data,patch)
 if all and not (#cards==1 and same(all,cards[1].rows))then table.insert(cards,1,{label="All Weapons",rows=all})end
 return #cards>0 and cards or nil
end
function X.crystalline(tracker,patch,mode)
 local r=events(tracker,patch,mode,"psyker").crystalline_will;if type(r)~="table"then return nil end
 local rows={};local function add(label,v)if type(v)=="number"then rows[#rows+1]={label,commas(v)}end end
 add("Highest Damage Per Detonation",r.damage_burst);add("Most Kills Per Detonation",r.kills_burst)
 add("Most Elite Kills Per Detonation",r.elite_burst);add("Most Special Kills Per Detonation",r.special_burst)
 add("Highest Damage In A Mission",r.damage_game);add("Most Kills In A Mission",r.kills_game)
 add("Most Elite Kills In A Mission",r.elite_game);add("Most Special Kills In A Mission",r.special_game)
 add("Total Kills",r.total_kills);add("Total Elite Kills",r.elite_total);add("Total Special Kills",r.special_total)
 return #rows>0 and rows or nil
end
-- everything the extra tabs need for one class in one scope
function X.build(tracker,patch,mode,class)
 local x={}
 if not patch then return x end
 local b=X.blitz(tracker,patch,mode,class);if #b>0 then x.blitz=b end
 if class=="ogryn"then x.pbb=X.pbb(tracker,patch);x.blo=X.blo(tracker,patch)end
 if class=="psyker"then x.cw=X.crystalline(tracker,patch,mode)end
 return x
end
return X
