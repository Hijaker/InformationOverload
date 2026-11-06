local E={groups={{id="normal",label="Trash Enemies"},{id="elite",label="Elites"},{id="special",label="Specials"},{id="boss",label="Bosses"}}}
local aliases={['Rinda Karnak']='Melee-Twin',['Rodin Karnak']='Ranged-Twin'}
local function display(label,id)
 if id=='renegade_wizard' then return 'Rodin Karnak, Prophet of Decay' end
 if id=='renegade_twin_captain' then return 'Ranged-Twin' end
 if id=='renegade_twin_captain_two' then return 'Melee-Twin' end
 if id and id:find('daemonhost',1,true) or label:find('Daemonhost',1,true) then return 'Daemonhost' end
 if label:find('Prophet of Decay',1,true) then return 'Rodin Karnak, Prophet of Decay' end
 return aliases[label] or label
end
local cache
local function localize(key)
    if type(key)~="string" then return end
    local label=Localize(key)
    if type(label)=="string" and label~=key and label~="" and not label:find("<unlocalized",1,true) then return label end
end
function E.catalog()
    if cache then return cache end
    local breeds=require("scripts/settings/breed/breeds")
    local result={};for id,b in pairs(breeds) do if b.breed_type=="minion" then
        local label=localize(b.display_name);local tags=b.tags or {}
        if label then result[id]={id=id,label=display(label,id),horde_type=b.ranged and "ranged" or "melee",group=(b.is_boss or tags.monster or tags.captain) and "boss" or tags.special and "special" or tags.elite and "elite" or "normal"} end
    end end
    result.renegade_captain=nil;result.cultist_captain=nil
    result.hammer_captain={id="hammer_captain",label="Hammer-captain",group="boss"}
    result.sword_captain={id="sword_captain",label="Sword-captain",group="boss"}
    cache=result;return result
end
function E.name(value)
    local entry=E.catalog()[value];if entry then return entry.label end
    if type(value)=="string" and value:find("loc_",1,true)==1 then return localize(value) or "Unknown enemy" end
    return type(value)=="string" and not value:find("_",1,true) and display(value) or "Unknown enemy"
end
return E
