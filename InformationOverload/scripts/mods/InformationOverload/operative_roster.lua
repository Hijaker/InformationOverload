local O={}
local mod=type(get_mod)=="function"and get_mod("information_overload")
local DisplayName=mod and mod.io_dofile and mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/display_name")or {clean=function(n)return n end}
function O.sample(tracker,players,local_unit,social)
    local m=tracker.mission;if not m then return end
    m.context.operative_roster=m.context.operative_roster or {};local roster=m.context.operative_roster
    local initial=not m.roster_initialized;local present={};local local_present=false
    for _,player in pairs(players or {}) do
        if type(player.is_human_controlled)=="function" and player:is_human_controlled() then
            local profile=type(player.profile)=="function" and player:profile()
            local id=type(player.character_id)=="function" and player:character_id() or profile and profile.character_id
            if id then
                id=tostring(id);present[id]=true
                local row=roster[id] or {late_join=not initial};roster[id]=row
                if profile then local a=profile.archetype;row.name=profile.name or row.name;row.class=type(a)=="table" and a.name or a or row.class;row.level=tonumber(profile.current_level)or row.level end
                if type(player.account_id)=="function" then local value=player:account_id();if value then row.account_id=tostring(value) end end
                if player.player_unit~=nil and player.player_unit==local_unit then local_present=true end
                if social then row.steam_id=social.steam_identity and social.steam_identity(player)or row.steam_id;row.steam_name=social.steam_name(player)or row.steam_name;row.friend_name=social.friend_name(player)or row.friend_name end
                row.personal=player.player_unit~=nil and player.player_unit==local_unit or row.personal==true;row.present=true;row.left=false
                if row.personal then row.late_join=not m.full end
            end
        end
    end
    if not local_present then return end
    for id,row in pairs(roster) do if not present[id] then
        if row.present and not row.personal then
            m.departed_players=m.departed_players or {};local person=row.account_id or id
            if not m.departed_players[person] then m.departed_players[person]=true;m.players_left=(m.players_left or 0)+1;tracker.dirty=true end
        end
        row.present=false;row.left=true
    end end
    if next(present) then m.roster_initialized=true end
end
-- you and your Steam friends go by Steam name, everyone else by character name
local function friend(row)
 if row.personal then return true end
 if row.steam_id and Friends and Friends.relationship then return Friends.relationship(tostring(row.steam_id))==Friends.FRIEND end
 return row.friend_name~=nil
end
-- ASCII spaces only, since %s can take the last byte of a character such as à for one; a name of Unicode blanks alone
-- (no-break, ideographic and other spaces, Hangul fillers, the braille blank) is no name
local function trim(s)if s==nil then return ""end;s=tostring(s):match("^[ \t\r\n\f\v]*(.-)[ \t\r\n\f\v]*$")
 local rest=s:gsub("\194\160",""):gsub("\227\128\128",""):gsub("\227\133\164",""):gsub("\226\128[\128-\143]",""):gsub("\239\187\191",""):gsub("\225\133[\159\160]",""):gsub("\239\190\160",""):gsub("\226\160\128",""):gsub("[ \t\r\n\f\v]","")
 return rest==""and ""or s end
-- the name alone; known names them by Steam name as a friend is named, as Match History's Played With does a tracked player
-- never blank: a name cleaned to nothing shows as saved, then the character name, then the class, with true so a label does not give the class twice
function O.name(row,known,R)
 local name=row.name
 if not name or known or friend(row)then name=row.friend_name or row.steam_name or name
  if row.steam_id and Friends and Friends.name then local value=Friends.name(tostring(row.steam_id));if type(value)=="string"and value~=""then name=value end end
 end
 local s=trim(DisplayName.clean(name or "Name unavailable"))
 if s==""then s=trim(name)end
 if s==""then s=trim(DisplayName.clean(row.name))end
 if s==""then s=trim(row.name)end
 if s~=""then return s end
 if not row.class then return "Name unavailable"end
 return R and R.class_name and R.class_name(row.class)or tostring(row.class),true
end
function O.label(row,R,known)local name,class=O.name(row,known,R);return name..(class and ""or " ("..R.class_name(row.class)..")")..(row.late_join and " - late-joined"or "")end
return O
