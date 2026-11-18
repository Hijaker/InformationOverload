-- Information Overload: Records, the biggest hits and the most in one mission.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_stats")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local RD=mod:io_dofile(base.."io_records_damage")
local C,DASH,CN=D.c,K.dash,K.class_names
local X,W=D.left,D.width
local ND={{"downs","Downs"},{"pounces","Pox Hound Pounces"},{"nets","Trapper Nets"},{"mutant_charges","Mutant Catches"},{"deaths","Deaths"},{"pickups","Pickups"},{"friendly_fire","Friendly Fire Damage"}}
local RES={{"all","All Missions"},{"win","Wins"},{"loss","Losses"}}
local function nondamage(view,cv,tracker,s,res,y)
 local sum=Nav.incident_outcome_summary(tracker,s.patch,s.mode,res~="all"and res or nil)
 if not sum then return K.empty(view,cv,y,"No Non-Damage Records Yet")end
 local b,src,runs=sum.best,sum.sources,sum.record_runs
 local function cell(id,text)local n=b[id];if not n or n<=0 then return {DASH,nil,C.muted}end;return text or (id:find("friendly_fire",1,true)and K.exact(n)or tostring(n))end
 local function top(own_id,other_id)local own,other=b[own_id]or 0,b[other_id]or 0;local n=math.max(own,other);if n<=0 then return {DASH,nil,C.muted}end
  local me=own>=other;local source=src[me and own_id or other_id]or {};local who=me and " (You)"or source.friend_name and " ("..source.friend_name..")"or ""
  local num=own_id:find("friendly_fire",1,true)and K.exact(n)or tostring(n);return num.." · "..(CN[source.class]or "Unknown Class")..who end
 local list={}
 for _,f in ipairs(ND)do local own=f[1]=="mutant_charges"and "mutant_charges_mission"or "personal_"..f[1].."_mission";local team="team_"..f[1].."_mission"
  if (b[own]or 0)>0 or (b[team]or 0)>0 or (b["teammate_"..f[1].."_mission"]or 0)>0 then list[#list+1]={f[2],cell(own),top(own,"teammate_"..f[1].."_mission"),cell(team),act=runs[own]and K.open_run(view,runs[own])or nil}end end
 for _,p in ipairs({{"total","Total Bosses"},{"real","Real Bosses"}})do local own="personal_boss_"..p[1].."_mission";local team="team_boss_"..p[1].."_mission"
  if (b[team]or 0)>0 then list[#list+1]={p[2],cell(own),top(own,"teammate_boss_"..p[1].."_mission"),cell(team),act=runs[team]and K.open_run(view,runs[team])or nil}end end
 if #list==0 then return K.empty(view,cv,y,"No Non-Damage Records Yet")end
 y=y+K.table(view,cv,X,y,W,{{"Most In One Mission",10,"l"},{"You",470},{"Top Operative",940},{"Team",W-10}},list)+10
 local n=b.team_ritual_stops_mission
 if n and n>0 then local L=D.col;view:_card(cv,X,y,L,76,"Team Records")
  local run=runs.team_ritual_stops_mission;view:_rows(cv,X,y+45,L,{{"Most Rituals Stopped In A Mission",tostring(n),run}},run and K.open_run(view,run))
  y=y+86 end
 return y
end
return function(view,cv,popup)
 local tracker=view:_tracker();local m=view.model
 if not tracker or not m or m.empty then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 view:_scope(cv,popup,m,nil,true)
 local s=view.scope;local tab=view.io_rec_tab=="nd"and "nd"or "damage"
 local reset=function()if view.scroll then view.scroll.records=0 end end
 K.tabs(view,cv,{{"damage","Damage"},{"nd","Non-Damage"}},tab,function(v)view.io_rec_tab=v;reset()end)
 local draw
 do
  if tab=="damage"then
   local played,seen={},{};for _,row in pairs(tracker.data.rows or {})do local c=row.context;if c.mode==s.mode and (not s.patch or c.patch==s.patch)and CN[c.class]and not seen[c.class]then seen[c.class]=true;played[#played+1]=c.class end end
   local order={veteran=1,zealot=2,psyker=3,ogryn=4,adamant=5,broker=6,cryptic=7};table.sort(played,function(a,b)return (order[a]or 9)<(order[b]or 9)end)
   local cls=view.io_rec_class;if cls and not seen[cls]then cls=nil;view.io_rec_class=nil end
   local rows=RD.rows_of(tracker,s,cls)
   local dets=RD.details(rows,cls)
   local det=view.io_rec_detail or "overall";local label;for _,d in ipairs(dets)do if d[1]==det then label=d[2]end end;if not label then det="overall";label="Overall"end
   local copts={{value="all",current=cls or "all",label="All Classes"}};for _,c in ipairs(played)do copts[#copts+1]={value=c,current=cls or "all",label=CN[c]}end
   K.dd(view,cv,popup,"rcls",800,D.row2,200,"Class:",cls and CN[cls]or "All",copts,function(v)view.io_rec_class=v~="all"and v or nil end)
   local dopts={};for _,d in ipairs(dets)do dopts[#dopts+1]={value=d[1],current=det,label=d[2]}end
   K.dd(view,cv,popup,"rdet",D.right-280,D.row2,280,"Detail:",label,dopts,function(v)view.io_rec_detail=v;reset()end)
   -- a crumb is a link only where it leads somewhere; at the page's start they all lead back to it
   local top=(cls or det~="overall")and function()view.io_rec_class=nil;view.io_rec_detail=nil end or nil
   view.io_crumbs={{"Records",top},{"Damage",top},{cls and CN[cls]or "All Classes",det~="overall"and function()view.io_rec_detail=nil end or nil},{label}}
   draw=function()RD.cards(view,cv,tracker,rows,det,cls,D.sheet)end
  else
   local res=view.io_rec_result or "all";local label="All Missions";for _,r in ipairs(RES)do if r[1]==res then label=r[2]end end
   local opts={};for _,r in ipairs(RES)do opts[#opts+1]={value=r[1],current=res,label=r[2]}end
   K.dd(view,cv,popup,"rres",D.right-280,D.row2,280,"Result:",label,opts,function(v)view.io_rec_result=v end)
   view.io_crumbs={{"Records",function()view.io_rec_tab="damage"end},{"Non-Damage",res~="all"and function()view.io_rec_result=nil end or nil},{label}}
   draw=function()nondamage(view,cv,tracker,s,res,D.sheet)end
  end
 end
 view:_sheet(cv,D.sheet);draw();view:_sheet_end(cv)
end
