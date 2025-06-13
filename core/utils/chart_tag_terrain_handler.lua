---@diagnostic disable: undefined-global
-- Chart Tag Terrain Handler
-- Handles chart tags that end up over water due to terrain changes
-- Uses event-driven approach instead of polling

local Cache = require("__TeleportFavorites__.core.cache.cache")
local Lookups = require("__TeleportFavorites__.core.cache.lookups")
local gps_parser = require("__TeleportFavorites__.core.gps.gps_parser")
local RichTextFormatter = require("__TeleportFavorites__.core.utils.rich_text_formatter")

-- Local module table
local chart_tag_terrain_handler = {}

--- Check if a position is over water
---@param position MapPosition The position to check
---@param surface LuaSurface The surface to check on
---@return boolean is_water True if the position is over water
local function is_position_over_water(position, surface)
  if not position or not surface or not surface.valid then return true end
  
  -- Get the tile at the position
  local tile = surface.get_tile(position.x, position.y)
  if not tile or not tile.valid then return true end
  
  -- Check if the tile is water
  return tile.collides_with("water-tile")
end

--- Find nearest land position
---@param position MapPosition The starting position
---@param surface LuaSurface The surface to check on
---@param max_radius number Maximum radius to search (default: 20)
---@return MapPosition|nil nearest_land_position The nearest land position or nil if none found
local function find_nearest_land_position(position, surface, max_radius)
  if not position or not surface or not surface.valid then return nil end
  
  max_radius = max_radius or 20
  
  -- Check immediate position first
  if not is_position_over_water(position, surface) then
    return position
  end
  
  -- Search in expanding spiral pattern
  -- This is more efficient than checking every position in a square
  local directions = {
    {x = 1, y = 0},  -- right
    {x = 0, y = 1},  -- down
    {x = -1, y = 0}, -- left
    {x = 0, y = -1}  -- up
  }
  
  local x, y = position.x, position.y
  local dir_index = 1
  local steps = 1
  local step_count = 0
  local segment_count = 0
  
  for radius = 1, max_radius do
    for _ = 1, 2 do
      for _ = 1, steps do
        -- Move in the current direction
        x = x + directions[dir_index].x
        y = y + directions[dir_index].y
        
        -- Check if this position is land
        local check_pos = {x = x, y = y}
        if not is_position_over_water(check_pos, surface) then
          return check_pos
        end
        
        step_count = step_count + 1
        if step_count > max_radius * max_radius * 4 then
          -- Safety limit reached
          return nil
        end
      end
      
      -- Change direction
      dir_index = dir_index % 4 + 1
      segment_count = segment_count + 1
      
      -- Increase steps every 2 segments
      if segment_count % 2 == 0 then
        steps = steps + 1
      end
    end
  end
  
  return nil -- No land found within the radius
end

--- Relocate a chart tag that is over water to the nearest land
---@param chart_tag LuaCustomChartTag The chart tag to relocate
---@param player LuaPlayer|nil The player who owns the tag (optional)
---@return boolean was_relocated True if the tag was relocated successfully
local function relocate_chart_tag_from_water(chart_tag, player)
  if not chart_tag or not chart_tag.valid then return false end
  
  local surface = chart_tag.surface
  if not surface or not surface.valid then return false end
  
  local position = chart_tag.position
  local surface_index = surface.index
  
  -- If not over water, no need to relocate
  if not is_position_over_water(position, surface) then
    return false
  end
  
  -- Find nearest land position
  local new_position = find_nearest_land_position(position, surface)
  if not new_position then
    -- No land found nearby, can't relocate
    return false
  end
  
  -- Get the GPS string for the chart tag
  local old_gps = gps_parser.gps_from_map_position(position, surface_index)
  
  -- Get the tag from cache
  local tag = Cache.get_tag_by_gps(old_gps)
  if not tag then return false end
  
  -- Get force that owns the tag
  local force
  if player and player.valid then
    force = player.force
  else
    -- Try to find a player from the tag's faved_by_players
    if tag.faved_by_players and #tag.faved_by_players > 0 then
      for _, player_index in ipairs(tag.faved_by_players) do
        local p = game.get_player(player_index)
        if p and p.valid then
          force = p.force
          player = p
          break
        end
      end
    end
    
    -- If still no force, try to use the chart tag's last_user
    if not force and chart_tag.last_user then
      for _, p in pairs(game.players) do
        if p.valid and p.name == chart_tag.last_user then
          force = p.force
          player = p
          break
        end
      end
    end
    
    -- Last resort: try the first player in the game
    if not force then
      for _, p in pairs(game.players) do
        if p.valid then
          force = p.force
          player = p
          break
        end
      end
    end
  end
  
  if not force then return false end
  
  -- Create new chart tag spec
  local chart_tag_spec = {
    position = new_position,
    text = chart_tag.text or "Tag", -- Ensure text is never nil
    last_user = chart_tag.last_user or (player and player.name or "")
  }
  
  -- Only include icon if it's a valid SignalID
  if chart_tag.icon and type(chart_tag.icon) == "table" and chart_tag.icon.name then
    chart_tag_spec.icon = chart_tag.icon
  end

  -- Store original chart tag data before destruction
  local chart_tag_surface = chart_tag.surface
  
  -- Remove the original chart tag
  chart_tag.destroy()
  -- Create the new chart tag using safe wrapper
  local GPSChartHelpers = require("core.utils.gps_chart_helpers")
  local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(force, chart_tag_surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then
    return false
  end
  
  -- Get the new GPS string
  local new_gps = gps_parser.gps_from_map_position(new_position, surface_index)
  
  -- Update the tag reference with the new chart tag and GPS
  tag.chart_tag = new_chart_tag
  tag.gps = new_gps
  
  -- Invalidate the lookups cache for this surface
  Lookups.invalidate_surface_chart_tags(surface_index)
  
  -- Notify the player(s) who have this tag as a favorite
  if tag.faved_by_players then
    for _, player_index in ipairs(tag.faved_by_players) do
      local p = game.get_player(player_index)
      if p and p.valid then
        p.print({"", "[TeleportFavorites] Tag relocated from water: ", 
          old_gps, " → ", new_gps})
      end
    end
  end
  
  return true
end

--- Process changed tiles and check if any chart tags need to be relocated
---@param tiles table Array of tiles that were changed
---@param surface LuaSurface The surface where the tiles were changed
---@param player LuaPlayer|nil The player who changed the tiles (optional)
local function process_changed_tiles(tiles, surface, player)
  if not tiles or not surface or not surface.valid then return end
  
  -- Get all chart tags on this surface from the cache
  local surface_index = surface.index
  local all_chart_tags = Lookups.get_all_chart_tags_on_surface(surface_index)
  if not all_chart_tags or #all_chart_tags == 0 then return end

  -- Create a set of changed positions for quick lookup
  local changed_positions = {}
  for _, tile_data in ipairs(tiles) do
    if tile_data.position then
      local x = math.floor(tile_data.position.x)
      local y = math.floor(tile_data.position.y)
      changed_positions[x .. "," .. y] = true
    end
  end
  
  -- Check each chart tag to see if its position was affected
  for _, chart_tag in ipairs(all_chart_tags) do
    if chart_tag and chart_tag.valid then
      local pos = chart_tag.position
      local x = math.floor(pos.x)
      local y = math.floor(pos.y)
      
      -- Check if this position or nearby positions were changed
      -- We check a small area around the tag since a player might be standing slightly off-center
      local check_range = 1
      local needs_check = false
      
      for dx = -check_range, check_range do
        for dy = -check_range, check_range do
          local check_key = (x + dx) .. "," .. (y + dy)
          if changed_positions[check_key] then
            needs_check = true
            break
          end
        end
        if needs_check then break end
      end
      
      -- If this chart tag's position was changed, check if it's over water and needs relocation
      if needs_check and is_position_over_water(pos, surface) then
        relocate_chart_tag_from_water(chart_tag, player)
      end
    end
  end
end

--- Handle tile built event
---@param event EventData The event data for on_player_built_tile or on_robot_built_tile
function chart_tag_terrain_handler.on_tile_built(event)
  if not event or not event.tiles or #event.tiles == 0 then return end
  
  local surface = event.surface
  if not surface or not surface.valid then return end
  
  local player = nil
  if event.player_index then
    player = game.get_player(event.player_index)
  end
  
  process_changed_tiles(event.tiles, surface, player)
end

--- Initialize the terrain handler by registering event handlers
---@param script table The global script object
function chart_tag_terrain_handler.register_events(script)
  if not script then return end

  -- Register for tile built events
  script.on_event(defines.events.on_player_built_tile, chart_tag_terrain_handler.on_tile_built)
  script.on_event(defines.events.on_robot_built_tile, chart_tag_terrain_handler.on_tile_built)
  
  -- Landfill removal or water-creation events
  script.on_event(defines.events.on_player_mined_tile, chart_tag_terrain_handler.on_tile_built)
  script.on_event(defines.events.on_robot_mined_tile, chart_tag_terrain_handler.on_tile_built)
  
  -- Script-caused terrain changes
  script.on_event(defines.events.script_raised_set_tiles, function(event)
    if not event or not event.tiles or #event.tiles == 0 then return end
    process_changed_tiles(event.tiles, event.surface)
  end)
end

return chart_tag_terrain_handler
