-- Information Overload: the Havoc screen, your record on the Assignment's map and the Strike Team, over the game's own Havoc screen.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local M={id="havoc",name="Havoc Board",place="Mourningstar",icon="havoc_board",rows={}}
 local D,Model,Layout,UIWidget,UIRenderer,Sounds,Buttons,Graph,Post
 local broken,warned
 local function on()return mod:is_enabled()and mod:get("screen_havoc")~=false end
 -- the Havoc board, read afresh at each call since the composition root publishes it after the screens load; a fault or no board answers nil
 local function ask(name,...)local b=mod.io_havoc;local f=type(b)=="table"and b[name];if type(f)~="function"then return nil end
  local ok,x,y=pcall(f,...);if ok then return x,y end end
 local function fail(err)if broken then return end;broken=true;mod:error("I/O havoc screen: %s",tostring(err))end
 -- the right column in canvas units, from the signed-off design: the reward words' first line level with the band's top, both titles 11.96
 -- lower, the Assignment Rank grown to fill the room from 6 under the second goal down to 41.7 above Deployments until Demotion's ink,
 -- its badge at 0.878 of the label's scale, the label's words 24.5 down it and the badge's frame 46.34 under its top
 local MID,WORDS,DROP,GAP,INK,KEEP=1570,91.6,11.96,6,-33.8,41.7
 local LABEL,LABEL_MID,LABEL_H,BADGE,ART="ASSIGNMENT RANK",24.5,46.34,.878,56
 -- the art in the game's eight badge frames, havoc_rank_1 to 8 for ranks 1, 5, 10 and on to 35: its top and foot as parts of the frame's
 -- height, where alpha is 8 or more in the textures pulled from the Havoc background view's bundle; the badge is sized for the deepest, so
 -- every rank fits and the badge keeps its size and place whoever's rank is shown
 local TIERS={{.156,.745},{.135,.786},{.100,.786},{.100,.786},{.098,.786},{.017,.925},{.019,.919},{.019,.984}}
 local DEEP=0;for _,t in ipairs(TIERS)do DEEP=math.max(DEEP,t[2])end
 -- the spread screen (CONTRACT 08:34): HAVOC and the card picture go with I/O's left block 54 left, the whole right column 66 right, and
 -- everything 20 up
 local SHIFT_L,SHIFT_R,SHIFT_UP=-54,66,-20
 -- the background view's input legend under the left block: Back's ink from its left edge (130), the other three's ink ending at its right
 -- edge (1277), the words' middle at 1078, then spread with everything; the game draws Back's ink 10.48 into its box, ends the three's 7.2
 -- short of theirs, and sets the words' middle 26.2 under the entries' pivot
 local LEGEND_L,LEGEND_R,LEGEND_MID,INK_IN,INK_OUT,MID_DOWN=130,1277,1078,10.48,7.2,26.2
 -- Party Finder drawn as Play, 6 above Play's frame studs (7.76 over its node); Deployments' ink (62.4 tall) keeps 14 clear above its studs
 local STUDS,CLEAR,INK_H=7.76,14,62.4
 -- the box under Play in I/O's words at the design's 16, each sentence on its own line
 local NOTE=16
 -- I/O's parts sit this far over the canvas node, above the game parts they cover and well under the Help tour
 local Z,LAYERS=40,60
 local PICTURE="content/ui/materials/base/ui_default_base"
 -- every game value the screen changes is kept once, so leaving, turning the screen off and M.off each put it back
 local function put(hv,t,k,v)local o=hv.kept.vals[t];if not o then o={};hv.kept.vals[t]=o end;if not o[k]then o[k]={t[k]}end;t[k]=v end
 local function back(hv,t,k)local o=hv.kept.vals[t];local w=o and o[k];if w then t[k]=w[1];o[k]=nil end end
 local function keep(view,id,list,x,y,field)
  local cur=view._ui_scenegraph[id][field];local o=list[id]or {};list[id]=o
  if x and o[1]==nil then o[1]=cur[1]end;if y and o[2]==nil then o[2]=cur[2]end
 end
 local function move(view,id,x,y)keep(view,id,view.io_hv.kept.pos,x,y,"position");view:_set_scenegraph_position(id,x,y)end
 local function resize(view,id,w,h)keep(view,id,view.io_hv.kept.size,w,h,"size");view:_set_scenegraph_size(id,w,h)end
 -- where a node sits on the canvas, laid out from the live scenegraph the way the game lays it out
 local function at(view,id)
  local sg=view._ui_scenegraph
  if id=="canvas"then local s=sg.canvas.size or {1920,1080};return 0,0,s[1],s[2]end
  local n=sg[id];local d=view._definitions.scenegraph_definition[id]or {}
  local px,py,pw,ph=at(view,d.parent or n.parent)
  local p,s=n.position or d.position,n.size or d.size
  local x,y,ha,va=p[1]or 0,p[2]or 0,n.horizontal_alignment or d.horizontal_alignment,n.vertical_alignment or d.vertical_alignment
  if ha=="center"then x=x+(pw-s[1])/2 elseif ha=="right"then x=x+pw-s[1]end
  if va=="center"then y=y+(ph-s[2])/2 elseif va=="bottom"then y=y+ph-s[2]end
  return px+x,py+y,s[1],s[2]
 end
 -- a node moved so its top left lands on canvas x, y; nil leaves that side where it is
 local function place(view,id,x,y)
  local cx,cy=at(view,id);local p=view._ui_scenegraph[id].position
  move(view,id,x and p[1]+x-cx,y and p[2]+y-cy)
 end
 -- HAVOC and Play keep their spread over wherever the game puts them: its enter animation writes their x from the definitions every frame
 -- as they slide, so the spread goes on what it wrote and they slide in to their spread places
 local function pin(view,hv)
  local sg=view._ui_scenegraph
  for id,s in pairs(hv.spread)do local x=sg[id].position[1]
   if x~=hv.set[id]then hv.game[id]=x end
   local want=hv.game[id]+s;if x~=want then view:_set_scenegraph_position(id,want);hv.set[id]=want end
  end
 end
 local function own_rank(view)local o=view._parent and view._parent.havoc_order;return o and o.data and o.data.rank or 1 end
 -- the game's badge for a rank, every pass scaled about its node as the game lays it out
 local function badge(view,rank,s)
  local bd=view._definitions.badge_definitions
  local passes=bd.pass_template_function(view,{rank=math.max(1,math.min(40,math.floor(tonumber(rank)or 1)))})
  for _,p in ipairs(passes)do local st=p.style;if st then
   if st.size then st.size={st.size[1]*s,st.size[2]*s}end
   if st.offset then st.offset={(st.offset[1]or 0)*s,(st.offset[2]or 0)*s,st.offset[3]or 0}end
  end end
  return UIWidget.init("rank_badge",UIWidget.create_definition(passes,"current_rank",nil,{bd.size[1]*s,bd.size[2]*s}))
 end
 -- a widget swapped in where the game keeps one, under the same name so the Help tour still lights it
 local function trade(view,name,old,new)
  for i,x in ipairs(view._widgets)do if x==old then view._widgets[i]=new;break end end
  view._widgets_by_name[name]=new
 end
 -- a badge swapped in for the shown rank; only I/O's own are let go
 local function swap(view,hv,w)
  local old=view._widgets_by_name.rank_badge;if old==w then return end
  trade(view,"rank_badge",old,w)
  if old and old~=hv.kept.badge then pcall(UIWidget.destroy,view._ui_renderer,old)end
 end
 -- Party Finder drawn as the game's Play button: Play's own pass template at its size, with Party Finder's words, button and callback, just
 -- above Play; returns how high Deployments until Demotion's ink may reach
 local function party_finder(view,hv)
  local old=view._widgets_by_name.party_finder_button
  Buttons=Buttons or require("scripts/ui/pass_templates/button_pass_templates")
  local tpl=Buttons and Buttons.default_button;local size=tpl and tpl.size or view._ui_scenegraph.play_button.size
  if tpl and old then
   local pf=UIWidget.init("party_finder_button",UIWidget.create_definition(tpl,"party_finder_button",{gamepad_action="mission_board_group_finder_open",original_text=old.content.original_text,hotspot={}}))
   local hs,oh=pf.content.hotspot,old.content.hotspot
   if hs and oh then hs.pressed_callback=oh.pressed_callback;hs.disabled=oh.disabled end
   trade(view,"party_finder_button",old,pf);hv.kept.pf={old,pf}
  end
  resize(view,"party_finder_button",size[1],size[2])
  local _,py=at(view,"play_button");local top=py-STUDS-6-size[2]
  place(view,"party_finder_button",nil,top)
  return top-STUDS-CLEAR
 end
 -- the Reward Cache title at the HAVOC title's size, smaller only where a language's words would not fit its 400 across
 local function title_size(view,hv,size)
  local w=view._widgets_by_name.reward_title;local s=w.content and w.content.text
  if type(s)~="string"or s==""or not hv.ms then return size end
  local font=w.style.text.font_type or "machine_medium";local wide=math.max(hv.ms(s,font,size),hv.ms(s:upper(),font,size))
  local room=view._ui_scenegraph.reward_title.size[1]-4
  if wide<=room then return size end
  return math.floor(size*room/wide*2)/2
 end
 local function column(view,hv)
  local sg,wb,defs=view._ui_scenegraph,view._widgets_by_name,view._definitions.scenegraph_definition
  -- the words' height as the game measured it for this language, from where its own text positions left the first goal
  local words_h=sg.reward_objective_1.position[2]-sg.reward_description.position[2]-30
  keep(view,"page_header",hv.kept.pos,true,nil,"position");keep(view,"play_button",hv.kept.pos,true,nil,"position")
  hv.spread,hv.set,hv.game={page_header=SHIFT_L,play_button=SHIFT_R},{},{};pin(view,hv)
  move(view,"reward_area",defs.reward_area.position[1]+SHIFT_R,nil)
  local _,hy=at(view,"page_header");place(view,"page_header",nil,hy+DROP+SHIFT_UP)
  -- the Reward Cache title at the HAVOC title's size on a node level with it, so the two share a baseline
  local _,ty,_,th=at(view,"page_header");place(view,"reward_title",nil,ty);resize(view,"reward_title",nil,th)
  local hs,rs=wb.page_header.style.text,wb.reward_title.style.text
  put(hv,rs,"font_size",title_size(view,hv,hs.font_size));put(hv,rs,"text_vertical_alignment",hs.text_vertical_alignment)
  place(view,"reward_description",nil,WORDS+SHIFT_UP)
  -- the chest straight under the words at the game's own gap, the two goals under it, and no Havoc Rewards line
  local chest=WORDS+SHIFT_UP+words_h+30;place(view,"weekly_reward",nil,chest)
  local g1=chest+sg.weekly_reward.size[2]+20;place(view,"reward_objective_1",nil,g1)
  local g2=g1+sg.reward_objective_1.size[2]+10;place(view,"reward_objective_2",nil,g2)
  put(hv,wb.reward_header.content,"visible",false)
  -- Play 44 lower, so the column's foot lines up with the latest runs, Party Finder over it and Deployments until Demotion over that
  move(view,"play_button",nil,defs.play_button.position[2]+44+SHIFT_UP)
  local sy0=defs.havoc_stepper.position[2]-71;move(view,"havoc_stepper",nil,sy0)
  local limit=party_finder(view,hv)
  local _,sy=at(view,"havoc_stepper");local room=math.min(0,limit-(sy+INK+INK_H))
  if room<0 then move(view,"havoc_stepper",nil,sy0+room);sy=sy+room end
  local top,bs=g2+sg.reward_objective_2.size[2]+GAP,view._definitions.badge_definitions.size
  local a=math.max(.5,math.min(1.5,(sy+INK-KEEP-top)/(LABEL_H+DEEP*bs[2]*BADGE)));local b=a*BADGE;hv.a,hv.b=a,b
  local lw,lh=sg.current_rank_header.size[1],sg.current_rank_header.size[2]
  place(view,"current_rank_header",MID+SHIFT_R-lw/2,top+LABEL_MID*a-lh/2)
  local label=wb.current_rank_header
  if type(label.content.text)=="string"then put(hv,label.content,"text",LABEL)end
  put(hv,label.style.text,"font_size",(label.style.text.font_size or 36)*a)
  resize(view,"current_rank",bs[1]*b,bs[2]*b);place(view,"current_rank",nil,top+LABEL_H*a-ART*b)
  if wb.rank_badge then hv.kept.badge=wb.rank_badge;swap(view,hv,badge(view,own_rank(view),b))end
 end
 -- the legend's panel is laid across the screen's foot whatever its own place says, and its entries are set out at draw from the panel's
 -- width, a margin in from each edge: so the entries' pivot is moved, and the margin is this screen's while the legend draws, so Back starts
 -- and the other three end where the left block does; the legend is the background view's and outlives this screen, so it is put back
 local function margin(el,S)
  local rs=el._render_scale or 1
  return (Graph.get_render_size(el._ui_scenegraph,"bottom_panel",rs)/rs-(S.button_spacing or 0)-(LEGEND_R-LEGEND_L+INK_IN+INK_OUT))/2
 end
 local function legend_pin(view,hv)
  local lg=hv.kept.legend;if not lg then return end
  local sg=lg.el._ui_scenegraph;local bp,pv=sg.bottom_panel,sg.entry_pivot
  local cw,bw=view._ui_scenegraph.canvas.world_position,bp.world_position;if not (cw and bw)then return end
  local va=pv.vertical_alignment;local dy=va=="center"and (bp.size[2]-pv.size[2])/2 or va=="bottom"and bp.size[2]-pv.size[2]or 0
  local x=cw[1]+LEGEND_L+SHIFT_L-INK_IN-margin(lg.el,lg.S)-bw[1];local y=cw[2]+LEGEND_MID+SHIFT_UP-MID_DOWN-bw[2]-dy
  if pv.position[1]~=x or pv.position[2]~=y then lg.el:_set_scenegraph_position("entry_pivot",x,y)end
 end
 local function legend(view,hv)
  local el=view._parent and view._parent._input_legend_element;local sg=el and el._ui_scenegraph;local pv=sg and sg.entry_pivot
  if not (pv and pv.position and pv.size and sg.bottom_panel and el._set_scenegraph_position and el._draw_widgets)then return end
  Graph=Graph or require("scripts/managers/ui/ui_scenegraph")
  local S=require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend_settings")
  if type(S)~="table"or type(S.button_edge_margin)~="number"then return end
  local draw=el._draw_widgets
  local lg={el=el,S=S,x=pv.position[1],y=pv.position[2],own=rawget(el,"_draw_widgets"),layer=el._draw_layer}
  lg.wrap=function(self,...)
   local m=S.button_edge_margin;local ok,v=pcall(margin,self,S);if ok then S.button_edge_margin=v end
   local done,err=pcall(draw,self,...);S.button_edge_margin=m
   if not done then error(err,0)end
  end
  el._draw_widgets=lg.wrap;hv.kept.legend=lg
  -- the background view's corner art sits on the screen's own corners, over the legend: on a 16:10 screen the canvas stands 60 clear of the
  -- screen's foot and the words pass the art where it is narrow, but at 16:9 the canvas reaches the foot and Back would lie under the
  -- skull, so the legend's entries draw over the art while its dark panel stays under it
  local art=view._parent._ui_scenegraph;art=type(art)=="table"and rawget(art,"corner_bottom_left");local z=art and art.world_position and art.world_position[3]
  local pz=(pv.world_position or pv.position)[3]or 0;lg.z=pv.position[3]
  if type(lg.layer)=="number"and type(z)=="number"and lg.layer+pz<=z then el:_set_scenegraph_position("entry_pivot",nil,nil,(lg.z or 0)+z-lg.layer-pz+1)end
  legend_pin(view,hv)
 end
 -- the box under Play as wide as Play, so centred under it as the game centres it, rather than reaching past it toward the corner art
 local function under(view)local w=view._ui_scenegraph.play_button.size[1];if view._ui_scenegraph.play_button_disabled_info.size[1]~=w then resize(view,"play_button_disabled_info",w,nil)end end
 -- the game parts I/O's own cover: the head's words, Primary Objective, the reset line and the modifier cards; the card picture goes with
 -- I/O's block
 local function cover(view,hv)
  local wb,sg,defs=view._widgets_by_name,view._ui_scenegraph,view._definitions.scenegraph_definition
  put(hv,wb.detail.style.header_title,"visible",false);put(hv,wb.detail.style.header_subtitle,"visible",false)
  put(hv,wb.objective.content,"visible",false);put(hv,wb.reward_timer_header.content,"visible",false)
  local grid=view._mission_detail_grid;if grid then grid:set_visibility(false);hv.grid=grid end
  move(view,"detail",defs.detail.position[1]+SHIFT_L,defs.detail.position[2]+SHIFT_UP)
  -- the head 70 tall and the picture as much taller, so the picture starts right under I/O's head
  local cut=sg.detail_header.size[2]-70
  resize(view,"detail_header",nil,70);resize(view,"detail_location",nil,sg.detail_location.size[2]+cut)
  move(view,"detail_location",nil,sg.detail_location.position[2]+cut)
 end
 -- your own Assignment on the game's picture and badge, or a teammate's once it is shared
 local function show(view,hv,i,force)
  local st=hv.st;local p=hv.model.players[i]
  if not force and (i==st.shown or not p or i~=1 and not p.a)then return false end
  local d=view._widgets_by_name.detail;local mv=d.style.location_image.material_values
  if i==1 or not (p and p.a)then i=1;back(hv,mv,"texture_map");back(hv,d.content,"locked")
   if hv.kept.badge then swap(view,hv,badge(view,own_rank(view),hv.b))end
  else put(hv,mv,"texture_map",p.a.texture or mv.texture_map);put(hv,d.content,"locked",false)
   if hv.kept.badge then swap(view,hv,badge(view,p.a.rank,hv.b))end
  end
  st.shown=i;return true
 end
 -- the model reads the game at most twice a second and counts again only on a change; the reset line it refreshes in place, a new table when the
 -- time moves; with no Assignment of your own in it the screen stands aside
 local deps={tracker=api and api.dashboard_tracker}
 local function remodel(view,hv,t)
  Model=Model or mod:io_dofile(base.."havoc_model")
  local m,fresh=Model.get(view,deps,t)
  if not (m and m.players and m.players[1]and m.players[1].a)then return false end
  if m~=hv.model or fresh then hv.model,hv.dirty=m,true
   local st=hv.st;st.team=m.team==true
   local p=m.players[st.shown];if st.shown~=1 and not (p and p.a)then show(view,hv,1,true)end
  end
  if m.reset~=hv.reset then local was=hv.reset;hv.reset=m.reset;if was and m.reset and was[1]==m.reset[1]then hv.retime=true else hv.dirty=true end end
  return true
 end
 -- a width as the game measures it, in UI units at the size given, ink or caret whichever is wider
 local function measure(view,hv)
  if hv.ms then return hv.ms end
  D=D or mod:io_dofile(base.."io_view_definitions")
  local memo={}
  hv.ms=function(s,font,size)
   local key=font.."|"..size.."|"..s;local w=memo[key]
   if not w then
    local ok,v,_,_,caret=pcall(view._text_size,view,s,{font_type=font,font_size=size},{2000,200},true)
    if ok and type(v)=="number"and (v>0 or s=="")then w=D.advance(v,caret)
    else w=select(2,s:gsub("[^\128-\191]",""))*size*(font:find("^mono")and .706 or .62)end
    memo[key]=w
   end
   return w
  end
  return hv.ms
 end
 local function rect(passes,x,y,w,h,c,z)if w>0 and h>0 then local id="s"..(#passes+1);passes[#passes+1]={pass_type="rect",style_id=id,style={color={c[1],c[2],c[3],c[4]},offset={x,y,z},size={w,h}}};return id end end
 local function loaded(kind,path)local A=Application;if not (A and A.can_get_resource)then return true end;local ok,yes=pcall(A.can_get_resource,kind,path);return ok and yes==true end
 -- each drawing class its own layer over anything it overlaps, so a later part always lands on top of an earlier one it covers; a frame is
 -- its own class, so it always sits over the fill it edges
 local CLASS={rect="r",frame="f",icon="i",picture="p"}
 local function widgets(ops)
  local passes,content,boxes,slot,sids,words={}, {}, {}, nil, {}, nil
  for i,o in ipairs(ops)do
   local k,x,y,w,h=o.k,o.x,o.y,o.w,o.h;local c=CLASS[k]or "t"..tostring(o.font);local z=0
   for j=1,i-1 do local b=boxes[j]
    if b.x<x+w and x<b.x+b.w and b.y<y+h and y<b.y+b.h then local need=b.z+(b.c==c and 0 or 1);if need>z then z=need end end
   end
   z=math.min(z,LAYERS);boxes[i]={x=x,y=y,w=w,h=h,z=z,c=c}
   if k=="rect"then sids[i]={rect(passes,x,y,w,h,o.c,z)}
   elseif k=="frame"then local t=o.t or 2
    sids[i]={rect(passes,x,y,w,t,o.c,z),rect(passes,x,y+h-t,w,t,o.c,z),rect(passes,x,y+t,t,h-2*t,o.c,z),rect(passes,x+w-t,y+t,t,h-2*t,o.c,z)}
   elseif k=="text"then local id="t"..i;content[id]=o.s;local cl=o.c;sids[i]={id};if o.id=="plate.reset_time"then slot={id=id,i=i,font=o.font,size=o.size,w=o.room or o.w}elseif o.id=="plate.reset"then words=o.s end
    passes[#passes+1]={pass_type="text",value_id=id,style_id=id,style={font_type=o.font,font_size=o.size,text_color={cl[1],cl[2],cl[3],cl[4]},drop_shadow=o.shadow and true or nil,
     text_horizontal_alignment=o.align or "left",text_vertical_alignment="center",offset={x,y,z},size={w,h}}}
   elseif k=="icon"and o.material and loaded("material",o.material)then local cl=o.c;local id="s"..(#passes+1);sids[i]={id}
    passes[#passes+1]={pass_type="texture",value=o.material,style_id=id,style={color={cl[1],cl[2],cl[3],cl[4]},offset={x,y,z},size={w,h}}}
   elseif k=="picture"and o.texture and loaded("texture",o.texture)then
    passes[#passes+1]={pass_type="texture_uv",value=PICTURE,style={color={255,255,255,255},offset={x,y,z},size={w,h},uvs=o.uvs or {{0,0},{1,1}},material_values={texture_map=o.texture}}}
   end
  end
  if #passes==0 then return {}end
  local wd=UIWidget.init("io_havoc",UIWidget.create_definition(passes,"canvas",content,{1920,1080},nil,{offset={0,0,Z}}));wd.visible=true;if slot then slot.words=words end;wd.io_reset,wd.io_ops,wd.io_sids=slot,ops,sids
  return {wd}
 end
 -- every texture pass holds a material of its own, so the widgets a redraw replaces are let go
 local function drop(view,list)if UIWidget then for _,w in ipairs(list or {})do pcall(UIWidget.destroy,view._ui_renderer,w)end end end
 local function lay(view,hv)
  Layout=Layout or mod:io_dofile(base.."havoc_layout")
  local out=hv.pending or Layout.layout(hv.model,hv.st,measure(view,hv))
  local fresh=widgets(out.ops or {})
  drop(view,hv.widgets);hv.widgets,hv.out,hv.dirty,hv.retime,hv.rehover,hv.pending=fresh,out,false,nil,nil,nil
 end
 -- the reset time alone moving is written into the drawn line where it still fits its room, so the last hour's ticking seconds lay nothing out
 local function retime(view,hv)
  hv.retime=nil;local wd=hv.widgets and hv.widgets[1];local sl=wd and wd.io_reset;local s=hv.reset and hv.reset[2]
  if sl and type(s)=="string"and sl.words==hv.reset[1]and measure(view,hv)(s,sl.font,sl.size)<=sl.w then wd.content[sl.id]=s;if wd.io_ops[sl.i]then wd.io_ops[sl.i].s=s end else hv.dirty=true end
 end
 -- the hover alone moving lays the screen out again, and where only colours differ recolours the drawn parts instead of building them again
 local SAME={"k","x","y","w","h","s","font","size","t","texture","material","shadow","align"}
 local function recolour(view,hv)
  hv.rehover=nil;local wd=hv.widgets and hv.widgets[1];local was=wd and wd.io_ops
  Layout=Layout or mod:io_dofile(base.."havoc_layout")
  local out=Layout.layout(hv.model,hv.st,measure(view,hv));local ops=out.ops or {}
  local same=was and #ops==#was
  for i=1,same and #ops or 0 do local o,p=ops[i],was[i];for _,f in ipairs(SAME)do if o[f]~=p[f]then same=false;break end end;if not same then break end end
  if not same then hv.pending,hv.dirty=out,true;return end
  for i,o in ipairs(ops)do local c,pc=o.c,was[i].c
   if c and pc and (c[1]~=pc[1]or c[2]~=pc[2]or c[3]~=pc[3]or c[4]~=pc[4])then
    for _,sid in ipairs(wd.io_sids[i]or {})do local st=wd.style[sid];if st then st[o.k=="text"and "text_color"or "color"]={c[1],c[2],c[3],c[4]}end end
   end
  end
  wd.io_ops,hv.out=ops,out
 end
 -- a vote toggles: the board takes it and the model reads afresh at once, so the button flips this frame
 local function vote(view,hv,k)
  local m=hv.model;local x=m.sharing and m.players[k]and m.players[k].a;if not (x and x.owner and x.assignment_id)then return end
  ask("vote",x.owner,(m.mine or {})[k]and 0 or 1,x.assignment_id)
  Model.again();remodel(view,hv,hv.t)
 end
 -- Play while sharing in a Strike Team starts the shown Assignment through the board, which publishes the attempt so teammates who voted for
 -- it are accepted for themselves; a teammate's is asked about first and never falls back to the game's Play, which would start your own;
 -- your own falls back when the board refuses it; true when the press is taken
 local GOING={requesting=true,accepted=true,voting=true}
 local function play(view)
  local hv=view.io_hv;local m=hv and hv.model;if not (m and hv.st.team and m.sharing)then return false end
  -- a start already under way, yours or one you run for a teammate, takes the press and starts nothing more, so a second press never
  -- reaches the game's own Play
  local s=ask("snapshot");if type(s)=="table"and (type(s.launch)=="table"and GOING[s.launch.status]or s.owner_launch~=nil)then Model.again();return true end
  local k=hv.st.shown;local x=m.players[k]and m.players[k].a;local known=x and x.owner and x.assignment_id
  if k==1 then if not known or ask("start",x.owner,x.assignment_id)~=true then return false end
  elseif known then local key=x.owner.."|"..x.assignment_id;local e=ask("eligibility",x.owner,x.assignment_id);hv.elig={key=key,model=m,t=hv.t or 0,e=e}
   if type(e)=="table"and e.allowed==true then local ok,why=ask("start",x.owner,x.assignment_id);if ok~=true then hv.refused={key=key,why=why,at=hv.t or 0}end end
  end
  Model.again();return true
 end
 -- a tile's post button sends its Assignment to the Strike Team chat at once, then rests until it can post again
 local function post(view,hv,k)
  Post=Post or mod:io_dofile(base.."havoc_post")
  local st,now=hv.st,hv.t or 0;st.post_at=st.post_at or {};st.posted=st.posted or {}
  if st.post_at[k]and now-st.post_at[k]<Post.WAIT then return end
  local lines=Post.messages(hv.model and hv.model.players[k]);if not lines or not Post.send(lines)then return end
  st.post_at[k]=now;st.posted[k]="done";hv.dirty=true
 end
 -- each posted button's state from the time since its post: the tick, then waiting, then ready again
 local function posts(hv,t)
  local st=hv.st;if not st.post_at then return end
  for k,at in pairs(st.post_at)do local s=t-at<Post.DONE and "done"or t-at<Post.WAIT and "wait"or nil
   if st.posted[k]~=s then st.posted[k]=s;hv.dirty=true end;if not s then st.post_at[k]=nil end end
 end
 local function sound(name)local ui=Managers and Managers.ui;if not ui then return end;Sounds=Sounds or require("scripts/settings/ui/ui_sound_events");pcall(ui.play_2d_sound,ui,Sounds[name])end
 local function act(view,hv,a)
  local st=hv.st
  if a.k=="tab"then if st.tab~=a.i then st.tab=a.i;hv.dirty=true end
  elseif a.k=="show"then if show(view,hv,a.i)then hv.dirty=true end
  elseif a.k=="vote"then vote(view,hv,a.i)
  elseif a.k=="post"then post(view,hv,a.i)end
  sound("default_click")
 end
 -- the topmost part under the mouse lights up and takes the click; a controller in use leaves the mouse alone
 local function pointer(view,hv,input,rs)
  local st,hit=hv.st,nil
  local ui=Managers and Managers.ui;local mouse=not (ui and ui.using_cursor_navigation)or ui:using_cursor_navigation()
  local o=view._ui_scenegraph.canvas.world_position
  if mouse and input and hv.out and o then
   local ok,c=pcall(input.get,input,"cursor")
   if ok and c then
    local k=rs and rs.inverse_scale or view._render_scale and 1/view._render_scale or 1;local x,y=c[1]*k-o[1],c[2]*k-o[2]
    local hits=hv.out.hits or {}
    for i=#hits,1,-1 do local h=hits[i];if x>=h.x and x<h.x+h.w and y>=h.y and y<h.y+h.h then hit=h;break end end
   end
  end
  local key=hit and hit.key or nil
  if key~=st.hover then st.hover=key;hv.rehover=true end
  if hit and hit.act then local ok,down=pcall(input.get,input,"left_pressed");if ok and down==true then act(view,hv,hit.act)end end
 end
 local function restore(view,leaving)
  local hv=view.io_hv;if not hv then return end;view.io_hv=nil
  if Model and Model.drop then pcall(Model.drop)end
  drop(view,hv.widgets);hv.widgets={}
  if hv.kept.badge then swap(view,hv,hv.kept.badge)end
  local pf=hv.kept.pf;if pf then trade(view,"party_finder_button",pf[2],pf[1]);drop(view,{pf[2]})end
  local lg=hv.kept.legend
  if lg then if rawget(lg.el,"_draw_widgets")==lg.wrap then lg.el._draw_widgets=lg.own end
   pcall(lg.el._set_scenegraph_position,lg.el,"entry_pivot",lg.x,lg.y,lg.z)end
  for id,o in pairs(hv.kept.pos)do view:_set_scenegraph_position(id,o[1],o[2])end
  for id,o in pairs(hv.kept.size)do view:_set_scenegraph_size(id,o[1],o[2])end
  for t,o in pairs(hv.kept.vals)do for k,w in pairs(o)do t[k]=w[1]end end
  -- the game hides the cards itself on leaving
  if hv.grid and not leaving then hv.grid:set_visibility(true)end
 end
 -- with no Assignment of your own to show, the game's screen is left whole for this visit rather than its parts hidden under nothing
 local function stand_aside(view)
  restore(view);view.io_skip=true
  if not warned then warned=true;if mod.info then pcall(mod.info,mod,"I/O havoc screen: no Assignment of your own to show")end end
 end
 local function arrange(view)
  UIWidget=UIWidget or require("scripts/managers/ui/ui_widget")
  UIRenderer=UIRenderer or require("scripts/managers/ui/ui_renderer")
  local hv={kept={pos={},size={},vals={}},st={team=false,shown=1,tab=1},widgets={},dirty=true,spread={},set={},game={},info={{255,10,14,12},{140,240,196,92},{255,240,196,92}}}
  view.io_hv=hv
  if not remodel(view,hv)then stand_aside(view);return end
  -- a start that had already ended is not news on entering, and the board refreshes every Assignment once
  local L=hv.model.launch;if type(L)=="table"and L.status and not GOING[L.status]then hv.ended=tostring(L.id)..":"..tostring(L.status)end
  local s=ask("snapshot");if type(s)=="table"and s.enabled then ask("refresh")end
  measure(view,hv);cover(view,hv);column(view,hv);under(view)
  -- the legend is the background view's own and unproven in game, so a fault there leaves it where the game put it and the screen whole
  pcall(legend,view,hv)
 end
 -- a sentence for the box under Play that never wraps: with the whole name, else in its shorter words where it has them, else the name cut a
 -- whole character at a time until it fits the box's one line at the size given
 local function line(view,hv,box,size,who,make,short)
  local ts=box.style.text;local font=ts.font_type or "proxima_nova_bold"
  local n=view._ui_scenegraph.play_button_disabled_info.size;local add=ts.size_addition
  local room,ms=n[1]+(add and add[1]or 0)-8,measure(view,hv)
  who=tostring(who or "")
  local s=make(who);if ms(s,font,size)<=room then return s end
  if short then make=short;s=make(who);if ms(s,font,size)<=room then return s end end
  while #who>0 do who=who:gsub("[^\128-\191]?[\128-\191]*$","");local c=make((who:gsub("[ \t\r\n]+$","")).."…");if ms(c,font,size)<=room then return c end end
  return make("…")
 end
 -- the box as tall as its lines need from the game's own 80, at most to 10 above the canvas's foot; where that is too little the type
 -- steps down from 16 to 12, and where even 12 cannot hold them all the last line that fits counts the rest, so the box never runs off
 -- the screen; the game's own measure of the lines counts where it is the taller
 local LEAD,PAD,FOOT,SMALL=1.25,16,10,12
 local function compose(view,hv,box,parts)
  local id="play_button_disabled_info";local sg=view._ui_scenegraph;local o=hv.kept.size[id];local base=o and o[2]or sg[id].size[2]
  local _,y=at(view,id);local room=math.max(base,(sg.canvas.size or {1920,1080})[2]-FOOT-y)
  local ts=box.style.text;local font=ts.font_type or "proxima_nova_bold";local w=sg[id].size[1]+(ts.size_addition and ts.size_addition[1]or 0)
  local function sized(out,sz)local text=table.concat(out,"\n");local ok,_,th=pcall(view._text_size,view,text,{font_type=font,font_size=sz},{w,2000},true)
   return text,math.max(base,#out*sz*LEAD+PAD,(ok and type(th)=="number"and th or 0)+PAD)end
  local out,text,h
  for sz=NOTE,SMALL,-1 do out={}
   for i,x in ipairs(parts)do out[i]=x[2]and line(view,hv,box,sz,x[2],function(n)return x[1]:format(n)end,x[3]and function(n)return x[3]:format(n)end)or x[1]end
   text,h=sized(out,sz);if h<=room then return text,sz,h end
  end
  -- the count takes a line of its own, so it always stands for two or more
  for n=#out-2,1,-1 do local cut={};for i=1,n do cut[i]=out[i]end;cut[n+1]="And "..(#out-n).." more reasons."
   text,h=sized(cut,SMALL);if h<=room then break end
  end
  return text,SMALL,h
 end
 -- the box's height set while I/O writes it and the game's own back otherwise
 local function tall(view,hv,h)
  local id="play_button_disabled_info";local s=view._ui_scenegraph[id].size
  if h then if s[2]~=h then resize(view,id,nil,h)end
  else local o=hv.kept.size[id];if o and o[2]and s[2]~=o[2]then view:_set_scenegraph_size(id,nil,o[2])end end
 end
 -- the words for a start, yours or a teammate's, under way or ended; %s is the owner's name
 local LAUNCH={requesting={"Starting your Assignment.","Asking %s to start their Assignment."},accepted={"Starting your Assignment.","%s is starting their Assignment."},
  voting={"Voting on your Assignment.","Voting on %s's Assignment."},busy={"Your Assignment is already starting.","%s is busy starting another."},
  denied={"Your Assignment can't start now.","%s's game refused the start."},changed={"Your Assignment changed.","%s's Assignment changed."},
  failed={"Your Assignment failed to start.","%s's Assignment failed to start."},expired={"Your Assignment took too long.","%s's game didn't answer in time."},
  rejected={"The vote on your Assignment failed.","The vote on %s's Assignment failed."}}
 -- each reason Play is shut or a teammate's start is blocked, one set of words for the game's box and the board alike: a teammate's, then
 -- your own; the statuses are the backend's eligibility codes the presence carries, "none" where it carries none yet
 local WHY={away={"%s isn't in the Mourningstar.","You aren't in the Mourningstar."},dukane_no_quest={"%s hasn't unlocked Havoc.","You haven't unlocked Havoc."},
  havoc_reward_not_claimed={"%s hasn't claimed their Rewards.","You haven't claimed your Rewards."},
  havoc_locked={"%s's last Havoc mission hasn't ended.","Your last Havoc mission hasn't ended."},none={"%s's Havoc status is unknown.","Your Havoc status is unknown."},
  status={"%s can't play Havoc right now.","You can't play Havoc right now."},outsider={"%s isn't part of this Assignment.","You aren't part of this Assignment."},
  party_too_small={"Havoc needs at least %d players."},mission_vote_ongoing={"A mission vote is under way."},
  owner_not_voted={"%s has to vote for their own Assignment first."},remote_start_disabled={"%s doesn't let others start their Assignment."},
  owner_unavailable={"%s's Assignment isn't shared right now."},assignment_unavailable={"That Assignment has changed."},launch_in_progress={"A start is already under way."},
  matchmaking={"%s is matchmaking.","You're matchmaking."},cinematic={"%s is in a cutscene.","You're in a cutscene."},loading={"%s is loading.","You're loading."},
  unseen={"%s's location isn't known.","Your location isn't known."},presence_full={"Server presence is blocked.","I/O cannot share between players."},
  presence_changed={"A game update turned the Havoc board off."}}
 local STATUS={dukane_no_quest="dukane_no_quest",havoc_reward_not_claimed="havoc_reward_not_claimed",havoc_locked="havoc_locked",none="none",unknown_havoc_status="none"}
 -- the board's own reasons, first among a blocked start's lines as the ones about that Assignment
 local OWN={owner_not_voted=true,remote_start_disabled=true,owner_unavailable=true,assignment_unavailable=true,launch_in_progress=true,presence_full=true,presence_changed=true}
 local REFUSED={["launch already in progress"]=WHY.launch_in_progress[1],["assignment changed or unavailable"]=WHY.assignment_unavailable[1],
  ["owner is unavailable or declines remote starts"]="%s isn't taking starts now."}
 -- the shorter words for a sentence that leaves little room for a name
 local SHORT={["%s has to vote for their own Assignment first."]="%s has to vote for it first.",["%s doesn't let others start their Assignment."]="%s doesn't let others start it.",
  ["%s hasn't claimed their Rewards."]="%s has Rewards to claim."}
 -- the activities the board passes on as the game's presence names them; the prologue is "onboarding" there
 local ACTIVITY={mission=true,training_grounds=true,main_menu=true,matchmaking=true,loading=true,end_of_round=true,cinematic=true,onboarding=true,title_screen=true,splash_screen=true,unknown_activity=true}
 -- the ones the game sets while a player may still stand in the Mourningstar (the party matchmaking or booting a mission, a cutscene, their
 -- character not yet standing there) and the splash screen a teammate's presence reads until it arrives, each in its own words; others are away
 local WHERE={matchmaking="matchmaking",cinematic="cinematic",loading="loading",splash_screen="unseen",unknown_activity="unseen"}
 local function named(m,acc)for i,p in ipairs(m.players)do if acc~=nil and (p.account==acc or p.a and p.a.owner==acc)then return p.who,i==1,i end end;return false,false,9 end
 -- someone no longer in the party is a teammate, a capital only where the sentence starts with them
 local function says(tpl,who)if not who or who==""then who=tpl:find("^%%s")and "A teammate"or "a teammate"end;return {tpl,tpl:find("%s",1,true)and who or nil,SHORT[tpl]}end
 local function call(o,f,...)local fn=type(o)=="table"and o[f];if type(fn)~="function"then return nil end;local ok,a,b=pcall(fn,o,...);if ok then return a,b end end
 -- the fewest players Havoc takes, from the game's Havoc settings
 local function fewest()local hs=Managers and Managers.data_service and Managers.data_service.havoc;local s=call(hs,"get_settings");return type(s)=="table"and tonumber(s.min_participants)or nil end
 -- one reason in its words; n the fewest players
 local function phrase(k,who,you,n)
  local w=WHY[k];if not w then return says("It can't be started now.")end
  if k=="party_too_small"then return says(n and w[1]:format(n)or "Havoc needs more players.")end
  if you and w[1]:find("%s",1,true)then return says(w[2]or "It can't be started now.")end
  return says(w[1],who or false)
 end
 -- what stands in the way of a teammate's Assignment, every blocker on its own line: the board's own first, then the fewest players, each
 -- player in the party's order and a mission vote last
 local function blocked(m,p,e)
  local list=type(e)=="table"and type(e.blockers)=="table"and e.blockers or {}
  if #list==0 then return {says("%s's Assignment can't start now.",p.who)}end
  local rows,n={},fewest()
  for i,b in ipairs(list)do local r,acc=b.reason,b.account_id;local who,you,seat=named(m,acc);local k,rank
   if OWN[r]then k,rank=r,0 elseif r=="party_too_small"then k,rank=r,1 elseif r=="mission_vote_ongoing"then k,rank=r,99
   elseif acc==nil then rank=98 else k,rank=ACTIVITY[r]and (WHERE[r]or "away")or STATUS[r]or "status",10+seat end
   rows[#rows+1]={rank,i,phrase(k,who,you,n)}
  end
  table.sort(rows,function(a,b)if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
  local out,seen={},{};for _,r in ipairs(rows)do local x=r[3];local key=x[1].."\1"..tostring(x[2]);if not seen[key]then seen[key]=true;out[#out+1]=x end end
  return out
 end
 -- why the game shut Play, from what its _update_can_play reads: each player's Havoc status, who is in the Mourningstar (the Psykhanium
 -- counts for a teammate, not for you), the fewest players and the order's own participants; a mission vote only adds to them, so nil
 -- where none of these explains it and the game's own words stay; nil and true where your own presence is matchmaking
 local function shut(view,m)
  local mg=Managers;local party=mg and mg.party_immaterium;local hs=mg and mg.data_service and mg.data_service.havoc
  local order=view._parent and view._parent.havoc_order;if not (party and hs and type(order)=="table"and order.id)then return nil end
  local all=call(party,"all_members");if type(all)~="table"then return nil end
  local me,status,out=call(party,"get_myself"),{},{}
  -- after a start the game sets your presence to matchmaking while you still stand in the Mourningstar, and everyone's soon after
  if call(me,"presence_name")=="matchmaking"then return nil,true end
  local _,denied=call(hs,"can_all_party_members_play_havoc")
  for _,d in ipairs(type(denied)=="table"and denied or {})do local acc=type(d)=="table"and call(d.member,"account_id")or nil;if acc~=nil then status[tostring(acc)]=d.denied_reason or "none"end end
  local n=fewest()or 1;if n>math.max(1,#all)then out[1]=phrase("party_too_small",nil,false,n)end
  local ps=type(order.participants)=="table"and order.participants
  for _,x in ipairs(all)do local acc=call(x,"account_id");acc=acc~=nil and tostring(acc)or nil;local who,you=named(m,acc);you=you or x==me
   if not you and (who==false or who=="")then local nm=call(x,"name");who=nm~=nil and tostring(nm)~=""and tostring(nm)or false end
   local at=call(x,"presence_name");if at~="hub"and (you or at~="training_grounds")then out[#out+1]=phrase(WHERE[at or "unknown_activity"]or "away",who,you)end
   if acc and status[acc]then out[#out+1]=phrase(STATUS[status[acc]]or "status",who,you)end
   if ps then local found=false;for _,q in ipairs(ps)do if q==acc then found=true;break end end;if not found then out[#out+1]=phrase("outsider",who,you)end end
  end
  if #out==0 then return nil end
  local v=call(party,"party_vote_state");if type(v)=="table"and v.state=="ONGOING"then out[#out+1]=phrase("mission_vote_ongoing")end
  return out
 end
 -- the squad readying up: a mission vote under way
 local function readying()
  local party=Managers and Managers.party_immaterium;if not party then return false end
  local v=call(party,"party_vote_state");if type(v)=="table"and v.state=="ONGOING"then return true end
  return false
 end
 -- the first reasons Play is shut show at once; a change shows once it has held for SETTLE seconds, the last ones kept meanwhile, so a
 -- status flipping as the squad readies up never flashes
 local SETTLE=2
 local function settled(hv,parts,now)
  local key={};for i,x in ipairs(parts)do key[i]=x[1].."\1"..tostring(x[2])end;key=table.concat(key,"\2")
  if hv.settle_key~=key then hv.settle_key,hv.settle_at=key,now end
  if hv.settled==nil or now-hv.settle_at>=SETTLE then hv.settled=parts end
  return hv.settled
 end
 -- the board asked again about the shown teammate's Assignment with each new model, a new tile, or every half second
 local function eligible(hv,m,x,key,now)
  local c=hv.elig
  if not (c and c.key==key and c.model==m and now>=c.t and now-c.t<.5)then c={key=key,model=m,t=now,e=ask("eligibility",x.owner,x.assignment_id)};hv.elig=c end
  return c.e
 end
 -- a start's words: one under way or ended in the last 8 seconds (one already ended on entering is not news), or a teammate starting yours
 local function started(hv,m,now)
  local L=m.launch
  if type(L)=="table"and LAUNCH[L.status]then local lk=tostring(L.id)..":"..tostring(L.status)
   if not GOING[L.status]and hv.ended~=lk then hv.ended,hv.ended_at=lk,now end
   if GOING[L.status]or hv.ended==lk and hv.ended_at and now-hv.ended_at<8 then local who,you=named(m,L.owner);local w=LAUNCH[L.status]
    if you and L.status=="voting"and hv.sounded~=L.id then hv.sounded=L.id;sound("havoc_terminal_start_mission")end
    return {you and says(w[1])or says(w[2],who)}end
  end
  local O=m.owner_launch
  if type(O)=="table"and O.requester~=nil then local who,you=named(m,O.requester)
   if not you then return {says(O.status=="voting"and "%s started the vote on your Assignment."or "%s is starting your Assignment.",who)}end end
 end
 -- the box's sentences, most pressing first: a start's words, a presence the board can't use (full, or its code changed), a start of the
 -- shown teammate's the board refused, what stands in the way of it, else whose Assignment Play starts and which has most votes
 local function words(hv,m,st,now)
  local s=started(hv,m,now);if s then return s end
  local off=m.presence_changed and "presence_changed"or m.presence_full and "presence_full";if off then local t={};for i,s in ipairs(WHY[off])do t[i]=says(s)end;return t end
  local k=st.shown;local p=m.players[k];local x=p and p.a;local lead={};for i in pairs(m.leaders or {})do lead[#lead+1]=i end
  if k~=1 and x then if not (x.owner and x.assignment_id)then return blocked(m,p,nil)end;local key=x.owner.."|"..x.assignment_id
   local r=hv.refused;if r and r.key==key and now>=r.at and now-r.at<8 then return {says(REFUSED[r.why]or "%s's Assignment can't start now.",p.who)}end
   local e=eligible(hv,m,x,key,now)
   if not (type(e)=="table"and e.allowed==true)then return blocked(m,p,e)end
   local out={says("Play starts %s's Assignment.",p.who)}
   if (m.leaders or {})[k]then out[2]=says(#lead>1 and "It shares the most votes."or "It has the most votes.")end
   return out
  end
  if #lead>1 then return {says(#lead.." Assignments share the most votes.")}end
  if lead[1]==1 then return {says("Your Assignment has the most votes.")}end
  local q=lead[1]and m.players[lead[1]];if q then return {says("%s's Assignment has the most votes.",q.who)}end
  return {says("No votes yet.")}
 end
 -- the box under Play, after the game writes it each frame (it shows and hides the widget itself and alone decides whether Play is open):
 -- where the game shut Play, each reason in I/O's words in the game's red, or the game's own words where they are not all known, and
 -- with your own presence matchmaking a start's words in the gold or else the game's own; else, sharing in a Strike Team, it speaks for
 -- the board in the gold; else it is the game's own
 local function note(view,dt,t)
  local hv=view.io_hv;if not (hv and hv.model)then return end
  pin(view,hv);if t then hv.t=t end;local now=hv.t or 0
  local wb=view._widgets_by_name;local box=wb.play_button_disabled_info;local s=box.style
  wb.reward_header.content.visible=false
  local st,m,parts,gold=hv.st,hv.model,nil,false
  if box.visible==true then local matching;parts,matching=shut(view,m)
   if matching and st.team and m.sharing then parts=started(hv,m,now);gold=parts~=nil
   elseif parts and readying()then parts,gold={says("Readying Up…")},true;hv.settle_key,hv.settled=nil,nil
   elseif parts then parts=settled(hv,parts,now)else hv.settle_key,hv.settled=nil,nil end
  elseif st.team and m.sharing then parts,gold=words(hv,m,st,now),true end
  if parts then local key={gold and "g"or "r"}
   for i,x in ipairs(parts)do key[i+1]=x[1].."\1"..tostring(x[2])end;key=table.concat(key,"\2")
   if hv.note_key~=key then hv.note_key=key;hv.note,hv.note_size,hv.note_h=compose(view,hv,box,parts)end
   box.visible=true;box.content.text=hv.note;put(hv,s.text,"font_size",hv.note_size);tall(view,hv,hv.note_h)
  else back(hv,s.text,"font_size");tall(view,hv,nil)end
  if gold then put(hv,s.background,"color",hv.info[1]);put(hv,s.frame,"color",hv.info[2]);put(hv,s.text,"text_color",hv.info[3])
  else back(hv,s.background,"color");back(hv,s.frame,"color");back(hv,s.text,"text_color")end
 end
 local function draw_all(list,renderer)for _,w in ipairs(list)do UIWidget.draw(w,renderer)end end
 local function frame(view,dt,t,renderer,rs,input)
  local hv=view.io_hv
  if not on()then if hv then restore(view)end;return end
  if view.io_skip then return end
  if not hv then arrange(view);hv=view.io_hv;if not hv then return end end
  pin(view,hv);pcall(legend_pin,view,hv)
  -- nothing of I/O's over the options or the revoke question
  if view._mission_board_options~=nil or view._revoke_popup_id~=nil then if hv.st.hover~=nil then hv.st.hover=nil;hv.dirty=true end;return end
  t=t or 0;hv.t=t
  if not remodel(view,hv,t)then stand_aside(view);return end
  posts(hv,t)
  pointer(view,hv,input,rs)
  if hv.retime and not hv.dirty then retime(view,hv)end
  if hv.rehover and not hv.dirty then recolour(view,hv)end
  if hv.dirty then lay(view,hv)end
  if #hv.widgets==0 then return end
  -- the pass is always ended, so a failed draw never leaves the renderer inside it
  UIRenderer.begin_pass(renderer,view._ui_scenegraph,input,dt,rs)
  local ok,err=pcall(draw_all,hv.widgets,renderer)
  UIRenderer.end_pass(renderer)
  if not ok then error(err,0)end
 end
 -- one failure stops the screen until the mod reloads, logged once, and puts the game's own screen back whole
 local function guarded(fn)return function(view,...)
  if broken then return end
  local ok,err=pcall(fn,view,...);if not ok then fail(err);pcall(restore,view)end
 end end
 function M.off()local ui=Managers and Managers.ui;if not ui then return end;local ok,v=pcall(ui.view_instance,ui,"havoc_play_view");if ok and v then pcall(restore,v)end end
 -- the pre-mission loadout screen: its Havoc modifiers fitted above Ready, after the game lays them out; a fault is logged once and leaves
 -- the game's own layout
 local Fit,fit_warned
 mod:hook_require("scripts/ui/views/lobby_view/lobby_view",function(View)
  if View.io_havoc_fit==M then return end;View.io_havoc_fit=M
  mod:hook_safe(View,"_setup_havoc_info",function(view)
   if not on()then return end
   Fit=Fit or mod:io_dofile(base.."havoc_lobby_fit")
   local ok,err=pcall(Fit.fit,view);if not ok and not fit_warned then fit_warned=true;mod:error("I/O havoc lobby fit: %s",tostring(err))end
  end)
 end)
 mod:hook_require("scripts/ui/views/havoc_play_view/havoc_play_view",function(View)
  -- the game requires the view again on each visit and the class outlives a mods reload, so it is hooked once per load of the mod
  if View.io_havoc==M then return end;View.io_havoc=M
  mod:hook_safe(View,"on_enter",guarded(function(view)restore(view);view.io_skip=nil;if on()then arrange(view)end end))
  -- after the whole update, so another mod's hook on _update_can_play cannot undo the note
  mod:hook_safe(View,"update",guarded(note))
  -- after the enter animation writes its frame and before the scenegraph is laid out from it
  mod:hook_safe(View,"_update_animations",guarded(function(view)local hv=view.io_hv;if hv then pin(view,hv)end end))
  mod:hook_safe(View,"_draw_elements",guarded(frame))
  mod:hook_safe(View,"on_exit",function(view)pcall(restore,view,true)end)
  -- the game's Play with the original handed in: when the board does not take the press the game's own call runs as it wrote it
  mod:hook(View,"_cb_on_mission_start",function(func,view,...)
   if not broken and on()then local ok,took=pcall(play,view);if not ok then fail(took);pcall(restore,view)elseif took then return end end
   return func(view,...)
  end)
 end)
 return M
end
