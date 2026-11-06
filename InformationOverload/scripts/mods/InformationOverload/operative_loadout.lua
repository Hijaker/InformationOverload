-- Store display-only profile snapshots; never retain live item/profile objects.
local L={}
local Items=require("scripts/utilities/items")
local Master=require("scripts/backend/master_items")
local function master_items()
 local backend=Managers and Managers.backend
 if not backend or not backend.interfaces or not backend.interfaces.master_data then return end
 return Master.get_cached()
end
local Parser=require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local function valid(s) return type(s)=="string" and s~="" and not s:find("<unlocalized",1,true) end
-- a description keeps the game's colour codes for the Builds page; one that is only codes is no text
local function shown(s) return valid(s) and valid((s:gsub("{#[^}]*}",""))) and s or nil end
local function item_name(item)
    if type(item)~="table" then return end
    local label=Items.display_name(item);return valid(label)and label or nil
end
local function blessings(item,curio)
    if type(item)~="table" or type(item.traits)~="table" then return end
    local definitions=master_items()
    local names={}
    for _,trait in ipairs(item.traits) do
        local definition=definitions and definitions[trait.id]
        local label=item_name(definition) or "Unknown blessing"
        if curio and definition and type(trait.rarity)=="number" then
            local description=shown(Items.trait_description(definition,trait.rarity,trait.value or 0))
            if description then label=description end
        end
        local tier=not curio and tonumber(trait.rarity)
        names[#names+1]=label..(tier and " "..(({"I","II","III","IV"})[tier] or tostring(tier)) or "")
    end
    return #names>0 and table.concat(names,", ") or "None"
end
local function perks(item,shorten)
    if type(item)~="table" or type(item.perks)~="table" then return end
    local result={};local definitions=master_items()
    for _,perk in ipairs(item.perks) do
        local definition=definitions and definitions[perk.id]
        -- a perk is known by its rarity alone; the game gives it no value of its own
        if definition and type(perk.rarity)=="number"then
            local label=shown(Items.trait_description(definition,perk.rarity,perk.value))
            if label then
                if shorten then
                    local lower=label:lower()
                    for _,armor in ipairs({"Flak","Carapace","Unyielding","Maniac","Infested","Unarmoured"}) do
                        if lower:find(armor:lower(),1,true) then label=armor;break end
                    end
                end
                result[#result+1]=label
            elseif not shorten then
                result[#result+1]="Unknown perk"
            end
        elseif not shorten then
            result[#result+1]="Unknown perk"
        end
    end
    return #result>0 and table.concat(result," / ") or "None"
end
function L.weapon_names(profile)
 local slots=profile.loadout or {};return {melee=item_name(slots.slot_primary),ranged=item_name(slots.slot_secondary)}
end
function L.capture(profile)
    local result={}
    local loadout=profile.loadout or {}
    local slots={
        {"melee","slot_primary"},{"ranged","slot_secondary"},
        {"curio_1","slot_attachment_1"},{"curio_2","slot_attachment_2"},{"curio_3","slot_attachment_3"},
    }
    for _,slot in ipairs(slots) do
        local key,item=slot[1],loadout[slot[2]]
        result[key]=item_name(item)
        local weapon=key=="melee" or key=="ranged"
        result[key.."_blessings"]=blessings(item,not weapon)
        result[key.."_perks"]=perks(item,weapon)
        if weapon then result[key.."_perk_details"]=perks(item) end
    end
    local archetype=profile.archetype
    if type(archetype)~="table" then return result end
    local definitions=archetype.talents or {};local selected=profile.selected_nodes or {};local choices, talents, captured={},{},{}
    do
        local layouts=Parser.archetype_layouts(archetype)
        for _,layout in ipairs(layouts or {}) do for _,node in ipairs(layout.nodes or {}) do
            local selection=selected[node.widget_name]
            local value=profile.talents and profile.talents[node.talent]
            local tier=type(value)=="table" and value.tier or value
            local chosen=type(selection)=="number" and selection>0 or type(value)=="table" and value.node_name==node.widget_name and type(tier)=="number" and tier>0
            local field=({tactical="blitz",ability="ability",aura="aura",keystone="keystone"})[node.type]
            local definition=definitions[node.talent]
            if chosen and definition then
                local rank=type(selection)=="number" and selection>0 and selection or tier
                local label=Parser.talent_title(definition,rank)
                if valid(label) then
                    talents[#talents+1]={name=label,id=node.talent,node=node.widget_name,rank=rank}
                    captured[node.talent]=true
                    if field then choices[field]=choices[field] or {};choices[field][label]=true end
                end
            end
        end end
    end
    -- Older profiles can still expose ability/aura definitions without tree nodes.
    for id,value in pairs(profile.talents or {}) do
        local tier=type(value)=="table" and value.tier or value;local definition=definitions[id]
        if type(tier)=="number" and tier>0 and definition then
            if not captured[id] then
                local label=Parser.talent_title(definition,tier)
                if valid(label) then talents[#talents+1]={name=label,id=id,rank=tier} end
            end
            local ability=definition.player_ability
            local field=ability and (ability.ability_type=="grenade_ability" and "blitz" or ability.ability_type=="combat_ability" and "ability") or definition.coherency and "aura"
            if field and not choices[field] and definition.display_name then
                local label=type(definition.display_name)=="string"and Localize(definition.display_name)
                if valid(label) and label~=definition.display_name then result[field]=label end
            end
        end
    end
    for field,names in pairs(choices) do local list={};for name in pairs(names) do list[#list+1]=name end;table.sort(list);result[field]=table.concat(list,", ") end
    table.sort(talents,function(a,b)
        if a.name~=b.name then return a.name<b.name end
        if a.id~=b.id then return a.id<b.id end
        return (a.node or "")<(b.node or "")
    end)
    if #talents>0 then result.talents=talents end
    return result
end
function L.lines(name,snapshot)
    snapshot=snapshot or {};local lines={"{#color(221,183,99)}"..name.."{#reset()}",""}
    local colors={melee="235,233,224",ranged="235,233,224",blitz="100,200,120",ability="220,175,90",keystone="175,125,220",aura="110,175,220"}
    for _,pair in ipairs({{"melee","Melee"},{"ranged","Ranged"},{"blitz","Blitz"},{"ability","Ability"},{"keystone","Keystone"},{"aura","Aura"}}) do
        local id=pair[1];lines[#lines+1]="{#color("..colors[id]..")}"..pair[2]..":{#reset()}"
        lines[#lines+1]=snapshot[id] or "Not available"
        if id=="melee" or id=="ranged" then
            lines[#lines+1]="{#color(215,165,95)}"..(snapshot[id.."_blessings"] or "Not available").."{#reset()}"
            lines[#lines+1]="{#color(145,185,225)}"..(snapshot[id.."_perks"] or "Not available").."{#reset()}"
        end
        lines[#lines+1]=""
    end
    return lines
end
return L

