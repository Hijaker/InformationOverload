-- Information Overload: Copy Build. A saved operative's talents go into a new loadout preset on the character being played, the same
-- class only: every pick the character's points allow, from the top of the tree down, the rest left out; its gear is the character's own.
local B={}
local function game(path)local ok,m=pcall(require,path);return ok and type(m)=="table"and m or nil end
local CLASS={veteran="Veteran",zealot="Zealot",psyker="Psyker",ogryn="Ogryn",adamant="Arbitrator",broker="Hive Scum",cryptic="Skitarius"}
function B.class_name(arch)return CLASS[arch]or tostring(arch or "")end
-- the picks kept from want (widget name to points) within budget: the start's way down, top first, a node taken only once the links it
-- needs are taken (all of them where the node asks, else one) and enough points are spent, a pick costing its points times the node's cost
-- (the Stimm Lab's run 1 to 5); budget nil keeps every pick that links up
function B.trim(layout,want,budget)
 local by,start={},nil
 for _,n in ipairs(layout.nodes or {})do by[n.widget_name]=n;if n.type=="start"then start=n.widget_name end end
 local kept,spent={},0
 if start then kept[start]=true end
 while true do
  local best
  for name in pairs(want)do local n=by[name]
   if n and not kept[name]and (not budget or (n.cost or 1)*want[name]<=budget-spent)then
    local r=n.requirements or {};local any,all=false,true
    for _,p in ipairs(n.parents or {})do if kept[p]then any=true else all=false end end
    local ok=(r.all_parents_chosen and all)or (not r.all_parents_chosen and any)
    if r.min_points_spent and spent<r.min_points_spent then ok=false end
    if ok and (not best or n.y<best.y or n.y==best.y and n.x<best.x)then best=n end
   end
  end
  if not best then break end
  kept[best.widget_name]=true;spent=spent+(best.cost or 1)*want[best.widget_name]
 end
 if start then kept[start]=nil end
 local out,n={},0;for name in pairs(kept)do out[name]=want[name];n=n+1 end
 return out,n,spent
end
-- the gear in the preset: each slot's item as the game keeps it in a preset, its gear id, else its name for an item always owned
local function loadout(profile)
 local lo={}
 -- only the slots the game keeps in a preset: shown in the inventory and open to this class
 local Slots=game("scripts/settings/item/item_slot_settings");local arch=profile.archetype and profile.archetype.name
 local function kept(slot)if not Slots then return true end;local d=Slots[slot];if type(d)~="table"or not d.equipped_in_inventory then return false end
  local r=d.archetype_restrictions;if type(r)=="table"and next(r)then for _,a in ipairs(r)do if a==arch then return true end end;return false end;return true end
 for slot,item in pairs(profile.loadout or {})do if type(item)=="table"and kept(slot)then
  local g=item.gear_id;local v=type(g)=="string"and g:find("^%x+%-%x+%-%x+%-%x+%-%x+$")and g or item.name
  if v then lo[slot]=v end
 end end
 return lo
end
-- what the button can do now: nil and why it can't, or the character, the presets and the room left
function B.check(snap)
 local P=game("scripts/utilities/profile_utils")
 local pm=Managers and Managers.player;local player=pm and pm:local_player(1);local profile=player and player:profile()
 if not P or not profile or not profile.archetype then return nil,"Copy Build works once your character is loaded."end
 if snap.archetype and snap.archetype~=profile.archetype.name then
  return nil,"This is a "..B.class_name(snap.archetype).." build. Switch to a "..B.class_name(snap.archetype).." to copy it."end
 -- the game's own limit as it stands now, so a mod that raises it (More Characters And Loadouts sets 12) is followed
 local S=rawget(_G,"ViewElementProfilePresetsSettings")or game("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")
 local max=type(S)=="table"and tonumber(S.max_profile_presets)or 8
 local ok,list=pcall(P.get_profile_presets);list=ok and type(list)=="table"and list or {}
 if #list>=max then return nil,"All loadout presets are in use. Delete one in your inventory to copy this build.","full"end
 return {P=P,player=player,profile=profile,count=#list,max=max}
end
-- the copy itself: a new preset with as many of the build's talents as the character can have; gives true and what was copied, or nil and why
function B.copy(snap)
 local c,why=B.check(snap);if not c then return nil,why end
 local profile,P=c.profile,c.P
 local TLP=game("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
 local main=game(profile.archetype.talent_layout_file_path or "")
 if not TLP or not main then return nil,"This class's talent tree could not be read."end
 local spec=profile.archetype.specialization_talent_layout_file_path and game(profile.archetype.specialization_talent_layout_file_path)
 local want_main,want_spec,total={},{},0
 -- a pick whose node the layout no longer has is found by its talent id, as the Build page lights it
 local in_main,in_spec,id_main,id_spec={},{},{},{}
 local function index(tree,by,ids)for _,n in ipairs(tree.nodes or {})do by[n.widget_name]=true;if n.type~="start"and n.type~="stat"and n.talent then ids[n.talent]=ids[n.talent]or n.widget_name end end end
 index(main,in_main,id_main);if spec then index(spec,in_spec,id_spec)end
 for _,t in ipairs(type(snap.talents)=="table"and snap.talents or {})do
  local pts=type(t.rank)=="number"and t.rank>0 and t.rank or 1
  local node=t.node;if not (node and (in_main[node]or in_spec[node]))then node=t.id and (id_main[t.id]or id_spec[t.id])end
  if node and in_main[node]then want_main[node]=pts;total=total+1 elseif node and in_spec[node]then want_spec[node]=pts;total=total+1 end
 end
 if total==0 then return nil,"No talents from this build fit your character's tree."end
 -- each tree within its own points: the talents within the character's talent points, the Stimm Lab within its own; what links up at
 -- any level against what the points allow tells the picks left for points apart from those the tree no longer has a way to
 local kept,n=B.trim(main,want_main,tonumber(profile.talent_points))
 local _,linked=B.trim(main,want_main,nil)
 if spec then local ks,m=B.trim(spec,want_spec,tonumber(profile.expertise_points)or 0);for k,v in pairs(ks)do kept[k]=v end;n=n+m
  local _,l=B.trim(spec,want_spec,nil);linked=linked+l end
 if n==0 then return nil,linked==0 and "None of this build's talents link up in your character's tree any more."or "Your character doesn't have the points for any of this build's talents yet."end
 local ok,id,entry=pcall(P.add_profile_preset)
 if not ok or not id or type(entry)~="table"then return nil,"The preset could not be made."end
 entry.loadout=loadout(profile)
 local okv,version=pcall(TLP.talents_version,profile);if not okv or type(version)~="string"then version=nil end
 local oks=pcall(P.save_talent_nodes_for_profile_preset,id,kept,version)
 if not oks then pcall(P.remove_profile_preset,id);return nil,"The preset could not be saved, so none was made."end
 return true,n,total,c.count+1,{points=linked-n,unlinked=total-linked}
end
return B
