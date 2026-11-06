-- Mission-only locked profile inspection. Unknown never means missing.
local F={}
function F.inspect(player)
    if type(player.is_human_controlled)~="function" or not player:is_human_controlled() then return end
    local p=type(player.profile)=="function" and player:profile()
    if not p then return nil,"unknown" end
    local a=p.archetype;local class=type(a)=="table" and a.name or a
    if not class then return nil,"unknown" end
    if class~="veteran" then return end
    local level=tonumber(p.current_level)
    if not level then return nil,"unknown" end
    if level<30 then return end
    if type(p.talents)~="table" or not next(p.talents) then return nil,"unknown" end
    local id=type(player.character_id)=="function" and player:character_id() or p.character_id
    if not id then return nil,"unknown" end
    local selected=p.talents.veteran_better_deployables
    local tier=type(selected)=="table" and selected.tier or selected
    return {id=tostring(id),has=type(tier)=="number" and tier>0}
end
function F.sample(mod,tracker,players,clock)
    local m=tracker.mission
    if not m or m.context.difficulty=="psykhanium" or m.context.difficulty=="TEST ONLY" then return end
    local stats=m.field_improvisation
    if not stats then stats={veterans={},started=clock}end
    m.field_improvisation=stats
    local entries,unknown={},false
    for _,player in pairs(players or {}) do
        local entry,state=F.inspect(player)
        if state=="unknown" then unknown=true end
        if entry then entries[#entries+1]=entry
            if stats.veterans[entry.id]==nil then stats.veterans[entry.id]={has=entry.has};tracker.dirty=true end
        end
    end
    if clock-stats.started<2 or #entries==0 then return end
    table.sort(entries,function(a,b)return a.id<b.id end)
    local signature,has={},false
    for _,entry in ipairs(entries) do signature[#signature+1]=entry.id..":"..tostring(entry.has);has=has or entry.has end
    if unknown and not has then return end
    local key=table.concat(signature,"|")
    if key~=stats.notice then
        if mod:get("field_improvisation_chat")==true then mod:echo(has and "Field Improvisation: registered" or "Field Improvisation: missing")end
        stats.notice=key;tracker.dirty=true
    end
end
return F
