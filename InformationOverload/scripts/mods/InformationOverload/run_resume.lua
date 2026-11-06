local M={}
function M.restore(tracker,m,c)
 if not m or m.history_recorded or not m.context or not c.mission_instance or c.mission_instance~=m.context.mission_instance or c.character~=m.context.character or c.class~=m.context.class or c.patch~=m.context.patch then return false end
 m.full=false;m.interrupted=false;m.data_only=nil;m.resumed=true;m.segments=(m.segments or 1)+1;m.context.combat_tracking_v56=true
 m.departure_snapshot=nil;m.ended_clock=nil;m.ended_wall=nil;m.ammo_seen={}
 for _,clutch in pairs(m.operative_clutches or {})do if clutch.clutches then clutch.clutches.active=nil;clutch.clutches.standing=false end end
 if m.clutches then m.clutches.active=nil;m.clutches.standing=false end
 tracker.mission=m;tracker.dirty=true
 return true
end
return M
