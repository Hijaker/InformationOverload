return function(mod,collectors,Times)
 local Renderer=require("scripts/managers/ui/ui_renderer")
 local scenegraph={};local settings={material_flags=0};local text_options={}
 -- the mod's one UIHud.draw hook: the scoreboard draws from here too
 mod:hook_safe("UIHud","draw",function(hud)
  if not mod:is_enabled()then return end
  if mod.io_scoreboard then mod.io_scoreboard.hud(hud)end
  if not mod.io_display_options().mission_timer then return end
  local seconds=collectors and collectors:timer_seconds();local renderer=hud._ui_renderer
  if not seconds or not renderer or not renderer.gui then return end
  local text=Times.format(seconds)
  Renderer.begin_pass(renderer,scenegraph,nil,0,settings)
  -- draw_text scales the box but not the font, so the font is scaled here
  local size=22*(renderer.scale or RESOLUTION_LOOKUP.scale or 1)
  Renderer.draw_text(renderer,text,size,"proxima_nova_bold",Vector3(51,31,901),Vector2(180,30),Color(255,0,0,0),text_options)
  Renderer.draw_text(renderer,text,size,"proxima_nova_bold",Vector3(50,30,902),Vector2(180,30),Color(255,235,235,235),text_options)
  Renderer.end_pass(renderer)
 end)
end
