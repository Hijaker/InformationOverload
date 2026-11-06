-- Information Overload: one mission's page, also shown as Last Mission.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Data=mod:io_dofile(base.."io_data_missions")
local People=mod:io_dofile(base.."mission_presentation")
local Team=mod:io_dofile(base.."team_damage")
local H=mod:io_dofile(base.."history_presentation")
local Times=mod:io_dofile(base.."mission_times")
local Patch=mod:io_dofile(base.."game_patch")
local Faction=mod:io_dofile(base.."havoc_faction")
local Friends=mod:io_dofile(base.."friend_stats")
local Identity=mod:io_dofile(base.."player_identity")
local Timeline=mod:io_dofile(base.."combat_timeline")
local KillStreaks=mod:io_dofile(base.."kill_streaks")
local Graph=mod:io_dofile(base.."io_mission_graph")
local HitStreak,HealthStreak=KillStreaks.hit,KillStreaks.health
-- who can be tracked on the Friends page: anyone known by id who isn't already a Steam friend
local function trackable(tracker,c,actor)
 local idn=c.operative_identities and c.operative_identities[actor]or {};local roster=c.operative_roster and c.operative_roster[actor]or {}
 local key=Identity.key(roster)or Identity.key(idn);if not key or Friends.is_friend(key,roster)then return nil end
 local t=tracker.data.friend_tracking;return {id=key,on=t and t.tracked and Identity.lookup(t.tracked,key)and true or false,name=idn.steam_name or roster.steam_name or idn.friend_name or roster.friend_name or idn.name or roster.name}
end
local C,DASH,fmt=D.c,Overview.dash,Data.fmt
local ARMOUR={unarmored="Unarmoured",disgustingly_resilient="Infested",berserker="Maniac",resistant="Unyielding",armored="Flak",super_armor="Carapace",unknown="Unknown"}
local TABS={{"overview","Overview"},{"damage","Damage"},{"ff","Friendly Fire"},{"deaths","Deaths"},{"atk","Attacks"},{"build","Builds"}}
local CATS={{"total","All Damage","Total Damage"},{"melee","Melee","Melee Damage"},{"ranged","Ranged","Ranged Damage"},{"dot","Damage Over Time","Damage Over Time"},{"dot_bleed","Bleed","Bleed"},{"dot_burn","Burn","Burn"},{"dot_soulblaze","Soulblaze","Soulblaze"},{"dot_toxin","Toxin","Toxin"}}
local DOTS={{"dot_bleed","Bleed"},{"dot_burn","Burn"},{"dot_soulblaze","Soulblaze"},{"dot_toxin","Toxin"},{"dot_other","Other DoT"}}
local function pct(n,d)if not d or d<=0 then return DASH end;return string.format("%.1f%%",100*n/d)end
local function find(tracker,id)for i,run in ipairs(tracker.data.run_history or {})do if run.id==id then return run,i end end end
local function stamp(run,n)return type(n)=="number"and Times.format(Times.marker(run,n))or nil end
local function plain(s)return (tostring(s):gsub("{#[^}]*}",""))end
local function gold(s)return tostring(s):find("{#color",1,true)==1 end
local function you_first(a,b)if a.you~=b.you then return a.you==true end;return a.label<b.label end
local function enemy(s)
 if type(s)~="string"or s==""then return DASH end
 local function one(k)
  if k:find("loc_breed_display_name_",1,true)==1 then local l=Localize(k);return type(l)=="string"and l~=""and not l:find("<unlocalized",1,true)and l or "Unknown Enemy"end
  if k:find("_",1,true)and k:match("^[%w_]+$")then local key="loc_breed_display_name_"..k;local l=Localize(key);return type(l)=="string"and l~=""and l~=key and not l:find("<unlocalized",1,true)and l or "Unknown Enemy"end
  return k
 end
 local out={};for part in (s..", "):gmatch("(.-), ")do out[#out+1]=one(part)end;return table.concat(out,", ")
end
-- a weapon by its name; a best hit saves the readable name already, which stands as it is if the lookup knows nothing of it
local function weapon(id)if not id then return nil end;local ok,n=pcall(mod.io_weapon_name,id);if ok and type(n)=="string"and n~=""and n~="Unknown weapon"then return n end
 if type(id)=="string"and id:find("[%s%u]")then return id end end
local function shape(tracker,run)
 local c=run.context;local m={map=tracker:run_mission_name(c),faction=c.mode=="havoc"and Faction.label(c.havoc_faction)or nil}
 m.scope={{"Mode:",Overview.mode_names[c.mode]or DASH},{"Difficulty:",Overview.diff_label(c)},{"Patch:",c.patch and Patch.display(c.patch)or DASH}}
 local info={{"Date",run.started_at and H.timestamp(run.started_at)or DASH},{"Match","#"..tostring(run.id or DASH)},{"Result",(run.victory and "Victory"or "Defeat")..(run.full==false and ", Partial Mission"or "")},
  {"Difficulty",Overview.diff_label(c)},{"Your Class",Overview.class_names[c.class]or DASH}}
 local mods={};for _,name in pairs(c.modifiers or {})do if type(name)=="string"and name~=""and not name:find("Fading",1,true)then mods[#mods+1]=name end end;table.sort(mods)
 if #mods>0 then info[#info+1]={"Modifiers",table.concat(mods,", ")}end
 local marks,opts=run.completion_markers or {},mod.io_display_options and mod.io_display_options()or {}
 local completion=Times.completion(run)
 if run.victory and completion and type(completion.seconds)=="number"then
  local t=completion;local chosen=t.source=="mission_clock"and (opts.boss_map_timing and marks.boss_death or marks.victory_request or marks.victory_transition)
  local tip=t.source=="backend"and {"Clear Time","The mission's completion time, as the server reports it.","Every time is worked out this way, so results stay consistent across hardware, latency and each map's win conditions."}
   or t.source=="manual"and {"Clear Time","This time was typed in with Set Mission Time.","A Havoc 40 win not played from the start has no clock of its own."}
   or {"Clear Time","This match was saved before the server's time was recorded, so its time comes from the mission's own clock."}
  info[#info+1]={"Clear Time",chosen and stamp(run,chosen)or Times.format(t.seconds),tip=tip}
 end
 -- older matches kept no combat timeline; the match file is the one Team.from_run reads below
 local health=Timeline.best_health_streak(run);info[#info+1]={HealthStreak.title,health and tostring(health)or "Not Recorded",tip=HealthStreak.tip}
 local streak=Timeline.best_streak(run);info[#info+1]={HitStreak.title,streak and tostring(streak)or "Not Recorded",tip=HitStreak.tip}
 m.info=info
 local people=People.people(run,tracker);m.people={}
 for _,p in ipairs(people)do local n=p.counts or {};local id=p.personal and tostring(c.character)or p.id
  m.people[#m.people+1]={name=p.name,me=p.personal==true,id=id,downs=n.downs or 0,deaths=n.deaths or 0,pickups=n.pickups or 0,track=not p.personal and p.id and trackable(tracker,c,p.id)or nil}
 end
 local data=Team.from_run(run)
 if data then
  local over=opts.includes_overkill
  -- the player's own damage as the Damage tab gives it, for the graph's Your Damage; every entry that is the player, as one keyed by its unit before its character was known
  local me,yours=tostring(c.character),0;for id,p in pairs(data.members or {})do if id~="unknown_operative"and (p.personal==true or tostring(id)==me)then yours=yours+Team.summary(data,id,"total").reported end end;if yours>0 then m.you_reported=yours end
  local total=Team.summary(data,nil,"total");m.team={}
  for _,e in ipairs({{"total","All Damage"},{"melee","Melee"},{"ranged","Ranged"},{"dot","Damage Over Time"},{"boss","Boss Damage"}})do local b=Team.summary(data,nil,e[1])
   if b.reported>0 then m.team[#m.team+1]={e[2],fmt(over and b.reported or b.useful).." · "..pct(b.overkill,b.reported).." Overkill"}end
  end
  if total.unknown>0 then m.team[#m.team+1]={"Uncertainty",100*total.unknown/total.reported<0.1 and "<0.1%"or pct(total.unknown,total.reported)}end
  m.share={};for _,p in ipairs(m.people)do local u=Team.summary(data,p.id,"total").useful;if u>0 then m.share[#m.share+1]={name=p.me and "You"or p.name,me=p.me,v=u}end end
  table.sort(m.share,function(a,b)if a.me~=b.me then return a.me end;return a.v>b.v end);m.useful=total.useful
  m.armour={};for key in pairs(Team.armours(data))do local u=Team.summary(data,nil,"total",key).useful;if u>0 then m.armour[#m.armour+1]={ARMOUR[key]or key,u}end end
  table.sort(m.armour,function(a,b)return a[2]>b[2]end)
 end
 return m
end
local function available(run)
 local pr=run.party_records
 return {overview=true,damage=Team.from_run(run)~=nil,ff=run.incidents~=nil or run.friendly_fire_pairs~=nil,
  build=true,deaths=run.incidents~=nil or run.lethality_events~=nil or run.pickup_pairs~=nil,atk=pr~=nil and type(pr.members)=="table"and next(pr.members)~=nil}
end
-- Damage: one total, its parts and the armour split, for the team or one operative
local function damage_shape(tracker,run,sel)
 local data=Team.from_run(run);if not data then return nil end
 local c=run.context;local me=tostring(c.character);local d={opts={},snap=data.basis=="local_attack_snapshots"}
 if not d.snap then d.opts[1]={head="Whole Team"};for _,e in ipairs(CATS)do if Team.summary(data,nil,e[1]).reported>0 then d.opts[#d.opts+1]={value="team:"..e[1],label=e[2],shown="Team: "..e[2],title=e[3],ind=true}end end end
 local people={};for id,p in pairs(data.members or {})do if id~="unknown_operative"and Team.summary(data,id,"total").reported>0 then local you=p.personal==true or tostring(id)==me
  people[#people+1]={value="p:"..tostring(id),id=id,label=People.name(c,id,tracker,p.class)..(you and " (You)"or ""),you=you,ind=not d.snap,title="Total Damage"}end end
 table.sort(people,you_first);if #people>0 and not d.snap then d.opts[#d.opts+1]={head="One Operative"}end
 for _,p in ipairs(people)do p.shown=p.label;d.opts[#d.opts+1]=p end
 for _,o in ipairs(d.opts)do if not o.head and o.value==sel then d.cur=o end end
 if not d.cur then for _,o in ipairs(d.opts)do if not o.head then d.cur=o;break end end end
 if not d.cur then return d end
 local player,cat=nil,"total";if d.cur.id~=nil then player=d.cur.id else cat=d.cur.value:sub(6)end
 local b=Team.summary(data,player,cat);d.title=d.cur.title
 d.total={{l="Damage",v=fmt(b.reported)},{l="Useful Damage",v=fmt(b.useful)},{l="Overkill",v=fmt(b.overkill)},{l="Overkill %",v=pct(b.overkill,b.reported)}}
 if b.unknown>0 then d.total[#d.total+1]={l="Uncertainty",v=100*b.unknown/b.reported<0.1 and "<0.1%"or pct(b.unknown,b.reported)}end
 local recorded,keys={},{}
 for id,mem in pairs(data.members or {})do if id~="unknown_operative"and (not player or id==player)then for _,g in pairs(mem.groups or {})do for key,bk in pairs(g)do if key~="void_shield"and (bk.reported or 0)>0 then recorded[key]=true end end end end end
 for key in pairs(recorded)do local a=Team.summary(data,player,cat,key);if a.reported>0 then keys[#keys+1]={key=key,b=a}end end
 table.sort(keys,function(x,y)if x.b.useful~=y.b.useful then return x.b.useful>y.b.useful end;return x.b.reported>y.b.reported end)
 d.armour={};for _,k in ipairs(keys)do local a=k.b;local split=a.unknown<a.reported;if not split then d.unsplit=true end
  d.armour[#d.armour+1]={{ARMOUR[k.key]or "Unknown",sub=not split and "No Armour Split"or nil},split and pct(a.useful,b.useful)or nil,fmt(a.reported),split and fmt(a.useful)or nil,split and fmt(a.overkill)or nil,split and pct(a.overkill,a.reported)or nil}
 end
 if cat=="dot"then d.parts={};for _,e in ipairs(DOTS)do local x=Team.summary(data,player,e[1]);if x.reported>0 then d.parts[#d.parts+1]={e[2],pct(x.reported,b.reported),fmt(x.reported),fmt(x.overkill).." · "..pct(x.overkill,x.reported),n=x.reported}end end
  table.sort(d.parts,function(x,y)return x.n>y.n end)end
 return d
end
-- Friendly Fire, read from the mod's own lines
local function ff_shape(tracker,index)
 local lines=People.friendly_fire(tracker,index);local out={people={},notes={}};local cur,victim
 for i=2,#lines do local s=lines[i]
  if s==""then victim=nil
  elseif gold(s)then cur={name=plain(s),ff=0,murders=0,suicides=0,rows={}};out.people[#out.people+1]=cur;victim=nil
  elseif not cur then out.notes[#out.notes+1]=plain(s)
  elseif s:sub(1,2)=="  "then local k,v=s:match("^  (%a+): ([%d%.]+)$")
   if k and victim then victim[k]=tonumber(v)elseif not k then victim={name=plain(s:sub(3))};cur.rows[#cur.rows+1]=victim end
  else local k,v=s:match("^([%a ]+): ([%d%.]+)$");v=tonumber(v)
   if k=="Friendly Fire"then cur.ff=v or 0 elseif k=="Murders"then cur.murders=v or 0 elseif k=="Suicides"then cur.suicides=v or 0 end
  end
 end
 return out
end
-- Deaths and pickups, read from the mod's own lines
local function deaths_shape(tracker,index)
 local lines=People.deaths(tracker,index);local d={notes={},deaths={},pickups={},unknown={}};local mode="deaths";local cur,item
 for i=2,#lines do local s=lines[i]
  if s==""then item=nil
  elseif s=="Unknown Deaths/Pickups:"then mode="unknown";cur=nil
  elseif mode=="deaths"and s:match("^Pickups: %d+")then mode="pickups";cur=nil;d.total=s:match("^Pickups: (.+)$"):gsub("by bot","By Bot")
  elseif gold(s)then cur={name=plain(s),rows={}};local list=d[mode];list[#list+1]=cur;item=nil
  elseif not cur then if s~="No Enemy Death Records."then d.notes[#d.notes+1]=plain(s)end
  elseif mode=="deaths"then local k,v=s:match("^(%a+): (%d+)$")
   if k and item then item[k]=tonumber(v)elseif not k then item={name=enemy(s)};cur.rows[#cur.rows+1]=item end
  elseif mode=="pickups"then local k,v=s:match("^  ([%a ]+): (%d+)$")
   if k and item then item[k]=tonumber(v)elseif s:sub(1,2)=="  "and not k then item={name=plain(s:sub(3))};cur.rows[#cur.rows+1]=item end
  else local n,word=s:match("^(%d+) (%a+)$");if n then local key=word:gsub("s$","").."s";cur.rows[#cur.rows+1]={l=key,v=n}end end
 end
 return d
end
-- Attacks: kill types and the biggest hits for one operative
local BEST={{"single_hit","Biggest Single-Target Hit"},{"melee_cleave","Biggest Melee Cleave"},{"explosive_single_hit","Biggest Single Explosion (One Target)"}}
local function attack_shape(tracker,run,sel)
 local members=run.party_records and run.party_records.members or {};local c=run.context;local me=tostring(c.character)
 local a={opts={}};for id,p in pairs(members)do local you=p.personal==true or tostring(id)==me;a.opts[#a.opts+1]={value=tostring(id),key=id,label=People.name(c,id,tracker,p.class)..(you and " (You)"or ""),you=you}end
 table.sort(a.opts,you_first);for _,o in ipairs(a.opts)do if o.value==sel then a.cur=o end end;a.cur=a.cur or a.opts[1]
 if not a.cur then return a end
 local p=members[a.cur.key]or {};local k=p.kills or {}
 local typed=0;for _,f in ipairs({"horde_melee","horde_ranged","elite","special","boss"})do typed=typed+(k[f]or 0)end
 local kills=a.cur.you and type(run.kills)=="number"and run.kills or k.total or typed
 a.kills={{l="Kills",v=Overview.commas(kills)}}
 for _,e in ipairs({{"horde_melee","Melee Horde"},{"horde_ranged","Ranged Horde"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"}})do a.kills[#a.kills+1]={l=e[2],v=Overview.commas(k[e[1]]or 0),ind=true}end
 if kills>typed then a.kills[#a.kills+1]={l="No Type",v=Overview.commas(kills-typed),ind=true}end
 a.best={};for _,e in ipairs(BEST)do local r=p.best and p.best[e[1]]
  if r and type(r.value)=="number"then local rows={{l="Damage",v=fmt(r.value)}}
   local named=weapon(r.weapon);if named then rows[#rows+1]={l="Weapon",v=named}end
   if r.enemy then rows[#rows+1]={l="Enemy",v=enemy(r.enemy)}end
   if r.armour then rows[#rows+1]={l="Armour",v=ARMOUR[r.armour]or "Unknown"}end
   if e[1]=="melee_cleave"and r.hits then rows[#rows+1]={l="Hits",v=tostring(r.hits)};rows[#rows+1]={l="Targets",v=tostring(r.targets or DASH)}end
   a.best[#a.best+1]={title=e[2],rows=rows}
  end
 end
 return a
end
local function card_h(n)return 52+n*26 end
local function lead(view,cv,text,h)return {wide=true,h=h or 24,gap=6,draw=function(x,y,w)cv:text(text,x,y,w,24,14,C.muted,"left",D.font.medium)end}end
local function kv_card(view,cv,title,rows,sub,col)return {col=col,h=card_h(#rows),draw=function(x,y,w)view:_card(cv,x,y,w,card_h(#rows),title,sub);Data.kv(view,cv,x,y+45,w,rows)end}end
local function overview(view,cv,m,run)
 view:_sheet(cv,D.sheet)
 local L,R,W=D.left,D.col2,D.col
 -- the damage graph spans the top, and both columns start under it
 local top=D.sheet;local gh=Graph.overview(view,cv,run,L,top,D.width,m.you_reported);if gh then top=top+gh+10 end
 local y=top
 local h=card_h(#m.info);view:_card(cv,L,y,W,h,m.map,m.faction);view:_rows(cv,L,y+45,W,m.info)
 if view._tip then for i,r in ipairs(m.info)do if r.tip then view:_tip("base",L+25,y+45+(i-1)*26,W-50,26,r.tip)end end end;y=y+h+10
 if m.armour and #m.armour>0 then
  h=card_h(#m.armour)+24;view:_card(cv,L,y,W,h,"Armour Breakdown");cv:text("Useful damage only, without overkill.",L+36,y+42,W-60,20,14,C.muted,"left",D.font.medium)
  local top=m.armour[1][2]
  for i,a in ipairs(m.armour)do local ry=y+68+(i-1)*26
   cv:text(a[1],L+36,ry,200,26,16,C.label)
   cv:rect(L+385,ry+9,120,8,C.fill);cv:rect(L+385,ry+9,math.max(2,120*a[2]/top),8,i==1 and C.gold or C.hover)
   cv:text(pct(a[2],m.useful),L+W-313,ry,300,26,16,C.value,"right")
  end
  y=y+h+10
 end
 local with={};for _,p in ipairs(m.people)do if p.pickups>0 then with[#with+1]=p end end
 if #with>0 then
  h=86+#with*32;view:_card(cv,L,y,W,h,"Pickups")
  local hy=y+46;cv:text("Operative",L+35,hy,200,30,14,C.muted);cv:text("Pickups",L+W-313,hy,300,30,14,C.muted,"right");cv:rect(L+25,hy+29,W-50,1,C.frame,true)
  for i,p in ipairs(with)do local ry=hy+30+(i-1)*32;cv:text(p.name,L+35,ry,380,32,16,C.label);cv:text(tostring(p.pickups),L+W-313,ry,300,32,16,C.value,"right");cv:rect(L+25,ry+31,W-50,1,C.line,true)end
  y=y+h+10
 end
 y=top
 h=card_h(#m.people);view:_card(cv,R,y,W,h,"Operatives")
 for i,p in ipairs(m.people)do local ry=y+45+(i-1)*26;cv:text(p.name,R+36,ry,400,26,16,C.value)
  if not p.me and p.track then local tr=p.track;local lab=tr.on and "Tracked"or "Track";local tw=view:_w(lab,14)+16
   view:_ctl(cv,"base",R+W-26-tw,ry+3,tw,20,function()mod.io_friend_action(tr.id,tr.on and "untrack"or "track",tr.name);view:_refresh()end,{sel=tr.on});cv:text(lab,R+W-26-tw,ry+3,tw,20,14,tr.on and C.gold_hi or C.value,"center")end
 end
 y=y+h+10
 if m.team then
  local shares=#m.share;h=card_h(#m.team)+(shares>0 and 50+shares*20 or 0);view:_card(cv,R,y,W,h,"Team Damage");view:_rows(cv,R,y+45,W,m.team)
  if shares>0 then local sy=y+45+#m.team*26+8
   cv:text("Share Of Useful Team Damage",R+36,sy,300,20,14,C.muted,"left",D.font.medium)
   local bx,bw=R+36,W-72;local cx=bx
   for i,s in ipairs(m.share)do local w=bw*s.v/m.useful;cv:rect(cx,sy+24,math.max(1,w-2),14,s.me and C.gold or C.frame);cx=cx+w end
   for i,s in ipairs(m.share)do local ly=sy+44+(i-1)*20;cv:rect(bx,ly+5,10,10,s.me and C.gold or C.frame);cv:text(s.name,bx+18,ly,320,20,14,s.me and C.value or C.label);cv:text(fmt(s.v).." ("..pct(s.v,m.useful)..")",R+W-313,ly,300,20,14,C.value,"right")end
  end
  y=y+h+10
 end
 local hit={};for _,p in ipairs(m.people)do if p.downs>0 or p.deaths>0 then hit[#hit+1]=p end end
 if #hit>0 then
  h=86+#hit*32;view:_card(cv,R,y,W,h,"Deaths And Downs")
  local hy=y+46;cv:text("Operative",R+35,hy,200,30,14,C.muted);cv:text("Downs",R+W-200,hy,80,30,14,C.muted,"right")
  cv:text("Deaths",R+W-120,hy,94,30,14,C.muted,"right");cv:rect(R+25,hy+29,W-50,1,C.frame,true)
  for i,p in ipairs(hit)do local ry=hy+30+(i-1)*32;cv:text(p.name,R+35,ry,320,32,16,C.label);cv:text(tostring(p.downs),R+W-200,ry,80,32,16,C.value,"right");cv:text(tostring(p.deaths),R+W-120,ry,94,32,16,C.value,"right");cv:rect(R+25,ry+31,W-50,1,C.line,true)end
 end
 view:_sheet_end(cv)
end
local function damage(view,cv,popup,d,st,run)
 local graph=Graph.damage(view,cv,run,st,d and d.cur)
 if not d or not d.cur then
  if not graph then view:_card(cv,D.left,D.sheet,D.width,92,"No Damage Breakdown");return end
  view:_sheet(cv,D.sheet);Data.layout(view,{graph,{wide=true,h=92,draw=function(x,y,w)view:_card(cv,x,y,w,92,"No Damage Breakdown")end}},D.sheet);view:_sheet_end(cv);return
 end
 local opts={};for _,o in ipairs(d.opts)do opts[#opts+1]=o.head and {head=o.head}or {value=o.value,current=d.cur.value,label=o.label,ind=o.ind}end
 Data.dropdown(view,cv,popup,"io_run_det",1010,D.row2,280,"Detail:",d.cur.shown,opts,function(v)st.det=v end)
 view:_sheet(cv,D.sheet)
 local sub=d.snap and "Weapon Hits Only"or nil;local cards={kv_card(view,cv,d.title,d.total,sub,1)}
 if graph then table.insert(cards,1,graph)end
 if d.parts and #d.parts>0 then local n=#d.parts
  cards[#cards+1]={col=2,h=46+Data.table_h(n)+12,draw=function(x,y,w)view:_card(cv,x,y,w,46+Data.table_h(n)+12,"By Kind");Data.table(view,cv,x,y+46,w,{{"Kind"},{"Share",250},{"Damage",390},{"Overkill",w-35}},d.parts)end}
 end
 if #d.armour>0 then local n=#d.armour;local h=46+Data.table_h(n)+(d.unsplit and 28 or 0)+12
  cards[#cards+1]={wide=true,h=h,draw=function(x,y,w)view:_card(cv,x,y,w,h,"By Armour",sub)
   local th=Data.table(view,cv,x,y+46,w,{{"Armour"},{"Useful Share",580},{"Damage",721},{"Useful",862},{"Overkill",1003},{"Overkill %",w-35}},d.armour)
   if d.unsplit then cv:text("Unknown is damage the game reported without an armour type, so useful damage and overkill cannot be split.",x+35,y+50+th,w-70,24,14,C.muted,"left",D.font.medium)end end}
 end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
local function friendly(view,cv,f)
 view:_sheet(cv,D.sheet)
 local cards={};for _,n in ipairs(f.notes)do cards[#cards+1]=lead(view,cv,n)end
 local quiet,loud={},0
 for _,p in ipairs(f.people)do
  if p.ff<=0 and #p.rows==0 and p.murders<=0 and p.suicides<=0 then quiet[#quiet+1]=p.name
  else loud=loud+1;local head={{l="Friendly Fire",v=Overview.commas(p.ff)}}
   if #p.rows==0 then if p.murders>0 then head[#head+1]={l="Murders",v=tostring(p.murders)}end;if p.suicides>0 then head[#head+1]={l="Suicides",v=tostring(p.suicides)}end end
   local fields,m,s={"Damage"},false,false;for _,r in ipairs(p.rows)do m=m or (r.Murders or 0)>0;s=s or (r.Suicides or 0)>0 end
   if m then fields[#fields+1]="Murders"end;if s then fields[#fields+1]="Suicides"end
   local cols={{"Who They Hit"}};for i,k in ipairs(fields)do cols[#cols+1]={k,D.col-35-(#fields-i)*100}end
   local rows={};for _,r in ipairs(p.rows)do local row={r.name};for i,k in ipairs(fields)do row[i+1]=Overview.commas(r[k]or 0)end;rows[#rows+1]=row end
   local h=card_h(#head)+(#rows>0 and Data.table_h(#rows)+6 or 0)
   cards[#cards+1]={h=h,draw=function(x,y,w)view:_card(cv,x,y,w,h,p.name);Data.kv(view,cv,x,y+45,w,head);if #rows>0 then Data.table(view,cv,x,y+45+#head*26+4,w,cols,rows)end end}
  end
 end
 if loud==0 then cards[#cards+1]={wide=true,h=92,draw=function(x,y,w)view:_card(cv,x,y,w,92,"No Friendly Fire")end}
 elseif #quiet>0 then cards[#cards+1]=lead(view,cv,"No friendly fire from "..table.concat(quiet,", ")..".")end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
local function deaths(view,cv,d)
 view:_sheet(cv,D.sheet)
 local cards={};for _,n in ipairs(d.notes)do cards[#cards+1]=lead(view,cv,n)end
 local function group(title,text,list,right,cols,fields)
  if #list==0 and not right then return end
  cards[#cards+1]={wide=true,h=40,gap=8,draw=function(x,y,w)Data.section(view,cv,x,y,w,title,text,right)end}
  for _,p in ipairs(list)do
   if cols then local rows={};for _,r in ipairs(p.rows)do local row={r.name};for i,k in ipairs(fields)do row[i+1]=tostring(r[k]or 0)end;rows[#rows+1]=row end
    local h=46+Data.table_h(#rows)+12;cards[#cards+1]={h=h,draw=function(x,y,w)view:_card(cv,x,y,w,h,p.name);Data.table(view,cv,x,y+46,w,cols,rows)end}
   else cards[#cards+1]=kv_card(view,cv,p.name,p.rows)end
  end
 end
 group("Deaths And Downs","What downed or killed each operative.",d.deaths,nil,{{"Enemy"},{"Downs",387},{"Deaths",D.col-35}},{"Downs","Deaths"})
 local plain_pick=false;for _,p in ipairs(d.pickups)do for _,r in ipairs(p.rows)do if r.Pickups then plain_pick=true end end end
 local pcols,pf={{"Picked Up"},{"From Down",387},{"From Hogtie",D.col-35}},{"Down Pickups","Hogtie Pickups"}
 if plain_pick then pcols={{"Picked Up"},{"From Down",287},{"From Hogtie",420},{"Pickups",D.col-35}};pf={"Down Pickups","Hogtie Pickups","Pickups"}end
 group("Pickups","Who picked up whom.",d.pickups,d.total and d.total~="0"and {"Team Pickups",d.total}or nil,pcols,pf)
 group("Unknown Deaths And Pickups","Downs and deaths with no known cause, and pickups with no known teammate.",d.unknown)
 if #cards==0 then cards[1]={wide=true,h=92,draw=function(x,y,w)view:_card(cv,x,y,w,92,"No Deaths Or Pickups")end}end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
local function attacks(view,cv,popup,a,st)
 if not a or not a.cur then view:_card(cv,D.left,D.sheet,D.width,92,"No Attack Records");return end
 local opts={};for _,o in ipairs(a.opts)do opts[#opts+1]={value=o.value,current=a.cur.value,label=o.label}end
 Data.dropdown(view,cv,popup,"io_run_atk",1010,D.row2,280,"Operative:",a.cur.label,opts,function(v)st.atk=v end)
 view:_sheet(cv,D.sheet)
 local cards={kv_card(view,cv,"Kills By Type",a.kills)}
 for _,b in ipairs(a.best)do cards[#cards+1]=kv_card(view,cv,b.title,b.rows)end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
local function builds(view,cv,popup,run,tracker,st)
 local c=run.context
 local snapshots=c.operative_loadouts or {}
 local members=run.party_records and run.party_records.members or {}
 local roster,identities=c.operative_roster or {},c.operative_identities or {}
 local ids,opts={},{}
 for id in pairs(snapshots)do
  if not c.character or id~=c.character_name then ids[id]=true end
 end
 for id in pairs(identities)do ids[id]=true end
 for id in pairs(roster)do ids[id]=true end
 for id in pairs(members)do ids[id]=true end
 if c.character then ids[tostring(c.character)]=true end
 for id in pairs(ids)do
  local member=members[id] or {}
  local you=member.personal==true or tostring(id)==tostring(c.character)
  local legacy_name=not (you or roster[id] or identities[id]) and (c.teammates or {})[id] and id
  local label=legacy_name or People.name(c,id,tracker,member.class)
  opts[#opts+1]={value=tostring(id),label=label..(you and " (You)" or ""),you=you}
 end
 table.sort(opts,you_first)
 local current=opts[1]
 for _,o in ipairs(opts)do if o.value==st.build then current=o end end
 if current then
  for _,o in ipairs(opts)do o.current=current.value end
  Data.dropdown(view,cv,popup,"io_run_build",1010,D.row2,280,"Operative:",current.label,opts,function(v)st.build=v end)
 end
 view:_sheet(cv,D.sheet)
 local cards={}
 local snapshot=current and (snapshots[current.value] or current.you and snapshots[c.character_name])
 if snapshot then
  local function add_perks(rows,perks)
   rows[#rows+1]={head="Perks"}
   for label in (perks or "Unavailable"):gmatch("[^/]+")do
    rows[#rows+1]={note=label:match("^%s*(.-)%s*$")}
   end
  end
  for _,slot in ipairs({{"melee","Melee"},{"ranged","Ranged"}})do
   local id=slot[1]
   if snapshot[id] or snapshot[id.."_perks"] or snapshot[id.."_blessings"] then
    local rows={{head=snapshot[id] or "Item unavailable"}}
    add_perks(rows,snapshot[id.."_perk_details"] or snapshot[id.."_perks"])
    rows[#rows+1]={head="Blessings"}
    rows[#rows+1]={note=snapshot[id.."_blessings"] or "Unavailable"}
    cards[#cards+1]=kv_card(view,cv,slot[2],rows)
   end
  end
  local curios,by_bonus={},{}
  for i=1,3 do
   local id="curio_"..i
   local name,bonus,perks=snapshot[id],snapshot[id.."_blessings"],snapshot[id.."_perks"]
   if name or bonus or perks then
    local kind=bonus and bonus~="None" and bonus~="Unknown blessing" and bonus or name or "Curio bonus unavailable"
    local group=by_bonus[kind]
    if not group then
     group={kind=kind,sets={},by_perks={}}
     curios[#curios+1]=group
     by_bonus[kind]=group
    end
    local labels={}
    for label in (perks or "Unavailable"):gmatch("[^/]+")do labels[#labels+1]=label:match("^%s*(.-)%s*$") end
    table.sort(labels)
    local key=table.concat(labels," / ")
    local set=group.by_perks[key]
    if not set then
     set={perks=key,count=0}
     group.sets[#group.sets+1]=set
     group.by_perks[key]=set
    end
    set.count=set.count+1
   end
  end
  local rows={}
  for _,group in ipairs(curios)do
   for _,set in ipairs(group.sets)do
    rows[#rows+1]={head=group.kind..(set.count>1 and " ×"..set.count or "")}
    add_perks(rows,set.perks)
   end
  end
  if #rows>0 then cards[#cards+1]=kv_card(view,cv,"Curios",rows)end
  rows={}
  for _,field in ipairs({{"aura","Aura"},{"blitz","Blitz"},{"keystone","Keystone"}})do
   if snapshot[field[1]] then rows[#rows+1]={l=field[2],v=snapshot[field[1]]}end
  end
  if #rows>0 then cards[#cards+1]=kv_card(view,cv,"Talents",rows)end
 end
 if #cards==0 then
  cards[1]=kv_card(view,cv,"Build Unavailable",{{note="No build data was saved for this operative."}})
 end
 Data.layout(view,cards,D.sheet);view:_sheet_end(cv)
end
return function(view,cv,popup)
 local tracker=view:_tracker();local model=view.model
 local last=view.page=="last";local id;if last then id=model and model.last and model.last.id else id=view.io_params and view.io_params.run end
 local run,index
 if tracker and id then run,index=find(tracker,id)end
 if not run then view:_card(cv,D.left,D.row2,D.width,92,"No Missions Recorded Yet");return end
 local okm,m,avail=pcall(function()return shape(tracker,run),available(run)end)
 if not okm then view:_card(cv,D.left,D.row2,D.width,92,"This Match File Could Not Be Read");local said=view.page.."|"..tostring(m);if view.io_said~=said then view.io_said=said;mod:error("I/O %s: %s",view.page,tostring(m))end;return end
 local st=view.io_run_sel;if not st or st.id~=run.id then st={id=run.id};view.io_run_sel=st end
 view.io_tab=view.io_tab or "overview";if not avail[view.io_tab]then view.io_tab="overview"end
 local label="Overview";for _,t in ipairs(TABS)do if t[1]==view.io_tab then label=t[2]end end
 local function reset()if view.scroll then view.scroll[view.page]=0 end end
 local first=last and {"Last Mission",function()view.io_tab="overview";reset()end}or {"Match History",function()view:_go("history")end}
 view.io_crumbs={first,{m.map,function()view.io_tab="overview";reset()end},{label}}
 local x=100;for _,s in ipairs(m.scope)do local lw=view:_w(s[1],16);cv:text(s[1],x,D.top,lw+4,34,16,C.label);local vw=view:_w(s[2],16);cv:text(s[2],x+lw+8,D.top,vw+6,34,16,C.value);x=x+lw+vw+40 end
 -- Use the existing transactional delete/rebuild action; never mutate history here.
 if mod.io_delete_match then
  view:_ctl(cv,"base",D.right-150,D.top,150,34,function()
   local event=Managers.event;if not event then return end
   local selected=run.id
   event:trigger("event_show_ui_popup",{title_text_unlocalized="Delete Match",description_text_unlocalized="Delete this match and rebuild records and streaks from the remaining Match History?\n\nThis cannot be undone.",options={
    {text="Delete Match",no_localization=true,close_on_pressed=true,callback=function()
     local ok,reason=mod.io_delete_match(selected)
     -- back to Match History without leaving the deleted mission behind it for Back
     if ok then
      -- nothing behind or ahead may lead back to the deleted mission
      local keep,rb={},{};for i,p in ipairs(view.stack)do local r=view.io_run_back and view.io_run_back[i];if not (p=="run"and r==selected)then keep[#keep+1]=p;rb[#keep]=r end end;view.stack,view.io_run_back=keep,rb
      for _,list in ipairs({view.io_steps or {},view.io_fwd or {}})do for i=#list,1,-1 do if list[i].page=="run"and list[i].v["@run"]==selected then table.remove(list,i)end end end
      -- Last Mission now shows another mission, so it stays behind Match History as the rail leaves it
      if view.page=="last"then local was=view:_snap();view:_go("history");view:_came_from(was)elseif view.stack[#view.stack]=="history"then view.page=table.remove(view.stack);view.io_run_back[#view.stack+1]=nil else view.page="history"end
      -- the click that opened the mission from Match History left a step to the very place this lands on
      local st=view.io_steps;if st and st[#st]and st[#st].page=="history"then st[#st]=nil end;view:_refresh()else mod:echo("%s",reason or "The match could not be deleted.")end
    end},
    {text="Cancel",no_localization=true,close_on_pressed=true,hotkey="back"}}})
  end,{hv={bg=C.fill_h,edge=C.bad}})
  cv:text("Delete Match",D.right-150,D.top,150,34,16,C.bad,"center")
 end
 -- a Havoc 40 win merged from a rejoin has no clock of its own; its time can be typed in here
 if mod.io_manual_time_allowed and mod.io_manual_time_allowed(run)then
  local label=run.completion_time and "Change Mission Time"or "Set Mission Time";local bx=D.right-150-16-190
  view:_ctl(cv,"base",bx,D.top,190,34,function()mod.io_offer_manual_time(run.id,function()view.io_hist_rows=nil;view:_refresh()end)end,{hv={bg=C.fill_h}})
  cv:text(label,bx,D.top,190,34,16,C.value,"center")
 end
 local tx=100;for _,t in ipairs(TABS)do if avail[t[1]]then local w=view:_w(t[2],16)+30;local sel=view.io_tab==t[1]
  view:_ctl(cv,"base",tx,D.row2,w,34,function()if view.io_tab~=t[1]then view.io_tab=t[1];reset()end end,{sel=sel});cv:text(t[2],tx,D.row2,w,34,16,sel and C.gold_hi or C.value,"center");tx=tx+w+8 end end
 local tab=view.io_tab
 if tab=="overview"then return overview(view,cv,m,run)end
 if tab=="build"then return builds(view,cv,popup,run,tracker,st)end
 local okT,data
 if tab=="damage"then okT,data=pcall(damage_shape,tracker,run,st.det)
 elseif tab=="ff"then okT,data=pcall(ff_shape,tracker,index)
 elseif tab=="deaths"then okT,data=pcall(deaths_shape,tracker,index)
 else okT,data=pcall(attack_shape,tracker,run,st.atk)end
 if not okT then view:_card(cv,D.left,D.sheet,D.width,92,"No Data Recorded");mod:error("I/O mission %s: %s",tab,tostring(data));return end
 if tab=="damage"then damage(view,cv,popup,data,st,run)elseif tab=="ff"then friendly(view,cv,data)elseif tab=="deaths"then deaths(view,cv,data)else attacks(view,cv,popup,data,st)end
end
