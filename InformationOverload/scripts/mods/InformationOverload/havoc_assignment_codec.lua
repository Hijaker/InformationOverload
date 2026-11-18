-- Pure protocol/normalization boundary; no game, transport or filesystem access.
local C={VERSION=1,MAX_BYTES=250}
local excluded={mutator_increased_difficulty=true,mutator_highest_difficulty=true}
local function token(v,n)return type(v)=="string" and #v>0 and #v<=(n or 96) and v:match("^[a-z0-9_%-]+$")~=nil end
local function split(s,sep)local out={};for v in (s..sep):gmatch("(.-)"..sep)do out[#out+1]=v end;return out end
local function shorten(s)return (s:gsub("^mutator_havoc_","~h"):gsub("^mutator_","~m"))end
local function expand(s)return (s:gsub("^~h","mutator_havoc_"):gsub("^~m","mutator_"))end
function C.validate(a,known)
 if type(a)~="table" or not token(a.assignment_id,64) then return nil,"invalid assignment ID" end
 if type(a.rank)~="number" or a.rank~=math.floor(a.rank) or a.rank<1 or a.rank>40 then return nil,"invalid rank" end
 if not token(a.map) or not known.maps[a.map] then return nil,"unknown map" end
 if a.faction~="mixed" and a.faction~="renegade" and a.faction~="cultist" then return nil,"unknown faction" end
 if type(a.modifiers)~="table" or #a.modifiers>8 then return nil,"invalid modifier list" end
 local seen={};local out={assignment_id=a.assignment_id,rank=a.rank,map=a.map,faction=a.faction,modifiers={}}
 local count=0
 for k in pairs(a.modifiers)do count=count+1;if type(k)~="number" or k<1 or k>#a.modifiers or k~=math.floor(k)then return nil,"invalid modifier array"end end
 if count~=#a.modifiers then return nil,"sparse modifier array"end
 for _,id in ipairs(a.modifiers)do
  if not token(id) or not known.modifiers[id] or excluded[id] or seen[id] then return nil,"invalid or duplicate modifier" end
  seen[id]=true;out.modifiers[#out.modifiers+1]=id
 end
 table.sort(out.modifiers);return out
end
function C.from_order(order,known)
 if type(order)~="table" then return nil,"invalid order"end
 local b=order.blueprint or {};local flags=b.flags
 if type(flags)~="table" then return nil,"missing assignment flags"end
 local mods,faction={},nil
 for key,on in pairs(flags)do if on==true and type(key)=="string" then
  local id=key:match("^havoc%-circ%-(.+)$")
  -- the game renames maelstrom_plus to havoc before looking a circumstance up
  if id then id=id:gsub("maelstrom_plus","havoc")end
  if id and not excluded[id]then mods[#mods+1]=id end
  local f=key:match("^havoc%-faction%-(.+)$")
  if f then if faction and faction~=f then return nil,"conflicting factions"end;faction=f end
 end end
 return C.validate({assignment_id=order.id,rank=order.data and order.data.rank,map=b.template and b.template.id,faction=faction,modifiers=mods},known)
end
function C.encode(a,known)
 local v,err=C.validate(a,known);if not v then return nil,err end
 local mods={};for i,id in ipairs(v.modifiers)do mods[i]=shorten(id)end
 local raw=table.concat({"1",v.assignment_id,tostring(v.rank),v.map,v.faction,table.concat(mods,",")},"|")
 if #raw>C.MAX_BYTES then return nil,"payload exceeds 250 bytes ("..#raw..")"end
 return raw
end
function C.decode(raw,known)
 if type(raw)~="string" or #raw==0 or #raw>C.MAX_BYTES then return nil,"invalid payload size"end
 local f=split(raw,"|");if #f~=6 or f[1]~="1"then return nil,"unsupported protocol or field count"end
 if not f[3]:match("^%d+$")then return nil,"invalid rank encoding"end
 local mods={};if f[6]~=""then for _,id in ipairs(split(f[6],","))do mods[#mods+1]=expand(id)end end
 local a,err=C.validate({assignment_id=f[2],rank=tonumber(f[3]),map=f[4],faction=f[5],modifiers=mods},known)
 if not a then return nil,err end
 local canonical=C.encode(a,known);if canonical~=raw then return nil,"noncanonical payload"end
 return a
end
return C
