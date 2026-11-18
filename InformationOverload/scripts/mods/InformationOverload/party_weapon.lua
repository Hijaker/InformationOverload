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
function W.slot(template)
 for _,keyword in ipairs(template.keywords or {})do
  if keyword=="melee"or keyword=="ranged"then return keyword end
 end
end
local function ranged_bash(slot,kind)
 return slot=="ranged" and kind=="melee"
end
function W.action_special(template,action,slot,kind,name)
 action=action or {}
 name=name or action.name
 return ranged_bash(slot,kind) or action.kind=="melee_explosive"
  or (action.start_input or ""):match("^special_action")~=nil
  or name~=nil and (name==template.special_action_name or name:match("_special$")~=nil)
end
-- Uncorrelated reports can still identify a weapon when exactly one equipped
-- template owns the profile. Powered variants sharing a profile stay unknown.
local special_profiles=setmetatable({},{__mode="k"})
local function special_mode(template,profile)
 local modes=special_profiles[template]
 if not modes then
  modes={}
  local function mark(profiles,mode)
   for p in pairs(profiles)do
    local previous=modes[p]
    if previous==nil then modes[p]=mode elseif previous~=mode then modes[p]="unknown"end
   end
  end
  for name,action in pairs(template.actions or {})do
   local special=W.action_special(template,action,nil,nil,name)
   if special then mark(W.profiles(action),true)
   else
    for key,value in pairs(action)do
     if type(key)=="string" and key:find("damage_profile",1,true)then
      mark(W.profiles({[key]=value}),key:find("special",1,true)~=nil)
     elseif type(value)=="table" then
      mark(W.profiles(value),type(key)=="string"and key:find("special",1,true)~=nil)
     end
    end
   end
  end
  special_profiles[template]=modes
 end
 local mode=modes[profile]
 if mode==nil and type(profile)=="table"then mode=modes[profile.name]end
 if type(mode)=="boolean"then return mode end
end
function W.damage_slot(info,profile,kind)
 -- Force Greatsword wind slash is emitted by a buff after the swing.
 local tweaks=info.melee_template and info.melee_template.weapon_special_tweak_data
 if tweaks and W.matches(tweaks.slash_settings,profile)then return "melee",true end
 if kind~="melee"and kind~="ranged"and kind~="explosion"then return end
 local melee,ranged=W.matches(info.melee_template,profile),W.matches(info.ranged_template,profile)
 if melee==ranged then return end
 local slot=melee and "melee"or "ranged"
 if ranged_bash(slot,kind)then return slot,true end
 return slot,special_mode(info[slot.."_template"],profile)
end
function W.group(info,profile,kind,component,current_template)
 if kind~="melee"or not component or current_template~=info.melee_template then return nil end
 local name=component.current_action_name;local start=component.start_t
 local settings=type(current_template)=="table"and current_template.actions and current_template.actions[name]
 if type(start)~="number"or type(name)~="string"or not W.matches(settings,profile)then return nil end
 return tostring(component.template_name)..":"..name..":"..string.format("%.17g",start)
end
return W
