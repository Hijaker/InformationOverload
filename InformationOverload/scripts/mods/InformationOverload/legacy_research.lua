-- Read-only compatibility for historical research; no live capture.
local E={}
local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
function E.merge(a,b)
 if not a and not b then return end
 local out={version=1,status="experimental",segments={}}
 local function append(v)if not v then out.segments[#out.segments+1]={version=1,status="not_recorded"}elseif v.segments then for _,segment in ipairs(v.segments)do out.segments[#out.segments+1]=copy(segment)end else out.segments[#out.segments+1]=copy(v)end end
 append(a);append(b);return out
end
return E
