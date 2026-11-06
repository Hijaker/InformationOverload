-- Information Overload: the End Screen, the mission time and records under the squad, the Mission Debrief behind them, the held scoreboard, the hidden mission rating and the vote under Continue.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local Times=mod:io_dofile(base.."mission_times")
 local M={id="endscreen",name="End Screen",place="Mission",icon="endscreen",rows={
  {key="endscreen_time_records",label="Mission Time And Records",help="Your clear time and any records you set, under the squad.",kind="toggle",default=true},
  {key="endscreen_debrief",label="Mission Debrief",help="Hover the time and records for the mission's records, kills, damage and how it compares with your others.",kind="toggle",default=true},
  {key="endscreen_debrief_downs",label="Downs And Deaths",help="Every down and death in the debrief, yours and your teammates', in the order they were recorded.",kind="toggle",default=true},
 }}
 local defaults={};for _,r in ipairs(M.rows)do defaults[r.key]=r.default end
 local function on()return mod:is_enabled()and mod:get("screen_endscreen")~=false end
 local function row(key)local v=mod:get(key);if v==nil then return defaults[key]end;return v==true end
 -- Hide Mission Rating keeps its own key and is drawn under the rows on the tab by Settings, so it is not one of them
 local function hide_rating()return on()and mod:get("hide_match_rating")==true end
 local Debrief
 local function debrief()Debrief=Debrief or mod:io_dofile(base.."endscreen_debrief");return Debrief end
 local function basis()local o=mod.io_display_options and mod.io_display_options()or {};return o.boss_map_timing and "boss"or "victory"end
 -- what a saved run broke: a first or faster clear of its map on its patch, then each Dossier best of its mode it beat; the second list is its class's alone
 function M.broken(tracker,run,how)return debrief().broken(tracker,run,how)end
 function M.records(tracker,run,how)return #(M.broken(tracker,run,how))end
 -- worked out once a mission, and again only if the history moves while the end screen is up
 local shown
 local function summary(f,sb)
  local d=f.tracker and f.tracker.data or {};local seq,n,rev=d.run_sequence,#(d.run_history or {}),tostring(d.history_policy_revision)..":"..tostring(mod.io_times_revision)
  if shown and shown.m==f.m and shown.seq==seq and shown.n==n and shown.rev==rev then return shown end
  -- a run saved after the end screen first drew is looked for again
  if shown and shown.m==f.m and f.run==false then f.run=nil end
  local run=sb.saved_run(f);local s={m=f.m,seq=seq,n=n,rev=rev,run=run,list={},cls={}}
  if run then s.list,s.cls=M.broken(f.tracker,run,basis())end
  shown=s;return s
 end
 local Renderer=require("scripts/managers/ui/ui_renderer")
 local ALIGN
 local LAB,HI,SHADE={255,164,186,167},{255,218,231,216},{242,0,0,0}
 local HINT,HINT_ON,HINT_PIN={255,118,124,119},{255,214,220,212},{255,238,216,164}
 local function width(view,s,size,cache,font)
  local key=s..size..(font or "");if not cache[key]then local ok,w=pcall(view._text_size,view,s,{font_type=font or "proxima_nova_bold",font_size=size},{2000,200});cache[key]=ok and type(w)=="number"and w>0 and w or #s*size*.55 end
  return cache[key]
 end
 local widths={}
 local function put(renderer,s,size,x,y,c,a,k,font,z)
  font=font or "proxima_nova_bold";z=z or 200
  SHADE[1]=242*a;Renderer.draw_text(renderer,s,size*k,font,Vector3(x+1,y+1,z),Vector2(400,34),SHADE,ALIGN.left)
  local alpha=c[1];c[1]=alpha*a;Renderer.draw_text(renderer,s,size*k,font,Vector3(x,y,z+1),Vector2(400,34),c,ALIGN.left);c[1]=alpha
 end
 -- the mockup is 2000 wide and its card is drawn at 1.07, the game's UI 1920: one card unit is F UI units
 local F=1.07*1920/2000
 M.F=F
 -- the bar's text block from the skull corner to the eagle, as x, height up from the bottom and width
 M.HIT={255.4,104.6,493.4}
 -- the card rises from the bar, centred, its bar's foot 110.4 above the screen's; its top stays under the game's 200 high title block, at the mockup's 202, so a screen shorter than 16:10 draws it smaller
 function M.scale(sh,h)return math.min(F,(sh-110.4-202)/h)end
 function M.origin(sw,sh,h)local f=M.scale(sh,h);return sw/2-debrief().W/2*f,sh-110.4-h*f,f end
 local PREVIEW,CLOSE=.15,.12
 -- hover opens it after a moment, a click keeps it until a click, Back or Esc; Full History asks for the mission's own page
 function M.step(st,where,click,back,t)
  local bar=where=="bar";local over=where~=nil
  if back and st.mode~="closed"then st.mode,st.at,st.left="closed",nil,nil;return end
  if click then
   if bar then st.mode=st.mode=="pinned"and "preview"or "pinned";st.at,st.left=nil,nil;return end
   if st.mode~="closed"and where=="link"then st.mode="closed";return "link"end
   if st.mode=="pinned"and where=="back"then st.mode="closed";return end
   if st.mode=="preview"and over then st.mode="pinned";return end
  end
  if st.mode=="closed"then if bar then st.at=st.at or t;if t-st.at>=PREVIEW then st.mode,st.left="preview",nil end else st.at=nil end
  elseif st.mode=="preview"then if over then st.left=nil else st.left=st.left or t;if t-st.left>=CLOSE then st.mode,st.at,st.left="closed",nil,nil end end end
 end
 local st={mode="closed"}
 -- the player view's input from its last frame, and whether it has been up this end screen
 local over_input,over_seen
 function M.state()return st end
 function M.reset()shown=nil;st={mode="closed"};widths={};over_input,over_seen=nil,nil end
 local function inside(x,y,r)return x~=nil and x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]end
 local function input_get(input,name)if not input then return nil end;local ok,v=pcall(input.get,input,name);if ok then return v end end
 local tmp={0,0,0,0}
 local function col(c,a)tmp[1]=c[1]*a;tmp[2]=c[2];tmp[3]=c[3];tmp[4]=c[4];return tmp end
 local Z=600
 local function op(renderer,o,ox,oy,f,a,k,c)
  c=col(c or o.c,a)
  if o.t=="r"then Renderer.draw_rect(renderer,Vector3(ox+o.x*f,oy+o.y*f,Z+o.l),Vector2(o.w*f,o.h*f),c)
  elseif o.t=="t"then Renderer.draw_text(renderer,o.s,math.max(1,o.size*f*k),o.font,Vector3(ox+o.x*f,oy+o.y*f,Z+o.l),Vector2(o.w*f,o.h*f),c,ALIGN[o.align])
  else Renderer.draw_circle(renderer,Vector3(ox+o.x*f,oy+o.y*f,Z+o.l),o.r*f,nil,c)end
 end
 local SCRIM={163,3,5,4}
 -- the layout is built once a mission from the debrief's figures, in card units, so each frame only places it
 local function layout(view,f,sb,s)
  local downs=row("endscreen_debrief_downs")
  if s.lay and s.lay_downs==downs then return s.lay end
  local D=debrief()
  if not s.model then local secs=sb.final_seconds(f);s.model=D.model(f.tracker,f.m,s.run,secs,basis(),s.list,s.cls)
   -- a solo run's id counts in the solo history, and the panel opens runs of the dashboard's, so it gets no Full History
   if f.tracker~=(api.dashboard_tracker and api.dashboard_tracker())then s.model.run_id=nil end
  end
  s.lay=D.layout(s.model,function(t,size,font)return width(view,t,size*F,widths,font)/F end,downs);s.lay_downs=downs
  return s.lay
 end
 local function rect(renderer,x,y,w,h,c,z,a)Renderer.draw_rect(renderer,Vector3(x,y,z),Vector2(w,h),col(c,a))end
 local function card(renderer,lay,a,k,ox,oy,f,sw,sh,where)
  local C=Debrief.c;local pinned=st.mode=="pinned";local w,h,H=Debrief.W*f,lay.card*f,lay.h*f
  if pinned then rect(renderer,0,0,sw,sh-M.HIT[2],SCRIM,Z-10,a)end
  local edge=pinned and C.edge or C.frame
  rect(renderer,ox,oy,w,H,pinned and C.pinned or C.preview,Z,a)
  rect(renderer,ox,oy,w,1,edge,Z+1,a);rect(renderer,ox,oy+H-1,w,1,edge,Z+1,a);rect(renderer,ox,oy,1,H,edge,Z+1,a);rect(renderer,ox+w-1,oy,1,H,edge,Z+1,a)
  rect(renderer,ox,oy+h,w,1,C.frame,Z+1,a);rect(renderer,ox,oy,120*f,2*f,C.accent,Z+2,a)
  for _,o in ipairs(lay.ops)do op(renderer,o,ox,oy,f,a,k)end
  for _,o in ipairs(pinned and lay.pinned or lay.preview)do op(renderer,o,ox,oy,f,a,k,o.id=="back"and where=="back"and C.back_hover or nil)end
 end
 local function open_history(id)
  local ui=Managers.ui;if not ui or not id then return end
  if mod.io_hold_icons then mod.io_hold_icons()end
  ui:open_view("information_overload_view",nil,false,false,nil,{use_transition_ui=false,io_tap=true,io_run=id})
 end
 -- the records failing loses them and the debrief; the debrief failing loses only itself
 local lost,dead
 local function fail_records(err)lost=true;st.mode="closed";mod:error("I/O end screen records: %s",tostring(err))end
 local function fail_debrief(err)dead=true;st.mode="closed";mod:error("I/O mission debrief: %s",tostring(err))end
 -- until the debrief has been opened once, I/O's cog and a tip cover the time and records, the place to hover, and go once it opens
 M.TIP_KEY,M.TIP_SAY="endscreen_debrief_tip_seen","Hover here and I'll show you how that mission went."
 local TIP,TIP_BOX={255,201,162,90},{255,12,16,13}
 local Intro
 local function cog(renderer,cx,cy,s,angle,c,z)
  Intro=Intro or mod:io_dofile(base.."io_intro")
  local u=s/160;local lap=math.max(1,math.min(3,1.5/u))
  for _,r in ipairs(Intro.RECTS)do local ox,oy=r[1]*u,(r[2]-lap/2)*u
   Renderer.draw_rect_rotated(renderer,Vector2(r[3]*u,(r[4]+lap)*u),Vector3(cx-s/2+ox,cy-s/2+oy,z),angle,Vector2(s/2-ox,s/2-oy),c)
  end
 end
 -- held in under the bar's trim and round the time and hint, its width the cog and words
 local function tip(view,renderer,sh,t,a,k)
  local s=34;local tw=width(view,M.TIP_SAY,16,widths,"proxima_nova_medium")
  local x,y,w,h=M.HIT[1]+18,sh-82,math.min(M.HIT[3]-36,16+s+14+tw+18),72
  rect(renderer,x,y,w,h,TIP_BOX,202,a);rect(renderer,x,y,w,2,TIP,203,a);rect(renderer,x,y+h-2,w,2,TIP,203,a);rect(renderer,x,y,2,h,TIP,203,a);rect(renderer,x+w-2,y,2,h,TIP,203,a)
  cog(renderer,x+16+s/2,y+h/2,s,t*.8,col(TIP,a),204)
  put(renderer,M.TIP_SAY,16,x+16+s+14,y+h/2-17,HI,a,k,"proxima_nova_medium",205)
 end
 -- the hint beside the records, the hover and clicks, and the card while it is open
 local function talk(view,renderer,f,sb,s,input,t,a,k,sw,sh,hx,hy)
  local lay=layout(view,f,sb,s)
  -- with a controller in use a mouse left resting on the bar opens nothing, and the tip, which only a hover puts away, is left off
  local ui=Managers.ui;local pad=ui and ui.using_cursor_navigation and not ui:using_cursor_navigation()
  local inv=1/k;local cur=input_get(input,"cursor");if pad then cur=nil end;local cx,cy=cur and cur[1]*inv,cur and cur[2]*inv
  local ox,oy,f=M.origin(sw,sh,lay.h)
  local seen=mod:get(M.TIP_KEY)==true
  local where=inside(cx,cy,{M.HIT[1],sh-M.HIT[2],M.HIT[3],M.HIT[2]})and "bar"or nil
  if not where and st.mode~="closed"then
   local function hot(r)return r and {ox+r[1]*f,oy+r[2]*f,r[3]*f,r[4]*f}end
   if st.mode=="pinned"and inside(cx,cy,hot(lay.hot.back))then where="back"
   elseif lay.hot.link and inside(cx,cy,hot(lay.hot.link))then where="link"
   elseif inside(cx,cy,{ox,oy,Debrief.W*f,lay.h*f})then where="panel"end
  end
  -- the held or tapped-on scoreboard is drawn in this pass far under the card, so while it shows the card, its dim and the tip step aside and keep their state
  local held=sb.state~=nil and sb.S.held(sb.state,os.clock(),sb.finished and sb.finished())and not (sb.hold_layout and sb.hold_layout(true)=="off")
  if held then where=nil end
  local act=not held and M.step(st,where,input_get(input,"left_pressed")==true,input_get(input,"back")==true,t)
  if act=="link"then open_history(s.model.run_id)end
  if st.mode~="closed"and not seen then mod:set(M.TIP_KEY,true);seen=true end
  if not seen and not held and not pad then tip(view,renderer,sh,t,a,k)end
  local pinned=st.mode=="pinned"
  put(renderer,pinned and "Click To Unlock"or where=="bar"and "Click To Lock"or "Hover For Debrief",15,hx,hy,pinned and HINT_PIN or where=="bar"and HINT_ON or HINT,a,k,"proxima_nova_medium")
  if st.mode~="closed"and not held then card(renderer,lay,a,k,ox,oy,f,sw,sh,where)end
 end
 -- set into the game's bar left of the eagle, the time on Continue's line and the records under it
 local function lines(view,renderer,input,t,full)
  if not on()then return end
  local times,more=row("endscreen_time_records"),row("endscreen_debrief")
  if not times and not more then return end
  local sb=mod.io_scoreboard;local f=sb and sb.finished();if not f then return end
  -- the lines fade in with the game's bar; once the player view has been up they stay at full strength
  local a=view._widget_alpha;a=(full or type(a)~="number")and 1 or math.min(1,a);if a<=0 then return end
  if st.m~=f.m then st={m=f.m,mode="closed"}end
  local s;if not lost then local ok,r=pcall(summary,f,sb);if ok then s=r else fail_records(r)end end
  local k=renderer.scale or RESOLUTION_LOOKUP.scale or 1;local sw,sh=RESOLUTION_LOOKUP.width/k,RESOLUTION_LOOKUP.height/k;local x=288
  if not ALIGN then local v=Gui.VerticalAlignCenter;ALIGN={left={horizontal_alignment=Gui.HorizontalAlignLeft,vertical_alignment=v},right={horizontal_alignment=Gui.HorizontalAlignRight,vertical_alignment=v},center={horizontal_alignment=Gui.HorizontalAlignCenter,vertical_alignment=v}}end
  local count=s and #s.list or 0;local hx,hy=x,sh-43
  -- a mission joined late or picked up after a mods reload shows how long it was tracked, with a + for at least
  if times then local seconds=sb.final_seconds(f);local least=not seconds and sb.tracked_seconds and sb.tracked_seconds(f)
   if seconds or least then local y=sh-75;put(renderer,"Mission Time:",18,x,y,LAB,a,k);put(renderer,(seconds and Times.backend(s and s.run or f.m)and Times.format(seconds)or sb.S.clock(seconds or least))..(seconds and ""or "+"),24,x+width(view,"Mission Time:",18,widths)+7,y-2,HI,a,k)end
   if count>0 then local n=tostring(count);local word=count==1 and "Record"or "Records";local y=sh-43
    put(renderer,n,18,x,y-1,HI,a,k);put(renderer,word,16,x+width(view,n,18,widths)+5,y,LAB,a,k);hx=x+width(view,n,18,widths)+5+width(view,word,16,widths)+25
   end
  end
  if more and s and not dead then local ok,err=pcall(talk,view,renderer,f,sb,s,input,t or os.clock(),a,k,sw,sh,hx,hy);if not ok then fail_debrief(err)end end
 end
 local broken
 local function fail(err)broken=true;mod:error("I/O end screen: %s",tostring(err))end
 -- the end view draws its bar on a layer over the player view, so the lines are always drawn in the end view's pass, with the player view's input while it is up
 local function draw(view,renderer,name,input,t)
  if not renderer or not mod:is_enabled()then return end
  if name=="end_player_view"then over_input,over_seen=input,true
  elseif not broken then local ui=Managers.ui;local up=over_input and ui and ui:view_active("end_player_view")
   local ok,err=pcall(lines,view,renderer,up and over_input or input,t,over_seen);if not ok then fail(err)end
  end
  local sb=mod.io_scoreboard;if sb and sb.over_end then sb.over_end(renderer,name)end
 end
 -- Layout E: while the vote is up it sits on the line under Continue, its right edge on Continue's, and Rate Mission is always lifted to the screen's right edge above the skulls; with End Screen off the game's own layout is kept
 local LINE,GAP,LIFT_X,LIFT_Y=31,8,169.2,-129.6
 local function node(view,id,x,y,ha)
  local kept=view.io_kept;local n=view._ui_scenegraph[id];local p=n.position
  local o=kept[id]or {p[1],p[2],n.horizontal_alignment};kept[id]=o;if x==nil then x,y,ha=o[1],o[2],o[3]end
  if p[1]~=x or p[2]~=y or n.horizontal_alignment~=ha then view:_set_scenegraph_position(id,x,y,nil,ha);return true end
 end
 local function styles(view,c)
  local w=view._widgets_by_name;local vs,cs=w.stay_in_party_vote.style,w.continue_button.style;cs.hotspot=cs.hotspot or {}
  local hot={size={0,LINE},offset={0,0,0}};view.io_hot=hot
  -- Continue's own hints sit under its text, where the vote now is, so they go above it, and the vote's own hint, under the screen's edge now, a line above those
  local function up(o,dy)o=o or {0,0,0};return {o[1]or 0,(o[2]or 0)-dy,o[3]or 0}end
  local list={{vs.vote_text,"text_horizontal_alignment","right"},{vs.vote_count_text,"text_horizontal_alignment","right"},{vs.vote_count_text,"font_size",22},{vs.hotspot,"size",hot.size},{vs.hotspot,"offset",hot.offset},
   {cs.hotspot,"size",{c.size[1],LINE}},{cs.tooltip,"offset",up(cs.tooltip.offset,c.size[2])},{cs.vote_done_tooltip,"offset",up(cs.vote_done_tooltip.offset,c.size[2])},
   {vs.tooltip,"text_horizontal_alignment","right"},{vs.tooltip,"offset",up(vs.tooltip.offset,2*LINE+view._ui_scenegraph.vote_text.size[2])}}
  for _,e in ipairs(list)do e[4]=e[1][e[2]]end
  return list
 end
 local function arrange(view)
  local w,sg=view._widgets_by_name,view._ui_scenegraph;if not (w and sg and w.stay_in_party_vote and w.continue_button and w.rate_match)then return end
  local c=sg.continue_button;local e=on()and c.horizontal_alignment=="right"
  if not e and not view.io_kept then return end
  view.io_kept=view.io_kept or {};view.io_sets=view.io_sets or styles(view,c)
  local vote=w.stay_in_party_vote;local up=e and vote.visible==true;local moved
  if up then
   local raw=vote.content.vote_text or "";local vt=vote.style.vote_text
   if view.io_vote_src~=raw then view.io_vote_src=raw;view.io_vote_w=math.ceil(width(view,(raw:gsub("{#.-}","")),vt.font_size or 22,widths,vt.font_type))end
   local tw,R,top,vn=view.io_vote_w,c.position[1],c.position[2]-c.size[2]+LINE,sg.vote_text
   moved=node(view,"vote_text",R,top+vn.size[2],"right");moved=node(view,"vote_count_text",R-tw-GAP,top+sg.vote_count_text.size[2],"right")or moved
   view.io_hot.size[1]=tw;view.io_hot.offset[1]=vn.size[1]-tw
  else moved=node(view,"vote_text");moved=node(view,"vote_count_text")or moved end
  for _,s in ipairs(view.io_sets)do local v=up and s[3]or s[4];if s[1][s[2]]~=v then s[1][s[2]]=v end end
  local o=view.io_kept.rate_match or {sg.rate_match.position[1],sg.rate_match.position[2],sg.rate_match.horizontal_alignment};view.io_kept.rate_match=o
  if e and not hide_rating()then moved=node(view,"rate_match",sg.rate_match.size[1]-LIFT_X,o[2]+LIFT_Y,"right")or moved
  else moved=node(view,"rate_match")or moved end
  if moved and view._force_update_scenegraph then view:_force_update_scenegraph()end
 end
 local stuck
 local function place(view)if stuck then return end;local ok,err=pcall(arrange,view);if not ok then stuck=true;mod:error("I/O end screen vote: %s",tostring(err))end end
 -- the thumbs follow Hide Mission Rating either way on the screen already up, and come back with the mod turned off; the game never sets their visibility itself
 local function rating(self)local w=self._widgets_by_name and self._widgets_by_name.rate_match;if not w then return end
  if hide_rating()then if not self.io_rating_hidden then w.visible=false;self.io_rating_hidden=true end
  elseif self.io_rating_hidden then w.visible=true;self.io_rating_hidden=nil end
 end
 -- the mod turned off stops its hooks, so an end screen already up gets the game's rating and vote back at once
 function M.off()local ui=Managers.ui;local v=ui and ui:view_instance("end_view");if v then rating(v);place(v)end end
 mod:hook_require("scripts/ui/views/end_view/end_view",function(EndView)
  if EndView.io_endscreen==M then return end;EndView.io_endscreen=M
  mod:hook_safe(EndView,"_setup_rate_match",rating)
  -- hidden, the thumbs up and down send no rating, even by their keys
  mod:hook(EndView,"rate_match",function(func,self,rating)
   if hide_rating()then return end
   return func(self,rating)
  end)
  mod:hook_safe(EndView,"update",function(self)rating(self);if mod:is_enabled()or self.io_kept then place(self)end end)
  mod:hook_safe(EndView,"_draw_widgets",function(self,_,t,input,renderer)draw(self,renderer,"end_view",input,t)end)
  mod:hook_safe(EndView,"on_exit",function()
   M.reset();local sb=mod.io_scoreboard;if sb and sb.end_closed then sb.end_closed()end
  end)
 end)
 mod:hook_require("scripts/ui/views/end_player_view/end_player_view",function(EndPlayerView)
  if EndPlayerView.io_endscreen==M then return end;EndPlayerView.io_endscreen=M
  mod:hook_safe(EndPlayerView,"_draw_widgets",function(self,_,t,input,renderer)draw(self,renderer,"end_player_view",input,t)end)
 end)
 return M
end
