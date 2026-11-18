-- The social menu cancels its own fetches when it closes or changes tab while friends are loading, and the game then hands that cancelled
-- fetch back for the rest of the session, every tab staying empty; a cancelled one is marked changed, so the next call starts a fresh one
return function(mod)
 local FETCHES={
  fetch_friends={"_friends_list_promise","_friends_list_has_changed"},
  _fetch_fatshark_friends={"_fatshark_friends_promise","_friends_list_has_changed"},
  fetch_friend_invites={"_friend_invites_promise","_friend_invites_has_changed"},
  fetch_blocked_accounts={"_blocked_accounts_list_promise","_blocked_accounts_list_changed"},
  fetch_recent_companions={"_recent_companions_promise","_recent_companions_has_changed"},
 }
 for name,fields in pairs(FETCHES)do
  local promise_field,changed_field=fields[1],fields[2]
  mod:hook("SocialService",name,function(func,self,...)
   local promise=self[promise_field]
   if promise and promise.is_canceled and promise:is_canceled()then self[changed_field]=true end
   return func(self,...)
  end)
 end
end
