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
local _PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Constants = require("constants")
local _Favorite = require("core.favorite.favorite")
local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local _Settings = require("settings")
local Helpers = require("core.utils.helpers_suite")
local gps_helpers = require("core.utils.gps_helpers")
local gps_parser = require("core.utils.gps_parser")
local basic_helpers = require("core.utils.basic_helpers")
local GPSCore = require("core.utils.gps_core")
local Lookups = require("core.cache.lookups")
local RichTextFormatter = require("core.utils.rich_text_formatter")

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
    player:print({ "tf-handler.teleport-favorite-no-location" })
    return
  end
  local favorite = favorites[i]
  if type(favorite) == "table" and favorite.gps ~= nil then
    ---@diagnostic disable-next-line: param-type-mismatch
    local result = Tag.teleport_player_with_messaging(player, favorite.gps)
    if result ~= Enum.ReturnStateEnum.SUCCESS then
      ---@diagnostic disable-next-line: param-type-mismatch
      player:print(result)
    end
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    player:print({ "tf-handler.teleport-favorite-no-location" })
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
    
    if player and player.valid and player.force and chart_tag.surface then
      -- Create new chart tag at normalized position
      local new_chart_tag = player.force.add_chart_tag(
        chart_tag.surface,
        {
          position = new_position,
          icon = chart_tag.icon,
          text = chart_tag.text,
          last_user = chart_tag.last_user or player.name
        }
      )
      
      if new_chart_tag and new_chart_tag.valid then
        -- Destroy the old chart tag with fractional coordinates
        chart_tag.destroy()
        
        -- Refresh the cache to include the new chart tag
        Lookups.invalidate_surface_chart_tags(surface_index)
        
        -- Inform the player about the position normalization
        player.print(RichTextFormatter.position_change_notification(
          player,
          new_chart_tag,
          old_position,
          new_position, 
          surface_index
        ))
      end
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
  
  if event.tag.position and player then
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
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context
local function update_tag_and_cleanup(old_gps, new_gps, event, player)
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
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@param acting_player LuaPlayer|nil Player who initiated the change
local function update_favorites_gps(old_gps, new_gps, acting_player)
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
    
    -- Add player to notification list if affected and not the initiator
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
    if old_gps then
      local parts = {}
      for part in string.gmatch(old_gps, "[^.]+") do
        table.insert(parts, part)
      end
      if #parts >= 3 then
        surface_index = tonumber(parts[3]) or 1
      end
    end
    
    -- Get chart tag for better notification
    local chart_tag = nil
    if new_gps then
      chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    end
    
    for _, affected_player in ipairs(affected_players) do
      if affected_player and affected_player.valid then
        affected_player.print(RichTextFormatter.position_change_notification(
          affected_player,
          chart_tag,
          old_position or {x=0, y=0},
          new_position or {x=0, y=0},
          surface_index
        ))
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
  if not new_gps or not old_gps then return end
  
  -- Check for need to normalize coordinates
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local position = chart_tag.position
    
    -- Ensure coordinates are whole numbers
    if not basic_helpers.is_whole_number(position.x) or not basic_helpers.is_whole_number(position.y) then
      local old_position = {x = position.x, y = position.y}
      local new_position = {
        x = basic_helpers.normalize_index(position.x),
        y = basic_helpers.normalize_index(position.y)
      }
      
      if player and player.valid and player.force and chart_tag.surface then
        -- Create new chart tag with normalized position
        local surface = chart_tag.surface
        local new_chart_tag = player.force.add_chart_tag(
          surface,
          {
            position = new_position,
            icon = chart_tag.icon,
            text = chart_tag.text,
            last_user = chart_tag.last_user or player.name
          }
        )
        
        if new_chart_tag and new_chart_tag.valid then
          -- Destroy the old chart tag with fractional coordinates
          chart_tag.destroy()
          
          -- Update the tag and gps
          local surface_index = surface and surface.index or 1
          new_gps = gps_parser.gps_from_map_position(new_position, surface_index)
          
          -- Refresh the cache
          Lookups.invalidate_surface_chart_tags(surface_index)
          
          -- Update chart_tag reference for future operations
          chart_tag = new_chart_tag
          
          -- Notify the player about the normalization
          player.print(RichTextFormatter.position_change_notification(
            player, 
            new_chart_tag,
            old_position,
            new_position,
            surface_index
          ))
        end
      end
    end
  end
  
  update_tag_and_cleanup(old_gps, new_gps, event, player)
  
  -- Update favorites GPS and notify affected players
  if old_gps ~= new_gps then
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
  local tag = Cache.get_tag_by_gps(gps)
  
  -- Get the player who is removing the chart tag
  local player = event.player_index and game.get_player(event.player_index) or nil
  
  -- Check if this tag has favorites from other players
  if tag and tag.faved_by_players and #tag.faved_by_players > 0 and player and player.valid then
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
      local new_chart_tag = player.force.add_chart_tag(
        chart_tag.surface,
        {
          position = chart_tag.position,
          icon = chart_tag.icon,
          text = chart_tag.text,
          last_user = owner
        }
      )
      
      if new_chart_tag and new_chart_tag.valid then
        -- Update the tag with the new chart tag reference
        tag.chart_tag = new_chart_tag
        
        -- Refresh the cache
        Lookups.invalidate_surface_chart_tags(surface_index)
        
        -- Notify the player
        player.print(RichTextFormatter.deletion_prevention_notification(new_chart_tag))
        return
      end
    end
  end
  
  -- Only destroy if the chart tag is not already being destroyed by our helper
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end

return handlers
