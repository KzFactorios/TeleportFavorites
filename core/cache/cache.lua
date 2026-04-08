---@diagnostic disable: undefined-global
-- Data Structure (v2.0+):
-- storage = {
--   mod_version = string,
--   players = {
--     [player_index] = {
--       player_name = string,
--       tag_editor_data = table,
--       fave_bar_slots_visible = bool,
--       sequential_history_mode = bool,
--       drag_favorite = table,
--       modal_dialog = table,
--       surfaces = {
--         [surface_index] = {
--           favorites = { Favorite, ... },
--           teleport_history = { stack = { ... }, pointer = number }
--         }, ...
--       }
--     }, ...
--   },
--   surfaces = {
--     [surface_index] = { tags = { [gps_string] = Tag }, ... }
--   }
-- }

local Deps = require("base_deps")
local BasicHelpers, Constants, GPSUtils, ErrorHandler =
  Deps.BasicHelpers, Deps.Constants, Deps.GpsUtils, Deps.ErrorHandler
local FavoriteUtils = require("core.favorite.favorite_utils")
local Lookups = require("core.cache.lookups")
local SettingsCache = require("core.cache.settings")

-- ===========================
-- HISTORY ITEM (from history_item.lua)
-- ===========================

---@class HistoryItem
---@field gps string GPS string for the location recorded
---@field timestamp integer Tick timestamp of the teleport event
local HistoryItem = {}
HistoryItem.__index = HistoryItem

function HistoryItem.new(gps)
  if type(gps) ~= "string" or gps == "" then return nil end
  ---@type HistoryItem
  local self = setmetatable({}, HistoryItem)
  self.gps = gps
  self.timestamp = game and game.tick or 0
  return self
end

function HistoryItem.get_locale_time(player, item)
  if not item or type(item) ~= "table" or type(item.timestamp) ~= "number" then return "" end
  if not player or not player.valid then return "" end
  local now = game and game.tick or 0
  local ticks_ago = math.max(0, now - item.timestamp)
  local seconds_ago = math.floor(ticks_ago / 60)
  local minutes_ago = math.floor(seconds_ago / 60)
  local hours_ago = math.floor(minutes_ago / 60)
  if hours_ago > 0 then return tostring(hours_ago) .. "h " .. tostring(minutes_ago % 60) .. "m ago"
  elseif minutes_ago > 0 then return tostring(minutes_ago) .. "m ago"
  else return tostring(seconds_ago) .. "s ago"
  end
end

local gps_move_in_progress = {}
local Cache = {}
Cache.gps_move_in_progress = gps_move_in_progress

-- Optional GUI observer module (guarded require to avoid runtime requires)
local _ok_gui_observer, GuiObserver = pcall(require, "core.events.gui_observer")
if not _ok_gui_observer then GuiObserver = nil end

---@class Cache
---@field Lookups table<string, any>
---@field Settings table<string, any>
Cache.__index = Cache

Cache.Lookups = Lookups
Cache.Settings = SettingsCache

if not storage then
  error("Storage table not available - this mod requires Factorio 2.0+")
end

--- Safe notification that handles module load order
function Cache.notify_observers_safe(event_type, data)
  if GuiObserver and GuiObserver.GuiEventBus then
    GuiObserver.GuiEventBus.notify(event_type, data)
  end
end

--- Resets transient state for a player
---@param player LuaPlayer
function Cache.reset_transient_player_states(player)
  if not player or not player.valid then return end

  local player_data = Cache.get_player_data(player)

  if player_data.drag_favorite then
    player_data.drag_favorite.active = false
    player_data.drag_favorite.source_slot = nil
    player_data.drag_favorite.favorite = nil
  end

  if player_data.tag_editor_data then
    if player_data.tag_editor_data.move_mode then
      player_data.tag_editor_data.move_mode = false
    end
    player_data.tag_editor_data.error_message = ""
  end
end

--- Initialize the persistent cache table if not already present.
function Cache.init()
  if storage and storage._cache_initialized then return end

  local is_debug = Constants.settings.DEFAULT_LOG_LEVEL == "debug"

  if is_debug and log and type(log) == "function" then
    log("[TeleFaves][DEBUG] Cache.init() called")
  end
  if not storage then
    error("Storage table not available - this mod requires Factorio 2.0+")
  end

  storage._cache_initializing = true
  storage.players = storage.players or {}
  storage.surfaces = storage.surfaces or {}

  local current_mod_version = get_mod_version()
  -- TODO: Run migrations here if stored_version ~= current_mod_version

  -- Legacy stack migration: convert raw GPS strings to HistoryItem objects
  for _, player_data in pairs(storage.players) do
    if player_data.surfaces then
      for _, surface_data in pairs(player_data.surfaces) do
        local history = surface_data.teleport_history
        if history and history.stack then
          for idx, entry in ipairs(history.stack) do
            if type(entry) == "string" then
              history.stack[idx] = HistoryItem.new(entry)
            end
          end
        end
      end
    end
  end

  storage.mod_version = current_mod_version

  Lookups.init()
  Cache.Lookups = Lookups
  Cache.Settings = SettingsCache

  storage._cache_initialized = true
  storage._cache_initializing = nil

  return storage
end

local function init_player_favorites(player)
  local pfaves = storage.players[player.index].surfaces[player.surface.index].favorites or {}
  local seed_max = SettingsCache.get_player_max_favorite_slots(player)
  for i = 1, seed_max do
    if not pfaves[i] or type(pfaves[i]) ~= "table" then
      pfaves[i] = FavoriteUtils.get_blank_favorite()
    end
    pfaves[i].gps = pfaves[i].gps or Constants.settings.BLANK_GPS
    pfaves[i].locked = pfaves[i].locked or false
  end
  storage.players[player.index].surfaces[player.surface.index].favorites = pfaves or {}
  return storage.players[player.index].surfaces[player.surface.index].favorites
end

local function init_player_data(player)
  if not player or not player.valid then return {} end

  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {}
  storage.players[player.index].surfaces = storage.players[player.index].surfaces or {}

  local player_data = storage.players[player.index]
  local surf_idx    = player.surface and player.surface.index

  -- Fast-path: most calls come from already-initialised players on an already-initialised surface.
  if player_data._pdata_ok and surf_idx and player_data._surfs_ok and player_data._surfs_ok[surf_idx] then
    player_data.player_name = player.name or "Unknown"
    return player_data
  end

  -- Player-level one-time initialisation
  if not player_data._pdata_ok then
    player_data.tag_editor_data     = player_data.tag_editor_data or Cache.create_tag_editor_data()
    if player_data.fave_bar_slots_visible == nil then
      player_data.fave_bar_slots_visible = true
    end
    if player_data.sequential_history_mode == nil then
      player_data.sequential_history_mode = false
    end
    player_data.drag_favorite = player_data.drag_favorite or {
      active = false, source_slot = nil, favorite = nil
    }
    player_data.modal_dialog = player_data.modal_dialog or {
      active = false, dialog_type = nil
    }
    if player_data.last_max_favorite_slots == nil then
      player_data.last_max_favorite_slots = SettingsCache.get_player_max_favorite_slots(player)
    end
    local pos = player_data.history_modal_position
    local needs_default = pos == nil
      or (type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number"
          and pos.x == 0 and pos.y == 0)
    if needs_default then
      local screen_width  = (player.display_resolution and player.display_resolution.width  or 1920)
      local screen_height = (player.display_resolution and player.display_resolution.height or 1080)
      local scale = player.display_scale or 1
      screen_width  = screen_width  / scale
      screen_height = screen_height / scale
      player_data.history_modal_position = { x = (screen_width - 350) / 2 * 0.6, y = (screen_height - 200) / 2 * 0.5 }
    end
    player_data._pdata_ok = true
  end

  player_data.player_name = player.name or "Unknown"

  -- Surface-level one-time initialisation
  if surf_idx then
    player_data.surfaces[surf_idx] = player_data.surfaces[surf_idx] or {}
    local sdata = player_data.surfaces[surf_idx]

    player_data._surfs_ok = player_data._surfs_ok or {}
    if not player_data._surfs_ok[surf_idx] then
      sdata.favorites = init_player_favorites(player)
      sdata.teleport_history = sdata.teleport_history or { stack = {}, pointer = 0 }
      player_data._surfs_ok[surf_idx] = true
    end
  end

  return player_data
end

--- Get persistent player data for a given player.
---@param player LuaPlayer
---@return table data table (persistent)
function Cache.get_player_data(player)
  if not player then return {} end
  return init_player_data(player)
end

local function init_surface_data(surface_index)
  storage.surfaces = storage.surfaces or {}
  storage.surfaces[surface_index] = storage.surfaces[surface_index] or {}
  local surface_data = storage.surfaces[surface_index]
  surface_data.tags = surface_data.tags or {}
  return surface_data
end

--- Get the persistent tag table for a given surface index.
---@param surface_index integer
---@return table<string, any>|nil
function Cache.get_surface_tags(surface_index)
  if not surface_index or type(surface_index) ~= "number" then
    ErrorHandler.warn_log("Invalid surface_index in get_surface_tags", { surface_index = surface_index })
    return nil
  end
  local sdata = init_surface_data(surface_index)
  return sdata and sdata.tags or {}
end

--- Remove a tag from persistent storage by GPS string.
---@param gps string GPS string key for the tag.
function Cache.remove_stored_tag(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return end

  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if not surface_index or surface_index < 1 then return end
  local safe_index = tonumber(surface_index) and math.floor(surface_index) or nil
  if not safe_index or safe_index < 1 then return end
  local integer_index = safe_index --[[@as integer]]
  local tag_cache = Cache.get_surface_tags(integer_index)
  if not tag_cache or not tag_cache[gps] then return end
  tag_cache[gps] = nil
  Cache.Lookups.remove_chart_tag_from_cache_by_gps(gps)
end

--- Get tag object by GPS string, attaching a transient chart_tag reference.
---@param player LuaPlayer
---@param gps string
---@return Tag|nil
function Cache.get_tag_by_gps(player, gps)
  if not player then return nil end
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = player.surface.index

  local tag_cache = Cache.get_surface_tags(surface_index --[[@as integer]])
  if not tag_cache then return nil end

  local match_tag = tag_cache[gps]
  if not match_tag then
    if not gps_move_in_progress[gps] then
      Cache.notify_observers_safe("invalid_chart_tag", { player = player, gps = gps })
    end
    return nil
  end

  -- MULTIPLAYER SAFETY: Shallow copy so we can attach chart_tag (userdata) transiently.
  local result = {}
  for k, v in pairs(match_tag) do
    if type(v) ~= "userdata" then
      result[k] = v
    end
  end

  local chart_tag_ref = Cache.Lookups.get_chart_tag_by_gps(gps)
  if chart_tag_ref and chart_tag_ref.valid and chart_tag_ref.position then
    result.chart_tag = chart_tag_ref
  else
    result.chart_tag = nil
  end

  if result.chart_tag and result.chart_tag.valid then
    return result
  end

  if not gps_move_in_progress[gps] then
    Cache.notify_observers_safe("invalid_chart_tag", { player = player, gps = gps })
  end
  return nil
end

--- Ensure the player's surface data structure exists and return it.
---@param player LuaPlayer
---@param surface_index integer|nil Falls back to player.surface.index
---@return table|nil surface_data
---@return table|nil player_data
function Cache.ensure_player_surface_data(player, surface_index)
  if not player or not player.valid then return nil, nil end
  local idx = surface_index or (player.surface and player.surface.index)
  if not idx then return nil, nil end
  local player_data = Cache.get_player_data(player)
  if not player_data then return nil, nil end
  player_data.surfaces = player_data.surfaces or {}
  player_data.surfaces[idx] = player_data.surfaces[idx] or {}
  return player_data.surfaces[idx], player_data
end

---@param player LuaPlayer
---@param surface_index integer
---@return table teleport_history
function Cache.get_player_teleport_history(player, surface_index)
  local surface_data = Cache.ensure_player_surface_data(player, surface_index)
  if not surface_data then return { stack = {}, pointer = 0 } end
  surface_data.teleport_history = surface_data.teleport_history or { stack = {}, pointer = 0 }
  return surface_data.teleport_history
end

function Cache.ensure_surface_cache(surface_index)
  if not Cache.Lookups or not Cache.Lookups.ensure_surface_cache then
    error("Lookups.ensure_surface_cache not available")
  end
  return Cache.Lookups.ensure_surface_cache(surface_index)
end

-- ===========================
-- CACHE FAVORITES (from cache_favorites.lua)
-- ===========================

do
  local rehydrated_favorites_cache = {}

  function Cache.get_player_favorites(player, surface_index)
    local surface_data = Cache.ensure_player_surface_data(player, surface_index)
    if not surface_data then return nil end
    return surface_data.favorites or {}
  end

  function Cache.invalidate_rehydrated_favorites()
    rehydrated_favorites_cache = {}
  end

  function Cache.get_last_max_favorite_slots(player)
    if not player or not player.valid then return nil end
    local pdata = Cache.get_player_data(player)
    local v = pdata and pdata.last_max_favorite_slots or nil
    if type(v) == "number" then return math.floor(v) end
    return nil
  end

  function Cache.set_last_max_favorite_slots(player, value)
    if not player or not player.valid then return end
    local pdata = Cache.get_player_data(player)
    if type(value) == "number" then pdata.last_max_favorite_slots = math.floor(value) end
  end

  function Cache.apply_player_max_slots(player, new_max)
    if not player or not player.valid then return end
    if type(new_max) ~= "number" then return end
    new_max = math.floor(new_max)
    if new_max < 1 then return end
    local player_data = Cache.get_player_data(player)
    if not player_data or not player_data.surfaces then return end
    for _, sdata in pairs(player_data.surfaces) do
      local favorites = sdata.favorites or {}
      local current_len = #favorites
      if current_len < new_max then
        for i = current_len + 1, new_max do favorites[i] = FavoriteUtils.get_blank_favorite() end
      elseif current_len > new_max then
        for i = new_max + 1, current_len do favorites[i] = nil end
      end
      sdata.favorites = favorites
    end
    storage.players[player.index] = player_data
  end

  function Cache.set_player_favorites(player, favorites)
    local surface_data = Cache.ensure_player_surface_data(player)
    if not surface_data then return false end
    surface_data.favorites = favorites or {}
    return true
  end
end

-- ===========================
-- CACHE UI (from cache_ui.lua)
-- ===========================

function Cache.get_tag_editor_data(player)
  return Cache.get_player_data(player).tag_editor_data
end

function Cache.set_tag_editor_data(player, data)
  if not data then data = {} end
  local pdata = Cache.get_player_data(player)
  if not pdata or not pdata.tag_editor_data then return nil end
  local is_empty = true
  for _ in pairs(data) do is_empty = false; break end
  if is_empty then
    pdata.tag_editor_data = Cache.create_tag_editor_data()
  else
    local sanitized = Cache.sanitize_for_storage(data, { chart_tag = true, tag = true })
    for k, v in pairs(sanitized) do pdata.tag_editor_data[k] = v end
  end
  return pdata.tag_editor_data
end

function Cache.create_tag_editor_data(options)
  local defaults = {
    gps = "", move_gps = "", locked = false, is_favorite = false,
    icon = "", text = "", tag = {}, chart_tag = {}, error_message = "",
    search_radius = 1, delete_mode = false, pending_delete = false, move_mode = false
  }
  if not options or type(options) ~= "table" then return defaults end
  local result = {}
  for key, default_value in pairs(defaults) do
    result[key] = options[key] ~= nil and options[key] or default_value
  end
  return result
end

function Cache.set_tag_editor_delete_mode(player, is_delete_mode)
  if not player or not player.valid then return end
  local tag_data = Cache.get_tag_editor_data(player)
  tag_data.delete_mode = is_delete_mode == true
  Cache.set_tag_editor_data(player, tag_data)
end

function Cache.set_modal_dialog_state(player, dialog_type)
  if not player or not player.valid then return end
  local player_data = Cache.get_player_data(player)
  player_data.modal_dialog.active = dialog_type ~= nil
  player_data.modal_dialog.dialog_type = dialog_type
end

function Cache.is_modal_dialog_active(player)
  if not player or not player.valid then return false end
  return Cache.get_player_data(player).modal_dialog.active == true
end

function Cache.get_modal_dialog_type(player)
  if not player or not player.valid then return nil end
  local player_data = Cache.get_player_data(player)
  if player_data.modal_dialog.active then return player_data.modal_dialog.dialog_type end
  return nil
end

function Cache.get_sequential_history_mode(player)
  return Cache.get_player_data(player).sequential_history_mode or false
end

function Cache.set_sequential_history_mode(player, value)
  Cache.get_player_data(player).sequential_history_mode = value == true
end

function Cache.get_history_modal_position(player)
  return Cache.get_player_data(player).history_modal_position
end

function Cache.set_history_modal_position(player, pos)
  local player_data = Cache.get_player_data(player)
  if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
    player_data.history_modal_position = { x = pos.x, y = pos.y, width = pos.width, height = pos.height }
  end
end

Cache.HistoryItem = HistoryItem

function Cache.sanitize_for_storage(obj, exclude_fields)
  if type(obj) ~= "table" then return {} end
  local sanitized = {}
  exclude_fields = exclude_fields or {}
  local keys = {}
  for k in pairs(obj) do table.insert(keys, k) end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local v = obj[k]
    if not exclude_fields[k] and type(v) ~= "userdata" then sanitized[k] = v end
  end
  return sanitized
end

return Cache
