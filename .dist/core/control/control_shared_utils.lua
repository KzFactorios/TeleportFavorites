local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local SharedUtils = {}

---@param key string
---@param ... any
---@return table
function SharedUtils.lstr(key, ...)
  return { key, ... }
end

---@param event_name string
---@param data table
function SharedUtils.notify_observer(event_name, data)
  GuiEventBus.notify(event_name, data)
end

return SharedUtils
