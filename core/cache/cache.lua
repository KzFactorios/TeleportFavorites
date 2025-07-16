---@diagnostic disable: undefined-global

--[[
Cache.lua
TeleportFavorites Factorio Mod
-----------------------------
Persistent and runtime cache management for mod data, including player, surface, and tag storage.

- Provides helpers for safe cache access, mutation, and removal, with strict EmmyLua annotations.
- All persistent data is stored in the global table under  storage.cache,  storage.players, and  storage.surfaces.
- Each player entry in storage.players[player_index] now includes a player_name field for the Factorio player name.
- Runtime (non-persistent) lookup tables are managed via the Lookups module.
- Settings access and caching is managed via the SettingsCache module.
- Player and surface data are always initialized and normalized for safe multiplayer and multi-surface support.
- All access to persistent cache should use the Cache API; do not access  storage directly.

Data Structure (as of v2.0+):
---------------
storage = {
  mod_version = string, -- Current mod version
  players = {
    [player_index] = {
      player_name = string,         -- Factorio player name
      render_mode = string,         -- Player's render mode
      tag_editor_data = table,      -- Tag editor UI state (see Cache.create_tag_editor_data)
      fave_bar_slots_visible = bool,-- Whether the favorites bar is visible
      show_player_coords = bool,    -- Show player coordinates in UI
      drag_favorite = table,        -- Drag state for favorites bar
      modal_dialog = table,         -- Modal dialog state
      surfaces = {
        [surface_index] = {
          favorites = { Favorite, ... },      -- Array of Favorite objects for this surface
          teleport_history = {                -- Teleport history for this surface
            stack = { gps_string, ... },
            pointer = number
          }
        },
        ...
      }
    },
    ...
  },
  surfaces = {
    [surface_index] = {
      tags = { [gps_string] = Tag }, -- Persistent tags for this surface, indexed by GPS string
    },
    ...
  }
}
]]

-- Function to get mod version from Factorio's mod system at runtime
local function get_mod_version()
  if script and script.active_mods and script.mod_name then
    return script.active_mods[script.mod_name] or "unknown"
  end
  return "unknown"
end

local FavoriteUtils = require("core.favorite.favorite")
local Constants = require("constants")
local GPSUtils = require("core.utils.gps_utils")
local Lookups = require("core.cache.lookups")
local SettingsCache = require("core.cache.settings")
local BasicHelpers = require("core.utils.basic_helpers")


--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field Lookups table<string, any> Lookup tables for chart tags and other runtime data.
---@field Settings table<string, any> Settings cache and access layer for all mod settings.
local Cache = {}
Cache.__index = Cache
--- Lookup tables for chart tags and other runtime data.
---@type Lookups
Cache.Lookups = nil
--- Settings cache and access layer for all mod settings.
---@type Settings  
Cache.Settings = nil


-- Ensure storage is always available for persistence (Factorio 2.0+)
if not storage then
  error("Storage table not available - this mod requires Factorio 2.0+")
end

-- Lazy-loaded Lookups module to avoid circular dependency
-- Observer Pattern Integration

--- Safe notification that handles module load order
function Cache.notify_observers_safe(event_type, data)
  local success, gui_observer = pcall(require, "core.events.gui_observer")
  if success and gui_observer.GuiEventBus then
    gui_observer.GuiEventBus.notify(event_type, data)
  end
end


--- Resets transient state for a player
---@param player LuaPlayer
function Cache.reset_transient_player_states(player)
  if not player or not player.valid then return end

  local player_data = Cache.get_player_data(player)

  -- Reset drag mode state
  if player_data.drag_favorite then
    player_data.drag_favorite.active = false
    player_data.drag_favorite.source_slot = nil
    player_data.drag_favorite.favorite = nil
  end

  -- Reset move mode state in tag editor
  if player_data.tag_editor_data then
    if player_data.tag_editor_data.move_mode then
      player_data.tag_editor_data.move_mode = false
    end
    -- Clear any error messages from previous session
    player_data.tag_editor_data.error_message = ""
  end
end

--- Initialize the persistent cache table if not already present.
function Cache.init()
  if not storage then
    error("Storage table not available - this mod requires Factorio 2.0+")
  end
  storage.players = storage.players or {}
  storage.surfaces = storage.surfaces or {}
  
  -- Version comparison for migration detection
  local current_mod_version = get_mod_version()
  local stored_version = storage.mod_version
  local needs_migration = stored_version and stored_version ~= current_mod_version
  
  -- TODO: Run migrations here if needs_migration is true
  -- if needs_migration then
  --   run_migrations(stored_version, current_mod_version)
  -- end
  
  -- Update stored version only after migrations would complete
  storage.mod_version = current_mod_version
  -- Initialize lookups cache properly
  Lookups.init()
  Cache.Lookups = Lookups
  
  -- Initialize settings cache
  Cache.Settings = SettingsCache

  return storage
end

local function init_player_favorites(player)
  if not player or not player.valid then return {} end

  local pfaves = storage.players[player.index].surfaces[player.surface.index].favorites or {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if not pfaves[i] or type(pfaves[i]) ~= "table" then
      pfaves[i] = FavoriteUtils.get_blank_favorite()
    end
    -- Don't override GPS if it's already set - preserve BLANK_GPS value
    pfaves[i].gps = pfaves[i].gps or Constants.settings.BLANK_GPS
    pfaves[i].locked = pfaves[i].locked or false
  end

  storage.players[player.index].surfaces[player.surface.index].favorites = pfaves or {}
  return storage.players[player.index].surfaces[player.surface.index].favorites
end

local function init_player_data(player)
  if not player or not player.valid then return {} end

  Cache.init()
  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {}
  storage.players[player.index].surfaces = storage.players[player.index].surfaces or {}

  local player_data = storage.players[player.index]
  player_data.surfaces[player.surface.index] = player_data.surfaces[player.surface.index] or {}
  player_data.surfaces[player.surface.index].favorites = init_player_favorites(player)
  player_data.surfaces[player.surface.index].teleport_history = player_data.surfaces[player.surface.index].teleport_history or { stack = {}, pointer = 0 }
  player_data.player_name = player.name or "Unknown"
  player_data.render_mode = player_data.render_mode or player.render_mode
  player_data.tag_editor_data = player_data.tag_editor_data or Cache.create_tag_editor_data()
  player_data.fave_bar_slots_visible = player_data.fave_bar_slots_visible
  if player_data.fave_bar_slots_visible == nil then
    player_data.fave_bar_slots_visible = true -- Default: slots are visible, show EYELASH icon
  end
  
  player_data.show_player_coords = player_data.show_player_coords
  if player_data.show_player_coords == nil then
    -- Default to the player's setting or true if setting doesn't exist
    ---@diagnostic disable-next-line: redundant-parameter
    local player_settings = settings.get_player_settings(player)
    player_data.show_player_coords = player_settings and player_settings["show-player-coords"] and player_settings["show-player-coords"].value or true
  end

  player_data.drag_favorite = player_data.drag_favorite or {
    active = false,
    source_slot = nil,
    favorite = nil
  }

  player_data.modal_dialog = player_data.modal_dialog or {
    active = false,
    dialog_type = nil
  }

  return player_data
end

--- Retrieve a value from the persistent cache by key.
---@param key string
---@return any|nil
function Cache.get(key)
  if not key or key == "" then return nil end
  Cache.init()
  return storage[key]
end

--- Get the mod version from the cache, setting it if not present.
---@return string|nil
function Cache.get_mod_version()
  local val = Cache.get("mod_version")
  return (val and val ~= "") and tostring(val) or nil
end

--- Get persistent player data for a given player.
---@param player LuaPlayer
---@return table --data table (persistent)
function Cache.get_player_data(player)
  if not player then return {} end
  local result = init_player_data(player)
  return result
end

---@param player LuaPlayer
--- Returns the player's favorites array, or nil if not found/invalid.
---@return table[]|nil
function Cache.get_player_favorites(player)
  if not player or not player.valid or not player.surface or not player.surface.index then
    return nil
  end
  local player_data = Cache.get_player_data(player)
  if not player_data.surfaces or not player_data.surfaces[player.surface.index] then
    return nil
  end
  local favorites = player_data.surfaces[player.surface.index].favorites or {}
  return favorites
end

---@param player LuaPlayer
---@param gps string
---@return table|nil
function Cache.is_player_favorite(player, gps)
  if not player or not player.valid or not gps or gps == "" then return nil end
  local player_faves = Cache.get_player_favorites(player)
  if not player_faves then return nil end
  for _, v in pairs(player_faves) do
    if v.gps == gps then
      return v
    end
  end
  return nil
end

--- Initialize and retrieve persistent surface data for a given surface index.
---@param surface_index integer
---@return table Surface data table (persistent)
local function init_surface_data(surface_index)
  Cache.init()
  storage.surfaces = storage.surfaces or {}
  storage.surfaces[surface_index] = storage.surfaces[surface_index] or {}
  local surface_data = storage.surfaces[surface_index]
  surface_data.tags = surface_data.tags or {}
  return surface_data
end


--- Get persistent surface data for a given surface index.
---@return table|nil Surface data table (persistent) or nil if invalid
function Cache.get_surface_data(surface_index)
  if not surface_index or type(surface_index) ~= "number" then
    return nil
  end
  return init_surface_data(surface_index)
end

--- Get the persistent tag table for a given surface index.
---@param surface_index integer
---@return table<string, any>|nil Table of tags indexed by GPS string, or nil if invalid
function Cache.get_surface_tags(surface_index)
  if not surface_index or type(surface_index) ~= "number" then
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
  local safe_surface_index = tonumber(surface_index) and math.floor(surface_index) or nil
  if not safe_surface_index or safe_surface_index < 1 then return end
  local integer_surface_index = safe_surface_index --[[@as integer]]
  local tag_cache = Cache.get_surface_tags(integer_surface_index)
  if not tag_cache or not tag_cache[gps] then return end
  tag_cache[gps] = nil

  -- Remove the tag from the Lookups cache as well
  Cache.init()
  ---@diagnostic disable-next-line: undefined-field, need-check-nil
  Cache.Lookups.remove_chart_tag_from_cache_by_gps(gps)
end

--- @param player LuaPlayer
--- @param gps string
--- @return Tag|nil
function Cache.get_tag_by_gps(player, gps)
  if not player then return nil end
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = player.surface.index

  local tag_cache = Cache.get_surface_tags(surface_index --[[@as integer]])
  if not tag_cache then return nil end
  
  local cache_keys = {}
  for k, _ in pairs(tag_cache) do
    table.insert(cache_keys, k)
  end

  local match_tag = tag_cache[gps] or nil

  -- Ensure chart_tag is present and valid
  if match_tag and match_tag.chart_tag then
    -- Safely check if chart_tag is valid and has position
    local chart_tag_valid, chart_tag_has_position = pcall(function()
      return match_tag.chart_tag.valid and match_tag.chart_tag.position ~= nil
    end)
    
    if not chart_tag_valid or not chart_tag_has_position then
      -- Chart tag is invalid or missing position, try to get a fresh one
      local chart_tag_lookup = Cache.Lookups.get_chart_tag_by_gps(gps)
      if chart_tag_lookup then
        local lookup_valid = pcall(function() return chart_tag_lookup.valid end)
        if lookup_valid then
          match_tag.chart_tag = chart_tag_lookup
        else
          match_tag.chart_tag = nil
        end
      else
        match_tag.chart_tag = nil
      end
    end
  elseif match_tag and not match_tag.chart_tag then
    -- No chart_tag reference, try to get one
    local chart_tag_lookup = Cache.Lookups.get_chart_tag_by_gps(gps)
    if chart_tag_lookup then
      local lookup_valid = pcall(function() return chart_tag_lookup.valid end)
      if lookup_valid then
        match_tag.chart_tag = chart_tag_lookup
      end
    end
  end

  -- Safely check if we have a valid chart_tag
  local valid_chart_tag = false
  if match_tag and match_tag.chart_tag then
    local chart_tag_check_success, is_valid = pcall(function() return match_tag.chart_tag.valid end)
    valid_chart_tag = chart_tag_check_success and is_valid == true
  end
  
  if valid_chart_tag and match_tag then
    return match_tag
  end

  -- Notify player if chart_tag is invalid
  Cache.notify_observers_safe("invalid_chart_tag", { player = player, gps = gps })
  return nil
end

--- Get the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@return table
function Cache.get_tag_editor_data(player)
  return Cache.get_player_data(player).tag_editor_data
end

--- Set the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@param data table|nil
---@return table|nil
function Cache.set_tag_editor_data(player, data)
  if not data then data = {} end
  local pdata = Cache.get_player_data(player)
  if not pdata or not pdata.tag_editor_data then
    return nil
  end

  -- If data is empty table, clear all tag_editor_data
  local is_empty = true
  for _ in pairs(data) do
    is_empty = false
    break
  end

  if is_empty then
    pdata.tag_editor_data = Cache.create_tag_editor_data()
  else
    for k, v in pairs(data) do
      pdata.tag_editor_data[k] = v
    end
  end

  return pdata.tag_editor_data
end

--- Create a new tag_editor_data structure with default values
--- This centralized factory method eliminates duplication across the codebase
---@param options table|nil Optional override values for specific fields
---@return table tag_editor_data structure with all required fields
function Cache.create_tag_editor_data(options)
  local defaults = {
    gps = "",
    move_gps = "",
    locked = false,
    is_favorite = false,
    icon = "",
    text = "",
    tag = {},       -- do not use nil
    chart_tag = {}, -- do not use nil
    error_message = "",
    search_radius = 1,
    -- Delete confirmation state
    delete_mode = false,
    pending_delete = false,
    -- Move mode state
    move_mode = false
  }

  if not options or type(options) ~= "table" then
    return defaults
  end

  -- Merge options with defaults, allowing partial overrides
  local result = {}
  for key, default_value in pairs(defaults) do
    result[key] = options[key] ~= nil and options[key] or default_value
  end

  return result
end

-- Set the pending delete flag in tag_editor_data
function Cache.set_tag_editor_delete_mode(player, is_delete_mode)
  if not player or not player.valid then return end

  local tag_data = Cache.get_tag_editor_data(player)
  tag_data.delete_mode = is_delete_mode == true

  -- Ensure we keep the tag_editor_data updated
  Cache.set_tag_editor_data(player, tag_data)
end

-- Reset the delete mode flag in tag_editor_data
function Cache.reset_tag_editor_delete_mode(player)
  if not player or not player.valid then return end

  local tag_data = Cache.get_tag_editor_data(player)
  tag_data.delete_mode = false

  -- Ensure we keep the tag_editor_data updated
  Cache.set_tag_editor_data(player, tag_data)
end

--- Set modal dialog state for a player
---@param player LuaPlayer
---@param dialog_type string|nil -- type of dialog that is modal, or nil to clear
function Cache.set_modal_dialog_state(player, dialog_type)
  if not player or not player.valid then return end

  local player_data = Cache.get_player_data(player)
  player_data.modal_dialog.active = dialog_type ~= nil
  player_data.modal_dialog.dialog_type = dialog_type
end

--- Check if a player has an active modal dialog
---@param player LuaPlayer
---@return boolean -- true if modal dialog is active
function Cache.is_modal_dialog_active(player)
  if not player or not player.valid then return false end

  local player_data = Cache.get_player_data(player)
  return player_data.modal_dialog.active == true
end

--- Get the type of active modal dialog for a player
---@param player LuaPlayer
---@return string|nil -- dialog type or nil if no modal dialog active
function Cache.get_modal_dialog_type(player)
  if not player or not player.valid then return nil end

  local player_data = Cache.get_player_data(player)
  if player_data.modal_dialog.active then
    return player_data.modal_dialog.dialog_type
  end
  return nil
end

--- Generic sanitizer for objects to be stored in persistent storage
---@param obj table
---@param exclude_fields table<string, boolean>|nil -- set of field names to exclude
---@return table sanitized_obj
function Cache.sanitize_for_storage(obj, exclude_fields)
  if type(obj) ~= "table" then return {} end
  local sanitized = {}
  exclude_fields = exclude_fields or {}
  for k, v in pairs(obj) do
    if not exclude_fields[k] and type(v) ~= "userdata" then
      sanitized[k] = v
    end
  end
  return sanitized
end

---@param player LuaPlayer
---@param surface_index integer
---@return table teleport_history
function Cache.get_player_teleport_history(player, surface_index)
  if not player or not player.valid then return { stack = {}, pointer = 0 } end
  Cache.init()
  local player_data = Cache.get_player_data(player)
  player_data.surfaces = player_data.surfaces or {}
  player_data.surfaces[surface_index] = player_data.surfaces[surface_index] or {}
  player_data.surfaces[surface_index].teleport_history = player_data.surfaces[surface_index].teleport_history or { stack = {}, pointer = 0 }
  return player_data.surfaces[surface_index].teleport_history
end

--- Ensure the runtime cache for a surface is initialized (pass-through to Lookups)
---@param surface_index integer
function Cache.ensure_surface_cache(surface_index)
  ---@diagnostic disable-next-line: undefined-field
  if not Cache.Lookups or not Cache.Lookups.ensure_surface_cache then
    error("Lookups.ensure_surface_cache not available")
  end
  ---@diagnostic disable-next-line: undefined-field
  return Cache.Lookups.ensure_surface_cache(surface_index)
end

--- Set the player's surface (for test and event handler use)
---@param player LuaPlayer
---@param surface_index integer
function Cache.set_player_surface(player, surface_index)
  if not player or not player.valid then return end
  player.surface = game.surfaces[surface_index]
end

---@param player LuaPlayer
---@param favorites table[]
function Cache.set_player_favorites(player, favorites)
  if not player or not player.valid or not player.surface or not player.surface.index then
    return false
  end
  local player_data = Cache.get_player_data(player)
  if not player_data then return false end
  
  -- Ensure surface data structure exists
  player_data.surfaces = player_data.surfaces or {}
  player_data.surfaces[player.surface.index] = player_data.surfaces[player.surface.index] or {}
  
  -- Set the favorites
  player_data.surfaces[player.surface.index].favorites = favorites or {}
  return true
end

--- Check if migration is needed by comparing stored vs current version
---@return boolean needs_migration Whether migration is needed
---@return string|nil stored_version The stored version (nil if fresh install)
---@return string current_version The current mod version
function Cache.check_migration_needed()
  local current_mod_version = get_mod_version()
  local stored_version = storage and storage.mod_version
  local needs_migration = stored_version and stored_version ~= current_mod_version
  return needs_migration or false, stored_version, current_mod_version
end

--- Mark migration as complete by updating stored version
function Cache.complete_migration()
  if storage then
    storage.mod_version = get_mod_version()
  end
end

return Cache
