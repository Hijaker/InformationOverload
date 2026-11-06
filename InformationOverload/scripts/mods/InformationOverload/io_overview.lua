-- Overview figures for Information Overload, read from the mod's own records.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local Records=mod:io_dofile(base.."records")
local Nav=mod:io_dofile(base.."dashboard_navigation")
local H=mod:io_dofile(base.."history_presentation")
local Times=mod:io_dofile(base.."mission_times")
local Patch=mod:io_dofile(base.."game_patch")
local Faction=mod:io_dofile(base.."havoc_faction")
local O={}
local DASH="—"
O.dash=DASH
O.class_names={veteran="Veteran",zealot="Zealot",psyker="Psyker",ogryn="Ogryn",adamant="Arbitrator",broker="Hive Scum",cryptic="Skitarius"}
O.mode_names={havoc="Havoc",["non-havoc"]="Non-Havoc"}
local function commas(n)local s=string.format("%.0f",n);local r=s:reverse():gsub("(%d%d%d)","%1,"):reverse();return (r:gsub("^,",""))end
O.commas=commas
local function full()local o=mod.io_display_options and mod.io_display_options();return o and o.numbers=="separators"end
-- a figure as Number Format asks, 12.3K and 1.2M or every digit; short keeps K and M where the exact figure sits beside it
function O.compact(n,short)if type(n)~="number"then return DASH end;if n<9999.5 or not short and full()then return commas(math.floor(n+.5))elseif n<999950 then return string.format("%.1fK",n/1e3)end;return string.format("%.1fM",n/1e6)end
local function pct(w,g)if not g or g<=0 then return DASH end;return (string.format("%.1f",100*w/g):gsub("%.0$","")).."%"end
-- left_out also takes a match a Counting switch leaves out
local function accepted(run,left_out)
 local c=run.context
 return c and not run.discarded and not run.hidden_contributions and (left_out or not run.stats_excluded)and not run.data_only and not c.training_history_test and c.difficulty~="psykhanium"and c.difficulty~="TEST ONLY"and type(run.victory)=="boolean"
end
O.accepted=accepted
function O.runs(tracker)
 local out={};for _,run in ipairs(tracker.data.run_history or {})do if accepted(run)then out[#out+1]=run end end
 table.sort(out,function(a,b)local x,y=tostring(a.started_at or ""),tostring(b.started_at or "");if x==y then return (a.id or 0)>(b.id or 0)end;return x>y end)
 return out
end
function O.diff_label(c)
 if c.mode=="havoc"then return tonumber(c.difficulty)and "Havoc "..tostring(c.difficulty)or "Havoc"end
 return H.difficulty_short(c)
end
local rank={Sedition=1,Uprising=2,Malice=3,Heresy=4,Damnation=5,Auric=6}
local function diff_rank(label)
 local n=label:match("^Havoc (%d+)$");if n then return -tonumber(n)end
 local word=label:match("^(%a+)");return (rank[word]or 9)*2+(label:find("Maelstrom",1,true)and 1 or 0)
end
local function damage(run)return (Records.run_mission_damage(run))end
local function basis()local options=mod.io_display_options and mod.io_display_options()or {};return options.boss_map_timing and "boss"or "victory"end
local function clear_time(run)
 local t=run.victory and Times.completion(run);if not t or type(t.seconds)~="number"then return nil end
 if t.source=="mission_clock"then
  local marks=run.completion_markers or {};local chosen=basis()=="boss"and marks.boss_death or marks.victory_request or marks.victory_transition
  return chosen and Times.marker(run,chosen)or nil
 end
 return t.seconds
end
local function streak(data,patch,mode,class)
 local groups=class and data.class_win_streaks or data.mode_streaks
 local row=groups and groups[patch or "Unknown patch"];row=row and row[mode];if class then row=row and row[class]end
 if not row then return nil,nil end
 if class then return row.current,row.best end
 return row.current and row.current.win,row.best and row.best.win
end
function O.defaults(tracker)
 local runs=O.runs(tracker);local patches=Nav.patches(tracker)
 -- pages start on the Preferred Mode while it has any missions, otherwise, or when it is Last Game, on the mode last played
 local mode=Nav.modes()[1];local has=mod:get("preferred_mode")~="last";if has then has=false;for _,run in ipairs(runs)do if run.context.mode==mode then has=true;break end end end
 return {mode=has and mode or runs[1]and runs[1].context.mode or mode,diff="all",patch=patches[#patches],all_patches=true}
end
function O.build(tracker,scope)
 local all=O.runs(tracker);local mode,patch=scope.mode,scope.patch
 local m={empty=#all==0,mode_counts={},patch_counts={},diffs={},patches=Nav.patches(tracker),current_patch=nil}
 m.current_patch=m.patches[#m.patches]
 if m.empty then local n=0;for _,run in ipairs(tracker.data.run_history or {})do if run.stats_excluded and accepted(run,true)then n=n+1 end end;m.left_out=n end
 local scoped,seen={},{}
 -- the dropdowns' counts, over every patch and over the patch picked
 for _,run in ipairs(all)do local c=run.context;local here=not patch or c.patch==patch;m.mode_counts[c.mode]=(m.mode_counts[c.mode]or 0)+1
  if here then m.patch_counts[c.mode]=(m.patch_counts[c.mode]or 0)+1 end
  if c.mode==mode then local key=O.diff_label(c)
   if not seen[key]then seen[key]={value=key,label=key,count=0,patch_count=0};m.diffs[#m.diffs+1]=seen[key]end;local d=seen[key];d.count=d.count+1;if here then d.patch_count=d.patch_count+1 end
   if here then scoped[#scoped+1]=run end
  end
 end
 table.sort(m.diffs,function(a,b)return diff_rank(a.label)<diff_rank(b.label)end)
 m.mode_total,m.patch_total=m.mode_counts[mode]or 0,m.patch_counts[mode]or 0;m.scoped=#scoped
 local lr=all[1]
 if lr then local c=lr.context;local faction=c.mode=="havoc"and Faction.label(c.havoc_faction)
  -- useful damage, as Most Damage In A Mission beside it has, and none for a match with no squad tally
  local dmg=Records.run_useful(lr);local t=clear_time(lr)
  m.last={id=lr.id,mode=c.mode,rows={{"Map",tracker:run_mission_name(c)},{"Result",(lr.victory and "Victory"or "Defeat")..(lr.full==false and " (Partial)"or "")},
   {"Difficulty",O.diff_label(c)..(faction and " · "..faction or "")},{"Class",O.class_names[c.class]or DASH},{"Your Damage",dmg and commas(dmg)or DASH},
   {"Clear Time",t and Times.format(t)or DASH},{"Date",lr.started_at and H.timestamp(lr.started_at)or DASH}}}
 else m.last={rows={{"Map",DASH},{"Result",DASH},{"Difficulty",DASH},{"Class",DASH},{"Your Damage",DASH},{"Clear Time",DASH},{"Date",DASH}}}end
 local overall=Nav.overall_missions(tracker,patch,mode);local sources=Nav.mission_sources(tracker,patch,mode,overall)
 local cur,best=streak(tracker.data,patch,mode)
 -- the best streak's mission is the one that reached it, and false when the history holds no streak that long
 local reached;if best and best>0 then reached=sources.win_value==best and sources.win or false end
 m.career={sub=(O.mode_names[mode]or DASH)..", Patch "..(patch and Patch.display(patch)or DASH),rows={{"Games",tostring(overall.games)},{"Wins",tostring(overall.wins)},
  {"Win Rate",pct(overall.wins,overall.games)},{"Current Win Streak",cur and tostring(cur)or DASH},{"Best Win Streak",best and tostring(best)or DASH,reached}}}
 local display=mod.io_display_options and mod.io_display_options()or {}
 m.classes={}
 for index,class in ipairs(Nav.classes)do local row=Nav.class_missions(tracker,patch,mode,class)
  if row.games>0 then local _,top=streak(tracker.data,patch,mode,class)
   m.classes[#m.classes+1]={id=class,order=index,name=O.class_names[class]or class,games=row.games,rate=pct(row.wins,row.games),best=top and top>0 and tostring(top)or DASH,favourite=display.favorite_class==class}
  end
 end
 table.sort(m.classes,function(a,b)if a.games~=b.games then return a.games>b.games end;return a.order<b.order end)
 local Model=mod.dashboard_model;local summary=Model and Model.summary(tracker,mode,patch and {patch=patch}or {})or {best={},record_runs={}}
 local single,single_run
 for _,row in pairs(tracker.data.rows or {})do local c=row.context
  if not row.aggregate and c.mode==mode and (not patch or c.patch==patch)and not tracker:is_class_grenade(c)then local n=row.best and row.best.single_hit
   if n and n>(single or 0)then single=n;single_run=row.best_runs and row.best_runs.single_hit end
  end
 end
 local function value(n)return n and n>0 and commas(n)or DASH end
 local runs=summary.record_runs
 m.bests={{"Biggest Single-Target Hit",value(single),single_run},{"Biggest Melee Cleave",value(summary.best.melee_cleave),runs.melee_cleave},
  {"Biggest Explosion",value(summary.best.explosive_hit),runs.explosive_hit},{"Most Kills In A Mission",value(overall.kills),overall.kills>0 and sources.kills or nil},
  {"Most Damage In A Mission",value(overall.damage),overall.damage>0 and sources.damage or nil}}
 local fastest;local timed={};for _,run in ipairs(tracker.data.run_history or {})do if not patch or (run.context or {}).patch==patch then timed[#timed+1]=run end end
 -- different maps are ranked by their seconds, as map lengths differ far more than the server's times and the mission clock's do
 for _,maps in pairs(Times.build(timed,mode,basis()))do for _,run in pairs(maps)do local s=run.completion_time.seconds
  if not fastest or s<fastest.seconds then fastest={seconds=s,run=run}end
 end end
 m.bests[#m.bests+1]=fastest and {"Fastest Clear ("..O.diff_label(fastest.run.context)..")",Times.format(fastest.seconds),fastest.run.id}or {"Fastest Clear",DASH}
 local recent={};for i=math.min(10,#scoped),1,-1 do local run=scoped[i];recent[#recent+1]={win=run.victory==true,damage=damage(run)}end
 local wins,sum,n=0,0,0;for _,r in ipairs(recent)do if r.win then wins=wins+1 end;if r.damage then sum=sum+r.damage;n=n+1 end end
 m.recent={bars=recent,wins=wins,average=n>0 and sum/n or nil,with=n}
 return m
end
return O
