-- Information Overload: the Character Select screen, the picked operative's service record beside the model a mode at a time and the Account Wallet moved down beside Start.
return function(mod,api,collectors)
 local base="InformationOverload/scripts/mods/InformationOverload/"
 local M={id="charselect",name="Character Select",place="Main Menu",icon="charselect",rows={
  {key="charselect_record",label="Service Record",help="Missions won, kills and damage for the operative you pick, one mode at a time.",kind="toggle",default=true},
  {key="charselect_weapons",label="Weapons Taken Most",help="The weapons that operative takes out most.",kind="toggle",default=true},
  {key="charselect_downs",label="What Downs Them",help="What downs and grabs that operative most.",kind="toggle",default=true},
 }}
 local defaults={};for _,r in ipairs(M.rows)do defaults[r.key]=r.default end
 local function row(key)local v=mod:get(key);if v==nil then return defaults[key]end;return v==true end
 local function on()return mod:is_enabled()and mod:get("screen_charselect")~=false end
 local function record_on()return row("charselect_record")or row("charselect_weapons")or row("charselect_downs")end
 -- how far the wallet drops, in UI units, so its foot sits level with the title under the model
 M.wallet_drop=132
 local P
 local function people()P=P or mod:io_dofile(base.."io_data_people");return P end
 local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
 local function ymd(ts)local y,m,d=tostring(ts or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)");if y then return y,MONTHS[tonumber(m)],tonumber(d)end end
 local function span(a,b)
  local y1,m1,d1=ymd(a);local y2,m2,d2=ymd(b);if not y1 or not y2 then return nil end
  if y1~=y2 then return d1.." "..m1.." "..y1.." To "..d2.." "..m2.." "..y2 end
  if m1~=m2 then return d1.." "..m1.." To "..d2.." "..m2 end
  if d1~=d2 then return d1.." To "..d2.." "..m2 end;return d2.." "..m2
 end
 local GRABS={{"mutant_charges","Mutants"},{"pounces","Pox Hounds"},{"nets","Trappers"}}
 local GROUP,OUT={normal="horde",elite="elite",special="special",boss="boss"},{down=true,down_to_death=true,direct_death=true}
 local Enemies
 -- each down and death counted once for every enemy with a hand in it, by type, and the ranged and the melee enemy that did it most: a tie goes to the one that killed most, then the latest
 local function threats(runs)
  Enemies=Enemies or mod:io_dofile(base.."enemy_catalog");local cat=Enemies.catalog()
  local by,foes,n,at={horde=0,elite=0,special=0,boss=0},{},0,0
  for _,run in ipairs(runs)do for _,e in ipairs(run.lethality_events or {})do if e.personal and OUT[e.outcome]then at=at+1
   local seen={}
   for _,s in ipairs(e.sources or {})do local key=s.enemy or s.label;local entry=s.enemy and cat[s.enemy]or {};local g=GROUP[s.group or entry.group]
    if g and key and key~="unknown_cause"and not seen[key]then seen[key]=true;by[g]=by[g]+1;n=n+1
     local ht=s.horde_type or entry.horde_type
     if ht=="ranged"or ht=="melee"then local f=foes[key];if not f then f={name=Enemies.name(s.label or key),ht=ht,n=0,kills=0};foes[key]=f end
      f.n=f.n+1;if e.outcome~="down"then f.kills=f.kills+1 end;f.at=at end
    end
   end
  end end end
  if n==0 then return nil end
  local most={}
  for _,f in pairs(foes)do local m=most[f.ht];if not m or f.n>m.n or f.n==m.n and (f.kills>m.kills or f.kills==m.kills and f.at>m.at)then most[f.ht]=f end end
  return {by=by,ranged=most.ranged and {most.ranged.name,most.ranged.n},melee=most.melee and {most.melee.name,most.melee.n}}
 end
 -- the few figures the screen shows for one mode's missions; the Dossier's own model is dropped once read
 local function figures(runs)
  local f=people().figures(runs);local t=f.tot;local won,wins={},0
  for _,x in ipairs(f.won)do won[#won+1]={x.label,x.w,x.g};wins=wins+x.w end
  local ws={};for i=1,2 do local x=f.weapons[i];if x and #x.runs>1 then ws[#ws+1]={x.n,#x.runs}end end
  if #ws==0 and f.weapons[1]then ws[1]={f.weapons[1].n,#f.weapons[1].runs}end
  local kinds,grabs,top={},0,nil
  for _,run in ipairs(runs)do local p=run.incidents and run.incidents.personal
   if p then for _,g in ipairs(GRABS)do local n=tonumber(p[g[1]])or 0;kinds[g[1]]=(kinds[g[1]]or 0)+n;grabs=grabs+n end end end
  for _,g in ipairs(GRABS)do local n=kinds[g[1]]or 0;if n>0 and (not top or n>top[2])then top={g[2],n}end end
  return {n=#runs,span=span(f.first.started_at,f.last.started_at),wins=wins,won=won,kills=t.kills.v,dmg=t.dmg.v,weapons=ws,
   inc=t.downs.n,downs=t.downs.v or 0,deaths=t.deaths.v or 0,grabs=grabs,grab_top=top,threats=threats(runs)}
 end
 -- the record kept a mode at a time, Havoc and each other difficulty on its own, so one mode's figures never flatter another's:
 -- the mode played last first, then the rest by missions played, the latest played first on a tie
 local function slim(ch)
  local Pp=people();local by,list={},{}
  local function mode(run)local c=run.context;return c.mode=="havoc"and "Havoc"or Pp.mode_label(c)end
  for i,run in ipairs(ch.runs)do local key=mode(run);local g=by[key];if not g then g={name=key,runs={}};by[key]=g;list[#list+1]=g end;g.runs[#g.runs+1]=run;g.at=i end
  local last=mode(ch.runs[#ch.runs])
  table.sort(list,function(a,b)if (a.name==last)~=(b.name==last)then return a.name==last end;if #a.runs~=#b.runs then return #a.runs>#b.runs end;return a.at>b.at end)
  local modes={};for i,g in ipairs(list)do local r=figures(g.runs);r.name=g.name;modes[i]=r end
  return {cls=ch.cls,modes=modes}
 end
 local model,model_data,model_seq,model_n,model_rev
 function M.model()
  local tracker=api.dashboard_tracker and api.dashboard_tracker();local data=tracker and tracker.data;if not data then return nil end
  local seq,n,rev=data.run_sequence,#(data.run_history or {}),data.history_policy_revision
  if not model or data~=model_data or seq~=model_seq or n~=model_n or rev~=model_rev then
   local out={};for _,ch in ipairs(people().dossier(tracker).chars)do out[ch.id]=slim(ch)end
   model,model_data,model_seq,model_n,model_rev=out,data,seq,n,rev
  end
  return model
 end
 local lines,lines_key,cyc={},{},{}
 function M.reset()model,model_data,lines,lines_key,cyc=nil,nil,{},{},{}end
 local WHITE,GOLD,LABEL,SHADOW={255,218,228,210},{255,199,167,129},{255,117,126,110},{150,0,0,0}
 local function w(s)return "{#color(218,228,210)}"..s.."{#reset()}"end
 local function times(n)if n==1 then return w("Once")elseif n==2 then return w("Twice")end;return w(people().commas(n)).." Times"end
 -- one mode's record as lines of text centred under one axis, built once each when the operative, the rows or the scale change
 function M.lines(id,k,i)
  i=i or 1
  local r,wp,dn=row("charselect_record"),row("charselect_weapons"),row("charselect_downs")
  local m=M.model();local key=lines_key
  if not (key[1]==id and key[2]==r and key[3]==wp and key[4]==dn and key[5]==k and key[6]==m)then lines,lines_key={},{id,r,wp,dn,k,m}end
  if lines[i]then return lines[i]end
  -- only the modes with something to show under the rows that are on take a turn, so the cycle never lands on an empty one
  local all=m and m[tostring(id)];local list={}
  for _,x in ipairs(all and all.modes or {})do if r or wp and #x.weapons>0 or dn and x.inc>0 then list[#list+1]=x end end
  local rec=list[i];local Pp=people();local L,y={n=math.max(1,#list)},0
  -- the shadow keeps the size changes so it sits exactly under the text, and only the colours go
 local function add(t,size,h,c,dx)L[#L+1]={t=t,p=(t:gsub("{#color%([^)]*%)}","")),s=size,h=h,y=y,c=c,x=dx or 0}end
  local function gap()if #L>0 then y=y+18 end end
  if r then add("Service Record",35,36.5,WHITE);y=y+36.5 end
  -- the mode in gold under the title, then a dot for each mode when there is more than one to cycle through
  if rec then add(rec.name:upper(),23,29,GOLD);y=y+29
   if #list>1 then L.dots=y;y=y+30 end end
  if r then
   if not rec then add("No Missions On File Yet",23,30,LABEL);y=y+30
   else
    add(Pp.plural(rec.n,(Pp.class_names[all.cls]or "Operative").." Mission")..(rec.span and ", "..rec.span or ""),23,30,LABEL);y=y+48
    -- the three figures spread out once a count runs to seven characters, so a million kills never touches the damage beside it
    local kills,dmg=rec.kills and Pp.commas(rec.kills)or Pp.dash,rec.dmg and Pp.short(rec.dmg)or Pp.dash;local sp=(#kills>=7 or #dmg>=7)and 165 or 140
    add(rec.wins.."{#size("..math.floor(23*k+.5)..")}{#color(117,126,110)}/"..rec.n.."{#reset()}",35,36.5,WHITE,-sp)
    add(kills,35,36.5,WHITE);add(dmg,35,36.5,WHITE,sp);y=y+36.5
    add("Missions Won",23,30,LABEL,-sp);add("Kills",23,30,LABEL);add("Damage",23,30,LABEL,sp);y=y+35
    -- a mode of one difficulty already says it in Missions Won; Havoc splits by rank
    local parts={};if #rec.won>1 then for _,s in ipairs(rec.won)do parts[#parts+1]=w(s[2].."/"..s[3]).." On "..s[1]end end
    for i=1,#parts,2 do add(table.concat(parts,", ",i,math.min(i+1,#parts)),19,24,LABEL);y=y+24 end
   end
  end
  if wp and rec and #rec.weapons>0 then gap();add("Weapons Taken Most",23,29,GOLD);y=y+29
   for _,x in ipairs(rec.weapons)do add(x[1].." "..times(x[2]),19,24,LABEL);y=y+24 end end
  if dn and rec and rec.inc>0 then gap();add("What Downs Them",23,29,GOLD);y=y+29
   add((rec.downs>0 and "Downed "..times(rec.downs)or "Never Downed")..", "..(rec.deaths>0 and "Died "..times(rec.deaths)or "Never Died"),19,24,LABEL);y=y+24
   add(rec.grabs>0 and "Grabbed "..times(rec.grabs)..", "..w(tostring(rec.grab_top[2])).." By "..rec.grab_top[1]or "Never Grabbed",19,24,LABEL);y=y+24
   -- the four types side by side, then the ranged and the melee enemy that did it most
   local th=rec.threats
   if th then y=y+6
    for i,g in ipairs({{"horde","Horde"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"}})do add(Pp.commas(th.by[g[1]]),30,32,WHITE,(i-2.5)*115)end;y=y+32
    for i,g in ipairs({"Horde","Elites","Specials","Bosses"})do add(g,19,24,LABEL,(i-2.5)*115)end;y=y+29
    for _,k in ipairs({{"ranged","Most Ranged: "},{"melee","Most Melee: "}})do local f=th[k[1]];if f then add(k[2]..f[1].." "..w("x"..Pp.commas(f[2])),19,24,LABEL);y=y+24 end end
   end
  end
  L.H=y;lines[i]=L;return L
 end
 local Renderer,ALIGN
 local broken
 local function fail(err)broken=true;mod:error("I/O character select: %s",tostring(err))end
 -- the operative whose name block the game shows, if it shows one
 local function picked(view)
  if view._is_main_menu_open or view._profiles_wait_overlay_active or not view._character_details_active then return end
  local profile=view._selected_profile;local id=profile and profile.character_id
  local node=view._ui_scenegraph and view._ui_scenegraph.character_info;if id and node and node.world_position then return id,node end
 end
 local function shows(id)
  if row("charselect_record")then return true end
  local m=M.model();local all=m and m[tostring(id)]
  for _,rec in ipairs(all and all.modes or {})do if row("charselect_weapons")and #rec.weapons>0 or row("charselect_downs")and rec.inc>0 then return true end end
  return false
 end
 -- each mode shows for HOLD seconds and fades into the next over FADE
 local HOLD,FADE,TRACK=7,.7,{90,117,126,110}
 function M.cycle()return cyc end
 local function input_get(input,name)if not input then return nil end;local ok,v=pcall(input.get,input,name);if ok then return v end end
 local function body(view,renderer,dt,input)
  local id,node=picked(view);if not id then return end;local pos=node.world_position
  local k=renderer.scale or RESOLUTION_LOOKUP.scale or 1
  local m=M.model();local first=M.lines(id,k,1);if #first==0 then return end;local n=first.n
  if cyc.id~=id or cyc.n~=n or cyc.m~=m then cyc={id=id,n=n,m=m,i=1,t=0}end
  local L=M.lines(id,k,cyc.i)
  Renderer=Renderer or require("scripts/managers/ui/ui_renderer")
  if not ALIGN then ALIGN={horizontal_alignment=Gui.HorizontalAlignCenter,vertical_alignment=Gui.VerticalAlignCenter}end
  local cx,top=pos[1]+(node.size and node.size[1]or 500)/2,44
  -- the class emblem sits at the top of the name block, so a record too tall for the room above it is drawn smaller to end clear of it,
  -- one size for every mode so it keeps its size as it fades between them
  local H=0;for j=1,n do H=math.max(H,M.lines(id,k,j).H or 0)end
  local fit=math.min(1,(pos[2]-8-top)/math.max(1,H))
  -- the mouse on the record holds the mode; a dot clicked shows its mode and the cycle carries on from there
  -- a mouse left resting on the record while a controller plays holds nothing
  local ui=Managers.ui;local cur=input_get(input,"cursor");if ui and ui.using_cursor_navigation and not ui:using_cursor_navigation()then cur=nil end;local mx,my=cur and cur[1]/k,cur and cur[2]/k
  local over=mx~=nil and math.abs(mx-cx)<=260*fit and my>=top and my<=top+H*fit
  local hot,dy;if n>1 and L.dots then dy=top+(L.dots+9)*fit
   for j=1,n do local dx=cx+(j-(n+1)/2)*26*fit;if mx and math.abs(mx-dx)<=12*fit and math.abs(my-dy)<=12*fit then hot=j end end end
  -- going back to the mode fading out turns the fade round where it stands rather than jumping
  local function go(j)if j~=cyc.i then if cyc.from==j then cyc.from,cyc.f=cyc.i,FADE-cyc.f else cyc.from,cyc.f=cyc.i,0 end end;cyc.i,cyc.t=j,0 end
  -- a fade under way goes on before a new one can start, so the frame that starts one starts it from the old mode at full strength
  if cyc.from then cyc.f=cyc.f+(dt or 0);if cyc.f>=FADE then cyc.from=nil end end
  if hot and input_get(input,"left_pressed")==true then go(hot)end
  if n>1 and not over then cyc.t=cyc.t+(dt or 0);if cyc.t>=HOLD then go(cyc.i%n+1)end end
  local function sized(t)if fit>=1 then return t end;return (t:gsub("{#size%((%d+)%)}",function(s)return "{#size("..math.floor(s*fit+.5)..")}"end))end
  -- a mode fading in or out takes its inline colours down with it
  local function faded(t,a)if a>=1 then return t end;return (t:gsub("{#color%((%d+),(%d+),(%d+)%)}",function(r,g,b)return "{#color("..r..","..g..","..b..","..math.floor(255*a+.5)..")}"end))end
  local tint={0,0,0,0};local function col(c,a)tint[1],tint[2],tint[3],tint[4]=c[1]*a,c[2],c[3],c[4];return tint end
  local function lay(Lx,a)if a<=0 then return end
   for _,l in ipairs(Lx)do local x,y,s,h=cx+l.x*fit-300,top+l.y*fit,math.max(1,l.s*k*fit),l.h*fit
    Renderer.draw_text(renderer,sized(l.p),s,"proxima_nova_bold",Vector3(x+1,y+2,40),Vector2(600,h),col(SHADOW,a),ALIGN)
    Renderer.draw_text(renderer,faded(sized(l.t),a),s,"proxima_nova_bold",Vector3(x,y,41),Vector2(600,h),col(l.c,a),ALIGN)
   end
  end
  local p=cyc.from and math.min(1,cyc.f/FADE)or 1
  if cyc.from then lay(M.lines(id,k,cyc.from),1-p)end;lay(M.lines(id,k,cyc.i),p)
  -- the dots stay put while the modes fade under them, and the line under them fills until the next mode
  if dy then
   for j=1,n do local dx=cx+(j-(n+1)/2)*26*fit;local c=j==cyc.i and GOLD or j==hot and WHITE or LABEL
    Renderer.draw_circle(renderer,Vector3(dx,dy,41),(j==cyc.i and 5.6 or 4.5)*fit,nil,c)end
   local ly=dy+12*fit;Renderer.draw_rect(renderer,Vector3(cx-60*fit,ly,40),Vector2(120*fit,2*fit),TRACK)
   Renderer.draw_rect(renderer,Vector3(cx-60*fit,ly,41),Vector2(120*fit*math.min(1,cyc.t/HOLD),2*fit),GOLD)
  end
 end
 function M.draw(view,renderer,dt,input)
  if broken or not renderer or not on()or not record_on()then return end
  local ok,err=pcall(body,view,renderer,dt,input);if not ok then fail(err)end
 end
 -- the game's wallet keeps its look and moves down beside Start while the screen is on, with no switch of its own; off, it goes back where the game put it
 local moved=setmetatable({},{__mode="k"})
 local function place(view)
  local want=on()and M.wallet_drop or 0
  if want==(moved[view]or 0)or not view._wallet_element then return end
  view:_set_scenegraph_position("wallet_element_pivot",nil,want)
  view:_update_element_position("wallet_element_pivot",view._wallet_element,true)
  moved[view]=want
 end
 -- the mod turned off stops its hooks, so every wallet it moved goes back where the game put it at once
 function M.off()for v in pairs(moved)do pcall(place,v)end end
 -- the news card is left out only while the record has the right side, and keeps the game's own visibility otherwise
 local function news_off(view)
  if broken or not on()or not record_on()then return nil end
  local id=picked(view);if not id or not shows(id)then return nil end
  local news=view._news_element;if not news or news._visible==false then return nil end
  news._visible=false;return news
 end
 local function news_back(news)if news and news._visible==false then news._visible=true end end
 local function hidden(view)local ok,news=pcall(news_off,view);if ok then return news end;fail(news)end
 mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view",function(MainMenuView)
  if MainMenuView.io_charselect==M then return end;MainMenuView.io_charselect=M
  mod:hook(MainMenuView,"update",function(func,self,...)
   local news=hidden(self);local a,b=func(self,...);news_back(news)
   if not broken then local ok,err=pcall(place,self);if not ok then fail(err)end end
   return a,b
  end)
  mod:hook(MainMenuView,"_draw_elements",function(func,self,...)local news=hidden(self);func(self,...);news_back(news)end)
  mod:hook_safe(MainMenuView,"_draw_widgets",function(self,dt,_,input,renderer)M.draw(self,renderer,dt,input)end)
  mod:hook_safe(MainMenuView,"on_exit",function()M.reset()end)
 end)
 return M
end
