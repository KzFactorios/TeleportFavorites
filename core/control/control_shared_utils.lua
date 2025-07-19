-- core/control/control_shared_utils.lua
-- TeleportFavorites Factorio Mod
-- Provides shared helpers for control modules, including refresh, update, observer notification, and common GUI/event utilities.

local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local SharedUtils = {}

--- Localized string helper
---@param key string
---@param ... any
---@return table
function SharedUtils.lstr(key, ...)
  return { key, ... }
end

--- Standardized observer notification
---@param event_name string
---@param data table
function SharedUtils.notify_observer(event_name, data)
  GuiEventBus.notify(event_name, data)
end

return SharedUtils
