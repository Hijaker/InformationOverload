-- Information Overload: the picture on each Screens card, that screen or what it adds, drawn in rects and text with example figures.
local mod=get_mod("information_overload")
local D=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_view_definitions")
local C,F,rgba=D.c,D.font,D.rgba
local LABEL,VALUE,GOLD,GOLD_HI,FRAME,SEL,MUTED,CORNER=C.label,C.value,C.gold,C.gold_hi,C.frame,C.sel,C.muted,C.corner
local FAINT,TINT,SHADE,TRACK=rgba(169,191,153,.13),rgba(169,191,153,.06),rgba(169,191,153,.04),rgba(169,191,153,.14)
local GOLD_TINT,GOLD_EDGE=rgba(221,183,99,.1),rgba(221,183,99,.4)
local BG={social=rgba(21,28,20),board=rgba(13,18,12),endscreen=rgba(18,24,17),tracker=rgba(10,13,10,.88)}
local V,R0="{#color(216,229,207)}","{#reset()}"
local P={}
-- coordinates are the card picture's own, 378 by 273, and a text's y is its baseline, as the mockup has it
-- SX and SY shrink a picture drawn inside another, from ox and oy
local cv,ox,oy,SX,SY=nil,0,0,1,1
local function rect(x,y,w,h,c,edge)x,y,w,h=ox+x*SX,oy+y*SY,w*SX,h*SY;if c then cv:rect(x,y,w,h,c)end;if edge then cv:edges(x,y,w,h,1,edge)end end
local function text(s,x,y,size,c,align,title)
 local h=size*1.4;local top=y-.35*size-h/2;local bx,w,a
 if align=="end"then w=x-2;bx,a=x-w,"right"elseif align=="middle"then w=2*math.min(x,376-x);bx,a=x-w/2,"center"else bx,w,a=x,376-x,"left"end
 cv:text(s,ox+bx*SX,oy+top*SY,w*SX,h*SY,size*math.min(SX,SY),c,a,type(title)=="string"and title or title and F.title or F.body)
end
local DRAW={}
-- Character Select with I/O on, its parts where a 2000 by 1250 screenshot has them, fitted across the picture; no operative drawn
local CK,CY0=346/2000,29.4
local CS_FRAME,CS_LIST,CS_ROW,CS_BTN,CS_METAL=rgba(74,70,60,.8),rgba(62,84,58,.92),rgba(150,128,62,.6),rgba(92,122,82,.98),rgba(110,112,104)
local CS_WHITE,CS_GOLD,CS_GREY,CS_BLUE,CS_RANK,CS_PORT,CS_FACE=rgba(228,228,218),rgba(221,183,99),rgba(154,160,142),rgba(157,182,216),rgba(150,130,70,.75),rgba(46,46,41),rgba(124,124,114)
local W0="{#color(228,228,218)}"
local function cx(x)return 16+x*CK end
local function cy(y)return CY0+y*CK end
local function crect(x,y,w,h,c,edge)rect(cx(x),cy(y),w*CK,h*CK,c,edge)end
local function ctext(s,x,y,size,c,align)text(s,cx(x),cy(y),size,c,align or "middle")end
-- a head and shoulders in a portrait slot
local function head(x,y,w,h)local r=w*.2*CK;cv:circle(ox+cx(x+w/2),oy+cy(y)+h*CK*.36,r,CS_FACE)
 rect(cx(x+w*.14),cy(y+h*.66),w*.72*CK,h*.34*CK,CS_FACE);rect(cx(x+w*.24),cy(y+h*.6),w*.52*CK,h*.08*CK,CS_FACE)end
-- the class emblem: a diamond in slices, a darker one inside, and the eye
local function emblem(x,y,hw,hh,c)local n=16
 for i=0,n-1 do local t=(i+.5)/n;local w=2*hw*(1-math.abs(2*t-1));crect(x-w/2,y-hh+i*2*hh/n,w,2*hh/n+.6,c)end end
function DRAW.charselect()
 crect(105,322,625,613,CS_FRAME);crect(115,330,605,595,CS_LIST)
 ctext("Friends Online  0",146,367,4.6,CS_GREY,"start");ctext("Strike Team  1/4",686,367,4.6,CS_GREY,"end")
 for i,o in ipairs({{"Kassia","Salvage Lord","Psyker - 30"},{"Mord","Salvage Lord","Hive Scum - 30"},{"Venn","Salvage Lord","Veteran - 30"},{"Ksen","Salvage Lord","Zealot - 18"},{"Dross"}})do
  local y=392+(i-1)*114;local h=i==5 and 72 or 112
  if i==3 then crect(120,y,583,h,CS_ROW)end
  crect(143,y+8,37,h-16,CS_RANK);crect(185,y+6,87,h-12,CS_PORT);head(185,y+6,87,h-12)
  if o[2]then ctext(o[1],297,y+34,6,CS_WHITE,"start");ctext(o[2],297,y+62,4.6,CS_GOLD,"start");ctext(o[3],297,y+91,4.6,CS_GREY,"start")
  elseif o[3]then ctext(o[1],297,y+52,6,CS_WHITE,"start");ctext(o[3],297,y+80,4.6,CS_WHITE,"start")
  else ctext(o[1],297,y+52,6,CS_WHITE,"start")end
 end
 crect(708,395,6,510,rgba(0,0,0,.6))
 crect(200,945,432,60,CS_BTN,CS_METAL);ctext("CREATE OPERATIVE",416,983,5,CS_WHITE)
 ctext("3 Operative slots remaining",416,1068,4.4,CS_GREY);ctext("Account Level: 479",416,1090,4.4,CS_GREY)
 local c=1635
 ctext("Service Record",c,76,7,CS_WHITE);ctext("AURIC",c,104,4.8,CS_GOLD);ctext("5 Veteran Missions, 30 To 31 Oct",c,136,4.6,CS_GREY)
 for _,e in ipairs({{1490,"2/5","Missions Won"},{1635,"1,048","Kills"},{1781,"1.53M","Damage"}})do ctext(e[2],e[1],195,7,CS_WHITE);ctext(e[3],e[1],224,4.6,CS_GREY)end
 ctext("Weapons Taken Most",c,279,5,CS_GOLD);ctext("Combat Blade Catachan Mk VI "..W0.."5 Times"..R0,c,305,4.4,CS_GREY)
 ctext("Combat Shotgun Agripinaa Mk VII "..W0.."5 Times"..R0,c,330,4.4,CS_GREY)
 ctext("What Downs Them",c,378,5,CS_GOLD);ctext("Never Downed, Died "..W0.."3 Times"..R0,c,404,4.4,CS_GREY);ctext("Grabbed "..W0.."3 Times"..R0..", 2 By Mutants",c,429,4.4,CS_GREY)
 for _,e in ipairs({{1455,"1","Horde"},{1575,"1","Elites"},{1695,"1","Specials"},{1815,"0","Bosses"}})do ctext(e[2],e[1],468,6,CS_WHITE);ctext(e[3],e[1],494,4.4,CS_GREY)end
 ctext("Most Ranged: Dreg Stalker "..W0.."x1"..R0,c,524,4.4,CS_GREY);ctext("Most Melee: Crusher "..W0.."x1"..R0,c,549,4.4,CS_GREY)
 emblem(c,730,59,77,rgba(169,163,151));emblem(c,730,52,68,rgba(111,106,96));emblem(c,730,44,58,rgba(74,71,64))
 cv:circle(ox+cx(c),oy+cy(730),18*CK,rgba(201,195,181));cv:circle(ox+cx(c),oy+cy(730),12*CK,rgba(74,71,64));cv:circle(ox+cx(c),oy+cy(730),7*CK,rgba(201,195,181))
 ctext("Venn",c,842,6.5,CS_WHITE);ctext("Salvage Lord",c,874,4.8,rgba(210,168,106));ctext("Veteran - 30 (+95)",1642,906,4.6,CS_GREY)
 crect(1420,928,430,104,CS_BTN,rgba(169,181,154));crect(1420,928,430,22,rgba(255,255,255,.08));ctext("START",c,1000,11,CS_WHITE)
 ctext("ACCOUNT WALLET",1990,646,3.6,CS_GOLD,"end");crect(1785,655,215,210,rgba(60,72,56,.92),CS_METAL)
 for i,e in ipairs({{"1 147 242",CS_GOLD},{"11 620",CS_WHITE},{"149 897",rgba(201,198,186)},{"66 956",CS_BLUE}})do
  ctext(e[1],1952,714+(i-1)*42,6,e[2],"end");crect(1964,690+(i-1)*42,24,22,rgba(141,135,122))end
end
local function social_panel()
 rect(16,14,346,244,BG.social,SEL)
 text("Your Record On This Operative",26,30,9,LABEL);text("Lily",26,48,15,VALUE);text("Psyker · 212 Games On File, 30 Oct 2026",26,61,8,LABEL)
 for _,e in ipairs({{"Games","212",26},{"Wins","146",138},{"Win Rate","68.9%",250}})do rect(e[3]-4,68,106,38,TINT);text(e[1],e[3],80,8,LABEL);text(e[2],e[3],100,17,VALUE)end
 for _,x in ipairs({22,134,246})do rect(x,110,106,118,SHADE)end
 text("Win Rate By Difficulty",26,122,8,LABEL)
 for i,e in ipairs({{"Auric","74%",70},{"Damnation","61%",58}})do local y=(i-1)*20
  text(e[1],26,136+y,9,VALUE);text(e[2],124,136+y,9,VALUE,"end");rect(26,140+y,98,2,FAINT);rect(26,140+y,e[3],2,LABEL)end
 text("What Downs You",26,188,8,LABEL);text("Downed 3 · Died 1",26,202,9,VALUE);text("Grabbed Or Pinned",26,214,7,LABEL)
 text("Top Weapons",138,122,8,LABEL)
 for i,e in ipairs({{"Combat Blade Mk VI","64 Games",98},{"Shotgun Mk VII","41 Games · 2.1M",62}})do local y=(i-1)*40
  text(e[1],138,136+y,9,VALUE);text(e[2],138,148+y,8,LABEL);rect(138,154+y,98,2,FAINT);rect(138,154+y,e[3],2,LABEL)end
 text("Best Streaks",250,122,8,LABEL)
 for i,e in ipairs({{"Headshot Streak","14"},{"Kill Streak","61"},{"Kills In A Game","412"},{"Biggest Hit","3,360"}})do local y=(i-1)*24
  text(e[1],250,136+y,9,VALUE);text("Chasm Logistratum",250,145+y,6,LABEL);text(e[2],348,141+y,12,GOLD,"end")end
 rect(22,234,330,20,TINT);text("Last Played",28,247,8,LABEL);text("30 Oct · Chasm Logistratum · Auric · Won",78,247,9,VALUE)
 text("Damage Dealt "..V.."93K"..R0,346,247,7,LABEL,"end")
end
-- a screen traced from a 2000-wide screenshot: k shrinks it, x0 and y0 are its top left, and it sits top at the picture's y0p
local function screen(k,x0,y0,y0p)
 local function sx(x)return 16+(x-x0)*k end
 local function sy(y)return y0p+(y-y0)*k end
 return function(x,y,w,h,c,edge)rect(sx(x),sy(y),w*k,h*k,c,edge)end,function(s,x,y,size,c,align)text(s,sx(x),sy(y),size,c,align)end,sx,sy
end
-- Squad Social: the Strike Team with the second operative, Lily, hovered, and the record panel in the friends list's place
local SK=346/1668;local SY0P=14+(247-750*SK)/2
local srect,stext,ssx,ssy=screen(SK,167,238,SY0P)
local SQ_PANEL,SQ_INSET,SQ_METAL,SQ_FACE=rgba(38,52,38,.95),rgba(10,14,10,.85),rgba(110,112,104),rgba(138,138,128)
function DRAW.social()
 stext("Strike Team 2/4",167,262,7,rgba(228,228,218),"start");srect(167,272,540,440,SQ_PANEL,SQ_METAL)
 for i,y in ipairs({298,402})do local on=i==2
  srect(187,y,500,84,on and rgba(70,85,62,.6)or rgba(52,66,50,.6),on and GOLD or SQ_METAL);srect(192,y+6,66,72,rgba(58,58,52))
  cv:circle(ox+ssx(225),oy+ssy(y+6)+72*SK*.36,66*SK*.2,SQ_FACE);srect(201,y+54,48,24,SQ_FACE)
  local who=i==1 and {"HijaKer","Ogryn"}or {"Lily","Psyker"}
  stext(who[1],276,y+40,6,rgba(228,228,218),"start");stext(who[2],276,y+66,4.5,rgba(150,160,140),"start")
 end
 for _,y in ipairs({506,610})do srect(187,y,500,84,SQ_INSET,SQ_METAL)end
 -- the record panel, drawn as its own picture and fitted to the list's box
 local bx,by,bw,bh=ssx(757),ssy(272),1078*SK,716*SK
 local x,y=ox,oy;SX,SY=bw/346,bh/244;ox,oy=x+bx-16*SX,y+by-14*SY
 social_panel();SX,SY,ox,oy=1,1,x,y
end
-- Mission Board: the map with its tiles over the two rings of the hive's platform, and the briefing's groups for an example map
local BK=346/1948;local BY0P=14+(247-982*BK)/2
local brect,btext,bsx,bsy=screen(BK,10,118,BY0P)
-- the hologram is dark green at the top and lit below, brightest up the spire, in fine scan lines; its tiles are the missions' own pictures
local MAP_DARK,MAP_LOW,MAP_SPIRE=rgba(28,54,33,.97),rgba(62,148,80),rgba(95,215,140)
local MAP_EDGE,MAP_ICON,MAP_LIT,MAP_CROSS,MAP_BAR=rgba(70,215,100),rgba(4,20,10),rgba(95,235,130),rgba(190,80,35,.85),rgba(42,133,61)
local MAP_ART={rgba(104,80,54),rgba(54,78,88),rgba(92,56,50),rgba(70,86,64),rgba(82,70,92)}
local B_RULE,B_WHITE,B_GREY,B_GOLD,B_BAR=rgba(88,106,89),rgba(182,190,170),rgba(117,136,119),rgba(232,198,102),rgba(103,144,103)
local function m(x,y)return 10+x*.768,118+y*.768 end
local function mrect(x,y,w,h,c,edge)local X,Y=m(x,y);brect(X,Y,w*.768,h*.768,c,edge)end
local TILES={{180,188,{285,318}},{440,135},{695,190,{795,325}},{975,150,{1083,272}},{1250,290,{1352,415}},
 {175,650,{275,770}},{1003,680},{1535,628,{1640,760}},{218,960,{325,1082}},{1020,972}}
-- a ring as short strokes, those outside the map left out
local function ring(cyy,rx,ry,c)local n=72;local X0,Y0=m(0,0);local X1,Y1=m(1751,1279)
 local function at(t)local X,Y=m(875+rx*math.cos(t),cyy+ry*math.sin(t));return X,Y end
 for i=0,n-1 do local ax,ay=at(2*math.pi*i/n);local cx2,cy2=at(2*math.pi*(i+1)/n)
  if math.min(ax,cx2)>=X0 and math.max(ax,cx2)<=X1 and math.min(ay,cy2)>=Y0 and math.max(ay,cy2)<=Y1 then
   cv:line(ox+bsx(ax),oy+bsy(ay),ox+bsx(cx2),oy+bsy(cy2),.9,c,nil,true)end end end
function DRAW.board()
 mrect(0,0,1751,1279,MAP_DARK)
 -- lit from the platform up, every other line a shade dimmer, then a soft column of light up the spire that fades out as it rises to the top
 local n=64;local bh=1279/n
 for i=0,n-1 do local t=(i+.5)/n;local k=math.min(1,math.max(0,(t-.25)/.3));k=k*k*(3-2*k)
  if k>0 then local c=rgba(MAP_LOW[2],MAP_LOW[3],MAP_LOW[4],.85*k*(i%2==0 and 1 or .8));mrect(0,i*bh,1751,bh,c)end end
 local sn,sx0,sw=32,500,800
 for i=0,sn-1 do local x=sx0+(i+.5)*sw/sn;local g=.32*math.exp(-((x-898)/170)^2)
  for _,v in ipairs({{0,130,.1},{130,120,.2},{250,150,.35},{400,150,.65},{550,729,1}})do mrect(sx0+i*sw/sn,v[1],sw/sn,v[2],rgba(MAP_SPIRE[2],MAP_SPIRE[3],MAP_SPIRE[4],g*v[3]))end
 end
 mrect(-3,-3,1757,1285,nil,rgba(70,215,100,.35));mrect(0,0,1751,1279,nil,MAP_EDGE)
 ring(1010,1010,600,rgba(150,245,180,.32));ring(1060,760,430,rgba(150,245,180,.32))
 -- the orange marks in the map's corners
 for _,c in ipairs({{78,65},{1673,65},{84,1200},{1665,1200}})do mrect(c[1]-20,c[2]-3,40,6,MAP_CROSS);mrect(c[1]-3,c[2]-20,6,40,MAP_CROSS)end
 for i,t in ipairs(TILES)do
  mrect(t[1],t[2]-9,95,6,rgba(20,40,26));mrect(t[1],t[2]-9,58,6,B_WHITE)
  -- each tile a black box under a thin edge, its picture set inside it
  mrect(t[1],t[2],95,110,rgba(0,0,0),i==7 and rgba(255,255,255)or rgba(70,100,74));mrect(t[1]+10,t[2]+10,75,90,MAP_ART[(i-1)%#MAP_ART+1])
  -- its type, and under it the circumstance when it has one: black squares with the green glyph inside
  mrect(t[1]-48,t[2]+8,44,44,MAP_ICON,MAP_EDGE);mrect(t[1]-36,t[2]+20,20,20,nil,MAP_LIT)
  if i%2==1 then mrect(t[1]-48,t[2]+60,44,44,MAP_ICON,MAP_EDGE);mrect(t[1]-32,t[2]+74,12,16,MAP_LIT)end
  if t[3]then mrect(t[3][1]-11,t[3][2]-11,22,22,rgba(232,178,58,.85))end
 end
 for _,e in ipairs({{708,130},{1550,566}})do
  mrect(e[1]-58,e[2]-4,44,44,MAP_ICON,MAP_EDGE);mrect(e[1],e[2]+2,105,30,rgba(95,224,138));local X,Y=m(e[1]+14,e[2]+26);btext("Event",X,Y,3.5,MAP_ICON,"start")end
 -- the game's own frame: the green bar down the right of the map, as tall as the map
 brect(1376,118,8,972,MAP_BAR)
 -- Quickplay and Campaigns, each a black box with its icon in a cell of its own and two lines, as the board has them; Quickplay is picked
 for i,b in ipairs({{913,"+10% - 20% Bonus","Quickplay",MAP_LIT},{975,"Completed (20/21)","Campaigns",rgba(232,178,58)}})do local y=b[1]
  brect(980,y,290,49,rgba(0,0,0),B_RULE);brect(1028,y,2,49,B_RULE)
  if i==1 then btext(">>",1004,y+33,5.5,MAP_LIT,"middle")else brect(996,y+16,16,17,b[4])end
  btext(b[2],1038,y+21,3.5,B_GREY,"start");btext(b[3],1038,y+42,4.2,MAP_LIT,"start")
 end
 for _,c in ipairs({{970,905,1,1},{1280,905,-1,1},{970,970,1,-1},{1280,970,-1,-1}})do brect(math.min(c[1],c[1]+12*c[3]),c[2]-(c[4]<0 and 2 or 0),12,2,B_GREY);brect(c[1]-(c[3]<0 and 2 or 0),math.min(c[2],c[2]+12*c[4]),2,12,B_GREY)end
 -- I/O's briefing for an example map, each group as the board lays it out, in words where the card has room for them
 brect(1455,125,503,287,rgba(0,0,0),B_RULE);btext("Magistrati Oubliette",1478,165,6.5,B_WHITE,"start");btext("Assassination · The Torrent",1478,197,3.5,B_GREY,"start")
 brect(1457,214,499,2,B_RULE);btext("6 Runs",1520,244,3.5,B_WHITE,"middle");brect(1580,216,2,38,B_RULE)
 for i,won in ipairs({false,true,true,true,false,true})do if won then brect(1598+(i-1)*57.5,231,53.5,8,B_BAR)else brect(1598+(i-1)*57.5,231,53.5,8,nil,B_BAR)end end
 brect(1457,254,499,2,B_RULE);brect(1708,266,2,130,B_RULE)
 btext("Won",1478,284,3.5,B_GREY,"start");btext("67%",1478,332,9,B_WHITE,"start");btext("4 Won, 2 Lost",1478,382,3.5,B_GREY,"start")
 btext("Best Clear",1730,284,3.5,B_GREY,"start");btext("21:30",1730,332,9,B_GOLD,"start");btext("Havoc 40 · 20 Oct",1730,382,3.5,B_GREY,"start")
 brect(1455,423,503,330,rgba(0,0,0),B_RULE)
 btext("A winning record here.",1478,458,3.5,B_WHITE,"start");btext("Zealot has won all three of its runs.",1478,488,3.5,B_GREY,"start")
 btext("Runs, Newest First",1478,548,3.5,B_GREY,"start")
 for i,r in ipairs({{"30 Oct","Havoc 40","Won","1,204,310"},{"28 Oct","Auric","Lost","611,902"},{"27 Oct","Auric","Won","598,450"},{"24 Oct","Havoc 40","Won","1,592,310"}})do local y=584+(i-1)*36
  if i==1 then brect(1462,y-24,489,32,rgba(232,198,102,.12))end
  btext(r[1],1478,y,3.5,B_WHITE,"start");btext(r[2],1580,y,3.5,B_WHITE,"start");btext(r[3],1720,y,3.5,r[3]=="Won"and B_WHITE or B_GREY,"start");btext(r[4],1935,y,3.5,B_WHITE,"end")end
 brect(1455,764,503,210,rgba(0,0,0),B_RULE);btext("What Downs You Here",1478,796,3.5,B_GREY,"start");btext("4 Of 6 Tracked",1935,796,3.5,B_GREY,"end")
 btext("Gunfire.",1478,832,4.2,B_WHITE,"start")
 for i,d in ipairs({{"Reaper",3,260},{"Dreg Gunner",2,173},{"Scab Shooter",1,87},{"Poxburster",1,87}})do local y=868+(i-1)*28
  btext(d[1],1478,y,3.5,B_WHITE,"start");brect(1640,y-12,d[3],8,i<4 and B_BAR or nil,i==4 and B_BAR or nil);btext(tostring(d[2]),1935,y,3.5,B_WHITE,"end")end
 brect(1455,985,503,115,rgba(0,0,0),B_RULE);btext("Won Here With",1478,1016,3.5,B_GREY,"start")
 for i,w in ipairs({{"Lily","Zealot","3–0"},{"SandSnake","Veteran","2–1"}})do local y=1048+(i-1)*30
  btext(w[1],1478,y,3.5,B_WHITE,"start");btext(w[2],1640,y,3.5,B_GREY,"start");btext(w[3],1935,y,3.5,B_WHITE,"end")end
end
-- Squad Cards with Extra Stats, laid out as scoreboard_draw's own, their 950 by 486 shrunk into the picture, with example figures; each row's top
-- figure gold, Downs and Deaths never
local QK=346/950;local QY=42+(190-486*QK)/2;local QRULE=rgba(60,78,57,.6)
local SQUAD={{"Kassia Venn","Veteran","61,204",.34,{"8,412","612","1,036","412","343","41","28","0","290","53","0","0"},true},
 {"Brother Mord","Zealot","54,880",.31,{"12,880","1,184","488","388","331","37","19","1","300","31","1","0"}},
 {"Ksen","Psyker","40,112",.22,{"4,120","803","597","290","243","25","22","0","150","93","0","0"}},
 {"Dross","Ogryn","22,301",.12,{"9,960","241","352","175","153","12","9","1","140","13","2","1"}}}
-- each row's label, its top and its kind: small, under Kills, or one half of the last row
local QROWS={{"Boss Dmg",176,"small"},{"Weakspots Hit",202,"small"},{"Critical Hits",228,"small"},{"Kills",262},{"Lesser Enemies",290,"in"},{"Elites",312,"in"},
 {"Specials",334,"in"},{"Monstrosities",356,"in"},{"Melee Enemies",386,"in"},{"Ranged Enemies",408,"in"},{"Downs",446,"half"},{"Deaths",446,"half2"}}
local function n(v)return tonumber((v:gsub(",","")))end
function DRAW.scoreboard()
 local function q(x,y,w,h,c,edge)rect(16+x*QK,QY+y*QK,w*QK,h*QK,c,edge)end
 -- a text in card units, centred on its row from y, lh tall
 local function qt(s,x,y,lh,size,c,align,font)local k=size*QK;text(s,16+x*QK,QY+(y+lh/2)*QK+.35*k,k,c,align,font)end
 local top,topd={},0
 for _,p in ipairs(SQUAD)do topd=math.max(topd,n(p[3]));for j=1,10 do top[j]=math.max(top[j]or 0,n(p[5][j]))end end
 for i,p in ipairs(SQUAD)do local cx=(i-1)*240;local you=p[6]
  q(cx,0,230,486,BG.tracker,you and GOLD or FRAME)
  for _,v in ipairs({{0,0},{1,0},{0,1},{1,1}})do q(cx+v[1]*218,v[2]*484,12,2,CORNER);q(cx+v[1]*228,v[2]*474,2,12,CORNER)end
  qt(p[1],cx+16,12,26,20,you and GOLD_HI or VALUE);qt(p[2],cx+16,38,20,15,MUTED,nil,F.medium)
  qt("Damage",cx+16,62,20,15,MUTED,nil,F.medium);qt(p[3],cx+16,82,46,40,n(p[3])==topd and GOLD or VALUE,nil,true)
  q(cx+16,134,198,5,TRACK);q(cx+16,134,198*p[4],5,you and GOLD or LABEL)
  qt(math.floor(p[4]*100+.5).."% of the squad's damage",cx+16,144,20,15,MUTED,nil,F.medium)
  for _,y in ipairs({172,258,438})do q(cx+16,y,198,1,QRULE)end;q(cx+30,380,184,1,TRACK)
  for j,e in ipairs(QROWS)do local inset=e[3]=="in";local half=e[3]=="half"and 0 or e[3]=="half2"and 108 or nil
   local lx=cx+16+(inset and 14 or 0)+(half or 0);local lh=inset and 22 or 26;local v=p[5][j]
   qt(e[1],lx,e[2],lh,(inset or e[3]=="small")and 15 or 17,inset and MUTED or LABEL,nil,F.medium)
   qt(v,half and lx+90 or cx+214,e[2],lh,inset and 18 or e[3]=="small"and 20 or 22,j<=10 and n(v)==top[j]and n(v)>0 and GOLD or VALUE,"end",true)
  end
 end
end
-- the Tracker Panel laid out as scoreboard_draw's own, its 700 by 362 shrunk into the picture, with example figures
local TK,TX,TY=346/700,16,14+(249-362*346/700)/2
local function trect(x,y,w,h,c)rect(TX+x*TK,TY+y*TK,w*TK,h*TK,c)end
local function tbox(s,x,y,w,h,size,c,align,font)cv:text(s,ox+TX+x*TK,oy+TY+y*TK,w*TK,h*TK,size*TK,c,align or "left",font or F.medium)end
local RULE,TM_BOX,GV=rgba(60,78,57,.6),rgba(10,13,10,.88),"{#color(221,183,99)}"
function DRAW.tracker()
 trect(0,0,700,362,TM_BOX);trect(0,0,700,2,FRAME);trect(0,360,700,2,FRAME);trect(0,0,2,362,FRAME);trect(698,0,2,362,FRAME)
 for _,p in ipairs({{0,0},{1,0},{0,1},{1,1}})do trect(p[1]*688,p[2]*360,12,2,CORNER);trect(p[1]*698,p[2]*350,2,12,CORNER)end
 tbox("Magistrati Oubliette · Damnation",24,12,652,34,26,VALUE,"left",F.title);trect(24,52,652,1,RULE)
 local ay,ax,bx,cx=64,24,246,478
 tbox("Mission Time",ax,ay,200,24,18,LABEL);tbox("18:41",ax,ay+22,210,80,72,VALUE,"left",F.title)
 trect(ax,ay+112,194,5,TRACK);trect(ax,ay+112,194*.77,5,LABEL);tbox("Best Clear",ax,ay+122,120,22,16,MUTED);tbox("24:10",ax,ay+122,194,22,16,GOLD,"right")
 trect(bx-14,ay,1,226,RULE);trect(cx-14,ay,1,226,RULE)
 tbox("Kill Streak",bx,ay,210,24,18,LABEL);tbox("Kills Before Taking A Hit",bx,ay+24,210,20,14,MUTED);tbox("37",bx,ay+44,90,26,24,VALUE,"left",F.title);tbox("Mission Best 61",bx,ay+46,210,22,14,GOLD,"right")
 tbox("Kills Before Losing Health",bx,ay+72,210,20,14,MUTED);tbox("52",bx,ay+92,90,24,22,VALUE,"left",F.title);tbox("Best 88",bx,ay+94,210,22,14,GOLD,"right");trect(bx,ay+118,210,1,RULE)
 tbox("Downs",bx,ay+124,210,24,18,LABEL);tbox("1",bx,ay+148,120,50,46,VALUE,"left",F.title);tbox("Deaths "..V.."0"..R0,bx,ay+168,210,22,15,MUTED,"right")
 tbox("Last: Poxburster",bx,ay+200,210,22,15,MUTED)
 tbox("Kills",cx,ay,198,24,18,LABEL);tbox("412",cx,ay+24,120,50,46,VALUE,"left",F.title);tbox("Best Here "..GV.."455"..R0,cx,ay+44,198,22,15,MUTED,"right");trect(cx,ay+82,198,1,RULE)
 for i,e in ipairs({{"Melee Horde","214"},{"Ranged Horde","96"},{"Elite","41"},{"Special","28"},{"Boss","2"}})do local ry=ay+86+(i-1)*28
  tbox(e[1],cx,ry,140,28,17,MUTED);tbox(e[2],cx,ry,198,28,22,VALUE,"right",F.title)end
 trect(ax,304,652,40,GOLD_TINT);trect(ax,304,4,40,GOLD);tbox("Record In Reach",ax+16,304,210,40,22,GOLD,"left",F.title)
 tbox(GV.."5:29"..R0.." to beat your best clear",ax+226,304,420,40,18,LABEL)
end
function DRAW.endscreen()
 rect(18,16,342,240,BG.endscreen,SEL)
 rect(30,26,82,16,rgba(169,191,153,.12),FRAME);rect(36,31,6,6,VALUE);text("Mission Won",46,38,9,VALUE);text("Mission Debrief · 30 Oct",120,38,9,LABEL)
 text("22:41",348,56,30,VALUE,"end",true);text("Mission Time",348,70,9,LABEL,"end")
 text("Chasm Logistratum",30,64,17,VALUE);text("Damnation · Veteran · Combat Blade · With Mord, Ksen",30,80,9,LABEL)
 rect(30,88,318,1,FRAME);text("Records Broken This Run",30,106,12,VALUE,nil,true);text("2 New",348,106,9,LABEL,"end")
 for i,e in ipairs({{"Kills In A Game","412","+38","Was 374"},{"Fastest Clear","22:41","-1:12","Was 23:53"}})do local x=30+(i-1)*164
  rect(x,114,154,70,GOLD_TINT,GOLD_EDGE);rect(x,114,2,70,GOLD);text("Best On Any Operative",x+10,128,8,GOLD);text(e[1],x+10,140,9,VALUE)
  text(e[2],x+10,166,22,GOLD,nil,true);text(e[3],x+80,166,11,GOLD,nil,true);text(e[4],x+10,178,8,LABEL)end
 text("By Enemy Type",30,206,11,VALUE,nil,true)
 for i,e in ipairs({{"Horde","286",120,104},{"Elites","41",70,84},{"Specials","28",60,52}})do local y=220+(i-1)*13
  text(e[1],30,y,9,VALUE);rect(76,y-5,150,4,FAINT);rect(76,y-6,e[3],6,LABEL);rect(76+e[4],y-9,2,10,VALUE);text(e[2],252,y,10,VALUE,"end")end
 text("Most Killed",348,220,8,LABEL,"end");text("Poxwalker 155",348,233,10,VALUE,"end")
end
-- a picture that fails is told once and left blank, and the rest of the page still draws
local broken={}
function P.draw(canvas,id,x,y)
 local f=DRAW[id];if not f or broken[id]then return end
 cv,ox,oy,SX,SY=canvas,x,y,1,1;local ok,err=pcall(f);cv=nil
 if not ok then broken[id]=true;mod:error("I/O Screens picture %s: %s",id,tostring(err))end
end
return P
