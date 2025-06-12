---@diagnostic disable: undefined-global, undefined-field, missing-fields, need-check-nil, param-type-mismatch
--[[
custom_input_dispatcher.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized dispatcher for custom input (keyboard shortcut) events.

Features:
---------
- Safe handler registration with comprehensive validation
- Error handling and recovery for individual handlers
- Proper logging for debugging and monitoring
- Extensible pattern for adding new custom inputs
- No global namespace pollution

Usage:
------
-- Register default handlers
CustomInputDispatcher.register_default_inputs(script)

-- Register custom handlers
CustomInputDispatcher.register_custom_inputs(script, {
  ["my-custom-input"] = function(event) ... end
})

Handler Signature:
------------------
All handlers receive a Factorio event object:
function handler(event)
  -- event.player_index: uint - Player who triggered the input
  -- event.input_name: string - Name of the custom input
  -- event.cursor_position: MapPosition - Cursor position when triggered
end
--]]

---@class CustomInputDispatcher
local M = {}

-- Private helper functions

--- Create a safe wrapper for handler functions with error handling
---@param handler function The handler function to wrap
---@param handler_name string Name for logging purposes
---@return function Safe wrapper function
local function create_safe_handler(handler, handler_name)  return function(event)
    local success, err = pcall(handler, event)
    if not success then
      log("[TeleportFavorites] Error in custom input handler '" .. handler_name .. "': " .. tostring(err))
      -- Could also show player message for user-facing errors
      if event.player_index then
        ---@diagnostic disable-next-line: undefined-field
        local player = game.get_player(event.player_index)
        ---@diagnostic disable-next-line: need-check-nil
        if player and player.valid then
          ---@diagnostic disable-next-line: param-type-mismatch
          player.print({"tf-error.input_handler_error"})
        end
      end
    end
  end
end

--- Create a lazy-loaded handler that requires modules on demand
---@param module_path string Path to the module to require
---@param method_name string Name of the method to call
---@return function Lazy-loaded handler function
local function create_lazy_handler(module_path, method_name)
  return function(event)
    local success, module = pcall(require, module_path)
    if not success then
      log("[TeleportFavorites] Failed to load module '" .. module_path .. "': " .. tostring(module))
      return
    end
    
    if type(module[method_name]) ~= "function" then
      log("[TeleportFavorites] Method '" .. method_name .. "' not found in module '" .. module_path .. "'")
      return
    end
    
    local handler_success, err = pcall(module[method_name], event)
    if not handler_success then
      log("[TeleportFavorites] Error in handler " .. module_path .. "." .. method_name .. ": " .. tostring(err))
    end
  end
end

-- Default custom input handlers (private to avoid global pollution)
---@type table<string, function>
local default_custom_input_handlers = {
  ["dv-toggle-data-viewer"] = create_lazy_handler("core.control.control_data_viewer", "on_toggle_data_viewer"),
  ["tf-undo-last-action"] = function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Use the GUI handler's undo function
    local on_gui_closed_handler = require("core.events.on_gui_closed_handler")
    local success = on_gui_closed_handler.undo_last_gui_close(player)
    
    if success then
      player.print({"tf-command.action_undone"})
    else
      player.print({"tf-command.nothing_to_undo"})
    end
  end,
  -- Add more custom input handlers here as needed
}

-- Public API

--- Register custom input handlers with comprehensive validation
---@param script table The Factorio script object
---@param handlers table<string, function> Table mapping input names to handler functions
---@return boolean success Whether registration completed successfully
function M.register_custom_inputs(script, handlers)
  -- Validate script object
  if not script or type(script.on_event) ~= "function" then
    error("[TeleportFavorites] Invalid script object provided to register_custom_inputs")
  end
  
  -- Validate handlers table
  if not handlers or type(handlers) ~= "table" then
    error("[TeleportFavorites] Handlers must be a table")
  end
  
  local registration_count = 0
  local error_count = 0
  
  -- Register each handler with validation
  for input_name, handler in pairs(handlers) do
    if type(input_name) ~= "string" or input_name == "" then
      log("[TeleportFavorites] Invalid input name: " .. tostring(input_name))
      error_count = error_count + 1
    elseif type(handler) ~= "function" then
      log("[TeleportFavorites] Handler for '" .. input_name .. "' must be a function, got " .. type(handler))
      error_count = error_count + 1
    else
      -- Wrap handler in safety wrapper and register
      local safe_handler = create_safe_handler(handler, input_name)
      local success, err = pcall(function()
        script.on_event(input_name, safe_handler)
      end)
      
      if success then
        registration_count = registration_count + 1
        log("[TeleportFavorites] Registered custom input: " .. input_name)
      else
        log("[TeleportFavorites] Failed to register custom input '" .. input_name .. "': " .. tostring(err))
        error_count = error_count + 1
      end
    end
  end
  
  log("[TeleportFavorites] Custom input registration complete: " .. registration_count .. " registered, " .. error_count .. " errors")
  return error_count == 0
end

--- Register the default TeleportFavorites custom input handlers
---@param script table The Factorio script object
---@return boolean success Whether registration completed successfully
function M.register_default_inputs(script)
  log("[TeleportFavorites] Registering default custom inputs...")
  return M.register_custom_inputs(script, default_custom_input_handlers)
end

--- Get a copy of the default handlers (for testing or extension)
---@return table<string, function> Copy of default handlers
function M.get_default_handlers()
  local copy = {}
  for name, handler in pairs(default_custom_input_handlers) do
    copy[name] = handler
  end
  return copy
end

--- Add a new handler to the default set (for dynamic registration)
---@param input_name string Name of the custom input
---@param handler function Handler function
---@return boolean success Whether the handler was added successfully
function M.add_default_handler(input_name, handler)
  if type(input_name) ~= "string" or input_name == "" then
    log("[TeleportFavorites] Invalid input name for add_default_handler: " .. tostring(input_name))
    return false
  end
  
  if type(handler) ~= "function" then
    log("[TeleportFavorites] Handler for add_default_handler must be a function, got " .. type(handler))
    return false
  end
  
  default_custom_input_handlers[input_name] = handler
  log("[TeleportFavorites] Added default handler for: " .. input_name)
  return true
end

return M
