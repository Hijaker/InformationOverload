local C={}
local incapacitated={knocked_down=true,dead=true,hogtied=true}
function C.sample(m,states,own)
 if not m or not own or m.context.difficulty=="psykhanium"then return end
 local own_state=states[own];if not own_state then return end
 m.clutches=m.clutches or {episodes=0,seen=false};local c=m.clutches
 local own_ready=not incapacitated[own_state]and own_state~="pounced"and own_state~="netted"and own_state~="mutant_charged"
 local living,down,unknown,has_down=0,{},false,false
 for id,state in pairs(states)do if state=="unknown"then unknown=true elseif incapacitated[state]then if id~=own then down[id]=true;if state=="knocked_down"then has_down=true end end else living=living+1 end end
 local standing=not unknown and not incapacitated[own_state]and living==1 and next(down)~=nil
 if standing and not c.standing then c.attempts=(c.attempts or 0)+1 end;c.standing=standing
 if c.active and not unknown and own_ready and living==1 and next(down)and not has_down then c.active_kind="full"end
 if c.active then
  if incapacitated[own_state]or own_state=="unknown"then c.active=nil
  else for id in pairs(c.active)do local state=states[id];if state and state~="unknown"and not incapacitated[state]then if m.clutch_bot_recovered and m.clutch_bot_recovered[id]then c.active=nil;break end;c.episodes=c.episodes+1;local field=c.active_kind=="full"and "full_episodes"or "semi_episodes";c[field]=(c[field]or 0)+1;c.active=nil;break end end end
 end
 if not unknown and own_ready and living==1 and next(down)and not c.active then c.active=down;c.active_kind=has_down and "semi"or "full";c.seen=true end
end
return C
