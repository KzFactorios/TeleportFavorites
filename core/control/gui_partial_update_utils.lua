-- gui_partial_update_utils.lua
-- Shared helpers for partial GUI updates (error/info/success messages)

local GuiPartialUpdateUtils = {}

--- Update an error message in a GUI panel
---@param update_fn function (player, message)
---@param player LuaPlayer
---@param message any
function GuiPartialUpdateUtils.update_error_message(update_fn, player, message)
  update_fn(player, message)
end

--- Update a state toggle in a GUI panel
---@param update_fn function (player, state)
---@param player LuaPlayer
---@param state any
function GuiPartialUpdateUtils.update_state(update_fn, player, state)
  update_fn(player, state)
end

return GuiPartialUpdateUtils
