local I={}
-- a teammate whose Steam id did not resolve in one mission is still one person: any saved row with both ids ties the account to the Steam id
local mod=type(get_mod)=="function"and get_mod("information_overload")or nil
local state=mod and mod.io_identity or {maps=setmetatable({},{__mode="k"})};if mod then mod.io_identity=state end
function I.learn(data)
 local list=data and data.run_history;if type(list)~="table"then return end
 local m=state.maps[data];local seq,pol,n=data.run_sequence,data.history_policy_revision,#list
 if not (m and m.own and m.seq==seq and m.pol==pol and m.n==n)then local ids,own,names={},{},{}
  for _,run in ipairs(list)do for _,set in ipairs({run.context and run.context.operative_roster or {},run.operative_clutches or {}})do for _,p in pairs(set)do
   if type(p)=="table"and p.account_id then local a=tostring(p.account_id);if p.personal then own[a]=true end
    if p.steam_id then ids[a]=tostring(p.steam_id);names[a]=p.steam_name or names[a]end end end end end
  local acc={};for a,s in pairs(ids)do acc[s]=a end
  m={seq=seq,pol=pol,n=n,ids=ids,acc=acc,own=own,names=names};state.maps[data]=m end
 state.ids=m.ids;state.acc=m.acc;state.own=m.own;state.names=m.names
end
-- the oldest matches saved who played only as undashed account ids: each one a roster ties to a Steam id stands in for that match's roster row, never yours
function I.team_accounts(data,c)
 local out={};if type(c)~="table"or type(c.team_accounts)~="table"or next(c.operative_roster or {})then return out end
 I.learn(data);local ids,own,names=state.ids or {},state.own or {},state.names or {}
 for key in pairs(c.team_accounts)do local acc=tostring(key):gsub("^(%x%x%x%x%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x+)$","%1-%2-%3-%4-%5")
  if ids[acc]and not own[acc]then out[acc]={account_id=acc,steam_id=ids[acc],steam_name=names[acc]}end end
 return out
end
function I.key(p)if p.steam_id then return tostring(p.steam_id)elseif p.account_id then local acc=tostring(p.account_id);return state.ids and state.ids[acc]or "account:"..acc end end
-- an entry saved under the account key before the Steam id turned up still belongs to that person
function I.lookup(t,id)if t[id]~=nil then return t[id]end;local acc=state.acc and state.acc[tostring(id)];if acc then return t["account:"..acc]end end
function I.matches(p,id)return I.key(p)==tostring(id)or p.account_id and "account:"..tostring(p.account_id)==tostring(id)end
return I
