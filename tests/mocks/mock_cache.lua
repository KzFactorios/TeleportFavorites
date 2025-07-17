-- Mock implementation of the Cache module for testing
local MockCache = {}

-- Storage for mock player data
local player_data_storage = {}

-- Storage for tag by GPS (for test control)
local tag_by_gps = nil

-- Initialize the cache
function MockCache.init()
  -- No-op for tests
end

-- Get player data or create if it doesn't exist
function MockCache.get_player_data(player)
  if not player or not player.valid then return {} end
  
  local index = player.index or 1
  if not player_data_storage[index] then
    player_data_storage[index] = {
      drag_favorite = {
        active = false
      },
      tag_editor_data = {},
      fave_bar_slots_visible = true,
      show_player_coords = true,
      favorites = {}
    }
  end
  
  return player_data_storage[index]
end

-- Get surface data or create if it doesn't exist
function MockCache.get_surface_data(surface_index)
  return {} -- Default empty surface data
end

-- Get tag editor data
function MockCache.get_tag_editor_data(player)
  if not player or not player.valid then return nil end
  
  local player_data = MockCache.get_player_data(player)
  return player_data.tag_editor_data
end

-- Set tag editor data
function MockCache.set_tag_editor_data(player, tag_editor_data)
  if not player or not player.valid then return end
  
  local player_data = MockCache.get_player_data(player)
  player_data.tag_editor_data = tag_editor_data or {}
end

-- Create tag editor data
function MockCache.create_tag_editor_data(options)
  local data = {
    gps = nil,
    position = nil,
    chart_tag = nil,
    favorite = nil
  }
  -- Merge options if provided
  if options then
    for k, v in pairs(options) do
      data[k] = v
    end
  end
  return data
end

-- Get player favorites
function MockCache.get_player_favorites(player)
  if not player or not player.valid then return {} end
  
  local player_data = MockCache.get_player_data(player)
  -- Ensure we return an array-like table, not an empty object
  if not player_data.favorites then
    player_data.favorites = {}
  end
  return player_data.favorites
end

-- Set player favorites
function MockCache.set_player_favorites(player, favorites)
  if not player or not player.valid then return end
  
  local player_data = MockCache.get_player_data(player)
  player_data.favorites = favorites or {}
end

-- Get player teleport history
function MockCache.get_player_teleport_history(player, surface_index)
  return { stack = {}, pointer = 0 } -- Default empty history with proper structure
end

-- Reset transient player states
function MockCache.reset_transient_player_states(player)
  if not player or not player.valid then return end
  
  local player_data = MockCache.get_player_data(player)
  if player_data.drag_favorite then
    player_data.drag_favorite.active = false
  end
end

-- Ensure surface cache
function MockCache.ensure_surface_cache(surface_index)
  -- No-op for tests
end

-- Sanitize for storage
function MockCache.sanitize_for_storage(obj)
  return obj -- Pass through for tests
end

-- Get mod version
function MockCache.get_mod_version()
  return "1.0.0"
end

-- Generic get/set
function MockCache.get(key)
  return nil
end

function MockCache.set(key, value)
  -- No-op for tests
end

-- Observer notifications
function MockCache.notify_observers_safe(event_type, data)
  -- No-op for tests
end

-- Remove stored tag
function MockCache.remove_stored_tag(gps, chart_tag)
  -- No-op for tests
end

-- Tag editor delete mode
function MockCache.set_tag_editor_delete_mode(player, enabled)
  -- No-op for tests
end

function MockCache.reset_tag_editor_delete_mode(player)
  -- No-op for tests
end

-- Modal dialog state
function MockCache.get_modal_dialog_state(player)
  return false
end

function MockCache.set_modal_dialog_state(player, state)
  -- No-op for tests
end

-- Set player surface
function MockCache.set_player_surface(player, surface_index)
  -- No-op for tests
end


-- Lookups submodule
MockCache.Lookups = {
  -- Get chart tag cache for a surface
  get_chart_tag_cache = function(surface_index)
    return {} -- Default empty cache
  end,
  -- Invalidate surface chart tags
  invalidate_surface_chart_tags = function(surface_index)
    -- No-op for tests
  end,
  -- Get chart tag by GPS
  get_chart_tag_by_gps = function(gps)
    return tag_by_gps
  end,
  -- Remove chart tag from cache by GPS
  remove_chart_tag_from_cache_by_gps = function(gps)
    -- No-op for tests
  end,
  -- Clear all caches
  clear_all_caches = function()
    -- No-op for tests
  end,
  -- Add stub for find_chart_tags to avoid nil error in lookups
  find_chart_tags = function(surface, force)
    return {} -- Return empty for test
  end
}

-- Set tag by GPS (for test control)
function MockCache.set_tag_by_gps(tag)
  tag_by_gps = tag
end

function MockCache.get_tag_by_gps(player, gps)
  return tag_by_gps
end

function MockCache.clear()
  for k in pairs(player_data_storage) do player_data_storage[k] = nil end
  tag_by_gps = nil
end

-- Add Settings mock
MockCache.Settings = {
  get_player_settings = function(player)
    if not player or not player.valid then return nil end
    return {
      show_player_coords = true,
      enable_teleport_history = true,
      favorites_enabled = true,
      hide_favorites_bar = false
    }
  end,
  
  get_chart_tag_click_radius = function(player)
    return 16.0  -- Default click radius for tests
  end,
  
  get_global_number_setting = function(setting_name, default)
    -- Mock global settings for tests
    local global_settings = {
      ["coords-update-interval"] = 15,
      ["history-update-interval"] = 30
    }
    return global_settings[setting_name] or default
  end,
  
  init = function() end,
  
  -- Additional settings methods if needed
  refresh_settings = function() end,
  invalidate_player_settings = function() end
}

return MockCache
