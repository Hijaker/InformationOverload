local H={}
function H.parameters(c)
    if not c or c.mode=="havoc" then return "" end
    local combined=tostring(c.circumstance or ""):lower()
    for id,label in pairs(c.modifiers or {}) do combined=combined.." "..tostring(id):lower().." "..tostring(label):lower() end
    if c.maelstrom or combined:find("maelstrom",1,true) or combined:find("flash_mission_",1,true) then return "Maelstrom" end
    local results,seen={},{}
    local function add(s)if not seen[s] then results[#results+1]=s;seen[s]=true end end
    for id,label in pairs(c.modifiers or {}) do
        local value=(tostring(id).." "..tostring(label)):lower()
        if value:find("darkness",1,true) or value:find("power supply interruption",1,true) then add("PSI")
        elseif value:find("high intensity",1,true) and (value:find("shock",1,true) or value:find("more_specials",1,true)) or value:find("high_intensity_more_specials",1,true) or value:find("more_resistance",1,true) and value:find("more_specials",1,true) then add("HI-STG")
        elseif value:find("shock",1,true) or value:find("more_specials",1,true) then add("STG")
        elseif value:find("high intensity",1,true) or value:find("high_intensity",1,true) or value:find("more_resistance",1,true) then add("HI")
        elseif type(label)=="string" and label~="" and not label:find("<unlocalized",1,true) then add(label) end
    end
    if seen.HI and seen.STG then results={};add=function()end;seen.HI=nil;seen.STG=nil;results[1]="HI-STG";for s in pairs(seen) do if s~="HI-STG" then results[#results+1]=s end end end
    table.sort(results);return table.concat(results," / ")
end
function H.timestamp(value)
 local text=tostring(value or "Time unavailable");text=text:gsub("(%d%d%d%d)%-(%d%d)%-(%d%d)",function(year,month,day)return day.."/"..month.."/"..year end);return text:gsub("(%d%d:%d%d):%d%d","%1")
end
function H.difficulty_short(c)
 if c.mode=="havoc"then return tonumber(c.difficulty)and "H"..tostring(c.difficulty)or "Havoc"end
 local labels={auric="Auric",damnation="Damnation",heresy="Heresy",malice="Malice",uprising="Uprising",sedition="Sedition"};return (labels[tostring(c.difficulty)]or ({"Sedition","Uprising","Malice","Heresy","Damnation"})[tonumber(c.difficulty)]or "Unknown Difficulty")..((c.maelstrom or H.parameters(c)=="Maelstrom")and " Maelstrom"or "")
end
function H.date_key(run)
 return type(run.started_at)=="string"and run.started_at:match("^(%d%d%d%d%-%d%d%-%d%d)")or nil
end
function H.date_label(key)
 local year,month,day=tostring(key):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
 return year and day.."/"..month.."/"..year or "All Dates"
end
return H
