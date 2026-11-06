-- Read the active mission's faction, not the player's next Havoc assignment.
local F={}
local names={renegade="Scabs",cultist="Dregs",mixed="Mixed",scabs="Scabs",dregs="Dregs"}
function F.label(value)
    return type(value)=="string" and names[value] or nil
end
function F.capture(context,havoc)
    if context and context.mode=="havoc" and type(havoc)=="table" and F.label(havoc.faction) then
        context.havoc_faction=havoc.faction
    end
end
return F
