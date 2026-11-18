-- Information Overload: the End Screen's Record Card as draw ops in the game's UI units, 1920 wide and sh high.
-- E.layout(M,opts) -> {ops,hot,geo,card}. Squad, event, minute and plate indices are 1-based; e.who is a squad index, or below 1 for a player who left.
local E={}
local floor,ceil,max,min,abs=math.floor,math.ceil,math.max,math.min,math.abs
local HUGE=math.huge

local C={world="#18201c",ground="#090d0a",panel="#101611",value="#d8e5cf",body="#a9bf99",dim="#74866c",faint="#4e5e4a",
 frame="#3c4e39",edge="#5c7456",corner="#79886d",gold="#e2c77e",dgold="#c9a25a",sgold="#ddb763",ownname="#ecd6a0",
 rust="#b8604a",grey="#989898",held="#666666",name="#cccccc",acct="#8f8f8f",white="#ffffff"}
local F={pb="proxima_nova_bold",pm="proxima_nova_medium",mm="machine_medium"}
local ICON_EM,ELL,MARGIN=.9,"…",2
local FLOOR={label=1,num=.75,game=.85,player=.85,list=1,more=1}
local ALIGN={start="left",["end"]="right",middle="center"}
E.C,E.F,E.FLOOR,E.ELL,E.MARGIN=C,F,FLOOR,ELL,MARGIN

local function round(x)return floor(x+.5)end
local function Z(n)return round(n*2.2)/2 end
local function isfin(v)return type(v)=="number" and v==v and v~=HUGE and v~=-HUGE end
local function merge(a,b)local o={};for k,v in pairs(a)do o[k]=v end;if b then for k,v in pairs(b)do o[k]=v end end;return o end
-- one table for each colour and opacity, shared by every op drawn in it, so never written to
local COLS={}
local function col(h,op)local k=h..(op or 1);local c=COLS[k];if not c then c={floor((op or 1)*255+.5),tonumber(h:sub(2,3),16),tonumber(h:sub(4,5),16),tonumber(h:sub(6,7),16)};COLS[k]=c end;return c end
local function chars(s)local o={};for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*")do o[#o+1]=ch end;return o end

-- the measure and the player's own squad index, set by each layout
local MEAS,ME
local function W(s,size,font)return MEAS(tostring(s),size,font)end

-- Fitting
local function floorSize(pref,policy)return ceil(pref*FLOOR[policy]*2-1e-9)/2 end
-- drop whole characters from the end until it fits with the ellipsis, then strip trailing spaces, commas and bars
local function cut(s,size,font,room)
 s=tostring(s)
 if W(s,size,font)<=room+1e-6 then return s end
 local cps=chars(s)
 while #cps>1 and W(table.concat(cps)..ELL,size,font)>room+1e-6 do cps[#cps]=nil end
 return (table.concat(cps):gsub("[%s,|]+$",""))..ELL
end
-- labels never change; numbers shrink to 75% and are never cut; game names shrink to 85% and only a synthetic one is cut; player names shrink and then are cut
local function fit(s,pref,font,room,policy,syn)
 s=tostring(s)
 local w0=W(s,pref,font)
 if w0<=room+1e-6 or policy=="label" or policy=="list" or policy=="more" then return {d=s,size=pref}end
 local fl=floorSize(pref,policy)
 local size=max(fl,floor(2*pref*max(0,room)/w0)/2)
 if size>pref then size=pref end
 if W(s,size,font)<=room+1e-6 then return {d=s,size=size}end
 size=fl
 if policy=="num" or (policy=="game" and not syn)then return {d=s,size=size}end
 return {d=cut(s,size,font,room),size=size}
end
local function commas(n)
 if n==nil then return "–"end
 local neg=n<0;local s=string.format("%.0f",round(abs(n)))
 local i=#s-3
 while i>0 do s=s:sub(1,i)..","..s:sub(i+1);i=i-3 end
 return (neg and "-" or "")..s
end
local function clock(s)s=max(0,floor(s));return string.format("%d:%02d",floor(s/60),s%60)end
E.fit,E.cut,E.commas,E.clock,E.floorSize=fit,cut,commas,clock,floorSize

-- Ops
-- layers: plain rects 1, marks 3, a ring's hole 4, text 5; a readout adds 10
local function rect(K,x,y,w,h,fill,op,mark)
 if w<=0 or h<=0 then return end
 K.ops[#K.ops+1]={t="r",x=x,y=y,w=w,h=h,c=col(fill,op),l=K.lay+(mark and 3 or 1)}
end
local function edge(K,x,y,w,h,stroke,op,sw)
 sw=sw or 1
 rect(K,x,y,w,sw,stroke,op);rect(K,x,y+h-sw,w,sw,stroke,op)
 rect(K,x,y+sw,sw,h-2*sw,stroke,op);rect(K,x+w-sw,y+sw,sw,h-2*sw,stroke,op)
end
local function circle(K,cx,cy,r,fill,op,l)K.ops[#K.ops+1]={t="o",x=cx,y=cy,r=r,c=col(fill,op),l=K.lay+(l or 3)}end
local function ring(K,cx,cy,r)circle(K,cx,cy,r,C.value);circle(K,cx,cy,r-2,C.ground,1,4)end
local function diamond(K,cx,cy,r,c)
 for i=0,math.ceil(r*2)-1 do local hw=r-math.abs(i+.5-r);if hw>0 then rect(K,cx-hw,cy-r+i,hw*2,1.5,c,1,true)end end
end
-- the game's own class mark, a glyph in its fonts, read from its UI settings; nil off the game, where the class name stands alone
local function class_glyph(arch)local ok,U=pcall(require,"scripts/settings/ui/ui_settings");local g=ok and type(U)=="table"and U.archetype_font_icon and U.archetype_font_icon[arch];return type(g)=="string"and g~=""and g or nil end
local function corners(K,x,y,w,h,c)
 c=c or C.corner;local a,t=12,2
 for _,q in ipairs({{x,y,1,1},{x+w,y,-1,1},{x,y+h,1,-1},{x+w,y+h,-1,-1}})do
  local cx,cy,sx,sy=q[1],q[2],q[3],q[4]
  rect(K,sx>0 and cx or cx-a,sy>0 and cy or cy-t,a,t,c)
  rect(K,sx>0 and cx or cx-t,sy>0 and cy or cy-a,t,a,c)
 end
end
local function panel(K,x,y,w,h,fill,op,ed,eop,sw)rect(K,x,y,w,h,fill or C.ground,op==nil and .92 or op);edge(K,x,y,w,h,ed or C.edge,eop==nil and 1 or eop,sw or 1)end
local function P(x,y,w,h,name)return {x=x,y=y,w=w,h=h,name=name}end

-- one text fitted to its box less the margin; own: placed by its own width, its box that width and the margin. The op's box is centred
-- 0.35 of the size above the baseline; tx and tw are the drawn text's left and width
local function T(K,o)
 local policy=o.policy or "label"
 local r=o.fitted or fit(o.s,o.size,o.font,o.own and HUGE or o.bw-MARGIN,policy,o.syn)
 local w=W(r.d,r.size,o.font)
 local align=o.align or "start"
 local x=align=="end" and o.bx+o.bw-w or align=="middle" and o.bx+(o.bw-w)/2 or o.bx
 local bx,bw=o.bx,o.bw
 if o.own then bx=align=="end" and x-MARGIN or align=="middle" and x-MARGIN/2 or x;bw=w+MARGIN end
 local t={t="t",s=r.d,full=tostring(o.s),x=bx,y=o.y-1.05*r.size,w=bw,h=1.4*r.size,size=r.size,pref=o.size,font=o.font,c=col(o.fill,o.op),
  align=ALIGN[align],l=K.lay+5,tx=x,tw=w,base=o.y,policy=policy,syn=not not o.syn,key=o.key or tostring(o.s):sub(1,28)}
 if o.meta then for k,v in pairs(o.meta)do t[k]=v end end
 K.ops[#K.ops+1]=t;return t
end
local function Tn(K,s,font,size,fill,x,y,align,policy,extra)
 local w=W(s,size,font)
 return T(K,merge({s=s,font=font,size=size,fill=fill,bx=align=="end" and x-w or x,bw=w,own=true,y=y,align=align or "start",policy=policy or "label"},extra))
end

-- icons in a line of words: ring and dot (downed, died), square (a legend swatch), platform (the account's mark, a square frame)
local function iconW(p)return p.icon=="platform" and ICON_EM*p.size or p.icon=="square" and 13 or 2*p.r end
local function drawIcon(K,p,x,y)
 local cy=y-(p.dy or 5)
 if p.icon=="ring"then ring(K,x+p.r,cy,p.r)
 elseif p.icon=="dot"then circle(K,x+p.r,cy,p.r,C.rust)
 elseif p.icon=="square"then rect(K,x,y-12,13,13,p.fill,p.op,true)
 elseif p.icon=="platform"then
  local s=p.size;local a=s*.62;local bx,by,t,c=x+(ICON_EM*s-a)/2,y-s*.66,a*.3,p.fill or C.acct
  rect(K,bx,by,a,t,c,1,true);rect(K,bx,by+a-t,a,t,c,1,true);rect(K,bx,by+t,t,a-2*t,c,1,true);rect(K,bx+a-t,by+t,t,a-2*t,c,1,true)
 end
end
-- a line of parts {s,font,size,fill,gap,policy,syn,flex,icon}; the one flex part takes the room the rest leave
local function run(K,parts,x,y,right,align)
 local fi
 for i,p in ipairs(parts)do if p.flex then fi=i;break end end
 local pw={}
 for i,p in ipairs(parts)do pw[i]=p.icon and iconW(p) or p.fitted and W(p.fitted.d,p.fitted.size,p.font) or W(p.s,p.size,p.font)end
 local fixed=0
 for i,p in ipairs(parts)do fixed=fixed+(p.gap or 0)+(i==fi and 0 or pw[i])end
 local room=max(0,right-x-fixed)
 local ff
 if fi then local p=parts[fi];ff=fit(p.s,p.size,p.font,room-MARGIN,p.policy or "label",p.syn);pw[fi]=W(ff.d,ff.size,p.font)end
 local total=0
 for i,p in ipairs(parts)do total=total+(p.gap or 0)+pw[i]end
 local cx=align=="end" and right-total or x
 local out={}
 for i,p in ipairs(parts)do
  cx=cx+(p.gap or 0)
  if p.icon then drawIcon(K,p,cx,y)
  elseif i==fi then
   local bx=align=="end" and cx-(room-pw[i]) or cx
   out[#out+1]=T(K,{s=p.s,font=p.font,size=p.size,fill=p.fill,bx=bx,bw=room,y=y,align=align=="end" and "end" or "start",policy=p.policy,syn=p.syn,key=p.key,fitted=ff,op=p.op})
  else out[#out+1]=T(K,{s=p.s,font=p.font,size=p.size,fill=p.fill,bx=cx,bw=pw[i],own=true,y=y,policy=p.policy,syn=p.syn,key=p.key,op=p.op,fitted=p.fitted})end
  cx=cx+pw[i]
 end
 return {right=cx,texts=out,total=total}
end
-- a lead and items of several parts each: as many whole items as fit, the rest "+N More"
local function itemsRun(K,lead,items,x,y,right,gapItem,moreStyle)
 local function wOf(parts)local a=0;for _,p in ipairs(parts)do a=a+(p.gap or 0)+(p.icon and iconW(p) or W(p.s,p.size,p.font))end;return a end
 local wl,wi,n=wOf(lead),{},#items
 for i,it in ipairs(items)do wi[i]=wOf(it)end
 local ms=moreStyle or {font=F.pm,size=Z(15),fill=C.dim}
 local function moreW(m)return W("+"..m.." More",ms.size,ms.font)end
 local k=n
 while k>=1 do
  local t=wl
  for i=1,k do t=t+((i>1 or #lead>0) and gapItem or 0)+wi[i]end
  if k<n then t=t+gapItem+moreW(n-k)end
  if t<=right-x+1e-6 then break end
  k=k-1
 end
 local function first(it,g)local o={};for j,p in ipairs(it)do o[j]=j==1 and merge(p,{gap=g}) or p end;return o end
 local cx=x
 if #lead>0 then cx=run(K,lead,cx,y,right).right end
 if k==0 then
  -- not even one whole: the first item's flex part takes what is left
  k=1
  local more=n>1 and gapItem+moreW(n-1) or 0
  cx=run(K,first(items[1],#lead>0 and gapItem or 0),cx,y,right-more).right
 else
  for i=1,k do cx=run(K,first(items[i],(i>1 or #lead>0) and gapItem or 0),cx,y,right).right end
 end
 if k<n then
  local s="+"..(n-k).." More"
  cx=cx+gapItem+Tn(K,s,ms.font,ms.size,ms.fill,cx+gapItem,y,"start","more",{meta={dropped=n-k}}).tw
 end
 return {k=k,right=cx}
end
-- a game name in up to n lines, greedy by words, coming down half a size at a time to its floor; only a synthetic one is cut
local function wrapText(K,o,maxLines,step)
 local words={}
 for wd in (tostring(o.s).." "):gmatch("(.-) ")do words[#words+1]=wd end
 local room=o.bw-MARGIN
 local function lay(size)
  local lines,line={},""
  for _,wd in ipairs(words)do
   local t=line~="" and line.." "..wd or wd
   if line=="" or W(t,size,o.font)<=room+1e-6 then line=t else lines[#lines+1]=line;line=wd end
  end
  if line~="" then lines[#lines+1]=line end
  return lines
 end
 local fl=floorSize(o.size,o.policy or "game")
 local size,lines=o.size,{tostring(o.s)}
 local function ok(ls)
  if #ls>maxLines then return false end
  for _,l in ipairs(ls)do if W(l,size,o.font)>room+1e-6 then return false end end
  return true
 end
 while not ok(lines) and size-.5>=fl-1e-9 do size=size-.5 end
 if not ok(lines)then size=o.size;lines=lay(size);while not ok(lines) and size-.5>=fl-1e-9 do size=size-.5;lines=lay(size)end end
 local cutLast=false
 if not ok(lines)then
  local keep,rest={},{}
  for i,l in ipairs(lines)do if i<=maxLines-1 then keep[#keep+1]=l else rest[#rest+1]=l end end
  local r=table.concat(rest," ");keep[#keep+1]=r;lines=keep
  if o.syn or o.policy=="player"then lines[#lines]=cut(r,size,o.font,room);cutLast=true end
 end
 for i,l in ipairs(lines)do
  local used=0
  if i>1 then local prev={};for j=1,i-1 do prev[j]=lines[j]end;local _,sp=table.concat(prev," "):gsub(" ","");used=sp+1 end
  local intended=l
  if cutLast and i==#lines then local tail={};for j=used+1,#words do tail[#tail+1]=words[j]end;intended=table.concat(tail," ")end
  T(K,{s=intended,font=o.font,size=o.size,fill=o.fill,bx=o.bx,bw=o.bw,y=o.y+(i-1)*step,policy=o.policy or "game",syn=o.syn,
   fitted={d=l,size=size},key=o.key,meta={wrap={i-1,#lines},full=tostring(o.s)}})
 end
 return #lines
end

-- Place
-- the card fills the end screen above I/O's bar: 60 in from each side, its top 24 down, its foot 110.4 above the screen's, its last 40 the bar
local TOP,FOOT,HEAD=24,110.4,104
local function cardAt(sh)local c={x=60,y=TOP,w=1800,h=(sh or 1080)-FOOT-TOP,bar=40};c.yb=c.y+c.h-c.bar;return c end
local CARD=cardAt(1080)
E.cardAt,E.CARD,E.TOP,E.FOOT=cardAt,CARD,TOP,FOOT
-- the places are written for 16:9's card; a taller card gives what it gains to the body under the first rule, every place and step there grown by k
local function geo(clk,sh)
 local K=cardAt(sh);local x0,x1,T0=K.x+24,K.x+K.w-24,K.y+HEAD;local PH=208;local PY,RW=K.yb-16-PH,500;local rcx=x1-RW
 -- with the clock on the weapons sit in the header, so the body under it starts 56 higher; the card's own box and the right column keep T0
 local Tb=clk and T0-56 or T0
 local hl={x=x0,w=rcx-28-x0};local plates={y=PY,h=PH,gap=10,w=(x1-x0-3*10)/4}
 local kw=568;local ax=x0+kw+48;local aw=hl.x+hl.w-ax
 local B0,r1=CARD.yb-16-PH-CARD.y,clk and 56 or 126
 local k=(PY-Tb-r1)/(B0-r1)
 local function Y(n)if k==1 or n<=r1 then return Tb+n end;return Tb+r1+(n-r1)*k end
 local function S(s)return s*k end
 if clk then
  local ch=k==1 and 220 or PY-12-Y(B0-12-220);local cy=PY-12-ch
  return {clock=true,x0=x0,x1=x1,hl=hl,plates=plates,K=K,k=k,head={y=K.y,h=HEAD,rcx=rcx},card=P(x0-8,T0+8,hl.w+16,cy-4-T0-8,"card"),a={y=Tb+40},
   rule1=Tb+56,kills={x=x0,y=Y(88),w=kw,rows0=Y(120),step=S(38),gap=S(40),mkY=Y(274)},
   armour={x=ax,y=Y(88),w=aw,rows0=Y(112),step=S(26),splitY=Y(244)},
   rule2=Y(298),avg={x=x0,y=Y(328),w=hl.w,rows0=Y(350),step=S(30),last=Y(430)},
   rc={x=rcx,w=RW,hy=T0+42,y0=T0+56,bottom=cy-12},div={x=rcx-14,y0=T0+24,y1=cy-12},
   clk=P(x0,cy,x1-x0,ch,"clock")}
 end
 return {clock=false,x0=x0,x1=x1,hl=hl,plates=plates,K=K,k=k,head={y=K.y,h=HEAD,rcx=rcx},card=P(x0-8,T0+8,hl.w+16,PY-6-T0-8,"card"),a={y=T0+18,dmgSize=Z(44),wx=x0+500},
  rule1=T0+126,kills={x=x0,y=Y(160),w=kw,rows0=Y(194),step=S(44),gap=S(44),mkY=Y(370)},
  armour={x=ax,y=Y(160),w=aw,rows0=Y(186),step=S(30),splitY=Y(340)},
  rule2=Y(394),avg={x=x0,y=Y(426),w=kw,rows0=Y(464),step=S(40),last=Y(648)},dd={x=ax,y=Y(426),w=aw,lanes={Y(518),Y(604)},times=Y(656)},
  rc={x=rcx,w=RW,hy=T0+42,y0=T0+56,bottom=PY-14},div={x=rcx-14,y0=T0+24,y1=PY-14}}
end
E.geo=geo

-- Header
-- the selected operative's portrait, level, name, class and account on the left; the result, date, mission and difficulty mirrored on the right.
-- The portrait is a framed dark square here, the op marked id "portrait" so a real portrait can take its place
-- Beside Name: the two weapons, each the game's own icon at the same size (124 by 46, its 2.7 to 1)
-- stacked down the header, and the two names beside them matched in size and colour; a weapon with no icon loaded keeps its place
local function headerWeapons(K,op,a,b,y)
 -- each icon centred on its own name, the game's art sitting in the middle of its box, so the names come in close
 local sx,sw,ih=a+22,124,46;local nx=sx+sw+6
 for _,ln in ipairs({{"melee",y+46,y+15},{"ranged",y+82,y+51}})do
  local slot,by,iy=ln[1],ln[2],ln[3];local wpn=op.weapons[slot]
  if wpn then
   local mat=op.icons and op.icons[slot]
   if mat then K.ops[#K.ops+1]={t="i",mat=mat,x=sx,y=iy,w=sw,h=ih,c=col(C.body),l=K.lay+4}end
   T(K,{s=wpn.s,font=F.pb,size=Z(22),fill=C.value,bx=nx,bw=b-nx,y=by,policy="game",syn=wpn.syn,key="weapon "..slot})
  end
 end
end
local function header(K,M,G,sel)
 local op,h,x0,x1=M.squad[sel],G.head,G.x0,G.x1;local y=h.y
 local pw=66;local ph,py=pw*200/180,y+16
 -- a saved match has no portrait, so the name and class move left into its place
 if M.no_portrait then pw=-16 else rect(K,x0,py,pw,ph,C.panel);K.ops[#K.ops].id="portrait";edge(K,x0,py,pw,ph,C.edge,1,2)end
 local nx0,mx0=x0+pw+16,G.armour.x;local colR,ns,ny,nc=G.clock and x0+430 or mx0-28,Z(26),y+46,op.own and C.ownname or C.name
 local lvl=tostring(op.lvl or "–");local lw=W(lvl,ns,F.pb)
 Tn(K,lvl,F.pb,ns,nc,nx0,ny,"start","num")
 diamond(K,nx0+lw+8,ny-ns*.35,6.5,nc)
 local nx=nx0+lw+22
 T(K,{s=op.name.s,font=F.pb,size=ns,fill=nc,bx=nx,bw=colR-nx,y=ny,policy="player",syn=op.name.syn,key="card name"})
 local glyph=class_glyph(op.arch);if glyph then Tn(K,glyph,F.pb,Z(18),C.body,nx0,ny+29)end
 local cr=run(K,{{s=op.cls,font=F.pb,size=Z(17),fill=C.body,policy="game",key="card class"}},nx0+22,ny+29,colR)
 if op.acct then run(K,{{icon="platform",size=Z(16)},{s=op.acct.s,font=F.pb,size=Z(16),fill=C.acct,gap=5,flex=true,policy="player",syn=op.acct.syn,key="card account"}},cr.right+22,ny+29,colR)end
 local won=M.result=="won";local res=won and "Mission Won" or "Mission Failed";local ts=Z(15);local cw=27+W(res,ts,F.pb)+14
 local ty,mx=y+22,x1-cw
 rect(K,mx,ty,cw,28,C.value,.05);edge(K,mx,ty,cw,28,C.frame)
 rect(K,mx+cw-19,ty+10,8,8,won and C.value or C.rust,1,true)
 Tn(K,res,F.pb,ts,C.value,mx+14,ty+14+ts*.35)
 run(K,{{s=M.date,font=F.pm,size=ts,fill=C.dim},{s="Mission Debrief",font=F.pm,size=ts,fill=C.dim,gap=14}},mx0,ty+14+ts*.35,mx-14,"end")
 run(K,{{s=M.diff.s,font=F.pb,size=Z(17),fill=C.body,policy="game",syn=M.diff.syn,key="difficulty"},
  {s=M.map.s,font=F.pb,size=Z(28),fill=C.value,policy="game",syn=M.map.syn,flex=true,gap=14,key="mission"}},G.clock and x1-586 or mx0,y+84,x1,"end")
 if G.clock then headerWeapons(K,op,colR+24,x1-600,y)end
 rect(K,x0,y+h.h,x1-x0,1,C.frame)
end

-- Weapons, and with the clock off the damage
local function rowA(K,M,G,sel)
 local op=M.squad[sel];local R=G.hl.x+G.hl.w
 if not G.clock then
  local a,x=G.a,G.hl.x;local vy,bw=a.y+44,a.wx-40-x
  T(K,{s=commas(op.dmg),font=F.mm,size=a.dmgSize,fill=C.value,bx=x-2,bw=bw+2,y=vy,policy="num",key="card damage"})
  rect(K,x,vy+18,bw,7,C.frame,.6,true)
  rect(K,x,vy+18,bw*min(1,op.share or 0),7,C.sgold,1,true)
  Tn(K,op.share and round(op.share*100).."% of team's damage"or "–",F.pm,Z(16),C.body,x,vy+44)
  local wy=a.y+38
  for _,sl in ipairs({{"melee","Melee"},{"ranged","Ranged"}})do
   local wpn=op.weapons[sl[1]]
   if wpn then
    Tn(K,sl[2],F.pm,Z(15),C.dim,a.wx,wy)
    wrapText(K,{s=wpn.s,font=F.pm,size=Z(18),fill=C.body,bx=a.wx+76,bw=R-a.wx-76,y=wy,policy="game",syn=wpn.syn,key="weapon "..sl[1]},1,24)
    wy=wy+34
   end
  end
  return
 end
 if G.clock then return end
 for _,sl in ipairs({{"melee","Melee",G.hl.x,G.armour.x-16},{"ranged","Ranged",G.armour.x,R}})do
  local wpn=op.weapons[sl[1]]
  if wpn then
   local x,r=sl[3],sl[4]
   local lw=Tn(K,sl[2],F.pm,Z(15),C.dim,x,G.a.y).tw
   wrapText(K,{s=wpn.s,font=F.pm,size=Z(18),fill=C.body,bx=x+lw+11,bw=r-x-lw-11,y=G.a.y,policy="game",syn=wpn.syn,key="weapon "..sl[1]},1,24)
  end
 end
end

-- Kills by enemy type, with the player's averages as ticks
local function killsBlock(K,M,G,sel)
 local op,g=M.squad[sel],G.kills;local x=g.x;local R,you=x+g.w,sel==ME
 local tw0=Tn(K,"Kills",F.mm,Z(22),C.value,x,g.y).tw
 T(K,{s=commas(op.kills),font=F.mm,size=Z(22),fill=C.value,align="end",bx=R-132,bw=132,y=g.y,policy="num",key="kills total"})
 local rows=op.kinds;local avg=false
 if you then for _,r in ipairs(rows)do if r[3]~=nil then avg=true end end end
 if avg then
  local lx=x+tw0+24
  rect(K,lx-2,g.y-17,4,20,C.ground,1,true);rect(K,lx-1,g.y-16,2,18,C.value,1,true)
  Tn(K,"Your Average",F.pm,Z(15),C.dim,lx+10,g.y)
 end
 local tx,tw,N=x+108,g.w-230,#rows
 local last=g.mkY-g.gap;local step=N>1 and min(g.step,(last-g.rows0)/(N-1)) or 0
 local top=1
 for _,r in ipairs(rows)do top=max(top,r[2])end
 for i,r in ipairs(rows)do
  local cy=g.rows0+(i-1)*step
  T(K,{s=r[1],font=F.pm,size=Z(17),fill=C.body,bx=x,bw=tx-x-8,y=cy+Z(17)*.35,key="kills row"})
  rect(K,tx,cy-4,tw,8,C.frame,.55,true)
  local hasAvg=avg and r[3]~=nil
  local m,kk=hasAvg and max(r[2],r[3],1e-9) or top,hasAvg and .87 or 1
  if r[2]>0 then rect(K,tx,cy-5,max(1,tw*kk*r[2]/m),10,C.body,1,true)end
  if hasAvg then local ax=tx+tw*kk*r[3]/m;rect(K,ax-2,cy-11,4,22,C.ground,1,true);rect(K,ax-1,cy-10,2,20,C.value,1,true)end
  T(K,{s=commas(r[2]),font=F.mm,size=Z(22),fill=C.value,align="end",bx=tx+tw+9,bw=R-tx-tw-9,y=cy+Z(22)*.36,policy="num",key="kills value"})
 end
 if #op.most>0 then
  local items={}
  for _,mv in ipairs(op.most)do
   items[#items+1]={{s=mv[1],font=F.pb,size=Z(15),fill=C.body,policy="game",syn=false,flex=true,key="most killed"},{s=commas(mv[2]),font=F.mm,size=Z(17),fill=C.value,gap=6,policy="num"}}
  end
  itemsRun(K,{{s="Most Killed",font=F.pm,size=Z(15),fill=C.dim}},items,x,g.mkY,R,13)
 end
end

-- Useful damage by armour and the melee and ranged split
local function armourBlock(K,M,G,sel)
 local op,g=M.squad[sel],G.armour;local x=g.x;local R=x+g.w
 Tn(K,"Damage By Armour",F.mm,Z(22),C.value,x,g.y)
 local rows=op.armour
 if #rows==0 then Tn(K,"No Damage Recorded",F.pm,Z(16),C.dim,x,g.rows0+7);return end
 local barX,barW,pctR,N=x+128,g.w-333,R-126,#rows
 local first=rows[1][2];if first==0 then first=1 end
 local total=0;for _,r in ipairs(rows)do total=total+r[2]end;if total==0 then total=1 end
 local step=N>1 and min(g.step,(g.splitY-16-g.rows0)/(N-1)) or 0
 for i,r in ipairs(rows)do
  local cy=g.rows0+(i-1)*step
  T(K,{s=r[1],font=F.pm,size=Z(16),fill=C.body,bx=x,bw=barX-x-9,y=cy+Z(16)*.35,key="armour row"})
  rect(K,barX,cy-4,max(1,barW*r[2]/first),8,C.body,1,true)
  T(K,{s=round(100*r[2]/total).."%",font=F.pm,size=Z(15),fill=C.dim,align="end",bx=barX+barW+7,bw=pctR-barX-barW-7,y=cy+Z(15)*.35,policy="num",key="armour pct"})
  T(K,{s=commas(r[2]),font=F.mm,size=Z(18),fill=C.value,align="end",bx=pctR+9,bw=R-pctR-9,y=cy+Z(18)*.36,policy="num",key="armour value"})
 end
 local sp=op.split;local st,nz=0,0
 for i=1,4 do local v=sp[i] or 0;st=st+v;if v>0 then nz=nz+1 end end
 if st==0 then st=1 end
 local cols={C.value,C.body,C.faint,C.dim};local avail=g.w-2*max(0,nz-1)
 local sx=x
 for i=1,4 do local ww=avail*(sp[i] or 0)/st;if ww>0 then rect(K,sx,g.splitY,ww,7,cols[i],1,true);sx=sx+ww+2 end end
 local labs={"Melee","Ranged","Damage Over Time","Other"};local items={}
 for i=1,4 do local v=sp[i] or 0;if v>0 then items[#items+1]={{s=labs[i],font=F.pb,size=Z(15),fill=C.body},{s=round(100*v/st).."%",font=F.pm,size=Z(15),fill=C.dim,gap=4,policy="num"}}end end
 if #items>0 then itemsRun(K,{},items,x,g.splitY+31,R,15)end
end

-- Against an average: the player's own past, or a teammate's squad
-- I/O's offset: half the line is twice or none of the average; downs, deaths and disabled flipped
local function avgRow(l,v,mean,pct,flip)
 local d=v-mean;local rel=mean>0 and d/mean or (d>0 and 1 or d<0 and -1 or 0)
 local off=max(-.5,min(.5,rel*.5));if flip then off=-off end
 local delta
 if pct then local pc=round(abs(rel)*100);delta=pc==0 and "Same" or pc.."% "..(d>0 and "More" or "Less")
 else local a=round(abs(d)*10)/10;delta=a==0 and "Same" or (string.format("%.1f",a):gsub("%.0$",""))..(" ")..(d>0 and "More" or "Less")end
 return {l=l,text=commas(v),off=off,good=off>=0 or delta=="Same",delta=delta,v=v,mean=mean}
end
E.avgRow=avgRow
local function disabledOf(o)return o.disabled.pounces+o.disabled.nets+o.disabled.mutant end
local function squadAvg(M,sel)
 local op,n=M.squad[sel],#M.squad
 local fields={{"Damage",function(o)return o.dmg end,true},{"Kills",function(o)return o.kills end,true},{"Boss Damage",function(o)return o.boss end,true},
  {"Downs",function(o)return o.downs end,false},{"Deaths",function(o)return o.deaths end,false},{"Disabled",disabledOf,false}}
 local out={}
 for i,f in ipairs(fields)do
  local v,sum=f[2](op),0
  for _,o in ipairs(M.squad)do sum=sum+f[2](o)end
  out[i]=avgRow(f[1],v,sum/n,f[3],not f[3])
 end
 return out
end
-- damage and kills a minute against the average mission's a minute (a teammate's against the squad's in this mission)
local function rateRows(M,rows,am)
 local mins=M.secs/60
 if not (mins>0 and am and am>0)then return rows end
 local out={}
 for i,r in ipairs(rows)do
  if (r.l=="Damage" or r.l=="Kills") and isfin(r.v) and isfin(r.mean)then
   out[i]=merge(avgRow(r.l,r.v/mins,r.mean/am,true,false),{text=r.l=="Kills" and string.format("%.1f",r.v/mins) or commas(r.v/mins)})
  else out[i]=r end
 end
 return out
end
local function drawAvgRow(K,r,x,cy,w)
 rect(K,x,cy-15,w,1,C.frame,.45)
 T(K,{s=r.l,font=F.pm,size=Z(16),fill=C.body,bx=x,bw=150,y=cy+Z(16)*.35,key="avg label"})
 if r.off~=nil then
  local tx,tw=x+158,122+(w-482)*.5;local mid,me=tx+tw/2,tx+tw*(.5+r.off)
  rect(K,tx,cy-.5,tw,1,C.frame)
  rect(K,min(mid,me),cy-1.5,abs(me-mid),3,r.good and C.value or C.rust,r.good and .45 or .55,true)
  rect(K,mid-1,cy-8,2,16,C.dim,1,true)
  circle(K,me,cy,5.5,r.good and C.value or C.rust)
  local dx=tx+tw+13
  T(K,{s=r.delta,font=F.pm,size=Z(15),fill=r.good and C.value or C.rust,bx=dx,bw=x+w-92-dx,y=cy+Z(15)*.35,policy="num",key="avg delta"})
 end
 T(K,{s=r.text,font=F.mm,size=Z(19),fill=C.value,align="end",bx=x+w-84,bw=84,y=cy+Z(19)*.36,policy="num",key="avg value"})
end
-- a small mark pointing down, stepped from three bars, for the heading that is a switch
local function chevron(K,x,y,c)rect(K,x,y,10,2,c,1,true);rect(K,x+2,y+2,6,2,c,1,true);rect(K,x+4,y+4,2,2,c,1,true)end
local function avgBlock(K,M,G,sel)
 -- on your own card the heading is the switch: Against, then the average it is set against in gold with its mark; a click flips Your
 -- Average and Squad Average. A teammate's card is always against the squad, so its heading is plain words
 local g,own=G.avg,sel==ME;local you=own and not K.squad;local tw
 if own then
  local fs=Z(22);local aw=Tn(K,"Against",F.mm,fs,C.value,g.x,g.y).tw;local sx=g.x+aw+10
  local lw=Tn(K,you and "Your Average" or "Squad Average",F.mm,fs,C.sgold,sx,g.y).tw;local cx=sx+lw+10
  chevron(K,cx,g.y-11,C.sgold);rect(K,sx,g.y+5,lw,1,C.sgold,.5,true)
  K.hot[#K.hot+1]={id="avgswitch",x=sx-4,y=g.y-22,w=lw+24,h=30}
  tw=cx+10-g.x
 else tw=Tn(K,"Against Squad Average",F.mm,Z(22),C.value,g.x,g.y).tw end
 -- the bare Mission Time row is left out: I/O's bar under the card holds the time
 local rates=M.secs>0 and (not you or M.avg.n>0)
 local rows={}
 for _,r in ipairs(you and M.avg.rows or squadAvg(M,sel))do if r.l~="Mission Time"then rows[#rows+1]=r end end
 if rates then
  local rr=rateRows(M,rows,you and M.avg.mins or M.secs/60);local out={}
  for i,r in ipairs(rows)do out[#out+1]=r;if rr[i]~=r then out[#out+1]=merge(rr[i],{l=r.l.." Per Min"})end end
  rows=out
 end
 local asideR,asideL=g.x+g.w,g.x+tw+18
 if you and M.avg.n>0 then run(K,{{s=M.diff.s,font=F.pm,size=Z(15),fill=C.dim,flex=true,policy="game",syn=M.diff.syn,key="avg difficulty"},
  {s=", "..M.avg.n..(M.avg.n==1 and " Mission" or " Missions"),font=F.pm,size=Z(15),fill=C.dim}},asideL,g.y,asideR,"end")end
 if not you then Tn(K,#M.squad.." Operatives",F.pm,Z(15),C.dim,asideR,g.y,"end")end
 -- with the clock on, two columns: damage and kills with their per min, then boss damage, downs, deaths and disabled
 local function idx(l)for i,r in ipairs(rows)do if r.l==l then return i-1 end end;return -1 end
 local c=idx("Boss Damage");if c<1 then c=idx("Downs")end;if c<1 then c=ceil(#rows/2)end
 local cols
 if G.clock then
  local a,b={},{}
  for i,r in ipairs(rows)do if i<=c then a[#a+1]=r else b[#b+1]=r end end
  cols={{g.x,524,a},{g.x+g.w-540,540,b}}
 else cols={{g.x,g.w,rows}}end
 local most=1;for _,cl in ipairs(cols)do most=max(most,#cl[3])end
 local step=min(g.step,(g.last-g.rows0)/max(1,most-1))
 for _,cl in ipairs(cols)do for i,r in ipairs(cl[3])do drawAvgRow(K,r,cl[1],g.rows0+(i-1)*step,cl[2])end end
end

-- Downs and deaths on two lanes (the clock off)
local function hasT(e)return isfin(e.t)end
local function evTimes(e)if e.outcome=="down_to_death" and isfin(e.diedT)then return {e.t,e.diedT}end;return {e.t}end
local function died(e)return e.outcome~="down"end
local function whoOf(M,e)if e.who==ME then return {s="You",syn=false}end;if e.who and e.who>=1 and M.squad[e.who]then return M.squad[e.who].name end;return e.name end
-- the operative's own lane (1) and everyone else's (2); each event at its time when its lane has times, otherwise spread in the order recorded
local function ddGeo(M,G,sel)
 local g,op,you=G.dd,M.squad[sel],sel==ME
 local single=#M.squad==1
 if single then for _,e in ipairs(M.events)do if e.who~=sel then single=false end end end
 local l1,l2=you and "You" or op.name.s,you and "Teammates" or "Others"
 local cw=max(77,min(143,max(W(l1,Z(16),F.pb),single and 0 or W(l2,Z(16),F.pb))))
 local LX=g.x+cw+15;local LW=g.x+g.w-LX
 local function laneOf(e)return (single or e.who==sel) and 1 or 2 end
 local timed,cnt,seen={},{0,0},{0,0}
 for li=1,2 do
  local all=M.secs>0
  for _,e in ipairs(M.events)do if laneOf(e)==li then cnt[li]=cnt[li]+1;if not hasT(e)then all=false end end end
  timed[li]=all
 end
 local function X(t)return LX+6+(LW-12)*max(0,min(1,t/M.secs))end
 local xs={}
 for i,e in ipairs(M.events)do
  local li=laneOf(e)
  if timed[li]then local o={};for j,t in ipairs(evTimes(e))do o[j]=X(t)end;xs[i]=o
  else local k,n=seen[li],cnt[li];seen[li]=k+1;xs[i]={LX+LW*(n==1 and .5 or .076+k*.848/(n-1))}end
 end
 return {LX=LX,LW=LW,lane=single and {(g.lanes[1]+g.lanes[2])/2} or {g.lanes[1],g.lanes[2]},cw=cw,l1=l1,l2=l2,single=single,laneOf=laneOf,timed=timed,xs=xs}
end
local function legend(K,R,y)
 local dw,ow=W("Died",Z(15),F.pm),W("Downed",Z(15),F.pm)
 Tn(K,"Died",F.pm,Z(15),C.dim,R,y,"end")
 circle(K,R-dw-11,y-5.5,5,C.rust)
 Tn(K,"Downed",F.pm,Z(15),C.dim,R-dw-26,y,"end")
 ring(K,R-dw-26-ow-11,y-5.5,5)
 return R-dw-26-ow-18
end
local function ddBlock(K,M,G,sel)
 local g=G.dd;local x=g.x;local R,op,you=x+g.w,M.squad[sel],sel==ME
 Tn(K,"Downs And Deaths",F.mm,Z(22),C.value,x,g.y)
 legend(K,R,g.y)
 local dg=ddGeo(M,G,sel);local LX,LW,lane,cw=dg.LX,dg.LW,dg.lane,dg.cw
 local mine,others={},{}
 for i,e in ipairs(M.events)do if dg.laneOf(e)==1 then mine[#mine+1]=i else others[#others+1]=i end end
 T(K,{s=dg.l1,font=F.pb,size=Z(16),fill=C.body,bx=x,bw=cw,y=lane[1]-3,policy=you and "label" or "player",syn=not you and op.name.syn,key="lane 1"})
 if not dg.single then Tn(K,dg.l2,F.pb,Z(16),C.dim,x,lane[2]-3)end
 for li,es in ipairs(dg.single and {mine} or {mine,others})do
  local dn,dd=0,0
  for _,i in ipairs(es)do local e=M.events[i];if e.outcome=="down"then dn=dn+1 end;if died(e)then dd=dd+1 end end
  run(K,{{icon="ring",r=5,dy=6.5},{s=tostring(dn),font=F.mm,size=Z(18),fill=C.value,gap=4,policy="num"},
   {icon="dot",r=5,dy=6.5,gap=11},{s=tostring(dd),font=F.mm,size=Z(18),fill=C.rust,gap=4,policy="num"}},x,lane[li]+21,x+cw)
 end
 for _,ly in ipairs(lane)do rect(K,LX,ly,LW,1,C.frame,.7)end
 if #M.events==0 then Tn(K,"No Downs Or Deaths",F.pm,Z(15),C.dim,LX+8,lane[1]+(dg.single and -14 or 31))end
 for i,e in ipairs(M.events)do
  local li=dg.laneOf(e);local cy,r,xs=lane[li]+.5,li==2 and 5 or 6,dg.xs[i]
  if #xs==2 then rect(K,xs[1],cy-1.5,xs[2]-xs[1],3,C.rust,.8,true);circle(K,xs[2],cy,r,C.rust);ring(K,xs[1],cy,r)
  elseif not died(e)then ring(K,xs[1],cy,r)
  else circle(K,xs[1],cy,r,C.rust)end
  K.hot[#K.hot+1]={id="event",i=i,x=xs[1]-9,y=cy-9,w=(xs[#xs]-xs[1])+18,h=18,cx=xs[1],cy=cy}
 end
 -- a time over each of the operative's own and its cause under it, a name by each other's, where they have room
 local placed={t={},c={},a={},b={}}
 local function fits(row,a,b)for _,q in ipairs(placed[row])do if not (b+6<=q[1] or a>=q[2]+6)then return false end end;return true end
 local function put(row,a,b)placed[row][#placed[row]+1]={a,b}end
 local order={};for _,i in ipairs(mine)do order[#order+1]=i end;for _,i in ipairs(others)do order[#order+1]=i end
 for _,i in ipairs(order)do
  local e=M.events[i];local own,x0=dg.laneOf(e)==1,dg.xs[i][1]
  if own then
   if dg.timed[1]then
    local ts=clock(e.t);local tw=W(ts,Z(14),F.pm);local ta=max(LX,min(R-tw-MARGIN,x0-tw/2))
    if fits("t",ta,ta+tw)then put("t",ta,ta+tw);T(K,{s=ts,font=F.pm,size=Z(14),fill=C.dgold,bx=ta,bw=tw,own=true,y=lane[1]-15,policy="num",key="lane time"})end
   end
   if e.cause then
    local f=fit(e.cause.s,Z(15),F.pb,209,"game",e.cause.syn);local cwid=W(f.d,f.size,F.pb);local ca=max(LX,min(R-cwid-MARGIN,x0-cwid/2))
    if fits("c",ca,ca+cwid)then put("c",ca,ca+cwid);T(K,{s=e.cause.s,font=F.pb,size=Z(15),fill=C.body,bx=ca,bw=cwid,own=true,y=lane[1]+27,policy="game",syn=e.cause.syn,fitted=f,key="lane cause"})end
   end
  else
   local me=e.who==ME;local nm,pol=whoOf(M,e),me and "label" or "player"
   local f=fit(nm.s,Z(14),F.pm,154,pol,nm.syn);local nw=W(f.d,f.size,F.pm);local na=max(LX,min(R-nw-MARGIN,x0-nw/2))
   for _,ry in ipairs({{"b",lane[2]+26},{"a",lane[2]-14}})do
    if fits(ry[1],na,na+nw)then put(ry[1],na,na+nw);T(K,{s=nm.s,font=F.pm,size=Z(14),fill=C.dim,bx=na,bw=nw,own=true,y=ry[2],policy=pol,syn=nm.syn,fitted=f,key="lane name"});break end
   end
  end
 end
 if #M.events>0 and not dg.timed[1] and not dg.timed[2]then Tn(K,"In Order, No Times Saved",F.pm,Z(14),C.dim,LX,g.times)
 elseif M.secs>0 then Tn(K,"0:00",F.pm,Z(14),C.dim,LX,g.times);Tn(K,clock(M.secs),F.pm,Z(14),C.dim,R,g.times,"end","num")end
 return dg
end

-- Right column: new records and bests, or a teammate's best hits
local SP={
 big={lab=26,fig=77,figSize=Z(46),first=106,step=23,pad=13},
 mid={lab=25,fig=70,figSize=Z(40),first=97,step=23,pad=10},
 small={lab=26,fig=29,first=50,step=23,pad=13},
 tight={lab=25,fig=28,first=50,step=21,pad=7},
}
local function oneLine(kind)return kind=="mid" or kind=="tight" end
local function tail(r,kind)
 if r.how then return {"how"}end
 local out={}
 if r.prev~=nil then out[#out+1]="was"end
 if oneLine(kind)then if r.who or r.mission then out[#out+1]="holder"end
 else if r.who then out[#out+1]="who"end;if r.mission then out[#out+1]="mission"end end
 return out
end
local function tileH(r,kind)local sp=SP[kind];local n=#tail(r,kind);if n>0 then return sp.first+sp.step*(n-1)+sp.pad end;return sp.fig+max(sp.pad,ceil(.22*(sp.figSize or Z(24)))+3)end
-- who held it, where and when on one line: the name gives way first, then the mission down to its floor
local function holderLine(K,r,x,y,R)
 local st={font=F.pm,size=Z(15),fill=C.dim};local sp=W(" ",Z(15),F.pm)
 local date=r.date and {merge(st,{s=", "..r.date})} or {}
 if not r.who then
  local parts={merge(st,{s=r.mission.s,flex=true,policy="game",syn=r.mission.syn,key="record mission"})}
  for _,d in ipairs(date)do parts[#parts+1]=d end
  run(K,parts,x,y,R);return
 end
 local parts={merge(st,{s=r.who.s,flex=true,policy="player",syn=r.who.syn,key="record who"})}
 if r.mission then
  local fixed=sp+W("On",Z(15),F.pm)+sp+(#date>0 and W(date[1].s,Z(15),F.pm) or 0)
  local fl,cps=floorSize(Z(15),"player"),chars(r.who.s)
  local four={};for i=1,min(4,#cps)do four[i]=cps[i]end
  local whoMin=min(W(r.who.s,Z(15),F.pm),W(table.concat(four)..ELL,fl,F.pm))+MARGIN
  local mf=fit(r.mission.s,Z(15),F.pm,R-x-fixed-whoMin-MARGIN,"game",r.mission.syn)
  parts[#parts+1]=merge(st,{s="On",gap=sp});parts[#parts+1]=merge(st,{s=r.mission.s,gap=sp,policy="game",syn=r.mission.syn,key="record mission",fitted=mf})
 end
 for _,d in ipairs(date)do parts[#parts+1]=d end
 run(K,parts,x,y,R)
end
local function entry(K,r,x,y,w,kind)
 local R,gold,sp=x+w,C.dgold,SP[kind]
 if sp.figSize then
  T(K,{s=r.label,font=F.pm,size=Z(17),fill=C.value,bx=x,bw=w,y=y+sp.lab,key="record label"})
  local vr=run(K,{{s=r.value,font=F.mm,size=sp.figSize,fill=gold,policy="num",key="record value"}},x-2,y+sp.fig,R)
  if r.delta then T(K,{s=r.delta,font=F.mm,size=Z(20),fill=gold,bx=vr.right+13,bw=R-vr.right-13,y=y+sp.fig,policy="num",key="record delta"})end
 else
  local vw=W(r.value,Z(24),F.mm);local vb=min(vw,187)
  local v=T(K,{s=r.value,font=F.mm,size=Z(24),fill=gold,align="end",bx=R-vb,bw=vb,own=vw<=187,y=y+sp.fig,policy="num",key="best value"})
  T(K,{s=r.label,font=F.pm,size=Z(17),fill=C.body,bx=x,bw=v.tx-13-x,y=y+sp.lab,key="best label"})
 end
 local ly=y+sp.first
 for _,line in ipairs(tail(r,kind))do
  if line=="how"then T(K,{s=r.how,font=F.pm,size=Z(15),fill=C.body,bx=x,bw=w,y=ly,key="record how"})
  elseif line=="was"then
   local was=run(K,{{s="Was",font=F.pm,size=Z(15),fill=C.dim},{s=r.prev,font=F.mm,size=Z(17),fill=C.body,gap=5,policy="num",key="record was"}},x,ly,R)
   if not sp.figSize and r.delta then T(K,{s=r.delta,font=F.mm,size=Z(17),fill=gold,align="end",bx=was.right+12,bw=R-was.right-12,y=ly,policy="num",key="best delta"})end
  elseif line=="who"then
   local parts={{s=r.who.s,font=F.pm,size=Z(15),fill=C.dim,flex=true,policy="player",syn=r.who.syn,key="record who"}}
   if r.date then parts[2]={s=", "..r.date,font=F.pm,size=Z(15),fill=C.dim}end
   run(K,parts,x,ly,R)
  elseif line=="mission"then T(K,{s=r.mission.s,font=F.pm,size=Z(15),fill=C.dim,bx=x,bw=w,y=ly,policy="game",syn=r.mission.syn,key="record mission"})
  else holderLine(K,r,x,ly,R)end
  ly=ly+sp.step
 end
end
-- this run's biggest hits; one with no hit of its kind has no entry
local function HITS(op)
 local o={}
 for _,h in ipairs({{"Single Target",op.hits.single},{"Melee Cleave",op.hits.cleave},{"Explosion",op.hits.blast}})do if h[2] and h[2]>0 then o[#o+1]=h end end
 return o
end
local function hitsNeed(op)return 48+33*#HITS(op)end
local KINDS_NEED=154
local function hitsPanel(K,op,x,y,w,h)
 local rows,top=HITS(op),33
 if #rows==0 then return end
 panel(K,x,y,w,h,C.panel,.72,C.frame,.55)
 Tn(K,"Biggest Hits",F.pb,Z(15),C.dim,x+18,y+26)
 local x0,w0=x+18,w-36
 local step=min(70,max(33,(h-top-18)/3))
 for i,hv in ipairs(rows)do
  local cy=y+top+8+step*(i-1)+step/2
  rect(K,x0,cy-step/2,w0,1,C.frame,.45)
  T(K,{s=hv[1],font=F.pm,size=Z(17),fill=C.body,bx=x0,bw=176,y=cy+Z(17)*.35,key="hit label"})
  T(K,{s=commas(hv[2]),font=F.mm,size=Z(24),fill=C.dgold,align="end",bx=x0+w0-187,bw=187,y=cy+Z(24)*.36,policy="num",key="hit value"})
 end
end
-- a match from before damage by kind was kept leaves the panel out
local function kindsPanel(K,op,x,y,w,h)
 if not op.kindDmg then return end
 panel(K,x,y,w,h,C.panel,.72,C.frame,.55)
 Tn(K,"Damage By Kind",F.pb,Z(15),C.dim,x+18,y+26)
 local kd=op.kindDmg;local rows={{"Horde",kd.horde},{"Elites",kd.elite},{"Specials",kd.special},{"Bosses",kd.boss}}
 local tot,top=0,1
 for _,r in ipairs(rows)do tot=tot+r[2];top=max(top,r[2])end
 if tot==0 then tot=1 end
 local step=min(77,max(26,(h-48)/#rows))
 for i,r in ipairs(rows)do
  local cy=y+42+step*(i-1)+step/2
  T(K,{s=r[1],font=F.pm,size=Z(16),fill=C.body,bx=x+18,bw=90,y=cy+Z(16)*.35,key="kind label"})
  rect(K,x+118,cy-3.5,165,7,C.frame,.55,true)
  if r[2]>0 then rect(K,x+118,cy-4,max(1,165*r[2]/top),8,C.body,1,true)end
  T(K,{s=round(100*r[2]/tot).."%",font=F.pm,size=Z(15),fill=C.dim,align="end",bx=x+291,bw=54,y=cy+Z(15)*.35,policy="num",key="kind pct"})
  T(K,{s=commas(r[2]),font=F.mm,size=Z(18),fill=C.value,align="end",bx=x+354,bw=w-18-354,y=cy+Z(18)*.36,policy="num",key="kind value"})
 end
end
local function tile(K,x,y,w,h)rect(K,x,y,w,h,C.dgold,.06);edge(K,x,y,w,h,C.dgold,.5);rect(K,x,y,3,h,C.dgold)end
local function rightColumn(K,M,G,sel)
 local g=G.rc;local x,w=g.x,g.w;local R,op,you=x+w,M.squad[sel],sel==ME
 if not you then
  -- a teammate keeps no records or bests here: their biggest hits as tiles, then their damage by kind
  Tn(K,"Biggest Hits",F.mm,Z(22),C.value,x,g.hy)
  local th0,vs=G.clock and 84 or 97,G.clock and Z(34) or Z(40)
  local hits=HITS(op);local fitN=min(#hits,floor((g.bottom-g.y0+10)/(th0+10)))
  local all=fitN==#hits and fitN>0 and g.bottom-g.y0-fitN*(th0+10)-2<KINDS_NEED
  local th=all and min(round(th0*1.4),floor((g.bottom-g.y0+10)/fitN)-10) or th0;local off=(th-th0)/2
  local y=g.y0
  for i=1,fitN do
   local hv=hits[i]
   tile(K,x,y,w,th)
   Tn(K,hv[1],F.pm,Z(17),C.value,x+18,y+off+(G.clock and 24 or 29))
   T(K,{s=commas(hv[2]),font=F.mm,size=vs,fill=C.dgold,bx=x+16,bw=w-34,y=y+th-off-15,policy="num",key="hit value"})
   y=y+th+10
  end
  if fitN<#hits then Tn(K,"+"..(#hits-fitN).." More",F.pm,Z(15),C.dim,R,g.hy,"end","more",{meta={dropped=#hits-fitN,spare=g.bottom-y,nextNeed=th0}})end
  if g.bottom-y-2>=KINDS_NEED then kindsPanel(K,op,x,y+2,w,g.bottom-y-2)end
  return
 end
 local recs,bests=M.records,M.classBests;local R0=#recs
 Tn(K,R0>0 and "New Records" or "No New Records",F.mm,Z(22),C.value,x,g.hy)
 local room,gap,top=g.bottom-g.y0,G.clock and 9 or 11,35
 local lead,row=G.clock and "mid" or "big",G.clock and "tight" or "small"
 -- room is kept for at least one class best: tiles with the figure leading go into rows first, then tiles go into "+N More"
 local needBests=#bests>0 and top+tileH(bests[1],row) or 0
 local function tilesH(k,kind)local a=0;for i=1,k do a=a+tileH(recs[i],kind)+gap end;return a end
 local n=min(3,R0)
 local kind=(n>0 and n<=2 and tilesH(n,lead)+needBests<=room) and lead or row
 while n>0 and tilesH(n,kind)+needBests>room do n=n-1 end
 if R0>n then
  local meta={dropped=R0-n}
  if n<3 then meta.spare=room-tilesH(n,kind)-needBests;meta.nextNeed=tileH(recs[n+1],kind)+gap end
  Tn(K,"+"..(R0-n).." More",F.pm,Z(15),C.dim,R,g.hy,"end","more",{meta=meta})
 end
 local y=g.y0
 for i=1,n do
  local h=tileH(recs[i],kind)
  tile(K,x,y,w,h)
  entry(K,recs[i],x+18,y,w-36,kind)
  y=y+h+gap
 end
 local left=g.bottom-y
 if #bests>0 then
  local k,hh=0,top
  while k<#bests and hh+tileH(bests[k+1],row)<=left do hh=hh+tileH(bests[k+1],row);k=k+1 end
  if k==0 then k=1;hh=hh+tileH(bests[1],row)end
  local hits=#HITS(op)>0 and left-hh-8-12>=max(hitsNeed(op),143)
  local ph=hits and hh+8 or left
  panel(K,x,y,w,ph,C.panel,.72,C.frame,.55)
  Tn(K,op.cls.." Bests",F.pb,Z(15),C.dim,x+18,y+26,"start","game")
  if k<#bests then Tn(K,"+"..(#bests-k).." More",F.pm,Z(15),C.dim,R-18,y+26,"end","more",{meta={dropped=#bests-k,spare=left-hh,nextNeed=tileH(bests[k+1],row)}})end
  local by=y+top
  for i=1,k do rect(K,x+18,by,w-36,1,C.frame,.45);entry(K,bests[i],x+18,by,w-36,row);by=by+tileH(bests[i],row)end
  y=y+ph+12
  if hits then hitsPanel(K,op,x,y,w,g.bottom-y)end
  return
 end
 -- nothing else fell: this run's best hits and damage by kind fill the room
 local rest=g.bottom-y;local hits=#HITS(op)>0;local hh=max(hitsNeed(op),round(rest*.42))
 if hits and rest-hh-12>=KINDS_NEED then hitsPanel(K,op,x,y,w,hh);kindsPanel(K,op,x,y+hh+12,w,rest-hh-12)
 elseif hits and rest>=hitsNeed(op)then hitsPanel(K,op,x,y,w,rest)
 elseif rest>=KINDS_NEED then kindsPanel(K,op,x,y,w,rest)end
end

-- Minute By Minute (the option on): a bar a minute and every down and death
local function niceStep(v)
 local e=10^floor(math.log10(max(v,1e-9)));local m=v/e
 return (m<=1 and 1 or m<=2 and 2 or m<=2.5 and 2.5 or m<=5 and 5 or 10)*e
end
local function trim(v)return (string.format("%.14g",v):gsub("%.0$",""))end
local function kfmt(v)
 if v>=1e6 then return trim(round(v/1e5)/10).."M"end
 return v>=1000 and trim(round(v/100)/10).."K" or tostring(round(v))
end
-- the selected operative's own scale, so their bars fill the band
local function clockScale(M,sel)
 local o=M.squad[sel or ME or 1];local dm,km=1,1
 for _,v in ipairs(o.minutes.dmg)do dm=max(dm,v)end
 for _,v in ipairs(o.minutes.kills)do km=max(km,v)end
 local ds=max(1,niceStep(dm/3))
 return {dmax=ds*3,dstep=ds,kmax=max(5,niceStep(km))}
end
E.clockScale,E.niceStep,E.kfmt=clockScale,niceStep,kfmt
-- 220 high on 16:9's card; a taller panel gives what it gains to the two bands
local function clockGeo(G,M)
 local c=G.clk;local x0,x1,row,bandTop=c.x+66,c.x+c.w-24,c.y+60,c.y+70
 local s=c.h==220 and 1 or (c.h-106)/114;local dh,kh=84*s,30*s
 return {x0=x0,x1=x1,row=row,bandTop=bandTop,dh=dh,kh=kh,ax=bandTop+dh,timeY=s==1 and c.y+206 or bandTop+dh+kh+22,ty=c.y+32,
  X=function(t)return x0+(x1-x0)*max(0,min(1,t/M.secs))end,nmin=ceil(M.secs/60-1e-9)}
end
local function clockStrip(K,M,G,sel)
 local c,op,you,cg,sc=G.clk,M.squad[sel],sel==ME,clockGeo(G,M),clockScale(M,sel)
 panel(K,c.x,c.y,c.w,c.h,C.ground,.94)
 local ty=cg.ty
 local tr=Tn(K,"Minute By Minute",F.mm,Z(22),C.value,c.x+24,ty)
 local lead=run(K,{{icon="square",fill=C.sgold,gap=0},{s="Useful Damage",font=F.pm,size=Z(15),fill=C.dim,gap=9},
  {s=commas(op.dmg),font=F.mm,size=Z(18),fill=C.value,gap=7,policy="num"},
  {icon="square",fill=C.body,op=.8,gap=24},{s="Kills",font=F.pm,size=Z(15),fill=C.dim,gap=8},
  {s=commas(op.kills),font=F.mm,size=Z(18),fill=C.value,gap=7,policy="num"},
  {s="Per Minute",font=F.pm,size=Z(15),fill=C.dim,gap=24}},tr.tx+tr.tw+40,ty,c.x+round(c.w*.53))
 local lg=legend(K,cg.x1,ty)
 local dn,dd=0,0
 for _,e in ipairs(M.events)do if e.who==sel then if e.outcome=="down"then dn=dn+1 end;if died(e)then dd=dd+1 end end end
 run(K,{{s=you and "You" or op.name.s,font=F.pm,size=Z(15),fill=C.dim,flex=not you,policy=you and "label" or "player",syn=not you and op.name.syn,key="clock who"},
  {icon="ring",r=5,gap=8},{s=tostring(dn),font=F.mm,size=Z(18),fill=C.value,gap=4,policy="num"},
  {icon="dot",r=5,gap=10},{s=tostring(dd),font=F.mm,size=Z(18),fill=C.rust,gap=4,policy="num"}},
  max(lead.right+32,c.x+round(c.w*.58)),ty,lg-18,"end")
 local x0,x1,ax,dh,kh,X=cg.x0,cg.x1,cg.ax,cg.dh,cg.kh,cg.X;local PW=x1-x0
 for i=1,3 do
  local y=ax-dh*i/3
  rect(K,x0,y,PW,1,C.frame,.45)
  T(K,{s=kfmt(sc.dstep*i),font=F.pm,size=Z(14),fill=C.dim,align="end",bx=c.x+4,bw=x0-8-c.x-4,y=y+5.5,policy="num",key="clock scale"})
 end
 rect(K,x0,ax+kh,PW,1,C.frame,.45)
 T(K,{s=kfmt(sc.kmax),font=F.pm,size=Z(14),fill=C.dim,align="end",bx=c.x+4,bw=x0-8-c.x-4,y=ax+kh+5.5,policy="num",key="clock kills scale"})
 local n=cg.nmin;local gap,hov=PW/n>14 and 2 or 1.5,K.hover
 -- markers sit inside the minutes, so their hits go in ahead of them to win the hover
 local h0,ne=#K.hot,0
 for k=0,n-1 do
  local a,b=X(k*60),X(min(M.secs,(k+1)*60));local bw=max(1.5,b-a-gap)
  K.mins[k+1]=#K.ops+1
  if hov and hov.kind=="minute" and hov.i==k+1 then rect(K,a,cg.bandTop-4,b-a,dh+kh+8,C.value,.07)end
  local dv,kv=op.minutes.dmg[k+1] or 0,op.minutes.kills[k+1] or 0
  local h=dh*min(1,dv/sc.dmax);if h>0 then rect(K,a+gap/2,ax-h,bw,h,C.sgold,1,true)end
  local hk=kh*min(1,kv/sc.kmax);if hk>0 then rect(K,a+gap/2,ax+1,bw,hk,C.body,.8,true)end
  K.hot[#K.hot+1]={id="minute",i=k+1,x=a,y=cg.bandTop-4,w=b-a,h=dh+kh+8}
 end
 rect(K,x0,ax,PW,1,C.edge)
 -- the clock's times, the end's in full; one that would run into the end's is left out
 local endS=clock(M.secs);local endW=W(endS,Z(15),F.mm)
 local stepT=M.secs>900 and 300 or 120
 local t=0
 while t<M.secs do
  local s=clock(t);local w=W(s,Z(14),F.pm);local a=t==0 and X(t) or X(t)-w/2
  if not (a+w+12>x1-endW)then
   rect(K,X(t),ax+kh,1,6,C.edge,1,true)
   T(K,{s=s,font=F.pm,size=Z(14),fill=C.dim,bx=a,bw=w,own=true,y=cg.timeY,policy="num",key="clock time"})
  end
  t=t+stepT
 end
 rect(K,x1-1,ax+kh,1,6,C.edge,1,true)
 T(K,{s=endS,font=F.mm,size=Z(15),fill=C.value,align="end",bx=x1-endW,bw=endW,own=true,y=cg.timeY,policy="num",key="clock end"})
 -- the selected operative's downs and deaths: the untimed listed at the row's start, each death named at its time
 local taken={}
 local items={}
 for _,e in ipairs(M.events)do
  if not hasT(e) and e.who==sel then
   local nm=whoOf(M,e)
   local ps={{icon=died(e) and "dot" or "ring",r=5,dy=5},{s=nm.s,font=F.pb,size=Z(15),fill=e.who==sel and C.value or C.body,gap=6,flex=e.who~=ME,policy=e.who==ME and "label" or "player",syn=e.who~=ME and nm.syn,key="clock list who"}}
   if e.cause then ps[#ps+1]={s=e.cause.s,font=F.pm,size=Z(15),fill=C.body,gap=6,policy="game",syn=e.cause.syn,key="clock list cause",fitted=fit(e.cause.s,Z(15),F.pm,242-MARGIN,"game",e.cause.syn)}end
   items[#items+1]=ps
  end
 end
 if #items>0 then
  local lr=itemsRun(K,{{s="No Times Saved",font=F.pm,size=Z(15),fill=C.dim}},items,x0,cg.row,x1,18)
  taken[#taken+1]={x0,lr.right}
 end
 local order={}
 for i,e in ipairs(M.events)do if hasT(e) and e.who==sel and died(e)then order[#order+1]=i end end
 table.sort(order,function(a,b)local ta,tb=M.events[a].t,M.events[b].t;if ta~=tb then return ta<tb end;return a<b end)
 for _,i in ipairs(order)do
  local e=M.events[i];local tl=evTimes(e);local dt=tl[#tl];local ex=X(dt)
  local parts={{s=clock(dt),font=F.mm,size=Z(16),fill=C.dgold,policy="num"},{icon="dot",r=5,gap=7,dy=5}}
  if e.cause then parts[#parts+1]={s=e.cause.s,font=F.pm,size=Z(15),fill=C.body,gap=7,policy="game",syn=e.cause.syn,key="clock event cause",room=242}end
  local pf,pw,wd={},{},0
  for j,p in ipairs(parts)do
   if not p.icon then pf[j]=p.room and fit(p.s,p.size,p.font,p.room-MARGIN,p.policy,p.syn) or {d=p.s,size=p.size}end
   pw[j]=p.icon and iconW(p) or W(pf[j].d,pf[j].size,p.font)
   wd=wd+(p.gap or 0)+pw[j]
  end
  local a=ex-1;if a+wd+MARGIN>x1 then a=x1-wd-MARGIN end
  local clash=false
  for _,q in ipairs(taken)do if not (a+wd+12<=q[1] or a>=q[2]+12)then clash=true end end
  if not clash then
   taken[#taken+1]={a,a+wd}
   local cx=a
   for j,p in ipairs(parts)do
    cx=cx+(p.gap or 0)
    if p.icon then drawIcon(K,p,cx,cg.row)
    else T(K,{s=p.s,font=p.font,size=p.size,fill=p.fill,bx=cx,bw=pw[j],own=true,y=cg.row,policy=p.policy or "label",syn=p.syn,fitted=pf[j],key=p.key or "clock event time"})end
    cx=cx+pw[j]
   end
   rect(K,ex-.5,cg.row+6,1,ax-cg.row-6,died(e) and C.rust or C.value,.6,true)
  end
 end
 for i,e in ipairs(M.events)do
  if hasT(e) and e.who==sel then
   local xs={};for j,tt in ipairs(evTimes(e))do xs[j]=X(tt)end
   if #xs==2 then rect(K,xs[1],ax-1,xs[2]-xs[1],3,C.rust,.8,true);circle(K,xs[2],ax+.5,5.5,C.rust);ring(K,xs[1],ax+.5,6)
   elseif not died(e)then ring(K,xs[1],ax+.5,6)
   else circle(K,xs[1],ax+.5,5.5,C.rust)end
   ne=ne+1;table.insert(K.hot,h0+ne,{id="event",i=i,x=xs[1]-9,y=ax-9,w=xs[#xs]-xs[1]+18,h=19,cx=xs[1],cy=ax+.5})
  end
 end
 return cg
end

-- Plates: the held scoreboard's figures
local GRID={{"boss","Boss Dmg"},{"ws","Weakspots Hit","Weakspots"},{"crit","Critical Hits","Crits"},{"downs","Downs"},{"kills","Kills"},
 {"lesser","Horde","Horde"},{"elites","Elites"},{"specials","Specials"},{"monst","Bosses"},{"melee","Melee Enemies"},
 {"ranged","Ranged Enemies"},{"deaths","Deaths"}}
local NO_GOLD={downs=true,deaths=true}
-- for two columns: the damage figures, then the kills and their kinds running on into the second, then downs and deaths at its foot
local ORDER2={"boss","ws","crit","kills","lesser","elites","specials","monst","melee","ranged","downs","deaths"}
local function gridKeys(cols)if cols==2 then return ORDER2 end;local o={};for i,g in ipairs(GRID)do o[i]=g[1]end;return o end
-- each column as wide as its widest label and figure need, the spare shared out; when the figures will not fit even at their floor,
-- labels take their short form, the one that frees the most first
local function gridPlan(M,cols,inner)
 local per,VF,short,keys=12/cols,floorSize(Z(16),"num"),{},gridKeys(cols)
 local byKey={};for _,g in ipairs(GRID)do byKey[g[1]]=g end
 local function lab(key)local g=byKey[key];return short[key] and g[3] or g[2]end
 local vw={}
 for _,g in ipairs(GRID)do for _,size in ipairs({Z(16),VF})do
  local m=-HUGE;for _,o in ipairs(M.squad)do m=max(m,W(commas(o[g[1]]),size,F.mm))end;vw[g[1].."|"..size]=m
 end end
 local function need(size)
  local out={}
  for c=0,cols-1 do
   local m=0
   for r=0,per-1 do local key=keys[c*per+r+1];m=max(m,W(lab(key),Z(14),key=="kills" and F.pb or F.pm)+9+vw[key.."|"..size]+MARGIN)end
   out[c+1]=m
  end
  return out
 end
 local function sum(a)local s=0;for _,v in ipairs(a)do s=s+v end;return s end
 local lo=need(VF)
 while sum(lo)>inner do
  local best,gain=nil,0
  for _,g in ipairs(GRID)do
   if g[3] and not short[g[1]]then short[g[1]]=true;local d=sum(lo)-sum(need(VF));short[g[1]]=nil;if d>gain then gain=d;best=g[1]end end
  end
  if not best then break end
  short[best]=true;lo=need(VF)
 end
 local hi=need(Z(16));local spare=inner-sum(hi)
 local widths={}
 if spare>=0 then
  local share=cols==3 and {127,136,132} or {};if cols~=3 then for c=1,cols do share[c]=1 end end
  local t=sum(share)
  for c,v in ipairs(hi)do widths[c]=v+spare*share[c]/t end
 else
  local want,room=sum(hi)-sum(lo),inner-sum(lo)
  for c,v in ipairs(lo)do widths[c]=v+(want>0 and room*(hi[c]-lo[c])/want or room/cols)end
 end
 return {widths=widths,lab=lab}
end
-- the player's own plate always stands first on the left, the rest in squad order
local function slotOrder(M)
 local own=1
 for i,o in ipairs(M.squad)do if o.own then own=i;break end end
 local o={own}
 for i=1,#M.squad do if i~=own then o[#o+1]=i end end
 return o
end
E.slotOrder,E.gridPlan=slotOrder,gridPlan
-- each plate opens with its operative's name and class; every plate is the size four share the row at, a smaller squad's stood centred as a group
local function plates(K,M,G,sel)
 local g,n=G.plates,#M.squad;local TY,PH,PW=g.y,g.h,g.w
 local X0=G.x0+(G.x1-G.x0-(n*PW+(n-1)*g.gap))/2
 local top={}
 for _,gk in ipairs(GRID)do local m=-HUGE;for _,o in ipairs(M.squad)do m=max(m,o[gk[1]] or 0)end;top[gk[1]]=m end
 do local m=-HUGE;for _,o in ipairs(M.squad)do m=max(m,o.dmg or 0)end;top.dmg=m end
 -- two columns of six on a plate a quarter of the card wide, three of four from 462, six of two from 880
 local cols=PW>=880 and 6 or PW>=462 and 3 or 2
 local per,inner=12/cols,PW-24-(cols-1)*12
 local plan,keys=gridPlan(M,cols,inner),gridKeys(cols)
 local NH=14;local step=cols==2 and 19 or cols==3 and 26 or 31
 local shift=floor((PH-NH-13-(84+(per-1)*step))/2)
 for s,i in ipairs(slotOrder(M))do
  local op=M.squad[i];local x0,on=X0+(s-1)*(PW+g.gap),i==sel
  rect(K,x0,TY,PW,PH,C.ground,.9)
  if on then rect(K,x0,TY,PW,PH,C.sgold,.05)end
  edge(K,x0,TY,PW,PH,on and C.sgold or C.frame,1,2)
  corners(K,x0+4,TY+4,PW-8,PH-8)
  if on then rect(K,x0+2,TY+2,PW-4,4,C.sgold,1,true)end
  local dy=TY+44+NH+shift
  run(K,{{s=commas(op.dmg),font=F.mm,size=Z(28),fill=(op.dmg==top.dmg and top.dmg>0) and C.sgold or C.value,policy="num",key="plate damage"},
   {s=op.share and round(op.share*100).."% of team's damage"or "–",font=F.pm,size=Z(15),fill=C.body,gap=13}},x0+14,dy,x0+PW-14)
  local cw=W(op.cls,Z(13),F.pm)
  T(K,{s=op.name.s,font=F.pb,size=Z(16),fill=op.own and C.ownname or C.name,bx=x0+14,bw=PW-28-cw-12,y=TY+23+shift,policy="player",syn=op.name.syn,key="plate name"})
  Tn(K,op.cls,F.pm,Z(13),C.dim,x0+PW-14,TY+23+shift,"end","game",{key="plate class"})
  rect(K,x0+14,dy+11,PW-28,6,C.frame,.6,true)
  rect(K,x0+14,dy+11,(PW-28)*min(1,op.share or 0),6,op.own and C.sgold or C.body,1,true)
  local gy=dy+40;local lx=x0+12
  for c=0,cols-1 do
   local vr=lx+plan.widths[c+1]
   if c>0 then rect(K,lx-6,gy-15,1,step*per,C.frame,.8)end
   for r=0,per-1 do
    local key=keys[c*per+r+1];local yy=gy+r*step
    local lw2=Tn(K,plan.lab(key),key=="kills" and F.pb or F.pm,Z(14),key=="kills" and C.body or C.dim,lx,yy).tw
    local v=op[key]
    T(K,{s=commas(v),font=F.mm,size=Z(16),fill=(not NO_GOLD[key] and v==top[key] and top[key]>0) and C.sgold or C.value,align="end",
     bx=lx+lw2+9,bw=vr-lx-lw2-9,y=yy+1,policy="num",key="grid "..key})
   end
   lx=vr+12
  end
  K.hot[#K.hot+1]={id="plate",i=i,x=x0,y=TY,w=PW,h=PH}
 end
end

-- Hover readouts: they fit their box and stay inside the card
local function readout(K,M,G,sel,hover,anchor)
 K.lay=10
 local lines={}
 if hover.kind=="minute"then
  local op,k=M.squad[sel],hover.i-1;local a,b=k*60,min(M.secs,(k+1)*60)
  lines[#lines+1]={{s=clock(a).."–"..clock(b),font=F.mm,size=Z(16),fill=C.dgold,policy="num"}}
  lines[#lines+1]={{s="Useful Damage",font=F.pm,size=Z(15),fill=C.dim},{s=commas(op.minutes.dmg[k+1] or 0),font=F.mm,size=Z(18),fill=C.value,gap=8,policy="num"}}
  lines[#lines+1]={{s="Kills",font=F.pm,size=Z(15),fill=C.dim},{s=commas(op.minutes.kills[k+1] or 0),font=F.mm,size=Z(18),fill=C.value,gap=8,policy="num"}}
 elseif anchor.cluster and #anchor.cluster>1 then
  local list={};local allT=true
  for j,i in ipairs(anchor.cluster)do list[j]={e=M.events[i],n=j};if not hasT(M.events[i])then allT=false end end
  if allT then table.sort(list,function(a,b)if a.e.t~=b.e.t then return a.e.t<b.e.t end;return a.n<b.n end)end
  local shownN=#list>5 and 4 or 5;if shownN>#list then shownN=#list end
  for j=1,shownN do
   local e=list[j].e;local nm,ps=whoOf(M,e),{}
   if hasT(e)then ps[#ps+1]={s=clock(e.t),font=F.mm,size=Z(16),fill=C.dgold,policy="num"}end
   ps[#ps+1]={icon=died(e) and "dot" or "ring",r=5,gap=#ps>0 and 8 or 0,dy=5}
   ps[#ps+1]={s=nm.s,font=F.pb,size=Z(15),fill=C.value,gap=7,flex=e.who~=ME,policy=e.who==ME and "label" or "player",syn=e.who~=ME and nm.syn,key="readout who",cap=165}
   if e.cause then ps[#ps+1]={s=e.cause.s,font=F.pm,size=Z(15),fill=C.body,gap=8,policy="game",syn=e.cause.syn,key="readout cause",fitted=fit(e.cause.s,Z(15),F.pm,242-MARGIN,"game",e.cause.syn)}end
   lines[#lines+1]=ps
  end
  if shownN<#list then lines[#lines+1]={{s="+"..(#list-shownN).." More",font=F.pm,size=Z(15),fill=C.dim,policy="more"}}end
 else
  local e=M.events[hover.i];local nm,l1=whoOf(M,e),{}
  if hasT(e)then l1[#l1+1]={s=clock(e.t),font=F.mm,size=Z(16),fill=C.dgold,policy="num"}end
  l1[#l1+1]={s=nm.s,font=F.pb,size=Z(16),fill=C.value,gap=#l1>0 and 8 or 0,flex=e.who~=ME,policy=e.who==ME and "label" or "player",syn=e.who~=ME and nm.syn,key="readout who"}
  lines[#lines+1]=l1
  -- with no cause saved it says only what happened
  local first=e.outcome=="direct_death" and "Died" or "Downed"
  local l2={{s=first,font=F.pb,size=Z(15),fill=first=="Died" and C.rust or C.value}}
  if e.cause then l2[2]={s="By",font=F.pm,size=Z(15),fill=C.dim,gap=5};l2[3]={s=e.cause.s,font=F.pb,size=Z(15),fill=C.body,gap=5,flex=true,policy="game",syn=e.cause.syn,key="readout cause"}end
  lines[#lines+1]=l2
  if e.outcome=="down_to_death"then
   lines[#lines+1]=isfin(e.diedT) and {{s="Died",font=F.pb,size=Z(15),fill=C.rust},{s="At",font=F.pm,size=Z(15),fill=C.dim,gap=5},{s=clock(e.diedT),font=F.mm,size=Z(16),fill=C.dgold,gap=5,policy="num"}}
    or {{s="Died",font=F.pb,size=Z(15),fill=C.rust}}
  end
 end
 local function pwid(p)return p.icon and iconW(p) or p.fitted and W(p.fitted.d,p.fitted.size,p.font) or p.cap and min(p.cap,W(p.s,p.size,p.font)) or W(p.s,p.size,p.font)end
 local widest=-HUGE
 for _,ps in ipairs(lines)do local a=0;for _,p in ipairs(ps)do a=a+(p.gap or 0)+pwid(p)end;widest=max(widest,a+MARGIN)end
 local w=min((anchor.cluster and #anchor.cluster>1) and 528 or 462,max(165,widest+30));local h=24+#lines*24
 local KC=G.K;local lo,hi,top,bot=KC.x+8,KC.x+KC.w-8,KC.y+8,KC.yb-8
 local x=anchor.x-w/2;x=max(lo,min(hi-w,x))
 local y=anchor.y-15-h;if y<top then y=anchor.y+20 end
 y=max(top,min(bot-h,y))
 local rp=P(x,y,w,h,"readout")
 rect(K,x,y,w,h,C.ground,.97);edge(K,x,y,w,h,C.edge,1)
 for i,ps in ipairs(lines)do run(K,ps,x+15,y+28+(i-1)*24,x+w-15)end
 K.lay=0
 return rp
end
-- where a readout points: the minute's bar top, or the marker, with every marker piled within 9 of it on its lane
local function anchorOf(M,G,sel,hv,dd,cg)
 if hv.kind=="minute" and cg then local a,b=cg.X((hv.i-1)*60),cg.X(min(M.secs,(hv.i-1)*60+60));return {x=(a+b)/2,y=cg.bandTop}end
 local e=M.events[hv.i];local cluster={}
 if not e then return nil end
 if cg and hasT(e)then
  local x=cg.X(e.t)
  for i,o in ipairs(M.events)do if hasT(o) and o.who==sel and abs(cg.X(o.t)-x)<=9 then cluster[#cluster+1]=i end end
  return {x=x,y=cg.ax-8,cluster=cluster}
 end
 if not dd then return {x=960,y=540}end
 local li,x=dd.laneOf(e),dd.xs[hv.i][1]
 for i,o in ipairs(M.events)do if dd.laneOf(o)==li and abs(dd.xs[i][1]-x)<=9 then cluster[#cluster+1]=i end end
 return {x=x,y=dd.lane[li]-8,cluster=cluster}
end

local function hoverReadout(K,M,G,sel,hover,dd,cg)local an=anchorOf(M,G,sel,hover,dd,cg);if an and (hover.kind~="minute" or cg)then return readout(K,M,G,sel,hover,an)end end

-- The card
local function begin(M,opts)
 MEAS=opts.measure
 ME=slotOrder(M)[1]
 return max(1,min(#M.squad,opts.sel or ME))
end
-- opts: sh (the UI's height, 1080 if left out), clock, sel (1-based squad index, the player's own if left out), measure(s,size,font), hover {kind="minute"|"event",i}
function E.layout(M,opts)
 opts=opts or {}
 local sel=begin(M,opts)
 -- a match from before the minutes were kept has no clock, and shows its downs and deaths on the lanes
 local clockOk=M.secs>0 and M.squad[sel].minutes~=nil
 local G=geo(opts.clock and clockOk or false,opts.sh)
 local K={ops={},hot={},lay=0,hover=opts.hover,squad=opts.squad==true,mins={}}
 header(K,M,G,sel)
 rowA(K,M,G,sel)
 rect(K,G.hl.x,G.rule1,G.hl.w,1,C.frame)
 killsBlock(K,M,G,sel)
 armourBlock(K,M,G,sel)
 rect(K,G.hl.x,G.rule2,G.hl.w,1,C.frame)
 avgBlock(K,M,G,sel)
 local dd,cg
 if not G.clock then dd=ddBlock(K,M,G,sel) else cg=clockStrip(K,M,G,sel)end
 rect(K,G.div.x,G.div.y0,1,G.div.y1-G.div.y0,C.frame)
 rightColumn(K,M,G,sel)
 plates(K,M,G,sel)
 local pop
 if opts.hover then pop=hoverReadout(K,M,G,sel,opts.hover,dd,cg)end
 local KC=G.K
 return {ops=K.ops,hot=K.hot,card={x=KC.x,y=KC.y,w=KC.w,h=KC.h,yb=KC.yb},sel=sel,own=ME,geo={G=G,dd=dd,cg=cg,mins=K.mins,pop=pop,clockUnavailable=(opts.clock and not clockOk) or false}}
end
-- the card laid out with opts.hover from L, the same card laid out with no hover: the minute's highlight put in among its ops and the readout after them
function E.hover(L,M,opts)
 local sel,g,hv=begin(M,opts),L.geo,opts.hover;local cg,b=g.cg,L.ops
 local K={ops={},hot=L.hot,lay=0};local ops=K.ops
 local at=hv.kind=="minute" and cg and g.mins[hv.i] or #b+1
 for j=1,at-1 do ops[j]=b[j]end
 if at<=#b then
  local a,c=cg.X((hv.i-1)*60),cg.X(min(M.secs,hv.i*60))
  rect(K,a,cg.bandTop-4,c-a,cg.dh+cg.kh+8,C.value,.07)
  local n=#ops;for j=at,#b do n=n+1;ops[n]=b[j]end
 end
 local pop=hoverReadout(K,M,g.G,sel,hv,g.dd,cg)
 return {ops=ops,hot=L.hot,card=L.card,sel=L.sel,own=L.own,geo={G=g.G,dd=g.dd,cg=cg,mins=g.mins,pop=pop,clockUnavailable=g.clockUnavailable}}
end
-- the card's ground, edge and the bar along its foot: Click To Lock while it only hovers, Back once locked, and Full History; opts: sh, measure,
-- mode ("pinned" dims the screen above the game's bar), lit (Back under the mouse), dim (the dim's height), link (false leaves Full History out);
-- gives its ops and hit areas
function E.frame(opts)
 MEAS=opts.measure
 local pinned=opts.mode=="pinned";local K={ops={},hot={},lay=0};local KC=cardAt(opts.sh);local X,Y,Wd,H,B=KC.x,KC.y,KC.w,KC.h,KC.yb
 if pinned then rect(K,-2000,0,6000,opts.dim or (opts.sh or 1080),"#030504",163/255);K.ops[#K.ops].l=-10 end
 rect(K,X,Y,Wd,H,C.ground,1);edge(K,X,Y,Wd,H,pinned and C.edge or C.frame,1,1)
 rect(K,X,B,Wd,1,C.frame);rect(K,X,Y,120,2,C.body,140/255)
 local link,back={X+Wd-16-155,B+3.5,155,33},{X+16,B+4.5,97,31}
 if opts.link==false then link=nil else
  -- the button is as wide as its words and their arrow, framed with the plates' corner marks, gold under the mouse
  local lit=opts.link_lit==true;local tw=W("Full History",17,F.mm);link[3]=24+tw+14+8+20;link[1]=X+Wd-16-link[3]
  rect(K,link[1],link[2],link[3],link[4],lit and C.sgold or C.value,lit and .16 or .05);edge(K,link[1],link[2],link[3],link[4],lit and C.sgold or C.frame,1,1)
  corners(K,link[1]-1,link[2]-1,link[3]+2,link[4]+2,lit and C.sgold or C.corner)
  local mid=link[2]+link[4]/2;local tc=lit and C.value or C.body
  Tn(K,"Full History",F.mm,17,tc,link[1]+24,mid+.33*17)
  local ax=link[1]+24+tw+14;rect(K,ax,mid-4,2,8,tc,1,true);rect(K,ax+2,mid-3,2,6,tc,1,true);rect(K,ax+4,mid-2,2,4,tc,1,true);rect(K,ax+6,mid-1,2,2,tc,1,true)
 end
 if pinned then Tn(K,"[Esc] Back",F.pb,19,opts.lit and "#eeece4" or "#989896",back[1],back[2]+back[4]/2+.33*19)
 else local w=W("Click To Lock",14,F.pm);Tn(K,"Click To Lock",F.pm,14,C.body,X+(Wd-w)/2,B+KC.bar/2+.33*14)end
 return {ops=K.ops,hot={card={X,Y,Wd,H},back=back,link=link}}
end
return E
