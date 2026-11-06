-- Information Overload: each saved match's melee and ranged damage by armour, kept small once read, so the Weapons page never reads every match file when it opens.
local mod=get_mod("information_overload")
local S={}
-- run.damage on a saved run reads its file; saved runs never change in place, so the run table keys what was read. Kept on mod because io_dofile reruns this file.
mod.io_run_slots=mod.io_run_slots or setmetatable({},{__mode="k"})
local seen=mod.io_run_slots
local function compact(d)local out={};if type(d)~="table"then return out end
 for armour,b in pairs(d)do if type(b)=="table"and (b.hits or 0)>0 then out[armour]={hits=b.hits,total=b.total or 0,useful=b.useful or 0,overkill=b.overkill or 0}end end
 return out
end
function S.get(run)local s=seen[run];if not s then local ok,d=pcall(function()return run.damage end);if not ok then d=nil end;s={melee=compact(d and d.melee),ranged=compact(d and d.ranged)};seen[run]=s end;return s end
-- Reads at most one unread match per call; true once every match in the list is read.
function S.warm(runs)for _,run in ipairs(runs or {})do if run.context and not seen[run]then S.get(run);return false,run end end;return true end
return S
