-- Information Overload: the scoreboard's two pages and its mouse. With the key held in a mission a left click flips Combat and Support and a
-- right click brings up a cursor to hover with while walking still works; over the Esc menu and on the end screen a click on the board flips it.
return function(mod,SB,S)
 local I={}
 local REF="InformationOverloadScoreboard"
 -- the game's cursor stack takes one away for every pop, pushed or not, so I/O's push is kept in a flag that outlives a mods reload
 local P=mod:persistent_table("io_scoreboard_input")
 local function pop()if P.cursor then P.cursor=nil;local im=Managers.input;if im then pcall(im.pop_cursor,im,REF)end end end
 pop()
 local BTN={mouse_left="left",mouse_right="right"}
 local KEYS={"dashboard_key","scoreboard_key"}
 local EMPTY={}
 local st={drawn=-1,ctx=nil,was=false,mode=false,pass={},latch={},letting={},taken={},fresh={},off={},off_at=-1,vlatch=false}
 local LOCK={}
 local function button(n,f)if not Mouse then return false end;local ok,v=pcall(function()local i=Mouse.button_index(n);return i~=nil and f(i)end);return ok and v==true end
 local function down(n)return button(n,function(i)return Mouse.button(i)>.5 end)end
 local function pressed(n)return button(n,function(i)return Mouse.pressed(i)==true end)end
 local function gamepad()return InputDevice~=nil and InputDevice.gamepad_active==true end
 -- the key held past S.HOLD; a tapped-on board stays up with the weapon still the player's, so its clicks are never taken
 local function key_held()local s=SB.state;return not s.idle and s.t0~=nil and (s.mode==nil or s.mode=="hold_board"or s.mode=="hold_only")and os.clock()-s.t0>=S.HOLD end
 -- the clicks are the board's while its pages are drawn in a mission with the key held, and never while spectating, where a click is the next player
 local function active()local ui=Managers.ui;return st.ctx=="hud"and os.clock()-st.drawn<.2 and key_held()and ui~=nil and not ui._spectator_hud end
 local function busy()local ui=Managers.ui;if not ui or not ui.using_input then return false end;local ok,v=pcall(ui.using_input,ui);return ok and v==true end
 -- a board key on a mouse button keeps that button's click
 local function bound(btn)for _,id in ipairs(KEYS)do local key=mod:get(id);if type(key)=="table"and key[1]=="mouse "..btn then return true end end;return false end
 -- The game reads the weapon's clicks through the keys the UI has in use, so while the board is up its clicks go there instead: a button
 -- already down as it appears is left to the weapon until it is let go, and one the board took stays the board's until it is let go,
 -- so lifting the board mid-click never swings.
 local function locks(base)
  -- a pad's triggers share the weapon's actions with the mouse buttons, so with a pad in use the board takes nothing and a block held stays up
  local on=active()and not gamepad()
  if on and not st.was then for k,n in pairs(BTN)do st.pass[k]=down(n)end end;st.was=on
  local any=false
  for k,n in pairs(BTN)do
   -- a button the board took is still the board's on the frame it is let go, so its release never reaches the weapon either
   local d=down(n);st.letting[k]=st.latch[k]and not d or nil
   if not d then st.latch[k]=nil;st.pass[k]=nil end
   if on and not st.off[k]and not st.pass[k]and not st.latch[k]and pressed(n)then st.latch[k]=true;st.fresh[k]=true end
   st.taken[k]=st.latch[k]or st.letting[k]or on and not st.off[k]and not st.pass[k]or nil
   if st.taken[k]then any=true end
  end
  if not any then return nil end
  for k in pairs(LOCK)do LOCK[k]=nil end
  for k,v in pairs(base or EMPTY)do LOCK[k]=v end
  for k in pairs(BTN)do if st.taken[k]then LOCK[k]=true end end
  return LOCK
 end
 -- the game's own table is never written to: a copy with the board's buttons in it is handed back instead
 mod:hook("UIManager","inputs_in_use",function(func,self,...)
  local base=func(self,...)
  local ok,lock=pcall(locks,base);if ok and lock then return lock end
  return base
 end)
 -- while I/O's cursor is up the camera holds still, as it does for the emote wheel, and walking still works
 mod:hook("UIManager","emote_wheel_wants_camera_control",function(func,self,...)if P.cursor then return true end;return func(self,...)end)
 local function sync()
  local on=active()
  if st.mode and on and not gamepad()then
   if not P.cursor then local im=Managers.input;if im and pcall(im.push_cursor,im,REF)then P.cursor=true end end
  else pop();if not on then st.mode=false end end
 end
 -- the cursor in screen units, nil on a pad, which has no cursor
 local AT={}
 function I.cursor(input,k)
  if not input or gamepad()then return nil end
  local ok,c=pcall(input.get,input,"cursor");if not ok or not c then return nil end
  AT.x,AT.y=c[1]/(k or 1),c[2]/(k or 1);return AT
 end
 -- where to hover: in a mission only with I/O's cursor up, over the Esc menu and on the end screen wherever the view's own cursor is
 function I.hover(ctx,input,k,sw,sh)
  if ctx=="hud"and not P.cursor then return nil end
  local p=I.cursor(input,k);if p then p.sw,p.sh=sw,sh end;return p
 end
 -- after the paged board is drawn, ctx "hud", "esc" or "end", its box in screen units
 function I.drawn(ctx,x,y,w,h,input,k)
  local now=os.clock();st.drawn,st.ctx=now,ctx
  if now>=st.off_at then st.off_at=now+.5;st.off.mouse_left,st.off.mouse_right=bound("left"),bound("right")end
  if ctx=="hud"then
   local free=not busy()
   if st.fresh.mouse_left then st.fresh.mouse_left=nil;if free then S.flip(SB.state)end end
   if st.fresh.mouse_right then st.fresh.mouse_right=nil;if free then st.mode=not st.mode end end
   sync();return
  end
  -- a view has its own cursor and its own clicks; one on the board flips it
  st.fresh.mouse_left,st.fresh.mouse_right=nil,nil;pop();st.mode=false
  local held=down("left");local p=I.cursor(input,k)
  if held and not st.vlatch and pressed("left")and p and p.x>=x and p.x<x+w and p.y>=y and p.y<y+h then S.flip(SB.state)end
  st.vlatch=held
 end
 -- each frame: the cursor goes with the board, a pad or anything else that ends the hold
 function I.tick()if P.cursor and (not active()or gamepad())then pop();st.mode=false end end
 function I.release()pop();st.mode=false;st.fresh.mouse_left,st.fresh.mouse_right=nil,nil end
 return I
end
