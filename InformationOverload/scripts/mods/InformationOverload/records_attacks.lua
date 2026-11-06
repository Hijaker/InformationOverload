-- Existing attack reducers, preserving the facade queue and dispatch.
return function(Records,copy,key)
function Records:dodge(c)
    if not self:accept(c) then return end
    self.current.dodges = self.current.dodges + 1
    self:best(c, "dodges", self.current.dodges)
end

function Records:damage_received(c, source)
    if not self:accept(c) then return end
    -- The adapter must classify actual damage, not attempted hits/blocks.
    if source == "enemy_attack" then self.current.dodges = 0 end
end

function Records:begin_attack(c)
    if not self:accept(c) then return nil end
    assert(c.category == "melee" or c.category == "ranged", "Attack category must be melee or ranged")
    self.next_id = self.next_id + 1
    local id = self.next_id
    self.pending[id] = { context = copy(c), damage = 0, kills = 0, headshot = false, resolved = false,
        armour_damage = {}, target_damage = {}, seen = {}, boss_damage = {}, boss_health = {} }
    self.queue[#self.queue + 1] = id
    return id
end

function Records:run_damage_hit(c,e)
    local m=self.mission
    if not m then return end
    local damage=e.calculated_damage or e.damage
    if type(damage)~="number" or damage~=damage or damage<0 or damage>=math.huge then return end
    m.damage=m.damage or {}
    m.damage.dot_version=1
    local category=c.category=="dot" and "dot" or c.category=="melee" and "melee" or "ranged"
    local armour=tostring(e.armour or "unknown")
    local groups={"total",category}
    if category=="dot" then groups[#groups+1]="dot_"..tostring(e.dot_type or "other") end
    for _,name in ipairs(groups) do
        local group=m.damage[name] or {};m.damage[name]=group
        for _,key in ipairs({"all",armour}) do
            local stats=group[key] or {total=0,useful=0,overkill=0,hits=0,health_hits=0};group[key]=stats
            stats.total=stats.total+damage;stats.hits=stats.hits+1
            local health=e.health_before
            if type(health)=="number" and health==health and health>0 and health<math.huge then
                local useful=math.min(damage,health)
                stats.useful=stats.useful+useful;stats.overkill=stats.overkill+damage-useful;stats.health_hits=stats.health_hits+1
            end
        end
    end
end

function Records:hit(id, e)
    local a = self.pending[id]
    if not a or a.resolved or e.origin ~= "player_attack" or e.status_effect then return false end
    assert(e.event_id ~= nil, "Damage events need a stable deduplication ID")
    if a.seen[e.event_id] then return false end
    a.seen[e.event_id] = true
    self:run_damage_hit(a.context,e)
    if e.armour=="void_shield"then return false end
    local damage = math.max(0, tonumber(e.damage) or 0)
    a.cleave = a.cleave or e.cleave == true
    a.damage = a.damage + damage
    if a.context.explosive and e.is_explosion~=false then a.explosion_damage=(a.explosion_damage or 0)+damage end
    local target = tostring(e.target_id or e.boss_id or e.event_id)
    a.target_names=a.target_names or {};a.target_names[target]=e.enemy or a.target_names[target] or "Unknown"
    a.target_damage[target] = (a.target_damage[target] or 0) + damage
    local armour=tostring(e.armour or "unknown")
    local group=a.armour_damage[armour] or {total=0,targets={}}
    a.armour_damage[armour]=group
    group.total=group.total+damage
    if a.context.explosive and e.is_explosion~=false then group.explosion_total=(group.explosion_total or 0)+damage end
    group.targets[target]=(group.targets[target] or 0)+damage
    a.kills = a.kills + (e.killed and 1 or 0)
    a.headshot = a.headshot or e.headshot == true
    if e.boss_id and e.boss_max_health then
        local boss = tostring(e.boss_id)
        a.boss_damage[boss] = (a.boss_damage[boss] or 0) + damage
        a.boss_health[boss] = e.boss_max_health
    end
    return true
end

function Records:commit(a)
    local c, cur = a.context, self.current
    if a.cancelled then
        -- Unknown/missing server confirmations must not fabricate a miss or
        -- bridge an unverified attack into a longer confirmed streak.
        cur.head_melee, cur.head_ranged, cur.head_combined, cur.kills = 0, 0, 0, 0
        return
    end
    local head = c.category == "melee" and "head_melee" or "head_ranged"
    cur[head] = a.headshot and cur[head] + 1 or 0
    cur.head_combined = a.headshot and cur.head_combined + 1 or 0
    cur.kills = a.kills > 0 and cur.kills + a.kills or 0
    self:best(c, head, cur[head])
    self:best(c, "head_combined", cur.head_combined)
    self:best(c, "kills", cur.kills)
    self:best(c, "damage", a.damage)
    if c.explosive then
        local enemies={};local seen={}
        for _,enemy in pairs(a.target_names or {}) do if not seen[enemy] then seen[enemy]=true;enemies[#enemies+1]=enemy end end
        table.sort(enemies);c.enemy=table.concat(enemies,", ");self:best(c,"explosive_hit",a.explosion_damage or 0);c.enemy=nil
    end
    local targets = 0
    for target,damage in pairs(a.target_damage) do
        c.enemy=a.target_names and a.target_names[target] or "Unknown"
        targets=targets+1
        if not c.explosive and not self:is_class_grenade(c) then self:best(c,"single_hit",damage) end
    end
    c.enemy=nil
    if c.category == "melee" and targets>1 then
        local enemies={};local seen={}
        for _,enemy in pairs(a.target_names or {}) do if not seen[enemy] then seen[enemy]=true;enemies[#enemies+1]=enemy end end
        table.sort(enemies);c.enemy=table.concat(enemies,", ");self:best(c,"melee_cleave",a.damage);c.enemy=nil
    end
    for armour,group in pairs(a.armour_damage) do
        local metrics={damage=group.total}
        if c.explosive then metrics.explosive_hit=group.explosion_total or 0 else
            if not self:is_class_grenade(c) then
                for _,damage in pairs(group.targets) do metrics.single_hit=math.max(metrics.single_hit or 0,damage) end
            end
        end
        if c.category=="melee" and targets>1 then metrics.melee_cleave=group.total end
        for _,row in ipairs(self:rows_for(c)) do
            row.armour_best=row.armour_best or {}
            local bucket=row.armour_best[armour] or {best={},sources={}}
            row.armour_best[armour]=bucket
            for stat,n in pairs(metrics) do
                if self.mission then local m=self.mission;m.replay_armour=m.replay_armour or {};local id=key(c,false).."|"..armour.."|"..stat;local old=m.replay_armour[id];if not old or n>old.value then local source=copy(c);local enemies,seen={},{};local high=-1;local single;for target,value in pairs(group.targets)do local enemy=a.target_names and a.target_names[target]or "Unknown";if value>high then high=value;single=enemy end;if not seen[enemy]then enemies[#enemies+1]=enemy;seen[enemy]=true end end;table.sort(enemies);source.enemy=stat=="single_hit"and single or table.concat(enemies,", ");m.replay_armour[id]={context=source,armour=armour,name=stat,value=n}end end
                if n>(bucket.best[stat] or 0) then bucket.best[stat]=n;bucket.sources[stat]=copy(c)
                    local enemies={};local seen={};local highest=-1;local single_enemy
                    for target,value in pairs(group.targets) do
                        local enemy=a.target_names and a.target_names[target] or "Unknown"
                        if value>highest then highest=value;single_enemy=enemy end
                        if not seen[enemy] then seen[enemy]=true;enemies[#enemies+1]=enemy end
                    end
                    table.sort(enemies);bucket.sources[stat].enemy=stat=="single_hit" and single_enemy or table.concat(enemies,", ")
                    self.dirty=true end
            end
        end
    end
    for boss, damage in pairs(a.boss_damage) do
        if a.boss_health[boss] > 0 and damage >= a.boss_health[boss] then
            for _, row in ipairs(self:rows_for(c)) do row.boss_attacks = row.boss_attacks + 1 end
            self.dirty = true
        end
    end
end

function Records:cancel(id)
    if not self.pending[id] then return false end
    self.pending[id].cancelled = true
    return self:resolve(id)
end

function Records:resolve(id)
    local a = self.pending[id]
    if not a then return false end
    a.resolved = true
    while self.queue[1] and self.pending[self.queue[1]].resolved do
        local next_id = table.remove(self.queue, 1)
        self:commit(self.pending[next_id])
        self.pending[next_id] = nil
    end
    return true
end

function Records:kill_run(c)
    self.data.kill_runs=self.data.kill_runs or {}
    local id=tostring(c.character)
    self.data.kill_runs[id]=self.data.kill_runs[id] or {current={special=0,elite=0,regular=0,total=0},best={special=0,elite=0,regular=0,total=0},class=c.class,name=c.character_name}
    local run=self.data.kill_runs[id]
    run.name=c.character_name or run.name
    return run
end
function Records:kill_credit(c,category,ranged)
    if not c or c.excluded then return false end
    
    if c.difficulty=="psykhanium" then return true end
    if self.mission then local m=self.mission;m.replay_kill_segments=m.replay_kill_segments or {{}};local segment=m.replay_kill_segments[#m.replay_kill_segments];segment.total=(segment.total or 0)+1;if category then segment[category]=(segment[category]or 0)+1 end;self.mission.kills=(self.mission.kills or 0)+1
        local kind=category=="regular"and (ranged and "horde_ranged"or "horde_melee")or category
        if kind then self.mission.kill_categories=self.mission.kill_categories or {};self.mission.kill_categories[kind]=(self.mission.kill_categories[kind]or 0)+1 end
    end
    local run=self:kill_run(c)
    local scoped=self:class_mode_streak(c.patch,c.mode,c.class);scoped.current.kill_run=(scoped.current.kill_run or 0)+1;scoped.best.kill_run=math.max(scoped.best.kill_run or 0,scoped.current.kill_run)
    local mode_record=self:mode_streak(c.patch,c.mode)
    mode_record.current.kill_run=(mode_record.current.kill_run or 0)+1;mode_record.best.kill_run=math.max(mode_record.best.kill_run or 0,mode_record.current.kill_run)
    run.current.total=run.current.total+1
    if category=="special" or category=="elite" or category=="regular" then run.current[category]=run.current[category]+1 end
    local improved=false
    for stat,n in pairs(run.current) do if n>(run.best[stat] or 0) then run.best[stat]=n;improved=true end end
    self.dirty=true
    return improved
end
function Records:reset_kill_run(c)
    if self.mission then self.mission.replay_kill_segments=self.mission.replay_kill_segments or {{}};table.insert(self.mission.replay_kill_segments,{})end
    if not c or c.difficulty=="psykhanium" then return end
    local run=self:kill_run(c)
    self:class_mode_streak(c.patch,c.mode,c.class).current.kill_run=0
    self:mode_streak(c.patch,c.mode).current.kill_run=0
    for stat in pairs(run.current) do run.current[stat]=0 end
    self.dirty=true
end

end
