-- Information Overload: a hover card in the talent screen's manner: what the thing is, its name, the game's own text in its colours, and lines under it.
local mod=get_mod("information_overload")
local D=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_view_definitions")
local C,F=D.c,D.font
local G={}
local WIDE,TALL,NARROW=620,460,340
local function visible(s)return (s:gsub("{#[^}]*}",""))~=""end
-- the game's text in rows no wider than w, measured a tenth wide as the panel's other tips are, since some screens draw text wider than it measures;
-- a colour still open at a break closes there and opens again on the next row
function G.rows(view,raw,size,w,font)
 raw=tostring(raw or ""):gsub("<br>","\n"):gsub("{#[^}]*}",function(t)return (t:gsub("%s",""))end)
 local out,colour={},nil
 for para in (raw.."\n"):gmatch("([^\n]*)\n")do
  local row,seen=colour or "",false
  for word in para:gmatch("%S+")do
   local try=seen and row.." "..word or row..word
   if seen and visible(word)and view:_w(try,size,font)*1.1>w then out[#out+1]=row..(colour and "{#reset()}"or "");row=(colour or "")..word else row=try end
   seen=seen or visible(word)
   for tag in word:gmatch("{#[^}]*}")do if tag:find("^{#color")then colour=tag elseif tag:find("^{#reset")then colour=nil end end
  end
  out[#out+1]=row..(colour and "{#reset()}"or "")
 end
 return out
end
-- card={kind=,name=,text=,more={{label,text}},status=,lit=}; a card taller than TALL is laid out wide instead
local function lay(view,card,w)
 local cv,cw,y=D.canvas(),w-28,10
 local function put(s,size,c,font,lh)for _,r in ipairs(G.rows(view,s,size,cw,font))do cv:text(r,14,y,cw+200,lh,size,c,"left",font);y=y+lh end end
 if card.kind then cv:text(card.kind,14,y,cw,18,13,C.gold,"left",F.medium);y=y+18 end
 put(card.name or "",22,C.value,F.title,28)
 if card.text and visible(tostring(card.text))then y=y+4;put(card.text,14,C.label,F.medium,20)end
 for _,m in ipairs(card.more or {})do y=y+6;cv.z=2;cv:rect(14,y,cw,1,C.line);y=y+7
  if m[1]then cv:text(m[1],14,y,cw,18,13,C.muted,"left",F.medium);y=y+18 end;put(m[2],14,C.value,F.body,20)
 end
 if card.status then y=y+6;cv:text(card.status,14,y,cw,18,13,card.lit and C.gold_hi or C.muted,"left",F.medium);y=y+18 end
 return cv,y+10
end
function G.build(view,lines)
 local card=lines.make();local w=NARROW;local cv,h=lay(view,card,w)
 if h>TALL then w=WIDE;cv,h=lay(view,card,w)end
 cv.z=0;cv:rect(0,0,w,h,C.tip);cv.z=1;cv:edges(0,0,w,h,1,C.hover);cv:corners(-1,-1,w+2,h+2,C.corner)
 local under,over=cv:widgets("io_tip",100);return {under=under,over=over,w=w,h=h}
end
-- the tip a hit carries: key tells one card from another, and make builds the card only when the pointer rests on it
function G.lines(key,make)return {key,build=G.build,make=make}end
return G
