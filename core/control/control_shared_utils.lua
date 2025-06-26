-- control_shared_utils.lua
-- Shared helpers for control modules: refresh, update, observer notification, and common utilities

local GuiObserver = require("core.pattern.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus
local GameHelpers = require("core.utils.game_helpers")

local SharedUtils = {}

--- Count the number of elements in a table
---@param t table
---@return number
function SharedUtils.table_size(t)
  if type(t) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

--- Localized string helper
---@param key string
---@param ... any
---@return table
function SharedUtils.lstr(key, ...)
  return { key, ... }
end

--- Standardized GUI refresh pattern
---@param cache_setter function
---@param gui_destroyer function
---@param gui_builder function
---@param ... any
function SharedUtils.refresh_gui(cache_setter, gui_destroyer, gui_builder, ...)
  cache_setter(...)
  gui_destroyer(...)
  gui_builder(...)
end

--- Standardized GUI refresh with cache update
---@param cache_setter function
---@param destroyer function
---@param builder function
---@param ... any
function SharedUtils.refresh_gui_with_cache(cache_setter, destroyer, builder, ...)
  cache_setter(...)
  destroyer(...)
  builder(...)
end

--- Standardized observer notification
---@param event_name string
---@param data table
function SharedUtils.notify_observer(event_name, data)
  GuiEventBus.notify(event_name, data)
end

--- Standardized error display
---@param player LuaPlayer
---@param message any
function SharedUtils.display_error(player, message)
  GameHelpers.player_print(player, message)
end

return SharedUtils
