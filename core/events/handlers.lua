-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\events\handlers.lua
--[[
core/events/handlers.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized event handler implementations for TeleportFavorites.

Features:
- Handles Factorio events for tag creation, modification, removal, and player actions
- Ensures robust multiplayer and surface-aware updates to tags, chart tags, and player favorites
- Uses helpers for tag destruction, GPS conversion, and cache management
- All event logic is routed through this module for maintainability and separation of concerns
- Comprehensive error handling and validation for all event types
- Type-safe player retrieval and validation

Architecture:
- Event handlers are pure functions that receive event objects
- All handlers validate inputs and handle edge cases gracefully
- Player objects are properly null-checked to prevent runtime errors
- GPS position normalization is handled through centralized helpers
- Surface and multi-player compatibility is maintained throughout

API:
-----
- handlers.on_init()                              -- Mod initialization logic
- handlers.on_load()                              -- Runtime-only structure re-initialization
- handlers.on_player_created(event)               -- New player initialization
- handlers.on_player_changed_surface(event)      -- Ensures surface cache for player after surface change
- handlers.on_open_tag_editor_custom_input(event) -- Handles right-click chart tag editor opening
- handlers.on_teleport_to_favorite(event, i)     -- Teleports player to favorite location
- handlers.on_chart_tag_added(event)             -- Handles chart tag creation (stub)
- handlers.on_chart_tag_modified(event)          -- Handles chart tag modification, GPS and favorite updates
- handlers.on_chart_tag_removed(event)           -- Handles chart tag removal and cleanup

--]]

---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- Centralized event handler implementations for TeleportFavorites

local Tag = require("core.tag.tag")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local Settings = require("core.utils.settings_access")
local gps_helpers = require("core.utils.gps_helpers")
local gps_parser = require("core.utils.gps_parser")
local basic_helpers = require("core.utils.basic_helpers")
local GPSCore = require("core.utils.gps_core")
local Lookups = require("core.cache.lookups")
local RichTextFormatter = require("__TeleportFavorites__.core.utils.rich_text_formatter")
local GPSChartHelpers = require("core.utils.gps_chart_helpers")
local GameHelpers = require("core.utils.game_helpers")
local PositionValidator = require("core.utils.position_validator")

local handlers = {}

function handlers.on_init()
  for _, player in pairs(game.players) do
    local parent = player.gui.top
    fave_bar.build(player, parent)
  end
end

function handlers.on_load()
  -- Re-initialize runtime-only structures if needed
end

function handlers.on_player_created(event)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  local parent = player.gui.top
  fave_bar.build(player, parent)
end

function handlers.on_player_changed_surface(event)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  local parent = player.gui.top
  fave_bar.build(player, parent)
end

--- Handles right-click on the chart view to open tag editor
---@param event table Event data containing player_index and cursor_position
function handlers.on_open_tag_editor_custom_input(event)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  -- Only handle chart mode interactions
  if player.render_mode ~= defines.render_mode.chart and player.render_mode ~= defines.render_mode.chart_zoomed_in then 
    return 
  end

  -- Check if tag editor is already open - if so, ignore right-click events
  local tag_editor_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if tag_editor_frame and tag_editor_frame.valid then
    return -- Tag editor is open, ignore right-click
  end

  local surface = player.surface
  local surface_id = surface.index

  -- Get the position we right-clicked upon
  local cursor_position = event.cursor_position
  if not cursor_position or not (cursor_position.x and cursor_position.y) then
    return
  end
  
  -- Normalize the clicked position and convert to GPS string
  local normalized_gps = gps_parser.gps_from_map_position(cursor_position, player.surface.index)
  local nrm_pos, nrm_tag, nrm_chart_tag, nrm_favorite = gps_helpers.normalize_landing_position_with_cache(player, normalized_gps, Cache)
  if not nrm_pos then
    -- TODO: play a sound to indicate invalid position
    return
  end
  local gps = gps_helpers.gps_from_map_position(nrm_pos, surface_id)
  
  -- Get player's teleport radius setting for use in tag editor
  local player_settings = Settings:getPlayerSettings(player)
  local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  
  local tag_data = Cache.create_tag_editor_data({
    gps = gps,
    locked = nrm_favorite and nrm_favorite.locked or false,
    is_favorite = nrm_favorite ~= nil,
    icon = nrm_chart_tag and nrm_chart_tag.icon or "",
    text = nrm_chart_tag and nrm_chart_tag.text or "",
    tag = nrm_tag or nil,
    chart_tag = nrm_chart_tag or nil,
    search_radius = search_radius
  })

  -- Persist GPS in tag_editor_data
  Cache.set_tag_editor_data(player, tag_data)
  tag_editor.build(player)
end

--- Teleport player to a specific favorite slot
---@param event table Event data containing player_index
---@param i number Favorite slot index (1-based)
function handlers.on_teleport_to_favorite(event, i)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  ---@diagnostic disable-next-line: param-type-mismatch
  local favorites = Cache.get_player_favorites(player)
  if type(favorites) ~= "table" or not i or not favorites[i] then
    ---@diagnostic disable-next-line: param-type-mismatch
    GameHelpers.player_print(player, { "tf-handler.teleport-favorite-no-location" })
    return
  end
  local favorite = favorites[i]
  if type(favorite) == "table" and favorite.gps ~= nil then    ---@diagnostic disable-next-line: param-type-mismatch
    local result = Tag.teleport_player_with_messaging(player, favorite.gps)
    if result ~= Enum.ReturnStateEnum.SUCCESS then
      ---@diagnostic disable-next-line: param-type-mismatch
      GameHelpers.player_print(player, result)
    end
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    GameHelpers.player_print(player, { "tf-handler.teleport-favorite-no-location" })
  end
end

--- Handle chart tag added events
---@param event table Event data for tag addition
function handlers.on_chart_tag_added(event)
  -- Handle automatic tag synchronization when players create chart tags outside of the mod interface
  if not event or not event.tag or not event.tag.valid then return end
  
  local chart_tag = event.tag
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not player or not player.valid then return end
  
  -- Check if the chart tag coordinates need normalization
  local position = chart_tag.position
  if not position then return end
  
  local surface_index = chart_tag.surface and chart_tag.surface.index or 1
  
  if not basic_helpers.is_whole_number(position.x) or not basic_helpers.is_whole_number(position.y) then
    -- Need to normalize this chart tag to whole numbers
    local old_position = {x = position.x, y = position.y}
    local new_position = {
      x = basic_helpers.normalize_index(position.x),
      y = basic_helpers.normalize_index(position.y)
    }
      -- Create new chart tag at normalized position
    -- Prepare chart_tag_spec properly
    local chart_tag_spec = {
      position = new_position,
      text = chart_tag.text or "Tag", -- Ensure text is never nil
      last_user = chart_tag.last_user or player.name
    }
    -- Only include icon if it's a valid SignalID
    if chart_tag.icon and type(chart_tag.icon) == "table" and chart_tag.icon.name then
      chart_tag_spec.icon = chart_tag.icon
    end
    
    local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec)
    
    if new_chart_tag and new_chart_tag.valid then
      -- Destroy the old chart tag with fractional coordinates
      chart_tag.destroy()
        -- Refresh the cache to include the new chart tag
      Lookups.invalidate_surface_chart_tags(surface_index)      -- Inform the player about the position normalization
      local notification_msg = RichTextFormatter.position_change_notification(
        player,
        new_chart_tag,
        old_position,
        new_position, 
        surface_index
      )
      GameHelpers.player_print(player, notification_msg)
    end
  end
  
  -- Update the cache
  Lookups.invalidate_surface_chart_tags(surface_index)
end

--- Validate if a tag modification event is valid
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player who triggered the modification
---@return boolean valid True if modification should be processed
local function is_valid_tag_modification(event, player)
  if not player or not player.valid then return false end
  if not event.tag or not event.tag.valid then return false end
  
  -- Set last_user if not present
  if not event.tag.last_user or event.tag.last_user == "" then
    event.tag.last_user = player.name
  end
  
  -- Only allow modifications by the last user (owner)
  if not event.tag.last_user or event.tag.last_user ~= player.name then
    return false
  end
  
  return true
end

--- Extract GPS coordinates from tag modification event
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context for surface fallbacks
---@return string|nil new_gps New GPS coordinate string
---@return string|nil old_gps Old GPS coordinate string
local function extract_gps(event, player)
  local new_gps = nil
  local old_gps = nil
  
  if event.tag and event.tag.position and player then
    local surface_index = (event.tag.surface and event.tag.surface.index) or player.surface.index
    new_gps = gps_parser.gps_from_map_position(event.tag.position, surface_index)
  end
  
  if event.old_position and player then
    local surface_index = (event.old_surface and event.old_surface.index) or player.surface.index
    old_gps = gps_parser.gps_from_map_position(event.old_position, surface_index)
  end
  
  return new_gps, old_gps
end

--- Get or create chart tag for new GPS position
---@param new_gps string New GPS coordinate string
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context
---@return LuaCustomChartTag|nil chart_tag Chart tag object or nil if creation failed
local function get_or_create_chart_tag(new_gps, event, player)
  local old_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
  if not old_chart_tag and player then
    -- Clear cache and retry lookup
    local surface_index = (event.tag.surface and event.tag.surface.index) or player.surface.index
    Lookups.clear_chart_tag_cache(surface_index)
    old_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    if not old_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end
  return old_chart_tag
end

--- Update tag data and cleanup old chart tag
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context
local function update_tag_and_cleanup(old_gps, new_gps, event, player)
  if not old_gps or not new_gps then return end
  
  local old_chart_tag = Lookups.get_chart_tag_by_gps(old_gps)
  local new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
  
  -- Ensure new chart tag exists
  if not new_chart_tag and player then
    local surface_index = (event.tag.surface and event.tag.surface.index) or player.surface.index
    Lookups.clear_chart_tag_cache(surface_index)
    new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    if not new_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end
  
  -- Get or create tag object
  local old_tag = Cache.get_tag_by_gps(old_gps)
  if not old_tag then
    old_tag = Tag.new(new_gps, {})
  end
  
  -- Update tag with new coordinates and chart tag reference
  old_tag.gps = new_gps
  old_tag.chart_tag = new_chart_tag
  
  -- Clean up old chart tag if it exists and is different from new one
  if old_chart_tag and old_chart_tag.valid and old_chart_tag ~= new_chart_tag then
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag)
  end
end

--- Update all player favorites that reference the old GPS to use new GPS and notify affected players
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param acting_player LuaPlayer|nil Player who initiated the change
local function update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end
  
  local affected_players = {}
  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil
  
  for _, p in pairs(game.players) do
    local pfaves = Cache.get_player_favorites(p)
    local player_affected = false
    
    for _, fav in ipairs(pfaves) do
      if fav.gps == old_gps then 
        fav.gps = new_gps
        player_affected = true
      end
    end
    
    if player_affected and p.valid and p.index ~= acting_player_index then
      table.insert(affected_players, p)
    end
  end
  
  -- Notify affected players about their favorite location changes
  if #affected_players > 0 then
    local old_position = GPSCore.map_position_from_gps(old_gps)
    local new_position = GPSCore.map_position_from_gps(new_gps)
    
    -- Extract surface_index from the GPS string
    local surface_index = 1
    local parts = {}
    for part in string.gmatch(old_gps, "[^.]+") do
      table.insert(parts, part)
    end
    if #parts >= 3 then
      surface_index = tonumber(parts[3]) or 1
    end
    
    -- Get chart tag for better notification
    local chart_tag = Lookups.get_chart_tag_by_gps(new_gps)    for _, affected_player in ipairs(affected_players) do
      if affected_player and affected_player.valid then
        local position_msg = RichTextFormatter.position_change_notification(
          affected_player,
          chart_tag,
          old_position or {x=0, y=0},
          new_position or {x=0, y=0},
          surface_index
        )
        GameHelpers.player_print(affected_player, position_msg)
      end
    end
  end
end

--- Handle chart tag modification events
---@param event table Chart tag modification event data
function handlers.on_chart_tag_modified(event)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not is_valid_tag_modification(event, player) then return end
  
  local new_gps, old_gps = extract_gps(event, player)
  
  -- Check for need to normalize coordinates
  local chart_tag = event.tag
  ---@cast player LuaPlayer
  if chart_tag and chart_tag.valid and chart_tag.position and player and player.valid then
    local position = chart_tag.position
    
    -- Ensure coordinates are whole numbers
    if not basic_helpers.is_whole_number(position.x) or not basic_helpers.is_whole_number(position.y) then
      local old_position = {x = position.x, y = position.y}
      local new_position = {
        x = basic_helpers.normalize_index(position.x),
        y = basic_helpers.normalize_index(position.y)
      }
      
      -- Create new chart tag with normalized position
      local surface = chart_tag.surface
      
      -- Prepare chart_tag_spec properly
      local chart_tag_spec = {
        position = new_position,
        text = chart_tag.text or "Tag", -- Ensure text is never nil
        last_user = chart_tag.last_user or player.name
      }      -- Only include icon if it's a valid SignalID
      if chart_tag.icon and type(chart_tag.icon) == "table" and chart_tag.icon.name then
        chart_tag_spec.icon = chart_tag.icon
      end
      
      local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, surface, chart_tag_spec)
      
      if new_chart_tag and new_chart_tag.valid then
        -- Destroy the old chart tag with fractional coordinates
        chart_tag.destroy()
        
        -- Update the tag and gps
        local surface_index = surface and surface.index or 1        -- Cast new_position to ensure it's a MapPosition
        local map_position = {x = math.floor(new_position.x or 0), y = math.floor(new_position.y or 0)}
        new_gps = gps_parser.gps_from_map_position(map_position, surface_index)
        
        -- Refresh the cache
        Lookups.invalidate_surface_chart_tags(surface_index)
          -- Update chart_tag reference for future operations
        chart_tag = new_chart_tag        -- Notify the player about the normalization
        local notification_msg = RichTextFormatter.position_change_notification(
          player, 
          new_chart_tag,
          old_position,
          new_position,
          surface_index
        )
        GameHelpers.player_print(player, notification_msg)
      end
    end
  end
  
  update_tag_and_cleanup(old_gps, new_gps, event, player)
  
  -- Update favorites GPS and notify affected players
  if old_gps and new_gps and old_gps ~= new_gps then
    update_favorites_gps(old_gps, new_gps, player)
  end
end

--- Handle chart tag removal events
---@param event table Chart tag removal event data
function handlers.on_chart_tag_removed(event)
  if not event or not event.tag or not event.tag.valid then return end
  
  local chart_tag = event.tag
  local surface_index = (chart_tag.surface and chart_tag.surface.index) or 1
  local gps = gps_parser.gps_from_map_position(chart_tag.position, surface_index)
  local tag = Cache.get_tag_by_gps(gps)  -- Get the player who is removing the chart tag
  local player = event.player_index and game.get_player(event.player_index) or nil
  -- Check if this tag has favorites from other players
  if tag and tag.faved_by_players and #tag.faved_by_players > 0 then
    if not player or not player.valid then
      -- No valid player to handle the removal, just clear the cache
      Lookups.invalidate_surface_chart_tags(surface_index)
      return
    end
    ---@cast tag -nil
    -- Check if any favorites belong to other players
    local has_other_players_favorites = false
    local owner = chart_tag.last_user or ""
    
    for _, fav_player_index in ipairs(tag.faved_by_players) do
      local fav_player = game.get_player(fav_player_index)
      if fav_player and fav_player.valid and fav_player.name ~= player.name then
        has_other_players_favorites = true
        break
      end
    end
      -- If other players have favorited this tag, prevent deletion
    if has_other_players_favorites and player.name == owner and player.force then
      -- Recreate the chart tag since it was already removed by the event
      
      -- Prepare chart_tag_spec properly
      local chart_tag_spec = {
        position = chart_tag.position,
        text = chart_tag.text or "Tag", -- Ensure text is never nil
        last_user = owner
      }
      -- Only include icon if it's a valid SignalID
      if chart_tag.icon and type(chart_tag.icon) == "table" and chart_tag.icon.name then
        chart_tag_spec.icon = chart_tag.icon
      end
      
      local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec)
      
      if new_chart_tag and new_chart_tag.valid then
        -- Update the tag with the new chart tag reference
        tag.chart_tag = new_chart_tag
        
        -- Refresh the cache
        Lookups.invalidate_surface_chart_tags(surface_index)        -- Notify the player
        local deletion_msg = RichTextFormatter.deletion_prevention_notification(new_chart_tag)
        GameHelpers.player_print(player, deletion_msg)
        return
      end
    end
  end
  
  -- Only destroy if the chart tag is not already being destroyed by our helper
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end

--- Handles Ctrl+Shift+Right-click to display tile debugging information
---@param event table Event data containing player_index and cursor_position
function handlers.on_debug_tile_info_custom_input(event)
  -- Debug logging
  log("[TF Debug] Handler called with event: " .. serpent.line(event))
    local player = game.get_player(event.player_index)
  if not player or not player.valid then 
    log("[TF Debug] Invalid player: " .. tostring(event.player_index))
    return 
  end
  
  -- Check if cursor position is available
  if not event.cursor_position then
    GameHelpers.player_print(player, "[TF Debug] No cursor position available")
    log("[TF Debug] No cursor position in event")
    return
  end
  local pos = event.cursor_position
  local surface = player.surface
  
  -- Get tile at position
  local tile = surface:get_tile(pos.x, pos.y)
  if not tile then
    GameHelpers.player_print(player, "[TF Debug] No tile found at position")
    return
  end

  -- Gather comprehensive tile information
  local tile_name = tile.name or "unknown"
  local tile_prototype = tile.prototype
  
  -- Create debug information string
  local debug_info = {}
  table.insert(debug_info, "=== TILE DEBUG INFO ===")
  table.insert(debug_info, "Position: " .. string.format("%.2f", pos.x) .. ", " .. string.format("%.2f", pos.y))
  table.insert(debug_info, "Tile name: " .. tile_name)
  
  -- Get tile prototype information if available
  if tile_prototype then
    local walking_speed = tile_prototype.walking_speed_modifier or 1.0
    table.insert(debug_info, "Walking speed modifier: " .. string.format("%.2f", walking_speed))
    
    if tile_prototype.layer then
      table.insert(debug_info, "Tile layer: " .. tile_prototype.layer)
    end
    
    if tile_prototype.collision_mask then
      local collision_layers = {}
      for layer_name, enabled in pairs(tile_prototype.collision_mask) do
        if enabled then
          table.insert(collision_layers, layer_name)
        end
      end
      if #collision_layers > 0 then
        table.insert(debug_info, "Collision layers: " .. table.concat(collision_layers, ", "))
      else
        table.insert(debug_info, "Collision layers: none")
      end
    end
  end
    -- Test walkability using our enhanced function
  local is_walkable = GameHelpers.is_walkable_position(surface, pos)
  table.insert(debug_info, "Is walkable (comprehensive): " .. tostring(is_walkable))
  
  -- Test individual checks
  local is_water = GameHelpers.is_water_tile(surface, pos)
  table.insert(debug_info, "Is water tile: " .. tostring(is_water))
  
  local is_space = GameHelpers.is_space_tile(surface, pos)
  table.insert(debug_info, "Is space tile: " .. tostring(is_space))
  
  -- Test pathfinding
  local pathfind_pos = surface:find_non_colliding_position("character", pos, 0, 0.1)
  if pathfind_pos then
    local dx = math.abs(pathfind_pos.x - pos.x)
    local dy = math.abs(pathfind_pos.y - pos.y)
    local distance = math.sqrt(dx*dx + dy*dy)    table.insert(debug_info, "Pathfinding result: " .. string.format("%.3f", pathfind_pos.x) .. 
                            ", " .. string.format("%.3f", pathfind_pos.y))
    table.insert(debug_info, "Distance from original: " .. string.format("%.3f", distance))
    table.insert(debug_info, "Pathfinding says walkable: " .. tostring(distance < 0.1))
  else
    table.insert(debug_info, "Pathfinding result: No valid position found")
  end
  
  -- Test position validation
  local is_valid_pos = PositionValidator.is_valid_tag_position(player, pos, true) -- skip notification
  table.insert(debug_info, "Valid for tagging: " .. tostring(is_valid_pos))
  
  -- Check for nearby chart tags
  local nearest_tag = GameHelpers.get_nearest_tag_to_click_position(player, pos, 5.0)
  if nearest_tag then
    local tag_distance = math.sqrt((nearest_tag.position.x - pos.x)^2 + (nearest_tag.position.y - pos.y)^2)
    table.insert(debug_info, "Nearest chart tag: " .. string.format("%.2f", tag_distance) .. " tiles away")
    if nearest_tag.text and nearest_tag.text ~= "" then
      table.insert(debug_info, "Tag text: " .. nearest_tag.text)
    end
  else
    table.insert(debug_info, "No chart tags nearby")
  end
  
  table.insert(debug_info, "=======================")
  -- Print all debug information
  for _, line in ipairs(debug_info) do
    GameHelpers.player_print(player, line)
  end
end

return handlers
