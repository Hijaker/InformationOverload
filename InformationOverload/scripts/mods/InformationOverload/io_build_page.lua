-- Information Overload: a match's Build tab: an operative's weapons, curios and talent tree, and what the talents did where the match recorded it.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local Overview=mod:io_dofile(base.."io_overview")
local Data=mod:io_dofile(base.."io_data_missions")
local People=mod:io_dofile(base.."mission_presentation")
local Loadouts=mod:io_dofile(base.."operative_loadout")
local Tree=mod:io_dofile(base.."talent_tree")
local Tip=mod:io_dofile(base.."io_game_tip")
local C,F=D.c,D.font
local TURN=3.5
local TOP_H,GAP,TREE_W=160,10,300
local GROUPS={"Damage","Survival","Utility"}
local function plain(s)return (tostring(s or ""):gsub("{#[^}]*}",""))end
local function you_first(a,b)if a.you~=b.you then return a.you==true end;return a.label<b.label end
local function split(s,sep)local out={};for p in (tostring(s or "")..sep):gmatch("(.-)"..sep)do p=p:match("^%s*(.-)%s*$");if p~=""and p~="None"and p~="Unavailable"then out[#out+1]=p end end;return out end
-- game text drawn in its colours while it fits, else cut down as plain text
local function line(view,cv,s,x,y,w,h,size,c,font)
 s=tostring(s);if view:_w(s,size,font)>w then s=view:_fit(plain(s),size,w,font)end
 cv:text(s,x,y,w+40,h,size,c,"left",font)
end
local function operatives(view,cv,popup,run,tracker,st)
 local c=run.context;local mt=getmetatable(run);local snapshots=(mt and mt.io_loadouts and mt.io_loadouts(run)or c.operative_loadouts)or {};local members=run.party_records and run.party_records.members or {}
 local roster,identities=c.operative_roster or {},c.operative_identities or {}
 local ids,opts,named={},{},{}
 -- a match saved from 7 to 27 October keys each build by character name, so a name its roster or identities give an id is listed once, by that id
 for _,list in ipairs({roster,identities})do for _,who in pairs(list)do if type(who)=="table"and who.name then named[who.name]=true end end end
 for id in pairs(snapshots)do if (not c.character or id~=c.character_name)and not named[id]then ids[id]=true end end
 for id in pairs(identities)do ids[id]=true end
 for id in pairs(roster)do ids[id]=true end
 for id in pairs(members)do ids[id]=true end
 if c.character then ids[tostring(c.character)]=true end
 for id in pairs(ids)do
  local member=members[id]or {};local you=member.personal==true or tostring(id)==tostring(c.character)
  local legacy_name=not (you or roster[id]or identities[id])and (c.teammates or {})[id]and id
  local cls=member.class or (identities[id]or {}).class or (roster[id]or {}).class or legacy_name and type(c.teammates[id])=="string"and c.teammates[id]or nil
  opts[#opts+1]={value=tostring(id),label=legacy_name or People.name(c,id,tracker,member.class),you=you,class=cls}
 end
 table.sort(opts,you_first)
 local current=opts[1];for _,o in ipairs(opts)do if o.value==st.build then current=o end end
 if current then for _,o in ipairs(opts)do o.current=current.value end
  Data.dropdown(view,cv,popup,"io_run_build",1010,D.row2,280,"Operative:",current.label,opts,function(v)st.build=v end)
 end
 if not current then return end
 local snapshot=snapshots[current.value]or current.you and snapshots[c.character_name]
 if not snapshot then local who=identities[current.value]or roster[current.value];snapshot=type(who)=="table"and who.name and snapshots[who.name]or nil end
 return snapshot,current.you and c.class or current.class,current
end
local function weapon(view,cv,x,y,w,h,title,snap,id)
 view:_card(cv,x,y,w,h,title)
 local cx,cw=x+36,w-72
 line(view,cv,snap[id]or "Item Unavailable",cx,y+42,cw,26,16,snap[id]and C.value or C.muted)
 local ry=y+70
 for i,p in ipairs(split(snap[id.."_perk_details"]or snap[id.."_perks"],"/"))do if i>2 then break end;line(view,cv,p,cx,ry,cw,20,14,C.value,F.medium);ry=ry+20 end
 local names=split(snap[id.."_blessings"],",");if #names==0 then return end
 -- each blessing opens its text, as the game words it now, when the pointer rests on it; an older match's are matched by name
 local by=y+h-42;local lw=view:_w("Blessings",14);cv:text("Blessings",cx,by,lw+6,22,14,C.gold)
 local bx,room=cx+lw+10,cw-lw-10;local all=table.concat(names,", ");local traits=Loadouts.blessing_refs(snap,id)
 cv:text(view:_fit(all,14,room,F.medium),bx,by,room+40,22,14,C.label,"left",F.medium)
 for i,name in ipairs(names)do
  local x0=bx+(i>1 and view:_w(table.concat(names,", ",1,i-1)..", ",14,F.medium)or 0);local x1=math.min(bx+room,x0+view:_w(name,14,F.medium))
  local text=x1-x0>10 and Loadouts.trait_text(traits[i])
  if text then view:_hit("base",x0,by,x1-x0,22,nil,{under=C.value},nil,Tip.lines("blessing|"..name.."|"..text,function()return {kind="Blessing",name=name,text=text}end))end
 end
end
-- the curios, one at a time: they turn every few seconds while the pointer is off them, and 1 2 3 holds one; st is the operative's own, so each keeps its place
local function curios(view,cv,x,y,w,h,snap,st)
 view:_card(cv,x,y,w,h,"Curios")
 local list={}
 for i=1,3 do local id="curio_"..i;local name,bonus=snap[id],snap[id.."_blessings"]
  if name or bonus or snap[id.."_perks"]then
   local kind=bonus and bonus~="None"and bonus~="Unknown blessing"and bonus or name or "Curio Bonus Unavailable"
   local perks=split(snap[id.."_perks"],"/");local sorted={};for j,p in ipairs(perks)do sorted[j]=plain(p)end;table.sort(sorted)
   list[#list+1]={slot=i,kind=kind,perks=perks,key=plain(kind).."|"..table.concat(sorted,"|")}
  end
 end
 if #list==0 then cv:text("No curios were saved for this operative.",x+36,y+44,w-72,24,14,C.muted,"left",F.medium);return end
 local alike=true;for _,c in ipairs(list)do if c.key~=list[1].key then alike=false end end
 local n=#list;local at=math.min(st.curio or 1,n)
 if n>1 and not alike then
  view:_hit("base",x,y,w,h,nil,nil,nil,nil,"io_curio")
  if not st.curio_hold and view.io_hkey~="io_curio"then local now=view.now or 0
   -- a turn missed by more than a moment was missed off the tab, so the wait starts again rather than flipping the moment the tab shows
   if not st.curio_next or now-st.curio_next>.5 then st.curio_next=now+TURN elseif now>=st.curio_next then at=at%n+1;st.curio_next=now+TURN end
   view.redraw_at=st.curio_next
  else st.curio_next=nil end
  for i,c in ipairs(list)do local bx,on=x+w-14-(n-i+1)*30,i==at
   cv.z=6;cv:rect(bx,y+14,26,20,on and C.fill_s or C.fill);cv:edges(bx,y+14,26,20,1,on and C.sel or C.frame)
   cv:text(tostring(c.slot),bx,y+14,26,20,13,on and C.gold_hi or C.value,"center")
   view:_hit("base",bx,y+14,26,20,function()st.curio,st.curio_hold=i,true;return true end,not on and {bg=C.fill_h,edge=C.hover}or nil,nil,nil,"io_curio")
  end
 end
 st.curio=at
 local c,cx,cw=list[at],x+36,w-72
 local same=0;for _,o in ipairs(list)do if o.kind==c.kind then same=same+1 end end
 local tag=same<3 and same.." Of 3"or nil;local tw=tag and view:_w(tag,13,F.medium)+10 or 0
 line(view,cv,c.kind,cx,y+42,cw-tw,26,16,C.value)
 if tag then cv:text(tag,cx+math.min(view:_w(c.kind,16),cw-tw)+10,y+44,tw,24,13,C.muted,"left",F.medium)end
 local ry=y+70
 for i,p in ipairs(c.perks)do if i>3 then break end;line(view,cv,p,cx,ry,cw,20,14,C.value,F.medium);ry=ry+20 end
 local twin;for _,o in ipairs(list)do if o~=c and o.key==c.key then twin=twin or o.slot end end
 if alike and n>1 then cv:text(n==2 and "Both Curios Alike."or "All "..n.." Curios Alike.",cx,y+h-30,cw,20,13,C.muted,"left",F.medium)
 elseif twin then cv:text("Same As Curio "..twin..".",cx,y+h-30,cw,20,13,C.muted,"left",F.medium)end
end
-- what each talent did; report={total=,rows={{node=,group=,detail=,share= or figure=}}}, which the match file carries once it is recorded
local function report_rows(report)
 local by,list={},{}
 for _,r in ipairs(type(report)=="table"and type(report.rows)=="table"and report.rows or {})do if r.node and r.group then by[r.group]=by[r.group]or {};table.insert(by[r.group],r)end end
 for _,g in ipairs(GROUPS)do if by[g]then list[#list+1]={head=g};for _,r in ipairs(by[g])do list[#list+1]=r end end end
 return list
end
-- the build's picks by kind, for a match with no talent figures: read off the trees, or for a build saved before talents were kept, off its saved names
local KINDS={{"Combat Ability",{ability=1,ability_modifier=1},"ability"},{"Blitz",{tactical=1,tactical_modifier=1},"blitz"},{"Aura",{aura=1,aura_modifier=1},"aura"},
 {"Keystone",{keystone=1,keystone_modifier=1},"keystone"},{"Talents",{default=1}},{"Stat Boosts",{stat=1}},{"Stimm Lab",{broker_stimm=1}}}
local function picks(build,snap)
 local out,seen={},{};local saved=build.legacy or not build[1].tree
 for _,k in ipairs(KINDS)do local names,count,order={},{},{}
  local function add(name)if not count[name]then order[#order+1]=name end;count[name]=(count[name]or 0)+1 end
  if not saved then for _,b in ipairs(build)do if b.tree then for _,n in ipairs(b.tree.nodes)do if k[2][n.type]and b.picked[n.name]then add(Tree.name(b.tree,n))end end end end
  elseif k[3]then for _,v in ipairs(split(snap[k[3]],","))do add(v)end
  -- with no tree to read, the saved talents are listed, the ones named above left out
  elseif k[1]=="Talents"then for _,t in ipairs(type(snap.talents)=="table"and snap.talents or {})do if t.name and not seen[t.name]then add(t.name)end end end
  for _,name in ipairs(order)do seen[name]=true;names[#names+1]=name..(count[name]>1 and " ×"..count[name]or "")end
  if #names>0 then out[#out+1]={k[1],table.concat(names,", ")}end
 end
 return out
end
local function did(view,cv,x,y,w,h,build,snap,you)
 local report=snap.talent_report;local tree,picked=build[1].tree,build[1].picked
 local total=type(report)=="table"and type(report.total)=="number"and report.total
 view:_card(cv,x,y,w,h,you and "What Your Talents Did"or "What Their Talents Did",total and "Damage share is of "..(you and "your "or "their ")..Overview.commas(total).." damage"or nil)
 local rows=report_rows(report)
 local cx,cr=x+36,x+w-36
 if #rows==0 then
  cv:text("Not recorded for this match.",cx,y+46,w-72,24,14,C.muted,"left",F.medium)
  -- the picks under it, a kind to a row, its names running on under one another
  -- each kind but the last leaves room under it for the line saying more did not fit
  local ry,lw=y+80,140;local list=picks(build,snap)
  for i,p in ipairs(list)do
   local rows_of=Tip.rows(view,p[2],14,cr-cx-lw,F.medium)
   if ry+20*#rows_of+(i<#list and 28 or 0)>y+h-12 then cv:text("More picks than this card holds.",cx,ry,w-72,20,13,C.muted,"left",F.medium);break end
   cv:text(p[1],cx,ry,lw-8,20,13,C.gold)
   for i,l in ipairs(rows_of)do cv:text(l,cx+lw,ry+(i-1)*20,cr-cx-lw+40,20,14,C.value,"left",F.medium)end
   ry=ry+20*#rows_of+8
  end
  return
 end
 local c2=x+286
 local hy=y+46;cv:text("Talent",cx,hy,200,24,13,C.muted);cv:text("In This Match",c2,hy,300,24,13,C.muted);cv:text("Share Or Count",cr-200,hy,200,24,13,C.muted,"right")
 cv:rect(x+25,hy+23,w-50,1,C.frame,true)
 local ry,listed,left=hy+24,{},0
 for i,r in ipairs(rows)do
  -- rows past the card's foot are counted there rather than dropped unsaid
  if ry+(r.head and 45 or 21)>y+h-32 then for j=i,#rows do if not rows[j].head then left=left+1 end end;break end
  if r.head then cv:text(r.head,cx,ry+4,300,20,14,C.gold);cv:rect(x+25,ry+23,w-50,1,C.frame,true);ry=ry+24
  else local n=tree and tree.by_name[r.node];listed[r.node]=true
   local name=n and Tree.name(tree,n)or "Unknown Talent"
   view:_hit("base",x+25,ry,w-50,21,nil,{bg=C.row_h},nil,nil,"io_tn:"..r.node)
   cv:text(view:_fit(name,14,240),cx,ry,244,21,14,C.value)
   cv:text(view:_fit(tostring(r.detail or ""),14,cr-c2-240,F.medium),c2,ry,cr-c2-236,21,14,C.label,"left",F.medium)
   if type(r.share)=="number"then local s=string.format("%.1f%%",r.share);local sw=56
    cv:text(s,cr-sw,ry,sw,21,14,C.value,"right");cv:rect(cr-sw-8-math.max(2,r.share*4),ry+7,math.max(2,r.share*4),8,C.gold,true)
   else cv:text(tostring(r.figure or ""),cr-200,ry,200,21,14,C.value,"right")end
   cv:rect(x+25,ry+20,w-50,1,C.line,true);ry=ry+21
  end
 end
 -- the picks with nothing to count, named at the foot
 for _,r in ipairs(rows)do if r.node then listed[r.node]=true end end
 local quiet={}
 for _,n in ipairs(tree and tree.nodes or {})do if picked[n.name]and not listed[n.name]and n.type~="start"and n.type~="stat"then quiet[#quiet+1]=Tree.name(tree,n)end end
 local foot=left>0 and left..(left==1 and " more row"or " more rows").." past the foot of this card."or nil
 if #quiet>0 then foot=(foot and foot.." "or "").."Nothing to measure: "..table.concat(quiet,", ",1,math.min(4,#quiet))..(#quiet>4 and " and "..(#quiet-4).." more."or ".")end
 if foot then cv:text(view:_fit(foot,13,w-72,F.medium),cx,y+h-30,w-72,20,13,C.muted,"left",F.medium)end
end
-- the tree's card: a Hive Scum's switches between Talents and Stimm Lab; a build saved before talents were kept lights what its saved names match,
-- and one with no class, or whose names match nothing, keeps the old list of its blitz, aura and keystone
local Copy=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/build_copy")
-- the game's own popup with one button, for what Copy Build did or why it could not
local function say(title,text)local e=Managers and Managers.event;if e then e:trigger("event_show_ui_popup",{title_text_unlocalized=title,description_text_unlocalized=text,options={{text="OK",no_localization=true,close_on_pressed=true,hotkey="back"}}})elseif mod.echo then mod:echo("%s",text)end end
local function copy_build(snap)
 local ok,done,n,total,_,left=pcall(Copy.copy,snap)
 if not ok then say("Copy Build","The build could not be copied.");mod:error("I/O Copy Build: %s",tostring(done));return end
 if not done then say("Copy Build",n);return end
 -- a new preset always goes at the end, so the popup names no number; what was left out says why: not enough points yet, or no longer on the tree
 left=left or {};local lines={n<total and "Saved as a new loadout preset, with "..n.." of "..total.." talents."or "Saved as a new loadout preset."}
 if (left.points or 0)>0 then lines[#lines+1]="Your character doesn't have enough points for the rest yet."end
 if (left.unlinked or 0)>0 then lines[#lines+1]=left.unlinked==1 and "1 isn't in the talent tree any more."or left.unlinked.." aren't in the talent tree any more."end
 lines[#lines+1]="Pick it in your inventory to use it."
 say("Build Copied",table.concat(lines,"\n"))
end
local function tree_card(view,cv,x,y,w,h,build,snap,report,st,you)
 view:_card(cv,x,y,w,h,"Talent Tree")
 local main=build[1]
 -- Copy Build, for a build saved with its talents: a new loadout preset on the character played, as much of it as that character can have
 if main.tree and not main.legacy then local bw=view:_w("Copy Build",13)+22;local bx=x+w-24-bw
  cv.z=6;cv:rect(bx,y+16,bw,24,C.fill);cv:edges(bx,y+16,bw,24,1,C.frame);cv:text("Copy Build",bx,y+16,bw,24,13,C.value,"center")
  view:_hit("base",bx,y+16,bw,24,function()copy_build(snap)end,{bg=C.fill_h,edge=C.hover},nil,nil,"io_copy_build")
 end
 if main.tree and not (main.legacy and main.found==0)then
  local b,top=main,y+64
  if build[2]then
   b=st.tree=="stimm"and build[2]or main;top=y+92
   local bx=x+36
   for _,opt in ipairs({{"main","Talents"},{"stimm","Stimm Lab"}})do local on=(st.tree or "main")==opt[1];local bw=view:_w(opt[2],13)+18
    cv.z=6;cv:rect(bx,y+62,bw,22,on and C.fill_s or C.fill);cv:edges(bx,y+62,bw,22,1,on and C.sel or C.frame)
    cv:text(opt[2],bx,y+62,bw,22,13,on and C.gold_hi or C.value,"center")
    if not on then view:_hit("base",bx,y+62,bw,22,function()st.tree=opt[1];return true end,{bg=C.fill_h,edge=C.hover})end
    bx=bx+bw+6
   end
  end
  local sub=b.legacy and main.tree.class.." · Main Picks Only"or (b==main and main.tree.class or "Stimm Lab").." · "..b.points.." Points"
  cv:text(sub,x+36,y+38,w-60,20,14,C.muted,"left",F.medium)
  local by={};for _,r in ipairs(report_rows(report))do if r.node then by[r.node]=r end end
  local hl=type(view.io_hkey)=="string"and view.io_hkey:match("^io_tn:(.+)$")
  Tree.draw(view,cv,b.tree,b.picked,x+12,top,w-24,y+h-12-top,{hl=hl,extra=function(n)local r=by[n.name];if not r then return end
   return (type(r.share)=="number"and string.format("%.1f%% of "..(you and "your"or "their").." damage. ",r.share)or tostring(r.figure or "")..". ")..tostring(r.detail or "").."."end})
  return
 end
 local ry=y+46
 for _,f in ipairs({{"aura","Aura"},{"blitz","Blitz"},{"keystone","Keystone"}})do if snap[f[1]]then
  cv:text(f[2],x+36,ry,w-60,20,13,C.muted,"left",F.medium);line(view,cv,snap[f[1]],x+36,ry+20,w-72,24,16,C.value);ry=ry+52 end end
 if ry==y+46 then cv:text("No talents were saved for this operative.",x+36,ry,w-60,24,14,C.muted,"left",F.medium)end
end
return function(view,cv,popup,run,tracker,st)
 local snap,hint,current=operatives(view,cv,popup,run,tracker,st)
 view:_sheet(cv,D.sheet)
 if not snap then view:_card(cv,D.left,D.sheet,D.width,92,"Build Unavailable");cv:text("No build data was saved for this operative.",D.left+36,D.sheet+46,D.width-72,24,14,C.muted,"left",F.medium);return view:_sheet_end(cv)end
 -- what the page keeps for each operative: the curio shown, the one held and the tree picked
 st.cs=st.cs or {};local cs=st.cs[current.value]or {};st.cs[current.value]=cs
 local L,y=D.left,D.sheet;local tw=(D.width-2*GAP)/3
 weapon(view,cv,L,y,tw,TOP_H,"Melee",snap,"melee")
 weapon(view,cv,L+tw+GAP,y,tw,TOP_H,"Ranged",snap,"ranged")
 curios(view,cv,L+2*(tw+GAP),y,tw,TOP_H,snap,cs)
 -- the talents and, for a Hive Scum, the Stimm Lab, each with its picks; a build saved before talents were kept has no Stimm Lab picks to show
 local cls=Tree.class_of(snap,hint);local build={}
 for i,which in ipairs({"main","stimm"})do local tree=(i==1 or not build[1].legacy)and Tree.load(cls,which)
  if tree or i==1 then local b={tree=tree,picked={},points=0}
   if tree then local found;b.picked,b.points,found=Tree.picked(tree,snap);if found then b.legacy,b.found=true,found end end
   build[#build+1]=b
  end
 end
 build.legacy=build[1].legacy
 local report=snap.talent_report;local y2=y+TOP_H+GAP;local h2=D.bottom-11-y2
 tree_card(view,cv,L,y2,TREE_W,h2,build,snap,report,cs,current.you)
 did(view,cv,L+TREE_W+GAP,y2,D.width-TREE_W-GAP,h2,build,snap,current.you)
 view:_sheet_end(cv)
end
