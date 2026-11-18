-- Explosion profiles owned by a hitscan weapon's firing configurations, excluding vent/overload damage.
local E={};local cached=setmetatable({},{__mode="k"})
function E.profiles(template)
    if type(template)~="table" then return nil end
    if cached[template] then return cached[template] end
    local out={}
    local function explosion(t)
        if type(t)~="table" then return end
        for _,key in ipairs({"damage_profile","close_damage_profile"}) do
            local p=t[key]
            if type(p)=="table" and p.name then out[p.name]=true end
        end
    end
    for _,action in pairs(template.actions or {}) do
        if action.kind=="shoot_hit_scan" then
            for _,field in ipairs({"fire_configuration","fire_special_configuration"}) do
                local config=action[field];local scan=config and config.hit_scan_template
                for _,stage in pairs(scan and scan.damage or {}) do
                    if type(stage)=="table" then
                        explosion(stage.explosion_template);explosion(stage.exit_explosion_template)
                        for _,t in pairs(stage.armor_explosion or {}) do explosion(t) end
                    end
                end
            end
        end
    end
    cached[template]=out
    return out
end
function E.matches(template,profile)
    local set=E.profiles(template)
    return type(set)=="table" and set[type(profile)=="table" and profile.name or profile]==true
end
return E
