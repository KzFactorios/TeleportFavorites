


-- Dependencies must be required first, with strict order based on dependencies
local ErrorHandler = require("core.utils.error_handler")
local BasicHelpers = require("core.utils.basic_helpers")
local PlayerHelpers = require("core.utils.player_helpers")
local GuiHelpers = require("core.utils.gui_helpers")
local Enum = require("prototypes.enums.enum")
local fave_bar = require("gui.favorites_bar.fave_bar")


-- Initialize error handler first
ErrorHandler.initialize("debug") -- Set to debug mode for maximum visibility

---@class GuiEventBus
---@field _observers table<string, table[]>
---@field _notification_queue table[]
---@field _deferred_queue table[]
local GuiEventBus = {
  _observers = {}, -- Map of event_type to array of observers
  _notification_queue = {}, -- Queue of pending notifications (processed immediately)
  _deferred_queue = {}, -- Queue of deferred GUI notifications (processed on next tick)
  _initialized = false -- Track initialization state
}

--- Initialize the event bus if not already initialized
function GuiEventBus.ensure_initialized()
  local was_initialized = GuiEventBus._initialized == true
  if not was_initialized then
    GuiEventBus._observers = GuiEventBus._observers or {}
    GuiEventBus._notification_queue = GuiEventBus._notification_queue or {}
    GuiEventBus._deferred_queue = GuiEventBus._deferred_queue or {}
    GuiEventBus._initialized = true
    ErrorHandler.debug_log("GuiEventBus initialized")
  end
  return was_initialized
end

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
---@param defer_to_tick boolean|nil If true, defer processing to next tick (for GUI updates during game logic)
function GuiEventBus.notify(event_type, event_data, defer_to_tick)
  -- MULTIPLAYER FIX: Defer GUI-related notifications to next tick to prevent desyncs
  -- GUI updates must never happen during game logic events (on_chart_tag_added, etc.)
  local gui_event_types = {
    cache_updated = true,
    favorite_added = true,
    favorite_removed = true,
    favorite_updated = true,
    tag_modified = true,
    tag_created = true,
    tag_deleted = true
  }
  
  -- Auto-defer GUI events or respect explicit defer flag
  local should_defer = defer_to_tick or gui_event_types[event_type]
  
  local notification = {
    type = event_type,
    data = event_data,
    timestamp = game.tick
  }
  
  if should_defer then
    -- Queue for deferred processing on next tick
    GuiEventBus._deferred_queue = GuiEventBus._deferred_queue or {}
    table.insert(GuiEventBus._deferred_queue, notification)
    
    ErrorHandler.debug_log("[GUI_OBSERVER] *** NOTIFICATION DEFERRED TO NEXT TICK ***", {
      event_type = event_type,
      deferred_queue_size = #GuiEventBus._deferred_queue,
      current_tick = game.tick,
      will_process_on_tick = game.tick + 1
    })
  else
    -- Queue for immediate processing (non-GUI events)
    table.insert(GuiEventBus._notification_queue, notification)
    
    -- Ensure processing flag is initialized
    GuiEventBus._processing = GuiEventBus._processing or false
    
    ErrorHandler.debug_log("[NOTIFY] Queued notification for immediate processing", {
      event_type = event_type,
      queue_size = #GuiEventBus._notification_queue,
      processing_flag = GuiEventBus._processing
    })
    
    -- Process immediately if not already processing
    if not GuiEventBus._processing then
      GuiEventBus.process_notifications()
    else
      ErrorHandler.debug_log("[NOTIFY] Skipping process_notifications - already processing", {
        event_type = event_type
      })
    end
  end
end

--- Process deferred GUI notifications (called on_tick)
function GuiEventBus.process_deferred_notifications()
  -- Initialize queue if needed
  GuiEventBus._deferred_queue = GuiEventBus._deferred_queue or {}
  
  if #GuiEventBus._deferred_queue == 0 then
    return
  end
  
  -- Process all deferred notifications
  local processed_count = 0
  local error_count = 0
  
  ErrorHandler.debug_log("[DEFERRED] *** PROCESSING DEFERRED NOTIFICATIONS ***", {
    queue_size = #GuiEventBus._deferred_queue,
    current_tick = game.tick
  })
  
  while #GuiEventBus._deferred_queue > 0 do
    local notification = table.remove(GuiEventBus._deferred_queue, 1)
    local observers = GuiEventBus._observers[notification.type] or {}
    
    ErrorHandler.debug_log("[GUI_OBSERVER] *** PROCESSING DEFERRED NOTIFICATION ***", {
      event_type = notification.type,
      observer_count = #observers,
      tick = game.tick,
      all_observer_types = GuiEventBus._observers
    })
    
    for _, observer in ipairs(observers) do
      if observer and observer.update then
        ErrorHandler.debug_log("[GUI_OBSERVER] *** CALLING OBSERVER UPDATE ***", {
          observer_type = observer.observer_type,
          player = observer.player and observer.player.name or "<no player>",
          player_valid = observer.player and observer.player.valid or false
        })
        local success, err = pcall(observer.update, observer, notification.data)
        if success then
          processed_count = processed_count + 1
          ErrorHandler.debug_log("[DEFERRED] Observer update succeeded", {
            observer_type = observer.observer_type
          })
        else
          error_count = error_count + 1
          ErrorHandler.warn_log("Deferred observer update failed", {
            event_type = notification.type,
            observer_type = observer.observer_type or "unknown",
            error = err
          })
        end
      end
    end
  end
  
  if processed_count > 0 or error_count > 0 then
    ErrorHandler.debug_log("[DEFERRED] Deferred notification batch processed", {
      processed = processed_count,
      errors = error_count
    })
  end
end

--- Process queued notifications
function GuiEventBus.process_notifications()
  -- Initialize queue if needed
  GuiEventBus._notification_queue = GuiEventBus._notification_queue or {}
  
  -- CRITICAL: Set processing flag to TRUE at the start to prevent recursive calls
  -- This prevents multiple process_notifications() calls in the same tick when
  -- multiple notify() calls happen in sequence (e.g., favorite_added, tag_modified, cache_updated)
  GuiEventBus._processing = true
  
  local processed_count = 0
  local error_count = 0
  
  -- DO NOT perform any cleanup during notification processing - it can cause desyncs
  -- Cleanup must happen at deterministic times only (on_tick, on_load, etc.)
  
  -- Log start of processing
  ErrorHandler.debug_log("Starting notification processing", {
    queue_size = #GuiEventBus._notification_queue
  })
  
  while #GuiEventBus._notification_queue > 0 do
    local notification = table.remove(GuiEventBus._notification_queue, 1)
    local observers = GuiEventBus._observers[notification.type] or {}
    
    -- DO NOT clean up observers during notification processing - it uses player.connected
    -- which is client-specific and causes desyncs in multiplayer!
    -- Cleanup happens during scheduled cleanup (on_tick) which is deterministic.
    
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
      -- cleanup: match by player index OR if observer's player is invalid
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
  if not game then return 0 end -- Safety check
  
  max_age_ticks = max_age_ticks or 108000 -- 30 minutes default (reduced from 1 hour)
  local current_tick = game.tick or 0
  if current_tick == 0 then return 0 end -- Not ready for timing checks
  
  local total_cleaned = 0
  
  for event_type, observers in pairs(GuiEventBus._observers) do
    local cleaned_count = 0
    for i = #observers, 1, -1 do
      local observer = observers[i]
      -- Skip any nil observers
      if type(observer) == "table" and observer.is_valid then
        local should_remove = false
        
        -- Remove if observer is invalid
        if not observer:is_valid() then
          should_remove = true
        
        -- CRITICAL FIX: Do NOT remove permanent observers (data, favorite, notification, tag_editor)
        -- These observers should persist as long as the player is valid
        -- Only remove temporary observers based on age (if we ever add them)
        elseif observer.observer_type and 
               observer.observer_type ~= "data" and 
               observer.observer_type ~= "favorite" and
               observer.observer_type ~= "notification" and
               observer.observer_type ~= "tag_editor" and
               observer.created_tick and 
               observer.created_tick > 0 and 
               (current_tick - observer.created_tick) > max_age_ticks then
          should_remove = true
        
        -- MULTIPLAYER FIX: Removed player.connected check - it's client-specific!
        -- Only clean up observers with invalid players, not disconnected ones.
        -- Disconnected players will be cleaned up when they're removed from the game.
        end
        
        if should_remove then
          table.remove(observers, i)
          cleaned_count = cleaned_count + 1
          
          -- Log what type of observer was removed for debugging
          ErrorHandler.debug_log("Observer removed during cleanup", {
            event_type = event_type,
            observer_type = observer.observer_type or "unknown",
            reason = not observer:is_valid() and "invalid" or "age_limit",
            observer_age_ticks = observer.created_tick and (current_tick - observer.created_tick) or "unknown"
          })
        end
      end
    end
    total_cleaned = total_cleaned + cleaned_count
  end
  
  if total_cleaned > 0 then
    ErrorHandler.debug_log("Cleaned up old observers", {
      max_age_ticks = max_age_ticks,
      cleaned_count = total_cleaned,
      current_tick = current_tick
    })
  end
  
  return total_cleaned
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
  -- Ensure game exists and has valid tick counter
  if not (game and type(game.tick) == "number") then
    ErrorHandler.debug_log("Skipping periodic cleanup - invalid game state")
    return
  end

  -- Always call ensure_initialized, but don't check return value
  GuiEventBus.ensure_initialized()

  -- Use local value to avoid multiple accesses
  local current_tick = game.tick
  
  -- Schedule cleanup every 5 minutes (18000 ticks)
  local should_do_regular_cleanup = current_tick % 18000 == 0
  if should_do_regular_cleanup then
    local cleaned_count = GuiEventBus.cleanup_old_observers(108000) -- Clean up observers older than 30 minutes
    
    -- Additional aggressive cleanup every 15 minutes
    local should_do_aggressive_cleanup = current_tick % 54000 == 0
    if should_do_aggressive_cleanup then
      -- MULTIPLAYER FIX: Clean up only observers with INVALID players, not disconnected ones
      -- player.connected is client-specific and causes desyncs!
      for event_type, observers in pairs(GuiEventBus._observers) do
        local cleaned_count = 0
        for i = #observers, 1, -1 do
          local observer = observers[i]
          if observer and observer.player and not observer.player.valid then
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
  obj.created_tick = game and game.tick or 0 -- Fallback to 0 if game not ready
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
    -- Create proper localized string table
    local warning = {type = "invalid_chart_tag", text = {"tf-gui.invalid_chart_tag_warning"}}
    PlayerHelpers.safe_player_print(event_data.player, warning)
  end
end

--- Clean up all observers
function GuiEventBus.cleanup_all()
  for event_type, _ in pairs(GuiEventBus._observers) do
    GuiEventBus.cleanup_observers(event_type)
  end
  
  -- Clear notification queues
  GuiEventBus._notification_queue = {}
  GuiEventBus._deferred_queue = {}
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
  ErrorHandler.debug_log("[DATA OBSERVER] *** UPDATE CALLED ***", {
    player = self.player and self.player.name or "<no player>",
    player_valid = self:is_valid(),
    event_data_type = event_data and event_data.type or "<no type>",
    tick = game.tick
  })
  
  if not self:is_valid() then 
    ErrorHandler.debug_log("[DATA OBSERVER] Skipped - observer not valid")
    return 
  end
  
  -- Check if conditions are right for building the bar
  local player = self.player
  
  -- Use shared space platform detection logic
  if BasicHelpers.should_hide_favorites_bar_for_space_platform(player) then
    ErrorHandler.debug_log("[DATA OBSERVER] Skipped - space platform")
    return
  end
  
  -- Skip for god mode and spectator mode
  if player.controller_type == defines.controllers.god or 
     player.controller_type == defines.controllers.spectator then
    ErrorHandler.debug_log("[DATA OBSERVER] Skipped - god/spectator mode")
    return
  end
  
  ErrorHandler.debug_log("[DATA OBSERVER] Calling fave_bar.build", {
    player = player.name
  })
  
  -- Use the standard build function which has all the proper validation checks
  local success, err = pcall(function()
    fave_bar.build(player)
  end)
  
  ErrorHandler.debug_log("[DATA OBSERVER] fave_bar.build completed", {
    success = success,
    error = err or "<none>"
  })
  
  if not success then
    ErrorHandler.warn_log("[DATA OBSERVER] Failed to refresh favorites bar", {
      player = player.name,
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

  -- PERFORMANCE: Don't build GUI here - let on_player_created handle deferred build
  -- This prevents double-building (immediate + deferred) which caused 25ms spikes
  -- The favorites bar will be built via the deferred 3-tick handler in on_player_created

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
      -- Skip any nil observers
      if type(observer) == "table" and observer.player then
        local should_remove = false
        
        -- Remove if observer belongs to disconnected player
        if observer.player.index == player_index then
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
  BaseObserver = BaseGuiObserver, -- Alias for backward compatibility with tests
  FavoriteObserver = FavoriteObserver,
  DataObserver = DataObserver,
  NotificationObserver = NotificationObserver,
  process_deferred_notifications = function() return GuiEventBus.process_deferred_notifications() end
}
