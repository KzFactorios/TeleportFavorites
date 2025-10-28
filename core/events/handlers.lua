---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- TeleportFavorites Factorio Mod
-- Centralized event handler implementations for TeleportFavorites.
-- Handles Factorio events, multiplayer/surface-aware updates, helpers, error handling, validation, and API for all event types.

local AdminUtils = require("core.utils.admin_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local CursorUtils = require("core.utils.cursor_utils")
local tag_editor = require("gui.tag_editor.tag_editor")
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Enum = require("prototypes.enums.enum")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local gui_observer = require("core.events.gui_observer")


-- Helper functions for surface refresh and captions

---@param surface_index number The surface index to refresh chart tags for
local function refresh_surface_chart_tags(surface_index)
  local safe_index = tonumber(surface_index) or 1
  -- Just call ensure_surface_cache, which internally handles cache invalidation
  Cache.ensure_surface_cache(safe_index)
end

-- Removed since we will set the caption directly

--- Validate player and run handler logic with early return pattern
---@param player_index number Player index from event
---@param handler_fn function Function to call with validated player
---@param ... any Additional arguments to pass to handler
---@return any Result from handler function, or nil if player invalid
-- Shared player validation using centralized helpers
local function with_valid_player(player_index, handler_fn, ...)
  if not player_index then return nil end
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return nil end
  return handler_fn(player, ...)
end

local handlers = {}

local function register_gui_observers(player)
  if not player or not player.valid then
    ErrorHandler.warn_log("Attempted to register observers for invalid player")
    return
  end

  ErrorHandler.debug_log("Starting GUI observer registration", {
    player = player.name,
    player_index = player.index
  })

  -- Initialize event bus
  gui_observer.GuiEventBus.ensure_initialized()

  -- Register player observers
  local register_ok, err = pcall(function()
    gui_observer.GuiEventBus.register_player_observers(player)
  end)

  if register_ok then
    ErrorHandler.debug_log("Successfully registered GUI observers", {
      player = player.name,
      player_index = player.index
    })
  else
    ErrorHandler.warn_log("Failed to register GUI observers", {
      player = player.name,
      error = err
    })
  end
end

function handlers.on_player_changed_surface(event)
  with_valid_player(event.player_index, function(player)
    if player.surface and player.surface.valid and player.surface.index ~= event.surface_index then
      Cache.ensure_surface_cache(event.surface_index)

      -- TODO build fave bar and optionally history modal

    end
  end)
end

function handlers.on_init()
  if log and type(log) == "function" then
    log("[TeleFaves][DEBUG] handlers.on_init() called (forced log)")
  end
  -- Initialize the GUI event bus first
  gui_observer.GuiEventBus.ensure_initialized()
  ErrorHandler.debug_log("GUI Event Bus initialized during startup")

  -- Initialize cache system
  Cache.init()

  -- Set up each player - defer GUI build to reduce startup UPS spike
  for _, player in pairs(game.players) do
    if Cache.get_player_data(player) == nil then
      Cache.reset_transient_player_states(player)
    end

    -- Register observers but defer GUI build until player joins
    register_gui_observers(player)
    -- Note: fave_bar.build() will be called when player joins via on_player_joined_game
  end
  
  ErrorHandler.debug_log("[INIT] Startup initialization complete - GUI build deferred to player join")
end

function handlers.on_load()
  -- Re-initialize GUI event bus on game load
  gui_observer.GuiEventBus.ensure_initialized()
  ErrorHandler.debug_log("GUI Event Bus re-initialized on game load")
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    -- PERFORMANCE: Defer ALL initialization by 60 ticks to eliminate startup UPS spike
    -- This includes cache initialization, observer registration, and GUI build
    local player_index = player.index
    script.on_nth_tick(60, function(event)
      local deferred_player = game.players[player_index]
      if deferred_player and deferred_player.valid then
        -- Reset player state
        Cache.reset_transient_player_states(deferred_player)
        -- Set up GUI observers
        register_gui_observers(deferred_player)
        -- Build GUI
        fave_bar.build(deferred_player, true)
      end
      -- Unregister this one-time handler
      script.on_nth_tick(60, nil)
    end)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    -- PERFORMANCE: Defer ALL initialization by 60 ticks to eliminate startup UPS spike
    -- This includes cache reset, observer cleanup/registration, and GUI build
    ErrorHandler.debug_log("Deferring initialization for rejoining player", {
      player = player.name,
      player_index = player.index
    })
    
    local player_index = player.index
    script.on_nth_tick(60, function(event)
      local deferred_player = game.players[player_index]
      if deferred_player and deferred_player.valid then
        -- Reset transient states
        Cache.reset_transient_player_states(deferred_player)
        -- Clean up and re-register observers
        gui_observer.GuiEventBus.cleanup_player_observers(deferred_player)
        register_gui_observers(deferred_player)
        -- Build GUI
        fave_bar.build(deferred_player, true)
      end
      -- Unregister this one-time handler
      script.on_nth_tick(60, nil)
    end)
  end)
end

function handlers.on_open_tag_editor_custom_input(event)
  with_valid_player(event.player_index, function(player)
    local can_open, reason = TagEditorEventHelpers.validate_tag_editor_opening(player)
    if not can_open then
      if reason == "Drag mode active" then
        CursorUtils.end_drag_favorite(player)
        if player and player.play_sound then
          player.play_sound { path = "utility/cannot_build" }
        end
      end
      return
    end

    local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
    local cursor_position = event.cursor_position
    local chart_tag = cursor_position and cursor_position.x and cursor_position.y and
        TagEditorEventHelpers.find_nearby_chart_tag(cursor_position, player.surface.index,
          Cache.Settings.get_chart_tag_click_radius(player))

    if chart_tag and chart_tag.valid then
      local gps = GPSUtils.gps_from_map_position(chart_tag.position,
        tonumber(chart_tag.surface and chart_tag.surface.index or player.surface.index) or 1)
      local player_favorites = PlayerFavorites.new(player)
      local favorite_entry = player_favorites:get_favorite_by_gps(gps)
      local icon = chart_tag.icon

      -- Try to get the full Tag object from cache (includes owner_name)
      local tag = Cache.get_tag_by_gps(player, gps)
      
      tag_data.chart_tag = chart_tag
      -- Use full Tag object if available, otherwise create minimal object
      if tag then
        tag_data.tag = tag
      else
        -- Create minimal Tag-like object for new/unknown tags
        tag_data.tag = {
          chart_tag = chart_tag,
          gps = gps,
          icon = icon,
          text = chart_tag.text,
          owner_name = nil,  -- New tag, no owner yet
          faved_by_players = {},  -- Empty array for new tags
        }
      end
      tag_data.gps = gps
      tag_data.is_favorite = favorite_entry ~= nil
      tag_data.icon = icon
      -- Cast to string with nil safety
      local chart_text = chart_tag.text
      tag_data.text = type(chart_text) == "string" and chart_text or ""
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
  -- Get the player object from the event.player_index (can be nil if added by script)
  if not event.player_index then
    ErrorHandler.debug_log("Chart tag added without player_index (added by script or other mod)")
    return
  end
  
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  -- Ensure the position of the added tag is normalized
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag added with fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position
      })
      local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
    end
  end

  local surface_index = player.surface and player.surface.valid and player.surface.index or 1
  refresh_surface_chart_tags(tonumber(surface_index) or 1)
  
  -- OWNERSHIP TRACKING: Store the creator's name in the Tag storage
  -- This is necessary because event.old_player_index is not reliable when admins move tags
  if chart_tag and chart_tag.valid then
    local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(surface_index) or 1)
    if gps then
      local tag = Cache.get_tag_by_gps(player, gps)
      if tag and type(tag) == "table" then
        tag.owner_name = player.name
        ErrorHandler.debug_log("Stored tag owner on creation", {
          gps = gps,
          owner_name = player.name
        })
      end
    end
  end
end

function handlers.on_chart_tag_modified(event)
  if not event or not event.old_position then return end
  
  -- Check for valid player_index (can be nil if modified by script)
  if not event.player_index then
    ErrorHandler.debug_log("Chart tag modified without player_index (modified by script or other mod)")
    return
  end
  
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  
  -- OWNERSHIP PRESERVATION: Get the original owner from our Tag storage
  -- event.old_player_index is unreliable (often nil), so we track ownership in Tag.owner_name
  local original_owner = nil
  local original_owner_name = nil
  
  -- Try to get owner from our stored Tag object first
  local old_gps, new_gps = ChartTagHelpers.extract_gps(event, player)
  if old_gps then
    local old_tag = Cache.get_tag_by_gps(player, old_gps)
    if old_tag and type(old_tag) == "table" and old_tag.owner_name then
      original_owner_name = old_tag.owner_name
      -- Find the player object by name
      for _, p in pairs(game.players) do
        if p.name == original_owner_name then
          original_owner = p
          break
        end
      end
      ErrorHandler.debug_log("Retrieved original owner from Tag storage", {
        player_who_moved = player.name,
        original_owner_name = original_owner_name,
        has_player_object = (original_owner ~= nil),
        old_gps = old_gps
      })
    end
  end
  
  -- Fallback to event.old_player_index if available
  if not original_owner_name and event.old_player_index then
    original_owner = game.players[event.old_player_index]
    if original_owner and original_owner.valid then
      original_owner_name = original_owner.name
    end
    ErrorHandler.debug_log("Retrieved original owner from event.old_player_index (fallback)", {
      player_who_moved = player.name,
      old_player_index = event.old_player_index,
      original_owner_name = original_owner_name
    })
  end
  
  if not ChartTagHelpers.is_valid_tag_modification(event, player) then
    ErrorHandler.debug_log("Chart tag modification validation failed", {
      player_name = player.name
    })
    return
  end
  
  -- CHARTED TERRITORY VALIDATION: Prevent moving tags into uncharted areas
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local surface = chart_tag.surface or player.surface
    local force = chart_tag.force or player.force
    
    -- Check if the new position is charted
    if surface and surface.valid and force and force.valid then
      -- Convert world position to chunk position for is_chunk_charted check
      local chunk_x = math.floor(chart_tag.position.x / 32)
      local chunk_y = math.floor(chart_tag.position.y / 32)
      local is_charted = force.is_chunk_charted(surface, {chunk_x, chunk_y})
      
      if not is_charted then
        -- Position is not charted - revert the tag to old position and play error sound
        chart_tag.position = event.old_position
        player.play_sound({path = "utility/cannot_build"})
        
        ErrorHandler.debug_log("Prevented tag move to uncharted territory", {
          player_name = player.name,
          attempted_position = chart_tag.position,
          attempted_chunk = {chunk_x, chunk_y},
          old_position = event.old_position,
          surface_name = surface.name
        })
        
        return
      end
    end
  end
  
  local new_gps, old_gps = ChartTagHelpers.extract_gps(event, player)
  
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
        local gps_string = new_gps --[[@as string]]
        local coords = GPSUtils.coords_string_from_gps(gps_string) or ""
        -- Set caption using make_teleport_caption helper
        -- Set caption directly - Factorio API handles localization internally
        ---@diagnostic disable-next-line: assign-type-mismatch
        teleport_btn.caption = {"tf-gui.teleport_to", coords}
      end
    end
  end
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local position_changed = old_gps and new_gps and old_gps ~= new_gps
    
    if PositionUtils.needs_normalization(chart_tag.position) then
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
          ChartTagHelpers.update_tag_and_cleanup(old_gps, normalized_gps, normalized_event, player, original_owner_name)
          ChartTagHelpers.update_favorites_gps(old_gps, normalized_gps, player)
        end
      end
      if old_gps and new_gps and old_gps ~= new_gps then
        -- Update tag data and cache using the original chart tag
        ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, original_owner_name)
        ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
      end
    elseif position_changed then
      -- If position changed but no normalization needed, still update tag and favorites
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, original_owner_name)
      ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
    else
      -- METADATA-ONLY CHANGE: Position unchanged, but text/icon may have changed
      -- Update tag metadata and refresh favorites bar for all affected players
      if new_gps then
        ChartTagHelpers.update_tag_metadata(new_gps, chart_tag, player)
      end
    end
    
    -- Ownership is preserved via Tag.owner_name field (no need to restore chart_tag.last_user)
  end
end

function handlers.on_chart_tag_removed(event)
  with_valid_player(event.player_index, function(player)
    local chart_tag = event.tag
    if not chart_tag or not chart_tag.valid then return end

    -- Get GPS and Tag object to check ownership via Tag.owner_name
    local gps = GPSUtils.gps_from_map_position(chart_tag.position,
      chart_tag.surface and chart_tag.surface.index or player.surface.index)
    local tag = Cache.get_tag_by_gps(player, gps)
    
    -- Only allow removal if player is admin or owner (using Tag.owner_name)
    local is_admin = player.admin
    local is_owner = tag and (not tag.owner_name or tag.owner_name == "" or tag.owner_name == player.name)
    
    if not is_admin and not is_owner then
      -- Restore the tag at its original location (Factorio will have already removed it, so recreate)
      if chart_tag.position and chart_tag.surface then
        player.surface.create_entity {
          name = chart_tag.name or "tf-chart-tag",
          position = chart_tag.position,
          force = player.force,
          text = chart_tag.text or "",
          icon = chart_tag.icon
        }
      end
      refresh_surface_chart_tags(tonumber(player.surface.index) or 1)
      return
    end

    -- Remove/update associated tags, favorites, etc.
    if tag then
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
    end

    refresh_surface_chart_tags(tonumber(player.surface.index) or 1)

  end)
end

return handlers
