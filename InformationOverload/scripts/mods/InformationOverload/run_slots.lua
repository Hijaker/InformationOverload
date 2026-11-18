-- Information Overload: each saved match's melee and ranged damage by armour, kept small once read, so the Weapons page never reads every match file when it opens.
local mod=get_mod("information_overload")
local S={}
-- run.damage on a saved run reads its file; saved runs never change in place, so the run table keys what was read. Kept on mod because io_dofile reruns this file.
mod.io_run_slots=mod.io_run_slots or setmetatable({},{__mode="k"})
local seen=mod.io_run_slots
local Warm=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/warm_parts")
-- warm_parts keeps each armour as hits, total, useful and overkill
local function compact(d)local out={};if type(d)~="table"then return out end
 for armour,b in pairs(d)do if type(b)=="table"then out[armour]={hits=b[1],total=b[2],useful=b[3],overkill=b[4]}end end
 return out
end
function S.combine(groups)
 local out={}
 for _,group in pairs(groups)do
  for armour,b in pairs(group)do
   local sum=out[armour] or {hits=0,total=0,useful=0,overkill=0}
   for key in pairs(sum)do sum[key]=sum[key]+b[key]end
   out[armour]=sum
  end
 end
 return out
end
-- from what the match keeps on its line, or else from its file
function S.get(run)
 local s=seen[run]
 if s then return s end
 local p=Warm.saved(run,"slots")
 -- a match read from its file gives up its boss damage for the End Screen in the same read
 if not p then p=Warm.slots(run);if not Warm.boss_of(run)then Warm.read_boss(run)end end
 s={soulblaze=compact(p.soulblaze),toxin=compact(p.toxin),burn=compact(p.burn),bleed=compact(p.bleed),weapons=p.weapons and {}or nil,burn_flamer=p.burn_flamer and compact(p.burn_flamer)or nil}
 for _,slot in ipairs({"melee","ranged","brain_burst","smite"})do
  local g=p.slots and p.slots[slot]or {}
  if p.weapons then
   local modes={regular=compact(g.regular),special=compact(g.special),unknown=compact(g.unknown)}
   modes.all=S.combine(modes)
   s.weapons[slot]=modes
   s[slot]=modes.all
  else
   s[slot]=compact(g)
  end
 end
 seen[run]=s
 return s
end
-- Takes in up to 64 matches that keep theirs, or reads one match file, a call; true once every match in the list is in.
function S.warm(runs)local n=0
 for _,run in ipairs(runs or {})do if run.context and not seen[run]then
  if Warm.saved(run,"slots")then S.get(run);n=n+1;if n>=64 then return false end else S.get(run);return false,run end
 end end
 return true
end
return S
