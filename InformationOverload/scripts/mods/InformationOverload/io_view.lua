-- Information Overload: the dashboard frame, its rail and the Overview page.
local mod=get_mod("information_overload")
require("scripts/ui/views/base_view")
local D=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_view_definitions")
local Overview=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_overview")
local Patch=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/game_patch")
local Icons=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_icons")
local S=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/scoreboard")
local Intro=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_intro")
local Screens=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_page_screens")
local PAGES={}
for _,key in ipairs({"run","history","trends","records","weapons","classes","streaks","deaths","speed","dossier","team","friends","psyk","settings"})do PAGES[key]=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_page_"..key)end
PAGES.last=PAGES.run
local C,F=D.c,D.font
local DASH=Overview.dash
local View=class("InformationOverloadView","BaseView")
local NAMES={run="Match History",overview="Overview",last="Last Mission",history="Match History",trends="Trends",records="Records",weapons="Weapons",classes="Classes",
 streaks="Streaks",deaths="Deaths",speed="Speedrunning",dossier="Dossier",team="Team",friends="Friends",psyk="Psykhanium",scoreboard="Scoreboard",settings="Settings"}
local ORDER={"overview","last","history","trends","records","weapons","classes","streaks","deaths","speed","dossier","team","friends","psyk"}
local PARTS={{"display","Display"},{"counting","Counting"},{"tracked","Tracked Players","friends"},{"data","Data"}}
local PART_NAMES={screens="Screens"};for _,p in ipairs(PARTS)do PART_NAMES[p[1]]=p[2]end;for _,s in ipairs(Screens.list)do PART_NAMES[s.id]=s.name end
local LOCKED,SEP=D.rgba(169,191,153,.3),D.rgba(60,78,57,.75)
local CREDITS={{"HijaKer","Data, Records, Tracking"},{"LilyMods","Interface & Layout"}}
-- the tops of Settings' two groups, each under its heading
local GROUPS={{"base",10},{"rail",12},{"drawer",40},{"popup",70}}
-- a card that opens from anywhere on it glows gold on hover: a faint warm fill, a gold edge and rings fading outward
local GLOW,CARD_HV={.45,.22,.1},{bg=D.rgba(221,183,99,.06),edge=C.gold,glow=C.gold}
local function pressed(input,name)local ok,v=pcall(input.get,input,name);return ok and v==true end
local function down(input,name)local ok,v=pcall(input.get,input,name);return ok and (v==true or type(v)=="number"and v>0)end
local function get(k)return mod:get(k)end
function View:init(settings,context)
 View.super.init(self,{scenegraph_definition=D.scenegraph(),widget_definitions={io_hover_a=D.hover_definition(),io_hover_b=D.hover_definition()}},settings,context)
 self._pass_draw,self._pass_input,self._allow_close_hotkey=false,false,false
 self.page="overview";self.stack={};self.layers={};self.hits={};self.part="screens"
 -- a tap of the key in a mission opens the panel without the intro
 self.io_tap=context and context.io_tap
 -- the End Screen's Full History opens on its mission
 self.io_run=context and context.io_run
end
function View:on_enter()
 View.super.on_enter(self)
 -- a scoreboard tapped on goes off once the panel opens
 local sb=mod.io_scoreboard;if sb and sb.state then sb.state.on=nil end
 self.io_key_armed=nil;self.pinned=mod:get("rail_pinned")==true;self.rail_mode=nil;self.rows=nil;self.leaving=nil;self.swap_t0=nil;self.io_bar_drag=nil;self.io_slide=nil
 self.page="overview";self.stack={};self.io_steps=nil;self.io_psyk_deleting=nil;self.io_psyk_del=nil;self.io_run_back=nil;self.dd=nil;self.drawer=self.pinned;self.drawer_t0=nil;self.drawer_k=nil;self.scope=nil
 -- a mission opened from the End Screen sits on Match History, so Back and right click have somewhere to go
 if self.io_run then self.page="run";self.stack={"history"};self.io_params={run=self.io_run};self.io_tab="overview";self.io_run=nil end
 -- the first open plays the intro instead of the page, unless a tap in a mission opened it
 self.intro=mod:get("intro_seen")~=true and not self.io_tap and not mod.io_intro_broken and Intro.new()or nil
 self:_refresh()
end
function View:on_exit()
 self.layers={};self.hits={};self.model=nil;self.rows=nil;self.leaving=nil;self.intro=nil;self.io_flash=nil;self.io_tip=nil;self.io_doss=nil;self.io_bar_drag=nil;self.io_slide=nil
 if mod.io_storage and mod.io_storage.release_details then mod.io_storage:release_details()end
 if View.super.on_exit then View.super.on_exit(self)end
end
function View:_tracker()
 local api=mod.io_api;if not api then return end
 return api.dashboard_tracker and api.dashboard_tracker()or api.tracker and api.tracker()
end
function View:_revision()
 local tracker=self:_tracker();local data=tracker and tracker.data or {}
 return tostring(data.run_sequence)..":"..tostring(data.history_policy_revision)..":"..tostring(data.friend_tracking_revision)..":"..tostring(tracker and tracker.data)..":"..tostring(mod.io_times_revision)
end
-- what the Overview model is built from besides the history: the mode and patch, two display options and the history's revision
function View:_inputs()
 local s=self.scope or {};local o=mod.io_display_options and mod.io_display_options()or {}
 return table.concat({tostring(s.mode),tostring(s.patch),tostring(s.all_patches),tostring(o.favorite_class),tostring(o.boss_map_timing),self:_revision()},"|")
end
function View:_refresh()
 local tracker=self:_tracker();self.model=nil;self.rev=self:_revision()
 if tracker then
  if not self.scope then self.scope=Overview.defaults(tracker)end
  local ok,result=pcall(Overview.build,tracker,self.scope)
  if ok then self.model=result else mod:error("%s",tostring(result))end
 end
 self:_render()
end
function View:_w(text,size,font)
 text=tostring(text):gsub("{#[^}]*}","")
 local ok,w,_,_,caret=pcall(self._text_size,self,text,{font_type=font or F.body,font_size=size},{2000,200},true)
 if ok and type(w)=="number"and w>0 then return D.advance(w,caret)end
 return #text*size*.52
end
-- text cut to a width with an ellipsis, a whole character at a time
function View:_fit(text,size,w,font)text=tostring(text);if self:_w(text,size,font)<=w then return text end;while #text>1 and self:_w(text.."…",size,font)>w do text=text:gsub("[^\128-\191]?[\128-\191]*$","")end;return (text:gsub("[%s,|]+$","")).."…"end
function View:_go(page)
 if page==self.page then return end
 self.stack[#self.stack+1]=self.page;if #self.stack>60 then table.remove(self.stack,1);self.io_run_back=nil end
 -- a mission left behind is remembered with its place on the stack, so Back shows that mission again
 self.io_run_back=self.io_run_back or {};self.io_run_back[#self.stack]=self.page=="run"and self.io_params and self.io_params.run or nil
 self.page=page;self.io_fwd=nil
end
-- a step back keeps what it left so the forward side button can undo it: the page and the plain values the page keeps on the view
local SNAP_SKIP={io_crumbs_page=true,io_crumbs_drawn=true,io_tap=true,io_nope=true,io_unlock=true,io_move=true,io_drag=true,io_dirty=true,io_bench_at=true,io_hkey=true,io_key_armed=true,io_set_part=true}
local function snappable(k,v)return type(k)=="string"and k:sub(1,3)=="io_"and not SNAP_SKIP[k]and (type(v)=="string"or type(v)=="number"or type(v)=="boolean")end
-- on a mission, which mission it is is kept too, as a step back to a mission must show that mission
function View:_snap()local v={};for k,x in pairs(self)do if snappable(k,x)then v[k]=x end end;if self.page=="run"then v["@run"]=self.io_params and self.io_params.run end;return {page=self.page,v=v}end
local function put_run(self,s)if s.v["@run"]~=nil then self.io_params=self.io_params or {};self.io_params.run=s.v["@run"]end end
local function same(a,b)if a.page~=b.page then return false end;for k,x in pairs(a.v)do if b.v[k]~=x then return false end end;for k in pairs(b.v)do if a.v[k]==nil then return false end end;return true end
-- every click that takes the panel somewhere new, a view inside a page included, leaves where it was for right click to step back to
function View:_came_from(s)if same(s,self:_snap())then return end;self.io_steps=self.io_steps or {};self.io_steps[#self.io_steps+1]=s;if #self.io_steps>30 then table.remove(self.io_steps,1)end end
function View:_restore(s)
 if s.page~=self.page then local i=#self.stack;if self.stack[i]==s.page then self.stack[i]=nil else self.stack[i+1]=self.page end end;self.page=s.page
 for k,x in pairs(self)do if snappable(k,x)and s.v[k]==nil then self[k]=nil end end
 for k,x in pairs(s.v)do if k~="@run"then self[k]=x end end;put_run(self,s)
end
function View:_step_back()
 -- a step that would land where the panel already is gets skipped
 local cur=self:_snap();local s;repeat s=self.io_steps and table.remove(self.io_steps)until not s or not same(s,cur)
 if not s then return self:_back(true)end
 self:_remember(self:_snap());self:_restore(s)
end
function View:_remember(s)self.io_fwd=self.io_fwd or {};self.io_fwd[#self.io_fwd+1]=s;if #self.io_fwd>30 then table.remove(self.io_fwd,1)end end
function View:_forward()
 local s=self.io_fwd and table.remove(self.io_fwd);if not s then return end
 local cur=self:_snap();self.io_steps=self.io_steps or {};self.io_steps[#self.io_steps+1]=cur
 if s.page~=self.page then self.stack[#self.stack+1]=self.page end;self.page=s.page
 for k,x in pairs(self)do if snappable(k,x)and s.v[k]==nil then self[k]=nil end end
 for k,x in pairs(s.v)do if k~="@run"then self[k]=x end end;put_run(self,s)
end
-- a page that opens something inside itself names its way up in its crumbs, and the Back button takes that step before leaving the page; right click always goes back to the page before
-- the crumbs kept from the last render count only while that page is still the one showing
function View:_trail_list()return self.io_crumbs or self.io_crumbs_page==self.page and self.io_crumbs_shown or {}end
function View:_up()local list=self:_trail_list();for i=#list-1,1,-1 do if list[i][2]then return list[i][2]end end end
function View:_back(page_only)
 -- in Settings, Back from any part goes to Screens first, and from Screens closes Settings
 if self.page=="settings"then if not page_only and (self.part or "screens")~="screens"then self.part="screens";return end;return self:_close_settings()end
 local snap=self:_snap()
 -- every page names its way up even at its own start, so a step that changes nothing leaves the page instead
 local up=not page_only and self:_up()
 if up then local function trail()local t={};for _,c in ipairs(self:_trail_list())do t[#t+1]=c[1]end;return table.concat(t,"|")end
  local before=trail();up();self:_render();if trail()~=before or not same(snap,self:_snap())then return self:_remember(snap)end end
 local i=#self.stack;local page=table.remove(self.stack)
 local run=self.io_run_back and self.io_run_back[i];if self.io_run_back then self.io_run_back[i]=nil end
 if page then self.page=page;if page=="run"and run then self.io_params=self.io_params or {};self.io_params.run=run end;self:_remember(snap)end
end
-- a page picked from the bar opens at its start, unless Keep Your Place is on and it is another page; the page you are on always goes back to its start
function View:_page_click(key)
 local same=self.page==key;self:_go(key)
 if same or mod:get("keep_page_place")~=true then self:_page_top()end
end
function View:_page_top()
 local page=self.page;self.scroll=self.scroll or {};self.scroll[page]=0;self:_render()
 local function trail()local t={};for _,c in ipairs(self.io_crumbs or {})do t[#t+1]=c[1]end;return table.concat(t,"|")end
 for _=1,8 do local up=self.io_crumbs and self:_up();if not up then break end
  local before=trail();up();if self.page~=page then break end;self:_render();if trail()==before then break end
 end
end
function View:_open_settings()if self.page~="settings"then self.settings_from=self.page;self.page="settings"end end
function View:_leave_settings()self.page=self.settings_from or "overview";self.settings_from=nil end
-- every way out of Settings during the first open ends the intro as the cog does
function View:_close_settings()
 local intro=self.intro;if intro and intro.first then local ok,err=pcall(intro.done,intro);if ok then return end;self:_intro_broken(err)end;self:_leave_settings()
end
function View:_intro_broken(err)
 mod.io_intro_broken=true;self.intro=nil;self.io_dirty=true;mod:error("I/O intro: %s",tostring(err))
end
function View:_rail()
 local entries={};local intro=self.intro
 if self.page=="settings"then
  -- Settings stacks up from the cog, which stays in its place lit as the selected slot and closes Settings; Screens heads the bar, and the pin sits above the bar on its own.
  entries[1]={key="settings",label="Close Settings",top=788,sel=true,away=intro and intro.away,fn=function()self:_close_settings()end}
  for i,p in ipairs(PARTS)do local id=p[1];entries[#entries+1]={key=id,icon=p[3],label=p[2],top=788-i*44,sel=self.part==id,fn=function()self.part=id end}end
  entries[#entries+1]={key="screens",label="Screens",top=68,sel=self.part=="screens",fn=function()self.part="screens"end}
  entries[#entries+1]={sep=true,top=114}
  -- each screen's tab stays locked until the screen is turned on in Screens
  for i,s in ipairs(Screens.list)do local id=s.id;local open=Screens.on(id)
   entries[#entries+1]={key=id,icon=s.icon,label=s.name,top=120+(i-1)*44,sel=self.part==id,locked=not open,
    fn=function()if not open then self.io_nope={id,self.now or 0};return true end;self.part=id end}
  end
  return entries
 end
 for _,key in ipairs(ORDER)do
  do
   entries[#entries+1]={key=key,label=NAMES[key],top=68+#entries*44,sel=self.page==key or key=="history"and self.page=="run",fn=function()self:_page_click(key)end}
  end
 end
 entries[#entries+1]={key="settings",label="Settings",top=788,lit=intro and intro.lit_slot,away=intro and intro.away,fn=function()self:_open_settings()end}
 return entries
end
function View:_ctl(cv,g,x,y,w,h,fn,opt)
 opt=opt or {};local k=opt.dis and .38 or 1
 cv.z=4;cv:rect(x,y,w,h,opt.sel and C.fill_s or opt.open and C.fill_h or C.fill,false,k)
 cv.z=5;cv:edges(x,y,w,h,1,opt.sel and C.sel or opt.open and C.hover or C.frame,false,k);cv:corners(x-1,y-1,w+2,h+2,opt.sel and C.gold or C.corner,false,k)
 if fn and not opt.dis then self:_hit(g,x,y,w,h,fn,opt.hv or (not opt.sel and {bg=C.fill_h,edge=C.hover})or nil,opt.rail,opt.tip)end
 return k
end
-- tip is a list of lines shown while the pointer rests on the area
-- key names an area the page draws differently while the pointer is on it; the page redraws when that changes
function View:_hit(g,x,y,w,h,fn,hv,rail,tip,key)
 local sc=g=="base"and self.sheet;if sc then y=y+sc.dy;if y<sc.y0 then h=h-(sc.y0-y);y=sc.y0 end;if y+h>sc.y1 then h=sc.y1-y end;if h<=0 then return end end
 local hits=self.hits;hits[#hits+1]={g=g,x=x,y=y,w=w,h=h,fn=fn,hv=hv,rail=rail,tip=tip,key=key}
end
-- a popup's panel, which takes a click anywhere on it so none falls through to what lies under it
function View:_panel(popup,x,y,w,h)popup.z=1;popup:rect(x,y,w,h,C.pop);popup.z=2;popup:edges(x,y,w,h,1,C.hover);self:_hit("popup",x,y,w,h,function()return true end)end
-- an area that only shows a tip; give a clickable area its tip through _hit instead, as this one sits over it
function View:_tip(g,x,y,w,h,lines)self:_hit(g,x,y,w,h,nil,nil,nil,lines)end
-- a tip as the mockup draws it: the first line a gold heading, an empty line a gap, and what follows ": " or " - " picked out
local function tip_split(l)local a,b=l:find(": ",1,true),l:find(" - ",1,true);if b and (not a or b<a)then return l:sub(1,b-1).." · ",l:sub(b+3)end;if a then return l:sub(1,a+1),l:sub(a+2)end end
local function tip_key(lines)local t={};for i,l in ipairs(lines)do t[i]=tostring(l)end;return table.concat(t,"\n")end
-- words laid into rows no wider than w, the first row w1
local function tip_wrap(self,s,size,w1,w,measure)local rows,cur,lim={},nil,w1
 for word in s:gmatch("%S+")do local try=cur and cur.." "..word or word
  if cur and measure(try,size)>lim then rows[#rows+1]=cur;cur=word;lim=w else cur=try end
 end
 rows[#rows+1]=cur or "";return rows
end
function View:_tip_build(lines)
 -- some screens draw text a little wider than it measures, and a box too narrow for its text wraps it over the next line, so the
 -- tip is laid out a tenth wider than measured and each line drawn in a box with room to spare
 local function mw(t,size)return self:_w(t,size)*1.1 end;local ROOM=200
 -- the game measures a label without its trailing space, so the gap before its value is added here
 local function lw(t,size)return mw((t:gsub("%s+$","")),size)+math.ceil(size*.35)end
 local rows,w,h={},0,10
 for i,l in ipairs(lines)do l=tostring(l)
  if l==""then rows[#rows+1]=false
  elseif i==1 then rows[#rows+1]={l,nil,16,C.gold,23};w=math.max(w,mw(l,16))
  else local k,v=tip_split(l);rows[#rows+1]={k or l,v,14,C.label,20};w=math.max(w,(v and lw(k,14)or mw(l,14))+(v and mw(v,14)or 0))end
 end
 w=math.min(460,math.ceil(w)+28);local cw=w-28
 local cv=D.canvas()
 -- a line too long for the box wraps, a value carrying on under its label
 for i,r in ipairs(rows)do
  if not r then h=h+6 else local s,v,size,c,lh=r[1],r[2],r[3],r[4],r[5];local kw=v and lw(s,size);local x,first,cc,body=14,cw,c
   if v and (kw+mw(v,size)<=cw or kw<cw*.6)then cv:text(s,14,h,kw+ROOM,lh,size,c);x,first,cc,body=14+kw,cw-kw,C.value,v else body=v and s..v or s end
   for j,t in ipairs(tip_wrap(self,body,size,first,cw,mw))do local tw=j==1 and first or cw;cv:text(self:_fit(t,size,tw),j==1 and x or 14,h,tw+ROOM,lh,size,cc);h=h+lh end
   if i==1 then h=h+4 end
  end
 end
 h=h+10;cv.z=0;cv:rect(0,0,w,h,C.tip);cv.z=1;cv:edges(0,0,w,h,1,C.hover)
 local under,over=cv:widgets("io_tip",100);return {under=under,over=over,w=w,h=h}
end
-- built once per set of lines and only moved after; a tip that fails to build stays hidden until the lines change
function View:_tip_at(hit,x,y)
 local tip,lines=self.io_tip,hit and not self.dd and x and hit.tip
 if type(lines)~="table"or #lines==0 then if tip then tip.on=false end;return end
 if not tip or tip.lines~=lines then local key=tip_key(lines)
  if not tip or tip.key~=key then local ok,made=pcall(self._tip_build,self,lines)
   if not ok then mod:error("I/O tip: %s",tostring(made));made={broken=true}end;made.key=key;tip=made;self.io_tip=tip
  end
  tip.lines=lines
 end
 if tip.broken then tip.on=false;return end
 tip.x,tip.y=math.min(math.max(x+28,20),1290-tip.w),math.min(math.max(y+12,20),830-tip.h);tip.on=true
 for _,wd in pairs({tip.under,tip.over})do wd.offset[1],wd.offset[2]=tip.x,tip.y end
end
-- pages call these round the part that scrolls; the wheel moves it
function View:_sheet(cv,y0)self.scroll=self.scroll or {};local at=self.scroll[self.page]or 0;cv:scroll(-at,y0-2,D.bottom);self.sheet=cv.sc end
function View:_sheet_end(cv)
 local sc=self.sheet;if not sc then return end;self.sheet=nil;local bottom=cv:unscroll()
 local view_h=sc.y1-sc.y0;local max=math.max(0,bottom+10-sc.y0-view_h);self.scroll_max=max;self.sheet_span={sc.y0,sc.y1}
 -- a page that got shorter, such as one row opened from far down a list, must not stay scrolled past its end
 local scroll=self.scroll or {};if (scroll[self.page]or 0)>max then scroll[self.page]=max;self.io_dirty=true end
 -- the bar can be taken anywhere down the panel's right edge, and widens while the pointer is on it or it is held
 if max>0 then local at=-sc.dy;local th=math.max(40,view_h*view_h/(view_h+max));local ty=sc.y0+(view_h-th)*at/max
  local held,on=self.io_bar_drag,self.io_hkey=="io_bar";local x,w=1299,3;if held or on then x,w=1298,5 end
  cv.z=6;cv:rect(x,sc.y0,w,view_h,C.line);cv:rect(x,ty,w,th,held and C.gold or on and C.label or C.hover)
  self.io_bar={y0=sc.y0,h=view_h,ty=ty,th=th,max=max}
  self:_hit("base",1290,sc.y0,16,view_h,function()self.io_bar_drag={page=self.page};return true end,nil,nil,nil,"io_bar")
 end
end
function View:_icon(cv,key,x,y,c)
 -- the safe lookup: before the game has connected, the plain one asks the network for an id it has not got and the game crashes
 if key=="classes"then local pm=Managers.player;local pl=pm and pm.local_player_safe and pm:local_player_safe(1);local pr=pl and pl:profile();local path=pr and pr.archetype and pr.archetype.archetype_icon_large
  if path and Application.can_get_resource("material",path)then return cv:texture(path,x-2,y-2,24,24,c,true)end end
 -- I/O's logo, on Settings, fills its square 15% more than the other icons, about the same middle
 if key=="settings"then return cv:icon(Icons.settings,x-1.5,y-1.5,c,nil,23)end
 if Icons[key]then return cv:icon(Icons[key],x,y,c)end
 local path=D.icons[key]
 if path and (not D.icon_held(path)or mod.io_icons_ready and mod.io_icons_ready())then cv:texture(path,x,y,20,20,c,true)end
end
-- Rows are cut to the inside of the bar's frame, so a swap scrolls them under its edges; text and textures can't be cut, so they fade out just before.
local TOP,BOTTOM=64,832
local function place_row(wd,dy)
 if wd.io_dy==dy then return end;wd.io_dy=dy
 for _,p in ipairs(wd.io_passes)do local st,y,h,a=p[1],p[2]+dy,p[3],p[4]
  if a then local b0,b1=y,y+h;if st.text_color then b0,b1=y+h/2-8,y+h/2+8 end
   st.offset[2]=y;(st.text_color or st.color)[1]=math.floor(a*math.max(0,math.min(1,math.min(b0-TOP,BOTTOM-b1)/10))+.5)
  else local y0,y1=math.max(y,TOP),math.min(y+h,BOTTOM);st.offset[2]=y0;st.size[2]=math.max(0,y1-y0)end
 end
end
local function clip(wd)
 if not wd then return end;local list={}
 for _,st in pairs(wd.style)do
  if type(st)=="table"and st.offset and st.size then local c=st.text_color or st.scale_to_material and st.color;list[#list+1]={st,st.offset[2],st.size[2],c and c[1]}end
 end
 wd.io_passes=list;wd.io_dy=nil;place_row(wd,0);return wd
end
local function clipped(a,b)return clip(a),clip(b)end
function View:_render()
 if self.io_move then return self:_render_move()end
 self.hits={};self.sheet=nil;self.scroll_max=0;self.sheet_span=nil;self.io_bar=nil;local base,rail,drawer,popup=D.canvas(),D.canvas(),D.canvas(),D.canvas();if self.drawer_k and self.drawer_k<1 then drawer.cx=16-292*self.drawer_k end
 local settings=self.page=="settings"
 -- until the cog reaches Screens the intro has the panel to itself
 local intro=self.intro;local shell=intro and intro:shell()
 -- Swapping between the page bar and the settings bar keeps the old bar's rows to scroll away.
 if self.rail_mode~=nil and self.rail_mode~=settings then self.leaving=self.rows;self.swap_t0=self.now;self.swap_dir=settings and 1 or -1 end
 self.rail_mode=settings
 base.z=0;base:rect(-1300,-1110,3920,3080,C.dim)
 -- while I/O talks there is no bar; it appears as the cog flies down to sit in it
 local talk=intro and intro.phase=="talk";local entries=talk and {}or self:_rail();local span={math.huge,0};self.rail_span=span
 if not talk then rail:panel(16,62,56,772,nil,self.drawer and "r"or nil)end;base:panel(84,62,1222,772)
 if not talk then drawer:panel(-216,62,232,772,{right=true},"l")end
 -- each row is its own widget so a swap can scroll the rows inside the bar
 local rows={}
 for i,e in ipairs(entries)do span[1]=math.min(span[1],e.top);span[2]=math.max(span[2],e.top+40)
  local rc,dc=D.canvas(),D.canvas();dc.cx=drawer.cx
  if e.sep then rc:rect(26,e.top,36,1,SEP)
  else
   local hv=e.locked and {}or nil
   self:_ctl(rc,"rail",22,e.top,44,40,e.fn,{sel=e.sel,rail=i,hv=hv})
   if not e.away then self:_icon(rc,e.icon or e.key,34,e.top+10,e.locked and LOCKED or (e.sel or e.lit)and C.gold_hi or C.label)end
   if e.locked then rc:icon(Icons.lock,51,e.top+25,C.muted,nil,14)end
   if not e.icon_only then
    self:_ctl(dc,"drawer",-208,e.top,216,40,e.fn,{sel=e.sel,rail=i,hv=hv})
    if e.sub then dc:text(e.label,-194,e.top+3,188,20,16,C.value);dc:text(e.sub,-194,e.top+21,188,16,13,C.muted,"left",F.medium)
    -- a screen turned off has its name greyed, as its icon is
    else dc:text(e.label,-194,e.top,e.count and 150 or 188,40,16,e.sel and C.gold_hi or e.locked and C.muted or C.value)end
    if e.count then dc:text(e.count,-120,e.top,106,40,14,e.sel and C.gold_hi or C.muted,"right")end
   end
  end
  rows[#rows+1]={y=e.top,h=40,rc=rc,dc=dc,key=e.key}
 end
 if settings then
  local function piece(y,h,draw)local dc=D.canvas();dc.cx=drawer.cx;draw(dc);rows[#rows+1]={y=y,h=h,dc=dc}end
  -- the credits at the foot of the gap above Data, across the names: the names side by side, a role too wide for its half wrapping
  local cx,cw=-208,216
  local half=cw/#CREDITS;local roles,n={},1
  for i,c in ipairs(CREDITS)do local lines,line={},""
   for word in c[2]:gmatch("%S+")do local try=line==""and word or line.." "..word
    if line~=""and self:_w(try,12,F.medium)>half-8 then lines[#lines+1]=line;line=word else line=try end end
   lines[#lines+1]=line;roles[i]=lines;n=math.max(n,#lines)
  end
  -- a role that fits on one line still splits in two when its neighbour wraps, at the most even break, so the halves match
  for i,c in ipairs(CREDITS)do if n==2 and #roles[i]==1 then local w={};for word in c[2]:gmatch("%S+")do w[#w+1]=word end
   local best,at=math.huge;for k=1,#w-1 do local m=math.max(self:_w(table.concat(w," ",1,k),12,F.medium),self:_w(table.concat(w," ",k+1),12,F.medium));if m<best then best,at=m,k end end
   if at then roles[i]={table.concat(w," ",1,at),table.concat(w," ",at+1)}end end end
  local y0=788-#PARTS*44-12-(20+n*15)
  piece(y0,20+n*15,function(dc)
   for i,c in ipairs(CREDITS)do local x=cx+(i-1)*half;dc:text(c[1],x,y0,half,20,15,C.value,"center")
    for j,l in ipairs(roles[i])do dc:text(l,x,y0+20+(j-1)*15,half,15,12,C.muted,"center",F.medium)end
   end
  end)
 end
 self:_ctl(base,"base",1258,20,34,34,function()Managers.ui:close_view(self.view_name,true)end)
 base:cross(1275,37,17,2,C.value)
 -- the pin keeps the names open between opens; in Settings only, above the bar on its own
 if settings and not shell then local on=self.pinned
  self:_ctl(base,"base",22,20,44,34,function()self.pinned=not on;mod:set("rail_pinned",self.pinned);return true end,{sel=on})
  self:_icon(base,"pin",34,27,on and C.gold_hi or C.label)
 end
 -- under the page at the right, the credits beside the version: the names lit, the rest muted, a small dot before the version
 do local line={{"By",C.muted,F.medium},{CREDITS[1][1],C.value},{"&",C.muted,F.medium},{CREDITS[2][1],C.value},false,{"v"..tostring(mod.version or ""),C.muted}}
  local ws,x={},1304;for i,s in ipairs(line)do ws[i]=s and self:_w(s[1],14,s[3])or 3;x=x-ws[i]-(i>1 and (s==false or line[i-1]==false)and 8 or i>1 and 4 or 0)end
  for i,s in ipairs(line)do if s then base:text(s[1],x,838,ws[i]+2,17,14,s[2],"left",s[3])else base:rect(x,845,3,3,C.muted)end;x=x+ws[i]+(line[i+1]==nil and 0 or (s==false or line[i+1]==false)and 8 or 4)end
 end
 self.io_crumbs_shown,self.io_crumbs_page,self.io_crumbs=self.io_crumbs,self.io_crumbs_drawn,nil;self.io_crumbs_drawn=self.page
 if shell then
  if intro.phase=="talk"then self:_ctl(base,"base",1168,20,80,34,function()intro:skip()end);base:text("Skip",1168,20,80,34,16,C.value,"center")end
 else
  local title=settings and "Settings"or self.page=="overview"and "Information Overload"or NAMES[self.page]or ""
  base:text(title:upper(),442,12,800,44,32,C.gold,"right",F.title)
  D.picks={}
  if self.page=="overview"then self:_overview(base,popup)
  elseif PAGES[self.page]then local ok,err=pcall(PAGES[self.page],self,base,popup,drawer);if not ok then local said=self.page.."|"..tostring(err);if self.io_said~=said then self.io_said=said;mod:error("I/O %s: %s",self.page,tostring(err))end end end
  -- a page that threw inside its scrolled sheet leaves it open, which would clip Back and the crumbs away
  if self.sheet then self:_sheet_end(base)end
  -- Back is drawn after the page, so it knows the steps up the page has just named
  local can_back=settings or #self.stack>0 or self:_up()~=nil
  -- a click anywhere clears what forward would redo, except on Back itself, so several Backs can all be redone
  self.io_back_fn=self.io_back_fn or function()self:_back()end
  local k=self:_ctl(base,"base",100,20,110,34,self.io_back_fn,{dis=not can_back})
  base:chevron(112,34,"left",8,C.value,k);base:text("Back",130,20,70,34,16,C.value,"left",nil,k)
  self:_crumbs(base)
 end
 D.picks=nil
 self.layers={}
 for i,r in ipairs(rows)do
  if r.rc then r.ru,r.ro=clipped(r.rc:widgets("io_rail"..i,12))end
  r.du,r.dov=clipped(r.dc:widgets("io_name"..i,40));r.rc,r.dc=nil,nil
 end
 self.rows=rows
 local cvs={base=base,rail=rail,drawer=drawer,popup=popup}
 for _,g in ipairs(GROUPS)do local cv=cvs[g[1]]
  local under,over=cv:widgets("io_"..g[1],g[2]);self.layers[#self.layers+1]={g=g[1],z=g[2],under=under,over=over}
 end
end
-- Move: the panel steps aside so one box, io_move, can be dragged: the squad or the Tracker Panel where they show with the key held, or "tm_esc", the Tracker Panel beside the Esc menu.
function View:_screen()
 local k=self._render_scale or RESOLUTION_LOOKUP.scale or 1;local sw,sh=RESOLUTION_LOOKUP.width/k,RESOLUTION_LOOKUP.height/k
 local node=self._ui_scenegraph and self._ui_scenegraph.panel;local o=node and node.world_position
 return sw,sh,o and o[1]or (sw-D.panel_size[1])/2,o and o[2]or (sh-D.panel_size[2])/2
end
function View:_render_move()
 self.hits={};self.sheet=nil;self.sheet_span=nil;self.io_bar=nil;self.rail_span=nil;self.rows={};self.leaving=nil
 local sw,sh,ox,oy=self:_screen();self.io_screen={sw,sh,ox,oy}
 local o=S.options(get);local layout=o.layout=="off"and "cards"or o.layout;local label="Squad Cards"
 for _,l in ipairs(S.LAYOUTS)do if l[1]==layout then label=l[2]end end
 local sb=mod.io_scoreboard;local live=sb and sb.live and sb.live();local n=live and #live.squad>0 and #live.squad or 4
 local kind=S.KEYS[self.io_move]and self.io_move or "squad"
 local prev=self.io_boxes and self.io_boxes[kind];local cv=D.canvas();self.io_boxes={};local esc=kind=="tm_esc";self.io_kinds={kind}
 cv.z=0;cv:rect(-ox,-oy,sw,sh,D.rgba(0,0,0,.35))
 -- a faint stand-in for the Esc menu's own buttons
 if esc then local m=S.ESC_MENU;local mx,my=S.canvas(m[1],m[2],sw,sh);mx,my=mx-ox,my-oy
  cv.z=1;cv:rect(mx,my,m[3],m[4],C.card);cv.z=2;cv:edges(mx,my,m[3],m[4],1,C.line);cv:text("Esc Menu",mx,my+m[4]/2-20,m[3],40,24,C.muted,"center",F.title)end
 do
  -- the box and its outlines are read as the HUD reads them, a drag's place standing in for the saved one once it moves, so each lands where it would draw
  local d=self.io_drag;local on=d and d.kind==kind and prev;local at=get
  if on and d.moved then local k,fx,fy=S.KEYS[kind],S.fraction(d.x,d.y,sw,sh,prev.w,prev.h);at=function(key)if key==k[1]then return fx end;if key==k[2]then return fy end;return get(key)end end
  local key=get("dashboard_key");local tab_key=key==nil or type(key)=="table"and key[1]=="tab"and key[2]==nil
  local below=kind=="squad"and sb and sb.tab_below and sb.tab_below(sw,sh,function(_,s,size,font)return self:_w(s,size,font)end)
  local list=S.move_boxes(kind,o,tab_key,layout,n,sw,sh,at,below);local b=list[1]
  self.io_boxes[kind]=b;self.io_ghosts={}
  -- a Tracker Panel's bottom 50 holds the best-clear line, there only with a best clear here
  local function strip(x,y,w,h)cv:rect(x,y+h-50,w,1,C.line);cv:text("Shows With A Best Clear",x,y+h-50,w,50,14,C.muted,"center",F.medium)end
  local x,y,w,h=b.x-ox,b.y-oy,b.w,b.h;local c=on and C.gold or C.frame
  cv.z=1;cv:rect(x,y,w,h,C.panel);cv.z=2;cv:edges(x,y,w,h,2,c);cv:corners(x-1,y-1,w+2,h+2,on and C.gold or C.corner)
  local mid=y+(b.strip and h-50 or h)/2
  cv:text(kind=="squad"and label or "Tracker Panel",x,mid-36,w,40,28,C.gold,"center",F.title);cv:text("Drag to move it.",x,mid+6,w,26,16,C.label,"center",F.medium)
  if b.strip then strip(x,y,w,h)end
  -- where it shows instead, outlined: its best-clear strip and name drawn only where the box leaves them clear, a name with no room said under the instructions
  local function clear(gy,gh,g)return gh>0 and not (g.x<b.x+b.w and b.x<g.x+g.w and gy<b.y+b.h and b.y<gy+gh)end
  cv.z=3
  for i=2,#list do local g=list[i];self.io_ghosts[#self.io_ghosts+1]=g;local gx,gy=g.x-ox,g.y-oy
   cv:edges(gx,gy,g.w,g.h,1,C.hover)
   local foot=g.y+g.h;if g.strip and clear(foot-50,50,g)then strip(gx,gy,g.w,g.h);foot=foot-50 end
   local at_y=clear(foot-26,26,g)and foot-26 or clear(g.y+4,26,g)and g.y+4
   if at_y then g.named=true;cv:text(g.label,gx,at_y-oy,g.w,22,14,C.label,"center",F.medium)end
  end
 end
 local untold={};for _,g in ipairs(self.io_ghosts or {})do if not g.named then untold[#untold+1]=g.say end end
 local cx,ty,ph=sw/2-ox,24-oy,#untold>0 and 112 or 96;local by=ty+ph-52
 cv.z=3;cv:rect(cx-340,ty,680,ph,C.pop);cv.z=4;cv:edges(cx-340,ty,680,ph,1,C.hover)
 cv:text(esc and "Drag the Tracker Panel to where it should show beside the Esc menu."or kind=="tm"and "Drag the Tracker Panel to where it should show with the key held."or "Drag the squad to where it should show with the key held.",cx-330,ty+6,660,30,16,C.value,"center",F.medium)
 if #untold>0 then cv:text((#untold>1 and "The outlines are where it shows "or "The outline is where it shows ")..table.concat(untold," and ")..".",cx-330,ty+34,660,22,14,C.label,"center",F.medium)end
 local function button(x,w,text,fn)self:_ctl(cv,"base",x,by,w,36,fn);cv:text(text,x,by,w,36,16,C.value,"center")end
 button(cx-170,160,"Done",function()self.io_move=nil;self.io_drag=nil end)
 button(cx+10,160,"Reset",function()local k=S.KEYS[kind];mod:set(k[1],nil);mod:set(k[2],nil,true)end)
 local under,over=cv:widgets("io_base",10);self.layers={{g="base",z=10,under=under,over=over}}
end
function View:_move_input(input,x,y)
 local d,sc=self.io_drag,self.io_screen
 if d then
  local b=self.io_boxes[d.kind];local sw,sh,ox,oy=sc[1],sc[2],sc[3],sc[4]
  if x and (d.moved or x~=d.cx or y~=d.cy)then d.moved=true;d.x=math.max(0,math.min(sw-b.w,x+ox-d.dx));d.y=math.max(0,math.min(sh-b.h,y+oy-d.dy))end
  -- let go: the place is kept as a fraction of the screen, and a click that moved nothing keeps the place it had
  if not down(input,"left_hold")then self.io_drag=nil
   if d.moved then local k=S.KEYS[d.kind];local fx,fy=S.fraction(d.x,d.y,sw,sh,b.w,b.h);mod:set(k[1],fx);mod:set(k[2],fy,true)end
  end
  return self:_render()
 end
 if pressed(input,"left_pressed")then
  local hit=self:_top(x,y);if hit and hit.fn then hit.fn();return self:_render()end
  if not x then return end
  for _,kind in ipairs(self.io_kinds)do local b=self.io_boxes[kind];local px,py=x+sc[3],y+sc[4]
   if px>=b.x and px<b.x+b.w and py>=b.y and py<b.y+b.h then self.io_drag={kind=kind,x=b.x,y=b.y,cx=x,cy=y,dx=px-b.x,dy=py-b.y};return self:_render()end
  end
 elseif pressed(input,"right_pressed")or pressed(input,"back")then self.io_move=nil;self.io_drag=nil;self:_refresh()end
end
function View:_crumbs(cv)
 local list
 if self.page=="settings"then
  list={{"Settings",function()self.part="screens"end},{PART_NAMES[self.part]or "Screens"}}
 else list=self.io_crumbs or {{NAMES[self.page]or ""}}end
 local named={};for _,c in ipairs(list)do named[c[1]]=true end
 for _,m in ipairs(D.picks or {})do if named[m.s]then local g=C.gold;m.p.style.text_color={g[1],g[2],g[3],g[4]}end end
 local x=226
 for i,c in ipairs(list)do local last=i==#list;local w=self:_w(c[1],14)
  cv:text(c[1],x,20,w+6,34,14,last and C.gold or C.label)
  if not last then if c[2]then self:_hit("base",x,27,w,20,c[2],{under=C.value})end;x=x+w+8;cv:chevron(x,33,"right",8,C.muted);x=x+14 end
 end
end
function View:_card(cv,x,y,w,h,title,sub,jump,click)
 cv.z=4;cv:rect(x,y,w,h,C.card);cv.z=5;cv:edges(x,y,w,h,1,C.frame);cv:corners(x-1,y-1,w+2,h+2,C.corner)
 if click then self:_hit("base",x,y,w,h,click,CARD_HV)end
 local tw=self:_w(title,20);cv:text(title,x+36,y+11,tw+6,30,20,C.gold)
 if sub then cv:text(sub,x+46+tw,y+13,300,30,14,C.muted)end
 if jump then self:_jump(cv,x+8,y+15,jump)end
end
function View:_jump(cv,x,y,fn)
 cv.z=4;cv:rect(x,y,22,22,C.fill);cv.z=5;cv:edges(x,y,22,22,1,C.frame);cv:chevron(x+9,y+6,"right",8,C.value)
 self:_hit("base",x,y,22,22,fn,{bg=C.fill_s,edge=C.sel})
end
function View:_rows(cv,x,y,w,rows,jump)
 for i,r in ipairs(rows)do local ry=y+(i-1)*26
  if r[3]and jump then self:_jump(cv,x+8,ry+2,jump)end
  cv:text(r[1],x+36,ry,w-200,26,16,C.label);cv:text(r[2],x+w-313,ry,300,26,16,C.value,"right")
 end
end
-- with no pick it is drawn dimmed and does nothing
function View:_dropdown(base,popup,id,x,w,label,value,options,pick)
 local open=pick and self.dd==id
 local k=self:_ctl(base,"base",x,D.top,w,34,function()self.dd=not open and id or nil end,{open=open,dis=not pick})
 local lw=self:_w(label,16);base:text(label,x+12,D.top,lw+4,34,16,C.label,nil,nil,k);base:text(self:_fit(value,16,w-lw-56),x+20+lw,D.top,w-lw-56,34,16,C.value,nil,nil,k)
 base:chevron(x+w-24,D.top+13,"down",10,C.value,k)
 if open then self:_options(popup,x,D.top+38,math.max(w,260),options,pick)end
end
-- a dropdown's list from x,y, wrapping into columns before the panel's foot and kept inside the panel
function View:_options(popup,x,y,w,options,pick)
 for _,o in ipairs(options)do w=math.max(w,self:_w(o.label,16)+(o.ind and 30 or 12)+(o.n and 140 or 24))end
 local per=math.max(1,math.floor((D.bottom-y-2)/30));local cols=math.ceil(#options/per);w=math.min(w,math.floor(D.width/cols));x=math.max(D.left,math.min(x,D.right-cols*w))
 for c=0,cols-1 do local cx,h=x+c*w,math.min(per,#options-c*per)*30+2;self:_panel(popup,cx,y,w,h)end
 for i,o in ipairs(options)do local r=(i-1)%per;local ox,oy,lw=x+math.floor((i-1)/per)*w,y+1+r*30,o.n and w-140 or w-24;local on=o.value==o.current
  if r>0 then popup:rect(ox+1,oy,w-2,1,C.line)end
  if on then popup:rect(ox+1,oy,w-2,30,C.on);popup:rect(ox+1,oy,3,30,C.sel)end
  popup:text(self:_fit(o.label,16,lw),ox+(o.ind and 30 or 12),oy,lw,30,16,on and C.gold_hi or C.value)
  if o.n then popup:text(o.n,ox+w-132,oy,120,30,14,C.muted,"right")end
  self:_hit("popup",ox+1,oy,w-2,30,function()self.dd=nil;pick(o.value)end,{bg=C.fill_h})
 end
end
-- allow_all gives the page an All Patches entry, kept apart from the patch the other pages use; a page whose figures count every difficulty shows Difficulty dimmed at N/A
function View:_scope(base,popup,m,allow_all,no_diff)
 local s=self.scope;local runs=function(n)n=n or 0;return n..(n==1 and " Run"or " Runs")end
 -- the runs counted are the Patch picked's, every patch's only on All Patches
 local every=allow_all and s.all_patches;local counts,total=m.mode_counts,m.mode_total;if not every then counts,total=m.patch_counts or {},m.patch_total end
 local modes={}
 for _,mode in ipairs({"havoc","non-havoc"})do modes[#modes+1]={value=mode,current=s.mode,label=Overview.mode_names[mode],n=runs(counts[mode])}end
 self:_dropdown(base,popup,"mode",100,200,"Mode:",Overview.mode_names[s.mode]or DASH,modes,function(v)s.mode=v;s.diff="all"end)
 if no_diff then self:_dropdown(base,popup,"diff",310,290,"Difficulty:","N/A")else
  local all=s.mode=="havoc"and "All Havoc"or "All";local diffs={{value="all",current=s.diff,label=all,n=runs(total)}};local shown=all
  for _,d in ipairs(m.diffs)do diffs[#diffs+1]={value=d.value,current=s.diff,label=d.label,n=runs(every and d.count or d.patch_count),ind=true};if d.value==s.diff then shown=d.label end end
  self:_dropdown(base,popup,"diff",310,290,"Difficulty:",shown,diffs,function(v)s.diff=v end)
 end
 local cur=every and "all"or s.patch;local patches={}
 if allow_all then patches[1]={value="all",current=cur,label="All Patches"}end
 for i=#m.patches,1,-1 do local p=m.patches[i];patches[#patches+1]={value=p,current=cur,label=Patch.display(p)..(p==m.current_patch and " (Current)"or "")}end
 self:_dropdown(base,popup,"patch",610,170,"Patch:",every and "All"or s.patch and Patch.display(s.patch)or DASH,patches,function(v)if v=="all"then s.all_patches=true else s.patch=v;if allow_all then s.all_patches=false end end end)
end
function View:_overview(cv,popup)
 local m=self.model
 if not m or m.empty then
  local x,y,out=D.left,D.top,m and m.left_out or 0
  -- every saved match is left out by a Counting switch
  if out>0 then self:_card(cv,x,y,D.width,142,"No Missions Counted")
   cv:text((out==1 and "1 saved mission is"or out.." saved missions are").." left out by Settings › Counting.",x+36,y+48,D.width-72,22,16,C.label)
   self:_ctl(cv,"base",x+36,y+88,260,34,function()self:_open_settings();self.part="counting"end)
   cv:text("Open Settings › Counting",x+36,y+88,260,34,16,C.value,"center");return
  end
  self:_card(cv,x,y,D.width,166,"No Missions Recorded Yet")
  cv:text("Play a mission and it shows up here.",x+36,y+48,D.width-72,22,16,C.label)
  cv:text("Moving from another PC? Copy your match files into the import folder and import them.",x+36,y+72,D.width-72,22,16,C.label)
  self:_ctl(cv,"base",x+36,y+112,260,34,function()self:_open_settings();self.part="data"end)
  cv:text("Open Settings › Data",x+36,y+112,260,34,16,C.value,"center");return
 end
 self:_scope(cv,popup,m,nil,true)
 local L,R,W=D.left,D.col2,D.col
 local mode=Overview.mode_names[self.scope.mode]
 local open_history=function()self.io_hist_tab=nil;self:_go("history")end
 -- a best opens its mission, as the Records page opens one
 local open_run=function(id)self.io_params=self.io_params or {};self.io_params.run=id;self.io_tab="overview";self:_go("run")end
 local function row_of(rows,label)for _,r in ipairs(rows)do if r[1]==label then return r end end;return {}end
 -- the headline tiles: six of one size along the top, the ones with somewhere to go opening it
 local games,rate=row_of(m.career.rows,"Games"),row_of(m.career.rows,"Win Rate")
 local cur,best=row_of(m.career.rows,"Current Win Streak"),row_of(m.career.rows,"Best Win Streak")
 local most,fast=row_of(m.bests,"Most Damage In A Mission"),m.bests[#m.bests]
 local result=m.last.id and (row_of(m.last.rows,"Result")[2]or DASH):gsub(" %(Partial%)","")
 -- Win Streak opens the mission that reached the best streak, or Match History when the history holds no streak that long
 local tiles={{"Games",games[2]},{"Win Rate",rate[2]},{"Win Streak",tostring(cur[2] or DASH)..(best[2]and best[2]~=DASH and " · Best "..best[2]or ""),best[3]and function()open_run(best[3])end or best[3]==false and open_history or nil},
  {"Fastest Clear",fast[2],fast[3]and function()open_run(fast[3])end},{"Most Damage",most[2],most[3]and function()open_run(most[3])end},
  {"Last Mission",result or DASH,m.last.id and function()self.io_tab="overview";self:_go("last")end,result and (result:find("^Victory")and C.gold or C.bad)}}
 local TW,TH=(D.width-5*D.gap)/6,76
 for i,t in ipairs(tiles)do local x=L+(i-1)*(TW+D.gap)
  self:_card(cv,x,D.row2,TW,TH,"",nil,nil,t[3])
  cv:text(t[1],x+16,D.row2+10,TW-32,18,14,C.muted);cv:text(t[2]or DASH,x+16,D.row2+30,TW-32,34,22,t[4]or C.value)
  if t[3]then cv:chevron(x+TW-22,D.row2+33,"right",8,C.muted)end
 end
 -- four cards of one size below, each with the same header, row height and arrow column on the right
 local y1=D.row2+TH+D.gap;local CH=(D.bottom-y1-D.gap)/2;local y2=y1+CH+D.gap
 local function card(x,y,title,sub,fn)self:_card(cv,x,y,W,CH,title,sub,nil,fn)end
 local function rows(x,y,list,jump)
  for i,r in ipairs(list)do local ry=y+(i-1)*26
   if r[3]and jump then self:_hit("base",x+25,ry,W-38,26,function()jump(r[3])end,{bg=C.row_h});cv:chevron(x+W-26,ry+9,"right",8,C.muted)end
   cv:text(r[1],x+36,ry,W-200,26,16,C.label);cv:text(r[2],x+W-343,ry,300,26,16,C.value,"right")
  end
 end
 -- Last Mission and Recent Form have nothing to click inside, so each opens from anywhere on it
 card(L,y1,"Last Mission",Overview.mode_names[m.last.mode]or mode,m.last.id and function()self.io_tab="overview";self:_go("last")end)
 rows(L,y1+45,m.last.rows)
 card(R,y1,"Personal Bests",mode)
 rows(R,y1+45,m.bests,open_run)
 card(L,y2,"Classes")
 local tx=L+25;local hy=y2+46;local rh=28;local fit=math.floor((CH-90)/rh)
 cv:text("Class",tx+10,hy,150,30,14,C.muted);cv:text("Games",tx+56,hy,192,30,14,C.muted,"right")
 cv:text("Win %",tx+147,hy,200,30,14,C.muted,"right");cv:text("Best Win Streak",tx+239,hy,300,30,14,C.muted,"right")
 cv:rect(tx,hy+29,W-38,1,C.frame,true)
 for i,c in ipairs(m.classes)do if i>fit then break end;local ry=hy+30+(i-1)*rh
  self:_hit("base",tx,ry,W-38,rh,function()self.io_params=self.io_params or {};self.io_params.class=c.id;self.io_cls_tab=nil;self:_go("classes")end,{bg=C.row_h})
  cv:text(c.name,tx+10,ry,150,rh,16,C.label)
  if c.favourite then local nw=self:_w(c.name,16);local fw=self:_w("Favourite",14)+12;cv.z=5;cv:edges(tx+16+nw,ry+5,fw,18,1,C.frame);cv:text("Favourite",tx+16+nw,ry+5,fw,18,14,C.label,"center")end
  cv:text(tostring(c.games),tx+56,ry,192,rh,16,C.value,"right");cv:text(c.rate,tx+147,ry,200,rh,16,C.value,"right");cv:text(c.best,tx+239,ry,300,rh,16,C.value,"right")
  cv:rect(tx,ry+rh-1,W-38,1,C.line,true)
 end
 self:_recent(cv,R,y2,W,m.recent,CH)
end
function View:_recent(cv,x,y,w,r,h)
 local n=#r.bars;h=h or 207
 self:_card(cv,x,y,w,h,"Recent Form",n>0 and "Last "..n..(n==1 and " Mission"or " Missions")or nil,nil,function()self.io_trend_tab=nil;self:_go("trends")end)
 local x0,top,zone=x+25,y+49+20,h-133;local axis=top+zone
 local sw=n>0 and (w-38)/n or w-38;local bw=math.min(22,sw*.62);local max=0
 for _,b in ipairs(r.bars)do if b.damage and b.damage>max then max=b.damage end end
 cv:rect(x0,axis,n>0 and sw*n or w-38,1,C.axis,true)
 local peak
 for i,b in ipairs(r.bars)do local cx=x0+sw*(i-.5)
  if b.damage and max>0 then local h=math.max(1,zone*b.damage/max);cv:rect(cx-bw/2,axis-h,bw,h,b.win and C.gold or C.bad,true);if b.damage==max and not peak then peak={cx,axis-h}end
  else cv:rect(cx-4,axis-4,8,2,C.muted,true)end
 end
 if peak then local cx=math.min(math.max(peak[1],x0+30),x0+sw*n-30);cv:text(Overview.compact(max),cx-60,peak[2]-21,120,16,14,C.value,"center")end
 local ky=y+h-52
 cv:rect(x+36,ky+3,12,12,C.gold,true);cv:text("Win",x+55,ky,60,18,14,C.label)
 local lx2=x+55+self:_w("Win",14)+16;cv:rect(lx2,ky+3,12,12,C.bad,true);cv:text("Loss",lx2+19,ky,60,18,14,C.label)
 local v="{#color(216,229,207)}"
 local text=n>0 and v..r.wins.." Of "..n.."{#reset()} Won"..(r.average and ", Average Damage "..v..Overview.compact(r.average).."{#reset()} (Over "..r.with.." With Damage)"or "")or DASH
 cv:text(text,x+36,ky+22,w-50,18,14,C.label)
end
function View:_top(x,y)
 if not x then return end
 for gi=#GROUPS,1,-1 do local g=GROUPS[gi][1]
  if g=="base"or g=="rail"or g=="drawer"and self.drawer or g=="popup"and self.dd then
   for i=#self.hits,1,-1 do local h=self.hits[i]
    if h.g==g and x>=h.x and x<h.x+h.w and y>=h.y and y<h.y+h.h then return h end
   end
  end
 end
end
local function paint(style,x,y,w,h,c)
 c=c or C.none;style.offset[1],style.offset[2]=x,y;style.size[1],style.size[2]=w,h
 style.color[1],style.color[2],style.color[3],style.color[4]=c[1],c[2],c[3],c[4]
end
local function place(widget,hit)
 if not hit or not hit.hv then widget.visible=false;widget.io_group=nil;return end
 local s,hv,x,y,w,h=widget.style,hit.hv,hit.x,hit.y,hit.w,hit.h
 widget.visible=true;widget.io_group=hit.g
 paint(s.bg,x,y,w,h,hv.bg);paint(s.top,x,y,w,1,hv.edge);paint(s.bottom,x,y+h-1,w,1,hv.edge or hv.under);paint(s.left,x,y,1,h,hv.edge);paint(s.right,x+w-1,y,1,h,hv.edge)
 -- a whole card glows: rings outside its edge, fading outward
 if s.glow1t then for k=1,3 do local c=hv.glow and D.copy(hv.glow,GLOW[k])or nil
  paint(s["glow"..k.."t"],x-k,y-k,w+2*k,1,c);paint(s["glow"..k.."b"],x-k,y+h+k-1,w+2*k,1,c);paint(s["glow"..k.."l"],x-k,y-k+1,1,h+2*k-2,c);paint(s["glow"..k.."r"],x+w+k-1,y-k+1,1,h+2*k-2,c)
 end end
end
function View:_pointer(x,y,t)
 local span=self.rail_span;local was=self.drawer
 -- no names while the cog talks, pinned or not; they stay open while it explains the pin
 if self.intro and self.intro.phase=="talk"then self.open_at=nil;self.close_at=nil;self.drawer=false
 elseif self.pinned or self.intro and self.intro.hold_drawer then self.open_at=nil;self.close_at=nil;self.drawer=true
 elseif x and span and not self.dd then
  local icons=x>=22 and x<=66 and y>=span[1]and y<=span[2]
  local names=self.drawer and x>=-220 and x<=66 and y>=span[1]-14 and y<=span[2]+14
  if (icons or names)and not self.io_bar_drag and not self.io_slide then self.close_at=nil
   if not self.drawer then self.open_at=self.open_at or t+.18;if t>=self.open_at then self.drawer=true;self.open_at=nil end end
  else self.open_at=nil;if self.drawer then self.close_at=self.close_at or t+.12;if t>=self.close_at then self.drawer=false;self.close_at=nil end end end
 else self.open_at=nil;self.close_at=nil;self.drawer=false end
 if was~=self.drawer then if self.drawer then self.drawer_t0=t;self.drawer_k=0 end;self:_render()end
 -- while the scroll bar or a slider is held nothing under the pointer lights up
 local held=self.io_bar_drag or self.io_slide;local hit=not held and self:_top(x,y)or nil;local pair
 local key=hit and hit.key;if key~=self.io_hkey then self.io_hkey=key;self:_render();hit=not held and self:_top(x,y)or nil end
 if hit and hit.rail and self.drawer then for _,h in ipairs(self.hits)do if h.rail==hit.rail and h.g~=hit.g then pair=h end end end
 local w=self._widgets_by_name;place(w.io_hover_a,hit);place(w.io_hover_b,pair)
 self:_tip_at(hit,x,y)
end
function View:_cursor(input)
 local ok,cursor=pcall(input.get,input,"cursor");local node=self._ui_scenegraph and self._ui_scenegraph.panel;local origin=node and node.world_position
 if not ok or not cursor or not origin then return end
 local scale=self._render_scale and 1/self._render_scale or RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
 return cursor[1]*scale-origin[1],cursor[2]*scale-origin[2]
end
local function side(name)if not Mouse then return false end;local ok,down=pcall(function()return Mouse.pressed(Mouse.button_index(name))end);return ok and down==true end
-- the bound key, read straight off the keyboard or mouse: DMF reads a held key through the game's input, which the open panel takes, so the key could open the panel but not close it
local MODS={ctrl={"left ctrl","right ctrl"},shift={"left shift","right shift"},alt={"left alt","right alt"}}
-- with held set, it reports whether the key is down at all rather than pressed this frame
local function bound_pressed(held)
 local k=mod:get("dashboard_key");local main=type(k)=="table"and k[1]
 if type(main)~="string"or not Keyboard then return false end
 local ok,down=pcall(function()
  local dev,name=Keyboard,main;if main:sub(1,6)=="mouse "then dev,name=Mouse,main:sub(7):gsub(" ","_")end
  local i=dev.button_index(name);if not i then return false end
  if held then return dev.button(i)>.5 end
  if not dev.pressed(i)then return false end
  for n=2,#k do local any=false
   for _,m in ipairs(MODS[k[n]]or {k[n]})do local j=Keyboard.button_index(m);if j and Keyboard.button(j)>.5 then any=true end end
   if not any then return false end
  end
  return true
 end)
 return ok and down==true
end
View.bound_pressed=bound_pressed
function View:update(dt,t,input)
 local pass_input,pass_draw=View.super.update(self,dt,t,input);self.now=t
 -- the press that opened the panel is still down as it opens, so the key only closes it once it has been let go
 if not self.io_key_armed then self.io_key_armed=not bound_pressed(true)
 elseif self.view_name and bound_pressed()then mod.io_key_closed=os.clock();Managers.ui:close_view(self.view_name,true);return pass_input,pass_draw end
 if self.io_move then local x,y=self:_cursor(input);if side("extra_1")then self.io_move=nil;self.io_drag=nil;self:_refresh()else self:_move_input(input,x,y)end;self:_pointer(x,y,t);return pass_input,pass_draw end
 local intro=self.intro
 if intro then local ok,dirty=pcall(intro.tick,intro,self,t);if not ok then self:_intro_broken(dirty)elseif dirty then self:_render()end end
 if self.io_dirty then self.io_dirty=nil;self:_render()end
 -- the bench's live readouts move while the player hits, so in the Psykhanium its page redraws twice a second
 if self.page=="psyk"and t>=(self.io_bench_at or 0)and mod.io_is_training and mod.io_is_training()then self.io_bench_at=t+.5;self:_render()end
 if t>=(self.poll_at or 0)then self.poll_at=t+1;local rev=self:_revision();if self.rev and rev~=self.rev then self:_refresh()end;self.rev=rev end
 local x,y=self:_cursor(input)
 local taken=false
 if self.intro and pressed(input,"left_pressed")then local ok,r=pcall(self.intro.click,self.intro,self,x,y);if ok then taken=r==true else self:_intro_broken(r)end end
 if taken then
 elseif pressed(input,"left_pressed")then
  -- Back and the scroll bar leave the way forward as it was
  local hit=self:_top(x,y);if not (hit and (hit.fn==self.io_back_fn or hit.key=="io_bar"))then self.io_fwd=nil end
  if self.dd and (not hit or hit.g~="popup")then self.dd=nil end
  -- the model is built again only when a click changed what it is built from; a fn that returns true changed nothing it holds
  local before=hit and hit.fn and self:_snap()
  local k0=self:_inputs();local light=hit and hit.fn and hit.fn()
  if before then self:_came_from(before)end
  if self.view_name and Managers.ui:view_active(self.view_name)then if light or self:_inputs()==k0 then self:_render()else self:_refresh()end end
 elseif pressed(input,"right_pressed")then
  if self.dd then self.dd=nil else self:_step_back()end;self:_render()
 -- the mouse's rear side button is the Back button and its front one goes forward again, as in a browser; neither closes the panel
 elseif side("extra_1")then
  if self.dd then self.dd=nil else self:_back()end;self:_render()
 elseif side("extra_2")then
  if self.dd then self.dd=nil else self:_forward()end;self:_render()
 elseif pressed(input,"back")then
  if self.dd then self.dd=nil;self:_render()elseif self.page=="settings"then self:_close_settings();self:_refresh()else Managers.ui:close_view(self.view_name,true)end
 end
 -- a held scroll bar follows the pointer from the point it was taken by, or from its middle when the track was pressed, until let go anywhere
 local held=self.io_bar_drag
 if held then local b=self.io_bar
  if held.page~=self.page or not b or held.grab and not down(input,"left_hold")then self.io_bar_drag=nil;self:_render()
  elseif y then if not held.grab then held.grab=y>=b.ty and y<b.ty+b.th and y-b.ty or b.th/2 end
   local room=b.h-b.th;local at=room>0 and math.max(0,math.min(b.max,math.floor((y-held.grab-b.y0)*b.max/room+.5)))or 0
   self.scroll=self.scroll or {};if at~=(self.scroll[self.page]or 0)then self.scroll[self.page]=at;self:_render()end
  end
 end
 -- a held slider follows the pointer along its track until let go anywhere, or until it is no longer drawn; the press that took it sets it too
 local sl=self.io_slide
 if sl then local drawn=false;for _,h in ipairs(self.hits)do if h.key==sl.key then drawn=true;break end end
  if not drawn or not sl.fresh and not down(input,"left_hold")then self.io_slide=nil;self:_render()
  elseif x then sl.fresh=nil;local v=math.floor(sl.min+(sl.max-sl.min)*math.max(0,math.min(1,(x-sl.x-7)/math.max(1,sl.w-14)))+.5)
   if v~=sl.v then sl.v=v;sl.set(v);self:_render()end
  end
 end
 local span=self.sheet_span
 if span and x and x>=84 and x<=1306 and y>=span[1]and y<=span[2]and not self.dd and not self.io_bar_drag and not self.io_slide then
  local ok,wheel=pcall(input.get,input,"scroll_axis");local amount=ok and (type(wheel)=="number"and wheel or wheel and wheel[2])or 0
  if amount~=0 then self.scroll=self.scroll or {};local at=self.scroll[self.page]or 0;local new=math.max(0,math.min(self.scroll_max or 0,at-amount*60))
   if new~=at then self.scroll[self.page]=new;self:_render()end end
 end
 self:_pointer(x,y,t)
 -- the names panel opens leftward out of the rail, as the mockup clips it
 if self.drawer and self.drawer_t0 and self.drawer_k~=1 then local k=math.min(1,(t-self.drawer_t0)/.16);self.drawer_k=1-(1-k)^3;self:_render()end
 return pass_input,pass_draw
end
function View:_draw_widgets(dt,t,input_service,ui_renderer,render_settings)
 local UIWidget=require("scripts/managers/ui/ui_widget")
 local w=self._widgets_by_name
 local fade=self.drawer_t0 and math.max(0,math.min(1,(t-self.drawer_t0-.06)/.14))or 1
 -- on a swap the old rows scroll out of the bar while the new ones scroll in behind them, up into Settings and down out of it
 local s=self.swap_t0 and t-self.swap_t0;local k=1
 if s then k=math.min(1,s/.3);if k>=1 then self.swap_t0=nil;self.leaving=nil end else self.leaving=nil end
 local e=k<.5 and 4*k^3 or 1-(2-2*k)^3/2;local dir=self.swap_dir or 1
 local function put(wd,dy,a,dx)if wd then place_row(wd,dy);wd.alpha_multiplier=a;wd.offset[1]=dx or 0;UIWidget.draw(wd,ui_renderer)end end
 -- a locked tab shakes its head when clicked
 local nope=self.io_nope;local n=nope and (t-nope[2])/.3
 if n and (n>=1 or n<0)then self.io_nope=nil;nope=nil end
 local shake=nope and (n<.25 and -16*n or n<.75 and -4+16*(n-.25)or 16*(1-n))or 0
 local function rows(list,dy)
  for _,r in ipairs(list or {})do local y=r.y+dy;local dx=nope and r.key==nope[1]and shake or 0
   if y+r.h>TOP and y<BOTTOM then put(r.ru,dy,1,dx);put(r.ro,dy,1,dx);if self.drawer then put(r.du,dy,1);put(r.dov,dy,fade)end end
  end
 end
 rows(self.leaving,-dir*772*e);rows(self.rows,dir*772*(1-e))
 -- a tab its screen has just unlocked flashes gold and fades
 local u=self.io_unlock;local uk=u and (t-u[2])/1.2
 if uk and (uk>=1 or uk<0)then self.io_unlock=nil;u=nil end
 if u and self.page=="settings"and not s then
  for _,r in ipairs(self.rows or {})do if r.key==u[1]then local f=self.io_flash
   if not f then local cv=D.canvas();cv.z=6;cv:rect(22,0,44,40,D.rgba(221,183,99,.45));cv:edges(22,0,44,40,1,C.gold);f=cv:widgets("io_flash",12);self.io_flash=f end
   f.offset[2]=r.y;f.alpha_multiplier=1-uk;UIWidget.draw(f,ui_renderer)end end
 end
 for _,layer in ipairs(self.layers)do
  if layer.g=="drawer"and layer.over then layer.over.alpha_multiplier=fade end
  if layer.g=="base"or layer.g=="rail"or layer.g=="drawer"and self.drawer or layer.g=="popup"and self.dd then
   if layer.under then UIWidget.draw(layer.under,ui_renderer)end
   for _,hover in ipairs({w.io_hover_a,w.io_hover_b})do if hover.visible and hover.io_group==layer.g and not (s and (layer.g=="rail"or layer.g=="drawer"))then hover.offset[3]=layer.z+10;UIWidget.draw(hover,ui_renderer)end end
   if layer.over then UIWidget.draw(layer.over,ui_renderer)end
  end
 end
 -- the hover tip sits over every layer, and a tip that fails to draw is dropped, never the page
 local tip=self.io_tip
 if tip and tip.on then local ok,err=pcall(UIWidget.draw,tip.under,ui_renderer);if ok and tip.over then ok,err=pcall(UIWidget.draw,tip.over,ui_renderer)end
  if not ok then tip.on=false;tip.broken=true;mod:error("I/O tip: %s",tostring(err))end
 end
 if self.intro then local ok,err=pcall(self.intro.draw,self.intro,self,ui_renderer);if not ok then self:_intro_broken(err)end end
end
return View
