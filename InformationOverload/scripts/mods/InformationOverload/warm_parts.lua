-- Information Overload: the small results pages read ahead from each saved match, its damage by armour for Weapons, its team share for
-- Trends, its totals for Squad Social, its melee hits for the Psykhanium and its boss damage for the End Screen. A match works them out as it saves and keeps them on its
-- line, so none of these opens a match file; a match without them works them out from its file as before.
local mod=get_mod("information_overload")
local Team=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/team_damage")
local W={}
-- a match file that cannot be read fails all but the Weapons damage, which reads as none, as each page did before
local function safe(run)local ok,d=pcall(function()return run.damage end);return ok and type(d)=="table"and d or nil end
local function damage(run)local d=run.damage;return type(d)=="table"and d or nil end
local function team(run)local t=run.team_damage;return type(t)=="table"and t or nil end
-- what the match keeps for key, or nil
function W.saved(run,key)local mt=getmetatable(run);local w=mt and mt.io_warm;return type(w)=="table"and w[key]or nil end
-- armour buckets with hits, each as hits, total, useful and overkill
local function buckets(d)local out={};if type(d)~="table"then return out end
 for armour,b in pairs(d)do if type(b)=="table"and (b.hits or 0)>0 then out[armour]={b.hits,b.total or 0,b.useful or 0,b.overkill or 0}end end
 return out
end
local SLOTS={"melee","ranged","brain_burst","smite"}
function W.slots(run)
 local d=safe(run);local weapons=d and d.weapons
 local p={soulblaze=buckets(d and d.dot_soulblaze),toxin=buckets(d and d.dot_toxin),burn=buckets(d and d.dot_burn),bleed=buckets(d and d.dot_bleed),slots={},weapons=weapons~=nil}
 -- the Flamer's own share of the burn, on a match that keeps it
 if d and d.dot_burn_flamer then p.burn_flamer=buckets(d.dot_burn_flamer)end
 for _,slot in ipairs(SLOTS)do
  if weapons then local g=weapons[slot]or {};p.slots[slot]={regular=buckets(g.regular),special=buckets(g.special),unknown=buckets(g.unknown)}
  else p.slots[slot]=buckets(d and d[slot])end
 end
 return p
end
function W.share(run)
 local c=run.context or {};local o={};local t=team(run);local data=t and Team.from_run(run)
 if data and data.basis~="local_attack_snapshots"then
  local ops,total,me={},0,nil
  for id,p in pairs(data.members or {})do if id~="unknown_operative"then local u=Team.summary(data,id,"total").useful
   if u>0 or p.personal then ops[#ops+1]={id=id,v=u,me=p.personal==true or id==tostring(c.character)};total=total+u;if ops[#ops].me then me=ops[#ops]end end end end
  table.sort(ops,function(a,b)if a.me~=b.me then return a.me end;return a.v>b.v end)
  if total>0 and me then o.team={ops=ops,total=total,mine=me.v,share=me.v/total}end
  if me then local arm={};local p=data.members[me.id]
   for _,groups in pairs(p.groups or {})do for key,b in pairs(groups)do if key~="void_shield"and (b.reported or 0)>0 then
    local a=arm[key]or {t=key,dmg=0,useful=0,over=0,unc=key=="unknown"};arm[key]=a;a.dmg=a.dmg+(b.reported or 0);a.useful=a.useful+(b.useful or 0);a.over=a.over+(b.overkill or 0)end end end
   if next(arm)then o.armour=arm end end
 end
 return o
end
function W.social(run)
 local h={};local d=damage(run)
 if d then for _,slot in ipairs({"melee","ranged"})do local g=d[slot];if type(g)=="table"then local n=0
  for a,b in pairs(g)do if a~="all"and a~="void_shield"and type(b)=="table"then n=n+(tonumber(b.total)or 0)end end;h[slot]=n end end end
 local t=team(run);if t then h.members={};for id in pairs(t.members or {})do h.members[tostring(id)]=Team.summary(t,id,"total").useful end end
 return h
end
local ARMOUR={"unarmored","armored","berserker","super_armor","resistant","disgustingly_resilient"}
function W.melee(run)
 local d=damage(run);local g=d and d.melee or {};local out={}
 for _,a in ipairs(ARMOUR)do local b=g[a];out[a]={dmg=b and b.total or 0,n=b and b.hits or 0}end
 local all=g.all;out.all={dmg=all and all.total or 0,n=all and all.hits or 0};return out
end
-- your useful damage to bosses, for the End Screen's averages; none where the match kept no boss damage apart
function W.boss(run)
 local c=run.context or {};local t=team(run);local data=t and Team.from_run(run)
 if not (data and data.shield_partition)then return {}end
 for id,p in pairs(data.members or {})do if id~="unknown_operative"and (p.personal==true or id==tostring(c.character))then return {mine=Team.summary(data,id,"boss").useful or 0}end end
 return {}
end
-- a match that saved before it kept its boss damage has it read from its file once a launch, in the Mourningstar as the other pages' figures
-- are, and held for the End Screen; kept on mod because io_dofile reruns this file, so the hub, Run Slots and the End Screen share it
local BOSS=rawget(mod,"io_boss_read")or setmetatable({},{__mode="k"});mod.io_boss_read=BOSS
function W.boss_of(run)return W.saved(run,"boss")or BOSS[run]end
function W.read_boss(run)local ok,v=pcall(W.boss,run);v=ok and v or {};BOSS[run]=v;return v end
-- up to 64 matches that keep or hold theirs, or one match file read, a call, carrying on where the last call stopped; true at the end of the
-- list, and the next call starts again from the top
local AT=setmetatable({},{__mode="k"})
function W.boss_warm(runs)runs=runs or {};local i=AT[runs]or 1
 for _=1,64 do local run=runs[i];if run==nil then AT[runs]=nil;return true end;i=i+1;AT[runs]=i
  if run.context and not W.boss_of(run)then W.read_boss(run);return false end end
 return false
end
-- all five, for the match's line as it saves; a part that fails is left off, and its page works it out from the file
function W.all(run)
 local out={}
 for key,f in pairs({slots=W.slots,share=W.share,social=W.social,melee=W.melee,boss=W.boss})do local ok,v=pcall(f,run);if ok then out[key]=v end end
 return out
end
return W
