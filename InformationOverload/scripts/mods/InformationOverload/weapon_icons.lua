-- Information Overload: a weapon's HUD icon from the game's item list, found by its template and else by the name it shows; nil until
-- the material is loaded. The Weapons page and the End Screen card both draw it.
local W={}
local ICONS
local function build()
 local okm,Master=pcall(require,"scripts/backend/master_items");local oki,Items=pcall(require,"scripts/utilities/items")
 if not okm or not oki or type(Master)~="table"or type(Items)~="table"then return end
 local ok,items=pcall(Master.get_cached);if not ok or type(items)~="table"or not next(items)then return end
 local t,n={},{}
 for id,it in pairs(items)do if type(it)=="table"and type(it.hud_icon)=="string"and it.weapon_template and (it.item_type=="WEAPON_MELEE"or it.item_type=="WEAPON_RANGED")then
  local main=tostring(id):find("^content/items/weapons/player/")~=nil;t[it.weapon_template]=t[it.weapon_template]or it.hud_icon;t[tostring(id):match("([^/]+)$")]=it.hud_icon
  local okn,label=pcall(Items.display_name,it)
  if okn and type(label)=="string"and label~=""then for _,l in ipairs({label,(label:gsub("[Cc]hordclaw","Transonic Claw"))})do if main or not n[l]then n[l]=it.hud_icon end end end
 end end
 ICONS={t=t,n=n}
end
function W.of(name,tmpl)
 if not ICONS then build()end;if not ICONS then return end
 local path=tmpl and ICONS.t[tmpl]or ICONS.n[name]
 if path and Application and Application.can_get_resource and Application.can_get_resource("material",path)then return path end
end
return W
