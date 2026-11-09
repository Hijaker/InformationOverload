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
-- the Support page: Revives, Saves and Time In Coherency, then Attacks Blocked and Dodged, then Blitzes and Abilities Used, Downs and Deaths kept at the foot
local SUPPORT_ROWS={{"Revives","revives",176,"small"},{"Saves","saves",202,"small"},{"Time In Coherency","coherency",228,"small"},
 {"Attacks Blocked","blocked",275},{"Attacks Dodged","dodged",303},{"Blitzes Used","blitzes",365},{"Abilities Used","abilities",393},
 {"Downs","downs",446,"half"},{"Deaths","deaths",446,"half2"}}
local SUPPORT_COLS={{"revives","REVIVES",395,95},{"saves","SAVES",492.5,95},{"coherency","COHERENCY",590,95},{"blocked","BLOCKED",687.5,95},{"dodged","DODGED",785,95},{"blitzes","BLITZES",882.5,95},{"abilities","ABILITIES",980,95}}
-- what each figure counts, shown under the scoreboard while the cursor is over it, one sentence a line
local TIPS={damage={"Damage","Damage dealt to enemies."},boss={"Boss Damage","Damage dealt to Monstrosities and Captains."},
 weak={"Weakspots","Hits that landed on a weakspot."},crit={"Critical Hits","Hits that were critical."},kills={"Kills","Enemies killed."},
 lesser={"Lesser Enemies","Horde enemies killed, melee and ranged."},elites={"Elites","Elites killed."},specials={"Specials","Specials killed."},
 monst={"Monstrosities","Monstrosities and Captains killed."},melee={"Melee Enemies","Lesser and elite enemies that fight up close, killed."},
 ranged={"Ranged Enemies","Lesser and elite enemies that shoot, killed."},downs={"Downs","Times knocked down."},deaths={"Deaths","Times killed."},
 revives={"Revives","Downed teammates helped back up."},
 saves={"Saves","Teammates pulled up from a ledge, cut out of a net or freed after a respawn.","Killing an enemy that has a teammate pinned counts too."},
 coherency={"Time In Coherency","Time spent in coherency with at least one teammate."},blocked={"Attacks Blocked","Enemy attacks blocked."},
 dodged={"Attacks Dodged","Melee attacks dodged."},
 blitzes={"Blitzes Used","Blitzes used.","A teammate's are worked out from their charges, so they can be slightly off."},
 abilities={"Abilities Used","Combat abilities used.","A teammate's are worked out from their charges, so they can be slightly off."}}
local EMPTY={}
local PEN,X0,Y0,FS=nil,0,0,1
-- the cursor in screen units while it is up, and what is under it this frame: a figure's name, or "kind" with its row and kind
local HP,HIT,HR,HK,HX,HY,HW,HH
-- figures, names and text widths are kept once worked out, so a held scoreboard makes no new strings a frame; each is let go when it grows large
local CC,CUT,PCT,cc_n,cut_n={}, {}, {},0,0
local function commas(n)if n==nil then return DASH end;local s=CC[n];if not s then if cc_n>600 then CC,cc_n={},0 end;s=S.commas(n);CC[n]=s;cc_n=cc_n+1 end;return s end
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
local function hit(ax,ay,aw,ah,key,r,k)
 if not HP then return end
 local x,y=X0+ax*FS,Y0+ay*FS
 if HP.x>=x and HP.x<x+aw*FS and HP.y>=y and HP.y<y+ah*FS then HIT,HR,HK,HX,HY,HW,HH=key,r,k,ax,ay,aw,ah end
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
 box(PEN,X0,Y0,w*FS,h*FS,C.frame)
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
-- what the figure under the cursor counts, lit where it is and told in a box just under the scoreboard, or over it where there is no room under
local function caption(bw,bh)
 local lines=TIPS[HIT]
 if HIT=="coherency"and HR and HR.coherency_share and HR.tracked then
  lines={"Time In Coherency","The share of their time alive in the mission spent in coherency with at least one teammate.",S.clock(HR.coherency or 0).." of "..S.clock(HR.tracked).."."}
 elseif HIT=="kind"then local d=HR.kind_damage;local sum=0;for _,k in ipairs(KIND)do sum=sum+(d[k]or 0)end
  lines={TIPS[HK]and TIPS[HK][1]or KIND_NAME[HK],math.floor(100*(d[HK]or 0)/math.max(sum,1e-9)+.5).."% of their damage.",commas(HR[HK]or 0).." killed."}end
 if not lines then return end
 R(HX,HY,HW,HH,C.label_tint,1)
 local cw=math.max(bw,380);local out=wrap(lines,cw-28);local ch=46+#out*22
 local x=math.max(0,math.min((HP.sw or math.huge)-cw,X0));local y=Y0+bh+8
 if HP.sh and y+ch>HP.sh then y=math.max(0,Y0-8-ch)end
 PEN:rect(x,y,cw,ch,C.box);PEN:rect(x,y,3,ch,C.gold,1)
 PEN:text(lines[1],x+14,y+8,cw-28,26,18,C.gold,"left",F.title)
 for i,l in ipairs(out)do PEN:text(l,x+14,y+34+(i-1)*22,cw-28,22,16,C.label,"left",F.medium)end
end
-- extra says Extra Stats is on, f the scale its layouts are drawn at, page "support" for the Support page and hover the cursor, {x,y,sw,sh} in
-- screen units, while it is up; the Strip has no extra figures and no pages
function W.squad(pen,layout,x,y,rows,seconds,extra,f,page,hover)
 if extra and (layout=="table"or layout=="cards")then
  PEN,X0,Y0,FS,HP,HIT=pen,x,y,f or 1,hover,nil
  local w,h=(layout=="table"and table_extra or cards_extra)(rows,page)
  if HIT then caption(w*FS,h*FS)end;HP,HR=nil,nil
  return w*FS,h*FS
 end
 if layout=="table"then return table_rows(pen,x,y,rows)elseif layout=="strip"then return strip(pen,x,y,rows,seconds)end
 return cards(pen,x,y,rows)
end
return W
end
