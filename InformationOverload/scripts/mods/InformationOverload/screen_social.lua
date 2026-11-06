-- Information Overload: the Squad Social screen, class and level and missions together on each player in the Mourningstar social roster, and a record over the list while a Strike Team entry is hovered.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local M={id="social",name="Squad Social",place="Mourningstar",icon="social",rows={
  {key="social_class_level",label="Class And Level",help="Fills in the class and level each friend last played with you.",kind="toggle",default=true},
  {key="social_missions_together",label="Missions Together",help="How many missions you have played with each friend.",kind="toggle",default=true},
  {key="social_own_record",label="Your Record On This Operative",help="Hover yourself in the Strike Team for your record on the operative you play.",kind="toggle",default=true},
  {key="social_team_record",label="In Your Strike Team",help="Hover a teammate in the Strike Team for your record together.",kind="toggle",default=true},
 }}
 local defaults={};for _,r in ipairs(M.rows)do defaults[r.key]=r.default end
 local function row(key)local v=mod:get(key);if v==nil then return defaults[key]end;return v==true end
 local function on()return mod:is_enabled()and mod:get("screen_social")~=false end
 local I=mod:io_dofile(base.."player_identity")
 local deps
 local function load()
  if not deps then local Overview=mod:io_dofile(base.."io_overview");deps={runs=Overview.runs,class_names=Overview.class_names,class_name=mod:io_dofile(base.."records").class_name}end
  return deps
 end
 -- one entry per person, newest mission first, reachable by Steam id and by account id
 function M.build(tracker)
  local by={};local runs=load().runs(tracker)
  for _,run in ipairs(runs)do local seen={}
   local function take(p)
    if type(p)~="table"or p.personal then return end
    local key=I.key(p);if not key then return end
    local account=p.account_id and "account:"..tostring(p.account_id)
    local e=by[key]or account and by[account];if not e then e={missions=0}end
    by[key]=e;if account then by[account]=e end
    if not seen[e]then seen[e]=true;e.missions=e.missions+1 end
    if e.class==nil and p.class then e.class=p.class;e.level=tonumber(p.level)end
   end
   local c=run.context or {}
   for _,p in pairs(c.operative_roster or {})do take(p)end
   for _,p in pairs(run.operative_clutches or {})do take(p)end
  end
  return by
 end
 local model,model_seq,model_n,model_rev
 function M.model()
  local tracker=api.dashboard_tracker();local data=tracker and tracker.data;if not data then return nil end
  local seq,n,rev=data.run_sequence,#(data.run_history or {}),data.history_policy_revision
  if not model or seq~=model_seq or n~=model_n or rev~=model_rev then model=M.build(tracker);model_seq,model_n,model_rev=seq,n,rev end
  return model
 end
 function M.reset()model=nil end
 function M.find(by,info)
  if not by then return end
  local platform=type(info.platform)=="function"and info:platform()
  local id=platform=="steam"and type(info.platform_user_id)=="function"and info:platform_user_id()
  local e=id and id~=""and by[tostring(id)]
  if e then return e end
  local account=type(info.account_id)=="function"and info:account_id()
  return account and by["account:"..tostring(account)]
 end
 function M.class_level(e)
  local d=load();local class=d.class_names[e.class]or d.class_name(e.class)
  return e.level and "Level "..e.level.." "..class or class
 end
 function M.together(n)return n..(n==1 and " Mission Together"or " Missions Together")end
 local FILLED={player_plaque_offline=true,player_plaque_platform_online=true}
 local COUNTED={player_plaque=true,player_plaque_offline=true,player_plaque_platform_online=true}
 local broken
 local function fail(err)broken=true;mod:error("I/O social: %s",tostring(err))end
 local decorated=setmetatable({},{__mode="k"})
 local function bare(content)if content.io_status and content.status==content.io_status then content.status=content.io_status_base end;content.io_status=nil;content.io_together=""end
 -- the game sets status once, so what was added is taken back before it is written again
 function M.decorate(widget,info,blueprint)
  local content=widget and widget.content;if not content or type(info)~="table"or not COUNTED[blueprint]then return end
  bare(content)
  if not on()then return end
  decorated[content]=true
  if type(info.is_own_player)=="function"and info:is_own_player()then return end
  local e=M.find(M.model(),info);if not e then return end
  if FILLED[blueprint]and e.class and type(content.status)=="string"and row("social_class_level")then
   content.io_status_base=content.status;content.io_status=content.status.." · "..M.class_level(e);content.status=content.io_status
  end
  if row("social_missions_together")then content.io_together=M.together(e.missions)end
 end
 -- the mod turned off stops its hooks, so every plaque it filled in gets the game's text back at once
 function M.off()for content in pairs(decorated)do bare(content)end end
 -- the records: yours from the Dossier's figures per operative, a teammate's from the missions they were in, each built once per history
 local Rec,People
 local function record()Rec=Rec or mod:io_dofile(base.."social_record");return Rec end
 local own,mates,rec_data,rec_seq,rec_n,rec_rev
 local function fresh(tracker)
  local data=tracker and tracker.data;if not data then return false end
  local seq,n,rev=data.run_sequence,#(data.run_history or {}),data.history_policy_revision
  if not mates or data~=rec_data or seq~=rec_seq or n~=rec_n or rev~=rec_rev then own,mates=nil,{};rec_data,rec_seq,rec_n,rec_rev=data,seq,n,rev end
  return true
 end
 function M.own(id)
  local tracker=api.dashboard_tracker();if not id or not fresh(tracker)then return nil end
  if not own then own={};People=People or mod:io_dofile(base.."io_data_people");for _,ch in ipairs(People.dossier(tracker).chars)do own[ch.id]=record().own(tracker,ch)end end
  return own[tostring(id)]
 end
 local function who(info)
  local platform=type(info.platform)=="function"and info:platform()
  local sid=platform=="steam"and type(info.platform_user_id)=="function"and info:platform_user_id()
  local acc=type(info.account_id)=="function"and info:account_id()
  return {sid=sid and sid~=""and tostring(sid)or nil,acc=acc and acc~=""and tostring(acc)or nil}
 end
 function M.mate(info)
  local tracker=api.dashboard_tracker();if not fresh(tracker)then return nil end
  local w=who(info);local key=w.sid or w.acc and "account:"..w.acc;if not key then return nil end
  if mates[key]==nil then mates[key]=record().mate(tracker,load().runs(tracker),w)end
  return mates[key]
 end
 local function char_id(info)return type(info.character_id)=="function"and info:character_id()end
 local function has(info,mine)if mine then return M.own(char_id(info))~=nil end;local m=M.mate(info);return m~=nil and m.games>0 end
 -- the match files behind the damage figures are read one a frame while the record is up, and the page is rebuilt as they come in
 local function warm(m,list)if m.ready then return m.ready end;local done,n=record().warm(list(m));if done==n then m.ready=n end;return done end
 local function own_runs(o)local t={};for _,w in ipairs(o.weapons)do for _,r in ipairs(w.runs)do t[#t+1]=r end end;return t end
 local function mate_runs(m)local t={};for _,s in ipairs(m.shared)do t[#t+1]=s.run end;return t end
 local page,page_key={}, {}
 function M.page(info,mine,k)
  local R=record();local m=mine and M.own(char_id(info))or not mine and M.mate(info);if not m or not mine and m.games==0 then return nil end
  local done=warm(m,mine and own_runs or mate_runs)
  local acct=not mine and (type(info.user_display_name)=="function"and info:user_display_name()or "")or nil
  local key=page_key;if key[1]==m and key[2]==k and key[3]==done and key[4]==acct then return page end
  page=mine and R.own_page(m,R.weapon_damage(m),k)or R.mate_page(m,acct,(R.best_damage(api.dashboard_tracker(),m)),k)
  page_key={m,k,done,acct};return page
 end
 function M.reset_records()rec_data,page,page_key=nil,{}, {}end
 -- the Strike Team entry under the cursor while the mouse is in use or under the gamepad's focus, when its record is on and there is one
 local function showing(view)
  if broken or not on()or view._popup_menu then return end
  local ui=Managers.ui;local pad=ui and ui.using_cursor_navigation and not ui:using_cursor_navigation()
  for _,w in ipairs(view._party_widgets or {})do local c=w.content;local h=c and c.hotspot
   if h and (h.is_hover and not pad or h.is_focused)and type(c.player_info)=="table"then local info=c.player_info
    local mine=type(info.is_own_player)=="function"and info:is_own_player()==true
    if row(mine and "social_own_record"or "social_team_record")and has(info,mine)then return info,mine end;return
   end
  end
 end
 local Renderer,ALIGN
 local SHADOW={140,0,0,0}
 -- the page is in the mockup's pixels, 2000 wide, with the friends list's top left corner at 762,270
 local F=1920/2000
 local function body(view,renderer,info,mine)
  local node=view._ui_scenegraph and view._ui_scenegraph.roster_panel;local pos=node and node.world_position;if not pos then return end
  local k=renderer.scale or RESOLUTION_LOOKUP.scale or 1
  local L=M.page(info,mine,k);if not L then return end
  Renderer=Renderer or require("scripts/managers/ui/ui_renderer")
  if not ALIGN then local V=Gui.VerticalAlignCenter;ALIGN={l={horizontal_alignment=Gui.HorizontalAlignLeft,vertical_alignment=V},r={horizontal_alignment=Gui.HorizontalAlignRight,vertical_alignment=V}}end
  local z=(pos[3]or 0)+30
  for _,it in ipairs(L)do local x,y,w,h=pos[1]+(it.x-762)*F,pos[2]+(it.y-270)*F,it.w*F,it.h*F
   if it.r then Renderer.draw_rect(renderer,Vector3(x,y,z+it.z),Vector2(w,h),it.c)
   else local s=math.max(1,it.s*F*k);local font=it.f=="m"and "proxima_nova_medium"or "proxima_nova_bold"
    Renderer.draw_text(renderer,it.p,s,font,Vector3(x+1,y+1,z+3),Vector2(w,h),SHADOW,ALIGN[it.a])
    Renderer.draw_text(renderer,it.t,s,font,Vector3(x,y,z+4),Vector2(w,h),it.c,ALIGN[it.a])
   end
  end
 end
 function M.draw(view,renderer,info,mine)
  if broken or not renderer then return end
  local ok,err=pcall(body,view,renderer,info,mine);if not ok then fail(err)end
 end
 -- one more text line on each player plaque, empty unless the screen fills it
 mod:hook_require("scripts/ui/views/social_menu_roster_view/social_menu_roster_view_blueprints",function(B)
  if broken or type(B)~="table"or B.io_social then return end
  local ok,err=pcall(function()
   local Font=require("scripts/managers/ui/ui_font_settings")
   for name in pairs(COUNTED)do local bp=B[name]
    if bp and bp.pass_template and bp.style then
     local s=table.clone(Font.body_small);s.text_horizontal_alignment="right";s.offset={-16,47,2};s.text_color=Color.terminal_text_body_dark(255,true);bp.style.io_together=s
     bp.pass_template[#bp.pass_template+1]={pass_type="text",style_id="io_together",value_id="io_together",value="",visibility_function=function(content)return content.io_together~=nil and content.io_together~=""end}
    end
   end
   B.io_social=true
  end)
  if not ok then fail(err)end
 end)
 mod:hook_require("scripts/ui/views/social_menu_roster_view/social_menu_roster_view",function(View)
  if View.io_social==M then return end;View.io_social=M
  mod:hook(View,"on_enter",function(func,self,...)model=nil;M.reset_records();return func(self,...)end)
  -- while a record shows it takes the friends list's place: the list, its scrollbar, its tabs and its Show hint are left out for that frame
  local cur
  mod:hook(View,"draw",function(func,self,...)
   local ok,info,mine=pcall(showing,self);if not ok then fail(info);info=nil end
   if not info then return func(self,...)end
   local tabs=self._player_list_tab_bar;local bar=self._widgets_by_name and self._widgets_by_name.roster_scrollbar
   local hint=self._widgets_by_name and self._widgets_by_name.show_list;hint=hint and hint.content
   local tv,bv,hv=tabs and tabs._visible,bar and bar.visible,hint and hint.visible
   if tabs then tabs._visible=false end;if bar then bar.visible=false end;if hint then hint.visible=false end
   cur={self,info,mine};func(self,...);cur=nil
   if tabs then tabs._visible=tv end;if bar then bar.visible=bv end;if hint then hint.visible=hv end
  end)
  mod:hook(View,"_draw_roster_grid",function(func,self,...)if cur and cur[1]==self then return end;return func(self,...)end)
  mod:hook_safe(View,"_draw_widgets",function(self,_,_,_,renderer)if cur and cur[1]==self then M.draw(self,renderer,cur[2],cur[3])end end)
  mod:hook(View,"_get_roster_widget",function(func,self,context,blueprint_name,...)
   local widget=func(self,context,blueprint_name,...)
   if not broken then local ok,err=pcall(M.decorate,widget,context,blueprint_name);if not ok then fail(err)end end
   return widget
  end)
 end)
 return M
end
