-- the name in the mod list, repainting the drawn text only; the display name DMF sorts and selects by stays plain
-- Heat: the name warms from its own colour to amber to red, then a bright band runs back across it right to left,
-- breaking the letters under it into code, and they land in their own colour
-- Glitch Decrypt: steady, and every couple of seconds a few letters break into code and decode back
return function(mod)
local O={}
local STYLE="heat"
local JUNK="#%&$@01<>/*+=?"
local GREEN,PALE,WHITE,AMBER,RED,HOT={118,196,104},{200,216,190},{255,255,255},{255,160,60},{232,64,52},{255,240,214}
-- the list's own text colour, read from the game; nil below means "leave it its own colour", so hover still lights it
local OWN={216,229,207}
local claimed=setmetatable({},{__mode="k"})
local last,name=-1
local function rnd(t,i)local x=math.sin(t*12.9898+i*78.233)*43758.5453;return x-math.floor(x)end
local function writer()
 local out,current={},nil
 return function(ch,c)
  if c then local code=c[1]..","..c[2]..","..c[3];if code~=current then out[#out+1]="{#color("..code..")}";current=code end
  elseif current then out[#out+1]="{#reset()}";current=nil end
  out[#out+1]=ch
 end,function()out[#out+1]="{#reset()}";return table.concat(out)end
end
local function between(a,b,f)return {math.floor(a[1]+(b[1]-a[1])*f+.5),math.floor(a[2]+(b[2]-a[2])*f+.5),math.floor(a[3]+(b[3]-a[3])*f+.5)}end
-- 74 ticks: 48 heating, 17 venting, 9 resting on its own colour
local CYCLE,VENT=74,17
function O.heat(t)
 local k=t%CYCLE
 if k==0 or k>=48 then return nil end
 if k<24 then return between(OWN,AMBER,k/24)end
 return between(AMBER,RED,(k-24)/23)
end
function O.named(t,text)
 local put,done=writer()
 local e,n=t%CYCLE-48,#text
 if e<0 or e>=VENT then put(text,O.heat(t));return done()end
 local pos=n+1-e*(n+3)/VENT
 for i=1,n do
  local ch,j=text:sub(i,i),i-1
  local b=math.max(0,1-math.abs(j-pos)/2.2)
  local base=j>pos and OWN or RED
  local c
  if b>0 or base==RED then c=between(base,HOT,b)end
  if b>.3 and ch~=" "then local m=1+math.floor(rnd(t,i)*#JUNK);ch=JUNK:sub(m,m)end
  put(ch,c)
 end
 return done()
end
function O.paint(t,text)
 local ev,k=math.floor(t/14),t%14
 local live=rnd(ev,99)>.2
 local len=2+math.floor(rnd(ev,98)*3)
 local start=1+math.floor(rnd(ev,97)*(#text-len+1))
 local solved=k-2
 local put,done=writer()
 for i=1,#text do
  local ch,c=text:sub(i,i),GREEN
  local j=i-start
  if live and j>=0 and j<len and ch~=" "then
   if j<solved then c=j==solved-1 and WHITE or GREEN
   else local n=1+math.floor(rnd(t,i)*#JUNK);ch,c=JUNK:sub(n,n),PALE end
  end
  put(ch,c)
 end
 return done()
end
-- a pinned mod's name keeps the pin DMF draws in front of it, by DMF's own helper
local pin
local function pinned(text)
 if pin==nil then local ok,u=pcall(function()return get_mod("DMF"):io_dofile("dmf/scripts/mods/dmf/modules/ui/options/options_display_utils")end);pin=ok and type(u)=="table"and u.pinned_category_name or false end
 return pin and pin(text)or text
end
-- the list entry is found by its mod rather than its text, as a pinned name reads differently
local function mine(content)local e=content and content.entry;if e then return e.mod_name==mod:get_name()end;return content and(content.text==name or claimed[content])end
mod:hook_safe("BaseView","update",function(self)
 if self.view_name~="dmf_options_view"then return end
 local now=Application.time_since_launch()
 if now-last<.12 then return end
 last=now
 name=name or mod:localize("mod_name")
 local t=math.floor(now/.12)
 for _,widget in ipairs(self._category_content_widgets or {})do
  local content=widget.content
  if mine(content)then claimed[content]=true;local e=content.entry;local d=e and e.display_name or name
   local text=STYLE=="heat"and O.named(t,d)or O.paint(t,d);content.text=e and e.is_favorited and pinned(text)or text end
 end
end)
-- switched off, the hook no longer runs, so each name it painted is put back as DMF draws it
function O.off()for content in pairs(claimed)do local e=content.entry;local d=e and e.display_name or name;if d then content.text=e and e.is_favorited and pinned(d)or d end end end
return O
end
