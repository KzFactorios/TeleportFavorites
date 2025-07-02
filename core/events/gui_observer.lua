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
local GuiHelpers = require("core.utils.gui_helpers")
local Enum = require("prototypes.enums.enum")
local GameHelpers = require("core.utils.game_helpers")

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
  
  -- Run periodic cleanup every 100 notifications or every 10 minutes
  local should_cleanup = (#GuiEventBus._notification_queue > 0 and 
                         (#GuiEventBus._notification_queue % 100 == 0 or 
                          game.tick % 36000 == 0)) -- 10 minutes
  
  if should_cleanup then
    GuiEventBus.periodic_cleanup()
  end
  
  while #GuiEventBus._notification_queue > 0 do
    local notification = table.remove(GuiEventBus._notification_queue, 1)
    local observers = GuiEventBus._observers[notification.type] or {}
    
    -- Clean up invalid observers for this specific event type
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

--- Clean up observers for a specific player (more targeted than cleanup_all)
---@param player LuaPlayer|nil The player whose observers should be cleaned up
function GuiEventBus.cleanup_player_observers(player)
  if not player then return end
  
  local player_index = player.index
  local player_name = player.name
  local total_cleaned = 0
  
  for event_type, observers in pairs(GuiEventBus._observers) do
    local cleaned_count = 0
    for i = #observers, 1, -1 do
      local observer = observers[i]
      -- Enhanced cleanup: match by player index OR if observer's player is invalid
      if observer and (
        (observer.player and observer.player.index == player_index) or
        (observer.player and not observer.player.valid) or
        not observer:is_valid()
      ) then
        table.remove(observers, i)
        cleaned_count = cleaned_count + 1
      end
    end
    total_cleaned = total_cleaned + cleaned_count
  end
  
  if total_cleaned > 0 then
    ErrorHandler.debug_log("Cleaned up player-specific observers", {
      player = player_name,
      player_index = player_index,
      cleaned_count = total_cleaned
    })
  end
end

--- Aggressive cleanup: Remove observers older than specified ticks
---@param max_age_ticks number Maximum age in ticks before cleanup (default: 30 minutes = 108000 ticks)
function GuiEventBus.cleanup_old_observers(max_age_ticks)
  max_age_ticks = max_age_ticks or 108000 -- 30 minutes default (reduced from 1 hour)
  local current_tick = game.tick
  local total_cleaned = 0
  
  for event_type, observers in pairs(GuiEventBus._observers) do
    local cleaned_count = 0
    for i = #observers, 1, -1 do
      local observer = observers[i]
      if observer then
        local should_remove = false
        
        -- Remove if observer is invalid
        if not observer:is_valid() then
          should_remove = true
        
        -- Remove if observer is too old
        elseif observer.created_tick and (current_tick - observer.created_tick) > max_age_ticks then
          should_remove = true
        
        -- Remove if observer's player is disconnected and observer is older than 5 minutes
        elseif observer.player and not observer.player.connected and 
               observer.created_tick and (current_tick - observer.created_tick) > 18000 then -- 5 minutes
          should_remove = true
        end
        
        if should_remove then
          table.remove(observers, i)
          cleaned_count = cleaned_count + 1
        end
      end
    end
    total_cleaned = total_cleaned + cleaned_count
  end
  
  if total_cleaned > 0 then
    ErrorHandler.debug_log("Cleaned up old observers", {
      max_age_ticks = max_age_ticks,
      cleaned_count = total_cleaned
    })
  end
end

--- Periodic cleanup that runs during notification processing
function GuiEventBus.periodic_cleanup()
  -- Clean up invalid observers more frequently
  for event_type in pairs(GuiEventBus._observers) do
    GuiEventBus.cleanup_observers(event_type)
  end
  
  -- Clean up old observers more aggressively (1+ hours)
  GuiEventBus.cleanup_old_observers(216000) -- 1 hour
  
  -- Clear excessive notification queue if it gets too large
  if #GuiEventBus._notification_queue > 100 then
    ErrorHandler.warn_log("Notification queue too large, clearing old notifications", {
      queue_size = #GuiEventBus._notification_queue
    })
    -- Keep only the most recent 50 notifications
    local recent_notifications = {}
    for i = math.max(1, #GuiEventBus._notification_queue - 49), #GuiEventBus._notification_queue do
      table.insert(recent_notifications, GuiEventBus._notification_queue[i])
    end
    GuiEventBus._notification_queue = recent_notifications
  end
  
  -- Additional memory optimization: remove empty observer arrays
  for event_type, observers in pairs(GuiEventBus._observers) do
    if #observers == 0 then
      GuiEventBus._observers[event_type] = nil
    end
  end
end

--- Schedule regular periodic cleanup (independent of notification processing)
--- This ensures memory cleanup even during quiet periods
function GuiEventBus.schedule_periodic_cleanup()
  local current_tick = game.tick
  
  -- Schedule cleanup every 5 minutes (18000 ticks)
  if current_tick % 18000 == 0 then
    GuiEventBus.cleanup_old_observers(108000) -- Clean up observers older than 30 minutes
    
    -- Additional aggressive cleanup every 15 minutes
    if current_tick % 54000 == 0 then
      -- Clean up any observers with invalid/disconnected players
      for event_type, observers in pairs(GuiEventBus._observers) do
        local cleaned_count = 0
        for i = #observers, 1, -1 do
          local observer = observers[i]
          if observer and observer.player and (not observer.player.valid or not observer.player.connected) then
            table.remove(observers, i)
            cleaned_count = cleaned_count + 1
          end
        end
        if cleaned_count > 0 then
          ErrorHandler.debug_log("Scheduled cleanup removed disconnected observers", {
            event_type = event_type,
            cleaned_count = cleaned_count
          })
        end
      end
    end
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
  ErrorHandler.debug_log("[FAVORITE OBSERVER] update called", {
    class = "FavoriteObserver",
    method = "update",
    player = self.player and self.player.name or "<nil>",
    event_type = event_data and event_data.type or "<nil>",
    player_index = event_data and event_data.player_index or "<nil>"
  })
  if not self:is_valid() or not event_data then return end
  -- Only handle events for this player
  if event_data.player_index and event_data.player_index ~= self.player.index then
    return
  end
  -- Only handle non-favorites-bar events here (e.g., for other GUIs if needed)
  -- Do not call fave_bar.build here for tag_collection_changed or cache_updated
end

---@class NotificationObserver : BaseGuiObserver
local NotificationObserver = setmetatable({}, { __index = BaseGuiObserver })
NotificationObserver.__index = NotificationObserver

--- Create notification observer
---@param player LuaPlayer
---@return NotificationObserver
function NotificationObserver:new(player)
  local obj = BaseGuiObserver:new(player, "notification")
  setmetatable(obj, self)
  ---@cast obj NotificationObserver
  return obj
end

--- Handle invalid chart tag notification events
---@param event_data table
function NotificationObserver:update(event_data)
  if not self:is_valid() or not event_data then return end
  if event_data.player and event_data.player.valid then
    GameHelpers.player_print(event_data.player, {"tf-gui.invalid_chart_tag_warning"})
  end
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
  local debug_context = {
    class = "DataObserver",
    method = "update",
    player = self.player.name,
    event_type = event_data and event_data.type or "unknown",
    event_data = event_data
    -- stacktrace removed for log clarity
  }
  ErrorHandler.debug_log("[DATA OBSERVER] ===> (cache/data event)", debug_context)
  local success, err = pcall(function()
    fave_bar.build(self.player)
    -- Force update labels after favorites bar is built
    local FaveBarGuiLabelsManager = require("core.control.fave_bar_gui_labels_manager")
    FaveBarGuiLabelsManager.force_update_labels_for_player(self.player)
  end)
  if not success then
    ErrorHandler.warn_log("[DATA OBSERVER] ===> Failed to refresh favorites bar", debug_context)
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

  -- Only register DataObserver for cache_updated events (favorites bar only)
  local data_observer = DataObserver:new(player)
  GuiEventBus.subscribe("cache_updated", data_observer)

  -- Also register DataObserver for favorite events to ensure favorites bar updates
  GuiEventBus.subscribe("favorite_added", data_observer)
  GuiEventBus.subscribe("favorite_removed", data_observer)
  GuiEventBus.subscribe("favorite_updated", data_observer)

  ErrorHandler.debug_log("GUI observers registered for player (DataObserver)", {
    player = player.name,
    events = {"cache_updated", "favorite_added", "favorite_removed", "favorite_updated"}
  })

  -- Ensure the favorites bar is visible on startup (only if not already present)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if not (bar_frame and bar_frame.valid) then
    fave_bar.build(player)
  end

  -- Register NotificationObserver for invalid_chart_tag events
  local notification_observer = NotificationObserver:new(player)
  GuiEventBus.subscribe("invalid_chart_tag", notification_observer)
end

--- Clean up observers for a disconnected player (more aggressive than player leave)
---@param player_index uint The index of the disconnected player
function GuiEventBus.cleanup_disconnected_player_observers(player_index)
  if not player_index then return end
  
  local total_cleaned = 0
  
  for event_type, observers in pairs(GuiEventBus._observers) do
    local cleaned_count = 0
    for i = #observers, 1, -1 do
      local observer = observers[i]
      if observer then
        local should_remove = false
        
        -- Remove if observer belongs to disconnected player
        if observer.player and observer.player.index == player_index then
          should_remove = true
        
        -- Remove if observer's player is invalid/nil
        elseif not observer.player or not observer.player.valid then
          should_remove = true
        
        -- Remove if observer itself is invalid
        elseif not observer:is_valid() then
          should_remove = true
        end
        
        if should_remove then
          table.remove(observers, i)
          cleaned_count = cleaned_count + 1
        end
      end
    end
    total_cleaned = total_cleaned + cleaned_count
  end
  
  if total_cleaned > 0 then
    ErrorHandler.debug_log("Cleaned up disconnected player observers", {
      player_index = player_index,
      cleaned_count = total_cleaned
    })
  end
end

return {
  GuiEventBus = GuiEventBus,
  BaseGuiObserver = BaseGuiObserver,
  FavoriteObserver = FavoriteObserver,
  DataObserver = DataObserver,
  NotificationObserver = NotificationObserver
}
