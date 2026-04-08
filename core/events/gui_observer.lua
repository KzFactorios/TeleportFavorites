


-- Dependencies must be required first, with strict order based on dependencies
local Deps = require("deps")
local BasicHelpers, ErrorHandler =
  Deps.BasicHelpers, Deps.ErrorHandler
local PlayerHelpers = require("core.utils.player_helpers")
local GuiHelpers = require("core.utils.gui_helpers")
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
---@field _deferred_queue table[]
local GuiEventBus = {
  _observers = {}, -- Map of event_type to array of observers
  _notification_queue = {}, -- Queue of pending notifications (processed immediately)
  _deferred_queue = {}, -- Queue of deferred GUI notifications (processed on next tick)
  _deferred_tick_active = false, -- Whether deferred queue has items to process (on_nth_tick(2) is always registered)
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
  
  local notification = {
    type = event_type,
    data = event_data,
    timestamp = game.tick
  }
  
  if should_defer then
    -- Queue for deferred processing on next tick
    GuiEventBus._deferred_queue = GuiEventBus._deferred_queue or {}
    table.insert(GuiEventBus._deferred_queue, notification)
    
    -- Flag that deferred queue has items to process
    -- on_nth_tick(2) is permanently registered at load time; it checks this flag to no-op when idle
    GuiEventBus._deferred_tick_active = true
  else
    -- Queue for immediate processing (non-GUI events)
    table.insert(GuiEventBus._notification_queue, notification)
    
    -- Ensure processing flag is initialized
    GuiEventBus._processing = GuiEventBus._processing or false
    
    -- Process immediately if not already processing
    if not GuiEventBus._processing then
      GuiEventBus.process_notifications()
    end
  end
end

--- Drain every notification in `queue`, calling each matching observer via pcall.
--- Errors are logged with `log_label` but do not abort remaining notifications.
---@param queue table   Mutable array of {type, data, timestamp} notifications
---@param log_label string  Prefix for warn_log on pcall failure
local function drain_queue(queue, log_label)
  while #queue > 0 do
    local notification = table.remove(queue, 1)
    local observers = GuiEventBus._observers[notification.type] or {}
    for _, observer in ipairs(observers) do
      if observer and observer.update then
        local success, err = pcall(observer.update, observer, notification.data)
        if not success then
          ErrorHandler.warn_log(log_label, {
            event_type    = notification.type,
            observer_type = observer.observer_type or "unknown",
            error         = err
          })
        end
      end
    end
  end
end

--- Process deferred GUI notifications (called on_nth_tick(2)).
function GuiEventBus.process_deferred_notifications()
  GuiEventBus._deferred_queue = GuiEventBus._deferred_queue or {}
  if #GuiEventBus._deferred_queue == 0 then
    GuiEventBus._deferred_tick_active = false
    return
  end
  drain_queue(GuiEventBus._deferred_queue, "Deferred observer update failed")
  -- Queue is now drained — mark inactive (handler stays registered for multiplayer safety)
  GuiEventBus._deferred_tick_active = false
end

--- Process immediate (non-deferred) notifications.
--- CRITICAL: _processing flag prevents re-entrant calls when multiple notify()
--- calls fire in the same tick (e.g. favorite_added → tag_modified → cache_updated).
function GuiEventBus.process_notifications()
  GuiEventBus._notification_queue = GuiEventBus._notification_queue or {}
  GuiEventBus._processing = true
  drain_queue(GuiEventBus._notification_queue, "Observer update failed")
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

--- Remove invalid and age-expired observers in a single pass, then drop empty
--- event-type buckets.  Permanent observer types (data, notification, tag_editor)
--- are never removed for age — only invalid-player observers are purged for those.
--- The age branch is currently inert for all registered permanent types; it acts as
--- a safety net for any future short-lived observer types that may be added.
---@param max_age_ticks number? Maximum age before a non-permanent observer is removed (default: 108000 = 30 min)
---@return number total_cleaned
function GuiEventBus.cleanup_old_observers(max_age_ticks)
  if not game then return 0 end
  max_age_ticks = max_age_ticks or 108000
  local current_tick = game.tick or 0
  if current_tick == 0 then return 0 end

  -- Permanent types are never evicted by age — only by invalidity.
  local permanent = { data = true, notification = true, tag_editor = true }

  local total_cleaned = 0

  for event_type, observers in pairs(GuiEventBus._observers) do
    for i = #observers, 1, -1 do
      local observer = observers[i]
      local should_remove = false
      local reason

      if type(observer) ~= "table" or not observer.is_valid then
        should_remove = true
        reason = "nil_or_malformed"
      elseif not observer:is_valid() then
        should_remove = true
        reason = "invalid_player"
      elseif not permanent[observer.observer_type]
          and observer.created_tick
          and observer.created_tick > 0
          and (current_tick - observer.created_tick) > max_age_ticks then
        should_remove = true
        reason = "age_limit"
      end

      if should_remove then
        table.remove(observers, i)
        total_cleaned = total_cleaned + 1
        ErrorHandler.debug_log("Observer removed during cleanup", {
          event_type    = event_type,
          observer_type = type(observer) == "table" and observer.observer_type or "unknown",
          reason        = reason,
        })
      end
    end
    -- Drop empty buckets in the same pass.
    if #observers == 0 then
      GuiEventBus._observers[event_type] = nil
    end
  end

  if total_cleaned > 0 then
    ErrorHandler.debug_log("Periodic observer cleanup complete", {
      cleaned_count  = total_cleaned,
      current_tick   = current_tick,
      max_age_ticks  = max_age_ticks,
    })
  end

  return total_cleaned
end

--- Scheduled cleanup entry point — called via on_nth_tick(108000) every 30 minutes.
--- Delegates entirely to cleanup_old_observers for a single-pass sweep.
function GuiEventBus.schedule_periodic_cleanup()
  if not (game and type(game.tick) == "number") then return end
  GuiEventBus.ensure_initialized()
  GuiEventBus.cleanup_old_observers()
end

---@class BaseGuiObserver
---@field player LuaPlayer
---@field player_index uint|nil
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
  -- player_index is stored separately so GuiEventBus.subscribe() can dedup
  -- without touching the LuaPlayer object (which may be userdata).
  obj.player_index  = player and player.index or nil
  obj.observer_type = observer_type or "base"
  obj.created_tick  = game and game.tick or 0
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
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[DEEP][NotificationObserver:update] called", {
      player = event_data.player and event_data.player.name or "<nil>",
      player_valid = event_data.player and event_data.player.valid or false,
      gps = event_data.gps,
      event_data = event_data,
      event_data_full = event_data
    })
  end
  -- [2026-04] Chart tag move triggers this warning after vanilla move events.
  -- To avoid confusing the player with unnecessary alerts, this notification is now suppressed.
  -- The underlying tag is already handled by vanilla; no further action is needed here.
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
    if event_data and event_data.slot then
      -- Targeted update for a single slot (avoids full rebuild)
      fave_bar.mark_slot_dirty(player, event_data.slot)
      fave_bar.partial_rehydrate(player)
    else
      -- Fallback: refresh entire slots row
      fave_bar.refresh_slots(player)
    end
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
  DataObserver = DataObserver,
  NotificationObserver = NotificationObserver,
  process_deferred_notifications = function() return GuiEventBus.process_deferred_notifications() end
}
