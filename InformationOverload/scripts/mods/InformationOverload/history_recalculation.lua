-- Compact mission contributions + a frozen legacy baseline. No per-hit event log.
local H={}
local function clone(v)if type(v)~="table"then return v end;local mt=getmetatable(v);if mt and mt.io_materialize then v=mt.io_materialize(v)end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
H.clone=clone
local function replay_mission(run,R)
 local out={}
 for k,v in pairs(run)do
  if k~="measurements"and k~="damage"and k~="contributions"and k~="enemy_kill_counts"and k~="completion_markers"and k~="completion_time"and k~="party_records"and k~="team_damage"and k~="performance"and k~="damage_diagnostics"and k~="compact_damage_test"and k~="talent_test"then out[k]=clone(v)end
 end
 -- File-backed detail fields are deliberately absent from pairs(). Only the damage total the summary
 -- holds is replayed, so no match file is read; teammate views and retired tests are not replayed.
 out.damage={total={all={total=R.run_damage_total(run)}}}
 return out
end
function H.kind(run)
 if run.run_kind then return run.run_kind end
 if run.interrupted then return "early_leave"end;if run.resumed then return "rejoined"end
 if run.full==false then return run.context and run.context.mode=="havoc"and "partial_unknown"or "late_join"end;return "full"
end
function H.enabled(run,policy)local kind=H.kind(run);return kind=="full"or (policy or {})[kind]~=false end
-- A saved match keeps each context its record entries name once, in a list beside them, with the parts every one of those contexts
-- shares kept once more as shared; an entry is {context number, name, value}, and an armour entry {context number, armour, name, value}.
local function context_key(c)local keys={};for k in pairs(c)do keys[#keys+1]=k end;table.sort(keys);local out={}
 for i,k in ipairs(keys)do local v=c[k];out[i]=k.."="..type(v)..":"..tostring(v)end;return table.concat(out,"|")end
function H.pack(c)
 if type(c)~="table"or c.version==2 or (type(c.best)~="table"and type(c.armour)~="table")then return c end
 local contexts,ids,out={},{},{version=2,shared={},contexts={},best={},armour={}}
 for _,field in ipairs({"best","armour"})do for _,e in ipairs(c[field]or {})do
  -- an entry with anything beyond its context, name, value and armour is kept as it was
  for k in pairs(e)do if k~="context"and k~="name"and k~="value"and k~="armour"then return c end end
  if type(e.context)~="table"or e.name==nil or e.value==nil or field=="armour"and e.armour==nil then return c end
 end end
 local function id(ctx)local key=context_key(ctx);local n=ids[key];if not n then contexts[#contexts+1]=ctx;n=#contexts;ids[key]=n end;return n end
 for _,e in ipairs(c.best or {})do out.best[#out.best+1]={id(e.context),e.name,e.value}end
 for _,e in ipairs(c.armour or {})do out.armour[#out.armour+1]={id(e.context),e.armour,e.name,e.value}end
 if contexts[1]then for k,v in pairs(contexts[1])do local all=true;for _,ctx in ipairs(contexts)do if ctx[k]~=v then all=false;break end end;if all then out.shared[k]=v end end end
 for i,ctx in ipairs(contexts)do local own={};for k,v in pairs(ctx)do if out.shared[k]==nil then own[k]=v end end;out.contexts[i]=own end
 for k,v in pairs(c)do if out[k]==nil then out[k]=v end end
 return out
end
-- a match's best or armour entries as {context, name, value, armour}, from either shape; each has a context of its own, or, for a
-- reader that only looks, entries naming one context share one table
function H.entries(c,field,look)
 if type(c)~="table"then return {}end
 if c.version~=2 then return c[field]or {}end
 local shared,contexts,out,made=c.shared or {},c.contexts or {},{},{}
 local function context(n)if look and made[n]then return made[n]end
  local t={};for k,v in pairs(shared)do t[k]=v end;for k,v in pairs(contexts[n]or {})do t[k]=v end;made[n]=t;return t end
 for _,e in ipairs(c[field]or {})do
  if field=="armour"then out[#out+1]={context=context(e[1]),armour=e[2],name=e[3],value=e[4]}
  else out[#out+1]={context=context(e[1]),name=e[2],value=e[3]}end
 end
 return out
end
local function context(c)local out={};for _,k in ipairs({"mode","patch","difficulty","class","character","character_name","category","weapon","explosive","enemy","grenade","blo_variant","blo_talent_selected","blo_chance"})do out[k]=c[k]end;return out end
local function deltas(before,after,path,out)
 for k,v in pairs(after or {})do local nextpath=clone(path);nextpath[#nextpath+1]=k
  if k~="schema"and k~="run_sequence"and k~="best"and k~="best_weapons"and k~="context"and k~="run_history"then
   if type(v)=="table"then deltas(type(before)=="table"and before[k]or nil,v,nextpath,out)
   elseif type(v)=="number"then local old=type(before)=="table"and before[k]or 0;if type(old)~="number"then old=0 end;if v>old then out[#out+1]={path=nextpath,amount=v-old}end end
  end
 end
end
function H.capture(tracker,m)
 tracker:finalize_distinct_incidents(m)
 tracker:finish_blo(true);tracker:finish_selected_blo(true);for _,child in pairs(tracker.blo_weapon_trackers or {})do child:finish_blo(true);child:finish_selected_blo(true)end
 local result={version=1,best={},armour={},blo_contexts={},increments={},kill_segments=clone(m.replay_kill_segments)}
 for _,entry in pairs(m.replay_best or {})do result.best[#result.best+1]={context=context(entry.context),name=entry.name,value=entry.value}end
 for _,entry in pairs(m.replay_armour or {})do result.armour[#result.armour+1]={context=context(entry.context),armour=entry.armour,name=entry.name,value=entry.value}end
 for id,c in pairs(m.replay_blo_contexts or {})do result.blo_contexts[#result.blo_contexts+1]={context=context(c),best=m.replay_blo_best and m.replay_blo_best[id]or 0}end
 local before_global=m.data_before and m.data_before.blo_global;local before_weapons=clone(m.data_before and m.data_before.blo_weapons or {});local factory=getmetatable(tracker)
 if factory and factory.new and #result.blo_contexts>0 then
  local normalized=factory.new({schema=1,rows=clone(m.data_before and m.data_before.rows or {}),blo_global=clone(before_global)})
  for _,entry in ipairs(result.blo_contexts)do local c=entry.context;normalized:blo_buckets(c);local patch=tostring(c.patch);before_weapons[patch]=before_weapons[patch]or {};local child=factory.new(clone(before_weapons[patch][c.weapon]));child.blo_weapon_only=true;child:blo_buckets(c);for _,variants in pairs(child.data.blo_global or {})do for _,bucket in pairs(variants)do child:initialize_blo_prefix(bucket)end end;before_weapons[patch][c.weapon]=child.data end
  for _,variants in pairs(normalized.data.blo_global or {})do for _,bucket in pairs(variants)do normalized:initialize_blo_prefix(bucket)end end;before_global=normalized.data.blo_global
 end
 deltas(before_global,tracker.data.blo_global,{"blo_global"},result.increments);deltas(before_weapons,tracker.data.blo_weapons,{"blo_weapons"},result.increments)
 for id,row in pairs(tracker.data.rows or {})do local old=m.data_before and m.data_before.rows and m.data_before.rows[id];local n=(row.boss_attacks or 0)-(old and old.boss_attacks or 0);if n>0 then result.increments[#result.increments+1]={path={"rows",id,"boss_attacks"},amount=n,context=context(row.context),aggregate=row.aggregate}end end
 return result
end
-- What a discarded run keeps: its BLO, taken when it ends, before any later run adds to the same buckets.
function H.discard_contribution(tracker,m)
 if not m.context or m.context.difficulty=="psykhanium"and not m.blo_trial or m.context.training_history_test then return end
 local full=H.capture(tracker,m);local contribution={version=1,best={},armour={},blo_contexts=full.blo_contexts,increments={}}
 for _,entry in ipairs(full.best)do if entry.name=="blo"then contribution.best[#contribution.best+1]=entry end end
 if m.blo_trial then for _,entry in ipairs(full.blo_contexts)do if entry.context.blo_variant~="melee"then contribution.best[#contribution.best+1]={context=entry.context,name="blo",value=entry.best}end end end
 for _,entry in ipairs(full.increments)do if entry.path[1]=="blo_global"or entry.path[1]=="blo_weapons"then contribution.increments[#contribution.increments+1]=entry end end
 return contribution
end
function H.discarded(tracker,m)
 if m.hidden_source_recorded or not m.context or m.context.difficulty=="psykhanium"and not m.blo_trial or m.context.training_history_test then return end
 local contribution=H.discard_contribution(tracker,m)
 if not contribution or #contribution.increments==0 and not next(m.boss_kills or {})then return end
 m.hidden_source_recorded=true;tracker.data.run_sequence=(tracker.data.run_sequence or 0)+1;tracker.data.run_history=tracker.data.run_history or {}
 local run={id=tracker.data.run_sequence,started_at=m.started_at,context=context(m.context),full=m.full,data_only=true,discarded=true,hidden_contributions=true,interrupted=m.interrupted,resumed=m.resumed,contributions=contribution,boss_kills=clone(m.boss_kills)};run.run_kind=H.kind(run);if tracker.trim_saved then tracker.trim_saved(run)end;tracker.data.run_history[#tracker.data.run_history+1]=run
end
local derived={"running_tallies","boss_tallies","class_boss_tallies","class_events","class_overview","mode_streaks","class_mode_streaks","class_win_streaks","maelstrom_streaks"}
-- A recount from the matches alone keeps the part of the baseline for patches with no saved match, which nothing else holds, and the Tracked Players the reset left, by which Restore knows who was untracked since.
local legacy_maps={"blo_global","blo_weapons"};for _,name in ipairs(derived)do legacy_maps[#legacy_maps+1]=name end
function H.legacy(R,legacy)
 legacy=legacy or {};local keep=legacy.history_legacy_patches or {};local out={schema=R.schema or 1,rows={},run_sequence=0,history_legacy_patches={},history_damage_reset_after=legacy.history_damage_reset_after,friend_tracking=clone(legacy.friend_tracking)}
 for patch in pairs(keep)do out.history_legacy_patches[patch]=true end
 for k,row in pairs(legacy.rows or {})do if row.context and keep[row.context.patch]then out.rows[k]=clone(row)end end
 for _,name in ipairs(legacy_maps)do for patch,v in pairs(legacy[name]or {})do if keep[patch]then out[name]=out[name]or {};out[name][patch]=clone(v)end end end
 return out
end
function H.baseline(data)local out={};for k,v in pairs(data)do if k~="run_history"then out[k]=clone(v)end end;out.run_history={};out.history_legacy_patches={};local known={};for _,run in ipairs(data.run_history or {})do if run.context then known[run.context.patch]=true end end;for _,row in pairs(data.rows or {})do if not known[row.context.patch]then out.history_legacy_patches[row.context.patch]=true end end;out.run_sequence=data.run_sequence or 0;out.self_leave_pending=nil;return out end
local function add(t,path,n)local target=t;for i=1,#path-1 do local k=path[i];target[k]=target[k]or {};target=target[k]end;local k=path[#path];target[k]=(target[k]or 0)+n end
local function boss_tallies(r,run)
 local c=run.context;r.data.boss_tallies=r.data.boss_tallies or {};local g=r.data.boss_tallies;g[c.patch]=g[c.patch]or {};g[c.patch][c.mode]=g[c.patch][c.mode]or {};local class=r:class_bosses(c.patch,c.mode,c.class)
 for id,e in pairs(run.boss_kills or {})do for _,group in ipairs({g[c.patch][c.mode],class})do local target=group[id]or {label=e.label};group[id]=target;for _,k in ipairs({"count","personal","weakened","personal_weakened"})do target[k]=(target[k]or 0)+(e[k]or 0)end end end
end
function H.rebuild(R,baseline,data,policy,read_only,pause)
 local runs=data.run_history or {};local base=clone(baseline);base.run_history={};base.run_sequence=data.run_sequence
 local damage_reset=data.history_damage_reset_after;local damage_metrics={damage=true,single_hit=true,melee_cleave=true,explosive_hit=true}
 -- a baseline taken after the damage reset carries it, and already holds only the bests set since
 local before_reset=damage_reset and baseline.history_damage_reset_after~=damage_reset
 local byid={};for _,run in ipairs(runs)do byid[run.id]=run end
 -- who each saved teammate record names, so a tie in a match saved before counts were numbered keeps its operative
 local credits=data.record_credits or R.record_credits and R.record_credits(data.rows)or {}
 for _,name in ipairs(derived)do local previous=base[name];base[name]={};for patch in pairs(base.history_legacy_patches or {})do if previous and previous[patch]then base[name][patch]=previous[patch]end end end
 for patch,modes in pairs(baseline.mode_streaks or {})do for mode,record in pairs(modes)do if record.best and record.best.kill_run then base.mode_streaks[patch]=base.mode_streaks[patch]or {};base.mode_streaks[patch][mode]=base.mode_streaks[patch][mode]or {current={},best={}};local target=base.mode_streaks[patch][mode];target.current.kill_run=record.current and record.current.kill_run or 0;target.best.kill_run=record.best.kill_run end end end
 for patch,modes in pairs(baseline.class_mode_streaks or {})do for mode,classes in pairs(modes)do for class,record in pairs(classes)do if record.best and record.best.kill_run then base.class_mode_streaks[patch]=base.class_mode_streaks[patch]or {};base.class_mode_streaks[patch][mode]=base.class_mode_streaks[patch][mode]or {};base.class_mode_streaks[patch][mode][class]=base.class_mode_streaks[patch][mode][class]or {current={},best={}};local target=base.class_mode_streaks[patch][mode][class];target.current.kill_run=record.current and record.current.kill_run or 0;target.best.kill_run=record.best.kill_run end end end end
 local known_bosses,known_class_bosses={},{}
 for _,run in ipairs(runs)do if (run.id or 0)<=(baseline.run_sequence or 0)then local c=run.context;known_bosses[c.patch]=known_bosses[c.patch]or {};known_bosses[c.patch][c.mode]=known_bosses[c.patch][c.mode]or {};known_class_bosses[c.patch]=known_class_bosses[c.patch]or {};known_class_bosses[c.patch][c.mode]=known_class_bosses[c.patch][c.mode]or {};known_class_bosses[c.patch][c.mode][c.class]=known_class_bosses[c.patch][c.mode][c.class]or {}
  for id,e in pairs(run.boss_kills or {})do for _,group in ipairs({known_bosses[c.patch][c.mode],known_class_bosses[c.patch][c.mode][c.class]})do group[id]=group[id]or {};for _,field in ipairs({"count","personal","weakened","personal_weakened"})do group[id][field]=(group[id][field]or 0)+(e[field]or 0)end end end
 end end
 local function legacy_bosses(old,known)
  local out={};for k,v in pairs(old or {})do if type(v)=="table"and v.count~=nil then local row={label=v.label};local any=false;for _,field in ipairs({"count","personal","weakened","personal_weakened"})do row[field]=math.max(0,(v[field]or 0)-(known and known[k]and known[k][field]or 0));any=any or row[field]>0 end;if any then out[k]=row end elseif type(v)=="table"then local child=legacy_bosses(v,known and known[k]);if next(child)then out[k]=child end end end;return out
 end
 base.boss_tallies=legacy_bosses(baseline.boss_tallies,known_bosses);base.class_boss_tallies=legacy_bosses(baseline.class_boss_tallies,known_class_bosses)
 base.class_overview_initialized=true;base.ally_overview_initialized=true;base.class_mode_streaks_initialized=true;base.maelstrom_streaks_initialized=true;base.class_bosses_initialized=true;base.boss_records_0470=true
 for _,row in pairs(base.rows or {})do row.win_current=0;row.loss_current=0;row.psyker_safe_current=0;row.undowned_current=0;row.unpounced_current=0;row.unnetted_current=0;row.uncharged_current=0;row.death_free_current=0
  if before_reset then for metric in pairs(damage_metrics)do row.best[metric]=nil;if row.best_weapons then row.best_weapons[metric]=nil end;if row.best_runs then row.best_runs[metric]=nil end end;for _,bucket in pairs(row.armour_best or {})do for metric in pairs(damage_metrics)do bucket.best[metric]=nil;if bucket.sources then bucket.sources[metric]=nil end end end end
  if damage_reset then for enemy,hit in pairs(row.enemy_hits or {})do if type(hit)~="table"or (hit.run_id or 0)<=damage_reset then row.enemy_hits[enemy]=nil end end end
  if not (base.history_legacy_patches or {})[row.context.patch]then for name in pairs(row.best or {})do local source=row.best_runs and byid[row.best_runs[name]]
   local mission_record=name:find("personal_",1,true)==1 or name:find("team_",1,true)==1 or name:find("teammate_",1,true)==1 or name=="win_streak"or name=="loss_streak"or name=="psyker_safe_missions"or name=="players_left_mission"or name=="mutant_charges_mission"
   if mission_record or source and not H.enabled(source,policy)then row.best[name]=nil;if row.best_weapons then row.best_weapons[name]=nil end;if row.best_runs then row.best_runs[name]=nil end end
  end end
 end
 local r=R.new(base);r.save_run=function()end
 local carries=data.history_patch_carries or {};local applied={};local function apply_carries(at)for i,e in ipairs(carries)do if not applied[i]and (e.after_run or 0)<=at then if R.patch_carry then R.patch_carry(r.data,e.old,e.new,e.policy)end;applied[i]=true end end end
 apply_carries(0)
 -- Exclusion flags land together at the end, so pages read between pauses never see half a replay.
 local flags={}
 for _,run in ipairs(runs)do if pause then pause()end;apply_carries((run.id or 1)-1);local excluded=not H.enabled(run,policy);if not read_only then flags[run]=excluded end;local c=run.context
  if not excluded and c and not c.training_history_test and (c.difficulty~="psykhanium"or run.hidden_contributions)and c.difficulty~="TEST ONLY"then
   local m=replay_mission(run,R);m.failed=m.failed or {};m.legacy_controls=not c.combat_tracking_v56;local own=run.incidents and run.incidents.personal or {};for field,event in pairs({downs="knocked_down",deaths="died",pounces="dog_pounced",nets="trapper_netted",mutant_charges="mutant_charged"})do if (own[field]or 0)>0 then m.failed[event]=true end end;m.full=true;m.id=nil;m.data_before=nil;m.recalculating=true;m.record_updates={};m.enemy_updates={};m.history_recorded=nil;m.interrupted=false;m.record_credits=credits[run.id]
   r.mission=m
   local contribution=run.contributions
   if contribution and run.id>(baseline.run_sequence or 0)then
    for _,entry in ipairs(contribution.blo_contexts or {})do local bc=entry.context;r:rows_for(bc);r:initialize_blo_prefix(r:blo_buckets(bc));r.data.blo_weapons=r.data.blo_weapons or {};local patch=tostring(bc.patch);r.data.blo_weapons[patch]=r.data.blo_weapons[patch]or {};local child=R.new(r.data.blo_weapons[patch][bc.weapon]);child.blo_weapon_only=true;child:rows_for(bc);child:initialize_blo_prefix(child:blo_buckets(bc));r.data.blo_weapons[patch][bc.weapon]=child.data end
    for _,entry in ipairs(contribution.increments or {})do if entry.context then r:rows_for(entry.context)end;add(r.data,entry.path,entry.amount)end
    for _,entry in ipairs(contribution.blo_contexts or {})do local bc=entry.context;local bucket=r:blo_buckets(bc);bucket.best=math.max(bucket.best or 0,entry.best);local child=R.new(r.data.blo_weapons[tostring(bc.patch)][bc.weapon]);child.blo_weapon_only=true;if bc.blo_variant~="melee"then child:best(bc,"blo",entry.best)end;local cb=child:blo_buckets(bc);cb.best=math.max(cb.best or 0,entry.best);r.data.blo_weapons[tostring(bc.patch)][bc.weapon]=child.data end
    for _,entry in ipairs(H.entries(contribution,"best"))do if not (damage_reset and run.id<=damage_reset and damage_metrics[entry.name])then r:best(entry.context,entry.name,entry.value)end end
    for _,entry in ipairs(H.entries(contribution,"armour"))do if not (damage_reset and run.id<=damage_reset)then for _,row in ipairs(r:rows_for(entry.context))do row.armour_best=row.armour_best or {};local bucket=row.armour_best[entry.armour]or {best={},sources={}};row.armour_best[entry.armour]=bucket;if entry.value>(bucket.best[entry.name]or 0)then bucket.best[entry.name]=entry.value;bucket.sources[entry.name]=clone(entry.context)end end end end
    for i,segment in ipairs(contribution.kill_segments or {})do if i>1 then r:reset_kill_run(c)end;local kr=r:kill_run(c);for k,n in pairs(segment)do kr.current[k]=(kr.current[k]or 0)+n;kr.best[k]=math.max(kr.best[k]or 0,kr.current[k])end;for _,record in ipairs({r:mode_streak(c.patch,c.mode),r:class_mode_streak(c.patch,c.mode,c.class)})do record.current.kill_run=(record.current.kill_run or 0)+(segment.total or 0);record.best.kill_run=math.max(record.best.kill_run or 0,record.current.kill_run)end end
   end
   boss_tallies(r,run)
   if not run.data_only and type(run.victory)=="boolean"then
    local stats=R.incident_counts and R.incident_counts(run)or run.incidents or {};for field,n in pairs(stats.personal or {})do if type(n)=="number"then r:incident_record(field=="mutant_charges"and "mutant_charges_mission"or "personal_"..field.."_mission",n)end end
    for field,n in pairs(stats.team or {})do if type(n)=="number"then r:incident_record("team_"..field.."_mission",n)end end
    local fields,who={},c.operative_identities;for _,p in pairs(stats.members or {})do for field,n in pairs(type(p)=="table"and p.counts or {})do if type(n)=="number"then fields[field]=true end end end
    for field in pairs(fields)do local name="teammate_"..field.."_mission"
     for _,id in ipairs(R.reach_order(stats.members,field,m.record_credits and m.record_credits[name],who))do local p=stats.members[id];local n=type(p.counts)=="table"and p.counts[field];if type(n)=="number"then r:incident_record(name,n,p.class,who and who[id])end end
    end
    r:finish_mission(true,run.victory,true);r:cache_class_run(run)
   else r.mission=nil end
   for _,update in ipairs(m.record_updates or {})do if update.row.best[update.name]==update.value then update.row.best_runs[update.name]=run.id end end
   for _,update in ipairs(m.enemy_updates or {})do local hit=update.row.enemy_hits and update.row.enemy_hits[update.enemy];if hit and hit.damage==update.value then hit.run_id=run.id end end
  end
 end
 -- left off rather than false
 for run,excluded in pairs(flags)do run.stats_excluded=excluded or nil end
 apply_carries(math.huge)
 for _,k in ipairs({"history_damage_reset_after","history_patch_carries","friend_tracking","friend_tracking_revision","history_policy_revision","self_leave_pending","character_names"})do r.data[k]=clone(data[k])end
 r.data.run_history=runs;r.data.run_sequence=data.run_sequence;r.data.history_rebuild_version=1;r.data.control_tracking_v55=true;return r.data
end
return H
