-- Information Overload: the Mission Board screen, a briefing on the map you hover.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local M={id="board",name="Mission Board",place="Mourningstar",icon="board",rows={
  {key="board_briefing",label="Map Briefing",help="Hovering a mission shows your record on its map over the mission details.",kind="toggle",default=true},
  {key="board_briefing_downs",label="What Downs You Here",help="What has downed you on that map, in the briefing.",kind="toggle",default=true},
  {key="board_briefing_mates",label="Won Here With",help="The teammates you have won that map with, in the briefing.",kind="toggle",default=true},
 }}
 local defaults={};for _,r in ipairs(M.rows)do defaults[r.key]=r.default end
 local function row(key)local v=mod:get(key);if v==nil then return defaults[key]end;return v==true end
 local opts,opts_at={},-1
 -- the switches are read twice a second at most
 local function options()
  local now=os.clock()
  if now>=opts_at+.5 then opts_at=now
   local on=mod:is_enabled()and mod:get("screen_board")~=false
   local brief,downs,mates=row("board_briefing"),row("board_briefing_downs"),row("board_briefing_mates")
   opts.on,opts.brief,opts.downs,opts.mates=on,brief,downs,mates
  end
  return opts
 end
 -- the briefing: the history read once per change, each map laid out once per hovered tile, drawn over the details column
 local Brief,Renderer,ALIGN
 local idx,idx_key
 local function laid(key,bd,o,renderer)
  local tracker=api.dashboard_tracker();local data=tracker and tracker.data;if not data then return nil end
  local d=mod.io_display_options and mod.io_display_options()or {};local basis=d.boss_map_timing and "boss"or "victory"
  local k=tostring(data.run_sequence)..":"..tostring(data.history_policy_revision)..":"..#(data.run_history or {})..":"..basis..":"..tostring(mod.io_times_revision)
  Brief=Brief or mod:io_dofile(base.."board_briefing")
  if not idx or idx_key~=k or idx.data~=data then idx={data=data,index=Brief.index(tracker),maps={},ops={}};idx_key=k end
  local m=idx.maps[key];if m==nil then m=Brief.map(idx.index,key,basis)or false;idx.maps[key]=m end
  if not m then return nil end
  local fk=key.."|"..tostring(bd)..tostring(o.brief)..tostring(o.downs)..tostring(o.mates)
  local ops=idx.ops[fk];if ops==nil then ops=Brief.fit(m,bd,{main=o.brief,downs=o.downs,mates=o.mates},M.measure(renderer))or false;idx.ops[fk]=ops end
  return ops or nil
 end
 -- the layout is in the scene's pixels: UI units are 0.96 of them, and the type is set to the scene's mono pitch; the game scales boxes to the screen but not type
 M.UI,M.PITCH,M.Z=0.96,0.85,700
 function M.measure(renderer)
  local memo={}
  Renderer=Renderer or require("scripts/managers/ui/ui_renderer")
  return function(s,size,font)local key=font..size..s;local w=memo[key];if w then return w end
   local ok,v=pcall(Renderer.text_size,renderer,s,font,size*M.UI*M.PITCH)
   if ok and type(v)=="number"then w=v/M.UI else w=select(2,s:gsub("[^\128-\191]",""))*size*.555 end
   memo[key]=w;return w end
 end
 local TINT={0,0,0,0}
 local function paint(view,renderer,ops,alpha)
  local node=view._ui_scenegraph and view._ui_scenegraph.sidebar;local pos=node and node.world_position;if not pos then return end
  local k=renderer.scale or RESOLUTION_LOOKUP.scale or 1;local S,H=M.UI,Brief.H
  if not ALIGN then local v=Gui.VerticalAlignCenter;ALIGN={left={horizontal_alignment=Gui.HorizontalAlignLeft,vertical_alignment=v},right={horizontal_alignment=Gui.HorizontalAlignRight,vertical_alignment=v},center={horizontal_alignment=Gui.HorizontalAlignCenter,vertical_alignment=v}}end
  for _,p in ipairs(ops)do if p.y<H and (p.r or p.y+p.h<=H)then
   local c=p.c;if alpha<1 then TINT[1],TINT[2],TINT[3],TINT[4]=c[1]*alpha,c[2],c[3],c[4];c=TINT end
   local at=Vector3(pos[1]+p.x*S,pos[2]+p.y*S,M.Z+p.z)
   if p.r then Renderer.draw_rect(renderer,at,Vector2(p.w*S,math.min(p.h,H-p.y)*S),c)
   -- left-aligned text gets the room to the column's edge, so a word measured a hair short of the game's own type never wraps
   else Renderer.draw_text(renderer,p.s,math.max(1,p.size*S*M.PITCH*k),p.f,at,Vector2((p.a=="left"and math.max(p.w,Brief.W-p.x)or p.w)*S,p.h*S),c,ALIGN[p.a])end
  end end
 end
 -- shown while a tile is hovered with the mouse in use, held a moment after leaving so crossing tiles does not flicker, never pinned
 local GRACE,FADE=.32,.12
 local shown={alpha=0}
 local function hide()shown.alpha,shown.ops,shown.seen,shown.dir=0,nil,nil,nil end
 M.shown=shown
 local function briefing(view,renderer,o,dt,t)
  local ui=Managers.ui;local pad=ui and ui.using_cursor_navigation and not ui:using_cursor_navigation()
  local card;if not pad then for _,w in ipairs(view._mission_widgets or {})do local c=w.content;local hs=c and c.hotspot
   if w.visible~=false and c.mission and hs and hs.is_hover then card=w;break end end end
  local ops;if card then local mission=card.content.mission;Brief=Brief or mod:io_dofile(base.."board_briefing")
   ops=mission.map and laid(mission.map,Brief.board_diff(view,mission),o,renderer)end
  t=t or 0;dt=dt or 0
  if ops then
   if shown.dir==-1 and shown.alpha>0 then shown.alpha=1 else shown.alpha=math.min(1,shown.alpha+dt/FADE)end
   shown.ops,shown.seen,shown.dir=ops,t,1
  elseif shown.ops and (not shown.seen or t-shown.seen>GRACE)then shown.dir=-1;shown.alpha=math.max(0,shown.alpha-dt/FADE);if shown.alpha<=0 then hide()end end
  if shown.ops and shown.alpha>0 then paint(view,renderer,shown.ops,shown.alpha)end
 end
 local function draw(view,renderer,dt,t)
  local o=options();if not o.on then hide();return end
  if view._mission_board_options~=nil then hide();return end
  local list=view._element and view:_element("mission_list");if list and list.visible and list:visible()then hide();return end
  if o.brief or o.downs or o.mates then briefing(view,renderer,o,dt,t)else hide()end
 end
 local broken
 local function fail(err)broken=true;mod:error("I/O mission board: %s",tostring(err))end
 mod:hook_require("scripts/ui/views/mission_board_view/mission_board_view",function(View)
  -- the game requires the view again on each visit and the class outlives a mods reload, so it is hooked once per load of the mod
  if View.io_board==M then return end;View.io_board=M
  mod:hook_safe(View,"on_enter",function()opts_at=-1 end)
  mod:hook_safe(View,"_draw_widgets",function(self,dt,t,_,renderer)
   if broken or not renderer then return end
   local ok,err=pcall(draw,self,renderer,dt,t);if not ok then fail(err)end
  end)
  mod:hook_safe(View,"on_exit",hide)
 end)
 return M
end
