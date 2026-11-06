-- Periodic observed state. Values are fractions; missing is false, never zero.
local R={version=1,interval=.5,max_samples=100000,max_members=16}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function R.new(data)return {data=data or {version=1,clock='gameplay',interval_seconds=R.interval,members={},samples=0,dropped=0},units={}}end
function R.sample(s,id,personal,unit,t,value)
 if not id or not finite(t)then return end
 local d=s.data;local row=d.members[id]
 if not row then local n=0;for _ in pairs(d.members)do n=n+1 end;if n>=R.max_members then d.dropped=d.dropped+1;return end
 row={personal=personal==true,source=personal and 'local_component'or 'replicated_component',segments={}};d.members[id]=row end
 local prev=s.units[id];local ms=math.floor(t*1000+.5)
 if prev and prev.unit==unit and ms>=prev.ms and ms-prev.ms<R.interval*1000 then return end
 if d.samples>=R.max_samples then d.dropped=d.dropped+1;return end
 local segment=row.segments[#row.segments]
 if not prev or prev.unit~=unit or ms<prev.ms or ms-prev.ms>1000 then segment={samples={}};row.segments[#row.segments+1]=segment end
 local valid=finite(value)and value>=0 and value<=1
 segment.samples[#segment.samples+1]={ms,valid and value or false}
 d.samples=d.samples+1;s.units[id]={unit=unit,ms=ms}
end
return R
