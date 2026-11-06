-- Resolve official localized family/pattern/mark names without changing record IDs.
local names = {}
local blitz_names={
    brain_burst="loc_talent_psyker_brain_burst_improved",
    assail="loc_ability_psyker_blitz_throwing_knives",
    missile_launcher="loc_talent_broker_blitz_missile_launcher",
    grenade_tox="loc_talent_broker_blitz_tox_grenade",
    grenade_flash="loc_talent_broker_blitz_flash_grenade",
    grenade_frag="loc_ability_frag_grenade",
    grenade_krak="loc_talent_ability_krak_grenade",
    grenade_smoke="loc_ability_smoke_grenade",
    grenade_shock="loc_ability_shock_grenade",
    grenade_fire="loc_talent_ability_fire_grenade",
    ogryn_grenade_frag="loc_ability_ogryn_grenade_demolition",
    grenade_ogryn_frag="loc_ability_ogryn_grenade_demolition",
    ogryn_grenade_box="loc_ability_ogryn_grenade_box",
    grenade_box_ogryn="loc_ability_ogryn_grenade_box",
    grenade_box_ogryn_cluster="loc_ability_ogryn_grenade_box",
    ogryn_grenade_friend_rock="loc_ability_ogryn_friend_rock",
    grenade_ogryn_friend_rock="loc_ability_ogryn_friend_rock",
    grenade_adamant="loc_talent_ability_adamant_grenade",
    mine_shock="loc_talent_ability_shock_mine",
    grenade_arc="loc_talent_cryptic_arc_grenades",
}

local Items=require("scripts/utilities/items")
local Master=require("scripts/backend/master_items")
local function master_items()
 local backend=Managers and Managers.backend
 if not backend or not backend.interfaces or not backend.interfaces.master_data then return end
 return Master.get_cached()
end
local populated = false
return function(id)
    if not populated then
        local items=master_items()
        if type(items) == "table" and next(items) then
            for _, item in pairs(items) do
                if type(item) == "table"  then
                    local label=Items.display_name(item)
                    if type(label) == "string" and label ~= "" and not label:find("<unlocalized",1,true) then
                        if item.weapon_template then names[item.weapon_template] = label end
                        if item.weapon_progression_template then names[item.weapon_progression_template] = label end
                        if item.name then names[item.name]=label;names[item.name:match("([^/]+)$")]=label end
                        if item.display_name then names[item.display_name]=label end
                    end
                end
            end
            populated = next(names) ~= nil
        end
    end
    local key=blitz_names[id] or blitz_names[tostring(id):match("([^/]+)$")]
    if key then local label=Localize(key);if type(label)=="string" and label~="" and label~=key and not label:find("<unlocalized",1,true) then return label end end
    local label=names[id]
    if label then return label:gsub("[Cc]hordclaw","Transonic Claw") end
    -- a squad member's weapon is saved as the name the game showed
    if type(id)=="string" and id:find("[%s%u]") then return (id:gsub("[Cc]hordclaw","Transonic Claw")) end
    if tostring(id):lower():find("chordclaw",1,true) then return "Transonic Claw" end
    return "Unknown weapon"
end

