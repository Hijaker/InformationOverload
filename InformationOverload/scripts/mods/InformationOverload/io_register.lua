-- Registers the Information Overload view, its icon package and the /io command.
return function(mod)
 local path="InformationOverload/scripts/mods/InformationOverload/io_view"
 -- The game requires the view on every open, and DMF reruns a required file each time (about 460 files, a 0.2 s hitch); hand it a stub instead.
 local stub=path.."_require"
 local name="information_overload_view"
 local icons="packages/ui/views/system_view/system_view"
 mod:add_require_path(stub)
 local view
 mod:register_view({
  view_name=name,
  view_settings={init_view_function=function()return true end,validation_function=function()return view end,class="InformationOverloadView",path=stub,
   package="packages/ui/views/options_view/options_view",display_name="information_overload_view",state_bound=false,
   disable_game_world=false,game_world_blur=0,load_always=true,load_in_hub=true,use_transition_ui=false},
  view_transitions={},view_options={close_all=false,close_previous=false},
 })
 function mod.io_hold_icons()
  local state=mod:persistent_table("information_overload")
  if state.icons or not Managers.package then return end
  local ok,id=pcall(Managers.package.load,Managers.package,icons,"information_overload",nil)
  if ok then state.icons=id elseif not state.icons_told then state.icons_told=true;mod:error("I/O icons: %s",tostring(id))end
 end
 function mod.io_icons_ready()
  local packages=Managers.package;if not packages then return false end
  return packages:has_loaded(icons)==true
 end
 mod.io_hold_icons()
 function mod.toggle_information_overload()
  local ui=Managers.ui
  if not ui then mod:echo("The panel opens once a character is loaded.");return end
  mod.io_hold_icons()
  if ui:view_active(name)then ui:close_view(name,true)
  else ui:open_view(name,nil,false,false,nil,{use_transition_ui=false})end
 end
 -- The key: in a mission and on its end screen a tap and a hold do what Settings' choice says, the scoreboard or the panel; on the end screen the panel opens as it opens anywhere else.
 -- With a Scoreboard Key bound, I/O's key only opens and closes the panel and the Scoreboard Key has the scoreboard's part of the choice.
 function mod.io_key(down)
  -- the panel closed itself on this press, so the same press must not open it again
  if mod.io_key_closed and os.clock()-mod.io_key_closed<.3 then return end
  local sb,ui=mod.io_scoreboard,Managers.ui
  if not sb or not ui then if down~=false then mod.toggle_information_overload()end;return end
  local o=sb.options();local fin=sb.finished and sb.finished()
  if down==false then
   if not o.own_key and sb.S.release(sb.state,os.clock())=="panel"and not ui:view_active(name)then mod.io_hold_icons();ui:open_view(name,nil,false,false,nil,{use_transition_ui=false,io_tap=not fin})end
   return
  end
  local r=o.own_key and "toggle"or sb.S.press(sb.state,os.clock(),ui:view_active(name),sb.in_mission(),sb.hold_layout and sb.hold_layout(fin~=nil)or o.layout,sb.S.key_mode(o.key,fin~=nil),sb.context and sb.context())
  if r=="close"or r=="toggle"then
   -- in a mission the panel opens without the intro, whether or not the scoreboard is on
   if not ui:view_active(name)and not(o.own_key and fin)and sb.live and sb.live()then mod.io_hold_icons();ui:open_view(name,nil,false,false,nil,{use_transition_ui=false,io_tap=true})else mod.toggle_information_overload()end
  end
 end
 function mod.io_scoreboard_key(down)
  local sb,ui=mod.io_scoreboard,Managers.ui;if not sb or not ui then return end
  if down==false then sb.S.release(sb.state,os.clock());return end
  if ui:view_active(name)then return end
  local o,fin=sb.options(),sb.finished()~=nil;sb.S.press(sb.state,os.clock(),false,sb.in_mission(),sb.hold_layout and sb.hold_layout(fin)or o.layout,sb.S.key_mode(o.key,fin,true),sb.context())
 end
 mod:command("io","Open or close Information Overload",mod.toggle_information_overload)
 mod:command("io_dashboard","Open or close Information Overload",mod.toggle_information_overload)
 -- the view and its pages load last, so a page that fails to load leaves the keys and /io in place, and a view that fails to load never opens
 view=mod:io_dofile(path)
end
