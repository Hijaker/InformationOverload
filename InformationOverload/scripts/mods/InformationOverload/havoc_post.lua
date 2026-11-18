-- Information Overload: a Strike Team tile's Assignment posted to the Strike Team chat as one message: whose it is, the rank, the map and its enemies (Scabs, Dregs or Mixed) in
-- white, then its modifiers, each in its own colour, or all in the Havoc screen's modifier yellow where the colours would not fit
local P={}
-- the longest message the Strike Team chat delivers: 320 arrived and 325 was dropped without a word (tested 17 Nov 2026; the chat box
-- caps typing at 200); a longer post goes as the Assignment, then the modifiers, each within it, colour tags counted
P.LIMIT=320
-- the tick shows for two seconds after a post and the button can post again ten seconds after it
P.DONE,P.WAIT=2,10
-- the modifier yellow as the game's own colour tags write a colour
local TAG,RESET="{#color(240,196,92)}","{#reset()}"
-- each Havoc modifier in a colour of its own, matched by its English name with any leading "The" and case set aside; the mission's own
-- circumstances and a name in another language keep the yellow
local OWN={["encroaching garden"]="160,100,220",["pus-hardened skin"]="170,220,70",["blight spreads"]="140,160,60",["rotten armour"]="175,110,60",
 ["final toll"]="220,40,50",["rampaging enemies"]="240,120,30",["heinous rituals"]="200,60,170",["contaminated stimms"]="60,210,230",
 ["moebian 21st"]="110,140,180",["cranial corruption"]="240,190,40"}
local function own(title)local k=title:lower():gsub("^the ","");local c=OWN[k];return c and "{#color("..c..")}"or TAG end
-- the mission's own circumstance first (havoc_settings circumstances_per_theme), the Havoc modifiers next in id order; the Emperor's
-- Fading Light is on every Havoc mission, so it is left out
local THEMES={darkness_01=true,darkness_hunting_grounds_01=true,ventilation_purge_01=true,ventilation_purge_with_snipers_01=true,toxic_gas_01=true,toxic_gas_cultist_grenadier=true}
local FADING={mutator_increased_difficulty=true,mutator_highest_difficulty=true}
local function tier(id)return FADING[id]and 2 or THEMES[id]and 0 or 1 end
-- words as plain text, since the chat reads {# as the game's markup
local function plain(s)s=tostring(s or "");while s:find("{#",1,true)do s=s:gsub("{#","{")end;return s end
-- characters as the game counts them
local function chars(s)return select(2,s:gsub("[^\128-\191]",""))end
P.chars=chars
local function join(t,sep)local o={};for _,v in ipairs(t)do if v~=nil and v~=""then o[#o+1]=tostring(v)end end;return table.concat(o,sep)end
-- a tile's player as the Havoc model has them, with the Assignment the tile shows: one message, or past the limit the Assignment line
-- and then the modifiers over as many messages as they need; nil with no Assignment
function P.messages(p)
 local a=type(p)=="table"and p.a;if type(a)~="table"then return nil end
 local who=plain(p.who);if who:find("^%s*$")then who="Teammate"end
 local head=(p.me and "My"or who.."'s").." Assignment: "..join({a.rank and "Havoc "..a.rank,plain(a.name~=""and a.name or a.base),a.faction and plain(a.faction)}," · ").."."
 local list={};for i,m in ipairs(a.mods or {})do if not FADING[m.id]then list[#list+1]={tier(m.id),m.id or "",i,plain(m.title)}end end
 table.sort(list,function(x,y)if x[1]~=y[1]then return x[1]<y[1]end;if x[2]~=y[2]then return x[2]<y[2]end;return x[3]<y[3]end)
 local out={head};if #list==0 then return out end
 local all={};for _,m in ipairs(list)do if m[4]~=""then all[#all+1]=m[4]end end
 if #all==0 then return out end
 -- each in its own colour while that fits in one message, else all in the yellow, which costs one tag instead of one each
 local each={};for i,t in ipairs(all)do each[i]=own(t)..t..RESET end
 local coloured=head.." "..table.concat(each,", ").."."
 if chars(coloured)<=P.LIMIT then return {coloured}end
 local one=head.." "..TAG..table.concat(all,", ")..RESET.."."
 if chars(one)<=P.LIMIT then return {one}end
 local function line(names,last)return TAG..table.concat(names,", ")..RESET..(last and "."or ",")end
 local names={}
 for _,m in ipairs(list)do local t=m[4]
  if t~=""then local try={unpack(names)};try[#try+1]=t
   if #names>0 and chars(line(try,false))>P.LIMIT then out[#out+1]=line(names,false);names={t}else names[#names+1]=t end end
 end
 if #names>0 then out[#out+1]=line(names,true)end
 return out
end
-- the Strike Team channel among the chat's connected channels, and each message sent on it as a typed line goes; true when all were sent
function P.send(lines,deps)
 deps=deps or {}
 local chat=deps.chat or (Managers and Managers.chat);if type(chat)~="table"or type(lines)~="table"then return false end
 local party=deps.party
 if not party then local ok,C=pcall(require,"scripts/foundation/managers/chat/chat_manager_constants");party=ok and C and C.ChannelTag and C.ChannelTag.PARTY end
 local ok,chans=pcall(chat.connected_chat_channels,chat);if not ok or type(chans)~="table"then return false end
 local handle;for h,c in pairs(chans)do if type(c)=="table"and c.tag==party then handle=h;break end end
 if not handle then return false end
 for _,l in ipairs(lines)do if not pcall(chat.send_channel_message,chat,handle,l)then return false end end
 return true
end
return P
