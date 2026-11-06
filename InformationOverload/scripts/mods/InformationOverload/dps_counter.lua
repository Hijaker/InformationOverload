local D={}
function D.new()return {version=1,timeout=5,total=0,useful=0,hits=0,groups={}}end
function D.update(s,t)if s.last and t-s.last>=s.timeout then s.finalized=true end end
function D.hit(s,t,total,useful,category)
 if not total or total<=0 then return end
 if s.last and t-s.last>=s.timeout then s.total=0;s.useful=0;s.hits=0;s.first=nil;s.useful_unavailable=false;s.groups={}end
 s.first=s.first or t;s.last=t;s.finalized=false;s.total=s.total+total;s.useful=s.useful+(useful or 0);s.hits=s.hits+1;s.useful_unavailable=s.useful_unavailable or useful==nil
 local key=category or "other";s.groups=s.groups or {};local g=s.groups[key]or {total=0,useful=0};s.groups[key]=g;g.total=g.total+total;g.useful=g.useful+(useful or 0);g.useful_unavailable=g.useful_unavailable or useful==nil
end
function D.lines(s,format)
 format=format or function(n)return string.format("%.1f",n)end
 if not s or not s.first then return {"Total DPS: —","Useful DPS: —"}end
 local duration=s.last-s.first;local total=duration>0 and format(s.total/duration)or "—";local useful=duration>0 and not s.useful_unavailable and format(s.useful/duration)or "—"
 local overkill=s.useful_unavailable and "Not recorded"or string.format("%.1f%%",s.total>0 and 100*(s.total-s.useful)/s.total or 0);return {"Total DPS: "..total.." ("..overkill.." Overkill)","Useful DPS: "..useful,s.finalized and "Measurement Finished"or "Measurement Active"}
end
return D
