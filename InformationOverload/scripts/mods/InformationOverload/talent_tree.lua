-- Information Overload: a class's talent tree from the game's own layout and node art, a build's picks lit, and the talent screen's hover card on every node.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Tip=mod:io_dofile(base.."io_game_tip")
local C=D.c
local T={}
local ICON="content/ui/materials/frames/talents/talent_icon_container"
local FRAME,MASK="content/ui/textures/frames/talents/circular_frame","content/ui/textures/frames/talents/circular_frame_mask"
local SMALL_SELECTED,ROUND_SELECTED="content/ui/materials/frames/talents/circular_small_frame_selected","content/ui/materials/frames/talents/circular_frame_selected"
-- a stat boost is its own small disc, as the talent screen draws it, not an icon in a frame
local SMALL_BG="content/ui/materials/frames/talents/circular_small_bg"
-- the talent screen's paths: a picked one pale with a glow round it, the rest dark
local WHITE,LINE,LIT,GLOW=D.rgba(255,255,255),D.rgba(42,55,59),D.rgba(224,250,255),D.rgba(99,167,176,.7)
local trees={}
-- the talent screen's frames and each class's icons sit in packages the game may not have loaded, in a mission above all; they are held while the panel draws a tree
local VIEW_PACKAGE="packages/ui/views/talent_builder_view/talent_builder_view"
-- each tree's layout file and the package holding its icons, as the class names them; the Stimm Lab's centre frame is in its own screen's package
local PATHS={main={"talent_layout_file_path","talents_package_path"},stimm={"specialization_talent_layout_file_path","specialization_talent_package_path","packages/ui/views/broker_stimm_builder_view/broker_stimm_builder_view"}}
local held={}
local function art_ready(tree)
 local pm=Managers and Managers.package;if not pm then return true end
 local ready,list=true,{VIEW_PACKAGE,tree.arch[PATHS[tree.which][2]],PATHS[tree.which][3]}
 for i=1,3 do local p=list[i];if type(p)=="string"then
  if not held[p]then local ok,id=pcall(pm.load,pm,p,"information_overload",nil);if ok then held[p]=id end end
  local ok,done=pcall(pm.has_loaded,pm,p);if not (ok and done)then ready=false end
 end end
 return ready
end
local function loaded(kind,path)return path==nil or not (Application and Application.can_get_resource)or Application.can_get_resource(kind,path)end
function T.release()local pm=Managers and Managers.package;for p,id in pairs(held)do if pm then pcall(pm.release,pm,id)end;held[p]=nil end end
mod.io_release_talent_art=T.release
local function game(path)local ok,m=pcall(require,path);return ok and type(m)=="table"and m or nil end
local function valid(s)return type(s)=="string"and s~=""and not s:find("<unlocalized",1,true)end
-- a class's tree, read once: each node centred in the layout's units, with its kind's size, frame and colours; stimm asks for the Hive Scum's Stimm Lab instead of the talents
function T.load(name,which)
 if type(name)~="string"then return nil end
 which=PATHS[which]and which or "main";local key=name.."|"..which
 if trees[key]~=nil then return trees[key]or nil end
 local tree=false
 local archetypes=game("scripts/settings/archetype/archetypes");local arch=archetypes and archetypes[name]
 local path=arch and arch[PATHS[which][1]]
 local layout=type(path)=="string"and game(path)
 local settings=game("scripts/ui/views/talent_builder_view/talent_builder_view_settings");local by_type=settings and settings.settings_by_node_type
 if layout and type(layout.nodes)=="table"and type(by_type)=="table"then
  local cls=type(arch.archetype_name)=="string"and Localize(arch.archetype_name)
  tree={name=name,key=key,which=which,arch=arch,class=valid(cls)and cls or Overview.class_names[name]or name,nodes={},by_name={}}
  for _,n in ipairs(layout.nodes)do
   local s=by_type[n.type]or by_type.default or {};local size=type(s.size)=="table"and s.size[1]or 80
   local node={name=n.widget_name,type=n.type,talent=n.talent,icon=n.icon,cost=n.cost or 0,children=n.children or {},x=(n.x or 0)+size/2,y=(n.y or 0)+size/2,size=size,s=s}
   if node.name then tree.nodes[#tree.nodes+1]=node;tree.by_name[node.name]=node end
  end
  if #tree.nodes==0 then tree=false end
 end
 trees[key]=tree;return tree or nil
end
-- the class a saved build belongs to: saved with it, else the one class whose talents hold every talent it names
function T.class_of(snapshot,hint)
 if type(snapshot.archetype)=="string"then return snapshot.archetype end
 local archetypes=game("scripts/settings/archetype/archetypes");if not archetypes then return hint end
 if hint and archetypes[hint]then return hint end
 local found
 for name,arch in pairs(archetypes)do if type(arch)=="table"and type(arch.talents)=="table"then local all=true
  for _,t in ipairs(snapshot.talents or {})do if t.id and not arch.talents[t.id]then all=false;break end end
  if all and #(snapshot.talents or {})>0 then if found then return hint end;found=name end
 end end
 return found or hint
end
-- the nodes a saved build picked and the points they cost; a node the layout no longer has, or a build saved before nodes were named, is matched by talent, stat boosts left out as they repeat
-- a build saved before talents were kept at all has only its blitz, ability, aura and keystone by name; those nodes are lit, points left unknown, and the count of them comes back third
local NAMED={tactical="blitz",ability="ability",aura="aura",keystone="keystone"}
function T.picked(tree,snapshot)
 local set,points,by_talent={},0,{}
 for _,n in ipairs(tree.nodes)do if n.type=="start"then set[n.name]=true elseif n.type~="stat"and n.talent then by_talent[n.talent]=by_talent[n.talent]or n end end
 local talents=type(snapshot.talents)=="table"and snapshot.talents or {}
 if #talents==0 then
  if tree.which~="main"then return set,0 end
  local named,found={},0
  for field in pairs({blitz=1,ability=1,aura=1,keystone=1})do for label in (tostring(snapshot[field]or "")..","):gmatch("(.-),")do label=label:match("^%s*(.-)%s*$");if label~=""then named[field.."|"..label]=true end end end
  for _,n in ipairs(tree.nodes)do local field=NAMED[n.type];if field and named[field.."|"..T.name(tree,n)]then set[n.name]=true;found=found+1 end end
  return set,nil,found
 end
 for _,t in ipairs(talents)do
  local n=t.node and tree.by_name[t.node]or t.id and by_talent[t.id]
  if n and not set[n.name]then set[n.name]=true;points=points+(n.cost or 0)end
 end
 return set,points
end
function T.card(tree,n,on,extra)
 local Parser=game("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
 local def=tree.arch.talents and tree.arch.talents[n.talent]
 local kind=n.type=="start"and (tree.which=="stimm"and "Stimm Lab"or "Class")or valid(n.s.display_name)and Localize(n.s.display_name)or "Talent"
 local name,text
 if n.type=="start"and not def then name,text=tree.class,"Where every path starts."
 elseif def and Parser then
  local ok,t=pcall(Parser.talent_title,def,1);name=ok and valid(t)and t or nil
  local colour=Color and Color.ui_terminal and Color.ui_terminal(255,true)
  ok,t=pcall(Parser.talent_description,def,1,colour);text=ok and valid(t)and t or nil
 end
 return {kind=kind,name=name or kind,text=text,more=extra and {{"In This Match",extra}}or nil,status=n.type=="start"and "Start"or on and "Picked"or "Not Picked",lit=on}
end
-- a node's name alone, kept once read
function T.name(tree,n)
 tree.names=tree.names or {};local s=tree.names[n.name]
 if not s then s=T.card(tree,n,true).name;tree.names[n.name]=s end
 return s
end
local function hl_material(n)if n.type=="stat"then return SMALL_SELECTED end;return n.s.selected_material or ROUND_SELECTED end
-- the whole tree fitted into the box; opt.hl names a node drawn ringed, opt.extra(node) gives a node's In This Match line
function T.draw(view,cv,tree,picked,x,y,w,h,opt)
 opt=opt or {}
 local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
 for _,n in ipairs(tree.nodes)do local r=n.size/2;x0=math.min(x0,n.x-r);x1=math.max(x1,n.x+r);y0=math.min(y0,n.y-r);y1=math.max(y1,n.y+r)end
 local k=math.min(w/(x1-x0),h/(y1-y0));local ox,oy=x+(w-(x1-x0)*k)/2-x0*k,y+(h-(y1-y0)*k)/2-y0*k
 local ready=art_ready(tree);if not ready then view.redraw_at=(view.now or 0)+.5 end
 local z=cv.z;cv.z=5
 local lit={}
 for _,n in ipairs(tree.nodes)do for _,c in ipairs(n.children)do local m=tree.by_name[c]
  if m then local l={ox+n.x*k,oy+n.y*k,ox+m.x*k,oy+m.y*k};if picked[n.name]and picked[m.name]then lit[#lit+1]=l else cv:line(l[1],l[2],l[3],l[4],math.max(1.5,6*k),LINE,nil,true)end end
 end end
 for _,l in ipairs(lit)do cv:line(l[1],l[2],l[3],l[4],math.max(3,10*k),GLOW,nil,true);cv:line(l[1],l[2],l[3],l[4],math.max(1.5,4*k),LIT,nil,true)end
 for _,n in ipairs(tree.nodes)do
  local cx,cy,s,on=ox+n.x*k,oy+n.y*k,n.size*k,picked[n.name]==true
  cv.z=6
  local frame,mask=n.s.frame or FRAME,n.s.icon_mask or MASK
  -- art not loaded yet is a plain dot until it is, never a texture the game can't find
  if not ready then cv:circle(cx,cy,s*.38,on and C.gold_hi or C.frame)
  elseif n.type=="start"then if n.icon and loaded("material",n.icon)then cv:texture(n.icon,cx-s/2,cy-s/2,s,s,WHITE)else cv:circle(cx,cy,s*.38,C.gold_hi)end
  elseif n.type=="stat"then if loaded("material",SMALL_BG)then cv:texture(SMALL_BG,cx-s/2,cy-s/2,s,s,WHITE,nil,nil,{saturation=1,intensity=on and 0 or -.8,frame_intensity=on and 1 or .45})else cv:circle(cx,cy,s*.38,on and C.gold_hi or C.frame)end
  elseif loaded("material",ICON)and loaded("texture",n.icon)and loaded("texture",frame)and loaded("texture",mask)and loaded("texture",n.s.gradient_map)then
   cv:texture(ICON,cx-s/2,cy-s/2,s,s,WHITE,nil,nil,{icon=n.icon,frame=frame,icon_mask=mask,gradient_map=n.s.gradient_map,saturation=1,intensity=on and 0 or -.8,frame_intensity=on and 1 or .45})
  else cv:circle(cx,cy,s*.38,on and C.gold_hi or C.frame)end
  -- every pick wears the talent screen's selected ring in gold, so a build reads at a glance; the node named by opt.hl rings white over it
  if on and n.type~="start"and ready and loaded("material",hl_material(n))then cv.z=7;cv:texture(hl_material(n),cx-s/2,cy-s/2,s,s,C.gold_hi)end
  if opt.hl==n.name and ready and loaded("material",hl_material(n))then cv.z=7;cv:texture(hl_material(n),cx-s/2,cy-s/2,s,s,C.value)end
  local r=math.max(s/2,9);local extra=opt.extra and opt.extra(n)
  view:_hit("base",cx-r,cy-r,2*r,2*r,nil,nil,nil,Tip.lines("talent|"..tree.key.."|"..n.name.."|"..tostring(on).."|"..tostring(extra),function()return T.card(tree,n,on,extra)end),"io_tn:"..n.name)
 end
 cv.z=z
end
return T
