-- Mock implementation of the Cache module for testing
local MockCache = {}

-- Storage for mock player data
local player_data_storage = {}

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

-- Set tag editor data
function MockCache.set_tag_editor_data(player, tag_editor_data)
  if not player or not player.valid then return end
  
  local player_data = MockCache.get_player_data(player)
  player_data.tag_editor_data = tag_editor_data or {}
end

-- Create tag editor data
function MockCache.create_tag_editor_data()
  return {
    gps = nil,
    position = nil,
    chart_tag = nil,
    favorite = nil
  }
end

-- Get player favorites
function MockCache.get_player_favorites(player)
  if not player or not player.valid then return nil end
  
  local player_data = MockCache.get_player_data(player)
  return player_data.favorites
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
  -- Add stub for find_chart_tags to avoid nil error in lookups
  find_chart_tags = function(surface, force)
    return {} -- Return empty for test
  end
}

-- Set player favorites for a given player (for test control)
function MockCache.set_player_favorites(favorites)
  -- For simplicity, always set for player index 1
  if not player_data_storage[1] then
    player_data_storage[1] = {
      favorites = {},
      drag_favorite = { active = false },
      tag_editor_data = {},
      fave_bar_slots_visible = true,
      show_player_coords = true
    }
  end
  player_data_storage[1].favorites = favorites
end

-- Set tag by GPS (for test control)
local tag_by_gps = nil
function MockCache.set_tag_by_gps(tag)
  tag_by_gps = tag
end

function MockCache.get_tag_by_gps(gps)
  return tag_by_gps
end

function MockCache.clear()
  for k in pairs(player_data_storage) do player_data_storage[k] = nil end
  tag_by_gps = nil
end

return MockCache
