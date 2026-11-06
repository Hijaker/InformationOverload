-- Diagnostic timing only. Never reads history, collects garbage, or changes a save.
local T={}
function T.new(mod,context)
 local now,label
 local ffi=Mods and Mods.lua and Mods.lua.ffi
 if ffi then
  pcall(ffi.cdef,"int QueryPerformanceCounter(int64_t *c); int QueryPerformanceFrequency(int64_t *f);")
  local ok,clock=pcall(function()
   local frequency,counter=ffi.new("int64_t[1]"),ffi.new("int64_t[1]")
   assert(ffi.C.QueryPerformanceFrequency(frequency)~=0 and tonumber(frequency[0])>0)
   local scale=1000/tonumber(frequency[0])
   return function()assert(ffi.C.QueryPerformanceCounter(counter)~=0);return tonumber(counter[0])*scale end
  end)
  if ok then now,label=clock,"wall"end
 end
 if not now then local system=Mods and Mods.lua and Mods.lua.os or os;now=function()return system.clock()*1000 end;label="clock-fallback"end
 local last={};local trace={}
 function trace.start()local ok,value=pcall(now);if ok then return value end end
 local function finish(tag,began)
   local ended=now();local ms=ended-began;if ms<50 then return end
   local name=tag
   if type(tag)=="function"then local info=debug.getinfo(tag,"S");name=tostring(info.short_src or info.source)..":"..tostring(info.linedefined)end
   if last[name]and ended-last[name]<1000 then return end;last[name]=ended
   if mod.info then mod:info("I/O slow %s: %.1f ms (%s), heap %.1f MB; %s",tostring(name),ms,label,collectgarbage("count")/1024,context and context()or "")end
 end
 function trace.finish(tag,began)
  -- A diagnostic failure must not escape into the callback being measured.
  if began then pcall(finish,tag,began)end
 end
 return trace
end
return T
