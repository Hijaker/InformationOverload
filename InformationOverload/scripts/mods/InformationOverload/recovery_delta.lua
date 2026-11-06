-- Compact aggregate changes since mission start. Completed history is immutable
-- and referenced separately by the recovery baseline, never copied into a delta.
local D={}
local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
function D.capture(before,current,touched)
 local out={version=1,set={},remove={}};local path={}
 local function visit(a,b)
  if a==b then return end
  if type(a)=="table"and type(b)=="table"then
   if #path==1 and path[1]=="rows"and touched then
    for k in pairs(touched)do
     path[2]=k;visit(a[k],b[k]);path[2]=nil
    end
    return
   end
   local depth=#path+1
   for k,v in pairs(b)do
    if (#path>0 or k~="run_history")and a[k]~=v then
     path[depth]=k;visit(a[k],v);path[depth]=nil
    end
   end
   for k in pairs(a)do
    if b[k]==nil and (#path>0 or k~="run_history")then
     path[depth]=k;out.remove[#out.remove+1]=copy(path);path[depth]=nil
    end
   end
  elseif b==nil then out.remove[#out.remove+1]=copy(path)
  else out.set[#out.set+1]={path=copy(path),value=copy(b)}end
 end
 visit(before or {},current or {});return out
end
function D.apply(before,delta,history)
 assert(type(delta)=="table"and delta.version==1,"Unsupported recovery progress")
 local out={};for k,v in pairs(before or {})do if k~="run_history"then out[k]=copy(v)end end
 out.run_history=history or before and before.run_history or {}
 local function parent(path)
  assert(type(path)=="table"and #path>0 and path[1]~="run_history","Invalid recovery path")
  local t=out;for i=1,#path-1 do local k=path[i];if type(t[k])~="table"then t[k]={}end;t=t[k]end;return t,path[#path]
 end
 for _,entry in ipairs(delta.set or {})do local t,k=parent(entry.path);t[k]=copy(entry.value)end
 for _,path in ipairs(delta.remove or {})do local t,k=parent(path);t[k]=nil end
 return out
end
return D
