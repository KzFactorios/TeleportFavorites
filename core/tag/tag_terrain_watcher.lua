---@diagnostic disable: undefined-global, param-type-mismatch, assign-type-mismatch
--[[
TeleportFavorites Mod - Tag Terrain Watcher
Handles cases where the terrain under chart tags changes (e.g., land becomes water)
and relocates managed tags as needed.

This is event-driven, responding to terrain change events in Factorio rather than
using polling mechanisms like on_tick.
]]

local Cache = require("core.cache.cache")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local GPSUtils = require("core.utils.gps_utils")


local tag_terrain_watcher = {}

-- Maximum radius to search for nearby land when a tag is over water
local MAX_SEARCH_RADIUS = 10

-- Helper function to check if a position is on water
---@param surface LuaSurface The surface to check
---@param position MapPosition The position to check
---@return boolean isWater True if the position is on water
local function is_position_on_water(surface, position)
  -- Delegate to consolidated position utils
  return PositionUtils.is_water_tile(surface, position)
end

-- Find nearest valid land position for a chart tag
---@param surface LuaSurface The surface to search on
---@param position MapPosition The original position
---@return MapPosition|nil newPosition The new valid position, or nil if none found
local function find_nearest_valid_land(surface, position)
  -- Delegate to consolidated position utils
  return PositionUtils.find_nearest_walkable_position(surface, position, MAX_SEARCH_RADIUS)
end

-- Relocate a chart tag if it's on water
---@param chart_tag LuaCustomChartTag The chart tag to check and potentially relocate
---@return boolean relocated True if the tag was relocated
local function relocate_tag_if_on_water(chart_tag)
  if not chart_tag or not chart_tag.valid then return false end
  
  local surface = chart_tag.surface
  if not surface or not surface.valid then return false end
  
  -- Skip if not on water
  if not is_position_on_water(surface, chart_tag.position) then
    return false
  end
  
  -- Find a valid land position nearby
  local new_position = find_nearest_valid_land(surface, chart_tag.position)
  if not new_position then
    -- No valid land found nearby
    return false
  end
    -- Remember the old position for reporting
  local old_position = {x = chart_tag.position.x, y = chart_tag.position.y}
  local surface_index = surface.index
    -- Find the linked tag in our system
  local old_gps = GPSUtils.gps_from_map_position(old_position, tonumber(surface_index) or 1)
  local tag = Cache.get_tag_by_gps(old_gps)
  
  -- Only proceed if this chart tag is linked to one of our tags
  if not tag then return false end
  
  -- Get the force that the chart tag belongs to
  local force = chart_tag.force
  if not force or not force.valid then return false end
    -- Create a new chart tag at the valid position
  local chart_tag_spec = {
    position = new_position,
    text = chart_tag.text or "Tag",
    last_user = chart_tag.last_user or ""
  }
  
  -- Only include icon if it's a valid SignalID
  if chart_tag.icon and type(chart_tag.icon) == "table" and chart_tag.icon.name then
    chart_tag_spec.icon = chart_tag.icon
  end
  
  -- Add the new chart tag using safe wrapper
  local new_chart_tag = ChartTagUtils.safe_add_chart_tag(force, surface, chart_tag_spec)
    -- Only proceed if creation was successful
  if not new_chart_tag or not new_chart_tag.valid then return false end
    -- Update the GPS reference in our system
  local new_gps = GPSUtils.gps_from_map_position(new_position, tonumber(surface_index) or 1)
  
  -- Update tag's chart_tag reference and GPS
  tag.chart_tag = new_chart_tag
  tag.gps = new_gps
    -- Destroy the old chart tag  chart_tag.destroy()
  
  -- Refresh the cache
  Cache.Lookups.invalidate_surface_chart_tags(surface_index)
  
  -- Notify tag owners and favorites users
  if tag.faved_by_players and #tag.faved_by_players > 0 then    for _, player_index in ipairs(tag.faved_by_players) do
      local player = game.get_player(player_index)
      if player and player.valid then
        GameHelpers.player_print(player, RichTextFormatter.tag_relocated_notification(new_chart_tag, old_position, new_position))
      end
    end
  end
  
  return true
end

-- Process tiles that were changed to check for affected tags
---@param tiles table Array of tiles that were changed
---@param surface LuaSurface The surface where the change occurred
local function process_changed_tiles(tiles, surface)
  if not tiles or #tiles == 0 or not surface or not surface.valid then return end
  
  -- Create a set of changed tile positions for faster lookup
  local changed_positions = {}
  for _, tile_data in ipairs(tiles) do
    local pos_key = tile_data.position.x .. "," .. tile_data.position.y
    changed_positions[pos_key] = true
  end
  -- Get chart tags from the affected surface
  local surface_index = surface.index
  local chart_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
  
  if not chart_tags then return end
  
  -- Check each chart tag to see if it's on a changed tile
  for _, chart_tag in pairs(chart_tags) do
    if chart_tag and chart_tag.valid then
      local pos = chart_tag.position
      local pos_key = pos.x .. "," .. pos.y
      
      -- If this position was changed, check if it's now water
      if changed_positions[pos_key] and is_position_on_water(surface, pos) then
        relocate_tag_if_on_water(chart_tag)
      end
    end
  end
end

-- Handle when a player places tiles (e.g., landfill being removed)
function tag_terrain_watcher.on_player_built_tile(event)
  if not event or not event.tiles or not event.surface_index then return end
  
  local surface = game.get_surface(event.surface_index)
  if not surface or not surface.valid then return end
  
  process_changed_tiles(event.tiles, surface)
end

-- Handle when a robot places tiles (e.g., landfill being removed by robots)
function tag_terrain_watcher.on_robot_built_tile(event)
  if not event or not event.tiles or not event.surface_index then return end
  
  local surface = game.get_surface(event.surface_index)
  if not surface or not surface.valid then return end
  
  process_changed_tiles(event.tiles, surface)
end

-- Handle when scripts change tiles
function tag_terrain_watcher.on_script_path_request_finished(event)
  -- Check all affected surfaces for any chart tags that need relocation
  if global.tf_surfaces_to_check then    for surface_index, _ in pairs(global.tf_surfaces_to_check) do      local surface = game.get_surface(surface_index)
      if surface and surface.valid then
        local chart_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
        if chart_tags then
          for _, chart_tag in pairs(chart_tags) do
            if chart_tag and chart_tag.valid then
              relocate_tag_if_on_water(chart_tag)
            end
          end
        end
      end
    end
    -- Clear the list of surfaces to check
    global.tf_surfaces_to_check = {}
  end
end

-- Handle the map being edited by a mod or scenario
function tag_terrain_watcher.on_surface_cleared(event)
  if not event or not event.surface_index then return end
  
  -- When a surface is cleared, queue it for checking when it's available again
  if not global.tf_surfaces_to_check then
    global.tf_surfaces_to_check = {}
  end
  global.tf_surfaces_to_check[event.surface_index] = true
end

-- Handle when map chunks are generated (for edge cases)
function tag_terrain_watcher.on_chunk_generated(event)
  if not event or not event.surface then return end
  
  -- Check for chart tags in the new chunk that might be on water
  local area = event.area
  if not area then return end
  
  local chart_tags = event.surface.find_entities_filtered({
    type = "chart-tag",
    area = area
  })
  
  for _, entity in ipairs(chart_tags) do
    local chart_tag = entity --[[@as LuaCustomChartTag]]
    relocate_tag_if_on_water(chart_tag)
  end
end

-- Register all event handlers
function tag_terrain_watcher.register(script)
  script.on_event(defines.events.on_player_built_tile, tag_terrain_watcher.on_player_built_tile)
  script.on_event(defines.events.on_robot_built_tile, tag_terrain_watcher.on_robot_built_tile)
  script.on_event(defines.events.on_script_path_request_finished, tag_terrain_watcher.on_script_path_request_finished)
  script.on_event(defines.events.on_surface_cleared, tag_terrain_watcher.on_surface_cleared)
  script.on_event(defines.events.on_chunk_generated, tag_terrain_watcher.on_chunk_generated)
end

return tag_terrain_watcher
