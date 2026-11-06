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
function B.lines(run,name)
 local counts={};for _,e in ipairs(run.barrel_pops or {})do if e.actor and (e.colour=="red"or e.colour=="yellow")then local row=counts[e.actor]or {class=e.class,personal=e.personal,red=0,yellow=0};counts[e.actor]=row;row[e.colour]=row[e.colour]+1 end end
 local people={};for id,row in pairs(counts)do row.name=name(id,row.class,row.personal);people[#people+1]=row end;table.sort(people,function(a,b)return a.name<b.name end)
 local lines={};if #people>0 then lines[1]="Barrels Popped";for _,row in ipairs(people)do lines[#lines+1]=row.name;for _,colour in ipairs({"red","yellow"})do if row[colour]>0 then lines[#lines+1]=(colour=="red"and "Red"or "Yellow")..": "..row[colour]end end;lines[#lines+1]=""end end
 return lines
end
return B
