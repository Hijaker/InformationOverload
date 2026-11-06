-- Per-collector class observations; hook registration stays at its original point.
return function(mod,api,C,D)
    local local_unit,extension,field,identity,breed=D.local_unit,D.extension,D.field,D.identity,D.breed
    local crystalline,live_context,invoke,is_enemy=D.crystalline,D.context,D.invoke,D.is_enemy
    local WeaponTemplate,HyperCritical,Haymaker=D.WeaponTemplate,D.HyperCritical,D.Haymaker
    local hyper_report,haymaker_report,pbb_unit
    local hyper_mission;local hyper_seen=setmetatable({},{__mode="k"})
    local function hyper_register(unit,profile)
        local m=api.tracker().mission;if not m then return end
        if hyper_mission~=m then hyper_mission=m;hyper_seen=setmetatable({},{__mode="k"})end
        local info=identity(unit);if not info or info.class~="broker"then return end
        return HyperCritical.register(m,info.id,profile,info.personal)
    end
    hyper_report=function(profile,target,attacker,result,attack_type,critical,measurement)
        local m=api.tracker().mission;if not m then return end
        if hyper_mission~=m then hyper_mission=m;hyper_seen=setmetatable({},{__mode="k"})end
        if not HyperCritical.signature(profile,result,attack_type,critical)or not target or hyper_seen[target]then return end
        local info=identity(attacker);if not info or info.class~="broker"then return end
        local p=type(info.player.profile)=="function"and info.player:profile()
        local row=hyper_register(attacker,p);if not row or not row.selected then return end
        local b=breed(target);if not b or b.is_boss or b.tags and (b.tags.monster or b.tags.captain)then return end
        hyper_seen[target]=true;row.kills=row.kills+1;HyperCritical.contribution(row,measurement)
    end
    local haymaker_mission;local haymaker_seen=setmetatable({},{__mode="k"})
    haymaker_report=function(profile,target,attacker,result,kind,measurement)
        local m=api.tracker().mission;if not m then return end
        if haymaker_mission~=m then haymaker_mission=m;haymaker_seen=setmetatable({},{__mode="k"})end
        if not target or haymaker_seen[target]or not Haymaker.signature(profile,result,kind)then return end
        local info=identity(attacker);if not info then return end
        if not Haymaker.equipped(extension(attacker,"buff_system"))then return end
        local b=breed(target);local tags=b and b.tags or {}
        if not b or b.is_boss or tags.monster or tags.captain or tags.ogryn or tags.cultist_captain then return end
        haymaker_seen[target]=true;Haymaker.record(m,info.id,info.personal,measurement)
    end
    local function report_class_events(profile,target,attacker,damage,result)
        if attacker==local_unit() and profile and profile.name=="plasma_overheat" and crystalline(attacker) and is_enemy(target) then
            api.tracker():class_event("crystalline_will",damage or 0,result=="died",C.clock,target,breed(target) and breed(target).tags)
        end
        if attacker==local_unit() and profile and is_enemy(target) then
            local name=profile.name or "";local id
            if name=="ogryn_friendly_rock_impact" then id="ogryn_grenade_friend_rock"
            elseif name=="psyker_smite_kill" then id="brain_burst"
            elseif name:find("psyker_throwing_knives",1,true)==1 then id="assail" end
            if id then api.tracker():class_event(id,damage or 0,result=="died",C.clock,target,breed(target) and breed(target).tags) end
        end
    end
    -- Scope ammo sampling to the specific PBB buff's stop callback. Other ammo
    -- additions (pickups, talents, teammates) cannot enter these records.
    local function ammo_snapshot(unit)
        local weapon = extension(unit, "weapon_system")
        local samples = {}
        for slot, w in pairs(weapon and weapon._weapons or {}) do
            local comp = w.inventory_slot_component
            if comp and w.weapon_template and not WeaponTemplate.is_melee(w.weapon_template) and (field(comp,"max_ammunition_reserve") or 0) > 0 then
                samples[slot] = {value = comp.current_ammunition_reserve,
                    component = comp, template = w.weapon_template}
            end
        end
        return samples
    end
    local function pbb_destroy(func, buff, ...)
        local previous = pbb_unit
        invoke(function()
            local context = buff._template_context
            local name = buff._template_name or (buff._template and buff._template.name)
            if name == "ogryn_ranged_stance" and context and context.unit == local_unit() then pbb_unit = context.unit end
        end)
        local result = {func(buff, ...)}
        pbb_unit = previous
        return unpack(result)
    end
    local function install_ammo_hooks()
    mod:hook("Buff", "destroy", pbb_destroy)
    -- ProcBuff overrides destroy and caches its superclass implementation.
    mod:hook("ProcBuff", "destroy", pbb_destroy)
    local Ammo = require("scripts/utilities/ammo")
    mod:hook(Ammo, "add_to_all_slots_flat", function(func, unit, amount, ...)
        local before;if unit == pbb_unit then invoke(function()before = ammo_snapshot(unit)end)end
        local result = {func(unit, amount, ...)}
        if before then invoke(function()
            for _, sample in pairs(before) do
                local c = live_context(nil, "ranged", sample.template)
                local added = sample.component.current_ammunition_reserve - sample.value
                if c and added > 0 then
                    C.ammo_event = (C.ammo_event or 0) + 1
                    api.tracker():pbb_ammo(c, added, C.ammo_event, "pbb"); 
                end
            end
        end) end
        return unpack(result)
    end)
    end
    return {hyper_register=hyper_register,hyper_report=hyper_report,
        haymaker_report=haymaker_report,report=report_class_events,
        install_ammo_hooks=install_ammo_hooks}
end
