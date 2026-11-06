local mod=type(get_mod)=="function"and get_mod("information_overload")
local parameters=mod and mod.io_dofile and mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/departure_parameters")or {}
local D={end_window=parameters.end_window or 60}
local function wall()return os and os.time and os.time()or nil end
local incapacitated={knocked_down=true,dead=true,hogtied=true}
function D.hit(m,id,at,cause)
 if m and m.context.mode=="havoc"and id then m.leave_hits=m.leave_hits or {};m.leave_hits[id]={at=at,cause=cause}end
end
function D.fall_death(m,id,at)
 local hit=m and m.leave_hits and m.leave_hits[id];if hit and at-hit.at<=2 then hit.failed=true end
end
function D.sample(m,people,bots,at)
 if not m or m.context.difficulty=="psykhanium"then return end
 local prev=m.departure_snapshot
 m.all_departures=m.all_departures or {};m.departure_events=m.departure_events or {};m.bot_links=m.bot_links or {};m.bot_candidates=m.bot_candidates or {};m.bot_appearances=m.bot_appearances or {}
 if prev then
  local departures={};for id,p in pairs(prev.people)do if not people[id]then departures[#departures+1]=p end end
  if #departures>0 then
   if #departures>1 or m.last_departure and at-m.last_departure<5 then for _,candidate in pairs(m.bot_candidates)do if at-candidate.at<5 then candidate.ambiguous=true end end end
   for _,p in ipairs(departures)do
    m.all_departures[#m.all_departures+1]={player=p.key,character_id=p.id,name=p.name,class=p.class,personal=p.personal,steam_id=p.steam_id,steam_name=p.steam_name,at=at,wall_at=wall()}
    for _,row in pairs(m.context.operative_roster or {})do if row.account_id==p.key or row.steam_id==p.steam_id and p.steam_id then row.left=true end end
    local clutch=m.operative_clutches and m.operative_clutches[p.key];if clutch and clutch.clutches then clutch.clutches.active=nil;clutch.clutches.standing=false end
    local hit=m.leave_hits and m.leave_hits[p.id]
    if m.context.mode=="havoc"and (p.state=="netted"or hit and at-hit.at<=2)then
     local failed=hit and hit.failed==true or false
     m.departure_events[#m.departure_events+1]={player=p.key,name=p.name,class=p.class,personal=p.personal,at=at,wall_at=wall(),cause=p.state=="netted"and "Trapper net"or hit.cause,failed=failed,steam_id=p.steam_id,steam_name=p.steam_name}
    end
    local all_down=true;local teammates=0
    for _,old in pairs(prev.people)do teammates=teammates+1;if not incapacitated[old.state]then all_down=false end end
    if all_down and teammates>=2 then m.bot_candidates[#m.bot_candidates+1]={player=p.key,name=p.name,class=p.class,personal=p.personal,steam_id=p.steam_id,steam_name=p.steam_name,at=at,ambiguous=#departures~=1 or m.last_departure and at-m.last_departure<5 or false}end
   end
   m.last_departure=at
  end
  local newcomers={};for id in pairs(bots)do if not prev.bots[id]then m.bot_appearances[id]=at end;if not m.bot_links[id]and at-(m.bot_appearances[id]or -100)<=5 then newcomers[#newcomers+1]=id end end
  if #newcomers==1 then local candidate
   for _,c in ipairs(m.bot_candidates)do if not c.bot and not c.ambiguous and at-c.at<=5 then if candidate then candidate.ambiguous=true;c.ambiguous=true;candidate=nil;break end;candidate=c end end
   if candidate then local bot=newcomers[1];candidate.bot=bot;m.bot_links[bot]=candidate;candidate.pickups=(candidate.pickups or 0)+(m.bot_pickup_events and m.bot_pickup_events[bot]or 0);if m.bot_pickup_events then m.bot_pickup_events[bot]=nil end end
  elseif #newcomers>1 then for _,c in ipairs(m.bot_candidates)do if not c.bot and at-c.at<=5 then c.ambiguous=true end end end
  for _,e in ipairs(m.all_departures)do if people[e.player]then e.returned=true;e.returned_at=at;e.returned_wall=wall()end end
  for _,e in ipairs(m.departure_events)do if people[e.player]then local p=people[e.player];e.returned=true;e.steam_id=e.steam_id or p.steam_id;e.steam_name=p.steam_name or e.steam_name end end
  for _,c in ipairs(m.bot_candidates)do if people[c.player]then local p=people[c.player];c.returned=true;c.steam_id=c.steam_id or p.steam_id;c.steam_name=p.steam_name or c.steam_name end end
 end
 m.departure_snapshot={people=people,bots=bots};m.last_observed_clock=at
end
function D.bot_pickup(m,bot)
 local c=m and m.bot_links and m.bot_links[bot]
 if c and not c.ambiguous then c.pickups=(c.pickups or 0)+1;return true end
 return false
end
function D.observe_bot_pickup(m,bot)
 if D.bot_pickup(m,bot)then return true end
 m.bot_pickup_events=m.bot_pickup_events or {};m.bot_pickup_events[bot]=(m.bot_pickup_events[bot]or 0)+1;return true
end
function D.finalize(m,at)
 local kept=m.clutches_by_bot;m.leave_abuse={};m.failed_leave_abuse={};m.clutches_by_bot=m.bot_candidates and {}or kept or {}
 if m.all_departures then local absent={};for _,e in ipairs(m.all_departures)do e.seconds_before_end=m.ended_wall and e.wall_at and math.max(0,m.ended_wall-e.wall_at)or at and math.max(0,at-e.at)or e.seconds_before_end;if not e.returned and (e.personal or e.seconds_before_end and e.seconds_before_end>D.end_window)then absent[e.player]=true end end
  m.players_left=0;for _ in pairs(absent)do m.players_left=m.players_left+1 end
  m.context.departure_summary={};for _,e in ipairs(m.all_departures)do m.context.departure_summary[e.player]={returned=e.returned==true,seconds_before_end=e.seconds_before_end}end
  for id,row in pairs(m.context.operative_roster or {})do row.left=absent[row.account_id or id]==true end
 end
 local function add(list,e)local key=e.player;local row=list[key]or {name=e.name,class=e.class,personal=e.personal,count=0};list[key]=row;row.count=row.count+1;row.steam_id=e.steam_id;row.steam_name=e.steam_name;if e.eligible then row.tally_count=(row.tally_count or 0)+1 end end
 for _,e in ipairs(m.departure_events or {})do
  e.seconds_before_end=m.ended_wall and e.wall_at and math.max(0,m.ended_wall-e.wall_at)or at and math.max(0,at-e.at)or e.seconds_before_end
  e.eligible=e.returned or e.seconds_before_end and e.seconds_before_end<=D.end_window or false
  if e.failed then add(m.failed_leave_abuse,e)
  elseif e.eligible then add(m.leave_abuse,e)end
 end
 for _,c in ipairs(m.bot_candidates or {})do if not c.ambiguous and c.returned and (c.pickups or 0)>0 then add(m.clutches_by_bot,c)end end
end
function D.capture_self(m,at)
 if not m or m.context.mode~="havoc"or not m.context.mission_instance then return end
 for _,p in pairs(m.departure_snapshot and m.departure_snapshot.people or {})do if p.personal then
  local hit=m.leave_hits and m.leave_hits[p.id]
  if p.state=="netted"or hit and at-hit.at<=2 then
   return {session=m.context.mission_instance,attempt={player=p.key,name=p.name,class=p.class,personal=true,at=at,wall_at=wall(),cause=p.state=="netted"and "Trapper net"or hit.cause,failed=hit and hit.failed==true or false,steam_id=p.steam_id,steam_name=p.steam_name}}
  end
 end end
end
function D.restore_self(tracker,people)
 local pending=tracker.data.self_leave_pending;local m=tracker.mission
 if not pending or not m or not m.context.mission_instance then return false end
 if m.context.mission_instance~=pending.session then tracker.data.self_leave_pending=nil;tracker.dirty=true;return false end
 local p=people[pending.attempt.player]
 if not p or not p.personal then return false end
 local e=pending.attempt;e.steam_id=e.steam_id or p.steam_id;e.steam_name=p.steam_name or e.steam_name;e.returned=true;e.self_rejoin=true;m.departure_events=m.departure_events or {};m.departure_events[#m.departure_events+1]=e
 tracker.data.self_leave_pending=nil;tracker.dirty=true;return true
end
return D
