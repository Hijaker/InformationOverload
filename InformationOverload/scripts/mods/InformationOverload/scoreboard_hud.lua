-- Information Overload: the scoreboard over the HUD while the key is held in a mission, beside the Esc menu, while dead and on the end screen.
return function(mod,collectors,api)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local S=mod:io_dofile(base.."scoreboard")
 local Times=mod:io_dofile(base.."mission_times")
 local D=mod:io_dofile(base.."io_view_definitions")
 local W=mod:io_dofile(base.."scoreboard_draw")(S,D)
 local Renderer=require("scripts/managers/ui/ui_renderer")
 local SB={S=S,state={}}
 mod.io_scoreboard=SB
 local get=function(k)return mod:get(k)end
 local opts,opts_at=nil,-1
 function SB.options()local now=os.clock();if not opts or now>=opts_at+.5 then opts=S.options(get);opts_at=now end;return opts end
 -- the squad shows only with Scoreboard turned on, the Tracker Panel only with Tracker
 local function board_on()return mod:get("screen_scoreboard")~=false end
 local function tracker_on()return mod:get("screen_tracker")~=false end
 local function on()return board_on()or tracker_on()end
 local function live_mission()
  local m=api.tracker().mission
  return m~=nil and m.context~=nil and m.context.difficulty~="psykhanium"and not api.in_hub()
 end
 SB.live=live_mission
 -- the mission just played, kept from its last HUD frame until the end screen closes or the hub loads
 local last
 local function end_up()local ui=Managers.ui;return ui~=nil and (ui:view_active("end_view")or ui:view_active("end_player_view"))and true or false end
 function SB.finished()if last and end_up()then return last end end
 -- where a hold of the key works: a mission, or its end screen, with something to show while it is held
 -- a mission counts with the scoreboard off too, so the key keeps its tap and hold there rather than opening the panel on the press
 function SB.in_mission()return live_mission()or SB.finished()~=nil end
 -- what a hold shows where the key is pressed, "off" for nothing: on the end screen (fin) its own choices, in a mission the squad's layout or else the Tracker Panel alone
 function SB.hold_layout(fin)local o=SB.options();if fin then return (board_on()and o.end_layout~="off"or tracker_on()and o.end_tm)and "end"or "off"end;if board_on()and o.layout~="off"then return o.layout end;return tracker_on()and o.this_mission and "tm"or "off"end
 -- what a tapped-on scoreboard belongs to: the live mission, or its end screen, so it goes off when the mission ends
 function SB.context()if live_mission()then return api.tracker().mission end;return SB.finished()end
 -- its saved run, the last in its history if that is this mission, or this mission merged with its part before a rejoin
 function SB.saved_run(f)
  if f.run==nil then local m=f.m;local h=m.history_recorded and f.tracker.data and f.tracker.data.run_history;local r=h and h[#h];local c=r and r.context or {}
   f.run=r and (r.started_at==(m.started_at or "Time unavailable")or r.resumed and c.mission_instance and c.mission_instance==m.context.mission_instance)and c.mission_name==m.context.mission_name and r or false end
  return f.run or nil
 end
 local function final_time(f)return Times.backend(f.run or f.m)or f.m.completion_time end
 local function server_timed(f)local t=final_time(f);return t~=nil and t.source=="backend"end
 function SB.final_seconds(f)local t=final_time(f);return t and t.seconds or f.seconds end
 -- how long a mission with no known start was tracked
 function SB.tracked_seconds(f)return f.tracked end
 -- what the model reads is loaded the first time it is needed
 local deps
 local function load()
  if deps then return deps end
  local Overview=mod:io_dofile(base.."io_overview")
  deps={Team=mod:io_dofile(base.."team_damage"),Times=mod:io_dofile(base.."mission_times"),clean=mod:io_dofile(base.."display_name").clean,class_names=Overview.class_names,runs=Overview.runs,
   title=function(tracker,c)return tracker:run_mission_name(c).." · "..Overview.diff_label(c)end,parts=function(tracker,c)return tracker:run_mission_name(c),Overview.diff_label(c)end,
   incident_counts=function(m)return api.dashboard_tracker().incident_counts(m)end}
  return deps
 end
 -- the squad's sums are rebuilt twice a second at most, the bests once a mission, a finished mission's once and again when the server's time arrives
 local cache,model,model_m,model_at,warm_m,final,final_m,final_backend={},nil,nil,-1,nil,nil,nil,nil
 local function source(m,team,party,finished,exclude,backend)
  local o=mod.io_display_options and mod.io_display_options()or {}
  return {m=m,tracker=api.dashboard_tracker(),team=team,party=party,basis=o.boss_map_timing and "boss"or "victory",overkill=o.includes_overkill==true,cache=cache,final=finished,exclude=exclude,backend=backend}
 end
 local function release()last,final,final_m,model,model_m,warm_m,cache.mission=nil,nil,nil,nil,nil,nil,nil end
 function SB.end_closed()release()end
 local broken
 local function fail(err)if not broken then mod:error("I/O scoreboard: %s",tostring(err))end;broken=true end
 -- a model that fails is told once and stops the overlays, and its callers, Move among them, get no scoreboard rather than the error
 local function made(ok,v)if ok then return v end;fail(v)end
 function SB.live()
  if live_mission()then
   local m=api.tracker().mission;local now=os.clock()
   if model_m~=m or now>=model_at+.5 then
    model=made(pcall(function()return S.model(source(m,collectors:live_squad(m)),load())end))
    model_m,model_at=m,now
   end
   if not model then return nil end
   return model,collectors:timer_seconds()
  end
  local f=SB.finished();if not f then return nil end
  local backend=server_timed(f)
  if final_m~=f.m or final_backend~=backend then
   -- a rejoin merged through the Mourningstar is read from its saved run, the only place that holds the part before the rejoin
   final=made(pcall(function()local run=f.tracker==api.dashboard_tracker()and SB.saved_run(f);local team,party=collectors:live_squad(f.m)
    local whole=run and run.merged_segment_ids and run or f.m;if whole~=f.m then team,party=load().Team.from_run(run),run.party_records end
    backend=server_timed(f);local src=source(whole,team,party,true,run and run.id or nil,backend);src.saved=whole~=f.m
    return S.model(src,load())end));final_m,final_backend=f.m,backend
  end
  if not final then return nil end
  return final,SB.final_seconds(f)
 end
 local ALIGN
 local pen={}
 function pen:rect(x,y,w,h,c,layer)Renderer.draw_rect(self.r,Vector3(x,y,self.z+(layer or 0)),Vector2(w,h),c)end
 -- draw_text scales the box but not the font, so the font is scaled here
 function pen:text(s,x,y,w,h,size,c,align,font)Renderer.draw_text(self.r,tostring(s),math.max(1,size*self.k),font or D.font.body,Vector3(x,y,self.z+4),Vector2(w,h),c,ALIGN[align or "left"])end
 function pen:texture(m,x,y,w,h,c)if Renderer.draw_texture then Renderer.draw_texture(self.r,m,Vector3(x,y,self.z+3),Vector2(w,h),c)end end
 -- a text's width in UI units, measured at the font size it is drawn at
 function pen:width(s,size,font)local ok,w,_,_,caret=pcall(Renderer.text_size,self.r,s,font or D.font.body,math.max(1,size*self.k));if ok and type(w)=="number"then return D.advance(w,caret)/self.k end;return #s*size*.5 end
 -- the game's Tab overlay on a HUD while it shows, and the difficulty icon its mission block holds
 local function overlay(hud)local e=type(hud)=="table"and hud.element and hud:element("HudElementTacticalOverlay");if e and (e._active or (e._alpha_multiplier or 0)>0)then return e end end
 local ICONS={}
 local function icons(e)
  local d=(e._widgets_by_name or {}).danger_info
  ICONS.difficulty=d and d.visible~=false and d.content and d.content.difficulty_icon or nil
  return ICONS
 end
 -- how far down the Tab overlay's Special Condition reaches, the HUD's own wrap of its description kept until the text changes; text and measure
 -- stand in for the overlay's text and the HUD's measure where the overlay has not shown yet, and leave the HUD's kept wrap alone
 local wrap={}
 local function below(e,sw,sh,text,measure)
  local w=e._widgets_by_name or {};local c=w.circumstance_info
  if e._havoc_data then local ok,size=pcall(e.scenegraph_size,e,"circumstance_info_panel");return ok and size and S.below(sw,sh,nil,size[2])or nil end
  if not (c and c.visible and c.content and c.style and c.style.circumstance_description)then return end
  local st=c.style.circumstance_description;local width=st.size and st.size[1]or 525
  if measure then return S.below(sw,sh,S.lines(text,width,function(s)return measure(nil,s,st.font_size or 24,st.font_type)end))end
  text=c.content.circumstance_description
  if wrap.text~=text then wrap.text=text;wrap.lines=S.lines(text,width,function(s)return pen:width(s,st.font_size or 24,st.font_type)end)end
  return S.below(sw,sh,wrap.lines)
 end
 -- where the HUD last put an unmoved squad under the Tab overlay, kept for the Move screen
 local seen
 -- For the Move screen in a mission: how far down an unmoved squad starts under the Special Condition with the Tab overlay up, as the HUD last
 -- placed it, or before the overlay has shown from the condition's own text, measure measuring as measure(_,text,size,font); nil for no lower.
 function SB.tab_below(sw,sh,measure)
  if not live_mission()then return end;local m=api.tracker().mission
  if seen and seen.m==m and seen.sw==sw and seen.sh==sh then return seen.b end
  local ui=Managers.ui;local hud=ui and ui._hud;local ok,e=pcall(function()return hud:element("HudElementTacticalOverlay")end);if not ok or not e then return end
  if e._havoc_data then return below(e,sw,sh)end
  local cm=Managers.state and Managers.state.circumstance;local ok2,name=pcall(function()return cm:circumstance_name()end)
  local ok3,tpl=pcall(function()return require("scripts/settings/circumstance/circumstance_templates")[name]end)
  local key=ok2 and ok3 and type(tpl)=="table"and tpl.ui and tpl.ui.description;if type(key)~="string"or type(Localize)~="function"then return end
  return below(e,sw,sh,Localize(key),measure)
 end
 -- esc says the Esc menu is up: its Tracker Panel is drawn at its own place, and a squad held over it starts under that
 -- fin, the end screen: the squad lines up with the game's currency boxes and the Tracker Panel rests above it, drawn or not
 local function body(renderer,z,squad_too,tm_too,esc,layout,tab,fin)
  local sb,seconds=SB.live();if not sb then return end
  local o=SB.options();layout=layout or o.layout;local k=renderer.scale or RESOLUTION_LOOKUP.scale or 1;local sw,sh=RESOLUTION_LOOKUP.width/k,RESOLUTION_LOOKUP.height/k
  pen.r,pen.z,pen.k=renderer,z,k
  local extra=o.extra and S.EXTRA[layout]==true;local w,h=S.size("squad",layout,math.max(1,#sb.squad),nil,extra);local x,y,f
  if fin then x,y,f=S.end_place(get,sw,sh,w,h,layout,extra)end
  if tm_too and tab then local tx,ty,tf,cats=S.tab_slot(sw,sh,get);W.tab(pen,tx,ty,sb.tm,seconds,tf,cats,icons(tab))
  elseif tm_too then local tw,th=S.size("tm",nil,nil,S.record(sb.tm,seconds)~=nil);local tx,ty
   -- placed as if at its tallest, so a best-clear line coming or going never moves it
   if fin then tx,ty=S.end_tm_place(sw,x,y,w*f,tw,th)else tx,ty=S.place(esc and "tm_esc"or "tm",get,sw,sh,tw,select(2,S.size("tm",nil,nil,true)))end;W.tm(pen,tx,ty,sb.tm,seconds)end
  if squad_too and #sb.squad>0 then
   if not fin then local b=tab and below(tab,sw,sh);if tab then seen={m=api.tracker().mission,sw=sw,sh=sh,b=b or nil}end;x,y,f=S.squad_place(get,sw,sh,w,h,esc,b,extra)end
   W.squad(pen,layout,x,y,sb.squad,seconds,extra,f)
  end
 end
 local function draw(renderer,z,squad_too,tm_too,esc,layout,tab,fin)
  if not ALIGN then local v=Gui.VerticalAlignCenter;ALIGN={left={horizontal_alignment=Gui.HorizontalAlignLeft,vertical_alignment=v},right={horizontal_alignment=Gui.HorizontalAlignRight,vertical_alignment=v},center={horizontal_alignment=Gui.HorizontalAlignCenter,vertical_alignment=v}}end
  local ok,err=pcall(body,renderer,z,squad_too,tm_too,esc,layout,tab,fin)
  if not ok then fail(err)end
 end
 -- the bests are worked out on the mission's first HUD frame, not the first time the key is held
 local function warm(m)
  if not m.context then return end;warm_m=m;if not live_mission()then return end
  local ok,err=pcall(S.warm,source(m),load());if not ok then fail(err)end
 end
 local settings={material_flags=0};local scenegraph={}
 local function esc_shows(ui,o)return o.esc and tracker_on()and ui:active_top_view()=="system_view"end
 -- what a HUD draws this frame: the squad, the Tracker Panel, and whether the Esc menu is up; nil for nothing
 local function plan(ui,hud)
  if broken or not on()then return end
  local spectator=ui._spectator_hud;if hud~=(ui._hud or spectator)then return end
  local held=S.held(SB.state,os.clock(),SB.context())
  local dead=not held and spectator~=nil and hud==spectator and tracker_on()and SB.options().dead
  if not held and not dead then return end
  local o=SB.options();local squad=held and board_on()and o.layout~="off"
  -- the Esc menu draws its own This Mission, so the HUD leaves it out rather than draw it twice
  local esc=esc_shows(ui,o);local tm_too=tracker_on()and (dead or o.this_mission)and not esc
  if not squad and not tm_too then return end
  return squad,tm_too,esc
 end
 -- called from the one UIHud.draw hook, in mission_timer_hud
 function SB.hud(hud)
  local ui=Managers.ui;if not ui then return end
  local spectator=ui._spectator_hud;if hud~=(ui._hud or spectator)then return end
  local m=api.tracker().mission
  -- the clock is kept each frame, since it stops counting once the mission is over
  if live_mission()then if not last or last.m~=m then last={m=m,tracker=api.tracker()}end;last.seconds=collectors:timer_seconds()or last.seconds;last.tracked=collectors:tracked_seconds()or last.tracked
  elseif last and api.in_hub()then release()end
  -- an overlay that broke still lets the end screen read the mission just played
  if broken or not on()then return end
  if m and m~=warm_m then warm(m)end
  local squad,tm_too,esc=plan(ui,hud);if squad==nil then return end
  local renderer=hud._ui_renderer;if not renderer or not renderer.gui then return end
  -- the game dims a pass by the settings it begins with, and the HUD keeps its dimming under the Tab overlay in its own, so this pass is never dimmed
  Renderer.begin_pass(renderer,scenegraph,nil,0,settings)
  -- the game's UI goes no higher than layer 999, and anything drawn above it lands there with its box over its text, so the boxes
  -- sit just under and the text on 999, level with the cutscene bars and above their fade on 998
  draw(renderer,995,squad,tm_too,esc,nil,overlay(hud))
  Renderer.end_pass(renderer)
 end
 -- beside the Esc menu, drawn inside the menu's own pass and only while it is the top view
 mod:hook_require("scripts/ui/views/system_view/system_view",function(SystemView)
  if SystemView.io_scoreboard==SB then return end;SystemView.io_scoreboard=SB
  mod:hook_safe(SystemView,"_draw_widgets",function(_,_,_,_,renderer)
   if broken or not mod:is_enabled()or not renderer or not tracker_on()then return end
   local ui=Managers.ui;if not ui or not esc_shows(ui,SB.options())then return end
   draw(renderer,200,false,true,true)
  end)
 end)
 -- on the end screen, held, inside the end view's own pass; screen_endscreen's hook calls it with the view it hooked
 function SB.over_end(renderer,name)
  if broken or not renderer or not on()then return end
  local ui=Managers.ui;if not ui or ui:active_top_view()~=name or not S.held(SB.state,os.clock(),SB.finished())then return end
  local o=SB.options();local squad,tm=board_on()and o.end_layout~="off",tracker_on()and o.end_tm
  if not squad and not tm then return end
  draw(renderer,200,squad,tm,false,o.end_layout,nil,true)
 end
 return SB
end
