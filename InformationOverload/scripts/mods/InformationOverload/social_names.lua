local S={}
local clock=0
local cache=setmetatable({},{__mode="k"})
function S.update_clock(t)clock=t end
local function entry(player)
 local e=cache[player]
 if not e or clock>=e.expires then e={expires=clock+1};cache[player]=e end
 return e
end
local function info_for(player,e)
 if e.looked_up then return e.info end
 e.looked_up=true
 local social=Managers.data_service and Managers.data_service.social
 local lookup=social and (social.get_player_info_for_player or social._get_player_info_for_player)
 if lookup and type(player.account_id)=="function"then e.info=lookup(social,player)end
 return e.info
end
function S.steam_name(player)
 local e=entry(player);if e.named then return e.name end;e.named=true
 local info=info_for(player,e)
 if not info or not info.platform or info:platform()~="steam"or not Friends or not Friends.name then return end
 local id=info.platform_user_id and info:platform_user_id();local name=id and Friends.name(id)
 if type(name)=="string"and name~=""then e.name=name end;return e.name
end
function S.steam_identity(player)
 local e=entry(player);local info=info_for(player,e)
 if info and info.platform and info:platform()=="steam"then local id=info:platform_user_id();if id then return tostring(id),S.steam_name(player)end end
end
function S.friend_name(player)
 local e=entry(player);if e.friend_checked then return e.friend_name end;e.friend_checked=true
 local info=info_for(player,e)
 if not info or not info.platform or info:platform()~="steam"or not Friends then return end
 local id=info.platform_user_id and info:platform_user_id();local relationship=id and Friends.relationship and Friends.relationship(id)
 if relationship==Friends.FRIEND then e.friend_name=S.steam_name(player)end;return e.friend_name
end
return S
