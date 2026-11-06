local mod = get_mod("information_overload")
-- One-time copy of the options and keybinds DMF saved under the old mod name.
do
 local saved=Application.user_setting("mods_settings")
 local old=type(saved)=="table"and saved.personal_records
 if type(old)=="table"and saved.information_overload==nil then
  for key,value in pairs(old)do if key~="io_view_key"then mod:set(key,value)end end
  local bind,io=old.dashboard_key,old.io_view_key
  if not(type(bind)=="table"and next(bind))and type(io)=="table"and next(io)then mod:set("dashboard_key",io)end
 end
end
return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = { widgets = {
        -- Dashboard options live on Settings; keybinds and collection switches stay here.
        -- Tab out of the box; held in a mission it shows the scoreboard, and with nothing to hold the game's own Tab overlay
        { setting_id = "dashboard_key", type = "keybind", default_value = { "tab" }, keybind_trigger = "held",
            keybind_type = "function_call", function_name = "io_key" },
        -- unbound, I/O's key shows the scoreboard too
        { setting_id = "scoreboard_key", type = "keybind", default_value = {}, keybind_trigger = "held",
            keybind_type = "function_call", function_name = "io_scoreboard_key" },
        { setting_id = "disable_psykhanium_tracking", type = "checkbox", default_value = false },
    } },
}
