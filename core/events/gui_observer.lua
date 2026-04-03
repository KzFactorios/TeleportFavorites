


-- Dependencies must be required first, with strict order based on dependencies
local ErrorHandler = require("core.utils.error_handler")
local BasicHelpers = require("core.utils.basic_helpers")
local PlayerHelpers = require("core.utils.player_helpers")
local GuiHelpers = require("core.utils.gui_helpers")
local Enum = require("prototypes.enums.enum")
local fave_bar = require("gui.favorites_bar.fave_bar")


--- Event types that should be deferred to next tick for multiplayer safety
local GUI_EVENT_TYPES = {
  cache_updated = true,
  favorite_added = true,
  favorite_removed = true,
  favorite_updated = true,
  tag_modified = true,
  tag_created = true,
  tag_deleted = true
}

---@class GuiEventBus
---@field _observers table<string, table[]>
---@field _notification_queue table[]
---@field _dirty_players table<number, boolean>
local GuiEventBus = {
  _observers = {}, -- Map of event_type to array of observers
  _notification_queue = {}, -- Queue of pending notifications (processed immediately)
  _dirty_players = {}, -- Set of player indices that need a GUI refresh (coalesces multiple events per tick)
  _deferred_tick_active = false, -- Whether _dirty_players has entries to flush (on_nth_tick(2) is always registered)
  _initialized = false -- Track initialization state
}

--- Initialize the event bus if not already initialized
function GuiEventBus.ensure_initialized()
  local was_initialized = GuiEventBus._initialized == true
  if not was_initialized then
    GuiEventBus._observers = GuiEventBus._observers or {}
    GuiEventBus._notification_queue = GuiEventBus._notification_queue or {}
    GuiEventBus._dirty_players = GuiEventBus._dirty_players or {}
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

  -- Dedup: skip if an observer for the same player already exists for this event type
  if observer.player_index then
    for _, existing in ipairs(GuiEventBus._observers[event_type]) do
      if existing.player_index == observer.player_index and existing.observer_type == observer.observer_type then
        ErrorHandler.debug_log("Observer subscribe skipped (duplicate)", {
          event_type = event_type,
          observer_type = observer.observer_type or "unknown",
          player_index = observer.player_index
        })
        return
      end
    end
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
  -- Auto-defer GUI events or respect explicit defer flag
  local should_defer = defer_to_tick or GUI_EVENT_TYPES[event_type]

  if should_defer then
    -- Coalesce: mark the player dirty instead of queuing individual notifications.
    -- Multiple events for the same player in the same tick (e.g. drag-drop firing
    -- favorite_added + cache_updated) collapse into a single refresh call.
    GuiEventBus._dirty_players = GuiEventBus._dirty_players or {}
    local player_index = event_data and event_data.player_index
    if player_index then
      GuiEventBus._dirty_players[player_index] = true
    else
      -- No player_index: mark all observers' players dirty (e.g. global tag events)
      for _, observers in pairs(GuiEventBus._observers) do
        for _, observer in ipairs(observers) do
          if observer.player and observer.player.valid then
            GuiEventBus._dirty_players[observer.player.index] = true
          end
        end
      end
    end
    -- Flag that dirty set has entries; on_nth_tick(2) is permanently registered
    GuiEventBus._deferred_tick_active = true
  else
    -- Immediate path for non-GUI events (invalid_chart_tag, etc.)
    local notification = { type = event_type, data = event_data, timestamp = game.tick }
    table.insert(GuiEventBus._notification_queue, notification)
    GuiEventBus._processing = GuiEventBus._processing or false
    if not GuiEventBus._processing then
      GuiEventBus.process_notifications()
    end
  end
end

--- Flush the dirty-player set: call fave_bar.refresh_slots exactly once per dirty player per tick.
--- All GUI events for a player in the same tick are coalesced into this single refresh.
function GuiEventBus.process_deferred_notifications()
  GuiEventBus._dirty_players = GuiEventBus._dirty_players or {}

  local any = false
  for _ in pairs(GuiEventBus._dirty_players) do any = true; break end
  if not any then
    GuiEventBus._deferred_tick_active = false
    return
  end

  -- Swap to a local copy and clear immediately so events fired during refresh
  -- schedule into the *next* tick rather than being lost or causing re-entry.
  local dirty = GuiEventBus._dirty_players
  GuiEventBus._dirty_players = {}
  GuiEventBus._deferred_tick_active = false

  for player_index, _ in pairs(dirty) do
    local player = game.players[player_index]
    if player and player.valid then
      local ok, err = pcall(fave_bar.refresh_slots, player)
      if not ok then
        ErrorHandler.warn_log("Deferred GUI refresh failed", {
          player_index = player_index,
          error = err
        })
      end
    end
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
  
  local error_count = 0

  -- Snapshot and clear the queue immediately so that notify() calls fired *during*
  -- observer updates write into a fresh table rather than the one we're iterating.
  -- Also eliminates the O(n²) cost of table.remove(queue, 1) shifting the array.
  local snapshot = GuiEventBus._notification_queue
  GuiEventBus._notification_queue = {}

  for i = 1, #snapshot do
    local notification = snapshot[i]
    local observers = GuiEventBus._observers[notification.type] or {}

    for _, observer in ipairs(observers) do
      if observer and observer.update then
        local success, err = pcall(observer.update, observer, notification.data)
        if not success then
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

--- Schedule regular periodic cleanup (independent of notification processing)
--- This ensures memory cleanup even during quiet periods
--- Called via on_nth_tick(108000) — runs every 30 minutes
function GuiEventBus.schedule_periodic_cleanup()
  -- Ensure game exists and has valid tick counter
  if not (game and type(game.tick) == "number") then
    return
  end

  GuiEventBus.ensure_initialized()

  -- Single pass: clean up invalid observers and empty event types
  for event_type, observers in pairs(GuiEventBus._observers) do
    for i = #observers, 1, -1 do
      local observer = observers[i]
      if not observer
        or not observer.is_valid
        or not observer:is_valid()
        or (observer.player and not observer.player.valid) then
        table.remove(observers, i)
      end
    end
    if #observers == 0 then
      GuiEventBus._observers[event_type] = nil
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
  GuiEventBus._dirty_players = {}
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
  
  -- Check if conditions are right for building the bar
  local player = self.player
  
  -- Hide on non-planet surfaces (space platforms, factory interiors, etc.)
  if not BasicHelpers.is_planet_surface(player.surface) then
    return
  end
  
  -- Skip for god mode and spectator mode
  if player.controller_type == defines.controllers.god or 
     player.controller_type == defines.controllers.spectator then
    return
  end
  
  -- PERFORMANCE: Use targeted slot refresh when bar already exists,
  -- fall back to full build only when the bar structure is missing
  local success, err = pcall(function()
    fave_bar.refresh_slots(player)
  end)
  
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
  if not player or not player.valid then return end

  -- GUI event types (cache_updated, favorite_added, etc.) are handled by the dirty-player
  -- coalescing mechanism in notify/process_deferred_notifications — they call fave_bar.refresh_slots
  -- directly, so DataObserver subscriptions for those event types are not needed.

  -- Register NotificationObserver for invalid_chart_tag events (immediate non-deferred path)
  local notification_observer = NotificationObserver:new(player)
  GuiEventBus.subscribe("invalid_chart_tag", notification_observer)

  ErrorHandler.debug_log("GUI observers registered for player (NotificationObserver)", {
    player = player.name,
  })
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
