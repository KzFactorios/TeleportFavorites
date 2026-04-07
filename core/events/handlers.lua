---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- TeleportFavorites Factorio Mod
-- Centralized event handler implementations for TeleportFavorites.
-- Handles Factorio events, multiplayer/surface-aware updates, helpers, error handling, validation, and API for all event types.

local TagClass = require("core.tag.tag")
local AdminUtils = require("core.utils.admin_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local ControlTagEditor = require("core.control.control_tag_editor")
local GameHelpers = require("core.utils.game_helpers")
local Cache = require("core.cache.cache")
local Constants = require("constants")
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
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local gui_observer = require("core.events.gui_observer")


-- Helper functions for surface refresh and captions

--- Close all mod screen-level GUIs for a player (tag editor, modals, history)
--- Called during save/load and player (re)join to prevent stale/orphaned GUI frames
---@param player LuaPlayer
local function close_all_mod_screens(player)
  if not player or not player.valid then return end
  ControlTagEditor.close_tag_editor(player)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME)
end

---@param surface_index number The surface index to refresh chart tags for
local function refresh_surface_chart_tags(surface_index)
  local safe_index = tonumber(surface_index) or 1
  -- Just call ensure_surface_cache, which internally handles cache invalidation
  Cache.ensure_surface_cache(safe_index)
end

--- Restore a chart tag that was removed and refresh caches/UI
---@param player LuaPlayer The player
---@param chart_tag LuaCustomChartTag The removed chart tag (still valid during event)
---@param tag table? The mod's Tag object
local function restore_chart_tag_and_refresh(player, chart_tag, tag)
  if chart_tag.position and chart_tag.surface then
    local new_chart_tag = player.force.add_chart_tag(
      player.surface,
      {
        position = chart_tag.position,
        text = chart_tag.text or "",
        icon = chart_tag.icon,
        last_user = chart_tag.last_user
      }
    )
    if tag then
      tag.chart_tag = new_chart_tag
    end
  end
  refresh_surface_chart_tags(tonumber(player.surface.index) or 1)
  fave_bar.build(player)
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
    if player.surface and player.surface.valid then
      -- Close tag editor if open (tag belongs to old surface)
      ControlTagEditor.close_tag_editor(player)

      Cache.ensure_surface_cache(player.surface.index)

      -- Force rebuild to show the new surface's favorites (skips tick debounce)
      fave_bar.build(player, true)
      -- Ensure visibility is updated for the new surface
      fave_bar.update_fave_bar_visibility(player)

      -- Refresh teleport history modal if open (show new surface's history)
      if teleport_history_modal.is_open(player) then
        teleport_history_modal.update_history_list(player)
      end
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
  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[Cache] Cache.init() called during on_init")
  end
  Cache.init()

  -- Set up each player - defer GUI build to reduce startup UPS spike
  for _, player in pairs(game.players) do
    if Cache.get_player_data(player) == nil then
      if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
        ErrorHandler.debug_log("[Cache] Cache.reset_transient_player_states() for player", { player = player.name })
      end
      Cache.reset_transient_player_states(player)
    end

    -- Register observers but defer GUI build until player joins
    register_gui_observers(player)
    -- Note: fave_bar.build() will be called when player joins via on_player_joined_game
  end

  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[INIT] Startup initialization complete - GUI build deferred to player join")
  end
end

-- Session-level flag (NOT in storage, safe for on_load)
-- This gets reset every time the mod is loaded
local observers_registered_this_session = false

function handlers.on_load()
  -- Re-initialize GUI event bus on game load
  gui_observer.GuiEventBus.ensure_initialized()
  ErrorHandler.debug_log("GUI Event Bus re-initialized on game load")

  -- CRITICAL: Reset the session flag so observers get registered on tick 1
  -- Using global variable instead of storage (can't modify storage in on_load)
  observers_registered_this_session = false
  ErrorHandler.debug_log("[ON_LOAD] Reset observer registration flag", {
    flag_value = observers_registered_this_session
  })
end

--- Handle mod configuration changes (mod update, added/removed mods)
--- Destroys and rebuilds all fave bars to ensure new GUI elements are created
function handlers.on_configuration_changed(data)
  ErrorHandler.debug_log("[CONFIG_CHANGED] Configuration changed, rebuilding all fave bars")
  for _, player in pairs(game.players) do
    if player.valid then
      -- Ensure player data is initialized (get_player_data calls init internally)
      Cache.get_player_data(player)
      -- Destroy existing fave bar so it gets fully rebuilt with new elements
      local main_flow = player.gui.top[Enum.UIEnums.GUI.Shared.MAIN_GUI_FLOW]
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
      fave_bar.build(player, true)
    end
  end
end

function handlers.get_observers_registered_flag()
  return observers_registered_this_session
end

function handlers.set_observers_registered_flag(value)
  observers_registered_this_session = value
end

-- Queue for deferred player initialization
-- Each entry: { player_index = N, is_rejoin = bool }
local _deferred_init_queue = {}

--- Process all queued player initializations
--- on_nth_tick(60) stays permanently registered for multiplayer safety; it no-ops when queue is empty
function handlers.process_deferred_init_queue()
  if #_deferred_init_queue == 0 then return end
  for _, entry in ipairs(_deferred_init_queue) do
    local deferred_player = game.players[entry.player_index]
    if deferred_player and deferred_player.valid then
      Cache.reset_transient_player_states(deferred_player)
      -- Close any stale mod GUIs from previous session (tag editor, modals, etc.)
      close_all_mod_screens(deferred_player)
      if entry.is_rejoin then
        gui_observer.GuiEventBus.cleanup_player_observers(deferred_player)
      end
      register_gui_observers(deferred_player)
      fave_bar.build(deferred_player, true)
    end
  end
  _deferred_init_queue = {}
end

--- Enqueue a player for deferred initialization
--- on_nth_tick(60) is permanently registered at load time; it processes whatever is in the queue
---@param player_index uint
---@param is_rejoin boolean
local function enqueue_deferred_init(player_index, is_rejoin)
  table.insert(_deferred_init_queue, { player_index = player_index, is_rejoin = is_rejoin })
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    enqueue_deferred_init(player.index, false)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    ErrorHandler.debug_log("Deferring initialization for rejoining player", {
      player = player.name,
      player_index = player.index
    })
    enqueue_deferred_init(player.index, true)
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
        tonumber(GPSUtils.get_context_surface_index(chart_tag, player)) or 1)
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
          owner_name = nil,      -- New tag, no owner yet
          faved_by_players = {}, -- Empty array for new tags
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
      local surface_tags = Cache.get_surface_tags(surface_index)
      if not tag then
        -- Create and store a new Tag object with owner_name
        tag = TagClass.new(gps, {}, player.name)
        surface_tags[gps] = tag
        ErrorHandler.debug_log("[OWNER][on_chart_tag_added] Created new Tag object with owner_name", {
          gps = gps,
          owner_name = player.name
        })
      else
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
    ErrorHandler.debug_log("[OWNER][on_chart_tag_modified] old_tag lookup before move", {
      player = player.name,
      old_gps = old_gps,
      old_tag_found = old_tag ~= nil,
      old_tag_full = old_tag,
      old_tag_owner_name = old_tag and old_tag.owner_name or "<nil>"
    })
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
    else
      ErrorHandler.debug_log("[OWNER][on_chart_tag_modified] No owner_name found in old_tag before move", {
        player = player.name,
        old_gps = old_gps,
        old_tag_full = old_tag
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

  -- FINAL FALLBACK: If still no owner, set to the player moving the tag
  if not original_owner_name then
    original_owner_name = player.name
    ErrorHandler.debug_log("[OWNER][on_chart_tag_modified] No owner found, defaulting to mover", {
      player_who_moved = player.name,
      assigned_owner_name = original_owner_name
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
      local is_charted = force.is_chunk_charted(surface, { chunk_x, chunk_y })

      if not is_charted then
        -- Position is not charted - revert the tag to old position and play error sound
        chart_tag.position = event.old_position
        player.play_sound({ path = "utility/cannot_build" })

        ErrorHandler.debug_log("Prevented tag move to uncharted territory", {
          player_name = player.name,
          attempted_position = chart_tag.position,
          attempted_chunk = { chunk_x, chunk_y },
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
        teleport_btn.caption = { "tf-gui.teleport_to", coords }
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
        local surface_index = GPSUtils.get_context_surface_index(new_chart_tag, player)
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
      GPSUtils.get_context_surface_index(chart_tag, player))
    local tag = Cache.get_tag_by_gps(player, gps)

    -- Only allow removal if player is admin or owner (using Tag.owner_name)
    local is_admin = player.admin
    local is_owner = tag and (not tag.owner_name or tag.owner_name == "" or tag.owner_name == player.name)

    -- Overrides to vanilla behavior, giving us a way to "put the tag back" if a vanilla deletion breaks the mod's rules
    if not is_admin and not is_owner then
      restore_chart_tag_and_refresh(player, chart_tag, tag)
      return
    end


    local player_favorites = Cache.get_player_favorites(player, chart_tag.surface.index) or {}
    local is_locked = false

    for _, v in ipairs(player_favorites) do
      if v.gps and v.gps == gps and v.locked == true then
        -- Reject the change due to locked status
        is_locked = true
        break
      end
    end

    if is_locked == true then
      -- Notify player that favorite is locked
      GameHelpers.player_print(player, { "tf-gui.favorite_locked_cant_delete" })
      restore_chart_tag_and_refresh(player, chart_tag, tag)
      return
    end

    -- Remove/update associated tags, favorites, etc.
    if not tag then
      tag = { gps = gps }
    end
    if tag then
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
    end

    refresh_surface_chart_tags(tonumber(player.surface.index) or 1)
    fave_bar.build(player)
  end)
end

return handlers
