-- Information Overload: a confirmation drawn in the manner of the game's own popup, its title and words decoding as the intro's do.
-- The game's popup cannot animate its text, so I/O draws this one over the panel; it takes every click and key while it is up.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local UIWidget=require("scripts/managers/ui/ui_widget")
local D=mod:io_dofile(base.."io_view_definitions")
local Intro=mod:io_dofile(base.."io_intro")
local C,F=D.c,D.font
local P={};P.__index=P
local W,BW,BH,CX=640,380,46,660
-- o: title, lines, buttons {{label,fn},...} with the first gold, and cancel, run by Back, Esc and right click
function P.new(view,o)
 local self=setmetatable({o=o,view=view},P)
 local n=#o.lines;local h=40+44+16+n*28+28+#o.buttons*(BH+10)+30
 local y=math.floor((D.panel_size[2]-h)/2);self.box={CX-W/2,y,W,h}
 local lines,sizes,fonts,lhs,ys={o.title:upper()},{30},{F.title},{44},{y+40}
 for i,l in ipairs(o.lines)do lines[#lines+1]=l;sizes[#sizes+1]=18;fonts[#fonts+1]=F.medium;lhs[#lhs+1]=28;ys[#ys+1]=y+40+44+16+(i-1)*28 end
 self.buttons={};local by=y+40+44+16+n*28+28
 for i,b in ipairs(o.buttons)do self.buttons[i]={x=CX-BW/2,y=by+(i-1)*(BH+10),w=BW,h=BH,label=b[1],fn=b[2],main=i==1}end
 self:frame()
 self.text=Intro.build(view,"io_popup_text",lines,{x=CX,align="center",sizes=sizes,fonts=fonts,lhs=lhs,ys=ys,size=18,lh=28,gap=0,z=84})
 Intro.step(nil,self.text,view.now or 0)
 return self
end
-- the dimmed screen, the box and its buttons; drawn again only when the button under the pointer changes
function P:frame()
 local cv=D.canvas();local b=self.box
 cv.z=0;cv:rect(-1300,-1110,3920,3080,D.rgba(0,0,0,.72))
 cv.z=1;cv:rect(b[1],b[2],b[3],b[4],C.pop);cv.z=2;cv:edges(b[1],b[2],b[3],b[4],1,C.frame);cv:corners(b[1]-1,b[2]-1,b[3]+2,b[4]+2,C.corner)
 for i,k in ipairs(self.buttons)do local on=self.hover==i
  cv.z=2;cv:rect(k.x,k.y,k.w,k.h,on and C.fill_h or C.fill);cv.z=3;cv:edges(k.x,k.y,k.w,k.h,1,k.main and C.gold or on and C.hover or C.frame)
  cv:text(k.label:upper(),k.x,k.y,k.w,k.h,20,k.main and C.gold or C.value,"center",F.title)
 end
 self:release()
 self.under,self.over=cv:widgets("io_popup_frame",80)
end
function P:release(all)
 local r=self.view and self.view._ui_renderer
 local t=all and self.text;local ws={self.under,self.over,t and t.under,t and t.over}
 for i=1,4 do local w=ws[i];if w and r then pcall(UIWidget.destroy,r,w)end end
 self.under,self.over=nil,nil
end
-- one 40 ms tick of the decode, once, from its opening
function P:tick(view,t)
 self.view=view;local d=self.text
 if d and not d.done and t>=d.next then Intro.step(nil,d,t)end
end
function P:at(x,y)if not x then return end;for i,k in ipairs(self.buttons)do if x>=k.x and x<k.x+k.w and y>=k.y and y<k.y+k.h then return i end end end
function P:point(x,y)local i=self:at(x,y);if i~=self.hover then self.hover=i;self:frame()end end
-- a click on a button closes the popup and does what it says; a click anywhere else does nothing
function P:click(view,x,y)local i=self:at(x,y);if not i then return end;self:close(view);local fn=self.buttons[i].fn;if fn then fn()end end
function P:back(view)self:close(view);if self.o.cancel then self.o.cancel()end end
function P:close(view)self.view=view or self.view;if view and view.io_modal==self then view.io_modal=nil end;self:release(true);self.text=nil end
function P:draw(view,renderer)
 if self.under then UIWidget.draw(self.under,renderer)end;if self.over then UIWidget.draw(self.over,renderer)end
 local d=self.text;if d then if d.under then UIWidget.draw(d.under,renderer)end;UIWidget.draw(d.over,renderer)end
end
return P
