-- Information Overload: draws This Mission and the squad onto any pen with rect and text, the HUD's or the panel's canvas.
return function(S,D)
local W={}
local C=setmetatable({box=D.rgba(10,13,10,.88),track=D.rgba(169,191,153,.14),rule=D.rgba(60,78,57,.6),gold_tint=D.rgba(221,183,99,.08),label_tint=D.rgba(169,191,153,.06)},{__index=D.c})
local F=D.font
local DASH="—"
local GOLD,VALUE,MUTED="{#color(221,183,99)}","{#color(216,229,207)}","{#color(132,149,120)}"
-- made once here, since the overlay draws every frame the key is held
local CORNERS={{0,0},{1,0},{0,1},{1,1}}
-- the plain table stays 950 wide, short of the Tab overlay's Penances
local COLS={{"Damage",520,"damage"},{"Kills",600,"kills"},{"Elites",680,"elites"},{"Specials",760,"specials"},{"Downs",840,"downs"},{"Deaths",920,"deaths"}}
local CARD={{"Kills","kills"},{"Elites","elites"},{"Specials","specials"}}
-- the Strip's line of figures on each page: the field, then its name for one and for any other number
local STRIP={{"kills","kill","kills"},{"elites","elite","elites"},{"specials","special","specials"},{"downs","down","downs"},{"deaths","death","deaths"}}
local STRIP_SUPPORT={{"revives","revive","revives"},{"saves","save","saves"},{"blocked","blocked","blocked"},{"dodged","dodged","dodged"},{"blitzes","blitz","blitzes"},{"abilities","ability","abilities"}}
local function box(pen,x,y,w,h,edge)
 pen:rect(x,y,w,h,C.box)
 pen:rect(x,y,w,2,edge,1);pen:rect(x,y+h-2,w,2,edge,1);pen:rect(x,y,2,h,edge,1);pen:rect(x+w-2,y,2,h,edge,1)
 for _,v in ipairs(CORNERS)do pen:rect(x+v[1]*(w-12),y+v[2]*(h-2),12,2,C.corner,2);pen:rect(x+v[1]*(w-2),y+v[2]*(h-12),2,12,C.corner,2)end
end
local function bar(pen,x,y,w,k,fill)pen:rect(x,y,w,5,C.track,1);if k>0 then pen:rect(x,y,math.max(1,w*math.min(1,k)),5,fill,2)end end
-- figures are kept once worked out, so a held panel makes no new strings a frame; let go when it grows large
local CC,cc_n={},0
local function commas(n)if n==nil then return DASH end;local s=CC[n];if not s then if cc_n>600 then CC,cc_n={},0 end;s=S.commas(n);CC[n]=s;cc_n=cc_n+1 end;return s end
local function num(n)return n and commas(n)or DASH end
-- a pen's kept measures, per UI scale: text widths by font and size, and the fits worked out from them
local function kept(pen)
 local all=pen.io_widths;if not all or all.n>600 then all={n=0};pen.io_widths=all end
 local key=pen.k or 1;local per=all[key];if not per then per={};all[key]=per end;return per,all
end
local function mw(pen,s,size,font)
 local per,all=kept(pen);font=font or F.body
 local byf=per[font];if not byf then byf={};per[font]=byf end;local bys=byf[size];if not bys then bys={};byf[size]=bys end
 local v=bys[s];if not v then v=pen:width(s,size,font);bys[s]=v;all.n=all.n+1 end;return v
end
local function tw(pen,s,size,font,k)return pen.width and mw(pen,s,size,font)or #s*size*k end
-- the kill kinds' colours on the Tracker Panel's mix bar, in S.CATS order: melee horde, ranged horde, elite, special, boss
local MIX={D.rgba(169,191,153,1),D.rgba(104,146,170,1),D.rgba(221,183,99,1),D.rgba(196,96,64,1),D.rgba(236,214,160,1)}
-- the key's items, each name with its count and colour, kept between frames
local ITEMS={}
local function key_items(cats)
 for i,e in ipairs(cats)do local it=ITEMS[i]or {};ITEMS[i]=it;it[1],it[2],it[3]=e[1],commas(e[2]or 0),MIX[i]or C.label end
 for i=#ITEMS,#cats+1,-1 do ITEMS[i]=nil end;return ITEMS
end
local function key_iw(pen,it,s,pad,k)return pad+tw(pen,it[1],s,F.medium,k)+5+tw(pen,it[2],s+2,F.title,k)end
local function key_sum(pen,s,pad,k)local n=0;for _,it in ipairs(ITEMS)do n=n+key_iw(pen,it,s,pad,k)end;return n end
-- the three cells: each streak with its best, and Downs with Deaths
local CELL={"Kills Before Taking A Hit","Kills Before Losing Health","Downs"}
local CELL_W={.35,.37,.28}
local function cell(t,i,raw)
 if i==1 then return t.streak,t.streak_best and "Mission Best "..GOLD..num(t.streak_best).."{#reset()}"end
 if i==2 then return t.health_streak,t.health_streak_best and "Best "..GOLD..num(t.health_streak_best).."{#reset()}"end
 return t.downs,"Deaths "..VALUE..(raw and t.deaths or num(t.deaths)).."{#reset()}"
end
-- a label set at size, smaller to 11 where the pen can measure and it runs past w, else cut
local function fit(pen,s,x,y,w,h,size,c,align)
 if pen.width then while size>11 and mw(pen,s,size,F.medium)>w do size=size-1 end
  local n,full=#s,s;while n>4 and mw(pen,s,size,F.medium)>w do n=n-1;s=S.cut(full,n)end
 end
 pen:text(s,x,y,w,h,size,c,align or "left",F.medium)
end
-- a label on up to two lines of 15, broken at the space nearest its middle where one line runs past w; a second line still too long is fitted
local function label2(pen,s,x,y,w,c)
 if not pen.width or mw(pen,s,15,F.medium)<=w then fit(pen,s,x,y,w,18,15,c);return end
 local per=kept(pen);local m=per[label2];if not m then m={};per[label2]=m end;local by=m[w];if not by then by={};m[w]=by end
 local v=by[s]
 if v==nil then
  local best,cut=math.huge,nil;for i in s:gmatch("() ")do local d=math.abs(mw(pen,s:sub(1,i-1),15,F.medium)-mw(pen,s:sub(i+1),15,F.medium));if d<best then best,cut=d,i end end
  v=cut and {s:sub(1,cut-1),s:sub(cut+1)}or false;by[s]=v
 end
 if not v then fit(pen,s,x,y,w,18,15,c);return end
 fit(pen,v[1],x,y,w,18,15,c);fit(pen,v[2],x,y+18,w,18,15,c)
end
-- the kill best from before this mission: once passed, the old one, all in gold
local function kills_best(t)
 if (t.kills or 0)>t.kills_best then return GOLD.."Old Best "..commas(t.kills_best).."{#reset()}"end
 return "Best Here "..GOLD..commas(t.kills_best).."{#reset()}"
end
-- the time to beat the best clear as its own figure under the clock: gold while it is ahead, grey once past; nil with no best to chase
local function beat(t,seconds)
 local rt=S.record(t,seconds);if not rt then return nil end
 local left=t.best_clear-(t.clock_seconds or seconds)
 if left>0 then return S.best_clock(t,t.final and left or math.ceil(left)),t.final and "Under Your Old Best"or "Left To Beat Your Best",true end
 return "+"..S.best_clock(t,-left),"Over Your Best",false
end
-- Kills Leads: the clock on the left with a bar toward the best clear and the time to beat under it; Kills across the top of the right with
-- its best and its mix of kinds; the two kill streaks and Downs in three cells under it, every best a grey label with a gold figure
-- w widens the Kills side, the clock keeping its column; f scales the whole panel from its corner, through a pen kept on the pen it scales
local SCALED={}
function SCALED:rect(x,y,w,h,c,l)local f,ox,oy=self.f,self.ox,self.oy;self.pen:rect(ox+(x-ox)*f,oy+(y-oy)*f,math.max(1,w*f),math.max(1,h*f),c,l)end
function SCALED:text(s,x,y,w,h,size,c,align,font)local f,ox,oy=self.f,self.ox,self.oy;self.pen:text(s,ox+(x-ox)*f,oy+(y-oy)*f,w*f,h*f,size*f,c,align,font)end
local function scaled_width(q,s,size,font)return q.pen:width(s,size*q.f,font)/q.f end
local SCALED_META={__index=SCALED}
local function scaled(pen,ox,oy,f)
 local q=pen.io_scaled;if not q then q=setmetatable({pen=pen},SCALED_META);pen.io_scaled=q end
 q.ox,q.oy,q.f=ox,oy,f;q.width=pen.width and scaled_width or false
 -- its widths are kept by the whole scale it measures at
 q.k=f*(pen.k or 1)
 return q
end
function W.tm(pen,x,y,t,seconds,w,f)
 local bw,h=S.size("tm");w=w or bw;f=f or 1
 if f~=1 then pen=scaled(pen,x,y,f)end
 box(pen,x,y,w,h,C.frame)
 pen:text(S.cut(t.title,46),x+24,y+12,w-48,34,26,C.value,"left",F.title);pen:rect(x+24,y+52,w-48,1,C.rule,1)
 local ay=y+64;local ax,bx=x+24,x+246;local rw=x+w-24-bx
 -- the clock
 pen:text("Mission Time",ax,ay,200,24,18,C.label,"left",F.medium)
 pen:text(seconds and S.clock(seconds)or DASH,ax,ay+22,210,80,72,C.value,"left",F.title)
 if t.best_clear then
  local cs=t.clock_seconds or seconds;bar(pen,ax,ay+112,194,cs and cs/t.best_clear or 0,C.gold)
  pen:text("Best Clear "..GOLD..S.best_clock(t,t.best_clear).."{#reset()}",ax,ay+122,194,22,15,C.muted,"left",F.medium)
  local fig,words,ahead=beat(t,seconds)
  if fig then pen:rect(ax,ay+152,194,1,C.rule,1)
   -- level with the cells' figures and their bests on the right
   pen:text(fig,ax,ay+166,194,36,34,ahead and C.gold or C.muted,"left",F.title)
   pen:text(words,ax,ay+204,194,18,14,ahead and C.label or C.muted,"left",F.medium)
  end
 end
 pen:rect(bx-14,ay,1,240,C.rule,1)
 -- Kills: the figure, and beside it its best over the mix bar; under them the key on one line, each name with its count
 pen:text("Kills",bx,ay,rw,22,18,C.label,"left",F.medium)
 local kn=num(t.kills);local kw=pen.width and mw(pen,kn,48,F.title)or #kn*26
 pen:text(kn,bx,ay+22,kw+8,52,48,C.value,"left",F.title)
 local sx=bx+kw+28;local sw=x+w-24-sx
 if t.kills_best then pen:text(kills_best(t),sx,ay+26,sw,20,15,C.muted,"left",F.medium)end
 local total=0;for _,e in ipairs(t.cats)do total=total+(e[2]or 0)end
 if total>0 then local cx=sx
  for i,e in ipairs(t.cats)do if (e[2]or 0)>0 then local cw=math.max(1,(sw-2*(#t.cats-1))*e[2]/total);pen:rect(cx,ay+52,cw,6,MIX[i]or C.label,2);cx=cx+cw+2 end end
 else pen:rect(sx,ay+52,sw,6,C.track,1)end
 -- the key's items spread across the whole right side from their own measured widths, smaller where they would not fit
 local items=key_items(t.cats)
 local ks=13
 while ks>9 and key_sum(pen,ks,10,.5)+6*(#items-1)>rw do ks=ks-1 end
 local gap=#items>1 and math.max(6,(rw-key_sum(pen,ks,10,.5))/(#items-1))or 0;local kx=bx
 for _,it in ipairs(items)do local nw=tw(pen,it[1],ks,F.medium,.5)
  local vw=tw(pen,it[2],ks+2,F.title,.5)
  pen:rect(kx,ay+92,7,7,it[3],2);pen:text(it[1],kx+10,ay+86,nw+2,20,ks,C.muted,"left",F.medium)
  pen:text(it[2],kx+10+nw+5,ay+86,vw+4,20,ks+2,C.value,"left",F.title);kx=kx+key_iw(pen,it,ks,10,.5)+gap end
 pen:rect(bx,ay+122,rw,1,C.rule,1)
 local cx=bx
 for i=1,3 do local cw=rw*CELL_W[i];local px=i>1 and 14 or 0;local v,best=cell(t,i,true)
  if i>1 then pen:rect(cx,ay+128,1,112,C.rule,1)end
  label2(pen,CELL[i],cx+px,ay+128,cw-px-12,C.label)
  pen:text(num(v),cx+px,ay+166,cw-px,36,34,C.value,"left",F.title)
  if best then pen:text(best,cx+px,ay+204,cw-px-8,18,14,C.muted,"left",F.medium)end
  cx=cx+cw
 end
 return w*f,h*f
end
-- the Tab panel draws through these at its corner and scale, set as it starts
local TP,TX,TY,TF
local function tx(s,ax,ay,aw,ah,size,c,align,font)TP:text(s,TX+ax*TF,TY+ay*TF,aw*TF,ah*TF,size*TF,c,align or "left",font or F.medium)end
local function rc(ax,ay,aw,ah,c,l)TP:rect(TX+ax*TF,TY+ay*TF,math.max(1,aw*TF),math.max(1,ah*TF),c,l)end
-- the engine's Utf8.upper capitalises accented and Cyrillic letters too; string.upper only touches a-z
local function up(s)local u=Utf8 and Utf8.upper;return u and u(s)or s:upper()end
-- the mission and difficulty keep to one line: the size comes down to fit, then the mission's name is cut; kept per mission and difficulty
local function tab_name(pen,base,diff,room)
 local by
 if pen.width then local per=kept(pen);local m=per[tab_name];if not m then m={};per[tab_name]=m end;by=m[base];if not by then by={};m[base]=by end
  local v=by[diff or false];if v then return v[1],v[2]end
 end
 local size,n=32,24
 local function plain()return up(S.cut(base,n))..(diff and " · "..diff or "")end
 if pen.width then
  while size>24 and pen:width(plain(),size,F.title)>room do size=size-2 end
  while n>6 and pen:width(plain(),size,F.title)>room do n=n-1 end
 end
 local name=up(S.cut(base,n));if diff then name=name..MUTED.." · {#reset()}"..diff end
 if by then by[diff or false]={name,size}end
 return name,size
end
-- Layout A, in the Tab overlay's top right corner: the game's difficulty icon and the mission over the Tracker Panel's Kills Leads, pressed to the
-- slot's 800 by 250. f scales it to the slot; ic holds the overlay's own difficulty icon, its space left empty when missing.
local NO_ICONS={}
function W.tab(pen,x,y,t,seconds,f,_,ic)
 f=f or 1;ic=ic or NO_ICONS
 TP,TX,TY,TF=pen,x,y,f
 local w,h=800*f,250*f
 box(pen,x,y,w,h,C.frame)
 if ic.difficulty and pen.texture then pen:texture(ic.difficulty,x+24*f,y+14*f,40*f,40*f,C.value)end
 local room=696
 local name,size=tab_name(pen,t.mission or t.title,t.difficulty and up(t.difficulty),room)
 tx(name,76,12,room,42,size,C.value,"left",F.title);rc(24,59,752,1,C.rule,1)
 -- the clock, a bar toward the best clear, and the time to beat under it: gold while ahead, grey once past
 tx("Mission Time",24,71,188,20,17,C.label)
 tx(seconds and S.clock(seconds)or DASH,23,91,200,68,62,C.value,"left",F.title)
 if t.best_clear then
  rc(24,162,188,5,C.track,1);local cs=t.clock_seconds or seconds;local k=cs and math.min(1,cs/t.best_clear)or 0;if k>0 then rc(24,162,188*k,5,C.gold,2)end
  tx("Best Clear "..GOLD..S.best_clock(t,t.best_clear).."{#reset()}",24,173,188,16,13,C.muted)
  local fig,words,ahead=beat(t,seconds)
  if fig then rc(24,193,188,1,C.rule,1)
   tx(fig,24,200,188,26,24,ahead and C.gold or C.muted,"left",F.title)
   tx(words,24,228,188,16,13,ahead and C.label or C.muted)
  end
 end
 rc(228,71,1,168,C.rule,1)
 -- Kills: the figure, its best beside it over the mix bar, and the key on one line across the right side
 local bx,rw=242,534
 tx("Kills",bx,71,rw,20,17,C.label)
 local kn=num(t.kills);local kw=tw(pen,kn,42,F.title,.55)
 tx(kn,bx,91,kw+8,46,42,C.value,"left",F.title)
 local sx=bx+kw+18;local sw=bx+rw-sx
 if t.kills_best then tx(kills_best(t),sx,97,sw,16,13,C.muted)end
 local total=0;for _,e in ipairs(t.cats)do total=total+(e[2]or 0)end
 if total>0 then local cx=sx
  for i,e in ipairs(t.cats)do if (e[2]or 0)>0 then local cw=math.max(1,(sw-2*(#t.cats-1))*e[2]/total);rc(cx,118,cw,6,MIX[i]or C.label,2);cx=cx+cw+2 end end
 else rc(sx,118,sw,6,C.track,1)end
 local items=key_items(t.cats)
 local ks=13
 while ks>9 and key_sum(pen,ks,12,.55)+6*(#items-1)>rw do ks=ks-1 end
 local gap=#items>1 and math.max(6,(rw-key_sum(pen,ks,12,.55))/(#items-1))or 0;local kx=bx
 for _,it in ipairs(items)do local nw,vw=tw(pen,it[1],ks,F.medium,.55),tw(pen,it[2],ks+2,F.title,.55)
  rc(kx,145,7,7,it[3],2);tx(it[1],kx+12,140,nw+2,16,ks,C.muted);tx(it[2],kx+12+nw+5,139,vw+4,17,ks+2,C.value,"left",F.title);kx=kx+key_iw(pen,it,ks,12,.55)+gap end
 rc(bx,166,rw,1,C.rule,1)
 local cx=bx
 for i=1,3 do local cw=rw*CELL_W[i];local px=i>1 and 12 or 0;local v,best=cell(t,i);local label=CELL[i]
  if i>1 then rc(cx,173,1,67,C.rule,1)end
  local ls,lw=14,cw-px-10;if pen.width then while ls>11 and mw(pen,label,ls,F.medium)>lw do ls=ls-1 end end
  tx(label,cx+px,173,lw,16,ls,C.label)
  tx(num(v),cx+px,193,lw,30,28,C.value,"left",F.title)
  if best then tx(best,cx+px,227,lw,15,13,C.muted)end
  cx=cx+cw
 end
 return w,h
end
local function gold(r,f)if f=="coherency"and r.coherency_share then f="coherency_share"end;return r.top[f]and C.gold or C.value end
-- downs and deaths are never gold
local plain={downs=true,deaths=true}
local function name_colour(r)return r.you and C.gold_hi or r.left and C.muted or C.value end
local function class_line(r)return r.class..(r.left and " · Left"or "")end
local function table_rows(pen,x,y,rows)
 local w,h=S.size("squad","table",#rows);box(pen,x,y,w,h,C.frame)
 pen:text("PLAYER",x+30,y+14,200,26,15,C.muted,"left",F.body)
 for _,c in ipairs(COLS)do pen:text(c[1]:upper(),x+c[2]-80,y+14,80,26,15,C.muted,"right",F.body)end
 for i,r in ipairs(rows)do local ry=y+50+(i-1)*58
  pen:rect(x+20,ry,w-40,1,C.rule,1)
  if r.you then pen:rect(x+20,ry+1,w-40,57,C.on,1);pen:rect(x+20,ry+1,4,57,C.gold,2)end
  pen:text(S.cut(r.name,20),x+30,ry+6,290,26,20,name_colour(r),"left",F.body);pen:text(class_line(r),x+30,ry+31,290,20,15,C.muted,"left",F.medium)
  pen:text(S.commas(r.damage),x+320,ry+4,200,32,26,gold(r,"damage"),"right",F.title);bar(pen,x+400,ry+40,120,r.share,r.you and C.gold or C.label)
  for j=2,#COLS do local c=COLS[j];pen:text(S.commas(r[c[3]]),x+c[2]-80,ry,80,58,26,plain[c[3]]and C.value or gold(r,c[3]),"right",F.title)end
 end
 return w,h
end
local function cards(pen,x,y,rows)
 local w,h=S.size("squad","cards",#rows)
 for i,r in ipairs(rows)do local cx=x+(i-1)*240;local cw=230
  box(pen,cx,y,cw,h,r.you and C.gold or C.frame)
  pen:text(S.cut(r.name,16),cx+16,y+12,cw-32,26,20,name_colour(r),"left",F.body);pen:text(class_line(r),cx+16,y+38,cw-32,20,15,C.muted,"left",F.medium)
  pen:text("Damage",cx+16,y+62,cw-32,20,15,C.muted,"left",F.medium)
  pen:text(S.commas(r.damage),cx+16,y+82,cw-32,46,40,gold(r,"damage"),"left",F.title)
  bar(pen,cx+16,y+134,cw-32,r.share,r.you and C.gold or C.label)
  pen:text(string.format("%.0f%% of the squad's damage",100*r.share),cx+16,y+144,cw-32,20,15,C.muted,"left",F.medium)
  pen:rect(cx+16,y+172,cw-32,1,C.rule,1)
  for j,f in ipairs(CARD)do local ry=y+176+(j-1)*26
   pen:text(f[1],cx+16,ry,120,26,17,C.label,"left",F.medium);pen:text(S.commas(r[f[2]]),cx+16,ry,cw-32,26,22,gold(r,f[2]),"right",F.title)
  end
  pen:rect(cx+16,y+258,cw-32,1,C.rule,1)
  pen:text("Downs",cx+16,y+262,90,26,17,C.label,"left",F.medium);pen:text(S.commas(r.downs),cx+16,y+262,90,26,22,C.value,"right",F.title)
  pen:text("Deaths",cx+124,y+262,90,26,17,C.label,"left",F.medium);pen:text(S.commas(r.deaths),cx+124,y+262,cw-140,26,22,C.value,"right",F.title)
 end
 return w,h
end
-- Extra Stats: the Squad Table with a bar of kills by kind along each row and taller Squad Cards, laid out in the approved mockups' units from X0,Y0 and drawn at FS, the scale that fits them to their room.
local KIND={"lesser","elites","specials","monst"}
local KIND_NAME={lesser="Horde",elites="Elites",specials="Specials",monst="Bosses"}
local KIND_COL={lesser=D.rgba(127,145,114),elites=C.gold,specials=C.gold_hi,monst=C.bad}
local INK=D.rgba(11,15,12)
-- field, heading, right edge and width
local BAR_COLS={{"damage","DAMAGE",455,170},{"boss","BOSS DMG",565,105},{"weak","WEAKSPOTS",680,100},{"crit","CRITS",755,75},{"kills","KILLS",835,80},{"downs","DOWNS",905,70},{"deaths","DEATHS",980,75}}
-- a taller card's rows: label, field, top, and the mockup's smaller type for the three new rows or the indent of the kinds of kill under Kills
local CARD_ROWS={{"Boss Dmg","boss",176,"small"},{"Weakspots Hit","weak",202,"small"},{"Critical Hits","crit",228,"small"},{"Kills","kills",262},
 {"Horde","lesser",290,"in"},{"Elites","elites",312,"in"},{"Specials","specials",334,"in"},{"Bosses","monst",356,"in"},
 {"Melee Enemies","melee",386,"in"},{"Ranged Enemies","ranged",408,"in"},{"Downs","downs",446,"half"},{"Deaths","deaths",446,"half2"}}
-- the Support page: Revives, Saves and Time In Coherency, then Attacks Blocked and Dodged, then Blitzes and Abilities Used, Downs and Deaths kept at the foot
local SUPPORT_ROWS={{"Revives","revives",176,"small"},{"Saves","saves",202,"small"},{"Time In Coherency","coherency",228,"small"},
 {"Attacks Blocked","blocked",275},{"Attacks Dodged","dodged",303},{"Blitzes Used","blitzes",365},{"Abilities Used","abilities",393},
 {"Downs","downs",446,"half"},{"Deaths","deaths",446,"half2"}}
local SUPPORT_COLS={{"revives","REVIVES",395,95},{"saves","SAVES",492.5,95},{"coherency","COHERENCY",590,95},{"blocked","BLOCKED",687.5,95},{"dodged","DODGED",785,95},{"blitzes","BLITZES",882.5,95},{"abilities","ABILITIES",980,95}}
-- what each figure counts, shown under the scoreboard while the cursor is over it, one sentence a line
local TIPS={damage={"Damage","Damage dealt to enemies."},boss={"Boss Damage","Damage dealt to Monstrosities and Captains."},
 weak={"Weakspots","Hits that landed on a weakspot."},crit={"Critical Hits","Hits that were critical."},kills={"Kills","Enemies killed."},
 lesser={"Horde","Horde enemies killed, melee and ranged."},elites={"Elites","Elites killed."},specials={"Specials","Specials killed."},
 monst={"Bosses","Monstrosities and Captains killed."},melee={"Melee Enemies","Horde and elite enemies that fight up close, killed."},
 ranged={"Ranged Enemies","Horde and elite enemies that shoot, killed."},downs={"Downs","Times knocked down."},deaths={"Deaths","Times killed."},
 revives={"Revives","Downed teammates helped back up."},
 saves={"Saves","Teammates pulled up from a ledge, cut out of a net or freed after a respawn.","Killing an enemy that has a teammate pinned counts too."},
 coherency={"Time In Coherency","Time spent in coherency with at least one teammate."},blocked={"Attacks Blocked","Enemy attacks blocked."},
 dodged={"Attacks Dodged","Melee attacks dodged."},
 blitzes={"Blitzes Used","Blitzes used.","A teammate's are worked out from their charges, so they can be slightly off."},
 abilities={"Abilities Used","Combat abilities used.","A teammate's are worked out from their charges, so they can be slightly off."}}
local EMPTY={}
-- FX the scale across, which the Squad Table alone may stretch past FS to fill the room it is given, its type kept at FS
local PEN,X0,Y0,FS,FX=nil,0,0,1,1
local CARDS=false
-- the cursor in screen units while it is up, and what is under it this frame: a figure's name, or "kind" with its row and kind
local HP,HIT,HR,HK,HX,HY,HW,HH
-- names and text widths are kept once worked out, so a held scoreboard makes no new strings a frame; each is let go when it grows large
local CUT,PCT,cut_n={}, {},0
local function cut(s,n)
 if cut_n>200 then CUT,cut_n={},0 end
 local by=CUT[n];if not by then by={};CUT[n]=by end;local v=by[s];if not v then v=S.cut(s,n);by[s]=v;cut_n=cut_n+1 end;return v
end
local function pct(k)k=math.floor(100*k+.5);local s=PCT[k];if not s then s=string.format("%d%% of the squad's damage",k);PCT[k]=s end;return s end
local CLK,SHARE,clk_n,share_n={}, {},0,0
local share
local function fig(r,f)
 local v=r[f];if f~="coherency"then return commas(v)end
 if r.coherency_share then return share(math.floor(100*r.coherency_share+.5))end;if v==nil then return DASH end
 v=math.floor(v);local s=CLK[v];if not s then if clk_n>600 then CLK,clk_n={},0 end;s=S.clock(v);CLK[v]=s;clk_n=clk_n+1 end;return s
end
-- a kinds bar part's label, its share of the player's damage first and then its kills, or the share alone
function share(p,kills)
 if share_n>600 then SHARE,share_n={},0 end
 local by=SHARE[p];if not by then by={};SHARE[p]=by end
 local k=kills or false;local s=by[k];if not s then s=kills and p.."%  ·  "..commas(kills)or p.."%";by[k]=s;share_n=share_n+1 end;return s
end
local function width(s,size,font)if not PEN.width then return #s*size*.55 end;return mw(PEN,s,size,font)end
local function R(ax,ay,aw,ah,c,l)PEN:rect(X0+ax*FX,Y0+ay*FS,math.max(1,aw*FX),math.max(1,ah*FS),c,l)end
-- a text too long for its box comes down in size to fit it, as the mockup's do
local function T(s,ax,ay,aw,ah,size,c,align,font)
 local room=aw*FX/FS;local tw=width(s,size,font);if tw>room then size=math.max(9,math.floor(2*size*room/tw)/2)end
 PEN:text(s,X0+ax*FX,Y0+ay*FS,aw*FX,ah*FS,size*FS,c,align,font)
end
local function B(ax,ay,aw,k,fill)R(ax,ay,aw,5,C.track,1);if k>0 then R(ax,ay,math.max(1,aw*math.min(1,k)),5,fill,2)end end
local function hit(ax,ay,aw,ah,key,r,k)
 if not HP then return end
 local x,y=X0+ax*FX,Y0+ay*FS
 if HP.x>=x and HP.x<x+aw*FX and HP.y>=y and HP.y<y+ah*FS then HIT,HR,HK,HX,HY,HW,HH=key,r,k,ax,ay,aw,ah end
end
-- the table's row: the rule above, the player's own tinted with its gold edge, name and class, then the damage with its share and the other figures
local function row_start(r,ry,w)
 R(20,ry,w-40,1,C.rule,1)
 if r.you then R(20,ry+1,w-40,83,C.on,1);R(20,ry+1,4,83,C.gold,2)end
 T(cut(r.name,20),30,ry+6,250,26,20,name_colour(r),"left",F.body);T(class_line(r),30,ry+31,250,20,15,C.muted,"left",F.medium)
end
local function table_row(r,ry,w)
 row_start(r,ry,w)
 local d=BAR_COLS[1];T(commas(r.damage),d[3]-d[4],ry+4,d[4],32,26,gold(r,"damage"),"right",F.title);B(d[3]-120,ry+40,120,r.share,r.you and C.gold or C.label);hit(d[3]-d[4],ry,d[4],52,"damage")
 for j=2,#BAR_COLS do local c=BAR_COLS[j];T(commas(r[c[1]]),c[3]-c[4],ry,c[4],52,24,plain[c[1]]and C.value or gold(r,c[1]),"right",F.title);hit(c[3]-c[4],ry,c[4],52,c[1])end
end
-- the Support page's row: the same start, then a column for each figure
local function support_row(r,ry,w)
 row_start(r,ry,w)
 for _,c in ipairs(SUPPORT_COLS)do T(fig(r,c[1]),c[3]-c[4],ry,c[4],52,24,gold(r,c[1]),"right",F.title);hit(c[3]-c[4],ry,c[4],52,c[1],r)end
end
-- how far the counts too small for their parts run past a bar bw long
local function past(r,bw)
 if r.kind_damage then return 0 end
 local sum,out=0,0;for _,k in ipairs(KIND)do sum=sum+(r[k]or 0)end;if sum<=0 then return 0 end
 for _,k in ipairs(KIND)do local v=r[k]or 0;if v>0 and width(commas(v),13,F.title)+10>bw*v/sum-2 then out=out+width(commas(v),13,F.title)+8 end end
 return out
end
-- one length for every row's kinds bar, out to under Deaths, all of them coming in together only as far as a count after a bar needs;
-- a shorter bar can only push more counts out, so this settles within the four kinds
local function kinds_width(rows,w)
 local full=w-60;local bw=full
 for _=1,5 do local room=full;for _,r in ipairs(rows)do room=math.min(room,full-past(r,bw))end;if bw<=room then break end;bw=math.max(40,room)end
 return bw
end
-- the kinds bar along the foot of a row, each count inside its part or, too small for it, just after the bar
local function kinds_share(r,ry,bw)
 local d=r.kind_damage;local sum=0;for _,k in ipairs(KIND)do sum=sum+(d[k]or 0)end;if sum<=0 then return end
 local cx,sy,sh=30,ry+57,18
 for _,k in ipairs(KIND)do local v=d[k]or 0;local kw=bw*v/sum
  if v>0 then R(cx,sy,math.max(2,kw-2),sh,KIND_COL[k],2);hit(cx,sy,kw,sh,"kind",r,k)
   -- the share and kills inside the part, the share alone where both will not fit, nothing on a sliver
   local p=math.floor(100*v/sum+.5);local t=share(p,r[k]or 0);local tw=width(t,13,F.title)
   if tw+10>kw-2 then t=share(p);tw=width(t,13,F.title)end
   if tw+10<=kw-2 then T(t,cx,sy,kw-2,sh,13,INK,"center",F.title)end
  end
  cx=cx+kw
 end
end
local function kinds(r,ry,bw)
 if r.kind_damage then return kinds_share(r,ry,bw)end
 local sum=0;for _,k in ipairs(KIND)do sum=sum+(r[k]or 0)end;if sum<=0 then return end
 local sx,sy,sh=30,ry+57,18
 local cx,out=sx,sx+bw+8
 for _,k in ipairs(KIND)do local v=r[k]or 0;local kw=bw*v/sum
  if v>0 then R(cx,sy,math.max(2,kw-2),sh,KIND_COL[k],2)
   local t=commas(v);local tw=width(t,13,F.title)
   if tw+10<=kw-2 then T(t,cx,sy,kw-2,sh,13,INK,"center",F.title)else T(t,out,sy,tw+2,sh,13,KIND_COL[k],"left",F.title);out=out+tw+8 end
  end
  cx=cx+kw
 end
end
-- the key, flush right under the table, each kind's squad total beside its name; one wider than the table comes down in size to fit
local function key(t,ky,w)
 local total=0;for i,k in ipairs(KIND)do total=total+(i>1 and 24 or 0)+22+width(KIND_NAME[k],15,F.medium)+8+width(commas(t[k]),16,F.title)end
 local s=math.min(1,(w-60)/total);local kx=w-30-total*s
 for i,k in ipairs(KIND)do if i>1 then kx=kx+24*s end
  R(kx,ky+14-4*s,16*s,8*s,KIND_COL[k],2);kx=kx+22*s
  local lw=width(KIND_NAME[k],15,F.medium)*s;T(KIND_NAME[k],kx,ky,lw+2,28,15*s,C.label,"left",F.medium);kx=kx+lw+8*s
  local v=commas(t[k]);local vw=width(v,16,F.title)*s;T(v,kx,ky,vw+2,28,16*s,C.value,"left",F.title);kx=kx+vw
 end
end
-- Squad Table: Damage, Boss Dmg, Weakspots, Crits, Kills, Downs and Deaths, the kinds bar along each row and the key under them
local function table_extra(rows,page)
 local n=#rows;local w,h=S.size("squad","table",n,nil,true);local support=page=="support"
 box(PEN,X0,Y0,w*FX,h*FS,C.frame)
 T("PLAYER",30,8,200,22,15,C.muted,"left",F.body);T(support and "SUPPORT"or "COMBAT",110,8,120,22,15,C.gold_hi,"left",F.body)
 for _,c in ipairs(support and SUPPORT_COLS or BAR_COLS)do T(c[2],c[3]-c[4],8,c[4],22,15,C.muted,"right",F.body);hit(c[3]-c[4],8,c[4],22,c[1])end
 if support then for i,r in ipairs(rows)do support_row(r,52+(i-1)*84,w)end;return w,h end
 local bw=kinds_width(rows,w);for i,r in ipairs(rows)do local ry=52+(i-1)*84;table_row(r,ry,w);kinds(r,ry,bw)end
 key(rows.totals or EMPTY,52+n*84+10,w)
 return w,h
end
-- a taller card's row: its label, and its figure right-aligned clear of it, coming down in size where both will not fit
local function card_row(r,cx,e)
 local small,inset=e[4]=="small",e[4]=="in"
 -- Downs and Deaths share the last row, a half each
 local half=e[4]=="half"and 0 or e[4]=="half2"and 108
 local lx,lw,lh,ls=cx+16+(inset and 14 or 0)+(half or 0),half and 56 or inset and 118 or 126,inset and 22 or 26,(inset or small)and 15 or 17
 T(e[1],lx,e[3],lw,lh,ls,inset and C.muted or C.label,"left",F.medium)
 local vx=lx+math.min(lw,width(e[1],ls,F.medium))+8
 T(fig(r,e[2]),vx,e[3],(half and lx+90 or cx+214)-vx,lh,inset and 18 or small and 20 or 22,plain[e[2]]and C.value or gold(r,e[2]),"right",F.title)
 hit(lx,e[3],(half and lx+90 or cx+214)-lx,lh,e[2],r)
end
-- Squad Cards: each card grows down with Boss Dmg, Weakspots Hit and Critical Hits, and the kinds of kill under Kills
local function cards_extra(rows,page)
 local w,h=S.size("squad","cards",#rows,nil,true);local support=page=="support"
 for i,r in ipairs(rows)do local cx=(i-1)*240
  box(PEN,X0+cx*FS,Y0,230*FS,h*FS,r.you and C.gold or C.frame)
  T(cut(r.name,16),cx+16,12,198,26,20,name_colour(r),"left",F.body);T(class_line(r),cx+16,38,198,20,15,C.muted,"left",F.medium)
  T("Damage",cx+16,62,198,20,15,C.muted,"left",F.medium);T(support and "SUPPORT"or "COMBAT",cx+16,62,198,20,13,C.muted,"right",F.body)
  T(commas(r.damage),cx+16,82,198,46,40,gold(r,"damage"),"left",F.title);hit(cx+16,62,198,106,"damage")
  B(cx+16,134,198,r.share,r.you and C.gold or C.label);T(pct(r.share),cx+16,144,198,20,15,C.muted,"left",F.medium)
  if support then R(cx+16,172,198,1,C.rule,1);R(cx+16,258,198,1,C.rule,1);R(cx+16,348,198,1,C.rule,1);R(cx+16,438,198,1,C.rule,1)
   for _,e in ipairs(SUPPORT_ROWS)do card_row(r,cx,e)end
  else R(cx+16,172,198,1,C.rule,1);R(cx+16,258,198,1,C.rule,1);R(cx+30,380,184,1,C.track,1);R(cx+16,438,198,1,C.rule,1)
   for _,e in ipairs(CARD_ROWS)do card_row(r,cx,e)end
  end
 end
 return w,h
end
-- a text's words in lines no wider than room, each kept for the next frame
local WRAP=setmetatable({},{__mode="k"})
local function wrap(lines,room)
 local kept=WRAP[lines];if kept and kept.room==room then return kept end
 local out={room=room}
 for i=2,#lines do local line
  for word in lines[i]:gmatch("%S+")do if line and width(line.." "..word,16,F.medium)<=room then line=line.." "..word else if line then out[#out+1]=line end;line=word end end
  if line then out[#out+1]=line end
 end
 WRAP[lines]=out;return out
end
-- a row's own lines, kept on the row for the next frame; the model makes new rows when its figures change
local BUILT=setmetatable({},{__mode="k"})
-- what the figure under the cursor counts, lit where it is and told in a box just under the scoreboard, or over it where there is no room under
local function caption(bw,bh)
 local lines=TIPS[HIT]
 local per=HR and BUILT[HR];if per and HIT=="kind"then per=per.kind end;local key=HIT=="kind"and HK or HIT
 if per and key and per[key]then lines=per[key]else
 local falls=HR and HR.falls or EMPTY
 if HIT=="downs"or HIT=="deaths"then local list={}
  for _,e in ipairs(falls)do local died=e.outcome~="down"
   if HIT=="downs"and e.outcome~="direct_death"or HIT=="deaths"and died then local t=HIT=="deaths"and e.died_t or e.t
    list[#list+1]=(t and S.clock(t).." "or "")..(e.what or "Unknown cause")..(HIT=="downs"and e.outcome=="down_to_death"and ", then died"or "")end end
  if #list>0 then lines={TIPS[HIT][1],unpack(list)}elseif CARDS then lines=nil end
 elseif HIT=="revives"then local list={}
  for _,q in ipairs(HR and HR.lifted or EMPTY)do list[#list+1]=q.name..(q.n>1 and " x"..q.n or "")end
  if #list>0 then lines={"Revived",unpack(list)}elseif CARDS then lines=nil end
 end
 if HIT=="coherency"and HR and HR.coherency_share and HR.tracked then
  lines={"Time In Coherency","The share of their time alive in the mission spent in coherency with at least one teammate.",S.clock(HR.coherency or 0).." of "..S.clock(HR.tracked).."."}
 elseif HIT=="kind"then local d=HR.kind_damage;local sum=0;for _,k in ipairs(KIND)do sum=sum+(d[k]or 0)end
  lines={TIPS[HK]and TIPS[HK][1]or KIND_NAME[HK],math.floor(100*(d[HK]or 0)/math.max(sum,1e-9)+.5).."% of their damage.",commas(HR[HK]or 0).." killed."}end
 if HR and key and lines and lines~=TIPS[HIT]then local all=BUILT[HR]or {};BUILT[HR]=all;if HIT=="kind"then all.kind=all.kind or {};all=all.kind end;all[key]=lines end
 end
 if CARDS and HIT~="downs"and HIT~="deaths"and HIT~="revives"then lines=nil end
 if not lines then return end
 R(HX,HY,HW,HH,C.label_tint,1)
 local cw=math.max(bw,380);local out=wrap(lines,cw-28);local ch=46+#out*22
 local x=math.max(0,math.min((HP.sw or math.huge)-cw,X0));local y=Y0+bh+8
 if HP.sh and y+ch>HP.sh then y=math.max(0,Y0-8-ch)end
 PEN:rect(x,y,cw,ch,C.box);PEN:rect(x,y,3,ch,C.gold,1)
 PEN:text(lines[1],x+14,y+8,cw-28,26,18,C.gold,"left",F.title)
 for i,l in ipairs(out)do PEN:text(l,x+14,y+34+(i-1)*22,cw-28,22,16,C.label,"left",F.medium)end
end
-- the Strip: a row each, its name and class, its headline figure over a bar and a line of figures under it; Combat leads with damage and its
-- share of the squad's, Support with time in coherency. Each figure on the line is its own text, so it can be hovered, and a line too long
-- for the row comes down in size to fit it.
local function strip(rows,seconds,page)
 local w,h=S.size("squad","strip",#rows);local support=page=="support"
 box(PEN,X0,Y0,w*FS,h*FS,C.frame)
 T("Scoreboard",22,12,300,36,28,C.value,"left",F.title)
 local right=w-22
 if seconds then local c=S.clock(seconds);T(c,22,12,w-44,36,18,C.muted,"right",F.medium);right=right-width(c,18,F.medium)-16 end
 if page then T(support and "SUPPORT"or "COMBAT",right-140,12,140,36,15,C.gold_hi,"right",F.body)end
 R(22,54,w-44,1,C.rule,1)
 local list=support and STRIP_SUPPORT or STRIP;local gap=width(" · ",16,F.medium)
 for i,r in ipairs(rows)do local ry=60+(i-1)*72
  if i>1 then R(22,ry,w-44,1,C.rule,1)end
  if r.you then R(10,ry+8,3,58,C.gold,2)end
  PEN:text(cut(r.name,18).."  "..MUTED..class_line(r).."{#reset()}",X0+22*FS,Y0+(ry+6)*FS,300*FS,28*FS,20*FS,name_colour(r),"left",F.body)
  local f,big,k="damage",commas(r.damage),r.share or 0
  if support then f,big,k="coherency",fig(r,"coherency"),r.coherency_share or 0
   T("In Coherency",250,ry+11,w-282-width(big,26,F.title),22,15,C.muted,"right",F.medium)end
  T(big,250,ry+4,w-272,30,26,gold(r,f),"right",F.title);hit(250,ry+2,w-272,34,f,r)
  B(22,ry+38,w-44,k,r.you and C.gold or C.label)
  local total=0
  for j,e in ipairs(list)do local v=r[e[1]];total=total+(j>1 and gap or 0)+width(commas(v),16,F.medium)+5+width(v==1 and e[2]or e[3],16,F.medium)end
  local s=math.min(1,(w-44)/math.max(1,total));local px=22
  for j,e in ipairs(list)do local v=r[e[1]];local vs,ls=commas(v),v==1 and e[2]or e[3]
   if j>1 then T(" · ",px,ry+46,gap*s+2,22,16*s,C.label,"left",F.medium);px=px+gap*s end
   local vw,lw=width(vs,16,F.medium)*s,width(ls,16,F.medium)*s
   T(vs,px,ry+46,vw+2,22,16*s,(not plain[e[1]]and r.top[e[1]])and C.gold or C.value,"left",F.medium)
   T(ls,px+vw+5*s,ry+46,lw+2,22,16*s,C.label,"left",F.medium);hit(px,ry+44,vw+5*s+lw,24,e[1],r)
   px=px+vw+5*s+lw
  end
 end
 return w,h
end
-- extra says Extra Stats is on, f the scale its layouts are drawn at, page "support" for the Support page and hover the cursor, {x,y,sw,sh} in
-- screen units, while it is up; the Strip has no extra figures, but has both pages. wide, for the Squad Table with Extra Stats, is how wide
-- it may run: shrunk to fit its height it keeps that scale up and down and stretches across to wide
function W.squad(pen,layout,x,y,rows,seconds,extra,f,page,hover,wide)
 if layout=="strip"or extra and (layout=="table"or layout=="cards")then
  -- the Squad Cards caption only Downs, Deaths and Revives, with what the card cannot say: when and what, and who
  PEN,X0,Y0,FS,HP,HIT=pen,x,y,f or 1,hover,nil;FX=FS;CARDS=layout=="cards"
  if layout=="table"and wide then FX=math.max(FS,wide/S.size("squad","table",#rows,nil,true))end
  local w,h
  if layout=="strip"then w,h=strip(rows,seconds,page)else w,h=(layout=="table"and table_extra or cards_extra)(rows,page)end
  if HIT then caption(w*FX,h*FS)end;HP,HR=nil,nil
  local dw=w*FX;FX=FS;return dw,h*FS
 end
 if layout=="table"then return table_rows(pen,x,y,rows)end
 return cards(pen,x,y,rows)
end
return W
end
