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
-- Mod initialization logic
- handlers.on_init()
-- Runtime-only structure re-initialization
- handlers.on_load()
-- New player initialization
- handlers.on_player_created(event)
-- Ensures surface cache for player after surface change
- handlers.on_player_changed_surface(event)
-- Handles right-click chart tag editor opening
- handlers.on_open_tag_editor_custom_input(event)
-- Teleports player to favorite location
-- Handles chart tag creation (stub)
- handlers.on_chart_tag_added(event)
-- Handles chart tag modification, GPS and favorite updates
- handlers.on_chart_tag_modified(event)
-- Handles chart tag removal and cleanup
- handlers.on_chart_tag_removed(event)

--]]

---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- Centralized event handler implementations for TeleportFavorites

local Cache = require("core.cache.cache")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local CursorUtils = require("core.utils.cursor_utils")
local tag_editor = require("gui.tag_editor.tag_editor")
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
local Settings = require("core.utils.settings_access")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Enum = require("prototypes.enums.enum")
local FaveBarGuiLabelsManager = require("core.control.fave_bar_gui_labels_manager")

-- Helper: Validate player and run handler logic
local function with_valid_player(player_index, handler_fn, ...)
  local player = game.get_player(player_index)
  if not player or not player.valid then return end
  return handler_fn(player, ...)
end

local function register_gui_observers(player)
  local ok, gui_observer = pcall(require, "core.pattern.gui_observer")
end

local handlers = {}

function handlers.on_init()
  ErrorHandler.debug_log("Mod initialization started")
  Cache.init()
  
  for _, player in pairs(game.players) do
    register_gui_observers(player)
    fave_bar.build(player)
  end
  
  -- Register the label managers AFTER GUI is built
  FaveBarGuiLabelsManager.register_all(script)
  
  -- Initialize labels for all existing players AFTER registration and GUI building
  FaveBarGuiLabelsManager.initialize_all_players(script)
  
  ErrorHandler.debug_log("Mod initialization completed")
end

function handlers.on_load()
  -- Re-initialize runtime-only structures if needed
  -- Re-register label managers for existing game AFTER ensuring GUIs exist
  FaveBarGuiLabelsManager.register_all(script)
  
  -- Initialize labels for all connected players in loaded games
  FaveBarGuiLabelsManager.initialize_all_players(script)
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    Cache.reset_transient_player_states(player)
    fave_bar.build(player)
    register_gui_observers(player)
    -- Force update labels after GUI is built
    FaveBarGuiLabelsManager.force_update_labels_for_player(player)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    fave_bar.build(player)
    -- Force update labels after GUI is built
    FaveBarGuiLabelsManager.force_update_labels_for_player(player)
  end)
end

function handlers.on_open_tag_editor_custom_input(event)
  with_valid_player(event.player_index, function(player)
    ErrorHandler.debug_log("Tag editor custom input handler called", {
      player_index = event.player_index,
      cursor_position = event.cursor_position
    })

    local can_open, reason = TagEditorEventHelpers.validate_tag_editor_opening(player)
    if not can_open then
      ErrorHandler.debug_log("Tag editor handler: " .. (reason or "validation failed"))
      if reason == "Drag mode active" then
        CursorUtils.end_drag_favorite(player)
        if player and player.play_sound then
          player.play_sound { path = "utility/cancel" }
        end
      end
      return
    end

    local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
    local cursor_position = event.cursor_position
    local chart_tag = nil

    if cursor_position and cursor_position.x and cursor_position.y then
      local surface_index = player.surface.index
      local click_radius = Settings.get_chart_tag_click_radius(player)
      chart_tag = TagEditorEventHelpers.find_nearby_chart_tag(cursor_position, surface_index, click_radius)
    end

    if chart_tag and chart_tag.valid then
      local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(chart_tag.surface and chart_tag.surface.index or player.surface.index) or 1)
      local tag_fave = Cache.get_tag_by_gps(player, gps)
      local player_favorites = PlayerFavorites.new(player)
      local favorite_entry, favorite_slot = player_favorites:get_favorite_by_gps(gps)
      local is_favorite = favorite_entry ~= nil
      local icon = chart_tag and chart_tag["icon"] or nil
      -- Do NOT attempt to access chart_tag.tag (property does not exist on LuaCustomChartTag)
      -- The tag_fave structure doesn't have a direct icon field
      -- We'll avoid looking for it to prevent errors
      -- The main icon will be used from the chart_tag

      -- If there is no matching tag in our mod data, still load chart_tag info into the editor
      tag_data.chart_tag = chart_tag
      tag_data.tag = {
        chart_tag = chart_tag,
        gps = gps,
        icon = icon,
        text = chart_tag and chart_tag.text or nil,
        last_user = chart_tag and chart_tag.last_user or nil,
      }
      tag_data.gps = gps
      tag_data.is_favorite = is_favorite
      tag_data.icon = icon
      tag_data.text = chart_tag and chart_tag.text or nil
    elseif tag_data.tag and tag_data.tag.gps and tag_data.tag.gps ~= "" then
      tag_data.gps = tag_data.tag.gps
    elseif cursor_position and cursor_position.x and cursor_position.y then
      tag_data.gps = GPSUtils.gps_from_map_position(cursor_position, tonumber(player.surface.index) or 1)
    end

    Cache.set_tag_editor_data(player, tag_data)
    tag_editor.build(player)
  end)
end
function handlers.on_chart_tag_added(event)
  -- Get the player object from the event.player_index
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  -- Ensure the position of the added tag is normalized
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag added with fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position
      })
      -- Delete the original tag and create a new one at normalized coords
      local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
      -- Optionally, you may want to update lookups here as well
    end
  end

  -- Invalidate/refresh the lookups for chart tags for this surface
  if Cache and Cache.Lookups and Cache.Lookups.invalidate_surface_chart_tags then
    Cache.Lookups.invalidate_surface_chart_tags(player.surface.index)
  end
end

function handlers.on_chart_tag_modified(event)
  with_valid_player(event.player_index, function(player)

    if not ChartTagModificationHelpers.is_valid_tag_modification(event, player) then 
      ErrorHandler.debug_log("Chart tag modification validation failed", {
        player_name = player.name
      })
      return 
    end
    local new_gps, old_gps = ChartTagModificationHelpers.extract_gps(event, player)
    
    -- Check if this tag is currently open in the tag editor and update it
    local tag_editor_data = Cache.get_tag_editor_data(player)
    if tag_editor_data and tag_editor_data.gps == old_gps then
      -- Update the GPS in tag editor data
      tag_editor_data.gps = new_gps
      if tag_editor_data.tag then
        tag_editor_data.tag.gps = new_gps
      end
      Cache.set_tag_editor_data(player, tag_editor_data)
      
      -- Update the teleport button caption to show new coordinates
      local tag_editor_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
      if tag_editor_frame and tag_editor_frame.valid then
        local teleport_btn = GuiValidation.find_child_by_name(tag_editor_frame, "tag_editor_teleport_button")
        if teleport_btn and teleport_btn.valid then
          ---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
          local coords_result = GPSUtils.coords_string_from_gps(new_gps)
          local coords = coords_result or ""
          ---@diagnostic disable-next-line: assign-type-mismatch
          teleport_btn.caption = {"tf-gui.teleport_to", coords}
        end
      end
    end
    
    local chart_tag = event.tag
    if chart_tag and chart_tag.valid and chart_tag.position then
      -- Only normalize if the tag position has fractional coordinates
      local needs_normalization = PositionUtils.needs_normalization(chart_tag.position)
      
      if needs_normalization then
        ErrorHandler.debug_log("Chart tag has fractional coordinates, normalizing", {
          player_name = player.name,
          position = chart_tag.position,
          old_gps = old_gps,
          new_gps = new_gps
        })
        
        local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
        if new_chart_tag then
          -- After normalization, recalculate GPS coordinates for the new chart tag
          local surface_index = new_chart_tag.surface and new_chart_tag.surface.index or 1
          local normalized_gps = GPSUtils.gps_from_map_position(new_chart_tag.position, tonumber(surface_index) or 1)

          -- Update using the normalized GPS as the final new GPS
          if old_gps and normalized_gps and old_gps ~= normalized_gps then
            -- Create a modified event with the new chart tag for cleanup
            local normalized_event = {
              tag = new_chart_tag,
              old_position = event.old_position,
              player_index = event.player_index
            }
            
            ChartTagModificationHelpers.update_tag_and_cleanup(old_gps, normalized_gps, normalized_event, player)
            ChartTagModificationHelpers.update_favorites_gps(old_gps, normalized_gps, player)
          end
        end
      else
        if old_gps and new_gps and old_gps ~= new_gps then
          -- Update tag data and cache using the original chart tag
          ChartTagModificationHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
          
          -- Update all player favorites that reference this GPS
          ChartTagModificationHelpers.update_favorites_gps(old_gps, new_gps, player)
        end
      end
    end
  end)
end

function handlers.on_chart_tag_removed(event)
  -- No-op for now. Add cleanup logic here if needed.
end

return handlers
