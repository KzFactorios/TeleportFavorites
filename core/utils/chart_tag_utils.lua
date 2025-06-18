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
local GPSUtils = require("core.utils.gps_utils")
local PositionUtils = require("core.utils.position_utils")
local Cache = require("core.cache.cache")
local RichTextFormatter = require("core.utils.rich_text_formatter")
local GameHelpers = require("core.utils.game_helpers")
local Constants = require("constants")

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
---@param set_ownership boolean? Whether to set last_user (only for final tags, not temporary)
---@return table chart_tag_spec Chart tag specification ready for Factorio API
function ChartTagUtils.build_chart_tag_spec(position, source_chart_tag, player, text, set_ownership)
  local spec = {
    position = position,
    text = text or (source_chart_tag and source_chart_tag.text) or "Tag"
  }
  
  -- Only set last_user if this is a final chart tag (not temporary)
  if set_ownership then
    spec.last_user = (source_chart_tag and source_chart_tag.last_user) or 
                     (player and player.valid and player.name) or 
                     "System"
  end
  
  -- Add icon if valid
  local icon = source_chart_tag and source_chart_tag.icon
  if icon and type(icon) == "table" and icon.name then
    spec.icon = icon
  end

  return spec
end

-- ========================================
-- CHART TAG CLICK DETECTION
-- ========================================

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
    -- Get click radius from player settings
  local click_radius = Constants.settings.CHART_TAG_CLICK_RADIUS
  local player_settings = settings.get_player_settings(player)
  local setting = player_settings["chart-tag-click-radius"]
  if setting and setting.value then
    local value = tonumber(setting.value)
    if value then
      click_radius = value
    end
  end
  
  -- Find the closest chart tag within detection radius
  local closest_tag = nil
  local min_distance = click_radius
  
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
    local gps = GPSUtils.gps_from_map_position(clicked_chart_tag.position, player.surface.index)
    
    ErrorHandler.debug_log("Player clicked chart tag", {
      player_name = player.name,
      gps = gps,
      tag_text = clicked_chart_tag.text
    })
  end
  
  return clicked_chart_tag
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
    
  return PositionUtils.find_valid_position(surface, chart_tag.position, search_radius or 20)
end

-- ========================================
-- TERRAIN PROTECTION SYSTEM
-- ========================================

--- Calculate the protected area around a chart tag position based on player settings
---@param position MapPosition Chart tag position
---@param player LuaPlayer? Player to get settings from (uses default if nil)
---@return BoundingBox? protected_area The protected bounding box
function ChartTagUtils.calculate_protected_area(position, player)
  if not position then return nil end
  
  -- Get protection radius from player settings or use default
  local protection_radius = Constants.settings.TERRAIN_PROTECTION_DEFAULT
  if player and player.valid then
    local player_settings = settings.get_player_settings(player)
    local setting = player_settings["terrain-protection-radius"]
    if setting and setting.value then
      -- Ensure we get a number value
      local value = tonumber(setting.value)
      if value then
        protection_radius = value
      end
    end
  end
  
  -- Create protection area based on radius
  return {
    left_top = { x = math.floor(position.x) - protection_radius, y = math.floor(position.y) - protection_radius },
    right_bottom = { x = math.floor(position.x) + protection_radius, y = math.floor(position.y) + protection_radius }
  }
end

--- Check if a position is within the protected area of any chart tag
---@param surface LuaSurface Surface to check on 
---@param position MapPosition Position to check
---@param requesting_player LuaPlayer? Player making the request (for ownership checks)
---@return boolean is_protected True if position is protected
---@return LuaCustomChartTag? protecting_tag The chart tag that protects this area
---@return boolean is_owner True if the requesting player owns the protecting tag
function ChartTagUtils.is_position_protected(surface, position, requesting_player)
  if not surface or not surface.valid or not position then 
    return false, nil, false 
  end  -- Get all chart tags on this surface
  local surface_index = surface.index
  local chart_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
  if not chart_tags or #chart_tags == 0 then 
    return false, nil, false 
  end
  
  -- Check each chart tag for protection overlap
  for _, chart_tag in pairs(chart_tags) do
    if chart_tag and chart_tag.valid then
      -- Determine ownership first
      local is_owner = false
      if requesting_player and requesting_player.valid and chart_tag.last_user then
        is_owner = (chart_tag.last_user == requesting_player.name)
      end
        -- Get the requesting player's protection setting
      local requesting_player_radius = Constants.settings.TERRAIN_PROTECTION_DEFAULT
      if requesting_player and requesting_player.valid then
        local player_settings = settings.get_player_settings(requesting_player)
        local setting = player_settings["terrain-protection-radius"]
        if setting and setting.value then
          local value = tonumber(setting.value)
          if value then
            requesting_player_radius = value
          end
        end
      end
      
      -- Special logic for radius 0: if requesting player has radius 0 and is owner, allow change
      if requesting_player_radius == 0 and is_owner then
        -- Owner with radius 0 can modify their own tags - skip protection check for this tag
        goto continue
      end
        -- For non-owners or when requesting player has radius > 0, use chart tag owner's settings or default
      local protection_radius = Constants.settings.TERRAIN_PROTECTION_DEFAULT
      if chart_tag.last_user then
        -- Try to find the chart tag owner to get their protection settings
        for _, player in pairs(game.players) do
          if player.valid and player.name == chart_tag.last_user then
            local owner_settings = settings.get_player_settings(player)
            local owner_setting = owner_settings["terrain-protection-radius"]
            if owner_setting and owner_setting.value then
              local value = tonumber(owner_setting.value)
              if value then                
                protection_radius = value
                -- Special case: if tag owner has radius 0 but requesting player is not owner,
                -- use default protection to prevent griefing
                if protection_radius == 0 and not is_owner then
                  protection_radius = Constants.settings.TERRAIN_PROTECTION_DEFAULT
                end
              end
            end
            break
          end
        end
      end
      
      -- Calculate protection area based on determined radius
      local protected_area = {
        left_top = { x = math.floor(chart_tag.position.x) - protection_radius, y = math.floor(chart_tag.position.y) - protection_radius },
        right_bottom = { x = math.floor(chart_tag.position.x) + protection_radius, y = math.floor(chart_tag.position.y) + protection_radius }
      }
      
      -- Check if position is within protected area
      if position.x >= protected_area.left_top.x and 
         position.x <= protected_area.right_bottom.x and
         position.y >= protected_area.left_top.y and 
         position.y <= protected_area.right_bottom.y then
        
        return true, chart_tag, is_owner
      end
      
      ::continue::
    end
  end
  
  return false, nil, false
end

--- Filter tiles to remove those in protected areas (unless owner allows it)
---@param tiles table Array of tile changes to filter
---@param surface LuaSurface Surface where tiles will be changed
---@param requesting_player LuaPlayer? Player making the changes
---@return table filtered_tiles Tiles that are allowed to be changed
---@return table blocked_tiles Tiles that were blocked due to protection
function ChartTagUtils.filter_protected_tiles(tiles, surface, requesting_player)
  if not tiles or #tiles == 0 or not surface or not surface.valid then 
    return tiles or {}, {} 
  end
  
  local filtered_tiles = {}
  local blocked_tiles = {}
  
  for _, tile_data in ipairs(tiles) do
    if tile_data.position then
      local is_protected, protecting_tag, is_owner = ChartTagUtils.is_position_protected(
        surface, tile_data.position, requesting_player
      )
      
      if is_protected and not is_owner then
        -- Tile is protected and player doesn't own the tag
        table.insert(blocked_tiles, {
          tile = tile_data,
          protecting_tag = protecting_tag
        })
      else
        -- Tile is not protected or player owns the protecting tag
        table.insert(filtered_tiles, tile_data)
      end
    else
      -- No position data, allow the tile change
      table.insert(filtered_tiles, tile_data)
    end
  end
  
  return filtered_tiles, blocked_tiles
end

--- Notify player about blocked terrain changes due to chart tag protection
---@param player LuaPlayer Player to notify
---@param blocked_tiles table Array of blocked tile changes
function ChartTagUtils.notify_terrain_protection(player, blocked_tiles)  if not player or not player.valid or not blocked_tiles or #blocked_tiles == 0 then 
    return 
  end
  
  -- Group blocked tiles by protecting tag
  local blocks_by_tag = {}
  for _, block_data in ipairs(blocked_tiles) do
    local tag = block_data.protecting_tag
    if tag and tag.valid then
      local tag_key = tag.position.x .. "," .. tag.position.y
      if not blocks_by_tag[tag_key] then
        blocks_by_tag[tag_key] = {
          tag = tag,
          blocked_count = 0
        }
      end
      blocks_by_tag[tag_key].blocked_count = blocks_by_tag[tag_key].blocked_count + 1
    end
  end
  
  -- Send notifications for each protecting tag
  for _, block_info in pairs(blocks_by_tag) do
    local tag = block_info.tag
    local surface_index = tag.surface and tag.surface.index or 1
    local gps = GPSUtils.gps_from_map_position(tag.position, surface_index)
    
    local message = string.format(
      "[TeleportFavorites] %d tile changes blocked by chart tag protection at %s. Delete the tag first to modify this area.",
      block_info.blocked_count,
      gps
    )
    
    GameHelpers.player_print(player, message)
  end
end

--- Process terrain changes with protection system - prevent changes in protected areas
---@param tiles table Array of tile changes to process  
---@param surface LuaSurface Surface where tiles will be changed
---@param requesting_player LuaPlayer? Player making the terrain changes
---@return number blocked_count Number of tile changes blocked by protection
function ChartTagUtils.process_terrain_changes_with_protection(tiles, surface, requesting_player)
  if not tiles or #tiles == 0 or not surface or not surface.valid then return 0 end
  
  -- Filter tiles based on chart tag protection
  local filtered_tiles, blocked_tiles = ChartTagUtils.filter_protected_tiles(tiles, surface, requesting_player)
  
  -- If any tiles were blocked, we need to revert them since the event fires after changes
  if #blocked_tiles > 0 then
    -- Revert blocked tile changes by restoring their original state
    local revert_tiles = {}
    for _, block_data in ipairs(blocked_tiles) do
      local tile_data = block_data.tile
      if tile_data.position and tile_data.old_tile_name then
        -- Revert to the original tile type
        table.insert(revert_tiles, {
          name = tile_data.old_tile_name,
          position = tile_data.position
        })
      end
    end
    
    -- Apply the reverted tiles if we have any
    if #revert_tiles > 0 then
      surface:set_tiles(revert_tiles)
    end
    
    -- Notify player about blocked changes
    if requesting_player and requesting_player.valid then
      ChartTagUtils.notify_terrain_protection(requesting_player, blocked_tiles)
    end
  end
  
  return #blocked_tiles
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
  
  -- Get the player who made the change (if applicable)
  local requesting_player = nil
  if event.player_index then
    requesting_player = game.get_player(event.player_index)
  end
  
  -- Use the new protection system instead of relocation
  ChartTagUtils.process_terrain_changes_with_protection(event.tiles, surface, requesting_player)
end

--- Register event handlers for chart tag terrain management
---@param script table The global script object
function ChartTagUtils.register_terrain_events(script)
  if not script then return end

  -- Register for tile built/removed events
  script.on_event(defines.events.on_player_built_tile, ChartTagUtils.on_tile_built)
  script.on_event(defines.events.on_robot_built_tile, ChartTagUtils.on_tile_built)  script.on_event(defines.events.on_player_mined_tile, ChartTagUtils.on_tile_built)
  script.on_event(defines.events.on_robot_mined_tile, ChartTagUtils.on_tile_built)
  
  -- Script-caused terrain changes
  script.on_event(defines.events.script_raised_set_tiles, function(event)
    if not event or not event.tiles or #event.tiles == 0 then return end
    -- Script changes don't have a specific player, so pass nil
    ChartTagUtils.process_terrain_changes_with_protection(event.tiles, event.surface, nil)
  end)
end

-- ========================================
-- CHART TAG CREATION WRAPPER
-- ========================================

--- Safe wrapper for chart tag creation with comprehensive error handling
---@param force LuaForce The force that will own the chart tag
---@param surface LuaSurface The surface where the tag will be placed
---@param spec table Chart tag specification table (position, text, etc.)
---@return LuaCustomChartTag|nil chart_tag The created chart tag or nil if failed
function ChartTagUtils.safe_add_chart_tag(force, surface, spec)
  -- Input validation
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end

  -- Validate position
  if not spec.position or type(spec.position.x) ~= "number" or type(spec.position.y) ~= "number" then
    ErrorHandler.debug_log("Invalid position in chart tag spec", {
      position = spec.position
    })
    return nil
  end  -- Use protected call to catch any errors
  local success, result = pcall(function()
    return force.add_chart_tag(surface, spec)
  end)

  -- Check if creation was successful
  if not success then
    ErrorHandler.debug_log("Chart tag creation failed with error", {
      error = result,
      position = spec.position
    })
    return nil
  end

  -- Cast result to ensure proper typing after successful pcall
  ---@cast result LuaCustomChartTag
  
  -- Validate the created chart tag
  if not result or not result.valid then
    ErrorHandler.debug_log("Chart tag created but is invalid", {
      chart_tag_exists = result ~= nil,
      position = spec.position
    })
    return nil
  end

  ErrorHandler.debug_log("Chart tag created successfully", {
    position = result.position,
    text = result.text
  })

  return result
end

return ChartTagUtils
