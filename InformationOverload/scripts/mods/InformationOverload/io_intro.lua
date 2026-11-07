-- Information Overload: the first open. The cog says hello, flies into its slot, opens Screens and says what it is for.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local UIWidget=require("scripts/managers/ui/ui_widget")
local D=mod:io_dofile(base.."io_view_definitions")
local Icons=mod:io_dofile(base.."io_icons")
local C,F=D.c,D.font
local PAGES={{"Hello!","Welcome to Information Overload!","You can call me I/O.","I'm here to keep a record of every mission you play."},
 {"But that's not the only way I can be of assistance.","","Here, let me show you."}}
local SCREENS_SAY={"This is where you choose when I turn up.","Using your own scoreboard?","You can disable mine here."}
local REPLY={"Perfect! If you change your mind I'll be right over here"}
local PIN_SAY={"See this pin? Use it to make the menu stay expanded or not."}
local GLYPHS="0123456789ABCDEF#$%&*+=<>?/|"
-- centre and size of the cog as it talks: on Screens it stays in its slot and its words run in one line along the foot of the menu,
-- then it hovers just above the pin, its one line to the right of it over the Back row
local TALK,SLOT,PIN={660,305,206},{44,808,23},{44,-26,48}
local FOOT={16,842,1290,44}
local I={PAGES=PAGES,SCREENS_SAY=SCREENS_SAY,REPLY=REPLY,PIN_SAY=PIN_SAY,TALK=TALK,SLOT=SLOT,PIN=PIN,FOOT=FOOT};I.__index=I
-- the logo's own baked samples as rects, a run repeated down the rows kept as one
local RECTS={}
do local open={}
 for r,runs in ipairs(Icons.settings)do local now={}
  for i=1,#runs,2 do local key=runs[i]*1000+runs[i+1];local o=open[key]
   if o then o[4]=o[4]+1 else o={runs[i],r-1,runs[i+1],1};RECTS[#RECTS+1]=o end;now[key]=o end
  open=now
 end
end
I.RECTS=RECTS
local function set(c,v)c[1],c[2],c[3],c[4]=v[1],v[2],v[3],v[4]end
local MIX={255,0,0,0}
local function mix(a,b,k)for i=2,4 do MIX[i]=a[i]+(b[i]-a[i])*k end;return MIX end
-- cubic-bezier(.5,0,.2,1), as the mockup flies it
local function ease(p)
 if p<=0 then return 0 elseif p>=1 then return 1 end
 local lo,hi=0,1;for _=1,16 do local u=(lo+hi)/2;if 1.5*(1-u)^2*u+.6*(1-u)*u*u+u^3<p then lo=u else hi=u end end
 local u=(lo+hi)/2;return 3*(1-u)*u*u+u^3
end
local function cog_widget()
 local passes={}
 for i in ipairs(RECTS)do passes[i]={pass_type="rotated_rect",style_id="c"..i,style={color={255,255,255,255},offset={0,0,1},size={0,0},angle=0,pivot={0,0}}}end
 return UIWidget.init("io_intro_cog",UIWidget.create_definition(passes,"panel",{},D.panel_size,nil,{offset={0,0,94}}))
end
-- every rect turns about the logo's centre, so the one shape spins whole
-- the rows overlap by a pixel or so, or the soft edges of two turned rows let a hairline through; while it fades they barely
-- overlap, since an overlap shows brighter through a see-through cog
local function place_cog(w,x,y,s,a,c,k)
 local st=w.style;w.offset[1],w.offset[2]=x-s/2,y-s/2;w.alpha_multiplier=k
 local u=s/160;local lap=k>=1 and math.max(1,math.min(3,1.5/u))or .3
 if w.io_s~=s or w.io_lap~=lap then w.io_s,w.io_lap=s,lap
  for i,r in ipairs(RECTS)do local p=st["c"..i];local ox,oy=r[1]*u,(r[2]-lap/2)*u
   p.offset[1],p.offset[2]=ox,oy;p.size[1],p.size[2]=r[3]*u,(r[4]+lap)*u;p.pivot[1],p.pivot[2]=s/2-ox,s/2-oy end
 end
 local rad=D.angle_sign*math.rad(a)
 for i=1,#RECTS do local p=st["c"..i];p.angle=rad;set(p.color,c)end
end
local function glow_widget(r)
 local cv=D.canvas()
 for i=1,16 do cv:circle(0,0,r*(1-(i-1)/16.5),i>10 and D.rgba(236,214,160,.045)or D.rgba(221,183,99,.032))end
 local _,over=cv:widgets("io_intro_glow",50);return over
end
-- each letter stands in its own place and cycles glyphs until it lands, the first quickly and later ones ever slower
local function build(view,name,lines,o)
 local cv=D.canvas();local cells,total={},0
 for _,l in ipairs(lines)do total=total+#l end
 total=math.max(1,total);local ticks=math.min(60,math.max(10,math.floor(total/5)))
 if o.box then local b=o.box;cv.z=0;cv:rect(b[1],b[2],b[3],b[4],D.rgba(10,13,10,.95));cv.z=1;cv:edges(b[1],b[2],b[3],b[4],1,C.sel);cv:rect(b[1],b[2],3,b[4],C.gold)end
 cv:text("I/O",o.wx,o.wy,o.ww,o.wh,o.wsize,C.gold,o.align,F.title)
 local k=0
 for li,l in ipairs(lines)do local y=o.y+(li-1)*(o.lh+o.gap);local lw=view:_w(l,o.size,F.medium);local x0=o.align=="center"and o.x-lw/2 or o.x
  for i=1,#l do local ch=l:sub(i,i)
   if ch~=" "then local f=(k+i-1)/total;local cw=view:_w(ch,o.size,F.medium);local cx=x0+view:_w(l:sub(1,i),o.size,F.medium)-cw
    cv:text(" ",cx-8,y,cw+16,o.lh,o.size,C.value,"center",F.medium);cells[#cells+1]={id="t"..cv.n,ch=ch,at=2+ticks*f*f+math.random()*2*(1-f)}
   end
  end
  k=k+#l
 end
 local under,over=cv:widgets(name,76)
 return {under=under,over=over,cells=cells,ticks=ticks,tk=0,next=0}
end
local function step(self,d,t)
 local st,ct=d.over.style,d.over.content;local tk=d.fast and d.ticks+4 or d.tk;local fin=tk>=d.ticks+4
 for _,x in ipairs(d.cells)do local s=st[x.id]
  if tk>=x.at then ct[x.id]=x.ch;set(s.text_color,not fin and tk<x.at+2 and C.gold_hi or C.value);s.font_type=F.medium
  else local g=math.random(#GLYPHS);ct[x.id]=GLYPHS:sub(g,g);set(s.text_color,math.random()<.5 and C.gold or C.muted);s.font_type=F.title end
 end
 -- the glow flickers while letters land, so the cog seems to speak
 if d.glow and tk<d.ticks+2 then self.lit=math.max(self.lit,.7+math.random()*.3)end
 if fin then d.done=true;local fn=d.after;d.after=nil;if fn then fn()end;return end
 d.tk=tk+1;d.next=t+.04
end
local function after(self,s,fn)self.q[#self.q+1]={self.now+s,fn}end
function I.new()return setmetatable({phase="talk",mode="talk",angle=0,spin=0,want=0,lit=0,alpha=0,alpha_to=0,q={}},I)end
function I:tick(view,t)
 self.view=view
 if not self.t0 then self.t0,self.last,self.now=t,t,t
  after(self,.06,function()self.alpha_to=1 end);after(self,.56,function()self.want=-420;self.lit=1 end);after(self,1.46,function()self:page(1)end)
 end
 local dt=math.max(0,math.min(.05,t-self.last));self.last,self.now=t,t
 -- a negative spin turns it backwards
 self.spin=self.spin+(self.want-self.spin)*math.min(1,dt*2.6);self.angle=(self.angle+self.spin*dt)%360
 self.lit=math.max(.28*(self.want~=0 and 1 or .6),self.lit-dt*2.2)
 if self.alpha~=self.alpha_to then local d=dt/.35;self.alpha=self.alpha_to>self.alpha and math.min(self.alpha_to,self.alpha+d)or math.max(self.alpha_to,self.alpha-d)end
 local q=self.q;local i=1
 while i<=#q and self.q==q do if t>=q[i][1]then table.remove(q,i)[2]()else i=i+1 end end
 local d=self.talk;if d and not d.done and t>=d.next then step(self,d,t)end
 d=self.say;if d and not d.done and t>=d.next then step(self,d,t)end
 local f=self.fly;if f and t>=f.t0+f.dur then self.fly=nil;f.done()end
 local dirty=self.dirty;self.dirty=nil;return dirty
end
function I:page(i)
 self.ix=i;self.want=-70
 local d=build(self.view,"io_intro_talk",PAGES[i],{x=TALK[1],y=466,lh=33,gap=11,size=26,align="center",wx=TALK[1]-100,wy=436,ww=200,wh=18,wsize=18})
 d.glow=true;d.after=function()self.want=-25 end;self.talk=d;step(self,d,self.now)
end
-- a click while letters land lands them all, and otherwise moves on
function I:advance()
 local d=self.talk;if not d then return end
 if not d.done then d.fast=true;step(self,d,self.now)
 elseif self.ix<#PAGES then self:page(self.ix+1)else self:to_screens()end
end
function I:flight(from,to,dur,done)self.mode="fly";self.fly={from=from,to=to,t0=self.now,dur=dur,done=done}end
-- the cog spins backwards into the Settings slot, which lights, and Settings opens on Screens
function I:to_screens()
 self.q={};self.phase="flying";self.want=-420;self.alpha_to=0;self.dirty=true
 self:flight(TALK,SLOT,.55,function()self.mode=nil end)
 after(self,.6,function()self.lit_slot=true;self.dirty=true end)
 after(self,1.05,function()self:screens();after(self,.5,function()if self.phase=="screens"then self:explain()end end)end)
end
function I:skip()
 self.q={};self.fly=nil;self.mode=nil;self.talk=nil;self.say=nil;self.alpha,self.alpha_to=0,0;self.lit_slot=true
 self:screens();after(self,.4,function()if self.phase=="screens"then self:explain()end end)
end
-- reaching Screens is what counts as seen, so a crash after it never replays the intro
function I:screens()
 local v=self.view;self.phase="screens";self.first=true;self.want=0;self.talk=nil;self.dirty=true
 v:_open_settings();v.part="screens";mod:set("intro_seen",true)
end
function I:explain()
 self.away=true;self.dirty=true
 self.mode="speaker";self.at=SLOT;self.angle=0;self.spin=-420;self.want=-70;self.lit=1
 self:speak(SCREENS_SAY,"foot",function()if self.mode=="speaker"then self.want=-25 end end)
end
-- once the Screens box goes the cog flies up above the pin, the names open out beside it and it says what the pin does
function I:pin()
 self.pinned_told=true;self.want=-420
 self:flight(self.at or SLOT,PIN,.55,function()self.mode="speaker";self.at=PIN;if self.phase~="screens"then return self:home(true)end
  self.hold_drawer=true;self.dirty=true;self.angle=0;self.spin=-420;self.want=-70;self.lit=1
  self:speak(PIN_SAY,"pin",function()if self.mode=="speaker"then self.want=-25 end end)end)
end
function I:speak(lines,where,fn)
 local v=self.view;local size,lh=where and 17 or 22,where and 23 or 29;local w=0
 if where=="foot"then lines={table.concat(lines," ")}end
 for _,l in ipairs(lines)do w=math.max(w,v:_w(l,size,F.medium))end
 local bw,bh=math.ceil(w)+36,46+#lines*lh+(#lines-1)*6
 local x,y
 if where=="foot"then x,y,bw,bh=FOOT[1],FOOT[2],FOOT[3],FOOT[4]
 elseif where=="pin"then x,y=PIN[1]+PIN[3]/2+12,math.floor(PIN[2]-bh/2)
 else x,y=16,842 end -- the last word sits under the bar, below the cog's slot
 -- along the foot the I/O tag sits at the line's start rather than above it
 local tx,ty,wy=x+18,y+32,y+12;if where=="foot"then tx,ty,wy=x+60,y+(bh-lh)/2,y+(bh-14)/2 end
 local d=build(v,"io_intro_say",lines,{x=tx,y=ty,lh=lh,gap=6,size=size,align="left",wx=x+18,wy=wy,ww=60,wh=14,wsize=14,box={x,y,bw,bh}})
 d.glow=where~=nil;d.where=where;d.after=fn;d.rect={x,y,bw,bh};self.say=d;step(self,d,self.now)
end
-- once its bubble goes the cog flies back into its slot, which pops as it lands
function I:home(fly)
 self.hold_drawer=nil
 if self.mode~="speaker"then if not self.fly then self.away=false;self.dirty=true end;return end
 self.want=0
 if not fly then self.mode=nil;self.away=false;self.dirty=true;return end
 self:flight(self.at or SLOT,SLOT,.55,function()self.mode="pop";self.pop=self.now
  after(self,.6,function()if self.mode=="pop"then self.mode=nil end;self.away=false;self.dirty=true end)end)
end
-- the cog that closes Settings ends the intro, and it has its last word from its slot
function I:done()
 self.first=false;self.phase="over";self:home(false);self.view:_leave_settings();self:speak(REPLY,false)
end
-- before Screens every click belongs to the intro; after it, a click on a button only does what it is on, and a click on empty space sends the bubble away
function I:click(view,x,y)
 self.view=view
 if self.phase=="talk"then local hit=view:_top(x,y);if hit and hit.fn then hit.fn()else self:advance()end;return true end
 if self.phase=="flying"then return true end
 local d=self.say;if not d or not x then return end;local r=d.rect
 if x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]then return end
 if self.phase=="screens"then local hit=view:_top(x,y);if hit and hit.fn then return end end
 -- the Screens box gives way to the pin step, and the pin box sends the cog home
 self.say=nil;if d.where=="foot"and not self.pinned_told then self:pin()else self:home(true)end
end
function I:shell()return self.phase=="talk"or self.phase=="flying"end
function I:draw(view,renderer)
 local t,m=self.now or 0,self.mode;local x,y,s,c,k,a,g=0,0,0,C.gold_hi,1,self.angle,nil
 if m=="talk"then x,y,s=TALK[1],TALK[2],TALK[3];c=mix(C.label,C.gold_hi,math.min(1,self.lit));k=self.alpha;g="talk"
 elseif m=="speaker"then local at=self.at or SLOT;x,y,s=at[1],at[2],at[3];c=mix(C.label,C.gold_hi,math.min(1,self.lit));g="pin"
 elseif m=="fly"and self.fly then local f=self.fly;local p=ease((t-f.t0)/f.dur)
  x,y,s=f.from[1]+(f.to[1]-f.from[1])*p,f.from[2]+(f.to[2]-f.from[2])*p,f.from[3]+(f.to[3]-f.from[3])*p
 elseif m=="pop"then local p=math.min(1,(t-(self.pop or t))/.6);local e,r
  if p<.35 then e=p/.35;r=1+.6*e;a=-40*e else e=(p-.35)/.65;e=1-(1-e)^2;r=1.6-.6*e;a=-40*(1-e)end
  x,y,s=SLOT[1],SLOT[2],SLOT[3]*r
 else m=nil end
 if g then local glow=self[g.."_glow"]or glow_widget(g=="talk"and 152 or g=="pin"and 36 or 91);self[g.."_glow"]=glow
  glow.offset[1],glow.offset[2]=x,y;glow.alpha_multiplier=math.min(1,self.lit*.9)*k;UIWidget.draw(glow,renderer)end
 if m then self.cog=self.cog or cog_widget();place_cog(self.cog,x,y,s,a,c,k);UIWidget.draw(self.cog,renderer)end
 local d=self.talk;if d and self.alpha>0 then d.over.alpha_multiplier=self.alpha;UIWidget.draw(d.over,renderer)end
 d=self.say;if d then if d.under then UIWidget.draw(d.under,renderer)end;UIWidget.draw(d.over,renderer)end
end
return I
