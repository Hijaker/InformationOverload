-- Game-independent owner-managed state. Transport supplies authenticated senders.
local B={};B.__index=B
local function copy(v)
 if type(v)~="table"then return v end
 local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function choice(v)return v==0 or v==1 end
local function same_assignment(a,b)
 if not a or not b then return a==b end
 for _,k in ipairs({"assignment_id","rank","map","faction"})do if a[k]~=b[k]then return false end end
 if #a.modifiers~=#b.modifiers then return false end
 for i,v in ipairs(a.modifiers)do if v~=b.modifiers[i]then return false end end
 return true
end
function B.new(myself)
 assert(type(myself)=="string"and myself~="","local identity required")
 return setmetatable({myself=myself,party=nil,members={},maps={},ready={},outgoing={},held={},actions={},consent=nil,generation=0,sequence=0},B)
end
function B:emit(kind,payload)
 local action={kind=kind,payload=copy(payload),generation=self.generation}
 for i,old in ipairs(self.actions)do
  if old.kind==kind and old.payload.recipient==payload.recipient then self.actions[i]=action;return end
 end
 self.actions[#self.actions+1]=action
end
function B:drain_actions()local actions=self.actions;self.actions={};return actions end
-- Your own votes that still stand: cast on the owner's current assignment.
function B:choices()
 local out={}
 for owner,wanted in pairs(self.outgoing)do
  local map=self.maps[owner]
  if wanted.value==1 and map and map.assignment.assignment_id==wanted.assignment_id then out[owner]=1 end
 end
 return out
end
-- Readiness is nothing but holding a vote that still stands; your own is worked out from your votes when read.
function B:own_ready()return next(self:choices())and 1 or 0 end
function B:snapshot()
 local out=copy({party=self.party,members=self.members,maps=self.maps,ready=self.ready,generation=self.generation})
 out.choices=self:choices()
 if self.members[self.myself]then out.ready[self.myself]=self:own_ready()end
 return out
end
function B:reset_choices()
 self.actions={};self.outgoing={};self.held={};self.consent=nil;self.generation=self.generation+1
 for id in pairs(self.members)do self.ready[id]=0 end
 for _,map in pairs(self.maps)do for id in pairs(self.members)do map.votes[id]=0 end end
 self:emit("publish_own",{})
 self:emit("publish_ready",{value=0})
end
-- members are keyed by account alone: a Havoc assignment is the account's, so swapping characters changes nothing on the board
function B:set_party(party,members)
 local next_members=copy(members or {})
 if not party or not next_members[self.myself]then party=nil;next_members={}end
 if party~=self.party then
  self.party=party;self.members=next_members;self.maps={};self.ready={};self:reset_choices()
  self:emit("refresh",{});return
 end
 local changed=false
 for id in pairs(self.members)do
  if not next_members[id]then
   self.maps[id]=nil;self.held[id]=nil;self.ready[id]=nil;self.outgoing[id]=nil;changed=true
   for _,map in pairs(self.maps)do map.votes[id]=nil end
  end
 end
 for id in pairs(next_members)do if not self.members[id]then
  self.ready[id]=0;changed=true;for _,map in pairs(self.maps)do map.votes[id]=0 end
 end end
 self.members=next_members
 if changed then self.consent=nil;self.actions={};self.generation=self.generation+1;self:emit("refresh",{});self:emit("publish_own",{});self:emit("publish_ready",{value=self:own_ready()})end
end
-- assignment must already have passed the shared codec. Caller supplies owner identity.
function B:receive_assignment(owner,assignment,votes)
 if not self.members[owner]then return nil,"owner is not in strike team"end
 if assignment==nil then
  self.maps[owner]=nil;self.held[owner]=nil;self.outgoing[owner]=nil
  if self.consent and self.consent.owner==owner then self.consent=nil end
  return true
 end
 local previous=self.maps[owner];local before=previous and previous.assignment or self.held[owner]
 local unchanged=before~=nil and same_assignment(before,assignment)
 local next_votes={}
 for id in pairs(self.members)do
  local v=votes and votes[id]
  if v~=nil and not choice(v)then return nil,"invalid vote snapshot"end
  next_votes[id]=v~=nil and v or unchanged and previous and previous.votes[id]or 0
 end
 self.maps[owner]={assignment=copy(assignment),votes=next_votes};self.held[owner]=nil
 if not unchanged then
  self.outgoing[owner]=nil
  -- consent outlives the owner briefly dropping out and coming back with the same assignment
  if self.consent and self.consent.owner==owner and self.consent.assignment_id~=assignment.assignment_id then self.consent=nil end
 end
 return true
end
-- A peer that lapses takes its map, and its votes on yours, until its frames bring them back. Your vote on its assignment is
-- kept, to stand again if it returns with that same assignment.
function B:lapse(owner)
 local map=self.maps[owner]
 if map then self.held[owner]=map.assignment end
 self.maps[owner]=nil;self.ready[owner]=0
 local own=self.maps[self.myself];if own then own.votes[owner]=0 end
end
function B:request_vote(owner,value)
 if not choice(value)then return nil,"vote must be 1 or 0"end
 local map=self.maps[owner];if not map or not self.members[self.myself]then return nil,"assignment unavailable"end
 local request={recipient=owner,assignment_id=map.assignment.assignment_id,value=value}
 self.outgoing[owner]=copy(request)
 if owner==self.myself then return self:receive_vote(self.myself,request)end
 self:emit("send_vote",request);return true
end
function B:receive_vote(sender,request)
 if not self.members[sender]then return nil,"sender is not in strike team"end
 local own=self.maps[self.myself]
 if not own or request.recipient~=self.myself or request.assignment_id~=own.assignment.assignment_id then
  self:emit("publish_own",{});return nil,"assignment changed; refresh and choose again"
 end
 if not choice(request.value)then return nil,"invalid vote"end
 own.votes[sender]=request.value;self:emit("publish_own",{});return true
end
function B:receive_ready(sender,value)
 if sender==self.myself or not self.members[sender]or not choice(value)then return nil,"invalid readiness sender/value"end
 self.ready[sender]=value;return true
end
function B:prepare_start(owner,now)
 local map=self.maps[owner]
 if not map then return nil,"assignment unavailable"end
 self.sequence=self.sequence+1
 local request={recipient=owner,assignment_id=map.assignment.assignment_id,id=tostring(now).."-"..self.sequence,expires=now+30}
 self.consent={owner=owner,assignment_id=request.assignment_id,attempt=request.id,expires=request.expires}
 return copy(request)
end
-- A verified game adapter must correlate a prompt with owner, assignment and attempt.
-- Unknown correlation is represented by nil and never consumes temporary consent.
function B:prompt_decision(category,owner,assignment,attempt,now)
 if category~="havoc"then return "manual"end
 local c=self.consent
 if c and c.expires<now then self.consent=nil;c=nil end
 if c and owner==c.owner and assignment==c.assignment_id and attempt==c.attempt then return "yes"end
 if not owner or not assignment then return "manual"end
 local map=self.maps[owner]
 if not map or map.assignment.assignment_id~=assignment then return "manual"end
 -- Only your own choice counts, at once and before the owner confirms it; the owner's copy of it can lag a take-back or a lapse.
 local wanted=self.outgoing[owner]
 local vote=wanted and wanted.assignment_id==assignment and wanted.value or 0
 return vote==1 and "yes" or "manual"
end
function B:attempt_finished(accepted)
 if accepted then self:reset_choices()else self.consent=nil end
end
return B
