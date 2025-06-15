---@diagnostic disable: undefined-global
--[[
core/utils/chart_tag_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated chart tag utilities combining all chart tag operations.

This module consolidates:
- chart_tag_spec_builder.lua - Chart tag specification creation
- chart_tag_click_detector.lua - Chart tag click detection and handling  
- chart_tag_terrain_handler.lua - Terrain change detection and chart tag relocation

Provides a unified API for all chart tag operations throughout the mod.
]]

local ErrorHandler = require("core.utils.error_handler")
local basic_helpers = require("core.utils.basic_helpers")

---@class ChartTagUtils
local ChartTagUtils = {}

-- ========================================
-- CHART TAG SPECIFICATION BUILDING
-- ========================================

--- Build a chart tag specification for Factorio's API
---@param position MapPosition
---@param source_chart_tag LuaCustomChartTag? Source chart tag to copy properties from
---@param player LuaPlayer? Player context
---@param text string? Custom text override
---@return table chart_tag_spec Chart tag specification ready for Factorio API
function ChartTagUtils.build_chart_tag_spec(position, source_chart_tag, player, text)
  local spec = {
    position = position,
    text = text or (source_chart_tag and source_chart_tag.text) or "Tag",
    last_user = (source_chart_tag and source_chart_tag.last_user) or 
                (player and player.valid and player.name) or 
                "System"
  }

  -- Add icon if valid
  local icon = source_chart_tag and source_chart_tag.icon
  if icon and type(icon) == "table" and icon.name then
    spec.icon = icon
  end

  return spec
end

--- Build chart tag spec from GPS and player context
---@param gps string GPS coordinate string
---@param player LuaPlayer Player context
---@param text string? Optional text override
---@param icon table? Optional icon override
---@return table? chart_tag_spec Chart tag specification or nil if invalid GPS
function ChartTagUtils.build_spec_from_gps(gps, player, text, icon)
  local GPSUtils = require("core.utils.gps_utils")
  local position = GPSUtils.map_position_from_gps(gps)
  if not position then return nil end
  
  local spec = {
    position = position,
    text = text or "Tag",
    last_user = player and player.valid and player.name or "System"
  }
  
  if icon and type(icon) == "table" and icon.name then
    spec.icon = icon
  end
  
  return spec
end

-- ========================================
-- CHART TAG CLICK DETECTION
-- ========================================

-- Settings for chart tag detection
local CHART_TAG_CLICK_RADIUS = 1.0

-- Cache for last clicked chart tags per player
local last_clicked_chart_tags = {}

--- Find chart tag at a specific position
---@param player LuaPlayer Player context
---@param cursor_position MapPosition Position to check
---@return LuaCustomChartTag? chart_tag Found chart tag or nil
function ChartTagUtils.find_chart_tag_at_position(player, cursor_position)
  if not player or not player.valid or not cursor_position then return nil end
  
  -- Only detect clicks while in map mode
  if player.render_mode ~= defines.render_mode.chart and 
     player.render_mode ~= defines.render_mode.chart_zoomed_in then 
    return nil
  end
    -- Get all chart tags on the current surface
  local force_tags = player.force.find_chart_tags(player.surface)
  if not force_tags or #force_tags == 0 then return nil end
  
  -- Find the closest chart tag within detection radius
  local closest_tag = nil
  local min_distance = CHART_TAG_CLICK_RADIUS
  
  for _, tag in pairs(force_tags) do
    if tag and tag.valid then
      local dx = tag.position.x - cursor_position.x
      local dy = tag.position.y - cursor_position.y
      local distance = math.sqrt(dx*dx + dy*dy)
      
      if distance < min_distance then
        min_distance = distance
        closest_tag = tag
      end
    end
  end
  
  return closest_tag
end

--- Handle map click event for chart tag detection
---@param event table Event data containing player_index and cursor_position
---@return LuaCustomChartTag? clicked_chart_tag The chart tag that was clicked or nil
function ChartTagUtils.handle_map_click(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return nil end
  
  -- Only process when player is in map view
  if player.render_mode ~= defines.render_mode.chart and 
     player.render_mode ~= defines.render_mode.chart_zoomed_in then 
    return nil
  end
  
  -- Get cursor position
  local cursor_position = event.cursor_position or player.position
  if player.selected then
    cursor_position = player.selected.position
  end
  
  -- Try to find chart tag at cursor position
  local clicked_chart_tag = ChartTagUtils.find_chart_tag_at_position(player, cursor_position)
  
  -- Store last clicked tag for this player
  last_clicked_chart_tags[player.index] = clicked_chart_tag
  
  -- Log the click if a tag was found
  if clicked_chart_tag and clicked_chart_tag.valid then
    local GPSUtils = require("core.utils.gps_utils")
    local gps = GPSUtils.gps_from_map_position(clicked_chart_tag.position, player.surface.index)
    
    ErrorHandler.debug_log("Player clicked chart tag", {
      player_name = player.name,
      gps = gps,
      tag_text = clicked_chart_tag.text
    })
  end
  
  return clicked_chart_tag
end

--- Get the last clicked chart tag for a player
---@param player_index number Player index
---@return LuaCustomChartTag? last_clicked The last clicked chart tag or nil
function ChartTagUtils.get_last_clicked_chart_tag(player_index)
  return last_clicked_chart_tags[player_index]
end

-- ========================================
-- CHART TAG TERRAIN HANDLING
-- ========================================

--- Check if a chart tag is on water
---@param chart_tag LuaCustomChartTag
---@param surface LuaSurface? Optional surface override
---@return boolean is_on_water
function ChartTagUtils.is_chart_tag_on_water(chart_tag, surface)
  if not chart_tag or not chart_tag.valid then return false end
  
  surface = surface or chart_tag.surface
  if not surface or not surface.valid then return false end
  
  local PositionUtils = require("core.utils.position_utils")
  return PositionUtils.is_water_tile(surface, chart_tag.position)
end

--- Check if a chart tag is on space
---@param chart_tag LuaCustomChartTag
---@param surface LuaSurface? Optional surface override
---@return boolean is_on_space
function ChartTagUtils.is_chart_tag_on_space(chart_tag, surface)
  if not chart_tag or not chart_tag.valid then return false end
  
  surface = surface or chart_tag.surface
  if not surface or not surface.valid then return false end
  
  local PositionUtils = require("core.utils.position_utils")
  return PositionUtils.is_space_tile(surface, chart_tag.position)
end

--- Find a valid position near a chart tag for relocation
---@param chart_tag LuaCustomChartTag
---@param search_radius number Search radius for valid position
---@param player LuaPlayer? Player context for validation
---@return MapPosition? valid_position
function ChartTagUtils.find_valid_position_near_chart_tag(chart_tag, search_radius, player)
  if not chart_tag or not chart_tag.valid then return nil end
  
  local surface = chart_tag.surface
  if not surface or not surface.valid then return nil end
    local PositionUtils = require("core.utils.position_utils")
  return PositionUtils.find_valid_position(surface, chart_tag.position, search_radius or 20)
end

--- Relocate a chart tag from water/space to nearby valid land
---@param chart_tag LuaCustomChartTag Chart tag to relocate
---@param search_radius number? Search radius (default: 20)
---@param notify_players boolean? Whether to notify affected players (default: true)
---@return boolean success True if relocation was successful
function ChartTagUtils.relocate_chart_tag_from_water(chart_tag, search_radius, notify_players)
  if not chart_tag or not chart_tag.valid then return false end
  
  search_radius = search_radius or 20
  notify_players = notify_players ~= false -- Default to true
  
  local surface = chart_tag.surface
  if not surface or not surface.valid then return false end
  
  -- Check if relocation is needed
  if not (ChartTagUtils.is_chart_tag_on_water(chart_tag, surface) or 
          ChartTagUtils.is_chart_tag_on_space(chart_tag, surface)) then
    return false -- No relocation needed
  end
  
  -- Find valid position
  local new_position = ChartTagUtils.find_valid_position_near_chart_tag(chart_tag, search_radius)
  if not new_position then
    ErrorHandler.debug_log("No valid position found for chart tag relocation", {
      chart_tag_position = chart_tag.position,
      search_radius = search_radius
    })
    return false
  end
  -- Store old position for notifications
  local old_position = { x = chart_tag.position.x, y = chart_tag.position.y }
  local surface_index = tonumber(surface.index) or 1
  
  -- Get associated tag data
  local Cache = require("core.cache.cache")
  local GPSUtils = require("core.utils.gps_utils")
  local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
  local tag = Cache.get_tag_by_gps(old_gps)
  
  -- Find a player context for chart tag creation
  local player = nil
  if tag and tag.faved_by_players and #tag.faved_by_players > 0 then
    for _, player_index in ipairs(tag.faved_by_players) do
      local p = game.get_player(player_index)
      if p and p.valid then
        player = p
        break
      end
    end
  end
  
  -- Fallback to chart tag's last user
  if not player and chart_tag.last_user then
    for _, p in pairs(game.players) do
      if p.valid and p.name == chart_tag.last_user then
        player = p
        break
      end
    end
  end
  
  if not player then
    ErrorHandler.debug_log("No valid player context for chart tag relocation")
    return false
  end
  
  -- Create new chart tag at valid position
  local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(new_position, chart_tag, player)
  
  local GPSChartHelpers = require("core.utils.gps_chart_helpers")
  local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then
    ErrorHandler.debug_log("Failed to create new chart tag during relocation")
    return false
  end
  
  -- Update tag data if it exists
  local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
  if tag then
    tag.chart_tag = new_chart_tag
    tag.gps = new_gps
    
    -- Update favorites that reference this tag
    if tag.faved_by_players and #tag.faved_by_players > 0 then
      for _, player_index in ipairs(tag.faved_by_players) do
        local fav_player = game.get_player(player_index)
        if fav_player and fav_player.valid then
          local favorites = Cache.get_player_favorites(fav_player)
          for i = 1, #favorites do
            local favorite = favorites[i]
            if favorite and favorite.gps == old_gps then
              favorite.gps = new_gps
            end
          end
        end
      end
    end
  end
  
  -- Destroy old chart tag
  chart_tag:destroy()
  
  -- Refresh cache
  local Lookups = Cache.lookups
  Lookups.invalidate_surface_chart_tags(surface_index)
  
  -- Notify affected players
  if notify_players and tag and tag.faved_by_players and #tag.faved_by_players > 0 then
    local RichTextFormatter = require("core.utils.rich_text_formatter")
    local GameHelpers = require("core.utils.game_helpers")
    
    local message = RichTextFormatter.tag_relocated_notification(new_chart_tag, old_position, new_position)
    for _, player_index in ipairs(tag.faved_by_players) do
      local fav_player = game.get_player(player_index)
      if fav_player and fav_player.valid then
        GameHelpers.player_print(fav_player, message)
      end
    end
  end
  
  ErrorHandler.debug_log("Chart tag successfully relocated", {
    old_position = old_position,
    new_position = new_position,
    old_gps = old_gps,
    new_gps = new_gps
  })
  
  return true
end

--- Process changed tiles and relocate affected chart tags
---@param tiles table Array of changed tiles
---@param surface LuaSurface Surface where tiles changed
---@param search_radius number? Search radius for relocation (default: 20)
---@param notify_players boolean? Whether to notify players (default: true)
---@return number relocated_count Number of chart tags relocated
function ChartTagUtils.process_terrain_changes(tiles, surface, search_radius, notify_players)
  if not tiles or #tiles == 0 or not surface or not surface.valid then return 0 end
  
  search_radius = search_radius or 20
  notify_players = notify_players ~= false
  
  -- Get all chart tags on this surface
  local Lookups = require("core.cache.cache").lookups
  local surface_index = surface.index
  local chart_tags = Lookups.get_surface_chart_tags(surface_index)
  if not chart_tags or #chart_tags == 0 then return 0 end
  
  -- Create a set of changed positions for quick lookup
  local changed_positions = {}
  for _, tile_data in ipairs(tiles) do
    if tile_data.position then
      local x = math.floor(tile_data.position.x)
      local y = math.floor(tile_data.position.y)
      changed_positions[x .. "," .. y] = true
    end
  end
  
  local relocated_count = 0
  
  -- Check each chart tag to see if its position was affected
  for _, chart_tag in pairs(chart_tags) do
    if chart_tag and chart_tag.valid then
      local pos = chart_tag.position
      local x = math.floor(pos.x)
      local y = math.floor(pos.y)
      
      -- Check if this position was changed
      local pos_key = x .. "," .. y
      if changed_positions[pos_key] then
        -- Check if relocation is needed and attempt it
        if ChartTagUtils.relocate_chart_tag_from_water(chart_tag, search_radius, notify_players) then
          relocated_count = relocated_count + 1
        end
      end
    end
  end
  
  return relocated_count
end

-- ========================================
-- CHART TAG ALIGNMENT
-- ========================================

--- Align a chart tag's position to whole number coordinates if needed
---@param player LuaPlayer Player context
---@param chart_tag LuaCustomChartTag Chart tag to align
---@return LuaCustomChartTag? aligned_chart_tag New aligned chart tag or original if no alignment needed
function ChartTagUtils.align_chart_tag_position(player, chart_tag)
  if not player or not player.valid or not chart_tag or not chart_tag.valid then
    return chart_tag
  end

  -- Check if alignment is needed
  if basic_helpers.is_whole_number(chart_tag.position.x) and basic_helpers.is_whole_number(chart_tag.position.y) then
    return chart_tag -- No alignment needed
  end

  ErrorHandler.debug_log("Aligning chart tag to whole number coordinates", {
    current_position = chart_tag.position
  })

  -- Normalize coordinates to whole numbers
  local x = basic_helpers.normalize_index(chart_tag.position.x)
  local y = basic_helpers.normalize_index(chart_tag.position.y)

  if not x or not y then
    ErrorHandler.debug_log("Failed to normalize chart tag coordinates")
    return chart_tag -- Return original if normalization fails
  end
  
  local new_position = { x = x, y = y }
  
  -- Create new chart tag at aligned position
  local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(new_position, chart_tag, player)
  
  -- Use safe wrapper to create the chart tag
  local GPSChartHelpers = require("core.utils.gps_chart_helpers")
  local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, player.surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then
    ErrorHandler.debug_log("Failed to create aligned chart tag")
    return chart_tag -- Return original if creation fails
  end

  -- Destroy the old chart tag (we know it's valid from function entry check)
  chart_tag:destroy()

  ErrorHandler.debug_log("Successfully aligned chart tag position", {
    old_position = chart_tag.position,
    new_position = new_position
  })

  return new_chart_tag
end

-- ========================================
-- EVENT HANDLERS
-- ========================================

--- Handle tile built events (player or robot)
---@param event table Event data for on_player_built_tile or on_robot_built_tile
function ChartTagUtils.on_tile_built(event)
  if not event or not event.tiles or #event.tiles == 0 then return end
  
  local surface = event.surface
  if not surface or not surface.valid then return end
  
  ChartTagUtils.process_terrain_changes(event.tiles, surface)
end

--- Register event handlers for chart tag terrain management
---@param script table The global script object
function ChartTagUtils.register_terrain_events(script)
  if not script then return end

  -- Register for tile built/removed events
  script.on_event(defines.events.on_player_built_tile, ChartTagUtils.on_tile_built)
  script.on_event(defines.events.on_robot_built_tile, ChartTagUtils.on_tile_built)
  script.on_event(defines.events.on_player_mined_tile, ChartTagUtils.on_tile_built)
  script.on_event(defines.events.on_robot_mined_tile, ChartTagUtils.on_tile_built)
  
  -- Script-caused terrain changes
  script.on_event(defines.events.script_raised_set_tiles, function(event)
    if not event or not event.tiles or #event.tiles == 0 then return end
    ChartTagUtils.process_terrain_changes(event.tiles, event.surface)
  end)
end

--- Register click detection events
---@param script table The global script object
function ChartTagUtils.register_click_events(script)
  if not script then return end
  
  -- Register the custom input handler for map clicks
  script.on_event("tf-map-left-click", ChartTagUtils.handle_map_click)
end

return ChartTagUtils
