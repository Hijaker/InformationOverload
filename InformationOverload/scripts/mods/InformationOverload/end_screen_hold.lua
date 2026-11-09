-- Information Overload: Keep The End Screen Up. The end screen stays until the minutes set have passed since it opened, or until Continue is
-- pressed, while the mission's server moves on without the player; dropped by it, a loading screen stays up through character select, which
-- starts the game with the character already in use, and on into the Mourningstar. At 1 minute the end screen goes when the game says.
return function(mod,on)
 local H={}
 -- the move the game wanted is held here, so a mods reload while it is held still lets it go; the game cannot ask for it again
 local P=mod:persistent_table("io_end_screen_hold")
 local KEEP={min=1,max=10,default=1}
 -- how long character select may sit behind the loading screen before it is shown after all
 local SAFETY=15
 local function minutes()local m=tonumber(mod:get("endscreen_keep_up_minutes"))or KEEP.default;return math.max(KEEP.min,math.min(KEEP.max,math.floor(m+.5)))end
 H.KEEP,H.minutes=KEEP,minutes
 local function holding()return P.pending~=nil or P.dropped~=nil end
 H.holding=holding
 local function due(now)local m=minutes();return m<=KEEP.min or now-(P.opened or now)>=60*m end
 local function game_state(name)local ok,s=pcall(require,"scripts/game_states/game/"..name);return ok and s or nil end
 local SGS
 local function let_go(p,now)
  P.pending,P.dropped,P.release,P.done=nil,nil,nil,true
  -- dropped to character select, which is skipped if it comes within the next minute and a half
  if p[1]~=nil and p[1]==game_state("state_exit_to_main_menu")then P.skip_until=now+90 end
  -- turned off while it was held, the update hook was kept on only to let this go
  if not mod:is_enabled()and SGS then pcall(mod.hook_disable,mod,SGS,"update")end
  return p[1],p[2]
 end
 mod:hook_require("scripts/game_states/game/state_game_score",function(State)
  SGS=State
  mod:hook_safe(State,"on_enter",function()for k in pairs(P)do P[k]=nil end;P.opened=os.clock()end)
  mod:hook(State,"update",function(func,self,dt,t)
   local now=os.clock()
   local go=P.release or not on()or due(now)
   -- once the game wants something after the server's move, such as the server dropping the player, that is held instead and the game not asked again
   if P.dropped then if go then return let_go(P.dropped,now)end;return nil end
   local a,b=func(self,dt,t)
   if P.pending then
    if a~=nil then P.dropped={a,b}end
    if go then return let_go(P.dropped or P.pending,now)end
    return nil
   end
   -- only the server's move on is held, never the player's own way out of the mission
   if a~=nil and a==game_state("state_mission_server_exit")and not P.done and on()and not due(now)then P.pending={a,b};return nil end
   return a,b
  end)
 end)
 -- while held, Continue by its key or a click lets it go rather than leaving the mission; cards still playing are skipped through as ever
 function H.end_view(EndView)
  mod:hook(EndView,"_trigger_current_presentation_skip",function(func,self,...)
   if holding()and self._summary_finished~=false then P.release=true;return end
   return func(self,...)
  end)
 end
 local function skipping()return P.skip_until~=nil and os.clock()<P.skip_until end
 -- character select opens none of its views and starts the game with the character already picked
 mod:hook_require("scripts/game_states/game/state_main_menu",function(Menu)
  mod:hook(Menu,"_stay_in_main_menu",function(func,self,profiles,selected)
   if not (skipping()and selected)then return func(self,profiles,selected)end
   -- once only, and the loading screen is kept over this one character select alone
   P.skip_until=nil;P.skip_state,P.skip_t,P.keep_t=self,os.clock(),os.clock()
   self:_set_profiles(profiles);self:_set_selected_profile(selected)
   local ok=pcall(self.event_continue_cb,self);if not ok then P.skip_t=-SAFETY end
  end)
  -- not started after 15 seconds, as when the backend turns the start down, character select is shown after all; a start under way keeps the loading screen
  mod:hook(Menu,"update",function(func,self,...)
   if P.skip_state==self and not P.gave_up and not self._continue and os.clock()-P.skip_t>SAFETY then
    P.gave_up=true;local c=P.loading
    if c then c._current_state_view_settings=nil;pcall(c._close_view_if_active,c,"loading_view")end
    pcall(self._set_view_state_cb,self,"main_menu");pcall(self._register_menu_events,self)
   end
   return func(self,...)
  end)
  mod:hook_safe(Menu,"on_exit",function(self)if P.skip_state==self then P.skip_state,P.loading,P.keep_t=nil,nil,nil end end)
 end)
 -- the loading screen stays up through the skipped character select while it goes on by itself
 mod:hook_require("scripts/ui/constant_elements/elements/loading/constant_element_loading",function(Loading)
  mod:hook(Loading,"_on_state_changed",function(func,self,new)
   local by=self._view_settings_by_state
   local keep=new=="StateMainMenu"and P.keep_t~=nil and os.clock()-P.keep_t<5
   if not keep or not by or by.StateMainMenu then return func(self,new)end
   local fake;for _,s in ipairs(by.StateLoading or {})do if s.view_name=="loading_view"then fake={s}end end
   if not fake then return func(self,new)end
   P.loading=self;by.StateMainMenu=fake
   local ok,err=pcall(func,self,new);by.StateMainMenu=nil
   if not ok then error(err,0)end
  end)
 end)
 -- turned off mid-hold the end screen goes at once, its update hook kept on until it has
 function H.off()if holding()and SGS then P.release=true;pcall(mod.hook_enable,mod,SGS,"update")end end
 return H
end
