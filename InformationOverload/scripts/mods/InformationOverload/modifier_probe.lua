-- Opt-in bounded diagnostics. No damage mutation, extra hooks or saved aggregate writes.
return function(helpers)
 local P={active=false}
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 function P:start(t)
  assert(not self.active,'Modifier probe already active')
  self.active=true;self.started=t;self.next_actor={};self.states={};self.index={};self.events={};self.counts={local_reports=0,ally_reports=0,unresolved_attacker=0,sampled=0,throttled=0,event_cap=0,state_cap=0,buff_cap=0,errors=0};self.reason=nil;self.last_error=nil
 end
 function P:stop(reason)self.active=false;self.reason=reason or 'manual'end
 local function snapshot(self,unit)
  local ext=helpers.extension(unit,'buff_system')
  local row={available=ext~=nil,enumerable=ext~=nil and (ext._buffs_by_index~=nil or ext._buffs~=nil),buffs={}};local signatures={tostring(row.available),tostring(row.enumerable)}
  local count=0
  for _,buff in pairs(ext and (ext._buffs_by_index or ext._buffs)or {})do
   count=count+1;if count>128 then self.counts.buff_cap=self.counts.buff_cap+1;row.truncated=true;break end
   local template=buff._template;local name=buff._template_name or template and template.name
   if name then
    local stacks=false
    if type(buff.stack_count)=='function'then local v=buff:stack_count();if finite(v)then stacks=v end end
    row.buffs[#row.buffs+1]={tostring(name),stacks}
   end
  end
  table.sort(row.buffs,function(a,b)return a[1]==b[1]and tostring(a[2])<tostring(b[2])or a[1]<b[1]end)
  for _,v in ipairs(row.buffs)do signatures[#signatures+1]=v[1]..'='..tostring(v[2])end
  signatures[#signatures+1]=tostring(row.truncated);local key=table.concat(signatures,'|');local id=self.index[key]
  if id then return id end
  if #self.states>=256 then self.counts.state_cap=self.counts.state_cap+1;return false end
  self.states[#self.states+1]=row;id=#self.states;self.index[key]=id;return id
 end
 function P:observe(clock,profile,target,attacker,weakspot,damage,result,attack_type,efficiency,critical)
  if not self.active then return end
  if self.started and clock-self.started>=600 then self:stop('timeout');return end
  local info=helpers.identity(attacker)
  if not info then self.counts.unresolved_attacker=self.counts.unresolved_attacker+1;return end
  local enemy,breed=helpers.is_enemy(target);if not enemy then return end
  self.started=self.started or clock
  local scope=info.personal and 'local_reports'or 'ally_reports';self.counts[scope]=self.counts[scope]+1
  if #self.events>=2048 then self.counts.event_cap=self.counts.event_cap+1;return end
  if clock<(self.next_actor[info.id]or -math.huge)then self.counts.throttled=self.counts.throttled+1;return end
  self.next_actor[info.id]=clock+.5
  local t=Managers.time:time('gameplay')
  local event={ms=math.floor(t*1000+.5),actor=info.id,personal=info.personal==true,breed=breed and breed.name,profile=profile and profile.name,damage=damage,result=result,attack_type=attack_type,efficiency=efficiency,critical=critical==true,weakspot=weakspot==true,attacker_state=snapshot(self,attacker),target_state=snapshot(self,target)}
  local data=helpers.extension(target,'unit_data_system')
  event.target_character_state_available=false
  if data and type(data.read_component)=='function'then
   local ok,character=pcall(data.read_component,data,'character_state')
   if ok and character then event.target_character_state=character.state_name;event.target_character_state_available=character.state_name~=nil
   elseif not ok then self.counts.character_state_read_errors=(self.counts.character_state_read_errors or 0)+1 end
  end
  if not event.target_character_state_available then self.counts.character_state_unavailable=(self.counts.character_state_unavailable or 0)+1 end
  self.events[#self.events+1]=event;self.counts.sampled=self.counts.sampled+1
 end
 function P:export()return {version=2,active=self.active,reason=self.reason,basis='report_receipt; sampled at most once per actor per 0.5 seconds; not causal attribution or verified attack-time state',counts=self.counts,last_error=self.last_error,started=self.started,states=self.states,events=self.events}end
 return P
end
