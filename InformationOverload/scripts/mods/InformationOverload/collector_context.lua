-- Shared context observations. Created once inside each collector factory.
return function(mod,api,C,WeaponTemplate,Loadouts,SocialNames,BossIdentity,crystalline,invoke,live_context)
    local function local_unit()
        local p = Managers.player and Managers.player:local_player_safe(1)
        return p and p.player_unit
    end
    local function extension(unit, system)
        return unit and ScriptUnit.has_extension(unit, system)
    end
    local function field(component, name)
        if not component then return nil end
        -- Game component proxies throw on fields absent from their schema.
        local config = type(component)=="table" and rawget(component,"__config")
        if config and not config[name] then return nil end
        return component[name]
    end
    local breed_cache=setmetatable({},{__mode="k"})
    local function breed(unit)
        local cached=unit and breed_cache[unit]
        if cached then return cached end
        
        local e=extension(unit,"unit_data_system")
        local b=e and type(e.breed)=="function"and e:breed()
        if unit and b then breed_cache[unit]=b end
        return b
    end
    local function enemy_display(b,unit)
        if b and BossIdentity.captains[b.name] then local _,label=BossIdentity.identify(unit,b,extension);return label or "Unknown enemy" end
        if not b then return "Unknown enemy" end
        local key=b.display_name or b.name and "loc_breed_display_name_"..b.name
        if type(key)=="string" then local label=Localize(key);if type(label)=="string" and label~=key and not label:find("<unlocalized",1,true) then return label end end
        return "Unknown enemy"
    end
    local function is_enemy(unit)
        local b = breed(unit)
        return b and b.breed_type == "minion", b
    end
    local function observe_context(action, category, template)
        if not api.enabled() then return end
        local unit = local_unit()
        if not unit or (action and action._player_unit ~= unit) then return end
        local data = extension(unit, "unit_data_system")
        if data and data.is_resimulating then return end
        local weapon = extension(unit, "weapon_system")
        template = template or (action and action._weapon_template) or (weapon and weapon:weapon_template())
        local c = api.context({_player_unit = unit, _weapon_template = template})
        if not c then return end
        if action then C.last_combat=C.clock end
        local party=Managers.party_immaterium
        if party and type(party.is_in_private_session)=="function"then
            local value=party:is_in_private_session()
            if type(value)=="boolean"then c.private_game=value end
        end
        c.crystalline_will=crystalline(unit)
        c.category = category or (template and WeaponTemplate.is_melee(template) and "melee" or "ranged")
        return c
    end
    local identity
    local function peril_players()
        local out={}
        for _,player in pairs(Managers.player and Managers.player:players()or {})do
            local unit=player.player_unit;local profile=player:profile();local a=profile and profile.archetype;local class=type(a)=="table"and a.name or a
            if unit and class=="psyker"and player:is_human_controlled()and HEALTH_ALIVE[unit]then
                local info=identity(unit);local data=extension(unit,"unit_data_system")
                local state=data and data:read_component("character_state");local name=state and state.state_name
                if info and name~="dead"and name~="hogtied"and name~="knocked_down"then
                    local component=data and data:read_component("warp_charge")
                    out[#out+1]={id=info.id,unit=unit,personal=info.personal,value=component and component.current_percentage}
                end
            end
        end
        return out
    end
    local function human(player)
        if player and type(player.is_human_controlled)=="function" then return player:is_human_controlled()==true end
        return player~=nil
    end
    -- Cache only resolved human identities; missing owners are retried immediately.
    -- A unit replacement invalidates immediately; the one-second expiry also
    -- refreshes profile/name changes without retaining per-hit identity tables.
    local identity_cache=setmetatable({},{__mode="k"})
    identity=function(unit)
        if not unit then return end
        local m=api.tracker().mission;local cached=identity_cache[unit]
        if cached and cached.mission==m and cached.player.player_unit==unit and C.clock<cached.expires then
            return cached
        end
        
        identity_cache[unit]=nil
        local spawn=Managers.state and Managers.state.player_unit_spawn
        local player=spawn and spawn.owner and spawn:owner(unit)
        if player and player.player_unit~=unit then player=nil end
        if not player then
            
            for _,p in pairs(Managers.player and Managers.player.players and Managers.player:players()or {})do
                if p.player_unit==unit then player=p;break end
            end
        end
        if not player or not human(player)then return end
        local id=tostring(unit)
        if type(player.character_id)=="function"then local value=player:character_id();if value then id=tostring(value)end end
        local profile=type(player.profile)=="function"and player:profile()
        local a=profile and profile.archetype;local class=type(a)=="table"and a.name or a
        local personal=unit==local_unit()
        local account=player.account_id and player.account_id(player)
        cached={id=id,class=class,personal=personal,player=player,account=account,mission=m,expires=C.clock+1}
        identity_cache[unit]=cached
        if m then
            m.context.operative_identities=m.context.operative_identities or {}
            m.context.operative_identities[id]={name=profile and profile.name,class=class,human=true,personal=personal,friend_name=SocialNames.friend_name(player),steam_name=SocialNames.steam_name(player)}
            
        end
        return cached
    end
    local function member(unit)
        local info=identity(unit)
        if info then return info.id,info.class,info.personal end
        if unit and unit==local_unit()then local c=live_context();return c and tostring(c.character)or tostring(unit),c and c.class,true end
        return nil,nil,false
    end
    local function sample_loadout(m)
            invoke(function()
                if C.clock<(m.next_loadout_sample or 0) then return end
                m.next_loadout_sample=C.clock+2
                local players=Managers.player
                if players and type(players.players)=="function" then
                    m.context.teammates=m.context.teammates or {}
                    for _,player in pairs(players:players()) do
                        if type(player.profile)=="function" then
                            local profile=player:profile()
                            if profile and type(profile.name)=="string" then local archetype=profile.archetype
                            local class=type(archetype)=="table" and archetype.name or archetype
                            m.context.teammates[profile.name]=type(class)=="string" and class or true
                            if type(player.is_human_controlled)~="function" or player:is_human_controlled() then
                            local id=type(player.character_id)=="function" and player:character_id() or profile.character_id;id=id and tostring(id) or profile.name
                            m.context.operative_loadouts=m.context.operative_loadouts or {}
                            local snapshot=Loadouts.capture(profile)
                            local previous=m.context.operative_loadouts[id] or {}
                            for key,value in pairs(snapshot) do previous[key]=value end
                            m.context.operative_loadouts[id]=previous end end
                        end
                    end
                end
            end)
    end
    return {local_unit=local_unit,extension=extension,field=field,breed=breed,
        enemy_display=enemy_display,is_enemy=is_enemy,human=human,identity=identity,
        member=member,peril_players=peril_players,observe_context=observe_context,
        sample_loadout=sample_loadout,
        cached_identity=function(unit)return identity_cache[unit]end,
        reset=function()
            identity_cache=setmetatable({},{__mode="k"})
            breed_cache=setmetatable({},{__mode="k"})
        end}
end
