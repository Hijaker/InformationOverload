-- Information Overload: Settings › Screens, a card for each screen I/O adds to; turning one on unlocks its own tab in the bar.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Preview=mod:io_dofile(base.."io_screen_previews")
local C,F=D.c,D.font
local LIST={{id="charselect",name="Character Select",place="Main Menu",icon="charselect"},{id="social",name="Squad Social",place="Mourningstar",icon="social"},
 {id="board",name="Mission Board",place="Mourningstar",icon="board"},
 {id="scoreboard",name="Scoreboard",place="Mission",icon="scoreboard"},{id="tracker",name="Tracker",place="Mission",icon="speed"},
 {id="endscreen",name="End Screen",place="Mission",icon="endscreen"}}
-- each group's name, its row and the columns its line spans
local GROUPS={{"Main Menu",1,1,1},{"Mourningstar",1,2,3},{"Mission",2,1,3}}
local SPOT={charselect={1,1},social={1,2},board={1,3},scoreboard={2,1},tracker={2,2},endscreen={2,3}}
-- the cards fill the page down to its foot
local COL,GAP,PIC,FOOT=380,25,273,50
local ROW={D.top+38,D.top+38+PIC+FOOT+46}
local S={list=LIST}
-- a screen is on until it is turned off, so a fresh install starts with every one
function S.on(id)return mod:get("screen_"..id)~=false end
local function card(view,cv,s,x,y)
 local on=S.on(s.id);local h=PIC+FOOT
 cv.z=4;cv:rect(x,y,COL,h,D.rgba(10,13,10,.7));if on then cv:rect(x+1,y+1,COL-2,PIC-1,C.on)end
 cv.z=5;Preview.draw(cv,s.id,x+1,y)
 cv.z=5;cv:edges(x,y,COL,h,1,on and C.sel or C.frame);cv:rect(x+1,y+PIC,COL-2,1,on and C.sel or C.frame)
 if on then cv:corners(x-1,y-1,COL+2,h+2,C.gold);cv:rect(x+1,y+h-4,COL-2,3,C.gold)end
 cv:text(s.name,x+16,y+PIC,COL-110,FOOT,24,on and C.gold_hi or C.label,"left",F.title)
 cv:text(on and "On"or "Off",x+COL-96,y+PIC,80,FOOT,16,on and C.gold or C.muted,"right")
 view:_hit("base",x,y,COL,h,function()mod:set("screen_"..s.id,not on,true);if not on then view.io_unlock={s.id,view.now or 0}end;return true end,{edge=C.corner})
end
function S.draw(view,cv)
 for _,g in ipairs(GROUPS)do local x=D.left+(g[3]-1)*(COL+GAP);local y=ROW[g[2]]-34;local tw=view:_w(g[1],22,F.title)
  cv:text(g[1],x,y,tw+8,30,22,C.label,"left",F.title);cv:rect(x+tw+14,y+15,(g[4]-g[3]+1)*COL+(g[4]-g[3])*GAP-tw-14,1,C.frame,true)
 end
 for _,s in ipairs(LIST)do local p=SPOT[s.id];card(view,cv,s,D.left+(p[2]-1)*(COL+GAP),ROW[p[1]])end
end
return S
