-- BLO reducers and local replay helpers, composed into the shared Records table.
return function(Records,copy,deep_copy,key)
function Records:blo_buckets(c)
    if not self.data.blo_global then
        self.data.blo_global={}
        -- Older records do not say whether the talent was equipped.
        for _,row in pairs(self.data.rows) do
            if row.aggregate then
                local patch=tostring(row.context.patch)
                self.data.blo_global[patch]=self.data.blo_global[patch] or {}
                local variants=self.data.blo_global[patch]
                variants.unknown=variants.unknown or {best=0,hist={},censored={}}
                local legacy=variants.unknown
                legacy.best=math.max(legacy.best,row.best.blo or 0)
                for k,n in pairs(row.blo_histogram) do legacy.hist[k]=(legacy.hist[k] or 0)+n end
                for k,n in pairs(row.blo_censored) do legacy.censored[k]=(legacy.censored[k] or 0)+n end
            end
        end
        self.dirty=true
    end
    local patch=tostring(c.patch)
    self.data.blo_global[patch]=self.data.blo_global[patch] or {}
    local variant=c.blo_variant or "unknown"
    local variants=self.data.blo_global[patch]
    local bucket=variants[variant] or {};variants[variant]=bucket
    bucket.best=bucket.best or 0;bucket.hist=bucket.hist or {};bucket.censored=bucket.censored or {}
    return bucket
end
function Records:finish_selected_blo(censored)
    local c=self.selected_blo_context
    local n=self.selected_blo_chain or 0
    if c and n>0 then
        local bucket=self:blo_buckets(c)
        local hist=censored and bucket.censored or bucket.hist
        hist[tostring(n)]=(hist[tostring(n)] or 0)+1;self.dirty=true
    end
    self.selected_blo_chain=0;self.selected_blo_context=nil
end

function Records:finish_blo(censored)
    local n, c = self.current.blo, self.blo_context
    if n > 0 and c then
        for _, row in ipairs(self:rows_for(c)) do
            local hist = censored and row.blo_censored or row.blo_histogram
            local bucket = tostring(n)
            hist[bucket] = (hist[bucket] or 0) + 1
        end
        local bucket=self:blo_buckets(c)
        local hist=censored and bucket.censored or bucket.hist
        hist[tostring(n)]=(hist[tostring(n)] or 0)+1
        self.dirty = true
    end
    self.current.blo = 0
    self.blo_context = nil
end

-- One qualifying count per threshold reached in a streak, including lower lengths.
function Records:initialize_blo_prefix(bucket)
    if bucket.prefix_counts then return end
    bucket.prefix_counts={}
    local censored=0
    for _,hist in ipairs({bucket.hist or {},bucket.censored or {}})do for length,count in pairs(hist)do
        local size=tonumber(length);if size then for n=1,size do local id=tostring(n);bucket.prefix_counts[id]=(bucket.prefix_counts[id]or 0)+count end end
    end end
    for _,count in pairs(bucket.censored or {})do censored=censored+count end
    bucket.chain_trials=math.max(0,(bucket.shots or 0)-(bucket.procs or 0))+censored
end

local function replay_blo(m,c,n)m.replay_blo_contexts=m.replay_blo_contexts or {};local id=key(c,false).."|"..tostring(c.blo_variant);m.replay_blo_contexts[id]=copy(c);m.replay_blo_best=m.replay_blo_best or {};m.replay_blo_best[id]=math.max(m.replay_blo_best[id]or 0,n)end
-- The chain this shot makes: another weapon or variant starts a new one.
local function chain_after(self,c,success)local b=self.blo_context;local n=b and key(c,false)==key(b,false)and c.blo_variant==b.blo_variant and self.current.blo or 0;return success and n+1 or n end
-- Psykhanium trials have no mission, so each keeps a snapshot until the boundary saves it as a hidden match the hub replay rebuilds from.
function Records:finish_blo_trial()
    local t=self.blo_trial;self.blo_trial=nil
    if t and t.data==self.data and Records.capture_discarded then local seq=self.data.run_sequence;Records.capture_discarded(self,t);if self.data.run_sequence~=seq then self.dirty=true end end
end
function Records:blo(c, success)
    if self.mission then replay_blo(self.mission,c,chain_after(self,c,success))end
    if not self:accept(c) then return false end
    if not self.mission and not self.blo_weapon_only and c.difficulty=="psykhanium"and Records.capture_discarded then
        local t=self.blo_trial
        if not t or t.data~=self.data then t={blo_trial=true,full=true,context=copy(c),data=self.data,started_at=os and os.date and os.date("%Y-%m-%d %H:%M:%S"),data_before={rows=not self.data.blo_global and deep_copy(self.data.rows)or {},blo_global=deep_copy(self.data.blo_global),blo_weapons=deep_copy(self.data.blo_weapons)}};self.blo_trial=t end
        replay_blo(t,c,chain_after(self,c,success))
    end
    if not self.blo_weapon_only and c.weapon then
        self.data.blo_weapons=self.data.blo_weapons or {}
        local patch=tostring(c.patch)
        self.data.blo_weapons[patch]=self.data.blo_weapons[patch] or {}
        local stored=self.data.blo_weapons[patch]
        self.blo_weapon_trackers=self.blo_weapon_trackers or {}
        local id=patch..":"..c.weapon
        local child=self.blo_weapon_trackers[id]
        if not child then child=Records.new(stored[c.weapon]);child.blo_weapon_only=true;self.blo_weapon_trackers[id]=child end
        child:blo(c,success);stored[c.weapon]=child.data;self.dirty=true
    end
    if self.selected_blo_context and (not c.blo_talent_selected or key(c,false)~=key(self.selected_blo_context,false)) then self:finish_selected_blo(true) end
    if c.blo_talent_selected then
        local selected=copy(c);selected.blo_variant="melee"
        if success then
            self.selected_blo_chain=(self.selected_blo_chain or 0)+1
            self.selected_blo_context=selected
            local bucket=self:blo_buckets(selected)
            bucket.best=math.max(bucket.best,self.selected_blo_chain);self.dirty=true
            local m=self.mission or self.blo_trial;if m then replay_blo(m,selected,self.selected_blo_chain)end
        else self:finish_selected_blo(false) end
    end
    if self.blo_context and (key(c, false) ~= key(self.blo_context, false) or c.blo_variant ~= self.blo_context.blo_variant) then self:finish_blo(true) end
    local rates=self:blo_buckets(c)
    self:initialize_blo_prefix(rates)
    if self.current.blo==0 then rates.chain_trials=(rates.chain_trials or 0)+1 end
    if success then local n=tostring(self.current.blo+1);rates.prefix_counts[n]=(rates.prefix_counts[n]or 0)+1 end
    rates.shots=(rates.shots or 0)+1
    rates.procs=(rates.procs or 0)+(success and 1 or 0)
    if type(c.blo_chance)=="number" then
        rates.chance_sum=(rates.chance_sum or 0)+math.max(0,math.min(1,c.blo_chance))
        rates.chance_shots=(rates.chance_shots or 0)+1
        rates.chance_procs=(rates.chance_procs or 0)+(success and 1 or 0)
    end
    self.dirty=true
    if success then
        self.blo_context = copy(c)
        self.current.blo = self.current.blo + 1
        local bucket=self:blo_buckets(c)
        local improved=self.current.blo>bucket.best
        if improved then bucket.best=self.current.blo;self.dirty=true end
        self:best(c,"blo",self.current.blo)
        return improved
    end
    self:finish_blo(false)
    return false
end

end
