-- Information Overload: Match History, the list of missions and their averages.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Data=mod:io_dofile(base.."io_data_missions")
local Records=mod:io_dofile(base.."records")
local Team=mod:io_dofile(base.."team_damage")
local Averages=mod:io_dofile(base.."history_averages")
local Times=mod:io_dofile(base.."mission_times")
local Patch=mod:io_dofile(base.."game_patch")
local C,DASH,fmt,one=D.c,Overview.dash,Data.fmt,Data.one
local PAGE,RH=100,26
local ARMOUR={unarmored="Unarmoured",disgustingly_resilient="Infested",berserker="Maniac",resistant="Unyielding",armored="Flak",super_armor="Carapace",unknown="Unknown"}
local COLS={date=108,id=246,map=304,diff=568,result=674,class=841,kills=1033,dmg=1147,time=D.right-20}
-- Right-aligned toolbar slots, derived from the content edge and shared widths.
local FILTER_X=D.left+D.width-280
local CLASS_X=FILTER_X-10-280
local MEASURE_X=CLASS_X-10-260
local function pct0(n,d)if not d or d<=0 then return DASH end;return (string.format("%.1f",100*n/d):gsub("%.0$","")).."%"end
local function card_h(n)return 52+n*26 end
local function state(view)
 local st=view.io_hist;if not st then st={sort="new",measure="average",f=Data.blank_filters(),page=1,fp={}};view.io_hist=st end
 st.measure=st.measure or "average"
 local s=view.scope or {};local key=tostring(s.mode)..":"..tostring(s.diff)..":"..tostring(s.patch)
 if st.key~=key then st.key=key;st.page=1;st.fp={}end
 return st
end
-- the filter panel: four lists over two rows, each list paged when it runs long
local function filters(view,popup,st,opts,matched,mode)
 local x0,y0,W=D.left,D.row2+38,D.width;local cw=W/4;local f=st.f
 local top={{"Result","res",opts.res,"one"},{"Date","date",opts.date,"one"},{"Your Class","cls",opts.cls,"one"},{"Team Had","team",opts.team,"all"}}
 local kept=0;for _,k in ipairs(opts.kinds)do if not f.kinds[k.v]then kept=kept+1 end end
 local bottom={{"Played With (All Of)","players",opts.players,"all"}}
 if mode=="havoc"then bottom[#bottom+1]={"Modifiers (All Of)","mods",opts.mods or {},"all"}end
 bottom[#bottom+1]={"Maps","maps",opts.maps,"except"};bottom[#bottom+1]={"Runs: "..kept.." Of "..#opts.kinds,"kinds",opts.kinds,"except"}
 local function most(list)local n=0;for _,s in ipairs(list)do n=math.max(n,#s[3])end;return math.max(1,n)end
 local nt=math.min(most(top),9);local th=44+RH*nt
 local nb=math.min(most(bottom),math.max(3,math.floor((660-50-th-44)/RH)));local bh=44+RH*nb;local h=th+bh+50
 view:_panel(popup,x0,y0,W,h)
 popup:rect(x0+1,y0+th,W-2,1,C.frame);popup:rect(x0+1,y0+th+bh,W-2,1,C.frame)
 local function block(list,by,n)
  for i,s in ipairs(list)do local cx=x0+(i-1)*cw;local title,key,items,how=s[1],s[2],s[3],s[4]
   if i>1 then popup:rect(cx,by+1,1,44+RH*n-2,C.frame)end
   popup:text(title,cx+12,by+6,cw-80,28,14,C.gold)
   local pages=math.max(1,math.ceil(#items/n));local p=math.min(st.fp[key]or 1,pages)
   if pages>1 then
    for j,dir in ipairs({"left","right"})do local bx=cx+cw-64+(j-1)*28;local ok=dir=="left"and p>1 or dir=="right"and p<pages
     view:_ctl(popup,"popup",bx,by+9,22,22,function()st.fp[key]=p+(dir=="left"and -1 or 1)end,{dis=not ok});popup:chevron(bx+8,by+15,dir,8,C.value,ok and 1 or .38)end
   end
   for r=1,n do local o=items[(p-1)*n+r];if not o then break end;local ry=by+36+(r-1)*RH
    if o.head then popup:text(o.head,cx+12,ry,cw-24,RH,14,C.muted)
    else
     local on;if how=="one"then on=f[key]==o.v elseif how=="all"then on=f[key][o.v]==true else on=not f[key][o.v]end
     if how=="one"and on then popup.z=2;popup:rect(cx+1,ry,cw-2,RH,C.on);popup:rect(cx+1,ry,3,RH,C.sel)end
     local ix=cx+12+(o.ind and 18 or 0)
     popup.z=3;popup:edges(ix,ry+6,14,14,1,on and C.sel or C.hover);if on then popup:rect(ix+3,ry+9,8,8,C.gold)end
     popup:text(o.label,ix+22,ry,cw-(ix-cx)-80,RH,16,how=="one"and on and C.gold_hi or C.value)
     popup:text(tostring(o.n or ""),cx+cw-72,ry,60,RH,14,C.muted,"right")
     view:_hit("popup",cx+1,ry,cw-2,RH,function()
      if how=="one"then f[key]=o.v elseif f[key][o.v]then f[key][o.v]=nil else f[key][o.v]=true end;st.page=1
     end,{bg=C.fill_h})
    end
   end
  end
 end
 block(top,y0,nt);block(bottom,y0+th,nb)
 local fy=y0+th+bh
 popup:text(matched..(matched==1 and " Run Matches"or " Runs Match"),x0+12,fy+8,400,34,14,C.muted)
 view:_ctl(popup,"popup",x0+W-226,fy+8,120,34,function()st.f=Data.blank_filters();st.fp={};st.page=1 end);popup:text("Clear All",x0+W-226,fy+8,120,34,16,C.value,"center")
 view:_ctl(popup,"popup",x0+W-96,fy+8,84,34,function()view.dd=nil end,{sel=true});popup:text("Done",x0+W-96,fy+8,84,34,16,C.gold_hi,"center")
end
local function tag(cv,x,y,win,w)
 local s=win and "Victory"or "Defeat";local c=win and C.gold or C.bad
 cv:edges(x,y+7,w,19,1,c,true);cv:text(s,x,y+7,w,19,14,c,"center");return w
end
-- the Filters button and its panel, shared by Runs and Averages
local function filter_button(view,cv,popup,st,rows,mode,matched)
 local nf=Data.filter_count(st.f);local open=view.dd=="io_hist_filters"
 view:_ctl(cv,"base",FILTER_X,D.row2,280,34,function()view.dd=not open and "io_hist_filters"or nil end,{open=open,sel=nf>0 and not open})
 cv:text("Filters"..(nf>0 and " ("..nf..")"or ""),FILTER_X+12,D.row2,220,34,16,nf>0 and C.gold_hi or C.value);cv:chevron(FILTER_X+256,D.row2+13,"down",10,C.value)
 if open then filters(view,popup,st,Data.options(rows,mode,view.scope.patch and Patch.display(view.scope.patch)or DASH,st.f,true),matched,mode)end
end
local function no_match(view,cv,st)
 view:_card(cv,D.left,D.sheet,D.width,110,"No Runs Match These Filters")
 view:_ctl(cv,"base",136,210,200,34,function()st.f=Data.blank_filters();st.page=1 end);cv:text("Clear Filters",136,210,200,34,16,C.value,"center")
end
local function runs(view,cv,popup,st,rows,mode)
 local f=st.f
 local sorts={};local shown="Newest";for _,s in ipairs(Data.sorts)do sorts[#sorts+1]={value=s[1],label=s[2],current=st.sort};if s[1]==st.sort then shown=s[2]end end
 Data.dropdown(view,cv,popup,"io_hist_sort",800,D.row2,200,"Sort:",shown,sorts,function(v)st.sort=v;st.page=1 end)
 local list=Data.apply(rows,f,mode,st.sort)
 filter_button(view,cv,popup,st,rows,mode,#list)
 view:_sheet(cv,D.sheet)
 if #list==0 then no_match(view,cv,st);return view:_sheet_end(cv)end
 local pages=math.ceil(#list/PAGE);st.page=math.max(1,math.min(st.page or 1,pages));local first=(st.page-1)*PAGE
 local mk,md=0,0;for i=first+1,math.min(first+PAGE,#list)do local r=list[i];mk=math.max(mk,r.kills or 0);md=math.max(md,r.dmg or 0)end
 -- one width for both tags, so the column of tags lines up
 local rw=math.max(view:_w("Victory",14),view:_w("Defeat",14))+14
 local y=D.sheet;local sorted={date=st.sort=="new"or st.sort=="old",kills=st.sort=="kills",dmg=st.sort=="dmg",time=st.sort=="fast"}
 local heads={{"date","Date","new"},{"id","Match"},{"map","Map"},{"diff","Difficulty"},{"result","Result"},{"class","Class"},{"kills","Kills","kills"},{"dmg","Damage","dmg"},{"time","Time","fast"}}
 for _,hd in ipairs(heads)do local key,label,sort=hd[1],hd[2],hd[3];local right=key=="kills"or key=="dmg"or key=="time"
  local w=view:_w(label,14);local x=right and COLS[key]-w or COLS[key];local on=sorted[key]
  cv:text(label,x,y,w+6,30,14,on and C.value or C.muted)
  if on then local ax=right and x-13 or x+w+6;for i=0,3 do local yy=st.sort=="old"and y+12+i or y+15-i;cv:rect(ax+3-i,yy,1+2*i,1,C.value,true)end end
  if sort then view:_hit("base",x-16,y,w+30,30,function()if key=="date"then st.sort=st.sort=="new"and "old"or "new"else st.sort=sort end;st.page=1 end,{under=C.value})end
 end
 cv:rect(D.left,y+29,D.width,1,C.frame,true)
 for i=first+1,math.min(first+PAGE,#list)do local r=list[i];local ry=y+30+(i-first-1)*32
  view:_hit("base",D.left,ry,D.width,32,function()view.io_params=view.io_params or {};view.io_params.run=r.id;view.io_tab="overview";if view.scroll then view.scroll.run=0 end;view:_go("run")end,{bg=C.row_h})
  local dw=view:_w(r.date,16);cv:text(r.date,COLS.date,ry,dw+4,32,16,C.label);cv:text(r.clock,COLS.date+dw+6,ry,60,32,14,C.muted)
  -- the match's own number, the one its page shows, so it can be found again
  cv:text("#"..tostring(r.id or DASH),COLS.id,ry,COLS.map-COLS.id-6,32,14,C.muted,"left",D.font.medium)
  cv:text(r.map,COLS.map,ry,COLS.diff-COLS.map-12,32,16,C.value);cv:text(view:_fit(r.diff,16,COLS.result-COLS.diff-6),COLS.diff,ry,COLS.result-COLS.diff-6,32,16,C.value)
  local tw=tag(cv,COLS.result,ry,r.win,rw);if r.partial then cv:text("Partial",COLS.result+tw+6,ry,80,32,13,C.muted,"left",D.font.medium)end
  cv:text(Overview.class_names[r.cls]or DASH,COLS.class,ry,150,32,16,C.value)
  cv:text(r.kills and Overview.commas(r.kills)or DASH,COLS.kills-150,ry,150,32,16,r.kills and C.value or C.muted,"right")
  cv:text(r.dmg and fmt(r.dmg)or DASH,COLS.dmg-150,ry,150,32,16,r.dmg and C.value or C.muted,"right")
  cv:text(r.secs and Times.format(r.secs)or DASH,COLS.time-150,ry,150,32,16,r.secs and C.value or C.muted,"right")
  if r.kills and mk>0 then local w=math.max(2,58*r.kills/mk);cv:rect(COLS.kills-w,ry+26,w,2,r.kills==mk and C.gold or C.hover,true)end
  if r.dmg and md>0 then local w=math.max(2,88*r.dmg/md);cv:rect(COLS.dmg-w,ry+26,w,2,r.dmg==md and C.gold or C.hover,true)end
  cv:rect(D.left,ry+31,D.width,1,C.line,true)
 end
 y=y+30+(math.min(first+PAGE,#list)-first)*32+8
 if pages>1 then
  for j,dir in ipairs({"left","right"})do local ok=dir=="left"and st.page>1 or dir=="right"and st.page<pages;local bx=j==1 and 100 or 330
   view:_ctl(cv,"base",bx,y,34,34,function()st.page=st.page+(dir=="left"and -1 or 1);if view.scroll then view.scroll[view.page]=0 end end,{dis=not ok});cv:chevron(bx+13,y+13,dir,8,C.value,ok and 1 or .38)
  end
  cv:text("Page "..st.page.." Of "..pages,140,y,184,34,16,C.label,"center");y=y+44
 end
 cv:text(#list.." of "..#rows.." "..(Overview.mode_names[mode]or "").." runs. Kills and Damage are yours. Time is the clear time; defeats, and wins with no timing data, show —.",D.left,y,D.width,24,14,C.muted,"left",D.font.medium)
 view:_sheet_end(cv)
end
-- a run the overview cache has not counted yet is counted here, one a draw, and kept on the view; the sum is kept until the runs, the history or the cache change
local function averaged(view,list,mode)
 local cache=mod.io_overview_cache and mod.io_overview_cache()or nil
 local ids={};for i,run in ipairs(list)do ids[i]=tostring(run.id)end
 local key=tostring(mode)..":"..view:_revision()..":"..tostring(cache)..":"..table.concat(ids,",")
 local memo=view.io_avg;if memo and memo.key==key then return memo.a,0 end
 local built=view.io_avg_built or setmetatable({},{__mode="k"});view.io_avg_built=built
 local have,left,wait=setmetatable({},{__index=cache}),1,0
 for i,run in ipairs(list)do local id=ids[i]
  if not (cache and cache[id])and not run.hidden_contributions then local row=built[run]
   if not row and left>0 then left=left-1;row=Averages.build({run},mode,Team,Records);built[run]=row end
   if row then have[id]=row else wait=wait+1 end
  end
 end
 local a=Averages.build(list,mode,Team,Records,have,true)
 if wait>0 then view.io_dirty=true else view.io_avg={key=key,a=a}end
 return a,wait
end
-- Filtered extrema reduce persisted per-match projections; rendering never opens detail to build extrema.
local function projected(view,list,mode,selection)
 local rows=mod.io_extrema_cache and mod.io_extrema_cache()
 local cache=mod.io_overview_cache and mod.io_overview_cache()
 if not rows or not cache then return nil end
 local ids={};for i,run in ipairs(list)do local id=tostring(run.id);if not rows[id]or not cache[id]then return nil end;ids[i]=id end
 local key=selection..":"..tostring(mode)..":"..view:_revision()..":"..tostring(rows)..":"..table.concat(ids,",")
 local memo=view.io_extrema;if memo and memo.key==key then return memo.a,memo.values end
 local a=Averages.build(list,mode,Team,Records,cache,true)
 local values=Averages.extremes(list,mode,rows,selection)
 view.io_extrema={key=key,a=a,values=values};return a,values
end
local function averages(view,cv,popup,st,rows,mode)
 -- Averages cover the runs the Runs filters keep; Your Class here is the filters' own class, so it narrows every card, not just yours.
 local selection=st.measure or "average"
 local label=selection=="highest"and "Max"or selection=="lowest"and "Min"or "Average"
 local metric_label=selection=="highest"and "Maximum"or selection=="lowest"and "Minimum"or "Average"
 local measures={{value="highest",label="Max",current=selection},{value="average",label="Average",current=selection},{value="lowest",label="Min",current=selection}}
 Data.dropdown(view,cv,popup,"io_hist_measure",MEASURE_X,D.row2,260,"Statistic:",label,measures,function(v)st.measure=v;st.page=1 end)
 local classes={};for _,c in ipairs(Data.class_order)do for _,r in ipairs(rows)do if r.cls==c then classes[#classes+1]=c;break end end end
 local cls=st.f.cls~="all"and st.f.cls or nil
 local opts={{value="all",label="Overall",current=cls or "all"}};for _,c in ipairs(classes)do opts[#opts+1]={value=c,label=Overview.class_names[c],current=cls or "all"}end
 Data.dropdown(view,cv,popup,"io_hist_cls",CLASS_X,D.row2,280,"Your Class:",cls and Overview.class_names[cls]or "Overall",opts,function(v)st.f.cls=v;st.page=1 end)
 local kept=Data.apply(rows,st.f,mode,"new");local nf=Data.filter_count(st.f)
 filter_button(view,cv,popup,st,rows,mode,#kept)
 if #kept==0 and nf>0 then return no_match(view,cv,st)end
 local list={};for _,r in ipairs(kept)do if selection=="average"or Averages.extreme_eligible(r.run)then list[#list+1]=r.run end end
 local a,wait,extremes=nil,0,nil
 if selection=="average"then a,wait=averaged(view,list,mode)
 else
  a,extremes=projected(view,list,mode,selection)
  if not a then view.io_dirty=true;view:_card(cv,D.left,D.sheet,D.width,92,"Preparing Saved Matches","Min/Max will be available after history preparation in the hub.");return end
 end
 if not a or (a.games or 0)==0 then view:_card(cv,D.left,D.sheet,D.width,92,wait>0 and "Counting Missions"or selection~="average"and "No Completed Missions"or "No Averages Yet");return end
 local function selected_value(key,average_value,format)
  local v,source
  if selection=="average"then v=average_value
  else v=extremes and extremes[key]or nil;source=extremes and extremes[key..".id"]or nil end
  return v~=nil and (format or fmt)(v)or DASH,source
 end
 local function value(key,n,d,format)return selected_value(key,d and d>0 and n/d or nil,format)end
 local function share(key,n,d)return value(key,n,d,function(v)return string.format("%.1f%%",100*v)end)end
 local played={};for _,c in ipairs(Data.class_order)do local p=a.personal[c];if p and (p.games or 0)>0 then played[#played+1]=c end end
 local you=cls and a.personal[cls]
 if not cls then you={damage=0,damage_games=0,defense={downs=0,deaths=0,pickups=0},defense_games=0}
  for _,p in pairs(a.personal)do you.damage=you.damage+(p.damage or 0);you.damage_games=you.damage_games+(p.damage_games or 0);you.defense_games=you.defense_games+(p.defense_games or 0);for k in pairs(you.defense)do you.defense[k]=you.defense[k]+((p.defense or {})[k]or 0)end end
 end
 local cn=cls and Overview.class_names[cls]or nil;local mn=Overview.mode_names[mode]or "";local as=cn and " As "..cn or ""
 view:_sheet(cv,D.sheet)
 local over=nf>0 and "the "..mn.." runs that match your filters"or "every "..mn.." run in this patch"
 local lead=selection=="average"and ("Averages over "..over..". Damage here is useful damage, without overkill.")or (metric_label.." per completed mission over "..over..". Damage here is useful damage, without overkill.")
 local cards={{wide=true,h=24,gap=6,draw=function(x,y,w)cv:text(lead,x,y,w,24,14,C.muted,"left",D.font.medium)end}}
 if wait>0 then cards[#cards+1]={wide=true,h=24,gap=6,draw=function(x,y,w)cv:text(string.format("Counting your missions, %d of %d.",#list-wait,#list),x,y,w,24,14,C.muted,"left",D.font.medium)end}end
 local function kv(title,rows,sub)if #rows>0 then cards[#cards+1]={h=card_h(#rows),draw=function(x,y,w)view:_card(cv,x,y,w,card_h(#rows),title,sub);Data.kv(view,cv,x,y+45,w,rows)end}end end
 local wins=0;for _,p in pairs(a.personal)do wins=wins+(p.wins or 0)end
 local g={{l="Games",v=tostring(a.games)},{l="Wins",v=wins.." ("..pct0(wins,a.games)..")"},{l="",v=""}}
 for _,c in ipairs(played)do local p=a.personal[c];g[#g+1]={l=Overview.class_names[c],v=p.wins.." Of "..p.games.." Won ("..pct0(p.wins,p.games)..")"}end
 kv("Games",g,cn and mn.." Runs"..as or "All "..mn.." Runs")
 if a.damage_games>0 then local team_value,team_source=value("damage",a.damage,a.damage_games,fmt);local t={{l=metric_label.." Team Damage",v=team_value,source_id=team_source}}
  if you and you.damage_games>0 then local personal_value,personal_source=value("personal.damage",you.damage,you.damage_games,fmt);t[#t+1]={l="Your "..metric_label.." Useful Damage"..as,v=personal_value,source_id=personal_source}end
  local by={};for c,v in pairs(a.classes)do if v.damage_games>0 and (v.damage>0 or selection~="average")then
   local share_sort=selection=="average"and (v.team_damage>0 and v.damage/v.team_damage or 0)or extremes and extremes["class."..c..".share"]or 0
   by[#by+1]={c=c,v=v,s=share_sort}
  end end
  table.sort(by,function(x,y)if x.s~=y.s then return x.s>y.s end;return x.c<y.c end)
  if #by>0 then t[#t+1]={head="By Class, Everyone In Your Teams"};t[#t+1]={note=selection=="average"and "Team Share (left) / Raw Damage (right); all operatives combined per mission."or "Share (left) / Raw (right), each its own mission."}
   for _,b in ipairs(by)do
    local class=b.c;local share_value,share_source=selected_value("class."..class..".share",b.v.team_damage>0 and b.v.damage/b.v.team_damage or 0,function(v)return string.format("%.1f%%",100*v)end)
    local raw_value,raw_source=value("class."..class..".damage",b.v.damage,b.v.damage_games,function(v)return Overview.compact(v):gsub("%.0([KM])$","%1")end)
    t[#t+1]={l=Overview.class_names[class]or class,parts={{v=share_value,source_id=share_source},{v=raw_value,source_id=raw_source}}}
   end
  end
  kv("Team Damage, Useful Only",t)
 end
 if a.damage>0 then local keys={};for k,n in pairs(a.armour)do if n>0 then keys[#keys+1]=k end end;table.sort(keys,function(x,y)return a.armour[x]>a.armour[y]end)
  local t={};for _,k in ipairs(keys)do local v,source=share("armour."..k,a.armour[k],a.damage);t[#t+1]={l=ARMOUR[k]or "Unknown",v=v,source_id=source}end
  kv(metric_label.." Armour Breakdown",t,selection=="average"and "Everyone In Your Teams, Useful Damage"or "Each share is its own extreme.")
 end
 if a.kill_games>0 then local k=a.kills
  local function cell(key,n,d)local v,source=value(key,n,d,one);return source and {v,source_id=source}or v end
  local t1={};for _,e in ipairs({{"horde","Trash Enemies"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"}})do t1[#t1+1]={e[2],cell("kills."..e[1],k[e[1]]or 0,a.kill_games)}end
  local t2={};if (a.role_games or 0)>0 then for _,e in ipairs({{"trash_ranged","Trash Enemies, Ranged"},{"trash_melee","Trash Enemies, Melee"},{"elite_ranged","Elites, Ranged"},{"elite_melee","Elites, Melee"}})do t2[#t2+1]={e[2],cell("kills."..e[1],k[e[1]]or 0,a.role_games)}end end
  local over=selection=="average"and (" Over "..a.kill_games..(a.kill_games==1 and " Mission"or " Missions"))or " Per Eligible Mission"
  local h=46+Data.table_h(#t1)+12+(#t2>0 and 40+Data.table_h(#t2)or 0)
  cards[#cards+1]={h=h,draw=function(x,y,w)view:_card(cv,x,y,w,h,metric_label.." Enemies Killed Per Game")
   local th=Data.table(view,cv,x,y+46,w,{{"Enemy"},{"Whole Team,"..over,w-35}},t1)
   if #t2>0 then local sy=y+46+th+6;cv:text("In Missions With Fixed Roles ("..a.role_games.." Of "..a.kill_games..")",x+36,sy,w-60,30,16,C.gold);Data.table(view,cv,x,sy+34,w,{{"Enemy"},{"Whole Team",w-35}},t2)end end}
 end
 local function defence(title,v,prefix)if v and (v.defense_games or 0)>0 then local t={};for _,e in ipairs({{"downs","Downs"},{"deaths","Deaths"},{"pickups","Pickups"}})do local n,source=value(prefix..e[1],v.defense[e[1]]or 0,v.defense_games,one);t[#t+1]={l=e[2],v=n,source_id=source}end;kv(title,t)end end
 defence(metric_label.." Team Defensive Stats",a,"defense.")
 defence("Your Defensive Stats"..as,you,"personal.defense.")
 for _,c in ipairs(Data.class_order)do defence(metric_label.." Defensive Stats For "..Overview.class_names[c],a.classes[c],"class."..c..".defense.")end
 local fr=a.friendly or {};if (fr.games or 0)>0 then local t={};for _,e in ipairs({{"damage","Damage Dealt"},{"murders","Murders"},{"suicides","Suicides"}})do local n=(fr[e[1]]or 0)/fr.games;if n>=0.05 or selection~="average"then local shown,source=value("friendly."..e[1],fr[e[1]]or 0,fr.games,one);t[#t+1]={l=e[2],v=shown,source_id=source}end end;kv(metric_label.." Team Friendly Fire",t)end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty or not view.scope then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 local st=state(view)
 view:_scope(cv,popup,m)
 -- the tab is a plain value on the view, so right click and forward step through it too
 local cur=view.io_hist_tab or "runs"
 local function tab(v)return function()if cur~=v then view.io_hist_tab=v~="runs"and v or nil;if view.scroll then view.scroll[view.page]=0 end end end end
 view.io_crumbs={{"Match History",cur~="runs"and tab("runs")or nil},{cur=="runs"and "Runs"or "All"}}
 local tx=100;for _,t in ipairs({{"runs","Runs"},{"avg","All"}})do local w=view:_w(t[2],16)+30;local sel=cur==t[1]
  view:_ctl(cv,"base",tx,D.row2,w,34,tab(t[1]),{sel=sel});cv:text(t[2],tx,D.row2,w,34,16,sel and C.gold_hi or C.value,"center");tx=tx+w+8 end
 -- the rows are kept until the runs or the scope change, or a mission's time is typed in, so the filter counts are not worked out again every draw
 local s=view.scope;local o=mod.io_display_options and mod.io_display_options()or {}
 local hk=table.concat({view:_revision(),tostring(s.mode),tostring(s.diff),tostring(s.patch),tostring(o.boss_map_timing)},"|")
 local hc=view.io_hist_rows;if not hc or hc.key~=hk then hc={key=hk,rows=Data.history(tracker,s)};view.io_hist_rows=hc end
 local rows=hc.rows
 if cur=="runs"then runs(view,cv,popup,st,rows,view.scope.mode)else averages(view,cv,popup,st,rows,view.scope.mode)end
end
