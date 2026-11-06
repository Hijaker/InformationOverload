-- Presentation model shared by the dashboard and isolated tests.
local Model = {}
local function value(row, field)
    if field == "category" and row.aggregate then return "all weapons" end
    if field == "explosive" then return row.context.explosive and "explosive" or "non-explosive" end
    return tostring(row.context[field])
end
local function matches(row, mode, filters)
    if mode and row.context.mode ~= mode then return false end
    for field, selected in pairs(filters) do if value(row, field) ~= selected then return false end end
    return true
end
function Model.summary(tracker, mode, filters)
    local best, record_runs = {}, {}
    local leaf_scope = filters.category and filters.category ~= "all weapons"
    if not mode then return {best = best, record_runs = record_runs} end
    for _, row in pairs(tracker.data.rows) do
        if matches(row, mode, filters) and (leaf_scope and not row.aggregate or not leaf_scope and row.aggregate) then
            for key, n in pairs(row.best) do
                if n > (best[key] or 0) then
                    best[key] = n
                    record_runs[key]=row.best_runs and row.best_runs[key] or nil
                end
            end
        end
    end
    return {best = best, record_runs = record_runs}
end
local function blo_prefix(bucket)
 local counts={};local censored=0
 if bucket.prefix_counts then for n,value in pairs(bucket.prefix_counts)do counts[tonumber(n)]=value end
 else for _,hist in ipairs({bucket.hist or {},bucket.censored or {}})do for n,value in pairs(hist)do local size=tonumber(n);if size then for length=1,size do counts[length]=(counts[length]or 0)+value end end end end end
 for _,value in pairs(bucket.censored or {})do censored=censored+value end
 local trials=bucket.chain_trials or math.max(0,(bucket.shots or 0)-(bucket.procs or 0))+censored
 local chance=(bucket.chance_shots or 0)>0 and bucket.chance_sum/bucket.chance_shots or nil
 return counts,trials,chance
end
Model.blo_prefix=blo_prefix

return Model
