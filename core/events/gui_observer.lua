
-- Dependencies must be required first, with strict order based on dependencies
local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler =
  Deps.BasicHelpers, Deps.ErrorHandler
local fave_bar = require("gui.favorites_bar.fave_bar")
local ProfilerExport = require("core.utils.profiler_export")

---@class BaseGuiObserver
---@field player LuaPlayer
---@field player_index uint|nil
---@field observer_type string
---@field created_tick uint
local BaseGuiObserver = {}
BaseGuiObserver.__index = BaseGuiObserver

---@param player LuaPlayer
---@param observer_type string
---@return BaseGuiObserver
function BaseGuiObserver:new(player, observer_type)
  local obj = setmetatable({}, self)
  obj.player        = player
  obj.player_index  = player and player.index or nil
  obj.observer_type = observer_type or "base"
  obj.created_tick  = game and game.tick or 0
  return obj
end

---@return boolean valid
function BaseGuiObserver:is_valid()
  return self.player and self.player.valid
end

-- Base update is a no-op; subclasses override it.
function BaseGuiObserver:update(_event_data) end

---@class DataObserver : BaseGuiObserver
local DataObserver = setmetatable({}, { __index = BaseGuiObserver })
DataObserver.__index = DataObserver

---@param player LuaPlayer
---@return DataObserver
function DataObserver:new(player)
  local obj = BaseGuiObserver:new(player, "data")
  setmetatable(obj, self)
  ---@cast obj DataObserver
  return obj
end

---@param event_data table
function DataObserver:update(event_data)
  if not self:is_valid() then return end
  local player = self.player

  local can_update = BasicHelpers.is_planet_surface(player.surface) and
    player.controller_type ~= defines.controllers.god and
    player.controller_type ~= defines.controllers.spectator
  if not can_update then
    return
  end

  local function run(fn)
    local ok, section_err = pcall(fn)
    if not ok then error(section_err) end
  end

  local success, err = pcall(function()
    if event_data and type(event_data) == "table" and type(event_data.slots) == "table" then
      -- Deferred path: mark all affected slots dirty; flush_all_dirty_slots() will
      -- write the GUI on the next on_nth_tick(2), spreading the visual-write cost.
      run(function()
        run(function()
          for slot_index, is_dirty in pairs(event_data.slots) do
            if is_dirty then
              fave_bar.mark_slot_dirty(player, tonumber(slot_index))
            end
          end
        end)
      end)
    elseif event_data and event_data.slot then
      -- Deferred path: mark the single affected slot dirty for next-tick flush.
      run(function()
        run(function()
          fave_bar.mark_slot_dirty(player, event_data.slot)
        end)
      end)
    else
      run(function()
        run(function()
          fave_bar.refresh_slots(player)
        end)
      end)
    end
  end)

  if not success then
    ErrorHandler.warn_log("[DATA OBSERVER] Failed to refresh favorites bar", {
      player = player.name,
      error  = err
    })
  end
end

---@class GuiEventBus
---@field _observers table<string, table[]>
---@field _deferred_queue table[]
local GuiEventBus = {
  _observers = {},
  _deferred_queue = {},
  -- Whether deferred queue has items to process.
  -- on_nth_tick(2) is permanently registered for multiplayer safety; this flag
  -- lets it no-op cheaply when idle.
  _deferred_tick_active = false,
}

--- Subscribe observer to event type
---@param event_type string
---@param observer table Observer with update method
function GuiEventBus.subscribe(event_type, observer)
  if not GuiEventBus._observers[event_type] then
    GuiEventBus._observers[event_type] = {}
  end

  -- Dedup: skip if an observer for the same player/type already exists for this event.
  if observer.player_index then
    for _, existing in ipairs(GuiEventBus._observers[event_type]) do
      if existing.player_index == observer.player_index and existing.observer_type == observer.observer_type then
        return
      end
    end
  end

  table.insert(GuiEventBus._observers[event_type], observer)
  ErrorHandler.debug_log("Observer subscribed", {
    event_type    = event_type,
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
        event_type    = event_type,
        observer_type = observer.observer_type or "unknown"
      })
      break
    end
  end
end

--- Queue a notification for all subscribers of event_type.
--- All notifications are deferred to the next on_nth_tick(2) for multiplayer safety.
---@param event_type string
---@param event_data table
function GuiEventBus.notify(event_type, event_data)
  if type(event_data) == "table" and not event_data.action_id then
    local player_index = event_data.player_index
    if type(player_index) ~= "number" then
      local player = event_data.player
      if player and player.valid then
        player_index = player.index
      end
    end
    if type(player_index) == "number" then
      event_data.action_id = ProfilerExport.get_action_trace_id(player_index)
    end
  end
  GuiEventBus._deferred_queue[#GuiEventBus._deferred_queue + 1] = {
    type      = event_type,
    data      = event_data,
    timestamp = game.tick
  }
  GuiEventBus._deferred_tick_active = true
end

--- Drain the deferred queue using a snapshot-then-iterate pattern.
--- The queue is swapped out before iteration so that any notify() calls made
--- inside an observer's update land in the NEW queue and are processed on the
--- next on_nth_tick(2), preventing unbounded loops.
local REFRESH_EVENT_TYPES = {
  cache_updated = true,
  favorite_added = true,
  favorite_removed = true,
  favorite_updated = true,
}

---@param target table
---@param source table|nil
local function merge_slot_payload(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then return end
  target.slots = target.slots or {}
  if type(source.slot) == "number" then
    target.slots[source.slot] = true
  end
  if type(source.slots) == "table" then
    for slot_index, is_dirty in pairs(source.slots) do
      if is_dirty then
        target.slots[tonumber(slot_index) or slot_index] = true
      end
    end
  end
  target.slot = nil
end

---@param notification table
---@return number|nil
local function notification_player_index(notification)
  local data = notification and notification.data or nil
  if type(data) ~= "table" then return nil end
  if type(data.player_index) == "number" then return data.player_index end
  local player = data.player
  if player and player.valid and type(player.index) == "number" then
    return player.index
  end
  return nil
end

---@param notification table
---@param fallback_index number
---@return string
local function notification_coalesce_key(notification, fallback_index)
  local event_type = tostring(notification and notification.type or "unknown")
  local player_index = notification_player_index(notification)
  if player_index then
    if REFRESH_EVENT_TYPES[event_type] then
      return "refresh|" .. tostring(player_index)
    end
    return event_type .. "|" .. tostring(player_index)
  end
  -- If no player identity exists, keep notification unique and ordered.
  return event_type .. "|u|" .. tostring(fallback_index)
end

---@param snapshot table[]
---@return table[]
local function coalesce_snapshot_notifications(snapshot)
  local key_to_result_index = {}
  local result = {}

  for i = 1, #snapshot do
    local notification = snapshot[i]
    local key = notification_coalesce_key(notification, i)
    local existing_index = key_to_result_index[key]
    if not existing_index then
      result[#result + 1] = notification
      key_to_result_index[key] = #result
    else
      local existing = result[existing_index]
      local existing_data = existing and existing.data or nil
      local new_data = notification and notification.data or nil

      -- Refresh-family notifications can arrive multiple times per tick for the same
      -- player; collapse to one cache_updated dispatch. Union per-slot dirty flags from
      -- both sides — do not drop slot identity when one notification is coarse (no slot)
      -- and another is precise; that used to force a full bar refresh every time.
      if existing
          and REFRESH_EVENT_TYPES[tostring(existing.type or "")]
          and REFRESH_EVENT_TYPES[tostring(notification.type or "")] then
        if type(existing_data) ~= "table" then existing_data = {} end
        if type(new_data) ~= "table" then new_data = {} end

        existing.type = "cache_updated"
        existing.data = existing_data

        existing_data.player_index = new_data.player_index or existing_data.player_index
        existing_data.player = new_data.player or existing_data.player
        existing_data.action_id = new_data.action_id or existing_data.action_id
        existing_data.type = new_data.type or existing_data.type
        existing_data.gps = new_data.gps or existing_data.gps
        existing_data.old_gps = new_data.old_gps or existing_data.old_gps
        existing_data.new_gps = new_data.new_gps or existing_data.new_gps

        merge_slot_payload(existing_data, new_data)
      elseif existing then
        existing.data = new_data
      end
      if existing then
        existing.timestamp = notification.timestamp
      end
    end
  end

  return result
end

-- Maximum number of coalesced notifications to dispatch in a single on_nth_tick(2) call.
-- After coalescing, each entry typically represents one player's pending refresh, so
-- this budget is generous for normal play but caps extreme spike bursts.
local DISPATCH_BUDGET_PER_TICK = 32

local function drain_deferred_queue()
  local snapshot = GuiEventBus._deferred_queue
  GuiEventBus._deferred_queue = {}
  snapshot = coalesce_snapshot_notifications(snapshot)

  -- Bounded dispatch: if there are more coalesced notifications than the budget
  -- allows this tick, carry the excess back into the queue for the next tick.
  -- This smooths latency spikes in large multiplayer sessions without reordering.
  local budget = DISPATCH_BUDGET_PER_TICK
  for i, notification in ipairs(snapshot) do
    if i > budget then
      -- Carry unprocessed tail to process first next tick, preserving order (O(n) prepend,
      -- not repeated table.insert(..., 1, x) which is O(n²)).
      local existing = GuiEventBus._deferred_queue
      local new_q = {}
      local r = 0
      for j = i, #snapshot do
        r = r + 1
        new_q[r] = snapshot[j]
      end
      for j = 1, #existing do
        r = r + 1
        new_q[r] = existing[j]
      end
      GuiEventBus._deferred_queue = new_q
      GuiEventBus._deferred_tick_active = true
      break
    end
    local observers = GuiEventBus._observers[notification.type] or {}
    for _, observer in ipairs(observers) do
      if observer and observer.update then
        local ok, err = pcall(observer.update, observer, notification.data)
        if not ok then
          ErrorHandler.warn_log("Observer update failed", {
            event_type    = notification.type,
            observer_type = observer.observer_type or "unknown",
            error         = err
          })
        end
      end
    end
  end
end

--- Process deferred notifications (called on_nth_tick(2)).
function GuiEventBus.process_deferred_notifications()
  if #GuiEventBus._deferred_queue == 0 then
    GuiEventBus._deferred_tick_active = false
    return
  end
  drain_deferred_queue()
  -- If drain carried items back (budget exceeded), _deferred_tick_active is already
  -- set to true inside drain_deferred_queue; otherwise mark inactive.
  if #GuiEventBus._deferred_queue == 0 then
    GuiEventBus._deferred_tick_active = false
  end
end

--- Clean up observers for a specific player.
---@param player LuaPlayer|nil The player whose observers should be cleaned up
function GuiEventBus.cleanup_player_observers(player)
  if not player then return end

  local player_index = player.index
  local player_name  = player.name
  local total_cleaned = 0

  for _, observers in pairs(GuiEventBus._observers) do
    local cleaned_count = 0
    for i = #observers, 1, -1 do
      local observer = observers[i]
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
      player        = player_name,
      player_index  = player_index,
      cleaned_count = total_cleaned
    })
  end
end

--- Remove invalid and age-expired observers in a single pass, then drop empty
--- event-type buckets. Permanent observer types (data, tag_editor) are never
--- removed for age — only invalid-player observers are purged for those.
--- The age branch acts as a safety net for any future short-lived observer types.
---@param max_age_ticks number? Maximum age before a non-permanent observer is removed (default: 108000 = 30 min)
---@return number total_cleaned
function GuiEventBus.cleanup_old_observers(max_age_ticks)
  if not game then return 0 end
  max_age_ticks = max_age_ticks or 108000
  local current_tick = game.tick or 0
  if current_tick == 0 then return 0 end

  -- Permanent types are never evicted by age — only by invalidity.
  local permanent = { data = true, tag_editor = true }

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
      cleaned_count = total_cleaned,
      current_tick  = current_tick,
      max_age_ticks = max_age_ticks,
    })
  end

  return total_cleaned
end

--- Scheduled cleanup entry point — called via on_nth_tick(108000) every 30 minutes.
function GuiEventBus.schedule_periodic_cleanup()
  if not (game and type(game.tick) == "number") then return end
  GuiEventBus.cleanup_old_observers()
end

--- Register observers for a player (DataObserver for favorites bar updates).
---@param player LuaPlayer
function GuiEventBus.register_player_observers(player)
  if not player or not player.valid then return end

  local data_observer = DataObserver:new(player)
  GuiEventBus.subscribe("cache_updated",    data_observer)
  GuiEventBus.subscribe("favorite_added",   data_observer)
  GuiEventBus.subscribe("favorite_removed", data_observer)
  GuiEventBus.subscribe("favorite_updated", data_observer)

  ErrorHandler.debug_log("GUI observers registered for player", {
    player = player.name,
    events = { "cache_updated", "favorite_added", "favorite_removed", "favorite_updated" }
  })
end

return {
  GuiEventBus  = GuiEventBus,
  BaseObserver = BaseGuiObserver,
  DataObserver = DataObserver,
}
