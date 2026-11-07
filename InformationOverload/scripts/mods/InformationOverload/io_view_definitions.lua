-- Information Overload view: theme, scenegraph and the canvas the pages draw on.
local UIWidget=require("scripts/managers/ui/ui_widget")
local Workspace=require("scripts/settings/ui/ui_workspace_settings")
local D={}
local function rgba(r,g,b,a)return {math.floor((a or 1)*255+.5),r,g,b}end
D.rgba=rgba
D.c={label=rgba(169,191,153),value=rgba(216,229,207),gold=rgba(221,183,99),gold_hi=rgba(236,214,160),frame=rgba(60,78,57),hover=rgba(113,126,103),
 sel=rgba(167,129,64),corner=rgba(121,136,109),fill=rgba(49,56,49,.39),fill_h=rgba(67,75,64,.55),fill_s=rgba(83,72,48,.62),muted=rgba(169,191,153,.62),
 panel=rgba(4,7,5,.86),card=rgba(49,56,49,.26),card_h=rgba(67,75,64,.3),bad=rgba(205,120,96),line=rgba(60,78,57,.45),pop=rgba(10,14,10),on=rgba(83,72,48,.35),
 row_h=rgba(67,75,64,.45),axis=rgba(169,191,153,.4),dim=rgba(0,0,0,.63),grain=rgba(90,115,83,.094),tip=rgba(8,11,8,.96),none={0,0,0,0}}
D.font={body="proxima_nova_bold",medium="proxima_nova_medium",title="machine_medium"}
-- the game measures a text by its ink, short of the room around a narrow glyph such as 1, and a box only that wide draws nothing, so a text is as
-- wide as its ink or its caret, where the next glyph would start, whichever is more
function D.advance(w,caret)if caret==nil or not (Vector3 and Vector3.to_elements)then return w end;local x=Vector3.to_elements(caret);return type(x)=="number"and x>w and x or w end
D.mat={grain="content/ui/materials/backgrounds/terminal_basic",frame="content/ui/materials/frames/frame_tile_2px"}
local sys,opt="content/ui/materials/icons/system/escape/","content/ui/materials/icons/system/settings/"
D.icons={overview=opt.."category_interface",last=sys.."leave_mission",history=sys.."news",trends=opt.."category_video",records=sys.."credits",
 weapons=sys.."inventory",classes=sys.."change_character",streaks=opt.."category_gameplay",deaths=sys.."quit",speed=opt.."category_controls",
 dossier=sys.."party_finder",team=sys.."social",friends=sys.."social_empty",psyk=sys.."leave_training",settings=sys.."settings",
 display=opt.."category_video",counting=opt.."category_gameplay",data=opt.."category_interface"}
D.icon_held=function(path)return path:find(sys,1,true)==1 end
D.panel_size={1320,860}
D.left,D.right,D.width,D.col,D.col2,D.gap=100,1290,1190,590,700,10
D.top,D.row2,D.sheet,D.bottom=78,120,166,818
function D.scenegraph()
 return {screen=Workspace.screen,panel={parent="screen",horizontal_alignment="center",vertical_alignment="center",size=D.panel_size,position={0,0,100}}}
end
-- a hover: its fill and edges, and three rings outside them for a whole card's glow
function D.hover_definition()
 local passes,ids={},{"bg","top","bottom","left","right"}
 for k=1,3 do for _,side in ipairs({"t","b","l","r"})do ids[#ids+1]="glow"..k..side end end
 for _,id in ipairs(ids)do passes[#passes+1]={pass_type="rect",style_id=id,style={color={0,0,0,0},offset={0,0,1},size={0,0}}}end
 return UIWidget.create_definition(passes,"panel",{},D.panel_size,nil,{offset={0,0,20}})
end
local Canvas={};Canvas.__index=Canvas
function D.canvas()return setmetatable({under={},over={},content={},n=0,z=0},Canvas)end
local function copy(c,k)return {math.floor(c[1]*(k or 1)+.5),c[2],c[3],c[4]}end
D.copy=copy
function Canvas:scroll(dy,y0,y1)self.sc={dy=dy,y0=y0,y1=y1,max=y0}end
function Canvas:unscroll()local sc=self.sc;self.sc=nil;return sc and sc.max or 0 end
-- a scrolled sheet: shift by dy, trim rects to the window, and drop anything else that pokes out of it
local function fits(sc,y,h)sc.max=math.max(sc.max,y+h);y=y+sc.dy;return y+h*.2>=sc.y0 and y+h*.8<=sc.y1,y end
function Canvas:rect(x,y,w,h,c,top,k)
 if self.cx and x<self.cx then w=w-(self.cx-x);x=self.cx end
 if w<=0 or h<=0 then return end
 local sc=self.sc;if sc then sc.max=math.max(sc.max,y+h);y=y+sc.dy;if y<sc.y0 then h=h-(sc.y0-y);y=sc.y0 end;if y+h>sc.y1 then h=sc.y1-y end;if h<=0 then return end end
 local list=top and self.over or self.under
 list[#list+1]={pass_type="rect",style={color=copy(c,k),offset={x,y,top and 1 or self.z},size={w,h}}}
end
function Canvas:texture(material,x,y,w,h,c,top,k)
 if self.cx and x<self.cx then return end
 if self.sc then local ok;ok,y=fits(self.sc,y,h);if not ok then return end end
 local list=top and self.over or self.under
 list[#list+1]={pass_type="texture",value=material,style={color=copy(c,k),offset={x,y,top and 1 or self.z},size={w,h},scale_to_material=true}}
end
-- a dropdown's value, which reads gold when it names one of the crumbs, or always when gold is asked for; the crumbs are only known once the page has drawn
function Canvas:pick(value,shown,x,y,w,gold)local n=#self.over;self:text(shown,x,y,w,34,16,gold and D.c.gold or D.c.value)
 if n<#self.over and D.picks then D.picks[#D.picks+1]={p=self.over[#self.over],s=value}end
end
function Canvas:text(s,x,y,w,h,size,c,align,font,k)
 if self.cx and x<self.cx then return end
 if self.sc then local ok;ok,y=fits(self.sc,y,h);if not ok then return end end
 self.n=self.n+1;local id="t"..self.n;self.content[id]=s
 self.over[#self.over+1]={pass_type="text",value_id=id,style_id=id,style={font_type=font or D.font.body,font_size=size,text_color=copy(c,k),
  text_horizontal_alignment=align or "left",text_vertical_alignment="center",offset={x,y,2},size={w,h}}}
end
function Canvas:edges(x,y,w,h,t,c,top,k,skip)
 skip=skip or {}
 if not skip.top then self:rect(x,y,w,t,c,top,k)end;if not skip.bottom then self:rect(x,y+h-t,w,t,c,top,k)end
 if not skip.left then self:rect(x,y,t,h,c,top,k)end;if not skip.right then self:rect(x+w-t,y,t,h,c,top,k)end
end
function Canvas:corners(x,y,w,h,c,top,k,only)
 for _,v in ipairs({{0,0,"l"},{1,0,"r"},{0,1,"l"},{1,1,"r"}})do
  if not only or only==v[3]then
   local cx,cy=x+v[1]*(w-12),y+v[2]*(h-2);local vx,vy=x+v[1]*(w-2),y+v[2]*(h-12)
   self:rect(cx,cy,12,2,c,top,k);self:rect(vx,vy,2,12,c,top,k)
  end
 end
end
function Canvas:chevron(x,y,dir,h,c,k)
 local d=math.floor(h/2)
 for i=0,d do
  if dir=="right"then self:rect(x+i,y+i,2,2,c,true,k);self:rect(x+i,y+h-i,2,2,c,true,k)
  elseif dir=="left"then self:rect(x+d-i,y+i,2,2,c,true,k);self:rect(x+d-i,y+h-i,2,2,c,true,k)
  else self:rect(x+i,y+i,2,2,c,true,k);self:rect(x+h-i,y+i,2,2,c,true,k)end
 end
end
D.angle_sign=-1
-- a line goes over everything unless asked under, where it takes its turn among the rects
function Canvas:line(x1,y1,x2,y2,t,c,k,under)
 if self.cx and math.min(x1,x2)<self.cx then return end
 if self.sc then local sc=self.sc;sc.max=math.max(sc.max,y1,y2);y1,y2=y1+sc.dy,y2+sc.dy;if math.min(y1,y2)<sc.y0 or math.max(y1,y2)>sc.y1 then return end end
 local dx,dy=x2-x1,y2-y1;local len=math.sqrt(dx*dx+dy*dy)+t
 local list=under and self.under or self.over
 list[#list+1]={pass_type="rotated_rect",style={color=copy(c,k),offset={(x1+x2)/2-len/2,(y1+y2)/2-t/2,under and self.z or 2},size={len,t},angle=D.angle_sign*math.atan2(dy,dx),pivot={len/2,t/2}}}
end
-- icons are baked at 8 samples per unit; each is box-filtered once per size and UI scale into soft-edged pixel runs, a run repeated down the rows kept as one
local function pixels(rows,s)
 local cache=rows.px;if not cache then cache={};rows.px=cache end;if cache[s]then return cache[s]end
 local P,cov=math.ceil(20*s),{}
 for r=1,#rows do local py=math.floor((r-1)*s/8);local line=cov[py]or {};cov[py]=line;local runs=rows[r]
  for i=1,#runs,2 do for col=runs[i],runs[i]+runs[i+1]-1 do local px=math.floor(col*s/8);line[px]=(line[px]or 0)+1 end end
 end
 local full,out,open=(8/s)^2,{},{}
 for py=0,P do local line,now=cov[py],{};if line then local px=0
  while px<=P do local q=math.floor(math.min(1,(line[px]or 0)/full)*16+.5)/16;local n=1
   while px+n<=P and math.floor(math.min(1,(line[px+n]or 0)/full)*16+.5)/16==q do n=n+1 end
   if q>0 then local key=(px*1024+n)*17+q*16;local o=open[key];if o then o[5]=o[5]+1 else o={px/s,py/s,n/s,q,1};out[#out+1]=o end;now[key]=o end;px=px+n
  end end;open=now end
 cache[s]=out;return out
end
-- size is the icon's box in UI units, 20 by default; a pixel takes a whole number of samples so its rows repeat, and past 8 pixels a unit the samples are drawn as they are
function Canvas:icon(rows,x,y,c,k,size)
 local m=(size or 20)/20;local s=8/math.max(1,math.floor(8/((RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale or 1)*m)+.5))
 for _,r in ipairs(pixels(rows,s))do self:rect(x+r[1]*m,y+r[2]*m,r[3]*m,r[5]*m/s,c,true,(k or 1)*r[4])end
 if rows.dim then self:icon(rows.dim,x,y,c,(k or 1)*.45,size)end
end
function Canvas:circle(cx,cy,r,c)
 self.over[#self.over+1]={pass_type="circle",style={color=copy(c),offset={cx-r,cy-r,self.z},size={2*r,2*r}}}
end

function Canvas:cross(cx,cy,len,t,c)
 for _,a in ipairs({math.pi/4,-math.pi/4})do
  self.over[#self.over+1]={pass_type="rotated_rect",style={color=copy(c),offset={cx-len/2,cy-t/2,2},size={len,t},angle=a,pivot={len/2,t/2}}}
 end
end
function Canvas:panel(x,y,w,h,skip,only)
 self.z=1;self:rect(x,y,w,h,D.c.panel)
 self.z=2;self:texture(D.mat.grain,x,y,w,h,D.c.grain)
 self.z=3;self:texture(D.mat.frame,x,y,w,h,D.c.frame);self:edges(x,y,w,h,2,D.c.frame,false,1,skip);self:corners(x,y,w,h,D.c.corner,false,1,only)
end
function Canvas:widgets(name,z)
 local function make(passes,layer)
  if #passes==0 then return nil end -- UIWidget.init crashes on an empty pass list
  local widget=UIWidget.init(name.."_"..layer,UIWidget.create_definition(passes,"panel",self.content,D.panel_size,nil,{offset={0,0,z+(layer=="over"and 20 or 0)}}))
  widget.visible=true;return widget
 end
 return make(self.under,"under"),make(self.over,"over")
end
return D
