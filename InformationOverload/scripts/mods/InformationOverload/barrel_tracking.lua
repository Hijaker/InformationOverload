-- Match History owns the event ledger; transient observations only correlate reports.
local B={}
function B.new()return {pending={}}end
local function ledger(m,key)
 for _,e in ipairs(m.barrel_pops or {})do if e.barrel==key then return e end end
end
local function scoped(state,m)if state.mission~=m then state.pending={};state.mission=m end end
local function append(m,key,p,actor,clock)
 if not actor or ledger(m,key)then return false end
 m.barrel_pops=m.barrel_pops or {};m.barrel_pops[#m.barrel_pops+1]={barrel=key,colour=p.colour,actor=actor.id,class=actor.class,personal=actor.personal,at=clock}
 return true
end
function B.transition(state,m,key,colour,clock,stage)
 if not m or not key or (colour~="red"and colour~="yellow")then return false end
 scoped(state,m);local p=state.pending[key];if not p or p.mission~=m then p={mission=m,colour=colour};state.pending[key]=p end
 if stage=="exploding"then
  p.exploded=clock;local e=ledger(m,key)
  if e and p.second and clock-p.second_hit<=1 then e.first_actor=e.first_actor or e.actor;e.actor=p.second.id;e.class=p.second.class;e.personal=p.second.personal;e.second_actor=p.second.id;return true end
  return false
 end
 if ledger(m,key)then return false end
 p.triggered=clock;p.colour=colour
 if p.actor and clock-p.hit>=0 and clock-p.hit<=1 then return append(m,key,p,p.actor,clock)end
 return false
end
function B.hit(state,m,key,colour,actor,clock,idle,exact)
 if not m or not key or not actor or (colour~="red"and colour~="yellow")then return false end
 scoped(state,m);local p=state.pending[key];if not p or p.mission~=m then p={mission=m,colour=colour};state.pending[key]=p end
 local e=ledger(m,key)
 if e then
  if exact=="first"or e.second_actor then return false end
  p.second=actor;p.second_hit=clock
  if exact=="second"or p.exploded and clock-p.exploded>=0 and clock-p.exploded<=1 then
   e.first_actor=e.first_actor or e.actor;e.actor=actor.id;e.class=actor.class;e.personal=actor.personal;e.second_actor=actor.id;return true
  end
  return false
 end
 if exact=="second"then
  local added=append(m,key,p,actor,clock);local recorded=ledger(m,key);if recorded then recorded.second_actor=actor.id end;return added
 end
 if p.ambiguous then return false end
 if p.triggered and clock-p.triggered>=0 and clock-p.triggered<=1 then return append(m,key,p,actor,clock)end
 -- Only the first attack on an idle barrel may be its activator.
 if idle then if p.actor and p.actor.id~=actor.id then p.actor=nil;p.ambiguous=true end;if not p.ambiguous and not p.actor then p.actor=actor;p.hit=clock end end
 return false
end
local KNOWN={barrel=true,colour=true,actor=true,class=true,personal=true,at=true,first_actor=true,second_actor=true}
local function plain(e)
 if type(e)~="table"or type(e.actor)~="string"or type(e.class)~="string"or type(e.colour)~="string"or type(e.personal)~="boolean"or type(e.at)~="number"or e.at~=e.at or math.abs(e.at)==math.huge then return false end
 if e.class:find("|",1,true)or e.colour:find("|",1,true)or type(e.barrel)~="string"and type(e.barrel)~="number"then return false end
 if e.first_actor~=nil and type(e.first_actor)~="string"or e.second_actor~=nil and type(e.second_actor)~="string"then return false end
 for k in pairs(e)do if not KNOWN[k]then return false end end
 return true
end
-- A saved match keeps its pops as columns: who popped it (the operative, their class, whether it was you, and the colour, kept together
-- in one list of the kinds the match saw), the barrel, the clocks as one line of numbers, and which pops had a first and second actor,
-- as the pop then the operative. A list holding anything else stays a list, and so does a match the next part of its mission may yet
-- join, as an older build joins pops as lists. The mission under way and its checkpoint keep the list.
function B.pack(list,joinable)
 if joinable or type(list)~="table"or type(list.kinds)=="table"or #list==0 then return list end
 local n=0;for _ in pairs(list)do n=n+1 end;if n~=#list then return list end
 for _,e in ipairs(list)do if not plain(e)then return list end end
 local ids,id_of,kinds,kind_of,k,barrel,at,first,second={},{},{},{},{},{},{},{},{}
 local function id(a)local i=id_of[a];if not i then ids[#ids+1]=a;i=#ids;id_of[a]=i end;return i end
 for i,e in ipairs(list)do
  local key=id(e.actor).."|"..e.class.."|"..tostring(e.personal).."|"..e.colour
  local j=kind_of[key];if not j then kinds[#kinds+1]={id(e.actor),e.class,e.personal,e.colour};j=#kinds;kind_of[key]=j end
  k[i]=j;barrel[i]=e.barrel;at[i]=string.format("%.17g",e.at)
  if e.first_actor then first[#first+1]=i;first[#first+1]=id(e.first_actor)end
  if e.second_actor then second[#second+1]=i;second[#second+1]=id(e.second_actor)end
 end
 return {ids=ids,kinds=kinds,k=k,barrel=barrel,at=table.concat(at,","),first=first[1]and first or nil,second=second[1]and second or nil}
end
-- a match's pops as the list the mission kept, whichever way it keeps them
function B.events(v)
 if type(v)~="table"or type(v.kinds)~="table"then return v end
 local out,kinds,ids,barrel,at={},v.kinds,v.ids or {},v.barrel or {},{}
 for x in tostring(v.at or ""):gmatch("[^,]+")do at[#at+1]=tonumber(x)end
 for i,j in ipairs(v.k or {})do local kind=kinds[j]or {};out[i]={actor=ids[kind[1]],class=kind[2],personal=kind[3],colour=kind[4],barrel=barrel[i],at=at[i]}end
 for _,f in ipairs({"first","second"})do local p=v[f];if type(p)=="table"then for j=1,#p-1,2 do local e=out[p[j]];if e then e[f.."_actor"]=ids[p[j+1]]end end end end
 return out
end
function B.lines(run,name)
 local counts={};for _,e in ipairs(B.events(run.barrel_pops)or {})do if e.actor and (e.colour=="red"or e.colour=="yellow")then local row=counts[e.actor]or {class=e.class,personal=e.personal,red=0,yellow=0};counts[e.actor]=row;row[e.colour]=row[e.colour]+1 end end
 local people={};for id,row in pairs(counts)do row.name=name(id,row.class,row.personal);people[#people+1]=row end;table.sort(people,function(a,b)return a.name<b.name end)
 local lines={};if #people>0 then lines[1]="Barrels Popped";for _,row in ipairs(people)do lines[#lines+1]=row.name;for _,colour in ipairs({"red","yellow"})do if row[colour]>0 then lines[#lines+1]=(colour=="red"and "Red"or "Yellow")..": "..row[colour]end end;lines[#lines+1]=""end end
 return lines
end
return B
