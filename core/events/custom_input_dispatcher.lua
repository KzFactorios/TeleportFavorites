---@diagnostic disable: undefined-global
-- custom_input_dispatcher.lua
-- Centralized dispatcher for custom input (keyboard shortcut) events in TeleportFavorites

local control_data_viewer = require("core.control.control_data_viewer")
local M = {}

--- Shared custom input event handler
default_custom_input_handlers = {
  ["dv-toggle-data-viewer"] = function(event)
    control_data_viewer.on_toggle_data_viewer(event)
  end,
  -- Add more custom input handlers here as needed
}

function M.register_custom_inputs(script, handlers)
  handlers = handlers or default_custom_input_handlers
  for input_name, handler in pairs(handlers) do
    script.on_event(input_name, handler)
  end
end

return M
