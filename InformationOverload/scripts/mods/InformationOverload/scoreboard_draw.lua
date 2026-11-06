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
local STRIP={"kills","elites","specials","downs","deaths"}
local parts={}
local function box(pen,x,y,w,h,edge)
 pen:rect(x,y,w,h,C.box)
 pen:rect(x,y,w,2,edge,1);pen:rect(x,y+h-2,w,2,edge,1);pen:rect(x,y,2,h,edge,1);pen:rect(x+w-2,y,2,h,edge,1)
 for _,v in ipairs(CORNERS)do pen:rect(x+v[1]*(w-12),y+v[2]*(h-2),12,2,C.corner,2);pen:rect(x+v[1]*(w-2),y+v[2]*(h-12),2,12,C.corner,2)end
end
local function bar(pen,x,y,w,k,fill)pen:rect(x,y,w,5,C.track,1);if k>0 then pen:rect(x,y,math.max(1,w*math.min(1,k)),5,fill,2)end end
local function num(n)return n and S.commas(n)or DASH end
function W.tm(pen,x,y,t,seconds)
 local rt,rl,ahead=S.record(t,seconds);local w,h=S.size("tm",nil,nil,rt~=nil)
 box(pen,x,y,w,h,C.frame)
 pen:text(S.cut(t.title,46),x+24,y+12,w-48,34,26,C.value,"left",F.title);pen:rect(x+24,y+52,w-48,1,C.rule,1)
 local ay=y+64;local ax,bx,cx=x+24,x+246,x+478
 pen:text("Mission Time",ax,ay,200,24,18,C.label,"left",F.medium)
 pen:text(seconds and S.clock(seconds)or DASH,ax,ay+22,210,80,72,C.value,"left",F.title)
 if t.best_clear then
  bar(pen,ax,ay+112,194,seconds and seconds/t.best_clear or 0,C.label)
  pen:text("Best Clear",ax,ay+122,120,22,16,C.muted,"left",F.medium);pen:text(S.clock(t.best_clear),ax,ay+122,194,22,16,C.gold,"right",F.medium)
 end
 pen:rect(bx-14,ay,1,226,C.rule,1);pen:rect(cx-14,ay,1,226,C.rule,1)
 pen:text("Kill Streak",bx,ay,210,24,18,C.label,"left",F.medium)
 pen:text("Kills Before Taking A Hit",bx,ay+24,210,20,14,C.muted,"left",F.medium)
 pen:text(num(t.streak),bx,ay+44,90,26,24,C.value,"left",F.title)
 if t.streak_best then pen:text("Mission Best "..num(t.streak_best),bx,ay+46,210,22,14,C.gold,"right",F.medium)end
 pen:text("Kills Before Losing Health",bx,ay+72,210,20,14,C.muted,"left",F.medium)
 pen:text(num(t.health_streak),bx,ay+92,90,24,22,C.value,"left",F.title)
 if t.health_streak_best then pen:text("Best "..num(t.health_streak_best),bx,ay+94,210,22,14,C.gold,"right",F.medium)end
 pen:rect(bx,ay+118,210,1,C.rule,1)
 pen:text("Downs",bx,ay+124,210,24,18,C.label,"left",F.medium)
 pen:text(num(t.downs),bx,ay+148,120,50,46,C.value,"left",F.title)
 pen:text("Deaths "..VALUE..t.deaths.."{#reset()}",bx,ay+168,210,22,15,C.muted,"right",F.medium)
 if t.last_down then pen:text("Last: "..S.cut(t.last_down,26),bx,ay+200,210,22,15,C.muted,"left",F.medium)end
 pen:text("Kills",cx,ay,198,24,18,C.label,"left",F.medium)
 pen:text(num(t.kills),cx,ay+24,120,50,46,C.value,"left",F.title)
 if t.kills_best then pen:text("Best Here "..GOLD..S.commas(t.kills_best).."{#reset()}",cx,ay+44,198,22,15,C.muted,"right",F.medium)end
 pen:rect(cx,ay+82,198,1,C.rule,1)
 for i,e in ipairs(t.cats)do local ry=ay+86+(i-1)*28
  pen:text(e[1],cx,ry,140,28,17,C.muted,"left",F.medium);pen:text(S.commas(e[2]),cx,ry,198,28,22,C.value,"right",F.title)
 end
 if rt then local ry=y+h-58
  pen:rect(ax,ry,w-48,40,ahead and C.gold_tint or C.label_tint,1);pen:rect(ax,ry,4,40,ahead and C.gold or C.label,2)
  pen:text(rt,ax+16,ry,210,40,22,ahead and C.gold or C.label,"left",F.title)
  local n,rest=rl:match("^(%S+)(.*)$");pen:text((ahead and GOLD or VALUE)..n.."{#reset()}"..rest,ax+226,ry,w-280,40,18,C.label,"left",F.medium)
 end
 return w,h
end
-- Layout A, in the Tab overlay's top right corner: the game's difficulty icon and the mission, then time, kill streak, downs and kills in one row and the kill kinds under them.
-- f scales it to the slot, cats says whether the kill kinds fit, ic holds the overlay's own difficulty icon; one missing leaves its space empty.
local TAB_COLS={{24,185},{250,148},{439,148},{628,148}}
function W.tab(pen,x,y,t,seconds,f,cats,ic)
 f=f or 1;ic=ic or {}
 local function tx(s,ax,ay,aw,ah,size,c,align,font)pen:text(s,x+ax*f,y+ay*f,aw*f,ah*f,size*f,c,align,font)end
 local function rc(ax,ay,aw,ah,c,l)pen:rect(x+ax*f,y+ay*f,math.max(1,aw*f),math.max(1,ah*f),c,l)end
 local w,h=800*f,(cats and 250 or 204)*f
 box(pen,x,y,w,h,C.frame)
 if ic.difficulty and pen.texture then pen:texture(ic.difficulty,x+24*f,y+16*f,44*f,44*f,C.value)end
 local ix=788
 -- the mission and difficulty keep to one line: the size comes down to fit, then the mission's name is cut
 local base,diff=t.mission or t.title,t.difficulty and t.difficulty:upper();local room,size,n=ix-92,34,24
 local function plain()return S.cut(base,n):upper()..(diff and " · "..diff or "")end
 if pen.width then
  while size>24 and pen:width(plain(),size,F.title)>room do size=size-2 end
  while n>6 and pen:width(plain(),size,F.title)>room do n=n-1 end
 end
 local name=S.cut(base,n):upper();if diff then name=name..MUTED.." · {#reset()}"..diff end
 tx(name,80,14,room,48,size,C.value,"left",F.title);rc(24,62,752,1,C.rule,1)
 local R=75
 for i=1,3 do rc(TAB_COLS[i][1]+TAB_COLS[i][2]+20,R,1,119,C.rule,1)end
 local c=TAB_COLS[1];tx("Mission Time",c[1],R,c[2],24,20,C.label,"left",F.medium);tx(seconds and S.clock(seconds)or DASH,c[1],R+22,c[2],84,72,C.value,"left",F.title)
 local cols={{"Kill Streak",t.streak,"Mission Best",t.streak_best,GOLD},{"Downs",t.downs,"Deaths",t.deaths,VALUE},{"Kills",t.kills,"Best Here",t.kills_best and S.commas(t.kills_best),GOLD}}
 for i,e in ipairs(cols)do c=TAB_COLS[i+1]
  tx(e[1],c[1],R,c[2],24,20,C.label,"left",F.medium);tx(num(e[2]),c[1],R+24,c[2],56,50,C.value,"left",F.title)
  if e[4]then tx(e[3],c[1],R+84,c[2],22,17,C.muted,"left",F.medium);tx(e[5]..e[4].."{#reset()}",c[1],R+84,c[2],22,17,C.muted,"right",F.medium)end
 end
 if cats then rc(24,204,752,1,C.rule,1)
  for i,e in ipairs(t.cats)do tx(e[1].." "..VALUE..S.commas(e[2]).."{#reset()}",24+(i-1)*752/5,210,752/5,26,17,C.muted,i==1 and "left"or i==#t.cats and "right"or "center",F.medium)end
 end
 return w,h
end
local function gold(r,f)return r.top[f]and C.gold or C.value end
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
local function strip(pen,x,y,rows,seconds)
 local w,h=S.size("squad","strip",#rows);box(pen,x,y,w,h,C.frame)
 pen:text("Scoreboard",x+22,y+12,300,36,28,C.value,"left",F.title)
 if seconds then pen:text(S.clock(seconds),x+22,y+12,w-44,36,18,C.muted,"right",F.medium)end
 pen:rect(x+22,y+54,w-44,1,C.rule,1)
 for i,r in ipairs(rows)do local ry=y+60+(i-1)*72
  if i>1 then pen:rect(x+22,ry,w-44,1,C.rule,1)end
  if r.you then pen:rect(x+10,ry+8,3,58,C.gold,2)end
  pen:text(S.cut(r.name,18).."  "..MUTED..class_line(r).."{#reset()}",x+22,ry+6,300,28,20,name_colour(r),"left",F.body)
  pen:text(S.commas(r.damage),x+250,ry+4,w-272,30,26,gold(r,"damage"),"right",F.title)
  bar(pen,x+22,ry+38,w-44,r.share,r.you and C.gold or C.label)
  for j,f in ipairs(STRIP)do parts[j]=((not plain[f]and r.top[f])and GOLD or VALUE)..S.commas(r[f]).."{#reset()} "..f end
  pen:text(table.concat(parts," · "),x+22,ry+46,w-44,22,16,C.label,"left",F.medium)
 end
 return w,h
end
-- Extra Stats: the Squad Table with a bar of kills by kind along each row and taller Squad Cards, laid out in the approved mockups' units from X0,Y0 and drawn at FS, the scale that fits them to their room.
local KIND={"lesser","elites","specials","monst"}
local KIND_NAME={lesser="Lesser",elites="Elites",specials="Specials",monst="Monstrosities"}
local KIND_COL={lesser=D.rgba(127,145,114),elites=C.gold,specials=C.gold_hi,monst=C.bad}
local INK=D.rgba(11,15,12)
-- field, heading, right edge and width
local BAR_COLS={{"damage","DAMAGE",455,170},{"boss","BOSS DMG",565,105},{"weak","WEAKSPOTS",680,100},{"crit","CRITS",755,75},{"kills","KILLS",835,80},{"downs","DOWNS",905,70},{"deaths","DEATHS",980,75}}
-- a taller card's rows: label, field, top, and the mockup's smaller type for the three new rows or the indent of the kinds of kill under Kills
local CARD_ROWS={{"Boss Dmg","boss",176,"small"},{"Weakspots Hit","weak",202,"small"},{"Critical Hits","crit",228,"small"},{"Kills","kills",262},
 {"Lesser Enemies","lesser",290,"in"},{"Elites","elites",312,"in"},{"Specials","specials",334,"in"},{"Monstrosities","monst",356,"in"},
 {"Melee Enemies","melee",386,"in"},{"Ranged Enemies","ranged",408,"in"},{"Downs","downs",446,"half"},{"Deaths","deaths",446,"half2"}}
local EMPTY={}
local PEN,X0,Y0,FS=nil,0,0,1
-- figures, names and text widths are kept once worked out, so a held scoreboard makes no new strings a frame; each is let go when it grows large
local CC,CUT,PCT,cc_n,cut_n={}, {}, {},0,0
local function commas(n)if n==nil then return DASH end;local s=CC[n];if not s then if cc_n>600 then CC,cc_n={},0 end;s=S.commas(n);CC[n]=s;cc_n=cc_n+1 end;return s end
local function cut(s,n)
 if cut_n>200 then CUT,cut_n={},0 end
 local by=CUT[n];if not by then by={};CUT[n]=by end;local v=by[s];if not v then v=S.cut(s,n);by[s]=v;cut_n=cut_n+1 end;return v
end
local function pct(k)k=math.floor(100*k+.5);local s=PCT[k];if not s then s=string.format("%d%% of the squad's damage",k);PCT[k]=s end;return s end
local function width(s,size,font)
 if not PEN.width then return #s*size*.55 end
 local all=PEN.io_widths;if not all or all.n>600 then all={n=0};PEN.io_widths=all end
 local key=PEN.k or 1;local per=all[key];if not per then per={};all[key]=per end
 font=font or F.body;local byf=per[font];if not byf then byf={};per[font]=byf end;local bys=byf[size];if not bys then bys={};byf[size]=bys end
 local v=bys[s];if not v then v=PEN:width(s,size,font);bys[s]=v;all.n=all.n+1 end;return v
end
local function R(ax,ay,aw,ah,c,l)PEN:rect(X0+ax*FS,Y0+ay*FS,math.max(1,aw*FS),math.max(1,ah*FS),c,l)end
-- a text too long for its box comes down in size to fit it, as the mockup's do
local function T(s,ax,ay,aw,ah,size,c,align,font)
 local tw=width(s,size,font);if tw>aw then size=math.max(9,math.floor(2*size*aw/tw)/2)end
 PEN:text(s,X0+ax*FS,Y0+ay*FS,aw*FS,ah*FS,size*FS,c,align,font)
end
local function B(ax,ay,aw,k,fill)R(ax,ay,aw,5,C.track,1);if k>0 then R(ax,ay,math.max(1,aw*math.min(1,k)),5,fill,2)end end
-- the table's row: the rule above, the player's own tinted with its gold edge, name and class, then the damage with its share and the other figures
local function table_row(r,ry,w)
 R(20,ry,w-40,1,C.rule,1)
 if r.you then R(20,ry+1,w-40,83,C.on,1);R(20,ry+1,4,83,C.gold,2)end
 T(cut(r.name,20),30,ry+6,250,26,20,name_colour(r),"left",F.body);T(class_line(r),30,ry+31,250,20,15,C.muted,"left",F.medium)
 local d=BAR_COLS[1];T(commas(r.damage),d[3]-d[4],ry+4,d[4],32,26,gold(r,"damage"),"right",F.title);B(d[3]-120,ry+40,120,r.share,r.you and C.gold or C.label)
 for j=2,#BAR_COLS do local c=BAR_COLS[j];T(commas(r[c[1]]),c[3]-c[4],ry,c[4],52,24,plain[c[1]]and C.value or gold(r,c[1]),"right",F.title)end
end
-- the kinds bar along the foot of a row, each count inside its part or, too small for it, just after the bar; the bar gives way to counts that would run past the box
local function kinds(r,ry,w)
 local sum=0;for _,k in ipairs(KIND)do sum=sum+(r[k]or 0)end;if sum<=0 then return end
 local sx,sy,sh,bw=30,ry+57,18,880
 -- a shorter bar can only push more counts out, so this settles within the four kinds
 for _=1,5 do local out=0
  for _,k in ipairs(KIND)do local v=r[k]or 0;if v>0 and width(commas(v),13,F.title)+10>bw*v/sum-2 then out=out+width(commas(v),13,F.title)+8 end end
  local room=w-12-(sx+8)-out;if bw<=room then break end;bw=math.max(40,room)
 end
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
local function table_extra(rows)
 local n=#rows;local w,h=S.size("squad","table",n,nil,true)
 box(PEN,X0,Y0,w*FS,h*FS,C.frame)
 T("PLAYER",30,8,200,22,15,C.muted,"left",F.body);for _,c in ipairs(BAR_COLS)do T(c[2],c[3]-c[4],8,c[4],22,15,C.muted,"right",F.body)end
 for i,r in ipairs(rows)do local ry=52+(i-1)*84;table_row(r,ry,w);kinds(r,ry,w)end
 key(rows.totals or EMPTY,52+n*84+10,w)
 return w*FS,h*FS
end
-- a taller card's row: its label, and its figure right-aligned clear of it, coming down in size where both will not fit
local function card_row(r,cx,e)
 local small,inset=e[4]=="small",e[4]=="in"
 -- Downs and Deaths share the last row, a half each
 local half=e[4]=="half"and 0 or e[4]=="half2"and 108
 local lx,lw,lh,ls=cx+16+(inset and 14 or 0)+(half or 0),half and 56 or inset and 118 or 126,inset and 22 or 26,(inset or small)and 15 or 17
 T(e[1],lx,e[3],lw,lh,ls,inset and C.muted or C.label,"left",F.medium)
 local vx=lx+math.min(lw,width(e[1],ls,F.medium))+8
 T(commas(r[e[2]]),vx,e[3],(half and lx+90 or cx+214)-vx,lh,inset and 18 or small and 20 or 22,plain[e[2]]and C.value or gold(r,e[2]),"right",F.title)
end
-- Squad Cards: each card grows down with Boss Dmg, Weakspots Hit and Critical Hits, and the kinds of kill under Kills
local function cards_extra(rows)
 local w,h=S.size("squad","cards",#rows,nil,true)
 for i,r in ipairs(rows)do local cx=(i-1)*240
  box(PEN,X0+cx*FS,Y0,230*FS,h*FS,r.you and C.gold or C.frame)
  T(cut(r.name,16),cx+16,12,198,26,20,name_colour(r),"left",F.body);T(class_line(r),cx+16,38,198,20,15,C.muted,"left",F.medium)
  T("Damage",cx+16,62,198,20,15,C.muted,"left",F.medium);T(commas(r.damage),cx+16,82,198,46,40,gold(r,"damage"),"left",F.title)
  B(cx+16,134,198,r.share,r.you and C.gold or C.label);T(pct(r.share),cx+16,144,198,20,15,C.muted,"left",F.medium)
  R(cx+16,172,198,1,C.rule,1);R(cx+16,258,198,1,C.rule,1);R(cx+30,380,184,1,C.track,1);R(cx+16,438,198,1,C.rule,1)
  for _,e in ipairs(CARD_ROWS)do card_row(r,cx,e)end
 end
 return w*FS,h*FS
end
-- extra says Extra Stats is on, f the scale its layouts are drawn at; the Strip has no extra figures
function W.squad(pen,layout,x,y,rows,seconds,extra,f)
 if extra and (layout=="table"or layout=="cards")then PEN,X0,Y0,FS=pen,x,y,f or 1;if layout=="table"then return table_extra(rows)end;return cards_extra(rows)end
 if layout=="table"then return table_rows(pen,x,y,rows)elseif layout=="strip"then return strip(pen,x,y,rows,seconds)end
 return cards(pen,x,y,rows)
end
return W
end
