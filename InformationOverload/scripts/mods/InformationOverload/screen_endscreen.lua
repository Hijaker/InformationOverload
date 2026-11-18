-- Information Overload: the End Screen, the mission time and records under the squad, the Mission Debrief behind them, the held scoreboard, the hidden mission rating, the vote under Continue, Prolong End Screen, and the game's own scoreboard kept shut.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local Times=mod:io_dofile(base.."mission_times")
 local Defs=mod:io_dofile(base.."io_view_definitions")
 local M={id="endscreen",name="End Screen",place="Mission",icon="endscreen",rows={
  {key="endscreen_time_records",label="Mission Time And Records",help="Your clear time and any records you set, under the squad.",kind="toggle",default=true},
  {key="endscreen_debrief",label="Mission Debrief",help="Hover the time and records for the mission's records, kills, damage and how it compares with your others.",kind="toggle",default=true},
  {key="endscreen_mission_clock",label="Minute By Minute",picture="clock",help="A bar for each minute of the mission across the debrief, with each death marked at the time it happened. Off, downs and deaths show on two lanes in the debrief instead.",kind="toggle",default=true},
 }}
 local defaults={};for _,r in ipairs(M.rows)do defaults[r.key]=r.default end
 local function on()return mod:is_enabled()and mod:get("screen_endscreen")~=false end
 -- Prolong End Screen keeps its own keys and is drawn under the rows on the tab by Settings, as Hide Mission Rating is
 local Hold=mod:io_dofile(base.."end_screen_hold")(mod,on)
 M.KEEP,M.keep_minutes=Hold.KEEP,Hold.minutes
 local function row(key)local v=mod:get(key);if v==nil then return defaults[key]end;return v==true end
 -- Hide Mission Rating keeps its own key and is drawn under the rows on the tab by Settings, so it is not one of them
 -- Hide Mission Rating is on unless switched off; its key is new, so an older saved "off" does not hold it back
 local function hide_rating()return on()and mod:get("hide_mission_rating")~=false end
 -- Remove Game's Scoreboard is a Scoreboard row, on unless switched off, and holds only while I/O's Scoreboard is on
 local function hide_board()return mod:is_enabled()and mod:get("screen_scoreboard")~=false and mod:get("hide_game_scoreboard")~=false end
 local Debrief
 local function debrief()Debrief=Debrief or mod:io_dofile(base.."endscreen_debrief");return Debrief end
 local function basis()local o=mod.io_display_options and mod.io_display_options()or {};return o.boss_map_timing and "boss"or "victory"end
 -- what a saved run broke: a first or faster clear of its map on its patch, then each Dossier best of its mode it beat; the second list is its class's alone
 function M.broken(tracker,run,how)return debrief().broken(tracker,run,how)end
 function M.records(tracker,run,how)return #(M.broken(tracker,run,how))end
 -- worked out once a mission, and again only if the history or the timing and overkill settings move while the end screen is up
 local shown
 local function summary(f,sb)
  local d=f.tracker and f.tracker.data or {};local o=mod.io_display_options and mod.io_display_options()or {};local seq,n,rev=d.run_sequence,#(d.run_history or {}),tostring(d.history_policy_revision)..":"..tostring(mod.io_times_revision)..":"..basis()..":"..tostring(o.includes_overkill==true)
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
  local key=s..size..(font or "");if not cache[key]then local ok,w,_,_,caret=pcall(view._text_size,view,s,{font_type=font or "proxima_nova_bold",font_size=size},{2000,200});cache[key]=ok and type(w)=="number"and w>0 and Defs.advance(w,caret)or #s*size*.55 end
  return cache[key]
 end
 local widths={}
 local function put(renderer,s,size,x,y,c,a,k,font,z)
  font=font or "proxima_nova_bold";z=z or 200
  SHADE[1]=242*a;Renderer.draw_text(renderer,s,size*k,font,Vector3(x+1,y+1,z),Vector2(400,34),SHADE,ALIGN.left)
  local alpha=c[1];c[1]=alpha*a;Renderer.draw_text(renderer,s,size*k,font,Vector3(x,y,z+1),Vector2(400,34),c,ALIGN.left);c[1]=alpha
 end
 -- the bar's text block from the skull corner to the eagle, as x, height up from the bottom and width
 M.HIT={255.4,104.6,493.4}
 -- the card is laid out in the game's 1920 wide frame at the screen's own height, centred on a wider screen
 local Card,Model
 local function card_mod()Card=Card or mod:io_dofile(base.."endscreen_card");return Card end
 function M.origin(sw)return (sw-1920)/2 end
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
 local drop_portraits
 function M.reset()shown=nil;st={mode="closed"};widths={};over_input,over_seen=nil,nil;if drop_portraits then drop_portraits()end end
 local function inside(x,y,r)return x~=nil and x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]end
 local function input_get(input,name)if not input then return nil end;local ok,v=pcall(input.get,input,name);if ok then return v end end
 local tmp={0,0,0,0}
 local function col(c,a)tmp[1]=c[1]*a;tmp[2]=c[2];tmp[3]=c[3];tmp[4]=c[4];return tmp end
 local Z=600
 local function op(renderer,o,ox,a,k)
  local c=col(o.c,a)
  if o.t=="r"then Renderer.draw_rect(renderer,Vector3(ox+o.x,o.y,Z+o.l),Vector2(o.w,o.h),c)
  elseif o.t=="t"then Renderer.draw_text(renderer,o.s,math.max(1,o.size*k),o.font,Vector3(ox+o.x,o.y,Z+o.l),Vector2(o.w,o.h),c,ALIGN[o.align])
  elseif o.t=="i"then if Renderer.draw_texture then Renderer.draw_texture(renderer,o.mat,Vector3(ox+o.x,o.y,Z+o.l),Vector2(o.w,o.h),c)end
  elseif o.t=="q"then Renderer.draw_rect_rotated(renderer,Vector2(o.w,o.h),Vector3(ox+o.x,o.y,Z+o.l),o.angle,Vector2(o.pivot_x,o.pivot_y),c)
  else Renderer.draw_circle(renderer,Vector3(ox+o.x,o.y,Z+o.l),o.r,nil,c)end
 end
 -- the card's figures are worked out once a mission: the debrief's model of the run, then each operative's from the scoreboard's squad rows,
 -- the squad's damage and kill tables and the mission clock's minutes
 local function card_model(f,sb,s)
  if s.card then return s.card end
  local D=debrief();local secs=sb.final_seconds(f)
  if not s.model then s.model=D.model(f.tracker,f.m,s.run,secs,basis(),s.list,s.cls)
   -- a solo run's id counts in the solo history, and the panel opens runs of the dashboard's, so it gets no Full History
   if f.tracker~=(api.dashboard_tracker and api.dashboard_tracker())then s.model.run_id=nil end
  end
  Model=Model or mod:io_dofile(base.."endscreen_card_model")
  local live=sb.live and sb.live();local run=s.run;local team,party
  if collectors and collectors.live_squad then team,party=collectors:live_squad(f.m)end
  if run and run.merged_segment_ids then team,party=mod:io_dofile(base.."team_damage").from_run(run),run.party_records end
  local dt=api.dashboard_tracker and api.dashboard_tracker();local counts=dt and dt.incident_counts and dt.incident_counts(run or f.m)or {}
  s.card=Model.model(f.tracker,f,run,s.model,live and live.squad or {},team,party,secs,Times.backend(run or f.m)~=nil,counts)
  return s.card
 end
 -- laid out again only when the selected operative, Minute By Minute, the screen's height or the squad average changes; the hovered minute or marker
 -- puts only its highlight and readout on that layout
 local function layout(view,f,sb,s,sh)
  local Mc=card_model(f,sb,s);local clock=row("endscreen_mission_clock");local hv=st.hover;local squad=mod:get("endscreen_squad_average")==true
  local key=tostring(st.sel)..(clock and "c"or "n")..(squad and "s"or "y")..sh
  local measure
  if not (s.lay and s.lay_key==key)then measure=function(t,size,font)return width(view,t,size,widths,font)end
   s.lay=card_mod().layout(Mc,{sh=sh,clock=clock,sel=st.sel,measure=measure,squad=squad});s.lay_key=key end
  if not hv then return s.lay end
  local hk=hv.kind..hv.i
  if not (s.pop and s.pop_of==s.lay and s.pop_key==hk)then measure=measure or function(t,size,font)return width(view,t,size,widths,font)end
   s.pop=card_mod().hover(s.lay,Mc,{sh=sh,clock=clock,sel=st.sel,measure=measure,hover=hv,squad=squad});s.pop_of,s.pop_key=s.lay,hk end
  return s.pop
 end
 -- the selected operative's portrait in the card's portrait slot, as the game's end view has loaded it for its own plate: its frame material with
 -- the portrait's values put on a material of ours, one per renderer; an operative the end view shows no plate for keeps the dark slot
 local mats=setmetatable({},{__mode="k"})
 local function values(m,list)
  for key,v in pairs(list)do local t=type(v)
   if t=="number"then Material.set_scalar(m,key,v)
   elseif t=="string"then Material.set_texture(m,key,v~=""and v or nil)
   elseif t=="userdata"then Material.set_resource(m,key,v)
   elseif t=="table"then if #v==1 then Material.set_scalar(m,key,v[1])elseif #v==2 then Material.set_vector2(m,key,Vector2(v[1],v[2]))
    elseif #v==3 then Material.set_vector3(m,key,Vector3(v[1],v[2],v[3]))elseif #v==4 then Material.set_vector4(m,key,Quaternion.from_elements(v[1],v[2],v[3],v[4]))end end
  end
 end
 local WHITE={255,255,255,255}
 local function portrait(view,renderer,lay,Mc,ox,a)
  local op=Mc.squad[lay.sel];if not (op and op.id)then return end
  local slot;for _,o in ipairs(lay.ops)do if o.id=="portrait"then slot=o;break end end
  local w;for _,x in ipairs(view._game_mode_condition_widgets or {})do local c=x.content;if c and c.portrait_character_id~=nil and tostring(c.portrait_character_id)==op.id then w=x end end
  local ps=w and w.style and w.style.character_portrait;local name=w and w.content.character_portrait
  if not (slot and ps and type(name)=="string")then return end
  local held=mats[renderer];if not held or held.name~=name then if held then pcall(Renderer.destroy_material,renderer,held.m)end;held={name=name,m=Renderer.create_material(renderer,name)};mats[renderer]=held end
  values(held.m,ps.material_values or {})
  local k=renderer.scale or 1
  Renderer.script_draw_bitmap(renderer,held.m,Vector3((ox+slot.x)*k,slot.y*k,Z+slot.l+1),Vector3(slot.w*k,slot.h*k,0),col(WHITE,a))
 end
 drop_portraits=function()for r,held in pairs(mats)do pcall(Renderer.destroy_material,r,held.m);mats[r]=nil end end
 local function frame(view,sh,lit,link,link_lit)
  local key=st.mode..sh..(lit and "l"or "")..(link and "h"or "")..(link_lit and "k"or "")
  if st.frame and st.frame_key==key then return st.frame end
  st.frame=card_mod().frame({sh=sh,mode=st.mode,lit=lit,link=link and true or false,link_lit=link_lit,dim=sh-M.HIT[2],measure=function(t,size,font)return width(view,t,size,widths,font)end});st.frame_key=key
  return st.frame
 end
 local function rect(renderer,x,y,w,h,c,z,a)Renderer.draw_rect(renderer,Vector3(x,y,z),Vector2(w,h),col(c,a))end
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
 -- Boss Damage against your average: what each earlier match at this difficulty keeps on its line or the Mourningstar read ahead, and only
 -- for one it has not reached, what its file holds, one file a frame; once all are in the row gets its average and the card is laid out again
 local Warm
 local function boss_step(s)
  local b=s.boss
  if not b then if not (s.model and s.card)then return end;b={list=s.model.before or {},i=1,sum=0,n=0};s.boss=b end
  if b.done then return end
  Warm=Warm or mod:io_dofile(base.."warm_parts")
  local read=false
  while b.i<=#b.list do local run=b.list[b.i];local w=Warm.boss_of(run)
   if not w then if read then return end;read=true;w=Warm.read_boss(run)end
   if type(w.mine)=="number"then b.sum,b.n=b.sum+w.mine,b.n+1 end;b.i=b.i+1
  end
  b.done=true
  local me=s.card.squad[1]
  if b.n>0 and me then for i,r in ipairs(s.card.avg.rows)do if r.l=="Boss Damage"then s.card.avg.rows[i]=card_mod().avgRow("Boss Damage",me.boss,b.sum/b.n,true,false)end end;s.lay=nil end
 end
 -- a portrait that fails to draw is told once and the slot stays dark
 local faceless
 local function talk(view,renderer,f,sb,s,input,t,a,k,sw,sh,hx,hy)
  local lay=layout(view,f,sb,s,sh)
  if not s.boss or not s.boss.done then local ok=pcall(boss_step,s);if not ok then s.boss={done=true}end;lay=layout(view,f,sb,s,sh)end
  -- with a controller in use a mouse left resting on the bar opens nothing, and the tip, which only a hover puts away, is left off
  local ui=Managers.ui;local pad=ui and ui.using_cursor_navigation and not ui:using_cursor_navigation()
  local inv=1/k;local cur=input_get(input,"cursor");if pad then cur=nil end;local cx,cy=cur and cur[1]*inv,cur and cur[2]*inv
  local ox=M.origin(sw)
  local seen=mod:get(M.TIP_KEY)==true
  local where=inside(cx,cy,{M.HIT[1],sh-M.HIT[2],M.HIT[3],M.HIT[2]})and "bar"or nil
  local fr=frame(view,sh,false,s.model.run_id);local plate,hover,swap
  if not where and st.mode~="closed"then
   local function hot(r)return r and {ox+r[1],r[2],r[3],r[4]}end
   if st.mode=="pinned"and inside(cx,cy,hot(fr.hot.back))then where="back"
   elseif fr.hot.link and inside(cx,cy,hot(fr.hot.link))then where="link"
   elseif inside(cx,cy,hot(fr.hot.card))then where="panel"
    for _,h in ipairs(lay.hot)do if inside(cx,cy,{ox+h.x,h.y,h.w,h.h})then if h.id=="plate"then plate=h.i elseif h.id=="avgswitch"then swap=true else hover=hover or {kind=h.id,i=h.i}end end end
   end
  end
  -- the held or tapped-on scoreboard is drawn in this pass far under the card, so while it shows the card, its dim and the tip step aside and keep their state
  local held=sb.state~=nil and sb.S.held(sb.state,os.clock(),sb.finished and sb.finished())and not (sb.hold_layout and sb.hold_layout(true)=="off")
  if held then where=nil end
  local press=input_get(input,"left_pressed")==true
  -- a click on a plate shows that operative's card, and locks it
  if not held and press and plate and st.mode~="closed"then st.sel=plate end
  -- a click on the Against heading of your own card flips it between your average and the squad's, kept for next time
  if not held and press and swap and st.mode~="closed"then mod:set("endscreen_squad_average",mod:get("endscreen_squad_average")~=true)end
  local hv=st.mode~="closed"and not held and hover or nil
  if (hv and (not st.hover or st.hover.kind~=hv.kind or st.hover.i~=hv.i))or (not hv and st.hover)then st.hover=hv end
  local act=not held and M.step(st,where,press,input_get(input,"back")==true,t)
  if act=="link"then open_history(s.model.run_id)end
  if st.mode~="closed"and not seen then mod:set(M.TIP_KEY,true);seen=true end
  if not seen and not held and not pad then tip(view,renderer,sh,t,a,k)end
  local pinned=st.mode=="pinned"
  put(renderer,pinned and "Click To Unlock"or where=="bar"and "Click To Lock"or "Hover For Debrief",15,hx,hy,pinned and HINT_PIN or where=="bar"and HINT_ON or HINT,a,k,"proxima_nova_medium")
  if st.mode~="closed"and not held then
   lay=layout(view,f,sb,s,sh);fr=frame(view,sh,where=="back",s.model.run_id,where=="link")
   for _,o in ipairs(fr.ops)do op(renderer,o,ox,a,k)end
   for _,o in ipairs(lay.ops)do op(renderer,o,ox,a,k)end
   if not faceless then local ok,err=pcall(portrait,view,renderer,lay,s.card,ox,a);if not ok then faceless=true;mod:error("I/O end screen portrait: %s",tostring(err))end end
  end
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
  -- a mission picked up after a mods reload, or joined late before the server's clock reached it, shows how long it was tracked, with a + for at least
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
  local sb=mod.io_scoreboard;if sb and sb.over_end then sb.over_end(renderer,name,input)end
 end
 -- Layout E: while the vote is up it sits on the line under Continue, its right edge on Continue's, and Rate Mission is always lifted to the screen's right edge, level with the XP bar; with End Screen off the game's own layout is kept
 -- the XP bar's middle is 244 up from the screen's foot, and Rate Mission's title and thumbs, 12 to 78 down its 96, have theirs 51 up from its own
 local LINE,GAP,LIFT_X,LIFT_Y=31,8,169.2,-(244-51)
 -- Vote Complete: on one line in a box twice Continue's width, its end on Continue's, CLEAR above Continue's words
 local CLEAR=8
 local function node(view,id,x,y,ha)
  local kept=view.io_kept;local n=view._ui_scenegraph[id];local p=n.position
  local o=kept[id]or {p[1],p[2],n.horizontal_alignment};kept[id]=o;if x==nil then x,y,ha=o[1],o[2],o[3]end
  if p[1]~=x or p[2]~=y or n.horizontal_alignment~=ha then view:_set_scenegraph_position(id,x,y,nil,ha);return true end
 end
 local function styles(view,c)
  local w=view._widgets_by_name;local vs,cs=w.stay_in_party_vote.style,w.continue_button.style;cs.hotspot=cs.hotspot or {}
  local hot={size={0,LINE},offset={0,0,0}};view.io_hot=hot
  -- Continue's own hints sit under its text, where the vote now is, so they go above it, and the vote's own hint, under the screen's edge now, a line above those
  local function up(o,dy,dx)o=o or {0,0,0};return {(o[1]or 0)-(dx or 0),(o[2]or 0)-dy,o[3]or 0}end
  local done=cs.vote_done_tooltip
  local list={{vs.vote_text,"text_horizontal_alignment","right"},{vs.vote_count_text,"text_horizontal_alignment","right"},{vs.vote_count_text,"font_size",22},{vs.hotspot,"size",hot.size},{vs.hotspot,"offset",hot.offset},
   {cs.hotspot,"size",{c.size[1],LINE}},{cs.tooltip,"offset",up(cs.tooltip.offset,c.size[2])},
   {done,"offset",up(done.offset,c.size[2]+CLEAR,c.size[1]),always=true},{done,"size",{2*c.size[1],c.size[2]},always=true},
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
  for _,s in ipairs(view.io_sets)do local v=(up or e and s.always)and s[3]or s[4];if s[1][s[2]]~=v then s[1][s[2]]=v end end
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
 -- the game puts its scoreboard prompt right only on its own events, never each frame, so Remove Game's Scoreboard switched either way on the screen already up is put to it here
 local function board(self)local h=hide_board();if self.io_board~=h then self.io_board=h;self:_update_session_stats_prompt()end end
 -- the mod turned off stops its hooks, so an end screen already up gets the game's rating, vote and scoreboard prompt back at once, and its scoreboard is hidden again when the mod comes back
 function M.off()Hold.off();local ui=Managers.ui;local v=ui and ui:view_instance("end_view");if v then rating(v);place(v);v.io_board=nil;v:_update_session_stats_prompt()end end
 mod:hook_require("scripts/ui/views/end_view/end_view",function(EndView)
  if EndView.io_endscreen==M then return end;EndView.io_endscreen=M
  mod:hook_safe(EndView,"_setup_rate_match",rating)
  -- hidden, the thumbs up and down send no rating, even by their keys
  mod:hook(EndView,"rate_match",function(func,self,rating)
   if hide_rating()then return end
   return func(self,rating)
  end)
  mod:hook_safe(EndView,"update",function(self)rating(self);board(self);if mod:is_enabled()or self.io_kept then place(self)end end)
  -- the game's own scoreboard stays shut while hidden, by its prompt or its key, and a press shuts one left open; shown, the game's own prompt is put back
  mod:hook(EndView,"_toggle_session_stats",function(func,self,...)if hide_board()then return self:_update_session_stats_prompt()end;return func(self,...)end)
  mod:hook(EndView,"_update_session_stats_prompt",function(func,self,...)
   if not hide_board()then return func(self,...)end
   local w=self._widgets_by_name and self._widgets_by_name.session_stats_prompt;if w then w.visible=false end
   local e=self._session_stats_element;if e and e.expanded and e:expanded()then e:set_expanded(false)end
  end)
  mod:hook_safe(EndView,"_draw_widgets",function(self,_,t,input,renderer)draw(self,renderer,"end_view",input,t)end)
  Hold.end_view(EndView)
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
