-- Imported Matches Count For Records, on Settings > Data: off, a match imported from Power DI holds no record or best and its estimated
-- clear time counts for nothing; on, it holds them as this PC's own matches do, its estimate counted as a clear time and still shown with ~
local R={KEY="imported_records"}
function R.on()
 local mod=type(get_mod)=="function"and get_mod("information_overload")or nil
 return mod~=nil and type(mod.get)=="function"and mod:get(R.KEY)==true
end
-- a match that may hold a record or best
function R.ranked(run)return not run.imported or R.on()end
return R
