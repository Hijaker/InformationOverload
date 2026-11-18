-- Information Overload: the game's news in a bar under Start on Character Select, while the service record has the top right where the game's
-- news card would be. It steps through the card's own slides on the card's own clock, and a click opens them as the card does.
return function(mod)
 local N={}
 local M="content/ui/materials/"
 local PICTURE,TERMINAL,GRADIENT,DIVIDER,TILE,CORNER,SQUARE=M.."backgrounds/news_feed/article_image_blank",M.."backgrounds/terminal_basic",
  M.."gradients/gradient_vertical",M.."dividers/horizontal_frame_big_lower",M.."frames/frame_tile_2px",M.."frames/frame_corner_2px",M.."backgrounds/default_square"
 -- the bar in UI units: the play button's width, below the play button's node with its eagle; GAP leaves room for the metal dividers,
 -- which stand 20 out from the bar
 local NODE,H,GAP,PIC_W,PIC_H="play_button",84,26,108,54
 local WHITE,LABEL,SHADOW,TRACK={255,218,228,210},{255,117,126,110},{150,0,0,0},{46,255,255,255}
 local FADE=.3
 -- the slide strip: its ticks 8 apart, their top 12 up from the bar's foot, under the line below the headline
 local STRIP_GAP,STRIP_UP=8,12
 local Renderer,UIWidget,Text,Sounds,LEFT
 local total_time
 local state={}
 -- the frame and the picture keep materials in the menu's renderer, which goes when the menu does, so a new menu gets new ones
 local made={}
 function N.reset()state,made={}, {}end
 local function slides(news)local s=news._slide_data;if type(s)=="table"and #s>0 then return s end end
 local function settings_time()
  if total_time then return total_time end
  local ok,s=pcall(require,"scripts/ui/view_elements/view_element_news_slide/view_element_news_slide_settings")
  total_time=ok and type(s)=="table"and tonumber(s.total_time)or 16;return total_time
 end
 local function sound(name)local ui=Managers.ui;local e=Sounds and Sounds[name];if ui and ui.play_2d_sound and e then pcall(ui.play_2d_sound,ui,e)end end
 -- time left on an event, as the game's card words it; nothing once it has run out
 local function countdown(slide)
  local at=tonumber(slide.timer_countdown);if not at then return nil end
  local b,tm=Managers.backend,Managers.time;if not (b and b.get_server_time and tm)then return nil end
  local ok,now=pcall(b.get_server_time,b,tm:time("main"));if not ok or type(now)~="number"then return nil end
  local left=math.max(at-now,0)/1000;if left<=0 then return nil end
  Text=Text or require("scripts/utilities/ui/text")
  local okf,s=pcall(Text.format_time_span_localized,left,true);if okf and type(s)=="string"and s~=""then return s end
 end
 -- the picture cropped to the box from its top centre, as the game's card crops it
 local function uvs(tex,uv)
  local sx,sy=PIC_W/tex.width,PIC_H/tex.height;local s=math.max(sx,sy);local u,v=sx/s,sy/s;local u0=(1-u)/2
  uv[1][1],uv[1][2],uv[2][1],uv[2][2]=u0,0,1-u0,v
 end
 local function widget(name,passes,w)
  UIWidget=UIWidget or require("scripts/managers/ui/ui_widget")
  return UIWidget.init(name,UIWidget.create_definition(passes,NODE,{},{w,H},nil,{offset={0,0,0}}))
 end
 local function pass(t,value,id,style)return {pass_type=t,value=value,value_id=id,style_id=id,style=style}end
 -- the wallet's panel beside Start: its terminal background and the big metal dividers above and below, the play button's shading, and a
 -- portrait's frame round the picture; the gold edge and corners an operative's row gets under the mouse
 local function frame_widget(w)
  return widget("io_news_bar_frame",{
   pass("texture",TERMINAL,"bg",{color={255,90,115,83},offset={-10,-10,38},size={w+20,H+20},scale_to_material=true}),
   pass("texture",GRADIENT,"shade",{color={155,101,133,96},offset={0,0,39},size={w,H}}),
   pass("texture",SQUARE,"lit_fill",{color={0,167,129,64},offset={0,0,40},size={w,H}}),
   pass("texture",TILE,"lit",{color={0,167,129,64},offset={0,0,40},size={w,H}}),
   pass("texture",CORNER,"lit_corner",{color={0,250,189,73},offset={0,0,41},size={w,H}}),
   pass("texture_uv",DIVIDER,"top",{color={255,255,255,255},uvs={{0,1},{1,0}},offset={-15,-20,44},size={w+30,36},scale_to_material=true}),
   pass("texture",DIVIDER,"bottom",{color={255,255,255,255},offset={-15,H-16,44},size={w+30,36},scale_to_material=true}),
   pass("texture",TILE,"pic_frame",{color={255,60,78,57},offset={17,13,43},size={PIC_W+4,PIC_H+4}}),
   pass("texture",CORNER,"pic_corner",{color={255,121,136,109},offset={17,13,44},size={PIC_W+4,PIC_H+4}}),
  },w)
 end
 local function picture_widget()
  return widget("io_news_bar_picture",{pass("texture_uv",PICTURE,"picture",{material_values={},uvs={{0,0},{1,1}},offset={0,0,42},size={PIC_W,PIC_H},color={255,255,255,255}})},PIC_W)
 end
 local function rect(r,x,y,w,h,c,z)Renderer.draw_rect(r,Vector3(x,y,z or 50),Vector2(w,h),c)end
 -- a small arrow pointing left or right, its rows widest in the middle
 local function arrow(r,x,y,dir,c)for j=-8,6,2 do local w=9-math.abs(j+1);rect(r,dir>0 and x-4 or x+5-w,y+j,w,2,c,51)end end
 local function faded(c,a,out)out[1],out[2],out[3],out[4]=c[1]*a,c[2],c[3],c[4];return out end
 local tint={0,0,0,0}
 -- a line cut short to its room, as the game cuts one; width in UI units and the font at its unscaled size
 local function crop(r,s,width,size)
  if s~=""and Renderer.crop_text_width then local ok,t=pcall(Renderer.crop_text_width,r,s,"proxima_nova_bold",size,width);if ok and type(t)=="string"then return t end end
  return s
 end
 local function words(r,s,size,x,y,w,c,a,k)
  if a<=0 or s==""then return end
  LEFT=LEFT or {horizontal_alignment=Gui.HorizontalAlignLeft,vertical_alignment=Gui.VerticalAlignCenter}
  local px=math.max(1,size*k);local plain=s:gsub("{#[^}]*}","")
  Renderer.draw_text(r,plain,px,"proxima_nova_bold",Vector3(x+1,y+2,50),Vector2(w,size+6),faded(SHADOW,a,tint),LEFT)
  Renderer.draw_text(r,s,px,"proxima_nova_bold",Vector3(x,y,51),Vector2(w,size+6),faded(c,a,tint),LEFT)
 end
 -- the bar and what it does this frame; news is the game's card, hidden under the record
 function N.draw(view,renderer,dt,input,k,mx,my)
  local news=view._news_element;local list=news and slides(news);local node=view._ui_scenegraph and view._ui_scenegraph[NODE]
  if not list or not node or not node.world_position then return end
  Renderer=Renderer or require("scripts/managers/ui/ui_renderer")
  if not Sounds then local ok,s=pcall(require,"scripts/settings/ui/ui_sound_events");Sounds=ok and type(s)=="table"and s or {}end
  local n=#list;local idx=news._current_index;if type(idx)~="number"or not list[idx]then idx=1;news._current_index=1 end
  -- the card's own clock, run here while the card itself is hidden and so does not run it
  if n>1 then news._slide_time=(news._slide_time or 0)+(dt or 0);if news._slide_time>=settings_time()then news:_change_slide_in_direction(1)end end
  local pos,w=node.world_position,(node.size and node.size[1])or 600
  -- the bottom divider kept on screen, which lifts the bar a little on a screen 1080 high
  local x,y=pos[1],math.min(pos[2]+((node.size and node.size[2])or 0)+GAP,RESOLUTION_LOOKUP.height/k-H-20)
  -- the cursor on the bar lights it; a click on an arrow steps, anywhere else opens the news as the card would; one slide has no arrows
  local over=mx~=nil and mx>=x and mx<=x+w and my>=y and my<=y+H
  if over and not state.over then sound("default_mouse_hover")end;state.over=over
  local ax=x+w-34
  local function step(dir)news:_change_slide_in_direction(dir);sound("default_click")end
  local function get(name)if input and name then local ok,v=pcall(input.get,input,name);return ok and v end end
  if over and get("left_pressed")==true then
   local arrows=n>1 and my<=y+H/2
   if arrows and mx>=ax-42 and mx<=ax-18 then step(-1)elseif arrows and mx>=ax-6 and mx<=ax+18 then step(1)
   elseif not news.can_open_view or news:can_open_view()then sound("default_click");news:view_requested()end
  end
  -- a controller steps and opens with the card's own buttons
  if n>1 and get(news._input_action_right)then step(1)elseif n>1 and get(news._input_action_left)then step(-1)
  elseif get(news._input_action_open_news)and (not news.can_open_view or news:can_open_view())then news:view_requested()end
  idx=news._current_index;if not list[idx]then idx=1 end;local slide=list[idx]
  -- a slide changing fades in; the bar showing first does not
  if state.idx~=idx or state.list~=list then state.t=state.list and 0 or FADE;state.idx,state.list=idx,list end
  state.t=(state.t or FADE)+(dt or 0);local a=math.min(1,state.t/FADE)
  if made.r~=renderer or made.w~=w then made={r=renderer,w=w}end
  made.frame=made.frame or frame_widget(w)
  local f=made.frame;f.offset[1],f.offset[2]=x-pos[1],y-pos[2]
  f.style.lit.color[1],f.style.lit_corner.color[1],f.style.lit_fill.color[1]=over and 255 or 0,over and 255 or 0,over and 40 or 0
  UIWidget.draw(f,renderer)
  -- the picture once the card has it loaded; one the game will not draw is left out and noted once in the log, and the rest carries on
  local tex=slide.image_url and news._textures and news._textures[slide.image_url]
  if made.picture~=false and tex and tex.texture and tonumber(tex.width)and tonumber(tex.height)and tex.width>0 and tex.height>0 then
   local ok,err=pcall(function()
    made.picture=made.picture or picture_widget()
    local p=made.picture;local st=p.style.picture;st.material_values.texture=tex.texture;uvs(tex,st.uvs)
    p.offset[1],p.offset[2]=x+19-pos[1],y+15-pos[2];p.alpha_multiplier=a
    UIWidget.draw(p,renderer)
   end)
   if not ok then made.picture=false;if mod.info then mod:info("I/O news bar picture left out: %s",tostring(err))end end
  end
  -- the headline, and under it the time left in gold then the card's own words for it, each on one line cut to its room
  local tx=x+19+PIC_W+18;local tw=x+w-(n>1 and 96 or 16)-tx;local sw=x+w-16-tx
  local left=countdown(slide);local body=type(slide.body_text)=="string"and slide.body_text or ""
  local sub=left and "{#color(199,167,129)}"..left.."{#reset()}"..(body~=""and "  "..crop(renderer,body,sw-90,19)or "")or crop(renderer,body,sw,19)
  local title=crop(renderer,type(slide.title)=="string"and slide.title or "",tw,24)
  if sub~=""then words(renderer,title,24,tx,y+14,tw,WHITE,a,k);words(renderer,sub,19,tx,y+44,sw,LABEL,a,k)
  else words(renderer,title,24,tx,y+(H-30)/2,tw,WHITE,a,k)end
  -- the arrows, and one tick a slide in a strip along the foot under the words, the one showing filling on the card's clock
  if n>1 then
   local ac=over and WHITE or LABEL;arrow(renderer,ax-30,y+30,-1,ac);arrow(renderer,ax+6,y+30,1,ac)
   local gap=STRIP_GAP;local tick=(x+w-20-tx-(n-1)*gap)/n;local ty=y+H-STRIP_UP
   for i=1,n do rect(renderer,tx+(i-1)*(tick+gap),ty,tick,5,TRACK,50)end
   local p=math.max(0,math.min(1,(news._slide_time or 0)/settings_time()))
   rect(renderer,tx+(idx-1)*(tick+gap),ty,tick*p,5,WHITE,51)
  end
  return true
 end
 return N
end
