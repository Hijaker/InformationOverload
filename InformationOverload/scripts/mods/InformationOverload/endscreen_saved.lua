-- Information Overload: a saved match's End Screen card, for the End Screen tab on its match page. Built as the end screen builds it, from the
-- match file, its averages and records set against only the matches before it, and with no portrait, which only the end screen itself holds.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local X={}
-- one card a match, kept while the match is, and made again when the history or the timing and overkill options change
local made=setmetatable({},{__mode="k"})
local function dofile(name)return mod:io_dofile(base..name)end
local Used,Card
-- the tracker as it stood when the match ended: its history up to and including the match, the rest of it as it is
local function before(tracker,run)
 local list={};for _,r in ipairs(tracker.data.run_history or {})do if type(r.id)=="number"and r.id<=run.id then list[#list+1]=r end end
 return setmetatable({data=setmetatable({run_history=list},{__index=tracker.data})},{__index=tracker})
end
function X.model(tracker,run)
 local o=mod.io_display_options and mod.io_display_options()or {};local basis=o.boss_map_timing and "boss"or "victory"
 local data=tracker.data or {}
 local key=table.concat({basis,tostring(o.includes_overkill==true),tostring(data.run_sequence),tostring(data.history_policy_revision),tostring(data.friend_tracking_revision),tostring(data),tostring(mod.io_times_revision)},"|")
 local hit=made[run];if hit and hit.key==key then return hit.M end
 if not Used then Used={Debrief=dofile("endscreen_debrief"),S=dofile("scoreboard"),Team=dofile("team_damage"),Times=dofile("mission_times"),Overview=dofile("io_overview"),Model=dofile("endscreen_card_model"),clean=dofile("display_name").clean}end
 local Debrief,S,Team,Times,Overview,Model=Used.Debrief,Used.S,Used.Team,Used.Times,Used.Overview,Used.Model
 local t=Times.completion(run)
 -- a mission-clock win timed on the basis Settings has, as the Overview's Clear Time is
 if run.victory and t and t.source=="mission_clock"then local marks=run.completion_markers or {};local chosen=basis=="boss"and Times.boss_death(run)or marks.victory_request or marks.victory_transition or marks.win_condition~=marks.boss_death and marks.win_condition
  if chosen then t={seconds=Times.marker(run,chosen),source="mission_clock"}else t=nil end end
 local secs=t and t.seconds;local backend=t~=nil and t.source=="backend"
 local past=type(run.id)=="number"and before(tracker,run)or tracker
 local D=Debrief.model(past,run,run,secs,basis)
 local team,party=Team.from_run(run),run.party_records
 local counts=type(tracker.incident_counts)=="function"and tracker.incident_counts(run)or {}
 local deps={Team=Team,Times=Times,clean=Used.clean,class_names=Overview.class_names,runs=Overview.runs,
  title=function(tr,c)return tr:run_mission_name(c).." · "..Overview.diff_label(c)end,parts=function(tr,c)return tr:run_mission_name(c),Overview.diff_label(c)end,
  incident_counts=function()return counts end}
 local sb=S.model({m=run,tracker=past,team=team,party=party,basis=basis,overkill=o.includes_overkill==true,cache={},final=true,exclude=run.id,backend=backend,saved=true},deps)
 local M=Model.model(past,{m=run},run,D,sb and sb.squad or {},team,party,secs,backend,counts)
 M.no_portrait=true
 made[run]={key=key,M=M};return M
end
-- the card laid out for the operative picked, Minute By Minute and the average it is set against as Settings has them; and its ground and edge without the end screen's bar words
function X.layout(M,sel,measure)
 Card=Card or dofile("endscreen_card")
 local E=Card
 local v=mod.get and mod:get("endscreen_mission_clock")
 local lay=E.layout(M,{sh=1080,clock=v~=false,sel=sel,measure=measure,squad=mod.get and mod:get("endscreen_squad_average")==true})
 local ground={};for _,op in ipairs(E.frame({sh=1080,measure=measure,link=false}).ops)do if op.t~="t"then ground[#ground+1]=op end end
 return lay,ground
end
return X
