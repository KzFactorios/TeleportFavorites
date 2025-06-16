---@diagnostic disable: undefined-global

--[[
gui_observer.lua
TeleportFavorites Factorio Mod
-----------------------------
Observer pattern implementation for GUI state management and updates.

Features:
---------
- Decoupled GUI updates from business logic changes
- Event-driven architecture for state synchronization
- Multiple observer types for different GUI concerns
- Automatic cleanup of invalid observers
- Performance-optimized notification batching
- Type-safe event handling with validation

Observer Types:
---------------
- FavoriteObserver: Responds to favorite add/remove/update events
- TagObserver: Handles tag creation/modification/deletion
- TeleportObserver: Manages teleportation-related GUI updates
- DataObserver: Updates data viewer when cache changes
- ValidationObserver: Handles real-time validation feedback

Event Types:
------------
- favorite_added, favorite_removed, favorite_updated
- tag_created, tag_modified, tag_deleted
- player_teleported, teleport_failed
- cache_updated, data_refreshed
- validation_error, validation_success

Usage:
------
-- Register observer for favorite changes
local observer = FavoriteObserver:new(player)
GuiEventBus:subscribe("favorite_added", observer)

-- Notify all observers of favorite addition
GuiEventBus:notify("favorite_added", {
  player = player,
  gps = gps,
  favorite = favorite_obj
})
--]]

local Cache = require("core.cache.cache")
local control_data_viewer = require("core.control.control_data_viewer")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local gui_utils = require("core.utils.gui_utils")

---@class GuiEventBus
local GuiEventBus = {}
GuiEventBus._observers = {}
GuiEventBus._notification_queue = {}
GuiEventBus._processing = false

--- Subscribe observer to event type
---@param event_type string
---@param observer table Observer with update method
function GuiEventBus.subscribe(event_type, observer)
  if not GuiEventBus._observers[event_type] then
    GuiEventBus._observers[event_type] = {}
  end
  
  table.insert(GuiEventBus._observers[event_type], observer)
  
  ErrorHandler.debug_log("Observer subscribed", {
    event_type = event_type,
    observer_type = observer.observer_type or "unknown"
  })
end

--- Unsubscribe observer from event type
---@param event_type string
---@param observer table
function GuiEventBus.unsubscribe(event_type, observer)
  local observers = GuiEventBus._observers[event_type]
  if not observers then return end
  
  for i, obs in ipairs(observers) do
    if obs == observer then
      table.remove(observers, i)
      ErrorHandler.debug_log("Observer unsubscribed", {
        event_type = event_type,
        observer_type = observer.observer_type or "unknown"
      })
      break
    end
  end
end

--- Notify all observers of an event
---@param event_type string
---@param event_data table
function GuiEventBus.notify(event_type, event_data)
  -- Queue notification for batch processing
  table.insert(GuiEventBus._notification_queue, {
    type = event_type,
    data = event_data,
    timestamp = game.tick
  })
  
  -- Process immediately if not already processing
  if not GuiEventBus._processing then
    GuiEventBus.process_notifications()
  end
end

--- Process queued notifications
function GuiEventBus.process_notifications()
  if GuiEventBus._processing then return end
  GuiEventBus._processing = true
  
  local processed_count = 0
  local error_count = 0
  
  while #GuiEventBus._notification_queue > 0 do
    local notification = table.remove(GuiEventBus._notification_queue, 1)
    local observers = GuiEventBus._observers[notification.type] or {}
    
    -- Clean up invalid observers
    GuiEventBus.cleanup_observers(notification.type)
    
    for _, observer in ipairs(observers) do
      if observer and observer.update then
        local success, err = pcall(observer.update, observer, notification.data)
        if success then
          processed_count = processed_count + 1
        else
          error_count = error_count + 1
          ErrorHandler.warn_log("Observer update failed", {
            event_type = notification.type,
            observer_type = observer.observer_type or "unknown",
            error = err
          })
        end
      end
    end
  end
  
  GuiEventBus._processing = false
  
  if processed_count > 0 or error_count > 0 then
    ErrorHandler.debug_log("Notification batch processed", {
      processed = processed_count,
      errors = error_count
    })
  end
end

--- Remove invalid observers for event type
---@param event_type string
function GuiEventBus.cleanup_observers(event_type)
  local observers = GuiEventBus._observers[event_type]
  if not observers then return end
  
  local cleaned_count = 0
  for i = #observers, 1, -1 do
    local observer = observers[i]
    if not observer or not observer.is_valid or not observer:is_valid() then
      table.remove(observers, i)
      cleaned_count = cleaned_count + 1
    end
  end
  
  if cleaned_count > 0 then
    ErrorHandler.debug_log("Cleaned up invalid observers", {
      event_type = event_type,
      cleaned_count = cleaned_count
    })
  end
end

---@class BaseGuiObserver
local BaseGuiObserver = {}
BaseGuiObserver.__index = BaseGuiObserver

--- Create base observer
---@param player LuaPlayer
---@param observer_type string
---@return BaseGuiObserver
function BaseGuiObserver:new(player, observer_type)
  local obj = setmetatable({}, self)
  obj.player = player
  obj.observer_type = observer_type or "base"
  obj.created_tick = game.tick
  return obj
end

--- Check if observer is still valid
---@return boolean valid
function BaseGuiObserver:is_valid()
  return self.player and self.player.valid
end

--- Update method to be overridden by subclasses
---@param event_data table
function BaseGuiObserver:update(event_data)
  ErrorHandler.debug_log("Base observer update called", {
    observer_type = self.observer_type,
    event_data = event_data
  })
end

---@class FavoriteObserver : BaseGuiObserver
local FavoriteObserver = setmetatable({}, { __index = BaseGuiObserver })
FavoriteObserver.__index = FavoriteObserver

--- Create favorite observer
---@param player LuaPlayer
---@return FavoriteObserver
function FavoriteObserver:new(player)
  local obj = BaseGuiObserver.new(self, player, "favorite")
  setmetatable(obj, self)
  return obj
end

--- Handle favorite-related events
---@param event_data table
function FavoriteObserver:update(event_data)
  if not self:is_valid() or not event_data then return end
  
  -- Only handle events for this player
  if event_data.player and event_data.player.index ~= self.player.index then
    return
  end
  
  ErrorHandler.debug_log("Favorite observer updating", {
    player = self.player.name,
    event_type = event_data.type or "unknown"
  })
  -- Refresh favorites bar
  local success, err = pcall(function()
    fave_bar.build(self.player)
  end)
  
  if not success then
    ErrorHandler.warn_log("Failed to refresh favorites bar", {
      player = self.player.name,
      error = err
    })
  end
end

---@class TagObserver : BaseGuiObserver
local TagObserver = setmetatable({}, { __index = BaseGuiObserver })
TagObserver.__index = TagObserver

--- Create tag observer
---@param player LuaPlayer
---@return TagObserver
function TagObserver:new(player)
  local obj = BaseGuiObserver:new(player, "tag")
  setmetatable(obj, self)
  return obj
end

--- Handle tag-related events
---@param event_data table
function TagObserver:update(event_data)
  if not self:is_valid() or not event_data then return end
  
  ErrorHandler.debug_log("Tag observer updating", {
    player = self.player.name,
    event_type = event_data.type or "unknown",
    gps = event_data.gps
  })
    -- Refresh tag editor if it's open
  local tag_editor_frame = gui_utils.find_child_by_name(
    self.player.gui.screen, 
    Enum.GuiEnum.GUI_FRAME.TAG_EDITOR
  )
  
  if tag_editor_frame and tag_editor_frame.valid then
    local success, err = pcall(function()
      -- Get current tag data and refresh
      local tag_data = Cache.get_tag_editor_data(self.player)
      if tag_data and tag_data.gps == event_data.gps then
        tag_editor.build(self.player)
      end
    end)
    
    if not success then
      ErrorHandler.warn_log("Failed to refresh tag editor", {
        player = self.player.name,
        error = err
      })
    end
  end
end

---@class DataObserver : BaseGuiObserver
local DataObserver = setmetatable({}, { __index = BaseGuiObserver })
DataObserver.__index = DataObserver

--- Create data observer
---@param player LuaPlayer
---@return DataObserver
function DataObserver:new(player)
  local obj = BaseGuiObserver:new(player, "data")
  setmetatable(obj, self)
  return obj
end

--- Handle data-related events
---@param event_data table
function DataObserver:update(event_data)
  if not self:is_valid() or not event_data then return end
  
  -- Only handle events for this player
  if event_data.player and event_data.player.index ~= self.player.index then
    return
  end
  
  ErrorHandler.debug_log("Data observer updating", {
    player = self.player.name,
    event_type = event_data.type or "unknown"
  })
    -- Refresh data viewer if it's open
  local main_flow = gui_utils.get_or_create_gui_flow_from_gui_top(self.player)
  
  local data_viewer_frame = gui_utils.find_child_by_name(main_flow, "data_viewer_frame")
  if data_viewer_frame and data_viewer_frame.valid then
    local success, err = pcall(function()
      local pdata = Cache.get_player_data(self.player)
      local active_tab = pdata.data_viewer_settings and pdata.data_viewer_settings.active_tab or "player_data"
      local font_size = pdata.data_viewer_settings and pdata.data_viewer_settings.font_size or 12
      
      -- Use internal rebuild function
      if control_data_viewer.rebuild_data_viewer then
        control_data_viewer.rebuild_data_viewer(self.player, main_flow, active_tab, font_size, true)
      end
    end)
    
    if not success then
      ErrorHandler.warn_log("Failed to refresh data viewer", {
        player = self.player.name,
        error = err
      })
    end
  end
end

--- Register observers for a player
---@param player LuaPlayer
function GuiEventBus.register_player_observers(player)
  if not player or not player.valid then return end
  
  -- Create and register observers
  local favorite_observer = FavoriteObserver:new(player)
  local tag_observer = TagObserver:new(player)
  local data_observer = DataObserver:new(player)
  
  -- Subscribe to relevant events
  GuiEventBus.subscribe("favorite_added", favorite_observer)
  GuiEventBus.subscribe("favorite_removed", favorite_observer)
  GuiEventBus.subscribe("favorite_updated", favorite_observer)
  GuiEventBus.subscribe("favorites_reordered", favorite_observer)
  
  GuiEventBus.subscribe("tag_created", tag_observer)
  GuiEventBus.subscribe("tag_modified", tag_observer)
  GuiEventBus.subscribe("tag_deleted", tag_observer)
  
  GuiEventBus.subscribe("cache_updated", data_observer)
  GuiEventBus.subscribe("data_refreshed", data_observer)
  
  ErrorHandler.debug_log("GUI observers registered for player", {
    player = player.name
  })
end

--- Clean up all observers
function GuiEventBus.cleanup_all()
  for event_type, _ in pairs(GuiEventBus._observers) do
    GuiEventBus.cleanup_observers(event_type)
  end
  
  -- Clear notification queue
  GuiEventBus._notification_queue = {}
  GuiEventBus._processing = false
  
  ErrorHandler.debug_log("All GUI observers cleaned up")
end

return {
  GuiEventBus = GuiEventBus,
  BaseGuiObserver = BaseGuiObserver,
  FavoriteObserver = FavoriteObserver,
  TagObserver = TagObserver,
  DataObserver = DataObserver
}
