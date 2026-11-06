local P={}
function P.display(value)
 return type(value)=="string" and value:match("^(%d+%.%d+)") or "Unknown patch"
end
function P.normalize(value)
    return type(value)=="string" and value:match("^(%d+%.%d+%.%d+)") or nil
end
-- Merge persistent rows, not just their labels. Historical maxima retain
-- the matching weapon/run provenance; counters are summed only when additive.
local function row_key(c,aggregate)
    local parts={c.mode,c.patch,c.difficulty,c.class,c.character}
    if not aggregate then parts[#parts+1]=c.category;parts[#parts+1]=c.explosive and "explosive" or "non-explosive";parts[#parts+1]=c.weapon end
    for i,v in ipairs(parts) do v=tostring(v);parts[i]=#v..":"..v end
    return table.concat(parts,"|")
end
local function add(a,b)
    for k,v in pairs(b or {}) do
        if type(v)=="table" then a[k]=a[k] or {};add(a[k],v)
        elseif type(v)=="number" then a[k]=k=="best" and math.max(a[k] or 0,v) or (a[k] or 0)+v
        elseif a[k]==nil then a[k]=v end
    end
end
local function maxima(a,b,sources_a,sources_b,runs_a,runs_b)
    for k,v in pairs(b or {}) do
        if v>(a[k] or -math.huge) then
            a[k]=v
            if sources_a then sources_a[k]=sources_b and sources_b[k] or nil end
            if runs_a then runs_a[k]=runs_b and runs_b[k] or nil end
        end
    end
end
local function merge_row(a,b,newer)
    a.best=a.best or {};a.best_weapons=a.best_weapons or {};a.best_runs=a.best_runs or {}
    maxima(a.best,b.best,a.best_weapons,b.best_weapons,a.best_runs,b.best_runs)
    for _,field in ipairs({"blo_histogram","blo_censored","combat_totals"}) do a[field]=a[field] or {};add(a[field],b[field]) end
    a.boss_attacks=(a.boss_attacks or 0)+(b.boss_attacks or 0)
    a.enemy_hits=a.enemy_hits or {}
    for enemy,hit in pairs(b.enemy_hits or {}) do if not a.enemy_hits[enemy] or hit.damage>a.enemy_hits[enemy].damage then a.enemy_hits[enemy]=hit end end
    a.armour_best=a.armour_best or {}
    for armor,bucket in pairs(b.armour_best or {}) do
        local target=a.armour_best[armor]
        if not target then a.armour_best[armor]=bucket
        else target.best=target.best or {};target.sources=target.sources or {};maxima(target.best,bucket.best,target.sources,bucket.sources) end
    end
    for k,v in pairs(b) do
        if type(k)=="string" and k:match("_current$") then
            if newer or a[k]==nil then a[k]=v end
        elseif a[k]==nil then a[k]=v end
    end
end
function P.normalize_saved(data)
    if type(data)~="table" then return false end
    local changed=false
    local origins={};for _,run in ipairs(data.run_history or {}) do origins[run]=run.context.patch end
    local function walk(t)
        if type(t)~="table" then return end
        if t.patch then local p=P.normalize(t.patch);if p and p~=t.patch then t.patch=p;changed=true end end
        for _,v in pairs(t) do if type(v)=="table" then walk(v) end end
    end
    walk(data)
    local groups={}
    for old_id,row in pairs(data.rows or {}) do
        local id=row_key(row.context,row.aggregate)
        local original=old_id:match("^[^|]*|%d+:([^|]*)|") or row.context.patch
        groups[id]=groups[id] or {};groups[id][#groups[id]+1]={row=row,original=original,old_id=old_id,win_current=row.win_current,loss_current=row.loss_current}
        if old_id~=id then changed=true end
    end
    local rows={}
    for id,entries in pairs(groups) do
        local c=entries[1].row.context
        local history={};local latest={}
        for _,run in ipairs(data.run_history or {}) do
            if row_key(run.context,true)==row_key(c,true) and not run.data_only and not run.context.training_history_test and type(run.victory)=="boolean" then
                history[#history+1]=run;latest[origins[run]]=run.id or #history
            end
        end
        table.sort(entries,function(a,b)
            local aa,bb=latest[a.original] or 0,latest[b.original] or 0
            if aa~=bb then return aa<bb end
            return a.original<b.original
        end)
        local merged=entries[1].row
        for i=2,#entries do merge_row(merged,entries[i].row,true);changed=true end
        if #entries>1 and merged.aggregate and #history>0 then
            -- Recover win/loss ordering across the split. Seed only a uniform
            -- oldest segment; retain older recorded maxima when history is short.
            local first=origins[history[1]];local seed
            for _,entry in ipairs(entries) do if entry.original==first then seed=entry;break end end
            local wins,losses,all_wins,all_losses=0,0,true,true
            for _,run in ipairs(history) do if origins[run]==first then
                if run.victory then wins=wins+1;all_losses=false else losses=losses+1;all_wins=false end
            end end
            local win=all_wins and math.max(0,(seed and seed.win_current or 0)-wins) or 0
            local loss=all_losses and math.max(0,(seed and seed.loss_current or 0)-losses) or 0
            for _,run in ipairs(history) do
                win=run.victory and win+1 or 0;loss=not run.victory and loss+1 or 0
                merged.best.win_streak=math.max(merged.best.win_streak or 0,win)
                merged.best.loss_streak=math.max(merged.best.loss_streak or 0,loss)
            end
            merged.win_current,merged.loss_current=win,loss
        end
        rows[id]=merged
    end
    if changed then data.rows=rows end
    local function maps(t)
        if type(t)~="table" then return end
        local keys={};for k in pairs(t) do keys[#keys+1]=k end
        for _,k in ipairs(keys) do local n=P.normalize(k);if n and n~=k then
            if t[n] then add(t[n],t[k]) else t[n]=t[k] end
            t[k]=nil;changed=true
        end end
    end
    maps(data.blo_global)
    if data.blo_weapons then
        local keys={};for k in pairs(data.blo_weapons) do keys[#keys+1]=k end
        for _,k in ipairs(keys) do
            local stores=data.blo_weapons[k]
            for _,child in pairs(stores) do if P.normalize_saved(child) then changed=true end end
            local n=P.normalize(k)
            if n and n~=k then
                local target=data.blo_weapons[n]
                if not target then data.blo_weapons[n]=stores
                else
                    for weapon,child in pairs(stores) do
                        if not target[weapon] then target[weapon]=child
                        else
                            local existing=target[weapon]
                            existing.blo_global=existing.blo_global or {};add(existing.blo_global,child.blo_global or {})
                            existing.rows=existing.rows or {}
                            for id,row in pairs(child.rows or {}) do
                                if existing.rows[id] then merge_row(existing.rows[id],row,true) else existing.rows[id]=row end
                            end
                        end
                    end
                end
                data.blo_weapons[k]=nil;changed=true
            end
        end
    end
    return changed
end
function P.carry(data,old,new,policy)
 local function clone(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
 local cats=policy.categories or {};local classes=policy.classes or {};local weapons=policy.weapons or {}
 local damage={damage=true,single_hit=true,melee_cleave=true,explosive_hit=true,total_damage_mission=true}
 local class_metrics={blo=true,pbb_ammo_mission=true,kills_mission=true}
 local function allowed(c) return not classes[c.class] and not weapons[c.weapon] end
 local copies={}
 for _,row in pairs(data.rows or {}) do if row.context.patch==old then
  local r=clone(row);r.context.patch=new;r.best={};r.best_weapons={};r.best_runs={};r.armour_best={};r.enemy_hits={};r.combat_totals={};r.blo_histogram={};r.blo_censored={}
  for id,value in pairs(row.best or {}) do
   local source=row.best_weapons and row.best_weapons[id] or row.context
   local category=damage[id] and "damage" or class_metrics[id] and "class" or (id:find("mission") or id:find("downs")) and "non_damage" or "streaks"
   if cats[category]~=false and allowed(source) then r.best[id]=value;r.best_weapons[id]=clone(source);r.best_weapons[id].patch=new;r.best_runs[id]=row.best_runs and row.best_runs[id] end
  end
  for id,value in pairs(row) do if type(id)=="string" and id:match("_current$") then r[id]=cats.streaks~=false and not classes[row.context.class] and value or 0 end end
  if cats.damage~=false then
   for armor,bucket in pairs(row.armour_best or {}) do local a={best={},sources={}};for id,value in pairs(bucket.best or {}) do local source=bucket.sources and bucket.sources[id] or row.context;if allowed(source) then a.best[id]=value;a.sources[id]=clone(source);a.sources[id].patch=new end end;r.armour_best[armor]=a end
   for enemy,hit in pairs(row.enemy_hits or {}) do if allowed(hit) then r.enemy_hits[enemy]=clone(hit) end end
  end
  if not classes[row.context.class] and (row.aggregate or not weapons[row.context.weapon]) then copies[row_key(r.context,r.aggregate)]=r end
 end end
 -- Rebuild aggregate damage maxima from retained weapon rows if the former winning weapon was sunset.
 for _,row in pairs(copies) do if not row.aggregate then local aggregate=copies[row_key(row.context,true)];if aggregate then
  for id,value in pairs(row.best) do if damage[id] and value>(aggregate.best[id] or -1) then aggregate.best[id]=value;aggregate.best_weapons[id]=clone(row.best_weapons[id] or row.context);aggregate.best_runs[id]=row.best_runs[id] end end
  for armor,bucket in pairs(row.armour_best or {}) do local target=aggregate.armour_best[armor] or {best={},sources={}};aggregate.armour_best[armor]=target;for id,value in pairs(bucket.best or {}) do if value>(target.best[id] or -1) then target.best[id]=value;target.sources[id]=clone(bucket.sources[id] or row.context) end end end
 end end end
 for id,row in pairs(copies) do if not data.rows[id] then data.rows[id]=row end end
 for _,pair in ipairs({{"mode_streaks","streaks"},{"running_tallies","tallies"},{"boss_tallies","tallies"}}) do local map=data[pair[1]];if cats[pair[2]]~=false and map and map[old] and not map[new] then map[new]=clone(map[old]) end end
 if cats.streaks~=false and data.class_win_streaks and data.class_win_streaks[old] and not data.class_win_streaks[new] then
  local scoped=clone(data.class_win_streaks[old]);for _,rows in pairs(scoped) do for class,reset in pairs(classes) do if reset then rows[class]=nil end end end;data.class_win_streaks[new]=scoped
 end
 if cats.streaks~=false and data.class_mode_streaks and data.class_mode_streaks[old] and not data.class_mode_streaks[new] then
  local scoped=clone(data.class_mode_streaks[old]);for _,rows in pairs(scoped) do for class,reset in pairs(classes) do if reset then rows[class]=nil end end end;data.class_mode_streaks[new]=scoped
 end
 if cats.tallies~=false and data.class_boss_tallies and data.class_boss_tallies[old] and not data.class_boss_tallies[new] then local scoped=clone(data.class_boss_tallies[old]);for _,rows in pairs(scoped)do for class,reset in pairs(classes)do if reset then rows[class]=nil end end end;data.class_boss_tallies[new]=scoped end
 if cats.streaks~=false and data.maelstrom_streaks and data.maelstrom_streaks[old] and not data.maelstrom_streaks[new]then local scoped=clone(data.maelstrom_streaks[old]);for class,reset in pairs(classes)do if reset then scoped.classes[class]=nil end end;data.maelstrom_streaks[new]=scoped end
 if cats.class~=false and data.class_overview and data.class_overview[old]and not data.class_overview[new]then
  local scoped=clone(data.class_overview[old]);for _,rows in pairs(scoped)do for class,reset in pairs(classes)do if reset then rows[class]=nil end end;for _,value in pairs(rows)do if cats.damage==false then value.damage=0 end end end;data.class_overview[new]=scoped
 end
 if cats.class~=false then
  if not classes.ogryn and data.blo_global and data.blo_global[old] and not data.blo_global[new] then data.blo_global[new]=clone(data.blo_global[old]) end
  if not classes.ogryn and data.blo_weapons and data.blo_weapons[old] and not data.blo_weapons[new] then
   data.blo_weapons[new]={};for weapon,child in pairs(data.blo_weapons[old]) do if not weapons[weapon] then local c=clone(child);P.carry(c,old,new,{categories={class=true,damage=false,streaks=false,non_damage=false,tallies=false}});c.blo_global=c.blo_global or {};c.blo_global[new]=clone(c.blo_global[old]);data.blo_weapons[new][weapon]=c end end
  end
  if data.class_events and data.class_events[old] and not data.class_events[new] then local c=clone(data.class_events[old]);for _,rows in pairs(c) do for class,reset in pairs(classes) do if reset then rows[class]=nil end end end;data.class_events[new]=c end
 end
 return true
end
function P.bind(mod,previous)
    local state=(mod.io_data_get and mod.io_data_get("stats_patch_group_v1")or mod:get("stats_patch_group_v1"))or {}
    state.group=P.normalize(state.group);state.seen=P.normalize(state.seen)
    local pending,shown
    local function version() return P.normalize(APPLICATION_SETTINGS and APPLICATION_SETTINGS.game_version) end
    local function persist()
        if mod.io_data_set then mod.io_data_set("stats_patch_group_v1",state);if mod.io_storage then mod.io_storage:flush()end
        else mod:set("stats_patch_group_v1",state,false)end
    end
    local function current()
        local actual=version()
        if not actual then return state.group or "unverified-patch" end
        if not state.group then
            state.group=P.normalize(previous) or actual
            state.seen=state.group
            persist()
        end
        if actual~=state.seen then pending=actual end
        return state.group
    end
    local function update(allowed)
        current()
        if not pending or shown or not allowed or not Managers.event then return end
        local actual=pending;shown=true
        local function choose(new_group)
            if new_group then state.group=actual end
            state.seen=actual;pending=nil;shown=false;persist()
        end
        -- after a mods reload the answers of a popup still up belong to the old load, so they do nothing
        Managers.event:trigger("event_show_ui_popup",{
            title_text_unlocalized="Information Overload: new game patch",
            description_text_unlocalized="Game version "..actual.." detected. Does it change balance for the statistics you track?",
            options={
                {text="No - keep existing stats group",no_localization=true,close_on_pressed=true,callback=function() if get_mod("information_overload")~=mod then return end;choose(false) end},
                {text="Yes - start a new stats group",no_localization=true,close_on_pressed=true,callback=function()
                    if get_mod("information_overload")~=mod then return end
                    local policy={old=state.group,new=actual,categories={damage=true,streaks=true,class=true,non_damage=true,tallies=true},classes={},weapons={}}
                    if mod.io_apply_patch then mod.io_apply_patch(state.group,actual,policy) end;choose(true)
                end},
            },
        })
    end
    return current,update
end
return P
