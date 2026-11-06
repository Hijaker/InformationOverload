local Records = {}

local function copy(t)
    local result = {}
    for k, v in pairs(t or {}) do result[k] = v end
    return result
end

local function deep_copy(value)
    if type(value)~="table" then return value end;local mt=getmetatable(value);if mt and mt.io_materialize then value=mt.io_materialize(value)end;
    local result={};for k,v in pairs(value) do result[k]=deep_copy(v) end;return result
end

local function checkpoint_copy(data)
 local out={};for k,v in pairs(data)do
  if k=="run_history"then local history={};for i,run in ipairs(v)do history[i]=run end;out[k]=history
  else out[k]=deep_copy(v)end
 end;return out
end

local function key(c, aggregate)
    local parts = {c.mode, c.patch, c.difficulty, c.class, c.character}
    if not aggregate then
        parts[#parts + 1] = c.category
        parts[#parts + 1] = c.explosive and "explosive" or "non-explosive"
        parts[#parts + 1] = c.weapon
    end
    -- Length-prefix values to prevent delimiter collisions in names/IDs.
    for i, part in ipairs(parts) do part = tostring(part); parts[i] = #part .. ":" .. part end
    return table.concat(parts, "|")
end

local function fresh_row(c, aggregate)
    return { context = copy(c), aggregate = aggregate, best = {}, blo_histogram = {}, blo_censored = {}, boss_attacks = 0 }
end

function Records:rows_for(c)
    local rows = {}
    for _, aggregate in ipairs({true, false}) do
        local k = key(c, aggregate)
        if not self.data.rows[k] then self.data.rows[k] = fresh_row(c, aggregate) end
        rows[#rows + 1] = self.data.rows[k];if self.mission then self.mission.recovery_rows=self.mission.recovery_rows or {};self.mission.recovery_rows[k]=true end
    end
    return rows
end

function Records:best(c, name, value)
 if self.mission then local m=self.mission;m.replay_best=m.replay_best or {};local id=key(c,false).."|"..name.."|"..tostring(c.enemy);local old=m.replay_best[id];if not old or value>old.value then local source={};for _,field in ipairs({"mode","patch","difficulty","class","character","character_name","category","weapon","explosive","enemy","grenade"})do source[field]=c[field]end;m.replay_best[id]={context=source,name=name,value=value}end end
    if self.mission then
        self.mission.record_values=self.mission.record_values or {}
        self.mission.record_values[name]=math.max(self.mission.record_values[name] or 0,value)
    end
    if name=="single_hit" and c.enemy then
        for _,row in ipairs(self:rows_for(c)) do
            row.enemy_hits=row.enemy_hits or {}
            local old=row.enemy_hits[c.enemy]
            if not old or value>old.damage then row.enemy_hits[c.enemy]={damage=value,weapon=c.weapon,class=c.class};if self.mission then self.mission.enemy_updates=self.mission.enemy_updates or {};self.mission.enemy_updates[#self.mission.enemy_updates+1]={row=row,enemy=c.enemy,value=value} end;self.dirty=true end
        end
    end
    local improved = false
    for _, row in ipairs(self:rows_for(c)) do
        if value > (row.best[name] or 0) then
            row.best[name] = value
            row.best_runs=row.best_runs or {};row.best_runs[name]=nil
            if self.mission then
                self.mission.record_updates=self.mission.record_updates or {}
                self.mission.record_updates[#self.mission.record_updates+1]={row=row,name=name,value=value}
            end
            row.best_weapons = row.best_weapons or {}
            row.best_weapons[name] = copy(c)
            improved = true; self.dirty = true
        end
    end
    return improved
end

function Records:mission_row(c)
    local k = key(c, true)
    if not self.data.rows[k] then self.data.rows[k] = fresh_row(c, true) end
    if self.mission then self.mission.recovery_rows=self.mission.recovery_rows or {};self.mission.recovery_rows[k]=true end;return self.data.rows[k]
end

Records.copy=copy
Records.deep_copy=deep_copy
Records.checkpoint_copy=checkpoint_copy
Records.key=key
Records.fresh_row=fresh_row
return Records
