-- Information Overload: the Mission Board briefing, one map's record laid out over the mission details column.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Overview=mod:io_dofile(base.."io_overview")
local Records=mod:io_dofile(base.."records")
local Times=mod:io_dofile(base.."mission_times")
local I=mod:io_dofile(base.."player_identity")
local B={}
-- laid out in the mockup's own pixels, a 504 by 975 box over the 483-wide details column at 2000 wide
B.W,B.H=504,975
local function rgba(r,g,b,a)return {math.floor((a or 1)*255+.5),r,g,b}end
local C={rule=rgba(88,106,89),white=rgba(182,190,170),grey=rgba(117,136,119),bar=rgba(103,144,103),icon=rgba(152,255,180),gap=rgba(3,7,5),gold=rgba(232,198,102),black=rgba(0,0,0)}
B.C=C
local MED,REG,BOLD="mono_tide_medium","mono_tide_regular","mono_tide_bold"
local DASH=Overview.dash
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local DIFFS={sedition="Sedition",uprising="Uprising",malice="Malice",heresy="Heresy",damnation="Damnation",auric="Auric"}
local function day(ts)local _,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");return m and tonumber(d).." "..MONTHS[tonumber(m)]or DASH end
function B.diff(c)local l=Overview.diff_label(c);if l:find(" Maelstrom$")then return "Maelstrom"end;return l end
local function cls(id)return Overview.class_names[id]or Records.class_name(id)end
local function clear(run,basis)local c=run.context;local t=Times.build({run},c.mode,basis)[tostring(c.difficulty)];t=t and t[c.mission_name];if t then return t.completion_time.seconds,t.completion_time.source=="backend"end end
-- the timed wins set side by side: the server's times where any are recorded, the mission clock's only where none are
local function timed(runs)local backend=false;for _,r in ipairs(runs)do if r.won and r.time and r.backend then backend=true end end
 local out={};for _,r in ipairs(runs)do if r.won and r.time and r.backend==backend then out[#out+1]=r end end;return out end
-- the player's own useful damage, as Most Damage In A Mission counts it, so none for a match with no squad tally
local function damage(run)return (Records.run_useful(run))end
function B.clock(s)s=math.floor(s);return string.format("%d:%02d",math.floor(s/60),s%60)end
local function num(n)return Overview.commas(math.floor(n+.5))end
local function loc(key)if type(key)~="string"then return end;local ok,s=pcall(Localize,key);if ok and type(s)=="string"and s~=key and s~=""and not s:find("<unlocalized",1,true)then return s end end
local MissionTemplates,MissionTypes,Zones=require("scripts/settings/mission/mission_templates"),require("scripts/settings/mission/mission_types"),require("scripts/settings/zones/zones")
-- the designation is the last word with a digit in it: "Consignment Yard HL-17-36", "Warren 6-19"
function B.split(name)local a,b=tostring(name):match("^(.-)%s+(%S*%d%S*)$");if a and a~=""then return a,b end;return tostring(name),nil end
local function names(key,run,tracker)
 local t=MissionTemplates[key];local name,kind,zone
 if t then name=loc(t.mission_name);local ty=MissionTypes[t.mission_type];kind=ty and loc(ty.name)
  local z=Zones[t.zone_id];zone=z and loc(z.name);zone=zone and (zone:match('"([^"]+)"')or zone:match('“([^”]+)”')or zone)
 end
 local c=run.context;name=name or type(tracker.run_mission_name)=="function"and tracker:run_mission_name(c)or c.mission_display_name or key
 return name,kind,zone
end
-- one cause per down, picked as the Deaths page picks it; nil when the run kept no causes
local G,E
local KIND={special="special",boss="boss",environment="hazard"}
local OUT={down=true,down_to_death=true,direct_death=true}
local function events(run)
 local list,p=run.lethality_events,run.incidents and run.incidents.personal
 if not list then if not run.incidents or p and (p.downs or 0)+(p.deaths or 0)>0 then return nil end;return {}end
 G=G or mod:io_dofile(base.."enemy_grouping");E=E or mod:io_dofile(base.."enemy_catalog");local catalog=E.catalog()
 local out={}
 for _,e in ipairs(list)do if e.personal and OUT[e.outcome]then
  local s;for _,x in ipairs(e.sources or {})do if x.group~="environment"and x.group~="unknown"then s=x;break end end;s=s or (e.sources or {})[1]or {enemy="unknown_cause",group="unknown"}
  local entry=catalog[s.enemy]or {};local group=s.group or entry.group or "unknown"
  if group=="unknown"or s.enemy=="unknown_cause"or tostring(s.label):lower()=="unknown cause"then out[#out+1]={nil,"unknown",e.outcome}
  else local sub=s.subgroup or G.classify(s.enemy,group,entry.horde_type=="ranged"or s.horde_type=="ranged",s.attack_type)
   out[#out+1]={E.name(s.label or s.enemy),KIND[group]or (sub=="ranged"and "ranged"or "melee"),e.outcome}end
 end end
 return out
end
local function mate(c,id,p)return type(p)=="table"and not p.personal and tostring(id)~=tostring(c.character)and I.key(p)end
-- every counted mission by map, newest first, and each teammate's record with you over all maps; read once per history
function B.index(tracker)
 local maps,people={},{}
 for _,run in ipairs(Overview.runs(tracker))do local c=run.context;local key=c.mission_name
  if key then local l=maps[key];if not l then l={};maps[key]=l end;l[#l+1]=run end
  local seen,slot={},run.victory and 1 or 2
  for id,p in pairs(c.operative_roster or {})do local k=mate(c,id,p)
   if k and not seen[k]then seen[k]=true;local x=people[k];if not x then x={0,0};people[k]=x end;x[slot]=x[slot]+1 end end
 end
 return {maps=maps,people=people,tracker=tracker}
end
function B.map(index,key,basis)
 local list=index.maps[key];if not list or #list==0 then return nil end
 local name,kind,zone=names(key,list[1],index.tracker)
 local m={key=key,type=kind,zone=zone,runs={},won_with={}};m.base,m.desig=B.split(name)
 local byp,mates={},{}
 for _,run in ipairs(list)do local c=run.context;local ev=events(run);local time,backend=clear(run,basis)
  m.runs[#m.runs+1]={date=day(run.started_at),diff=B.diff(c),cls=cls(c.class),won=run.victory==true,time=time,backend=backend,dmg=damage(run),tracked=ev~=nil,events=ev or {},partial=run.full==false}
  if run.victory then for id,p in pairs(c.operative_roster or {})do local k=mate(c,id,p)
   if k and not byp[k]then local x={who=p.steam_name or p.friend_name or p.name or "Steam Name Unavailable",cls=cls(p.class),all=index.people[k]or {0,0}};byp[k]=x;mates[#mates+1]=x end end end
 end
 table.sort(mates,function(a,b)if a.all[1]~=b.all[1]then return a.all[1]>b.all[1]end;if a.all[2]~=b.all[2]then return a.all[2]<b.all[2]end
  local x,y=a.who:lower(),b.who:lower();if x~=y then return x<y end;return a.who<b.who end)
 m.won_with=mates;return m
end
-- the board's difficulty for a tile: Maelstrom on the Maelstrom tile, else the page the stepper is on
function B.board_diff(view,mission)
 if type(mission)=="table"and mission.category=="maelstrom"then return "Maelstrom"end
 local logic=view._mission_board_logic;if not logic or type(logic.get_current_page)~="function"then return nil end
 local page=logic:get_current_page();return type(page)=="table"and DIFFS[page.name]or nil
end

local WORDS={"one","two","three","four","five","six"}
local function word(n)if n==0 then return "no"end;return WORDS[n]or tostring(n)end
local function record(runs)local w=0;for _,r in ipairs(runs)do if r.won then w=w+1 end end;return w,#runs-w end
local KINDS={ranged={"Gunfire.","from ranged enemies","Ranged Enemy"},melee={"Up Close.","from melee enemies","Melee Enemy"},special={"Specials.","from specials","Special"},
 boss={"Bosses.","from bosses","Boss"},hazard={"The Map Itself.","from falls and hazards","Fall Or Hazard"}}
local ORDER={"ranged","melee","special","boss","hazard"}
local function verdict(m)
 local w,l=record(m.runs);local n=#m.runs;local s
 if l==0 then s=n==1 and "One run here, and you won it."or "You have won every run here."
 elseif w==0 then s=n==1 and "One run here, and it was lost."or "No wins here yet, from "..word(n).." runs."
 elseif w==l then s="An even record so far."elseif w>l then s="More wins than losses here."else s="More losses than wins here."end
 local by,order={},{};for _,r in ipairs(m.runs)do local c=by[r.cls];if not c then c={0,0};by[r.cls]=c;order[#order+1]=r.cls end;c[r.won and 1 or 2]=c[r.won and 1 or 2]+1 end
 local segs={{s}}
 for _,k in ipairs(order)do if by[k][1]>=2 and by[k][2]==0 then
  if l>0 then local n2=by[k][1];segs[2]={" "..k.." has won "..(n2==2 and "both of its runs"or "all "..word(n2).." of its runs"),bold=true};segs[3]={" here."}end;break end end
 return segs
end
-- what downs you here: the lead line, the four commonest causes and the rest, in the mockup's words
function B.downs(m)
 local tracked=0;local ev={}
 for _,r in ipairs(m.runs)do if r.tracked then tracked=tracked+1;for _,e in ipairs(r.events)do ev[#ev+1]=e end end end
 if tracked==0 then return nil end
 local d={tracked=tracked,of=#m.runs}
 if #ev==0 then d.none="Nothing downed you here in "..(tracked==1 and "the tracked run"or "the "..word(tracked).." tracked runs").."."return d end
 local byKind,byLabel,labels,unknown={},{},{},0
 for _,e in ipairs(ev)do if e[1]then byKind[e[2]]=(byKind[e[2]]or 0)+1;local b=byLabel[e[1]];if not b then b={n=0,kind=e[2]};byLabel[e[1]]=b;labels[#labels+1]=e[1]end;b.n=b.n+1 else unknown=unknown+1 end end
 local kinds={};for i,k in ipairs(ORDER)do if byKind[k]then kinds[#kinds+1]={k,i}end end
 table.sort(kinds,function(a,b)if byKind[a[1]]~=byKind[b[1]]then return byKind[a[1]]>byKind[b[1]]end;return a[2]<b[2]end)
 local top=kinds[1]and kinds[1][1];local tied={}
 if top then for _,k in ipairs(kinds)do if byKind[k[1]]==byKind[top]then tied[k[1]]=true;tied[#tied+1]=k[1]end end end
 if not top then d.head="Unknown Cause.";d.line=#ev==1 and "Your one down here was from an unknown cause."or "All "..#ev.." of your downs and deaths here were from an unknown cause."
 elseif #tied>1 then d.head="No Single Cause.";local p={};for _,k in ipairs(tied)do p[#p+1]=byKind[k].." "..KINDS[k][2]end;d.line=table.concat(p,", ").."."
 else d.head=KINDS[top][1];d.line=byKind[top].." of your "..#ev.." downs and deaths here "..(byKind[top]==1 and "was "or "were ")..KINDS[top][2].."."end
 table.sort(labels,function(a,b)local x,y=byLabel[a],byLabel[b];if x.n~=y.n then return x.n>y.n end
  local tx,ty=tied[x.kind]and 1 or 0,tied[y.kind]and 1 or 0;if tx~=ty then return tx>ty end;local la,lb=a:lower(),b:lower();if la~=lb then return la<lb end;return a<b end)
 local max=labels[1]and byLabel[labels[1]].n or 1
 d.bars={};d.rest={};local other=false
 for i,lab in ipairs(labels)do local b=byLabel[lab]
  if i<=4 then d.bars[#d.bars+1]={lab,b.n,b.n/max,tied[b.kind]==true};if not tied[b.kind]then other=true end end
 end
 if #labels>4 then local one=true;for i=5,#labels do if byLabel[labels[i]].n~=1 then one=false end end
  local p={};for i=5,#labels do p[#p+1]=one and labels[i]or labels[i].." "..byLabel[labels[i]].n end
  d.rest[#d.rest+1]={one and "1 Each:"or "Also",p}
 end
 if unknown>0 then d.rest[#d.rest+1]={"Unknown Cause "..unknown,{}}end
 if top then d.key=#tied>1 and "Tied Causes"or KINDS[top][3];d.other=other end
 return d
end
-- the stat cells, two to a row; an odd last cell spans the row
function B.stats(m)
 local w,l=record(m.runs);local cells={{"Won",math.floor(w/#m.runs*100+.5).."%",w.." Won, "..l.." Lost"}}
 local best,sum,list=nil,0,timed(m.runs)
 for _,r in ipairs(list)do sum=sum+r.time;if not best or r.time<best.time then best=r end end
 if best then cells[#cells+1]={"Best Clear",B.clock(best.time),best.diff.." · "..best.date,gold=true}
  if #list>1 then cells[#cells+1]={"Average Clear",B.clock(sum/#list),"Of "..#list.." Timed Wins"}end end
 local top;for _,r in ipairs(m.runs)do if r.dmg and (not top or r.dmg>top.dmg)then top=r end end
 if top then cells[#cells+1]={"Best Damage",num(top.dmg),top.cls.." · "..top.date.." · "..(top.won and "Won"or "Lost"),gold=true}end
 if #cells%2==1 then cells[#cells].wide=true end
 return cells
end

-- text that fits a width, cut with three dots
local function cut(s,size,font,w,ms)
 if ms(s,size,font)<=w then return s end
 while #s>0 and ms(s.."...",size,font)>w do repeat local b=s:byte(-1);s=s:sub(1,-2)until #s==0 or b<128 or b>=192 end
 return s.."..."
end
-- words of mixed runs filled into lines; a run marked bold is the white heading, and gap is the room after it
-- a space is the mono pitch the layout is drawn to
local function flow(segs,w,ms)
 local lines,cur,cw,gap={},{},0,0
 for _,sg in ipairs(segs)do local size,font,c=sg.size,sg.font,sg.c;local lead=sg[1]:match("^%s")~=nil;local first=true
  for wd in sg[1]:gmatch("%S+")do
   local sp=0;if #cur>0 then sp=(first and not lead)and gap or size*.555+(first and gap or 0)end
   local ww=ms(wd,size,font)
   if #cur>0 and cw+sp+ww>w then lines[#lines+1]=cur;cur={};cw=0;sp=0 end
   local last=cur[#cur]
   if last and not first then last.s=last.s.." "..wd;last.w=cw+sp+ww-last.x else cur[#cur+1]={s=wd,x=cw+sp,w=ww,size=size,font=font,c=c}end
   cw=cw+sp+ww;first=false
  end
  gap=sg.gap or 0
 end
 if #cur>0 then lines[#lines+1]=cur end
 return lines
end
-- the scene's spacing loosens with air, 0 to 1; nrun caps the run list
function B.layout(m,bd,rows,air,ms,nrun)
 local W,H=B.W,B.H;local ops={};local X,CW=23,458
 local function rect(x,y,w,h,c,z)ops[#ops+1]={r=true,x=x,y=y,w=w,h=h,c=c,z=z or 3}end
 local function text(s,x,y,w,h,size,c,font,align)ops[#ops+1]={s=s,x=x,y=y,w=w,h=h,size=size,c=c,f=font or MED,a=align or "left",z=4}end
 local function outline(x,y,w,h,c)rect(x,y,w,1,c);rect(x,y+h-1,w,1,c);rect(x,y+1,1,h-2,c);rect(x+w-1,y+1,1,h-2,c)end
 local function para(segs,y,lh)for _,line in ipairs(flow(segs,CW,ms))do for _,p in ipairs(line)do text(p.s,X+p.x,y,p.w,lh,p.size,p.c,p.font)end;y=y+lh end;return y end
 local function pad(fn)return function(y)y=fn(y+10+12*air);return y+12+12*air end end
 local function hd(y,a,b)text(a,X,y,CW,17,14,C.grey);if b then text(b,X,y,CW,17,14,C.grey,MED,"right")end;return y+17 end
 rect(0,0,W,H,C.gap,0)
 local runs=m.runs;local groups={}
 if rows.main then
  local function head(y)
   y=y+9+8*air;local t=cut(m.base,23,MED,CW,ms);local tw=ms(t,23,MED);text(t,X,y,tw,27,23,C.white)
   if m.desig and tw+9<CW then text(cut(m.desig,17,MED,CW-tw-9,ms),X+tw+9,y+2,CW-tw-9,27,17,C.grey)end;y=y+27
   local sub={};if m.type then sub[#sub+1]=m.type end;if m.zone then sub[#sub+1]=m.zone end
   if #sub>0 then text(cut(table.concat(sub," · "),15.5,MED,CW,ms),X,y,CW,20,15.5,C.grey);y=y+20 end
   return y+8+8*air
  end
  local function strip(y)
   local h=30+8*air;local n=#runs;text(n..(n==1 and " Run"or " Runs"),2,y,121,h,16,C.white,MED,"center");rect(123,y,2,h,C.rule,2)
   -- oldest of the last thirty on the left, as the run list reads upwards
   local k=math.min(n,30);local sx=143;local sw=W-2-18-sx;local w=(sw-4*(k-1))/k;local sy=y+(h-8)/2
   for i=1,k do local r=runs[k-i+1];local x=sx+(i-1)*(w+4);if r.won then rect(x,sy,w,8,C.bar)else outline(x,sy,w,8,C.bar)end end
   return y+h
  end
  local stats=pad(function(y)
   local cells=B.stats(m);local i=1;local first=true
   while cells[i]do if not first then y=y+10+10*air end;first=false
    local row={cells[i]};if not cells[i].wide and cells[i+1]then row[2]=cells[i+1]end;i=i+#row
    local rh=0;for j,c in ipairs(row)do local x,w=X,c.wide and CW or 229;if j==2 then x,w=X+229+23,206 end
     text(c[1],x,y,w,17,14,C.grey);text(cut(c[2],34,BOLD,w,ms),x,y+17,w,39,34,c.gold and C.gold or C.white,BOLD)
     local h=56;if c[3]then text(cut(c[3],14,MED,w,ms),x,y+56,w,17,14,C.grey);h=73 end;rh=math.max(rh,h)end
    if row[2]then rect(X+229,y,2,rh,C.rule,2)end;y=y+rh
   end
   return y
  end)
  groups[#groups+1]={head,strip,stats}
  local g2={}
  if bd then local at={};for _,r in ipairs(runs)do if r.diff==bd then at[#at+1]=r end end
   if #at>0 then local w,l=record(at)
    g2[#g2+1]=function(y)
     y=y+10+10*air;local iy=y+4.5
     -- the scene's chevrons, each stroke laid down in small squares close enough to read as one line
     for _,p in ipairs({{3,4,13,15,3,26},{14,4,24,15,14,26},{25,8,31,15,25,22}})do for s=0,1 do
      local x1,y1,x2,y2=p[1+s*2],p[2+s*2],p[3+s*2],p[4+s*2];local n=math.ceil(math.max(math.abs(x2-x1),math.abs(y2-y1))/.4)
      for t=0,n do rect(X+x1+(x2-x1)*t/n-1.6,iy+y1+(y2-y1)*t/n-1.6,3.2,3.2,C.icon)end end end
     text("Your Record "..(bd=="Maelstrom"and "In "or "At ")..bd,X+50,y,CW-50,17,14,C.grey);text(w.." Won, "..l.." Lost",X+50,y+17,CW-50,22,17,C.white)
     return y+39+10+10*air
    end
   end
  end
  local vs=verdict(m);for _,sg in ipairs(vs)do sg.size=16.5;sg.font=sg.bold and MED or REG;sg.c=sg.bold and C.white or C.grey end
  g2[#g2+1]=pad(function(y)return para(vs,y,21)end)
  groups[#groups+1]=g2
  local timedbest,tb,dmgbest;for _,r in ipairs(timed(runs))do if not timedbest or r.time<timedbest then timedbest,tb=r.time,r.backend end end
  for _,r in ipairs(runs)do if r.dmg and (not dmgbest or r.dmg>dmgbest)then dmgbest=r.dmg end end
  local lit=false;for _,r in ipairs(runs)do if r.diff==bd then lit=true end end
  groups[#groups+1]={pad(function(y)
   y=hd(y,"Runs, Newest First",lit and bd.." Highlighted"or nil)+4
   for i=1,math.min(#runs,nrun or #runs)do local r=runs[i];local rh=24+8*air;local on=r.diff==bd
    if on then for s=0,9 do rect(2+s*50,y,50,rh,rgba(88,106,89,.42-(.34*(s+.5)/10)),2)end end
    if r.won then rect(X,y+(rh-9)/2,9,9,C.bar)else outline(X,y+(rh-9)/2,9,9,C.bar)end
    local dim=on and C.white or C.grey
    text(r.date,X+16,y,58,rh,15,dim);text(r.diff,X+74,y,92,rh,15,C.white);local cl=cut(r.cls,15,MED,152,ms);text(cl,X+166,y,152,rh,15,dim)
    if r.partial then text("Partial",X+166+ms(cl,15,MED)+6,y,ms("Partial",15,MED),rh,15,C.rule)end
    text(r.won and (r.time and B.clock(r.time)or "Won")or "Lost",X+318,y,56,rh,15,r.time and r.time==timedbest and r.backend==tb and C.gold or C.white,MED,"right")
    text(r.dmg and num(r.dmg)or DASH,X+374,y,84,rh,15,r.dmg and r.dmg==dmgbest and #runs>1 and C.gold or C.white,MED,"right")
    y=y+rh
   end
   return y
  end)}
 end
 local d=rows.downs and B.downs(m)
 if d then groups[#groups+1]={pad(function(y)
  y=hd(y,"What Downs You Here",d.tracked.." Of "..d.of..(d.of==1 and " Run"or " Runs").." Tracked")
  if d.none then return para({{d.none,size=16.5,font=REG,c=C.grey}},y+6,21)end
  -- the cause and what it was made of share a line when they fit, otherwise the second starts a line of its own rather than wrapping in after it
  if ms(d.head,19,BOLD)+8+ms(d.line,16.5,REG)<=CW then y=para({{d.head,size=19,font=BOLD,c=C.white,gap=8},{d.line,size=16.5,font=REG,c=C.grey}},y+6,21)+7
  else y=para({{d.line,size=16.5,font=REG,c=C.grey}},para({{d.head,size=19,font=BOLD,c=C.white}},y+6,21),21)+7 end
  for _,b in ipairs(d.bars)do local rh=21+7*air;text(cut(b[1],15,MED,158,ms),X,y,158,rh,15,C.white)
   local fw=math.max(1,260*b[3]);if b[4]then rect(X+158,y+(rh-9)/2,fw,9,C.bar)else outline(X+158,y+(rh-9)/2,fw,9,C.bar)end
   text(tostring(b[2]),X+CW-34,y,34,rh,16,C.white,BOLD,"right");y=y+rh end
  y=y+6;local kw=0
  if d.key then kw=29+ms(d.key,14,MED)+(d.other and 29+ms("Other",14,MED)or 0)
   local kx,km=X+CW-kw,ms(d.key,14,MED);rect(kx+10,y+4.5,14,8,C.bar);text(d.key,kx+29,y,km,17,14,C.grey)
   if d.other then local ox=kx+29+km;outline(ox+10,y+4.5,14,8,C.bar);text("Other",ox+29,y,ms("Other",14,MED),17,14,C.grey)end end
  local lw=CW-kw-(kw>0 and 14 or 0);local ry=y
  -- names are kept whole; a line breaks only after a comma
  for _,rest in ipairs(d.rest)do local line=rest[1]
   for i,p in ipairs(rest[2])do local piece=p..(i<#rest[2]and ","or "");local try=line.." "..piece
    if ms(try,14,MED)>lw and line~=""then text(line,X,ry,lw,17,14,C.grey);ry=ry+17;line=piece else line=try end end
   text(line,X,ry,lw,17,14,C.grey);ry=ry+17 end
  return math.max(ry,d.key and y+17 or y)
 end)}end
 local mates=rows.mates and m.won_with
 if mates and #mates>0 then groups[#groups+1]={pad(function(y)
  y=hd(y,"Won Here With","Record Together, All Maps")+4
  for i=1,math.min(3,#mates)do local p=mates[i];local rh=23+7*air
   text(cut(p.who,15.5,MED,290,ms),X,y,290,rh,15.5,C.white);text(p.cls,X+300,y,104,rh,15.5,C.grey);text(p.all[1].."–"..p.all[2],X+404,y,54,rh,15.5,C.white,BOLD,"right");y=y+rh end
  if #mates>3 then local n={};for i=4,#mates do n[#n+1]=mates[i].who end;text(cut("And "..table.concat(n,", "),14,MED,CW,ms),X,y+4,CW,17,14,C.grey);y=y+21 end
  return y
 end)}end
 local y,gap=0,10+8*air
 for gi,g in ipairs(groups)do local top=y;local bg={r=true,x=0,y=top,w=W,h=0,c=C.black,z=1};ops[#ops+1]=bg;y=y+2
  for ci,child in ipairs(g)do if ci>1 then rect(2,y,W-4,2,C.rule,2);y=y+2 end;y=child(y)end
  y=y+2;local stop=y;if gi==#groups and y<H then y=H end;bg.h=y-top
  rect(0,top,W,2,C.rule,2);rect(0,y-2,W,2,C.rule,2);rect(0,top+2,2,y-top-4,C.rule,2);rect(W-2,top+2,2,y-top-4,C.rule,2)
  y=(gi==#groups and stop or y)+gap
 end
 return ops,#groups>0 and y-gap or 0,#groups
end
-- the loosest spacing that still fits, as the scene's fill() does, and only as many runs as fit when even the tightest does not
function B.fit(m,bd,rows,ms)
 local function try(a,n)local ops,h,g=B.layout(m,bd,rows,a,ms,n);return h<=B.H,ops,g,h end
 local ok,ops,g=try(1);if g==0 then return nil end;if ok then return ops end
 local n=#m.runs;local fits,_,_,h=try(0,n)
 -- a run row is 24 high at the tightest, so the overflow says how many to drop
 if not fits then n=math.max(3,n-math.ceil((h-B.H)/24));while n>3 and not try(0,n)do n=n-1 end end
 local lo,hi=0,1
 for _=1,6 do local mid=(lo+hi)/2;if try(mid,n)then lo=mid else hi=mid end end
 local _,best=try(lo,n);return best
end
return B
