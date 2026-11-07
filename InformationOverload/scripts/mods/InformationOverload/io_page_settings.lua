-- Information Overload: Settings, bound to the mod's own saved options.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local P=mod:io_dofile(base.."io_data_people")
local Overview=mod:io_dofile(base.."io_overview")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local I=mod:io_dofile(base.."player_identity")
local FriendStats=mod:io_dofile(base.."friend_stats")
local S=mod:io_dofile(base.."scoreboard")
local Screens=mod:io_dofile(base.."io_page_screens")
local Backup=mod:io_dofile(base.."statistics_backup")
local C,F=D.c,D.font
local X,W=D.left,D.width
local RX=X+W-27
local function opts()return mod.io_display_options and mod.io_display_options()or {}end
local function set_opt(k,v)if mod.io_set_display_option then mod.io_set_display_option(k,v)end end
local function popup(title,body,label,fn)
 if not (Managers.event and Managers.event.trigger)then return fn()end
 Managers.event:trigger("event_show_ui_popup",{title_text_unlocalized=title,description_text_unlocalized=body,
  options={{text=label,no_localization=true,close_on_pressed=true,callback=function()if mod.io_current()then fn()end end},{text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back"}}})
end
local function row(view,cv,y,title,desc,msg,ctl,indent)
 local x=X+(indent or 0);cv:rect(X+1,y,W-14,1,C.line,true)
 local lines=type(desc)=="table"and desc or desc and P.wrap(view,desc,14,1000,F.medium)or {}
 local sub=#lines>0 or msg~=nil
 cv:text(title,x+36,y+(sub and 8 or 0),700,sub and 24 or 55,indent and 14 or 16,indent and C.label or C.value)
 local ty=y+30
 for i,l in ipairs(lines)do cv:text(l,x+36,ty,1000,22,14,i==lines.hi and C.value or C.muted,"left",F.medium);ty=ty+22 end
 if msg then cv:text("“"..msg.."”",x+36,ty,900,22,14,C.label,"left",F.medium);ty=ty+22 end
 local h=sub and ty-y+10 or 55
 if ctl then ctl(y,h)end
 return h
end
local function toggle(view,cv,on,fn)return function(y,h)P.toggle(view,cv,RX-46,y+math.floor((h-24)/2),on,fn)end end
local function button(view,cv,w,label,fn,o)return function(y,h)P.button(view,cv,RX-w,y+math.floor((h-34)/2),w,34,label,fn,o)end end
local function note(cv,y,text)cv:text(text,X+36,y,1100,22,14,C.muted,"left",F.medium)end
local function display(view,cv,popup_cv,y)
 local o=opts();local rows={}
 local h=45
 local fmt={{value="compact",label="Compact K/M"},{value="separators",label="Full Numbers"}}
 local cur=o.numbers=="separators"and "separators"or "compact";for _,v in ipairs(fmt)do v.current=cur end
 h=h+row(view,cv,y+h,"Number Format","Compact shows 12.3K and 1.2M, Full Numbers shows every digit.",nil,function(ry,rh)
  P.select(view,cv,popup_cv,"set_numbers",RX-280,ry+14,280,cur=="separators"and "Full Numbers"or "Compact K/M",fmt,function(v)set_opt("numbers",v)end)end)
 local fav=o.favorite_class;local classes={{value="none",label="None",current=fav or "none"}}
 for _,c in ipairs(Nav.classes)do classes[#classes+1]={value=c,label=Overview.class_names[c]or c,current=fav or "none"}end
 h=h+row(view,cv,y+h,"Favourite Class","Marked in the Overview classes table.",nil,function(ry)
  P.select(view,cv,popup_cv,"set_favourite",RX-280,ry+14,280,fav and Overview.class_names[fav]or "None",classes,function(v)set_opt("favorite_class",v~="none"and v or nil)end)end)
 local leave=Nav.show_leave_abuse()
 h=h+row(view,cv,y+h,"Name Leave Abusers","Lists who left and rejoined in Havoc to escape a Trapper net, a knock-off or a death, under Team › Fun. Off shows counts only.",nil,
  toggle(view,cv,leave,function()mod:set("show_leave_abuse",not leave,true)end))
 local pm=mod:get("preferred_mode");pm=(pm=="non-havoc"or pm=="last")and pm or "havoc"
 local modes={{value="havoc",label="Havoc",current=pm},{value="non-havoc",label="Non-Havoc",current=pm},{value="last",label="Last Game",current=pm}}
 h=h+row(view,cv,y+h,"Preferred Mode","The mode every page starts on. Last Game starts on the mode of your last mission.",nil,function(ry)
  P.select(view,cv,popup_cv,"set_mode",RX-280,ry+14,280, pm=="non-havoc"and "Non-Havoc"or pm=="last"and "Last Game"or "Havoc",modes,function(v)mod:set("preferred_mode",v,true)end)end)
 local keep=mod:get("keep_page_place")==true
 h=h+row(view,cv,y+h,"Pages Keep Your Place","Moving to another page and back keeps where you were inside it. Off, a page always opens at its start. Clicking the page you are on takes you to its start either way.",nil,
  toggle(view,cv,keep,function()mod:set("keep_page_place",not keep,true)end))
 h=h+row(view,cv,y+h,"Mission Timer","The mission clock in the top left while you play.",nil,toggle(view,cv,o.mission_timer==true,function()set_opt("mission_timer",not o.mission_timer)end))
 return h+10,"Display"
end
-- a screen's own rows, drawn from what its module lists; a row's default stands until it is changed
local function screen_rows(view,cv,popup_cv,y,h,id,skip)
 local m=mod.io_screens and mod.io_screens[id]
 if not m then if not skip then note(cv,y+h+8,"Nothing to set here yet.");h=h+38 end;return h end
 for _,r in ipairs(m.rows or {})do if not (skip and skip[r.key])then local v=mod:get(r.key);if v==nil then v=r.default end
  if r.kind=="select"then local list,shown={},tostring(v)
   for _,c in ipairs(r.choices or {})do list[#list+1]={value=c.value,label=c.label,current=v};if c.value==v then shown=c.label end end
   h=h+row(view,cv,y+h,r.label,r.help,nil,function(ry)P.select(view,cv,popup_cv,"set_"..r.key,RX-280,ry+14,280,shown,list,function(x)mod:set(r.key,x,true)end)end)
  else h=h+row(view,cv,y+h,r.label,r.help,nil,toggle(view,cv,v==true,function()mod:set(r.key,v~=true,true)end))end
 end end
 return h
end
local NAME={};for _,s in ipairs(Screens.list)do NAME[s.id]=s.name end
local function screen_tab(id)return function(view,cv,popup_cv,y)return screen_rows(view,cv,popup_cv,y,45,id)+10,NAME[id]end end
local function endscreen(view,cv,popup_cv,y)
 local rating=mod:get("hide_match_rating")==true;local h=screen_rows(view,cv,popup_cv,y,45,"endscreen",{})
 h=h+row(view,cv,y+h,"Hide Mission Rating","Hides the thumbs up and down on the end screen that ask you to rate the mission.",nil,
  toggle(view,cv,rating,function()mod:set("hide_match_rating",not rating,true)end))
 return h+10,NAME.endscreen
end
local function buttons(view,cv,list)return function(y,h)local x=RX;for i=#list,1,-1 do local b=list[i];x=x-b[2];P.button(view,cv,x,y+math.floor((h-34)/2),b[2],34,b[1],b[3]);x=x-10 end end end
local function pct(n)return string.format("%.0f%%",100*n)end
-- the outline of a scoreboard layout, drawn on a 200 by 110 grid and fitted to the right of the box given; gold is your own row
local INK,INK2={255,91,106,82},{255,63,76,57}
local FIRST={30,22,16,12}
local function outline(cv,layout,x,y,w,h)
 local k=math.min(w/200,h/110);local ox,oy=x+w-200*k,y+(h-110*k)/2
 local function r(a,b,c,d,col)cv:rect(ox+a*k,oy+b*k,c*k,d*k,col)end
 local function box(a,b,c,d,col)cv:edges(ox+a*k,oy+b*k,c*k,d*k,math.max(1,1.5*k),col)end
 if layout=="table"then
  for i=0,3 do local ry,you=16+i*22,i==0
   if you then r(0,ry,3,16,C.gold)end;r(8,ry+3,you and 52 or 46,5,you and C.gold or INK);r(8,ry+11,30,3,INK2)
   for j=0,4 do r(78+j*24,ry+4,16,7,j==0 and you and C.gold or INK)end
   if i<3 then r(8,ry+19,192,1/k,INK2)end
  end
 elseif layout=="cards"then
  for i=0,3 do local cx,you=i*50,i==0;local c=you and C.gold or INK
   box(cx+1,1,44,106,c);r(cx+6,8,26,5,c);r(cx+6,24,30,11,c);r(cx+6,42,FIRST[i+1],3,you and C.gold or INK2)
   for j=0,3 do r(cx+6,56+j*11,16,3,INK2);r(cx+28,55+j*11,10,5,INK)end
  end
 elseif layout=="strip"then
  local x0=118;box(x0,1,80,108,INK);r(x0+6,7,36,6,INK)
  for i=0,3 do local ry,you=22+i*21,i==0;local c=you and C.gold or INK
   if you then r(x0+2,ry,2,17,C.gold)end;r(x0+6,ry+2,28,4,c);r(x0+54,ry+1,20,6,c);r(x0+6,ry+10,FIRST[i+1]*2,2.5,you and C.gold or INK2);r(x0+6,ry+15,54,2,INK2)
  end
 end
end
-- the chosen layout is outlined in the row's empty middle, and while its picker is open the one under the pointer; Off shows nothing
local function peek(view,cv,id,current,y,h)
 local hv=view.dd==id and type(view.io_hkey)=="string"and view.io_hkey:match("^"..id.."|(%a+)$")
 outline(cv,hv or current,RX-280-40-170,y+10,170,h-20)
end
-- where each sits, as the share of the screen to its left and above it; Move shows its scene, the key held or the Esc menu
local function places(view,cv,y,h,o,list)
 local sw,sh=view:_screen();local layout=o.layout=="off"and "cards"or o.layout
 local get=function(key)return mod:get(key)end;local key=get("dashboard_key");local tab_key=key==nil or type(key)=="table"and key[1]=="tab"and key[2]==nil
 local sb=mod.io_scoreboard;local live=sb and sb.live and sb.live();local n=live and #live.squad>0 and #live.squad or 4
 for _,e in ipairs(list)do local k=S.KEYS[e[1]]
  -- the box Move shows for it
  local below=e[1]=="squad"and sb and sb.tab_below and sb.tab_below(sw,sh,function(_,s,size,font)return view:_w(s,size,font)end)
  local b=S.move_boxes(e[1],o,tab_key,layout,n,sw,sh,get,below)[1];local x,yy=b.x,b.y
  local desc=(mod:get(k[1])==nil and "Starts "or "Moved to ")..pct(x/sw).." from the left and "..pct(yy/sh).." from the top."
  h=h+row(view,cv,y+h,e[2],desc,nil,buttons(view,cv,{{"Move",110,function()view.io_move=e[1];view.dd=nil end},{"Reset",110,function()mod:set(k[1],nil);mod:set(k[2],nil,true)end}}))
 end
 return h
end
-- what a tap and a hold of I/O's key do, on the Scoreboard tab, or on the Tracker tab while the Scoreboard screen is off
local function key_row(view,cv,popup_cv,y,o)
 local list,shown={},S.KEY_MODES[1][2];for _,l in ipairs(S.KEY_MODES)do list[#list+1]={value=l[1],label=l[2],current=o.key};if l[1]==o.key then shown=l[2]end end
 return row(view,cv,y,"I/O's Key In Missions",{"What a tap and a hold of I/O's key do in a mission.",o.own_key and "A Scoreboard Key is bound in Mod Options, so it shows the scoreboard and I/O's key only opens the panel."or "Uses I/O's key unless a Scoreboard Key is bound in Mod Options."},nil,function(ry)
  P.select(view,cv,popup_cv,"set_scoreboard_key",RX-360,ry+14,360,shown,list,function(v)mod:set("scoreboard_key_mode",v,true)end)end)
end
local function scoreboard(view,cv,popup_cv,y)
 local o=S.options(function(k)return mod:get(k)end);local h=45
 local list,shown={},"Squad Cards";for _,l in ipairs(S.LAYOUTS)do list[#list+1]={value=l[1],label=l[2],current=o.layout};if l[1]==o.layout then shown=l[2]end end
 local elist,eshown={},"Squad Cards";for _,l in ipairs(S.LAYOUTS)do elist[#elist+1]={value=l[1],label=l[2],current=o.end_layout};if l[1]==o.end_layout then eshown=l[2]end end
 h=h+key_row(view,cv,popup_cv,y+h,o)
 local rh=row(view,cv,y+h,"Scoreboard In Missions","Shown in a mission by the key, as set above.",nil,function(ry)
  P.select(view,cv,popup_cv,"set_scoreboard",RX-280,ry+14,280,shown,list,function(v)mod:set("scoreboard_layout",v,true)end)end)
 peek(view,cv,"set_scoreboard",o.layout,y+h,rh);h=h+rh
 rh=row(view,cv,y+h,"Scoreboard On The End Screen","Shown on the end screen by the key, as set above.",nil,function(ry)
  P.select(view,cv,popup_cv,"set_scoreboard_end",RX-280,ry+14,280,eshown,elist,function(v)mod:set("scoreboard_end_layout",v,true)end)end)
 peek(view,cv,"set_scoreboard_end",o.end_layout,y+h,rh);h=h+rh
 h=h+row(view,cv,y+h,"Extra Stats","Adds boss damage, weakspots hit, critical hits and kills by kind to the Squad Table and Squad Cards.",nil,toggle(view,cv,o.extra,function()mod:set("scoreboard_extra",not o.extra,true)end))
 h=places(view,cv,y,h,o,{{"squad","Squad Position","held"}})
 h=screen_rows(view,cv,popup_cv,y,h,"scoreboard",{scoreboard_layout=true,scoreboard_end_layout=true})
 return h+10,NAME.scoreboard
end
local function tracker_tab(view,cv,popup_cv,y)
 local o=S.options(function(k)return mod:get(k)end);local h=45
 if not Screens.on("scoreboard")then h=h+key_row(view,cv,popup_cv,y+h,o)end
 h=h+row(view,cv,y+h,"Tracker Panel","Your mission time, kill streak, downs and kills beside the Esc menu.",nil,toggle(view,cv,o.esc,function()mod:set("scoreboard_esc",not o.esc,true)end))
 h=h+row(view,cv,y+h,"Tracker Panel On Held","Adds the Esc menu's Tracker Panel to the scoreboard's keybind.",nil,toggle(view,cv,o.this_mission,function()mod:set("scoreboard_this_mission",not o.this_mission,true)end))
 h=h+row(view,cv,y+h,"While Dead","'Tracker Panel' while you wait to be rescued.",nil,toggle(view,cv,o.dead,function()mod:set("scoreboard_dead",not o.dead,true)end))
 h=h+row(view,cv,y+h,"On The End Screen","The Tracker Panel above the squad when the key is held on the End Screen.",nil,toggle(view,cv,o.end_tm,function()mod:set("scoreboard_end_tm",not o.end_tm,true)end))
 h=places(view,cv,y,h,o,{{"tm","Tracker Panel Position","held"},{"tm_esc","Tracker Panel Position In The Esc Menu","esc"}})
 h=screen_rows(view,cv,popup_cv,y,h,"tracker",{scoreboard_this_mission=true,scoreboard_esc=true,scoreboard_dead=true,scoreboard_end_tm=true})
 return h+10,NAME.tracker
end
local function counting(view,cv,popup_cv,y)
 local o=opts();local policy=mod.io_history_policy and mod.io_history_policy()or {}
 note(cv,y+45,"These change what counts toward records and streaks. Statistics are rebuilt once you are back in the Mourningstar.");local h=72
 for _,e in ipairs({{"late_join","Late-Join Partial Missions","Missions you joined after they started."},{"rejoined","Rejoined Partial Missions","Missions you left and came back to."},{"early_leave","Early-Leave Missions","Missions you left before the end."}})do
  h=h+row(view,cv,y+h,e[2],e[3],nil,toggle(view,cv,policy[e[1]]~=false,function()if mod.io_toggle_history_policy then mod.io_toggle_history_policy(e[1])end end))
 end
 h=h+row(view,cv,y+h,"Boss Maps: Time To The Boss Death","On boss maps, the clear time stops when the final boss dies.",nil,toggle(view,cv,o.boss_map_timing==true,function()set_opt("boss_map_timing",not o.boss_map_timing)end))
 local tracked=mod:get("friend_stats_scope")~="off"
 h=h+row(view,cv,y+h,"Stats For Tracked Players","Keep stats for the players you track, as well as for your Steam friends.",nil,toggle(view,cv,tracked,function()mod:set("friend_stats_scope",tracked and "off"or "friends",true)end))
 return h+10,"Counting"
end
local function tracked_players(view,cv,popup_cv,y,tracker)
 local h=45;local ft=tracker and tracker.data.friend_tracking or {};local tracked=ft.tracked or {};local aliases=ft.aliases or {}
 local any=false
 local people=tracker and FriendStats.people(tracker.data)or {}
 local list={};for id,name in pairs(tracked)do local p=people[id];list[#list+1]={id=id,name=aliases[id]or p and p.name or type(name)=="string"and name or "Steam Name Unavailable"}end
 table.sort(list,function(a,b)return a.name<b.name end)
 if #list==0 then note(cv,y+45,"No tracked players yet.");h=72 end
 for _,p in ipairs(list)do any=true;h=h+row(view,cv,y+h,p.name,"Tracked Player",nil,button(view,cv,110,"Tracked",function()mod.io_friend_action(p.id,"untrack")end,{sel=true}))end
 cv:text("Teammates From Your Last Missions",X+36,y+h+4,600,26,16,C.gold);h=h+32
 local seen,recent={},{}
 for _,run in ipairs(tracker and Overview.runs(tracker)or {})do if #recent>=8 then break end
  for _,p in pairs(run.context.operative_roster or {})do local id=I.key(p)
   if id and not p.personal and not seen[id]and I.lookup(tracked,id)==nil and #recent<8 then local name=I.lookup(aliases,id)or p.steam_name or p.friend_name or p.name
    if type(name)=="string"and name~=""then seen[id]=true;recent[#recent+1]={id=id,name=name,cls=p.class,run=run}end end
  end
 end
 table.sort(recent,function(a,b)return tostring(a.run.started_at)>tostring(b.run.started_at)end)
 if #recent==0 then cv:rect(X+1,y+h,W-14,1,C.line,true);note(cv,y+h+8,"Unnamed teammates are left out.");h=h+40 end
 -- Steam friends are always kept, so they show as Friend rather than offering Track
 for _,r in ipairs(recent)do local on=I.lookup(tracked,r.id)~=nil;local friend=people[r.id]and people[r.id].friend
  h=h+row(view,cv,y+h,r.name..(r.cls and " ("..(P.class_names[r.cls]or r.cls)..")"or ""),"Last Seen On "..tracker:run_mission_name(r.run.context)..", "..P.day(r.run.started_at),nil,
   friend and button(view,cv,110,"Friend",nil,{sel=true})or button(view,cv,110,on and "Tracked"or "Track",function()mod.io_friend_action(r.id,on and "untrack"or "track",r.name)end,{sel=on}))
 end
 return h+10,"Tracked Players"
end
local function recording(view,cv,y)
 local blo=mod:get("capture_blo")~=false
 local h=45+row(view,cv,y+45,"Burst Limiter Override","Counts the Ogryn's Burst Limiter Override procs for its records.",nil,toggle(view,cv,blo,function()mod:set("capture_blo",not blo,true)end))
 return h+10
end
local function your_data(view,cv,y)
 local h=45;local echo=function(ok,reason)if ok then mod:echo("%s",reason or "Statistics rebuilt.")else mod:echo("%s",tostring(reason))end end
 local st=mod.io_storage
 if st and st.unavailable then h=h+row(view,cv,y+h,"Saving Is Off",{"Saved data could not be opened, so nothing will be saved until this is fixed.","Your files were left as they are.",tostring(st.error or ""):sub(1,120),hi=1})end
 if mod.io_request_reset then
  h=h+row(view,cv,y+h,"Reset Statistics","Moves all saved statistics into a backup, after a confirmation. Settings are kept.",nil,button(view,cv,160,"Reset…",mod.io_request_reset))
 end
 local backups=mod.io_backups and mod.io_backups()or {}
 if backups[1]and mod.io_request_restore then
  h=h+row(view,cv,y+h,"Restore Latest Backup","Brings back "..Backup.describe(backups,false)..", after a confirmation. Matches played since are kept.",nil,button(view,cv,160,"Restore…",function()mod.io_request_restore(false)end))
  if backups[2]then h=h+row(view,cv,y+h,"Restore All Backups","Brings back "..Backup.describe(backups,true)..", after a confirmation. Matches played since are kept.",nil,button(view,cv,160,"Restore All…",function()mod.io_request_restore(true)end))end
  h=h+row(view,cv,y+h,"Delete Backups","Deletes "..(backups[2]and "all "..#backups.." backups"or "the backup").." for good, after a confirmation. Your current statistics are kept.",nil,button(view,cv,160,"Delete…",mod.io_request_delete_backups,{danger=true}))
 end
 local reconstruct=function(import)return function()
  if import and mod.io_start_history_import then
   local ok,reason=mod.io_start_history_import()
   if ok then mod:echo("Importing match history…")else echo(ok,reason)end
  elseif mod.io_reconstruct_history then echo(mod.io_reconstruct_history(import))end
 end end
 h=h+row(view,cv,y+h,"Rebuild Statistics","Recount every record and streak from your saved Match History.",nil,button(view,cv,160,"Rebuild",function()
  popup("Rebuild Statistics","Rebuild statistics from your saved Match History?\nYour matches are not changed.","Rebuild",reconstruct(false))end))
 h=h+row(view,cv,y+h,"Import Match History",{"Copy match files into","InformationOverload\\reconstruction_import","Import replaces the matches on this PC.",hi=2},nil,button(view,cv,160,"Import…",function()
  popup("Import Match History","Replace the active history with the files from reconstruction_import and rebuild statistics?\nThe matches it replaces go into a backup, which Restore Latest Backup brings back.","Import",reconstruct(true))end))
 return h+10
end
return function(view,cv,popup_cv)
 local tracker=view:_tracker();local part=view.part or "screens"
 if view.io_set_part~=part then view.io_set_part=part;view.scroll=view.scroll or {};view.scroll.settings=0 end
 if part=="screens"then return Screens.draw(view,cv)end
 view:_sheet(cv,D.top);if cv.sc then cv.sc.y1=D.bottom-34 end
 local noop=function()end;local ghost=setmetatable({_jump=noop,_hit=noop,_ctl=noop},{__index=view})
 local function card(fn,y,...)local h,title=fn(ghost,D.canvas(),D.canvas(),y,...);view:_card(cv,X,y,W,h,title);cv.z=5;fn(view,cv,popup_cv,y,...);return h end
 local y=D.top
 local tab=part=="display"and display or part=="counting"and counting or part=="scoreboard"and scoreboard or part=="tracker"and tracker_tab or part=="endscreen"and endscreen or NAME[part]and screen_tab(part)
 if tab then card(tab,y)
 elseif part=="tracked"then card(tracked_players,y,tracker)
 else
  local rh=recording(ghost,D.canvas(),y);view:_card(cv,X,y,W,rh,"Recording");cv.z=5;recording(view,cv,y);y=y+rh+10
  local h=your_data(ghost,D.canvas(),y);view:_card(cv,X,y,W,h,"Your Data");cv.z=5;your_data(view,cv,y)
 end
 view:_sheet_end(cv)
end
