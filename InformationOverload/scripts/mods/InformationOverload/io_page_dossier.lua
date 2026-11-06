-- Information Overload: the Dossier, one file per character over every mission.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local P=mod:io_dofile(base.."io_data_people")
local Times=mod:io_dofile(base.."mission_times")
local C,F,DASH=D.c,D.font,P.dash
local L,R,W=D.left,D.col2,D.col
local function fit(view,t,size,w)if view:_w(t,size)<=w then return t end;while #t>1 and view:_w(t.."…",size)>w do repeat local b=t:byte(-1);t=t:sub(1,-2)until #t==0 or b<128 or b>=192 end;return (t:gsub("[%s,]+$","")).."…"end
local function head(cv,x,y,w,text)cv:text(text,x,y+11,w-13,30,14,C.muted,"right")end
-- a hollow mark per down and a filled one per death, kept left of r; past it as many as fit and the rest counted, both kinds kept in
local function marks(view,cv,x,y,r,down,death)
 local n=down+death;local k=math.min(n,math.floor((r-x+3)/13))
 while k>0 and k<n and x+k*13+view:_w("+"..(n-k),13,F.medium)>r do k=k-1 end
 local dd=death;if k<n then dd=death>0 and math.max(1,math.floor(k*death/n+.5))or 0;dd=math.max(0,math.min(dd,down>0 and k-1 or k))end
 for i=1,math.min(down,k-dd)do cv.z=5;cv:edges(x,y,10,10,1,C.label)x=x+13 end
 for i=1,dd do cv:rect(x,y,10,10,C.bad)x=x+13 end
 if k>0 and k<n then cv:text("+"..(n-k),x,y-4,60,18,13,C.muted,"left",F.medium)end
end
local function id_card(view,cv,ch,y)
 local x,yy=L,y+45
 view:_rows(cv,x,yy,W,{{"First Deployed",P.day(ch.first.started_at),true}},P.open_run(view,ch.first.id));yy=yy+26
 view:_rows(cv,x,yy,W,{{"Last Deployed",P.day(ch.last.started_at),true}},P.open_run(view,ch.last.id));yy=yy+31
 cv:text("Missions Won",x+36,yy,300,26,16,C.gold);yy=yy+26
 for _,w in ipairs(ch.won)do
  cv:text(w.label,x+56,yy,240,26,16,C.label)
  local vt=w.w.." Of "..w.g;local vw=view:_w(vt,16);local n=math.min(#w.seq,14);local cx=x+W-13-vw-18-n*15
  for i=#w.seq-n+1,#w.seq do local s=w.seq[i];cv:rect(cx,yy+6,13,13,s.win and C.label or C.fill);if not s.win then cv.z=5;cv:edges(cx,yy+6,13,13,1,C.frame)end;cx=cx+15 end
  cv:text(vt,x+W-313,yy,300,26,16,C.value,"right");yy=yy+26
  if w.mode~="havoc"and w.mw>0 then
   local t=w.mw==w.w and (w.w==1 and "The "..w.label.." win was Maelstrom."or (w.w==2 and "Both "or "All "..w.w.." ")..w.label.." wins were Maelstrom.")or (w.mw==1 and "One"or tostring(w.mw)).." of the "..w.w.." "..w.label.." wins "..(w.mw==1 and "was"or "were").." Maelstrom."
   cv:text(t,x+56,yy,W-80,22,14,C.muted,"left",F.medium);yy=yy+22
  end
 end
 yy=yy+8
 local list={}
 local lo="From the newest mission that saved a loadout."
 if ch.keystone then list[#list+1]={"Keystone",ch.keystone,lo}end
 if ch.blitz then list[#list+1]={"Blitz",ch.blitz,lo}end
 if #ch.others>0 then local o={};for _,v in ipairs(ch.others)do o[#o+1]=v.n.." ("..P.plural(v.k,"Mission")..")"end;list[#list+1]={"Also On File As",table.concat(o,", "),"The same character under another name in some match files."}end
 for _,r in ipairs(list)do cv:text(r[1],x+36,yy,200,26,16,C.label);cv:text(r[2],x+200,yy,W-213,26,16,C.value,"right");if view._tip then view:_tip("base",x+25,yy,W-38,26,{r[1],r[3]})end;yy=yy+26 end
 yy=yy+10
 local N=#ch.runs;local tx,tw=x+37,(W-50)/5
 local tiles={{"kills","Kills",P.commas},{"dmg","Damage",P.compact},{"bosses","Bosses",P.commas},{"downs","Downs",P.commas},{"deaths","Deaths",P.commas}}
 -- Only as tall as the text: the third line shows only when some missions lack that figure.
 local th=56;for _,t in ipairs(tiles)do local v=ch.tot[t[1]];if v.v and v.n<N then th=74 end end
 cv.z=5;cv:edges(tx,yy,W-50,th,1,C.frame)
 for i,t in ipairs(tiles)do local v=ch.tot[t[1]];local cx=tx+(i-1)*tw
  if i>1 then cv:rect(cx,yy,1,th,C.frame)end
  -- with every digit shown, a figure too wide for its tile drops a size, or two
  local s=v.v and t[3](v.v)or DASH;cv:text(s,cx+12,yy+6,tw-16,26,view:_w(s,20)<=tw-16 and 20 or view:_w(s,16)<=tw-16 and 16 or 14,C.value)
  cv:text(t[2],cx+12,yy+30,tw-16,20,14,C.label)
  if v.v and v.n<N then cv:text("In "..v.n.." Of "..N,cx+12,yy+48,tw-16,18,13,C.muted,"left",F.medium)end
 end
 return yy+th+16-y
end
local function down_card(view,cv,ch,y)
 local x,yy=R,y+45;local E=ch.enemies;local N=#ch.runs
 if #E==0 then
  local t=#ch.leth_runs>0 and "Nothing downed you in "..P.plural(#ch.leth_runs,"mission").." on file."or "The match files for these missions keep no record of what downed you."
  for _,l in ipairs(P.wrap(view,t,14,W-60,F.medium))do cv:text(l,x+36,yy,W-50,20,14,C.muted,"left",F.medium);yy=yy+20 end
  return yy+14-y
 end
 local mx=0;for _,e in ipairs(E)do mx=math.max(mx,view:_w(e.n,16))end;mx=x+math.min(290,mx+50)
 for _,e in ipairs(E)do
  view:_jump(cv,x+8,yy+4,P.open_run(view,e.runs[#e.runs]))
  cv:text(e.n,x+36,yy,250,30,16,C.value)
  local how={};if e.down>0 then how[#how+1]="Downed "..P.times(e.down)end;if e.death>0 then how[#how+1]="Killed You "..P.times(e.death)end
  local t=table.concat(how,", ");marks(view,cv,mx,yy+10,x+W-23-view:_w(t,14,F.medium),e.down,e.death)
  cv:text(t,x+W-313,yy,300,30,14,C.muted,"right",F.medium)
  cv:rect(x+25,yy+29,W-38,1,C.line,true);yy=yy+30
 end
 yy=yy+12
 cv.z=5;cv:edges(x+37,yy+4,10,10,1,C.label);cv:text("Down",x+53,yy,60,18,14,C.label)
 local dx=x+53+view:_w("Down",14)+16;cv:rect(dx,yy+4,10,10,C.bad);cv:text("Death",dx+16,yy,60,18,14,C.label);yy=yy+24
 local notes={}
 local L2=#ch.leth_runs;if L2>0 and L2<N then notes[#notes+1]="From "..L2.." of "..N.." missions. "..(N-L2==1 and "The older match file keeps"or "The "..(N-L2).." older match files keep").." no causes."end
 if ch.leth_two then notes[#notes+1]="An event with two causes is listed under both, so the rows can add up to more than the total."end
 if #notes>0 then for _,l in ipairs(P.wrap(view,table.concat(notes," "),14,W-60,F.medium))do cv:text(l,x+36,yy,W-50,20,14,C.muted,"left",F.medium);yy=yy+20 end end
 return yy+12-y
end
local function bests_card(view,cv,ch,y)
 local x,w=L,D.width;local yy=y+45;local tw=(w-50)/4
 for _,mode in ipairs({"havoc","non-havoc"})do local row=ch.bests[mode];local mn=mode=="havoc"and "Havoc"or "Non-Havoc"
  local hw=view:_w(mn,16);cv:text(mn,x+36,yy,hw+6,26,16,C.gold);cv:text(P.plural(row and row.n or 0,"Mission"),x+46+hw,yy+1,200,26,14,C.muted)
  yy=yy+30
  if not row then cv:text("No "..mn.." missions on file.",x+36,yy,600,22,14,C.muted,"left",F.medium);yy=yy+30
  else
   local tiles={}
   for _,s in ipairs(P.dossier_stats)do local v=row[s[1]]
    if v.v~=nil then
     if v.v==0 then tiles[#tiles+1]={v="0",l=s[2],s="None Yet",no=true}
     else local tg=v.rec=="holds"and "Record"or v.rec=="equals"and "Equals The Record"or v.n<v.of and "From "..v.n.." Of "..v.of or nil
      tiles[#tiles+1]={v=P.commas(v.v),l=s[2],s=v.run.context and view.io_dossier_map(v.run)..", "..P.dm(v.run.started_at),tg=tg,rec=v.rec=="holds",run=v.run.id}end
    end
   end
   local wv=row.wins
   if wv.v==0 then tiles[#tiles+1]={v="0",l="Wins In A Row",s="No Wins Yet",no=true}
   else local a,b=P.dm(wv.from.started_at),P.dm(wv.run.started_at);tiles[#tiles+1]={v=tostring(wv.v),l="Wins In A Row",s=(a==b and b or a.." To "..b)..(wv.going and ", Still Going"or ""),tg=wv.going and "Current"or nil,run=wv.run.id}end
   local rows_n=math.ceil(#tiles/4)
   cv.z=5;cv:edges(x+37,yy,w-50,rows_n*77,1,C.frame)
   for i,t in ipairs(tiles)do local col,rw=(i-1)%4,math.floor((i-1)/4);local tx,ty=x+37+col*tw,yy+rw*77
    if col>0 then cv:rect(tx,ty,1,77,C.frame)end;if rw>0 then cv:rect(tx,ty,tw,1,C.frame)end
    if t.rec then cv:rect(tx+1,ty+1,2,75,C.gold)end
    cv:text(t.v,tx+12,ty+6,tw-120,30,22,t.no and C.muted or C.value)
    if t.tg then cv:text(t.tg,tx+tw-213,ty+10,200,22,14,t.rec and C.gold or C.label,"right")end
    cv:text(t.l,tx+12,ty+33,tw-50,22,16,C.value);cv:text(t.s,tx+12,ty+52,tw-50,20,13,C.muted,"left",F.medium)
    if t.run then view:_jump(cv,tx+tw-30,ty+47,P.open_run(view,t.run))end
   end
   yy=yy+rows_n*77+16
  end
 end
 return yy-y
end
local function weapons_card(view,cv,ch,y)
 local x,yy=L,y+45;local M=#ch.wd_runs
 if #ch.weapons==0 then cv:text("No loadouts on file.",x+36,yy,W-50,22,14,C.muted,"left",F.medium);yy=yy+26 end
 for _,w in ipairs(ch.weapons)do
  local nw=math.min(view:_w(w.n,16),W-140);cv:text(w.n,x+36,yy+4,nw+6,22,16,C.value);cv:text(w.slot=="melee"and "Melee"or "Ranged",x+44+nw,yy+5,100,22,14,C.muted)
  local cx=x+37;local set={};for _,id in ipairs(w.runs)do set[id]=true end
  local lt=#w.runs.." Of "..M.." Missions";local n=math.max(0,math.min(M,math.floor((W-56-view:_w(lt,14))/15)))
  for i=M-n+1,M do cv:rect(cx,yy+38,13,4,set[ch.wd_runs[i]]and C.label or C.fill);cx=cx+15 end
  cv:text(lt,cx+6,yy+29,200,22,14,C.label)
  cv:rect(x+25,yy+61,W-38,1,C.line,true);yy=yy+62
 end
 if ch.nolo>0 then local t=P.plural(ch.nolo,"older mission").." saved no loadout, so "..(ch.nolo==1 and "its weapons are"or "their weapons are").." not known."
  for _,l in ipairs(P.wrap(view,t,14,W-60,F.medium))do cv:text(l,x+36,yy+6,W-50,20,14,C.muted,"left",F.medium);yy=yy+20 end;yy=yy+10 end
 return yy+10-y
end
local function clears_card(view,cv,ch,y)
 local x,yy=R,y+45;local timed=false;local top=45*60
 for _,c in ipairs(ch.clears)do if c.st=="time"then timed=true;top=math.max(top,c.s)end end
 local mx=math.ceil(top/900)*900;local bx,bw=x+267,167
 if timed then for k=0,3 do local tx=bx+bw*k/3;cv:text(tostring(math.floor(mx*k/3/60+.5)),tx-20,yy-6,40,18,13,C.muted,"center");if k>0 then cv:rect(tx,yy+14,1,#ch.clears*36,C.line)end end;yy=yy+16 end
 if #ch.clears==0 then cv:text("No missions on file.",x+36,yy,W-50,22,14,C.muted,"left",F.medium);yy=yy+26 end
 for _,c in ipairs(ch.clears)do
  view:_jump(cv,x+8,yy+7,P.open_run(view,c.run.id))
  local sub=c.label..(c.mael and ", Maelstrom"or "").." · "..P.dm(c.run.started_at)..(c.n>1 and " · Best Of "..c.n or "")
  cv:text(c.map,x+36,yy+2,226,20,15,c.st=="lost"and C.label or C.value);cv:text(sub,x+36,yy+19,226,16,13,C.muted,"left",F.medium)
  if c.st=="time"then cv:rect(bx,yy+16,math.max(2,bw*c.s/mx),4,C.label);cv:text(Times.format(c.s),x+W-163,yy,150,36,15,C.value,"right")
  else cv:text(c.st=="won"and (c.partial and "Won, Partial"or "Won")or "Lost",x+W-163,yy,150,36,15,c.st=="lost"and C.muted or C.value,"right")end
  cv:rect(x+25,yy+35,W-38,1,C.line,true);yy=yy+36
 end
 return yy+16-y
end
return function(view,cv,popup)
 local tracker=view:_tracker()
 if not tracker then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 -- kept until the history or the Overview model is replaced; that model is built again when the runs, a display option or a mission's time change
 local dc=view.io_doss;if not dc or dc.d~=tracker.data or dc.m~=view.model then dc={d=tracker.data,m=view.model,data=P.dossier(tracker)};view.io_doss=dc end
 local data=dc.data
 if #data.chars==0 then view:_card(cv,D.left,D.top,D.width,92,"No Missions Recorded Yet");view.io_crumbs={{"Dossier"}};return end
 view.io_dossier_map=function(run)return tracker:run_mission_name(run.context)end
 local byid={};for _,c in ipairs(data.chars)do byid[c.id]=c end
 local ch=byid[view.io_dossier]or byid[data.newest]or data.chars[1];view.io_dossier=ch.id
 local reset=function(id)return function()if view.io_dossier~=id then view.io_dossier=id;if view.scroll then view.scroll.dossier=0 end end end end
 view.io_crumbs={{"Dossier",data.newest and ch.id~=data.newest and reset(data.newest)or nil},{ch.name}}
 local n=#data.chars;local gap=7;local tw=(D.width-gap*(n-1))/n
 for i,c in ipairs(data.chars)do local tx=D.left+(i-1)*(tw+gap);local sel=c.id==ch.id
  view:_ctl(cv,"base",tx,D.top,tw,44,reset(c.id),{sel=sel})
  cv:text(fit(view,c.name,16,tw-20),tx+12,D.top+2,tw-20,22,16,sel and C.gold_hi or C.value);cv:text(fit(view,P.class_names[c.cls]or tostring(c.cls),14,tw-20),tx+12,D.top+20,tw-20,20,14,C.muted)
 end
 view:_sheet(cv,D.top+54)
 local noop=function()end
 local ghost=setmetatable({_jump=noop,_hit=noop,_ctl=noop},{__index=view})
 local function size(fn)return fn(ghost,D.canvas(),ch,0)end
 local function pair(fa,fb,y,ta,sa,tb,sb)local h=math.max(size(fa),size(fb));view:_card(cv,L,y,W,h,ta,sa);view:_card(cv,R,y,W,h,tb,sb);cv.z=5;fa(view,cv,ch,y);fb(view,cv,ch,y);return h end
 local y=D.top+54;local T=ch.tot
 local h=pair(id_card,down_card,y,ch.name,P.class_names[ch.cls],"What Downed You")
 head(cv,L,y,W,P.plural(#ch.runs,"Mission"))
 if #ch.enemies>0 and T.downs.v then head(cv,R,y,W,P.plural(T.downs.v,"Down")..", "..P.plural(T.deaths.v or 0,"Death"))end
 y=y+h+10;h=size(bests_card);view:_card(cv,L,y,D.width,h,"Bests");cv.z=5;bests_card(view,cv,ch,y);y=y+h+10
 pair(weapons_card,clears_card,y,"Weapons","By Missions Carried","Fastest Clears","Per Map And Difficulty")
 local any=false;for _,c in ipairs(ch.clears)do if c.st=="time"then any=true end end;if any then head(cv,R,y,W,"Minutes")end
 view:_sheet_end(cv)
end
