-- Information Overload: Settings › Screens, a card for each screen I/O adds to, in the order they are met: Main Menu and the Mourningstar four
-- across on top, the Mission's three across below, each row filling the page's width. A card is its picture with its name and On or Off; its full line shows only while the pointer is on it,
-- in one strip along the panel's foot. Turning a screen on unlocks its own tab in the bar.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Preview=mod:io_dofile(base.."io_screen_previews")
local C,F=D.c,D.font
local LIST={
 {id="charselect",name="Character Select",place="Main Menu",icon="charselect",desc="When at the character select screen, each operative gets a service record of recorded stats."},
 {id="social",name="Squad Social",place="Mourningstar",icon="social",desc="When using the social menu you can hover over squad members to see stats I/O might have for them."},
 {id="board",name="Mission Board",place="Mourningstar",icon="board",desc="When at mission board, hover over a mission to see a briefing for that level."},
 {id="havoc",name="Havoc Board",place="Mourningstar",icon="havoc_board",desc="A complete redesign for the Havoc menu. See other IO users missions and vote for each one you want to play."},
 {id="scoreboard",name="Scoreboard",place="Mission",icon="scoreboard",desc="An in mission scoreboard, simple but effective. Comes in a few customisable styles."},
 {id="tracker",name="Tracker",place="Mission",icon="speed",desc="Tracks basic mission stats much like a scoreboard but with focus on the level rather than the players themselves."},
 {id="endscreen",name="End Screen",place="Mission",icon="endscreen",desc="A mission breakdown, viewable while hovering cursor over its panel, at the end of mission debriefing."}}
local PLACES={"Main Menu","Mourningstar","Mission"}
-- the top row's four cards share the page's width 12 apart, the bottom row's three the same width, each picture as wide as its card at the
-- pictures' own shape; the strip sits on the panel's foot
local PW,G,PAD,ASPECT=1190,12,14,378/273
local W=(PW-3*G)/4
local PH=(W-2)/ASPECT
local W3=(PW-2*G)/3
local PH3=(W3-2)/ASPECT
local S={list=LIST}
-- a screen is on until it is turned off, so a fresh install starts with every one
function S.on(id)return mod:get("screen_"..id)~=false end
local function heading(view,cv,s,x,y,span)local tw=view:_w(s,22,F.title)
 cv:text(s,x,y,tw+8,30,22,C.label,"left",F.title);cv:rect(x+tw+14,y+15,span-tw-14,1,C.frame,true)end
-- one name size for every card: the largest that keeps every name on one line beside On or Off
local function fit(view)
 local sw=math.ceil(math.max(view:_w("On",16),view:_w("Off",16)))+12;local nw=W-2*PAD-sw
 for z=22,16,-1 do local ok=true;for _,s in ipairs(LIST)do if view:_w(s.name,z,F.title)>nw then ok=false;break end end;if ok then return z,sw end end
 return 16,sw
end
local function card(view,cv,s,x,y,nz,sw,foot,W,PH)
 local on=S.on(s.id);local h=PH+foot;local key="screen_card_"..s.id
 cv.z=4;cv:rect(x,y,W,h,D.rgba(10,13,10,.7));if on then cv:rect(x+1,y+1,W-2,PH-1,C.on)end
 cv.z=5;Preview.draw(cv,s.id,x+1,y,W-2,PH)
 cv.z=5;cv:edges(x,y,W,h,1,on and C.sel or C.frame);cv:rect(x+1,y+PH,W-2,1,on and C.sel or C.frame)
 if on then cv:corners(x-1,y-1,W+2,h+2,C.gold);cv:rect(x+1,y+h-4,W-2,3,C.gold)end
 cv:text(s.name,x+PAD,y+PH,W-2*PAD-sw,foot,nz,on and C.gold_hi or C.label,"left",F.title)
 cv:text(on and "On"or "Off",x+W-PAD-sw,y+PH,sw,foot,16,on and C.gold or C.muted,"right")
 view:_hit("base",x,y,W,h,function()mod:set("screen_"..s.id,not on,true);if not on then view.io_unlock={s.id,view.now or 0}end;return true end,{edge=C.corner},nil,nil,key)
end
-- the strip: the hovered card's name and its full line, nothing at all until a card is hovered
local function strip(view,cv,y)
 local id=type(view.io_hkey)=="string"and view.io_hkey:match("^screen_card_(.+)$");local s;for _,e in ipairs(LIST)do if e.id==id then s=e end end
 if not s then return end
 local x,w,h=D.left,PW,44;local z=13
 for t=16,14,-1 do local ok=true;for _,e in ipairs(LIST)do if view:_w(e.name,t+4,F.title)+20+view:_w(e.desc,t,F.medium)>w-32 then ok=false;break end end;if ok then z=t;break end end
 local nw=view:_w(s.name,z+4,F.title)
 cv.z=6;cv:rect(x,y,w,h,C.card);cv:edges(x,y,w,h,1,C.frame)
 cv:text(s.name,x+16,y,nw+4,h,z+4,S.on(s.id)and C.gold_hi or C.label,"left",F.title)
 cv:text(view:_fit(s.desc,z,w-52-nw,F.medium),x+36+nw,y,w-52-nw,h,z,C.value,"left",F.medium)
end
function S.draw(view,cv)
 local nz,sw=fit(view);local foot=math.max(50,math.floor(nz*1.6+.5)+14);local h=PH+foot
 local x0,y1=D.left,D.top+38;local y2=y1+h+46
 local by={};for _,p in ipairs(PLACES)do by[p]={}end;for _,s in ipairs(LIST)do local t=by[s.place];t[#t+1]=s end
 heading(view,cv,PLACES[1],x0,y1-34,W);heading(view,cv,PLACES[2],x0+W+G,y1-34,3*W+2*G);heading(view,cv,PLACES[3],x0,y2-34,PW)
 local top={};for _,s in ipairs(by["Main Menu"])do top[#top+1]=s end;for _,s in ipairs(by.Mourningstar)do top[#top+1]=s end
 for i,s in ipairs(top)do card(view,cv,s,x0+(i-1)*(W+G),y1,nz,sw,foot,W,PH)end
 for i,s in ipairs(by.Mission)do card(view,cv,s,x0+(i-1)*(W3+G),y2,nz,sw,foot,W3,PH3)end
 strip(view,cv,y1+658)
end
return S
