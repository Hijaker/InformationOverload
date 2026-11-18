-- Information Overload: the pre-mission loadout screen's Havoc modifiers fitted into their panel. The game stacks up to four under the rank
-- with no regard for the panel's height, so a long set runs down under Ready; the names and descriptions come down in size together until
-- the stack fits, never under 70% of the game's own sizes
local F={}
F.MIN,F.STEP=.7,.05
-- the Ready frame's top reaches 60 up into the panel's foot (seen in game 15 Nov 2026: a 556 stack ran under it, 476 sat clear)
F.KEEP=60
-- the game's sizes (lobby_view_definitions, LobbyView._setup_havoc_info): the name at 20, the description at 17, 20 between and round
-- the entries, 10 between a name and its description
local NAME,DESC,MARGIN,GAP=20,17,20,10
-- lays the shown entries out at s of the game's sizes as the game does, and returns the stack's foot
local function lay(view,list,top,w,s)
 local y=top
 for _,e in ipairs(list)do local st=e.style;local ns,ds=st.circumstance_name,st.circumstance_description
  ns.font_size,ds.font_size=NAME*s,DESC*s
  local th=math.max(st.icon.size[2],view:_get_text_height(e.content.circumstance_name,ns,{ns.size[1]}))
  local dh=view:_get_text_height(e.content.circumstance_description,ds,{ds.size[1]})
  ds.offset[2]=th+GAP;e.offset[2]=y;e.content.size={w,th+GAP+dh};y=y+th+GAP+dh+MARGIN
 end
 return y-MARGIN
end
-- after the game's own layout: the scale used and the stack's foot, or nil with no Havoc entries shown
function F.fit(view)
 local wb=view._widgets_by_name;local title=wb and wb.havoc_title
 if not (view._havoc_data and title and title.visible~=false)then return nil end
 local list={};for i=1,4 do local e=wb["havoc_circumstance_0"..i];if e and e.visible~=false and e.content.circumstance_name then list[#list+1]=e end end
 if #list==0 then return nil end
 local w,h=view:_scenegraph_size("havoc_title");h=h-F.KEEP;local top=title.style.havoc_icon.size[2]+MARGIN*2
 local s=1;local foot=lay(view,list,top,w,s)
 while foot>h and s>F.MIN+1e-9 do s=math.max(F.MIN,s-F.STEP);foot=lay(view,list,top,w,s)end
 return s,foot
end
return F
