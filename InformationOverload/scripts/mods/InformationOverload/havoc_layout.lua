-- Information Overload: the Havoc screen's own parts laid out in the game screen's canvas units, every text measured and fitted to its room.
-- pure: L.layout(model, state, measure) returns {ops, hits, fits}; measure(s, font, size) is the width at that game size
local L={}
local function rgba(r,g,b,a)return {math.floor((a or 1)*255+.5),r,g,b}end
local C={lab=rgba(150,168,148),rule=rgba(88,106,89),white=rgba(182,190,170),grey=rgba(117,136,119),bar=rgba(103,144,103),icon=rgba(152,255,180),gold=rgba(232,198,102),
 lit=rgba(88,106,89,.45),hair=rgba(88,106,89,.6),ggold=rgba(240,196,92),gtext=rgba(214,214,204),gdim=rgba(160,160,150),gpanel=rgba(6,9,8),
 gedge=rgba(200,200,190,.22),io=rgba(0,0,0,.88),blank=rgba(5,7,6),black=rgba(0,0,0),lost=rgba(103,144,103,.35),ts=rgba(196,204,186),
 nomod=rgba(0,0,0,.7),tabon=rgba(88,106,89,.22),tabhv=rgba(88,106,89,.14),tabrest=rgba(88,106,89,0),tabedge=rgba(232,198,102,.45),tabtext=rgba(236,228,206)}
L.C=C
local REG,MED,BOLD,FIG="mono_tide_regular","mono_tide_medium","mono_tide_bold","proxima_nova_bold"
L.font={reg=REG,med=MED,bold=BOLD,body=FIG}
-- the mockup's mono at the game size that matches its widths (mono_tide's mean advance 0.611 em, its bold's 0.603, against Plex Mono's 0.6):
-- 0.98 of the mockup's size for regular and medium, its own size for bold; its body type at its own size
L.PITCH={[REG]=.98,[MED]=.98,[BOLD]=1}
L.R={band={130,96,1147,302},head={130,410,482,70},plate={130,764,482,198},list={624,410,651,245},panel={624,655,651,310},strip={130,977,1147,80}}
-- a mission picture's shape, the threat bars shown before the Also line and the characters fill.js counts it to (a separator after the
-- last name included), the room left-aligned text gets past its column, and the margin a right or centred box gets past its
-- room on the side away from its edge or about its centre, so a drawn width a hair over the measure never wraps
L.PIC,L.BARS,L.ALSO,L.SLACK,L.MARGIN=964/548,8,80,40,4
-- the whole block sits this far left of and up from the rectangles laid out below, so more of the scene shows in the middle
L.SHIFT,L.SHIFT_Y=-54,-20
local DASH,ELL,DOT,TOL="—","…"," · ",1e-7
local ops,hits,fits,ms,memo,REGION,SHADOW
local function gs(font,px)return px*(L.PITCH[font]or 1)end
local function W(s,font,size)local key=font..size..s;local w=memo[key];if not w then w=ms(s,font,size)or 0;memo[key]=w end;return w end
local function space(font,size)return W("x x",font,size)-W("xx",font,size)end
local function rect(x,y,w,h,c,id)if w>0 and h>0 then ops[#ops+1]={k="rect",x=x,y=y,w=w,h=h,c=c,r=REGION,id=id}end end
local function frame(x,y,w,h,t,c,id)ops[#ops+1]={k="frame",x=x,y=y,w=w,h=h,t=t,c=c,r=REGION,id=id}end
local function icon(m,x,y,w,h,c,id)if m then ops[#ops+1]={k="icon",material=m,x=x,y=y,w=w,h=h,c=c,r=REGION,id=id}end end
local function hit(x,y,w,h,key,k,i)hits[#hits+1]={x=x,y=y,w=w,h=h,key=key,act={k=k,i=i}}end
local function fit(full,drawn,why)fits[#fits+1]={s_full=full,s_drawn=drawn,why=why}end
-- trial layouts measure without leaving fits behind
local function undo(n)for k=#fits,n+1,-1 do fits[k]=nil end end
-- a text in its column; left-aligned text gets slack past its room, right and centred text its room and the margin, keeping its right
-- edge or its centre; the box is at least 1.2 of the size tall, kept on the same centre line; text over a picture is shadowed
local function put(s,x,y,w,h,font,size,c,align,room,id)
 if s==nil or s==""then return end
 align=align or "left";room=room or w
 if h<size*1.2 then local nh=size*1.2;y=y-(nh-h)/2;h=nh end
 local bx,bw=x,room
 if align=="left"then bw=room+math.min(L.SLACK,math.max(0,1920-x-room))elseif align=="right"then bw=room+L.MARGIN;bx=x+w-bw else bw=room+L.MARGIN;bx=x+(w-bw)/2 end
 ops[#ops+1]={k="text",s=s,x=bx,y=y,w=bw,h=h,font=font,size=size,c=c,align=align,room=room,r=REGION,id=id,shadow=SHADOW}
end
-- a text cut to its room a whole character at a time, as the panel's _fit does
local function cut(s,font,size,room)
 s=tostring(s or "")
 if s==""or W(s,font,size)<=room+TOL then return s end
 local t=s
 while #t>0 and W(t..ELL,font,size)>room+TOL do t=(t:gsub("[^\128-\191]?[\128-\191]*$",""))end
 repeat local n,m;t,n=t:gsub("[ \t\r\n,|]+$","");t,m=t:gsub("\194\183$","")until n+m==0
 local out=t~=""and t..ELL or ""
 fit(s,out,"cut to "..room);return out
end
-- two texts on one line, a gap apart; the one named by prio keeps its width until the other is down to 40% of the room
local function duo(a,b,x,y,room,h,font,size,ca,cb,gap,prio,ida,idb)
 a,b=tostring(a or ""),tostring(b or "")
 if a==""then put(cut(b,font,size,room),x,y,room,h,font,size,cb,"left",room,idb);return end
 local wa,wb=W(a,font,size),W(b,font,size)
 local ra,rb=wa,wb
 if wa+gap+wb>room then
  if prio==1 then ra=math.min(wa,math.max(room-gap-wb,room*.6));rb=room-gap-ra
  else rb=math.min(wb,math.max(room-gap-wa,room*.6));ra=room-gap-rb end
 end
 a=cut(a,font,size,ra);local da=W(a,font,size)
 put(a,x,y,da,h,font,size,ca,"left",da,ida)
 local bx=x+(a~=""and da+gap or 0);put(cut(b,font,size,x+room-bx),bx,y,x+room-bx,h,font,size,cb,"left",x+room-bx,idb)
end
-- a label at the left and its value at the right of one row; the value keeps its width until the label is down to 40%
local function pair(lab,val,x,y,w,h,font,size,lc,vc,idl,idv)
 lab,val=tostring(lab or ""),tostring(val or "")
 local lw,vw=W(lab,font,size),W(val,font,size)
 local vr=math.min(vw,math.max(w-8-lw,w*.6))
 val=cut(val,font,size,vr);vr=W(val,font,size)
 local lr=w-8-vr
 put(cut(lab,font,size,lr),x,y,lr,h,font,size,lc,"left",lr,idl)
 put(val,x+w-vr,y,vr,h,font,size,vc,"right",vr,idv)
end
-- a word as the pieces a line may break between: Chinese and Japanese break between any two characters, a closing mark kept with the one
-- before it, so a line never starts with one
local CLOSE="\227\128\129\227\128\130\239\188\140\239\188\142\239\188\129\239\188\159\239\188\137\227\128\141\227\128\143\227\128\145\227\128\137\227\128\139"
local function pieces(wd)
 if not wd:find("[\227-\233\239]")then return {wd}end
 local out,was={},false
 for ch in wd:gmatch("[%z\1-\127\194-\244][\128-\191]*")do
  local cjk=ch:find("^[\227-\233]")~=nil or ch:find("^\239[\188-\191]")~=nil
  if #out==0 or (cjk or was)and not CLOSE:find(ch,1,true)then out[#out+1]=ch else out[#out]=out[#out]..ch end
  was=cjk
 end
 return out
end
-- words of mixed runs filled into lines w wide; a run's gap replaces the space after it
local function flow(segs,w)
 local lines,cur,cw={},{},0
 local function nl()lines[#lines+1]=cur;cur={};cw=0 end
 for si,sg in ipairs(segs)do local first=true
  for word in tostring(sg.s or ""):gmatch("[^ \t\r\n]+")do
   for pi,wd in ipairs(pieces(word))do
    local last=cur[#cur]
    if last and last.sg==sg and not first then
     local t=last.s..(pi>1 and ""or " ")..wd;local tw=W(t,sg.font,sg.size)
     if last.x+tw<=w+TOL then last.s,last.w=t,tw;cw=last.x+tw;wd=nil else nl()end
    end
    if wd then
     local ww=W(wd,sg.font,sg.size);local x=0
     if #cur>0 then local p=segs[si-1];x=cw+((first and p and p.gap)or space(sg.font,sg.size));if x+ww>w+TOL then nl();x=0 end end
     if ww>w+TOL then wd=cut(wd,sg.font,sg.size,w);ww=W(wd,sg.font,sg.size)end
     cur[#cur+1]={s=wd,x=x,w=ww,sg=sg};cw=x+ww
    end
    first=false
   end
  end
 end
 if #cur>0 then nl()end
 return lines
end
-- at most max lines; the last one kept ends with an ellipsis
local function clamp(lines,max,w)
 if #lines<=max then return lines end
 local full={};for _,ln in ipairs(lines)do for _,p in ipairs(ln)do full[#full+1]=p.s end end
 local keep={};for i=1,max do keep[i]=lines[i]end
 local ln=keep[max]
 while #ln>0 do local p=ln[#ln];local t=p.s
  while #t>0 and p.x+W(t..ELL,p.sg.font,p.sg.size)>w+TOL do t=(t:gsub("[^\128-\191]?[\128-\191]*$",""))end
  repeat local n;t,n=t:gsub("[ \t\r\n,|]+$","")until n==0
  if t~=""then p.s=t..ELL;p.w=W(p.s,p.sg.font,p.sg.size);break end
  ln[#ln]=nil
 end
 local drawn={};for _,l2 in ipairs(keep)do for _,p in ipairs(l2)do drawn[#drawn+1]=p.s end end
 fit(table.concat(full," "),table.concat(drawn," "),"capped at "..max.." lines");return keep
end
local function lines_put(lines,x,y,lh,id)for j,ln in ipairs(lines)do for _,p in ipairs(ln)do put(p.s,x+p.x,y+(j-1)*lh,p.w,lh,p.sg.font,p.sg.size,p.sg.c,"left",p.w,id..j)end end end
-- a fade as bands of black, each step no more than 3 of 255 in alpha
local function fade(x,y,w,h,stops)
 for i=1,#stops-1 do local a,b=stops[i],stops[i+1];local y0,y1=y+h*a[1],y+h*b[1]
  local n=math.max(1,math.ceil(math.abs(b[2]-a[2])*255/3),math.ceil((y1-y0)/12))
  for k=0,n-1 do local e0,e1=y0+(y1-y0)*k/n,y0+(y1-y0)*(k+1)/n;rect(x,e0,w,e1-e0,rgba(0,0,0,a[2]+(b[2]-a[2])*(k+.5)/n))end end
end
-- a mission picture cropped to cover its box from the middle
local function picture(tex,x,y,w,h)
 if not tex then return end
 local ba,pa=w/h,L.PIC;local u0,v0,u1,v1=0,0,1,1
 if pa>ba then u0=(1-ba/pa)/2;u1=1-u0 else v0=(1-pa/ba)/2;v1=1-v0 end
 ops[#ops+1]={k="picture",texture=tex,x=x,y=y,w=w,h=h,uvs={{u0,v0},{u1,v1}},r=REGION}
end
-- the double chevron, each stroke laid down in small squares close enough to read as one line
local CHEV={{3,4,13,15},{13,15,3,26},{14,4,24,15},{24,15,14,26}}
local function chevron(x,y,id)
 local s=22/30;local ox,t=(26-34*s)/2,3.2*s
 for _,g in ipairs(CHEV)do local n=math.ceil(math.max(math.abs(g[3]-g[1]),math.abs(g[4]-g[2]))*s/.6)
  for i=0,n do rect(x+ox+(g[1]+(g[3]-g[1])*i/n)*s-t/2,y+(g[2]+(g[4]-g[2])*i/n)*s-t/2,t,t,C.icon,id)end end
end
local function pl(n,one,many)return n.." "..(n==1 and one or many)end
local function wl(w,l)return (w or 0).." Won, "..(l or 0).." Lost"end
local function pct(a,b)if not b or b<=0 then return nil end;return math.floor((a or 0)/b*100+.5)end
local function dec(x,n)local k=10^n;return string.format("%."..n.."f",math.floor(x*k+.5)/k)end
local function join(t,sep)local o={};for _,v in ipairs(t)do if v~=nil and v~=""then o[#o+1]=tostring(v)end end;return table.concat(o,sep)end
local function rankup(rank,mine,top)if not rank or not mine or mine>=(top or 40)then return 0 end;local g=rank-mine;return g>=10 and 3 or g>=6 and 2 or g>=0 and 1 or 0 end
local function wintext(u)if u>0 then return "Win: +"..u..(u==1 and " Rank"or " Ranks")end;return "No Rank Up"end
local function runs_of(rec)return rec and rec.runs or 0 end
-- the standing under a name: this week's best, or the season's where the week is not known, as the model marks it
local function standing(p,label)if (p.sub or 0)>0 then return (p.when or label)..": "..p.sub end;return "None This Season"end
-- one button: a frame round its words, gold when pressed; tw is the room its words were given
local function button(s,x,y,w,tw,key,on,hv)
 local z=gs(MED,12)
 if on then rect(x,y,w,24,C.gold,key);frame(x,y,w,24,1,C.gold,key)else rect(x,y,w,24,C.black,key);frame(x,y,w,24,1,hv==key and C.white or C.rule,key)end
 put(cut(s,MED,z,tw),x+(w-tw)/2,y,tw,24,MED,z,on and C.black or C.white,"center",tw,key)
end
-- the post button at the right end of a tile's Win line: a speech bubble in a frame, gold with the post just sent, grey while it waits to
-- post again, and a click target only while it can post
local function post(x,y,k,st)
 local s=(st.posted or {})[k];local key="post"..k
 local c=s=="done"and C.gold or s=="wait"and C.grey or C.white
 rect(x,y,20,20,C.black,key);frame(x,y,20,20,1,s=="done"and C.gold or (not s and st.hover==key)and C.white or C.rule,key)
 frame(x+4,y+5,12,8,1.5,c,key..".bubble");rect(x+6,y+12.5,3,3,c,key..".tail")
 if not s then hit(x,y,20,20,key,"post",k)end
end
local function bw_of(s)local tw=math.min(W(s,MED,gs(MED,12)),114.4);return tw+25.6,tw end

-- the Strike Team: a tile each across the row, the one shown pressed, a vote under each that runs the mod; two or three tiles show the
-- modifiers by name, two lay their records side by side under the alone tile's lighter fade
local TX,TY,TW,TH,CW=139.6,105.6,275.9,282.8,250.4
local TEAMFADE,SOLOFADE={{0,.3},{.38,.55},{.62,.9},{1,1}},{{0,.5},{.35,.2},{.55,.25},{1,.78}}
-- each tile's voters by name, in party order
local function tally(model)
 local who={}
 for k,l in pairs(model.votes or {})do local t={};for _,j in ipairs(l)do local p=model.players[j];if p then t[#t+1]=p.who or ""end end;who[k]=t end
 return who
end
local function tile(model,st,k,who)
 local p=model.players[k];if not p then return end
 local n=math.min(4,#model.players);local TW=(4*TW+(4-n)*8.05)/n;local CW=TW-25.5
 local x=TX+(TW+8.05)*(k-1);local cx=x+12.8;local a=p.a;local key="tile"..k
 local z14=gs(BOLD,14)
 if a then picture(a.texture,x,TY,TW,TH);fade(x,TY,TW,TH,n==2 and SOLOFADE or TEAMFADE)else rect(x,TY,TW,TH,C.nomod)end
 SHADOW=a and true or nil
 if a and st.shown==k then frame(x,TY,TW,TH,2,C.gold,key)elseif a and st.hover==key then frame(x,TY,TW,TH,1,C.white,key)else frame(x,TY,TW,TH,1,C.rule,key)end
 -- the name, and at its right the Most Votes badge on every leader, ties sharing it, or a highest rank where no Assignment is shared
 local right=0
 if a and model.sharing and (model.leaders or {})[k]then local bz=gs(BOLD,11);local bt=cut("Most Votes",BOLD,bz,106);right=W(bt,BOLD,bz)+14
  rect(cx+CW-right,116.4,right,20,C.gold,key..".badge");SHADOW=nil;put(bt,cx+CW-right+7,117.4,right-14,18,BOLD,bz,C.black,"center",right-14,key..".most");SHADOW=true
 elseif not a and p.high then local s=cut("Highest Rank "..p.high,BOLD,z14,CW*.6);right=W(s,BOLD,z14);put(s,cx+CW-right,116.4,right,20,BOLD,z14,C.grey,"right",right,key..".high")end
 local nr=CW-(right>0 and right+8 or 0);put(cut(p.who,BOLD,z14,nr),cx,116.4,nr,20,BOLD,z14,C.white,"left",nr,key..".name")
 local z17,z11=gs(MED,17),gs(MED,11.5)
 if a then
  put(cut(a.base or a.name,MED,z17,CW),cx,139.4,CW,22,MED,z17,C.white,"left",CW,key..".map")
  put(cut(join({a.rank and "Havoc "..a.rank,a.faction,a.type},DOT),MED,z11,CW),cx,164.4,CW,15,MED,z11,C.ts,"left",CW,key..".sub")
 else
  local lab=model.standing_label or "This Week"
  put(cut(p.none and "No Assignment"or "Assignment Not Shared",MED,z17,CW),cx,139.4,CW,22,MED,z17,C.grey,"left",CW,key..".map")
  put(cut(standing(p,lab),MED,z11,CW),cx,164.4,CW,15,MED,z11,C.ts,"left",CW,key..".sub")
 end
 SHADOW=nil
 -- from the foot up: the vote, the rank a win gives, then the records
 local vtop
 if not model.sharing then vtop=370.8;if a then hit(x,TY,TW,TH,key,"show",k)end
 elseif a then
  local mine=(model.mine or {})[k]==true;local bl=mine and "Your Vote"or "Vote";local bw,btw=bw_of(bl);local room=CW-bw-8
  local vz=gs(MED,11);local names=who[k]
  local segs=names and #names>0 and {{s=pl(#names,"Vote","Votes")..":",font=MED,size=vz,c=C.grey},{s=table.concat(names,", "),font=MED,size=vz,c=C.white}}or {{s="No Votes",font=MED,size=vz,c=C.grey}}
  local ls=clamp(flow(segs,room),3,room);local inner=math.max(24,14*#ls)
  vtop=377.6-6.8-inner;rect(cx,vtop,CW,1,C.hair,key..".rule")
  lines_put(ls,cx,vtop+6.8+(inner-14*#ls)/2,14,key..".votes")
  local by=vtop+6.8+(inner-24)/2;button(bl,cx+CW-bw,by,bw,btw,"vote"..k,mine,st.hover)
  hit(x,TY,TW,TH,key,"show",k);hit(cx+CW-bw,by,bw,24,"vote"..k,"vote",k)
 else
  vtop=356.8;rect(cx,vtop,CW,1,C.hair,key..".rule")
  local vz=gs(MED,11);put(cut(p.none and "Nothing To Vote For"or "Can't Vote Unless Shared",MED,vz,CW),cx,vtop+6.8,CW,14,MED,vz,C.grey,"left",CW,key..".votes")
 end
 local ty=vtop-28;local z15=gs(BOLD,15)
 -- over a picture the records and the win line are shadowed, their labels a step lighter, so they read on a bright map
 SHADOW=a and true or nil
 if a then local u=rankup(a.rank,model.my_rank,model.max_rank);put(wintext(u),cx,ty,CW-28,21,BOLD,z15,u>0 and C.icon or C.grey,"left",CW-28,key..".win")
  SHADOW=nil;post(cx+CW-20,ty,k,st)end
 SHADOW=nil
 local rows={}
 if a then local rec=model.maps and model.maps[a.map]
  rows[1]={p.me and "Your Record Here"or "Your Record There",runs_of(rec)>0 and wl(rec.won,rec.lost)or "No Runs Yet"}
  if p.me then rows[2]={"Last Played Here",rec and rec.last or DASH}elseif p.mate then rows[2]={"Playing Together",wl(p.mate.won,p.mate.lost)}end
 elseif p.mate then rows[1]={"Playing Together",wl(p.mate.won,p.mate.lost)}end
 -- the modifiers in the room above the records, 3 clear of them: by name in one column, else two to a row, else the icons row
 if a then local mods,top=a.mods or {},ty-20*(n==2 and #rows==2 and 1 or #rows)-3;local c=#mods;SHADOW=true
  if n<4 and c<=(n==2 and 5 or 4)and 184.4+22*c<=top then
   for j,m in ipairs(mods)do local fy=186.4+22*(j-1);icon(m.icon,cx,fy,20,20,C.ggold,key..".icon"..j);put(cut(m.title,FIG,12,CW-26),cx+26,fy,CW-26,20,FIG,12,C.ggold,"left",CW-26,key..".fx"..j)end
  elseif n<4 and 184.4+24*math.ceil(c/2)<=top then local half=(CW-12)/2
   for j,m in ipairs(mods)do local fx,fy=cx+((j-1)%2)*(half+12),188.4+math.floor((j-1)/2)*24
    icon(m.icon,fx,fy,20,20,C.ggold,key..".icon"..j);put(cut(m.title,FIG,12,half-26),fx+26,fy,half-26,20,FIG,12,C.ggold,"left",half-26,key..".fx"..j)end
  else for j,m in ipairs(mods)do if j>8 then break end;icon(m.icon,cx+30*(j-1),187.4,24,24,C.ggold,key..".icon"..j)end end
  SHADOW=nil
 end
 local z12,lc=gs(MED,12),a and C.lab or C.grey;SHADOW=a and true or nil
 if n==2 and #rows==2 then local half=(CW-20)/2
  for j,r in ipairs(rows)do pair(r[1],r[2],cx+(j-1)*(half+20),ty-20,half,17,MED,z12,lc,C.white,key..".kl"..j,key..".kv"..j)end
 else for j,r in ipairs(rows)do pair(r[1],r[2],cx,ty-20*(#rows-j+1),CW,17,MED,z12,lc,C.white,key..".kl"..j,key..".kv"..j)end end
 SHADOW=nil
end
local function team_band(model,st)
 local R=L.R.band;rect(R[1],R[2],R[3],R[4],C.black,"band");frame(R[1],R[2],R[3],R[4],2,C.rule,"band")
 local who=tally(model)
 for k=1,4 do tile(model,st,k,who)end
end
-- playing alone: the Assignment as one wide tile, beside who was played with recently
local function solo_band(model,st)
 local R=L.R.band;rect(R[1],R[2],R[3],R[4],C.black,"band");frame(R[1],R[2],R[3],R[4],2,C.rule,"band")
 local p=model.players[1];local a=p.a;local x,y,w,h,cx,cw=139.6,105.6,559.9,282.8,152.4,534.3
 picture(a.texture,x,y,w,h);fade(x,y,w,h,SOLOFADE);frame(x,y,w,h,2,C.gold,"solo");SHADOW=true
 local z14=gs(BOLD,14);local u=rankup(a.rank,model.my_rank,model.max_rank);local wt=wintext(u);local ww=math.min(W(wt,BOLD,z14),cw*.5);wt=cut(wt,BOLD,z14,ww);ww=W(wt,BOLD,z14)
 put(wt,cx+cw-ww,116.4,ww,20,BOLD,z14,u>0 and C.icon or C.grey,"right",ww,"solo.win")
 put(cut("Your Assignment",BOLD,z14,cw-ww-8),cx,116.4,cw-ww-8,20,BOLD,z14,C.white,"left",cw-ww-8,"solo.title")
 local z17,z11=gs(MED,17),gs(MED,11.5)
 put(cut(a.name,MED,z17,cw),cx,139.4,cw,22,MED,z17,C.white,"left",cw,"solo.map")
 put(cut(join({a.zone,a.rank and "Havoc "..a.rank,a.faction,a.type},DOT),MED,z11,cw),cx,164.4,cw,15,MED,z11,C.ts,"left",cw,"solo.sub")
 for j,m in ipairs(a.mods or {})do if j>6 then break end
  local fx,fy=cx+((j-1)%2)*273.2,188.4+math.floor((j-1)/2)*24
  icon(m.icon,fx,fy,20,20,C.ggold,"solo.icon"..j);put(cut(m.title,FIG,12,235.2),fx+26,fy,235.2,20,FIG,12,C.ggold,"left",235.2,"solo.fx"..j)
 end
 SHADOW=nil
 local rec=model.maps and model.maps[a.map];local ar=rec and rec.at_rank and rec.at_rank[a.rank];local bd=rec and rec.best_damage
 local kv={{"Your Record Here",runs_of(rec)>0 and wl(rec.won,rec.lost)or "No Runs Yet"},{"Last Played Here",rec and rec.last or DASH},
  {"At Havoc "..(a.rank or ""),ar and (ar[1]or 0)+(ar[2]or 0)>0 and (ar[1]or 0).."–"..(ar[2]or 0)or "No Runs Yet"},{"Best Damage Here",bd and bd[1]or DASH}}
 local z12=gs(MED,12)
 for j,r in ipairs(kv)do pair(r[1],r[2],cx+((j-1)%2)*277.2,343.6+math.floor((j-1)/2)*17,257.2,17,MED,z12,C.grey,C.white,"solo.kl"..j,"solo.kv"..j)end
 -- who to invite, newest first, and Party Finder under them
 local hx,hw,hz=711.5,551.9,gs(MED,11.9)
 local rw=-10
 if model.invites then local rt="Invite To The Strike Team";rw=math.min(W(rt,MED,hz),hw*.5);rt=cut(rt,MED,hz,rw);rw=W(rt,MED,hz);put(rt,hx+hw-rw,109.6,rw,17,MED,hz,C.grey,"right",rw,"people.right")end
 put(cut("Played With Recently",MED,hz,hw-rw-10),hx,109.6,hw-rw-10,17,MED,hz,C.grey,"left",hw-rw-10,"people.left")
 local ry=132.6
 for i,r in ipairs(model.recent or {})do if i>3 then break end
  frame(hx,ry,hw,47.6,1,C.hair,"recent"..i)
  local tx,z12=hx+10.8,gs(MED,12);local rwid
  if not model.invites then rwid=-12
  elseif r.can_invite then local itw;rwid,itw=bw_of("Invite");button("Invite",hx+hw-10.8-rwid,ry+11.8,rwid,itw,"invite"..i,false,st.hover);hit(hx+hw-10.8-rwid,ry+11.8,rwid,24,"invite"..i,"invite",i)
  else local s="Can't Invite Now";rwid=math.min(W(s,MED,z12),160);s=cut(s,MED,z12,rwid);rwid=W(s,MED,z12);put(s,hx+hw-10.8-rwid,ry+15.3,rwid,17,MED,z12,C.grey,"right",rwid,"recent"..i..".cant")end
  local room=hw-21.6-12-rwid
  local nz=gs(BOLD,14);local nm=tostring(r.who or "")
  if r.where then
   local wz=gs(MED,12);local wn,ww2=W(nm,BOLD,nz),W(r.where,MED,wz)
   local nr=math.min(wn,math.max(room-12-ww2,room*.6));nm=cut(nm,BOLD,nz,nr);local dn=W(nm,BOLD,nz)
   put(nm,tx,ry+6.8,dn,17,BOLD,nz,C.white,"left",dn,"recent"..i..".name")
   local wx=tx+dn+12;local wr=tx+room-wx;put(cut(r.where,MED,wz,wr),wx,ry+6.8,wr,17,MED,wz,r.where=="In The Mourningstar"and C.icon or C.grey,"left",wr,"recent"..i..".where")
  else put(cut(nm,BOLD,nz,room),tx,ry+6.8,room,17,BOLD,nz,C.white,"left",room,"recent"..i..".name")end
  local z11b=gs(MED,11)
  put(cut(join({r.games and pl(r.games,"Game Together","Games Together"),(r.won or r.lost)and wl(r.won,r.lost),r.high and "Highest Rank "..r.high},DOT),MED,z11b,room),tx,ry+23.8,room,17,MED,z11b,C.grey,"left",room,"recent"..i..".line")
  ry=ry+53.6
 end
 local fz=gs(REG,11.9);put(cut("Or find an open Strike Team in Party Finder.",REG,fz,hw),hx,ry,hw,17,REG,fz,C.grey,"left",hw,"people.foot")
end

-- the card head: map, zone and objective, with your best clear on that map at its right
local function head(model,a,rec)
 local R=L.R.head;rect(R[1],R[2],R[3],R[4],C.gpanel,"head");frame(R[1],R[2],R[3],R[4],1,C.gedge,"head")
 local bc=rec and rec.best_clear;local z,tz=gs(MED,11),gs(BOLD,22)
 local l1,l2,l3="Your Best Clear",bc and bc[1]or DASH,bc and join({bc[2]and "Havoc "..bc[2],bc[3]},DOT)or "No Timed Win Yet"
 local bw=math.min(math.max(W(l1,MED,z),W(l2,BOLD,tz),W(l3,MED,z)),160);local bx=595.2-bw
 put(cut(l1,MED,z,bw),bx,419.8,bw,14,MED,z,C.grey,"right",bw,"best.label")
 put(cut(l2,BOLD,tz,bw),bx,434.8,bw,26,BOLD,tz,bc and C.gold or C.grey,"right",bw,"best.time")
 put(cut(l3,MED,z,bw),bx,461.8,bw,14,MED,z,C.grey,"right",bw,"best.sub")
 local room=bx-12-150.8
 put(cut(a.name,FIG,22,room),150.8,415.8,room,26,FIG,22,C.gtext,"left",room,"head.name")
 put(cut(a.zone,FIG,14,room),150.8,441.8,room,17,FIG,14,C.gdim,"left",room,"head.zone")
 duo(model.objective_label or "Primary Objective:",a.type,150.8,458.8,room,17,FIG,14,C.gdim,C.gtext,space(FIG,14),2,"head.objective","head.type")
end

-- the record plate: two rows of cells, then the game's Assignment reset line; a figure wider than its cell runs on into the 12 before
-- the next, as the mockup's unwrapped figure does, up to 3 short of it, and only then is cut
local function cell(x,w,y,lab,val,sub,vc,id)
 local z,vz=gs(MED,11),gs(BOLD,20)
 put(cut(lab,MED,z,w),x,y,w,16,MED,z,C.grey,"left",w,id..".label")
 val=tostring(val or "");local vr=W(val,BOLD,vz)>w+TOL and w+9 or w;put(cut(val,BOLD,vz,vr),x,y+16,vr,26,BOLD,vz,vc,"left",vr,id..".value")
 put(cut(sub,MED,z,w),x,y+42,w,16,MED,z,C.grey,"left",w,id..".sub")
end
local function plate(model,a,rec)
 local R=L.R.plate;rect(R[1],R[2],R[3],R[4],C.blank,"plate.blank");rect(R[1],R[2],R[3],R[4],C.io,"plate");frame(R[1],R[2],R[3],R[4],2,C.rule,"plate")
 local n=runs_of(rec);local won,lost=rec and rec.won or 0,rec and rec.lost or 0
 local bd=rec and rec.best_damage;local ar=rec and rec.at_rank and rec.at_rank[a.rank];local at=ar and (ar[1]or 0)+(ar[2]or 0)or 0
 local y=774.4
 cell(147.6,98,y,"Won",n>0 and pct(won,n).."%"or DASH,"Win Rate",n>0 and C.white or C.grey,"plate.won")
 cell(257.6,84,y,"Runs",tostring(n),rec and rec.since and "Since "..rec.since or "No Runs Yet",C.white,"plate.runs")
 if bd then cell(353.6,132.8,y,"Best Damage",bd[1],join({bd[2],bd[3]},DOT),C.gold,"plate.damage")else cell(353.6,132.8,y,"Best Damage",DASH,"No Runs Yet",C.grey,"plate.damage")end
 if at>0 then cell(498.4,96,y,"At Havoc "..(a.rank or ""),(ar[1]or 0).."–"..(ar[2]or 0),pl(at,"Run","Runs"),C.white,"plate.at")
 else cell(498.4,96,y,"At Havoc "..(a.rank or ""),DASH,"No Runs Yet",C.grey,"plate.at")end
 rect(131.6,842.4,478.8,2,C.rule,"plate.divider")
 y=854;local d=rec and rec.downs
 if d and d.total then local tr,of=d.tracked or n,d.runs or n
  cell(147.6,174.1,y,"Downs And Deaths",tostring(d.total),tr==of and "In "..pl(tr,"Run","Runs")or "In "..tr.." Of "..of.." Runs",C.white,"plate.downs")
  cell(333.7,124.4,y,"Per Run",tr>0 and dec(d.total/tr,1)or DASH,"Downs And Deaths",tr>0 and C.white or C.grey,"plate.per")
 else cell(147.6,174.1,y,"Downs And Deaths",DASH,n>0 and "Not Tracked"or "No Runs Yet",C.grey,"plate.downs");cell(333.7,124.4,y,"Per Run",DASH,"Downs And Deaths",C.grey,"plate.per")end
 if n>0 then cell(470.1,124.4,y,"Win–Loss",lost>0 and dec(won/lost,2)or "All Won",wl(won,lost),C.white,"plate.ratio")
 else cell(470.1,124.4,y,"Win–Loss",DASH,"No Runs Yet",C.grey,"plate.ratio")end
 rect(131.6,922,478.8,2,C.rule,"plate.reset_rule")
 local rs=model.reset or {}
 duo(rs[1],rs[2],147.6,932,446.8,20,FIG,14,C.gdim,C.gtext,space(FIG,14),2,"plate.reset","plate.reset_time")
end

-- the modifier list, 245 tall whatever it holds: two to a row, the descriptions set smaller in half steps until every row fits 221
local MX,MY,MW,TXT,ROOM=632.8,418.8,311.7,255.3,221
local function cards(mods,dz,cap)
 local lh=dz*17/13.5;local laid,rows,total={},{},0
 for i,m in ipairs(mods)do
  local tl=clamp(flow({{s=m.title or "",font=FIG,size=15,c=C.ggold}},TXT),2,TXT)
  local dl=flow({{s=m.desc or "",font=FIG,size=dz,c=C.gtext}},TXT);if cap then dl=clamp(dl,cap,TXT)end
  laid[i]={tl=tl,dl=dl,h=math.max(44,12+19*#tl+2+lh*#dl)}
  local r=math.floor((i-1)/2)+1;rows[r]=math.max(rows[r]or 0,laid[i].h)
 end
 for r,h in ipairs(rows)do total=total+h+(r>1 and 6 or 0)end
 return {laid=laid,rows=rows,h=total,lh=lh,dz=dz}
end
local function list(a)
 local R=L.R.list;rect(R[1],R[2],R[3],R[4],C.gpanel,"list");frame(R[1],R[2],R[3],R[4],1,C.gedge,"list")
 local mods={};for i,m in ipairs(a.mods or {})do if i>6 then break end;mods[i]=m end
 local n0=#fits;local best,dz=nil,13.5
 while true do best=cards(mods,dz);undo(n0);if best.h<=ROOM or dz<=10 then break end;dz=dz-.5 end
 local cap=nil
 if best.h>ROOM then cap=8;while best.h>ROOM and cap>1 do cap=cap-1;best=cards(mods,dz,cap);undo(n0)end end
 best=cards(mods,dz,cap)
 if dz<13.5 then fit("descriptions at 13.5","descriptions at "..dz,"shrunk so the rows fit "..ROOM)end
 local y=MY
 for r,rh in ipairs(best.rows)do
  for c=1,2 do local i=(r-1)*2+c;local m,cd=mods[i],best.laid[i]
   if m then local x=MX+(MW+10)*(c-1);local id="mod"..i
    rect(x,y,3,rh,C.ggold,id..".rule");icon(m.icon,x+10.4,y+7,30,30,C.ggold,id..".icon")
    lines_put(cd.tl,x+48.4,y+5,19,id..".title");lines_put(cd.dl,x+48.4,y+5+19*#cd.tl+2,best.lh,id..".desc")
   end
  end
  y=y+rh+6
 end
end

-- the panel under the list: Briefing, Threats and Team
local function hd(y,left,right,id)
 rect(625.6,y,647.8,2,C.rule,id..".rule");local z=gs(MED,11.9)
 local rw=math.min(W(right,MED,z),300);right=cut(right,MED,z,rw);rw=W(right,MED,z)
 put(right,1257.4-rw,y+9.6,rw,17,MED,z,C.grey,"right",rw,id..".right")
 put(cut(left,MED,z,615.8-rw-10),641.6,y+9.6,615.8-rw-10,17,MED,z,C.grey,"left",615.8-rw-10,id..".left")
 rect(625.6,y+34.6,647.8,2,C.rule,id..".body")
end
local function briefing(model,a,rec,team)
 hd(696.6,"Briefing: "..(a.base or a.name or ""),"From Saved Matches","brief")
 local items={}
 if runs_of(rec)==0 then items[1]={"No Runs Yet.","Your saved Havoc matches on this map will show here."}
 else
  local op=rec.op
  if op and (op[2]or 0)>0 then items[#items+1]={op[1]..".","The operative that wins this map most: "..wl(op[2],op[3]).."."}
  else items[#items+1]={op and op[1].."."or "Operatives.","No operative has won here yet."}end
  local d=rec.downs;if d and ((d.head or "")~=""or (d.line or "")~="")then items[#items+1]={d.head or "",d.line or ""}end
  if team then local t=rec.team_any;items[#items+1]={"Team.",t and (t[1]or 0)+(t[2]or 0)>0 and "With these players here: "..wl(t[1],t[2]).."."or "No runs here with these players yet."}end
  local r=rec.ranks;if r and r[1]then items[#items+1]={"Ranks.",r[1]==r[2]and "Every run here was at Havoc "..r[1].."."or "Runs here between Havoc "..r[1].." and "..r[2].."."}end
 end
 local lz,tz=gs(BOLD,13.8),gs(REG,12.75);local n0=#fits;local laid,total,cap=nil,0,3
 while true do
  laid,total={},0
  for i,it in ipairs(items)do laid[i]=clamp(flow({{s=it[1],font=BOLD,size=lz,c=C.white,gap=6},{s=it[2],font=REG,size=tz,c=C.grey}},575.8),cap,575.8);total=total+math.max(23,19*#laid[i])end
  total=total+10*(#items-1)
  if total<=214.6 or cap<=1 then break end;undo(n0);cap=cap-1
 end
 local y=740.8+(214.6-total)/2
 for i,ls in ipairs(laid)do chevron(641.6,y+1,"brief"..i..".chev");lines_put(ls,681.6,y,19,"brief"..i);y=y+math.max(23,19*#ls)+10 end
end
local function threats(a,rec)
 hd(696.6,"What Downs You On "..(a.base or a.name or ""),"Most First","threats")
 local d=rec and rec.downs;local bars=d and d.bars or {}
 local z,bz,rz=gs(MED,11.9),gs(BOLD,11.9),gs(REG,11.9)
 if #bars==0 then local s=cut(d and (d.line or "")~=""and d.line or "No downs or deaths recorded here yet.",REG,rz,615.8);put(s,641.6,839.6,615.8,17,REG,rz,C.grey,"center",615.8,"threats.none");return end
 local top=bars[1][2]or 1;if top<=0 then top=1 end;local y=744.8
 for i=1,math.min(L.BARS,#bars)do local b=bars[i]
  put(cut(b[1],MED,z,228),641.6,y,228,19,MED,z,C.white,"left",228,"threat"..i..".name")
  local bw=math.floor((b[2]or 0)/top*100+.5)/100*345.8
  -- filled when the cause is of a headline kind (several on a tie), outlined otherwise
  local lit=b[4];if lit==nil then lit=b[3]~=nil and b[3]==d.kind end
  if lit then rect(877.6,y+5.5,bw,8,C.bar,"threat"..i..".bar")else frame(877.6,y+5.5,bw,8,1,C.bar,"threat"..i..".bar")end
  -- a count wider than its column grows left into the gap, its box reaching the track's end at most
  local cs=tostring(b[2]or 0);local cr=W(cs,BOLD,bz)>26+TOL and 30 or 26;cs=cut(cs,BOLD,bz,cr);put(cs,1257.4-cr,y,cr,19,BOLD,bz,C.white,"right",cr,"threat"..i..".count")
  y=y+23
 end
 -- every cause from the ninth on one line, whole names, as many as fill.js lets in: while L.ALSO characters hold "Also: " and each name
 -- with a separator after it, and while the drawn line fits its room
 local rest={}
 if d.all then for i=L.BARS+1,#d.all do rest[#rest+1]=d.all[i]end
 else for i=L.BARS+1,#bars do rest[#rest+1]=bars[i]end;for _,x in ipairs(d.also or {})do rest[#rest+1]=x end end
 local s,len=nil,6
 for _,x in ipairs(rest)do local item=x[1].." "..(x[2]or "");len=len+#item-select(2,item:gsub("[\128-\191]",""))+3;if len>L.ALSO then break end
  local t=s and s..DOT..item or "Also: "..item;if W(t,REG,rz)>615.8+TOL then s=s or cut(t,REG,rz,615.8);break end;s=t end
 if not s then return end
 put(s,641.6,y-4+12,615.8,17,REG,rz,C.grey,"left",615.8,"threats.also")
end
local function team_tab(model,st,team)
 local lab=model.standing_label or "This Week"
 hd(696.6,"Havoc Standing","Highest Rank · Best "..lab,"stand")
 local people={}
 if team then for i,p in ipairs(model.players)do people[i]=p end else people[1]=model.players[1];for _,r in ipairs(model.recent or {})do people[#people+1]=r end end
 local nz,hz,ez=gs(MED,12.5),gs(BOLD,34),gs(MED,11)
 local n=math.min(4,#people);local sw=(615.75-(n-1)*8.05)/n
 for k=1,n do local p=people[k];local x=641.6+(sw+8.05)*(k-1);local id="stand"..k
  frame(x,731.1,sw,100.6,1,C.hair,id);local cx,cw=x+7,sw-14
  put(cut(p.who,MED,nz,cw),cx,743.9,cw,16,MED,nz,C.white,"center",cw,id..".name")
  put(cut(p.high and tostring(p.high)or DASH,BOLD,hz,cw),cx,760.9,cw,40,BOLD,hz,C.gold,"center",cw,id..".high")
  put(cut(standing(p,lab),MED,ez,cw),cx,803.9,cw,14,MED,ez,C.white,"center",cw,id..".sub")
 end
 hd(830,team and "Played Together"or "Played With Recently","Every Mode","mates")
 local list=model.together or {};local n=math.min(3,#list);local z,bz=gs(MED,12.5),gs(BOLD,12.5)
 if n==0 then put(cut("No Games Together Yet",MED,z,615.8),641.6,906,615.8,18,MED,z,C.grey,"center",615.8,"mates.none");return end
 local y=874.2+(81.2-(18*n+4*(n-1)))/2
 for i=1,n do local r=list[i];local id="mate"..i;local p=pct(r.won,r.games)or 0
  put(cut(r.who,BOLD,bz,96),641.6,y,96,18,BOLD,bz,C.white,"left",96,id..".name")
  put(cut(pl(r.games or 0,"Game","Games"),MED,z,76),749.6,y,76,18,MED,z,C.grey,"left",76,id..".games")
  frame(837.6,y+4,235.8,10,1,C.bar,id..".track");rect(837.6,y+4,235.8*p/100,10,C.bar,id..".fill")
  put(cut(wl(r.won,r.lost),MED,z,120),1085.4,y,120,18,MED,z,C.white,"left",120,id..".record")
  local ps=cut(p.."%",MED,z,40);put(ps,1217.4,y,40,18,MED,z,C.white,"right",40,id..".pct")
  y=y+22
 end
end
local TABS={"Briefing","Threats","Team"}
local function panel(model,st,a,rec,team)
 local R=L.R.panel;rect(R[1],R[2],R[3],R[4],C.black,"panel");frame(R[1],R[2],R[3],R[4],2,C.rule,"panel")
 local tab=st.tab or 1;local z=gs(MED,12.5)
 for i,name in ipairs(TABS)do local x,y,w,h=633.6+212.6*(i-1),662.6,206.6,28;local key="tab"..i
  if i==tab then rect(x,y,w,h,C.tabon,key);frame(x,y,w,h,1,C.tabedge,key);rect(x+1,y+h-3,w-2,2,C.gold,key..".under")
  elseif st.hover==key then rect(x,y,w,h,C.tabhv,key);frame(x,y,w,h,1,C.rule,key)else rect(x,y,w,h,C.tabrest,key);frame(x,y,w,h,1,C.lit,key)end
  put(cut(name,MED,z,w-21.6),x+10.8,y,w-21.6,h,MED,z,i==tab and C.tabtext or C.white,"center",w-21.6,key..".name")
  hit(x,y,w,h,key,"tab",i)
 end
 if tab==2 then threats(a,rec)elseif tab==3 then team_tab(model,st,team)else briefing(model,a,rec,team)end
end

-- the latest runs on the shown map along the bottom, the label and columns as wide as their words
local function strip(a,rec)
 local R=L.R.strip;rect(R[1],R[2],R[3],R[4],C.io,"strip");frame(R[1],R[2],R[3],R[4],2,C.rule,"strip")
 local z1,z2=gs(MED,14),gs(MED,11);local runs=rec and rec.strip or {}
 local cw=0;for i=1,math.min(12,#runs)do local r=runs[i];cw=math.max(cw,W("Havoc "..(r[1]or ""),MED,z2),W(tostring(r[2]or ""),MED,z2),W(r[3]and "Won"or "Lost",MED,z2))end
 local lw=math.max(W("Latest Runs",MED,z1),W("Newest First",MED,z2));local base=a.base or a.name or ""
 local avail=1143.8-1.6-24;local need=12*cw+66;local labw=math.max(lw,W(base,MED,z2))
 -- the map name gives way first, then the run columns
 if 32+labw+need>avail then labw=math.max(lw,avail-need-32);if 32+labw+need>avail then cw=(avail-32-labw-66)/12 end end
 local LW=32+labw
 put(cut("Latest Runs",MED,z1,labw),147.6,992.5,labw,19,MED,z1,C.white,"center",labw,"strip.title")
 put(cut(base,MED,z2,labw),147.6,1011.5,labw,15,MED,z2,C.grey,"center",labw,"strip.map")
 put(cut("Newest First",MED,z2,labw),147.6,1026.5,labw,15,MED,z2,C.grey,"center",labw,"strip.newest")
 rect(131.6+LW,978.6,2,76.8,C.rule,"strip.divider")
 local x=131.6+LW+1.6+12
 for i=1,math.min(12,#runs)do local r=runs[i];local id="run"..i
  rect(x,987.6,cw,4,r[3]and C.bar or C.lost,id..".tick")
  put(cut("Havoc "..(r[1]or ""),MED,z2,cw),x,998.6,cw,15,MED,z2,C.grey,"left",cw,id..".rank")
  put(cut(r[2],MED,z2,cw),x,1013.6,cw,15,MED,z2,C.white,"left",cw,id..".class")
  put(cut(r[3]and "Won"or "Lost",MED,z2,cw),x,1028.6,cw,15,MED,z2,r[3]and C.icon or C.grey,"left",cw,id..".result")
  x=x+cw+6
 end
end

function L.layout(model,st,measure)
 ops,hits,fits,ms,memo,SHADOW={}, {}, {},measure,{},nil
 local out={ops=ops,hits=hits,fits=fits,dx=L.SHIFT,dy=L.SHIFT_Y}
 st=st or {}
 local me=model and model.players and model.players[1]
 if not (me and me.a)then return out end
 local team=st.team and #model.players>1
 local si=team and st.shown or 1;if not (model.players[si]and model.players[si].a)then si=1 end
 local a=model.players[si].a;local rec=model.maps and model.maps[a.map]
 st={team=team,shown=si,tab=st.tab,hover=st.hover,posted=st.posted}
 REGION="band";if team then team_band(model,st)else solo_band(model,st)end
 REGION="head";head(model,a,rec)
 REGION="plate";plate(model,a,rec)
 REGION="list";list(a)
 REGION="panel";panel(model,st,a,rec,team)
 REGION="strip";strip(a,rec)
 REGION=nil
 for _,o in ipairs(ops)do o.x,o.y=o.x+L.SHIFT,o.y+L.SHIFT_Y end;for _,h in ipairs(hits)do h.x,h.y=h.x+L.SHIFT,h.y+L.SHIFT_Y end
 return out
end
return L
