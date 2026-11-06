local I={}
-- a teammate whose Steam id did not resolve in one mission is still one person: any saved row with both ids ties the account to the Steam id
local mod=type(get_mod)=="function"and get_mod("information_overload")or nil
local state=mod and mod.io_identity or {maps=setmetatable({},{__mode="k"})};if mod then mod.io_identity=state end
function I.learn(data)
 local list=data and data.run_history;if type(list)~="table"then return end
 local m=state.maps[data];local seq,pol,n=data.run_sequence,data.history_policy_revision,#list
 if not (m and m.seq==seq and m.pol==pol and m.n==n)then local ids={}
  for _,run in ipairs(list)do for _,set in ipairs({run.context and run.context.operative_roster or {},run.operative_clutches or {}})do for _,p in pairs(set)do
   if type(p)=="table"and p.steam_id and p.account_id then ids[tostring(p.account_id)]=tostring(p.steam_id)end end end end
  local acc={};for a,s in pairs(ids)do acc[s]=a end
  m={seq=seq,pol=pol,n=n,ids=ids,acc=acc};state.maps[data]=m end
 state.ids=m.ids;state.acc=m.acc
end
function I.key(p)if p.steam_id then return tostring(p.steam_id)elseif p.account_id then local acc=tostring(p.account_id);return state.ids and state.ids[acc]or "account:"..acc end end
-- an entry saved under the account key before the Steam id turned up still belongs to that person
function I.lookup(t,id)if t[id]~=nil then return t[id]end;local acc=state.acc and state.acc[tostring(id)];if acc then return t["account:"..acc]end end
function I.matches(p,id)return I.key(p)==tostring(id)or p.account_id and "account:"..tostring(p.account_id)==tostring(id)end
return I
