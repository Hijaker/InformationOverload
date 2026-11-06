local W={};local cached=setmetatable({},{__mode="k"})
function W.profiles(template)
 if type(template)~="table"then return {}end;if cached[template]then return cached[template]end
 local result,seen={},{};local count=0
 local function walk(t,depth)
  if type(t)~="table"or seen[t]or depth>10 or count>4000 then return end;seen[t]=true;count=count+1
  for key,v in pairs(t)do
   if type(key)=="string"and key:find("damage_profile",1,true)then
    if type(v)=="table"then result[v]=true;if v.name then result[v.name]=true end
    elseif type(v)=="string"then result[v]=true end
   end
   if type(v)=="table"then walk(v,depth+1)end
  end
 end;walk(template,0);cached[template]=result;return result
end
function W.matches(template,profile)
 local set=W.profiles(template);return set[profile]==true or type(profile)=="table"and set[profile.name]==true
end
function W.attribute(info,profile,kind)
 if kind~="melee"and kind~="ranged"then return nil end
 local slot=kind=="melee"and "melee"or "ranged";local other=slot=="melee"and "ranged"or "melee"
 if W.matches(info[slot.."_template"],profile)and not W.matches(info[other.."_template"],profile)then return info[slot]end
end
function W.group(info,profile,kind,component,current_template)
 if kind~="melee"or not component or current_template~=info.melee_template then return nil end
 local name=component.current_action_name;local start=component.start_t
 local settings=type(current_template)=="table"and current_template.actions and current_template.actions[name]
 if type(start)~="number"or type(name)~="string"or not W.matches(settings,profile)then return nil end
 return tostring(component.template_name)..":"..name..":"..string.format("%.17g",start)
end
return W
