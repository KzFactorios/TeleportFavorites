---@diagnostic disable: undefined-global, undefined-field

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
local fave_bar = require("gui.favorites_bar.fave_bar")
local ErrorHandler = require("core.utils.error_handler")
local gui_utils = require("core.utils.gui_utils")

---@class GuiEventBus
---@field _observers table<string, table[]>
---@field _notification_queue table[]
---@field _processing boolean
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
---@field player LuaPlayer
---@field observer_type string
---@field created_tick uint
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
  local obj = BaseGuiObserver:new(player, "favorite")
  setmetatable(obj, self)
  ---@cast obj FavoriteObserver
  return obj
end

--- Handle favorite-related events
---@param event_data table
function FavoriteObserver:update(event_data)
  if not self:is_valid() or not event_data then return end
  -- Only handle events for this player
  if event_data.player_index and event_data.player_index ~= self.player.index then
    return
  end
  -- Handle tag_collection_changed: rebuild bar if any favorite matches GPS and player is on the same surface
  if event_data.gps then
    local gps_surface = nil
    do
      -- Extract surface index from gps string (format: 'x.y.s')
      local parts = {}
      for part in string.gmatch(event_data.gps, "[^.]+") do table.insert(parts, part) end
      if #parts >= 3 then
        gps_surface = tonumber(parts[3])
      end
    end
    local player_surface = self.player and self.player.valid and self.player.surface and tonumber(self.player.surface.index) or nil
    if type(gps_surface) == "number" and type(player_surface) == "number" and gps_surface == player_surface then
      local player_faves = Cache.get_player_favorites(self.player)
      for _, fav in pairs(player_faves) do
        if fav.gps == event_data.gps then
          ErrorHandler.debug_log("FavoriteObserver: tag_collection_changed triggers bar rebuild (surface match)", {
            player = self.player.name,
            gps = event_data.gps,
            player_surface = player_surface
          })
          local success, err = pcall(function()
            fave_bar.build(self.player)
          end)
          if not success then
            ErrorHandler.warn_log("Failed to refresh favorites bar (tag_collection_changed)", {
              player = self.player.name,
              error = err
            })
          end
          return
        end
      end
    else
      ErrorHandler.debug_log("FavoriteObserver: tag_collection_changed ignored (surface mismatch)", {
        player = self.player and self.player.name or "<nil>",
        gps = event_data.gps,
        gps_surface = gps_surface,
        player_surface = player_surface
      })
    end
    return
  end
  ErrorHandler.debug_log("Favorite observer updating", {
    player = self.player.name,
    event_type = event_data.type or "unknown",
    player_index = event_data.player_index
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

--- Register observers for a player
---@param player LuaPlayer
function GuiEventBus.register_player_observers(player)
  ErrorHandler.debug_log("[GUI_OBSERVER] register_player_observers called", {
    player = player and player.name or "<nil>",
    player_index = player and player.index or "<nil>"
  })
  if not player or not player.valid then return end
  
  -- Create and register observers
  local favorite_observer = FavoriteObserver:new(player)
  
  -- Register favorite observer for all favorite-related events
  GuiEventBus.subscribe("favorite_added", favorite_observer)
  GuiEventBus.subscribe("favorite_removed", favorite_observer)
  GuiEventBus.subscribe("favorite_updated", favorite_observer)
  GuiEventBus.subscribe("favorites_reordered", favorite_observer)
  GuiEventBus.subscribe("tag_collection_changed", favorite_observer)

  -- Register data observer for cache/data refresh events (for favorites bar only)
  local data_observer = DataObserver:new(player)
  GuiEventBus.subscribe("cache_updated", data_observer)
  GuiEventBus.subscribe("data_refreshed", data_observer)

  ErrorHandler.debug_log("GUI observers registered for player", {
    player = player.name
  })

  -- After registering, trigger a single favorite_updated event to build the bar at startup
  local player_favorites = Cache.get_player_favorites(player)
  GuiEventBus.notify("favorite_updated", { player_index = player.index, favorites = player_favorites })
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

---@class DataObserver : BaseGuiObserver
local DataObserver = setmetatable({}, { __index = BaseGuiObserver })
DataObserver.__index = DataObserver

--- Create data observer
---@param player LuaPlayer
---@return DataObserver
function DataObserver:new(player)
  local obj = BaseGuiObserver:new(player, "data")
  setmetatable(obj, self)
  ---@cast obj DataObserver
  return obj
end

--- Handle data-related events (favorites bar only)
---@param event_data table
function DataObserver:update(event_data)
  if not self:is_valid() then return end
  local success, err = pcall(function()
    fave_bar.build(self.player)
  end)
  if not success then
    ErrorHandler.warn_log("DataObserver: Failed to refresh favorites bar", {
      player = self.player.name,
      error = err
    })
  end
end

return {
  GuiEventBus = GuiEventBus,
  BaseGuiObserver = BaseGuiObserver,
  FavoriteObserver = FavoriteObserver,
  DataObserver = DataObserver
}
