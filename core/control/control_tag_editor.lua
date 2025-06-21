---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- control_tag_editor.lua
-- Handles tag editor GUI events for TeleportFavorites

local tag_editor = require("gui.tag_editor.tag_editor")
local Cache = require("core.cache.cache")
local GuiUtils = require("core.utils.gui_utils")
local GameHelpers = require("core.utils.game_helpers")
local GPSUtils = require("core.utils.gps_utils")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local PositionUtils = require("core.utils.position_utils")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local PlayerFavorites = require("core.favorite.player_favorites")
local LocaleUtils = require("core.utils.locale_utils")
local ErrorHandler = require("core.utils.error_handler")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ValidationUtils = require("core.utils.validation_utils")
local AdminUtils = require("core.utils.admin_utils")
local SettingsAccess = require("core.utils.settings_access")
local TagEditorMoveMode = require("core.control.control_move_mode")
local CollectionUtils = require("core.utils.collection_utils")

-- Observer Pattern Integration
local GuiObserver = require("core.pattern.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local M = {}

local function refresh_tag_editor(player, tag_data)
  Cache.set_tag_editor_data(player, tag_data)
  GuiUtils.safe_destroy_frame(player.gui.screen, "tag_editor_frame")
  tag_editor.build(player)
end

local function show_tag_editor_error(player, tag_data, message)
  tag_data.error_message = message
  refresh_tag_editor(player, tag_data)
end

local function update_favorite_state(player, tag, is_favorite)
  -- This function only updates the is_favorite state in tag_editor_data
  -- Actual favorite creation/deletion happens only on confirm button click
  local tag_data = Cache.get_tag_editor_data(player) or {}
  tag_data.is_favorite = is_favorite
  Cache.set_tag_editor_data(player, tag_data)
end

local function handle_favorite_operations(player, tag, is_favorite)
  -- This function handles the actual favorite creation/deletion on confirm
  local player_favorites = PlayerFavorites.new(player)

  -- Check current favorite state
  local current_favorite, _ = player_favorites:get_favorite_by_gps(tag.gps)
  local currently_is_favorite = current_favorite ~= nil

  -- Only make changes if the state has actually changed
  if is_favorite and not currently_is_favorite then
    -- Add favorite
    local favorite, error_msg = player_favorites:add_favorite(tag.gps)
    if not favorite then
      local error_text = error_msg or "Unknown error"
      GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_add_favorite", { error_text }))
      return false
    end
  elseif not is_favorite and currently_is_favorite then
    -- Remove favorite
    local success, error_msg = player_favorites:remove_favorite(tag.gps)
    if not success then
      local error_text = error_msg or "Unknown error"
      GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_remove_favorite", { error_text }))
      return false
    end
  end
  -- If is_favorite == currently_is_favorite, no action needed

  -- Observer notifications are now sent from PlayerFavorites methods
  -- No need to send them here as they're already handled in add_favorite/remove_favorite
  return true
end

-- Change function signature to accept tag_data
local function update_chart_tag_fields(tag, tag_data, text, icon, player)
  -- Get or create chart tag
  local chart_tag = tag.chart_tag
  local map_position = GPSUtils.map_position_from_gps(tag.gps)

  if not map_position then
    ErrorHandler.warn_log("Cannot update chart tag: invalid GPS position", {
      gps = tag.gps
    })
    return
  end
  if chart_tag and chart_tag.valid then
    -- Check permissions using AdminUtils
    local can_edit, is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, chart_tag)
    if not can_edit then
      ErrorHandler.warn_log("Player cannot edit chart tag: insufficient permissions", {
        player_name = player.name,
        chart_tag_last_user = chart_tag.last_user and chart_tag.last_user.name or "",
        is_admin = AdminUtils.is_admin(player)
      })
      return
    end
    -- Log admin action if this is an admin override
    if is_admin_override then
      AdminUtils.log_admin_action(player, "edit_chart_tag", chart_tag, {
        old_text = chart_tag.text or "",
        new_text = text or "",
        old_icon = chart_tag.icon,
        new_icon = icon
      })
    end
    -- Always set ownership to the confirming player
    chart_tag.last_user = player.name
    ErrorHandler.debug_log("Set chart tag ownership to player (always on confirm)", {
      player_name = player.name,
      chart_tag_position = chart_tag.position,
      chart_tag_text = chart_tag.text or ""
    })
    -- Update existing chart tag properties
    chart_tag.text = text or ""
    -- Always set icon (can be nil for empty icons)
    if ValidationUtils.has_valid_icon(icon) then
      chart_tag.icon = icon
    else
      chart_tag.icon = nil
    end
    -- CRITICAL: Invalidate cache after modifying chart tag
    local surface_index = chart_tag.surface and chart_tag.surface.index or player.surface.index
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    -- Force immediate cache rebuild to ensure the modified chart tag is updated
    local refreshed_cache = Cache.Lookups.get_chart_tag_cache(surface_index)
    ErrorHandler.debug_log("Cache refreshed after chart tag modification", {
      surface_index = surface_index,
      chart_tags_in_cache = #refreshed_cache,
      modified_chart_tag_gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
    })
    -- Refresh chart_tag reference from cache to ensure latest last_user is used
    local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
    local refreshed_chart_tag = Cache.Lookups.get_chart_tag_by_gps(gps)
    if refreshed_chart_tag and refreshed_chart_tag.valid then
      tag.chart_tag = refreshed_chart_tag
      tag_data.chart_tag = refreshed_chart_tag
      tag_data.tag = tag
    end
  else
    -- Create new chart tag using ChartTagUtils - set ownership for final chart tag
    local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(map_position, nil, player, text, true)
    -- Always set icon (can be nil for empty icons)
    if ValidationUtils.has_valid_icon(icon) then
      chart_tag_spec.icon = icon
    else
      chart_tag_spec.icon = nil
    end

    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, player.surface, chart_tag_spec, player)
    if new_chart_tag and new_chart_tag.valid then
      tag.chart_tag = new_chart_tag

      -- CRITICAL: Invalidate cache after creating new chart tag
      -- Add a small delay to ensure Factorio has registered the chart tag
      local surface_index = player.surface.index
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      -- Force immediate cache rebuild to ensure the new chart tag is included
      local refreshed_cache = Cache.Lookups.get_chart_tag_cache(surface_index)
      ErrorHandler.debug_log("Cache refreshed after chart tag creation", {
        surface_index = surface_index,
        chart_tags_in_cache = #refreshed_cache,
        new_chart_tag_gps = GPSUtils.gps_from_map_position(new_chart_tag.position, surface_index)
      })
      -- Refresh chart_tag reference from cache to ensure latest last_user is used
      local gps = GPSUtils.gps_from_map_position(new_chart_tag.position, surface_index)
      local refreshed_chart_tag = Cache.Lookups.get_chart_tag_by_gps(gps)
      if refreshed_chart_tag and refreshed_chart_tag.valid then
        tag.chart_tag = refreshed_chart_tag
        tag_data.chart_tag = refreshed_chart_tag
        tag_data.tag = tag
      end
    else
      ErrorHandler.warn_log("Failed to create chart tag", {
        gps = tag.gps,
        text = text
      })
    end
  end

  -- Notify observers of tag modification
  GuiEventBus.notify("tag_modified", {
    player = player,
    gps = tag.gps,
    tag = tag,
    type = "tag_modified",
    changes = {
      text = text,
      icon = icon
    }
  })
end

local function close_tag_editor(player)
  -- Only destroy the tag editor frame, not the confirmation dialog
  local tag_data = Cache.get_tag_editor_data(player)
  local was_move_mode = tag_data and tag_data.move_mode == true
  if was_move_mode then
    if player and player.valid then
      player.clear_cursor()
    end
    if script and script.on_event then
      script.on_event(defines.events.on_player_selected_area, nil)
      script.on_event(defines.events.on_player_alt_selected_area, nil)
    end
  end
  Cache.set_tag_editor_data(player, {})
  GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  player.opened = nil
end

local function handle_confirm_btn(player, element, tag_data)
  -- Get values directly from storage (tag_data), not from UI elements
  local text = (tag_data.text or ""):gsub("%s+$", "")
  local icon = tag_data.icon or ""
  local is_favorite = tag_data.is_favorite
  local max_len = Constants.settings.TAG_TEXT_MAX_LENGTH
  if #text > max_len then
    return show_tag_editor_error(player, tag_data,
      LocaleUtils.get_error_string(player, "tag_text_length_exceeded", { tostring(max_len) }))
  end

  -- Require either text OR icon (not both empty)
  local has_valid_icon = ValidationUtils.has_valid_icon(icon)
  if text == "" and not has_valid_icon then
    return show_tag_editor_error(player, tag_data,
      LocaleUtils.get_error_string(player, "tag_requires_icon_or_text"))
  end

  local surface_index = player.surface.index
  local tags = Cache.get_surface_tags(surface_index)
  local tag = tag_data.tag or {}

  -- Ensure tag has GPS coordinate from tag_data
  if not tag.gps and tag_data.gps then
    tag.gps = tag_data.gps
  end

  -- Ensure tag has chart_tag reference from tag_data if available
  if not tag.chart_tag and tag_data.chart_tag then
    tag.chart_tag = tag_data.chart_tag
  end
  -- Determine if this is a new tag based on whether we opened the editor on an existing tag or chart tag
  -- If tag_data.tag OR tag_data.chart_tag exists, we're editing; if neither, we're creating
  local is_new_tag = not tag_data.tag and not tag_data.chart_tag

  update_chart_tag_fields(tag, tag_data, text, icon, player)

  -- After updating chart tag fields, re-fetch the tag object from cache to ensure latest chart_tag/last_user
  local refreshed_tag = tags[tag.gps] or tag
  refreshed_tag.faved_by_players = refreshed_tag.faved_by_players or {}
  tag_data.tag = refreshed_tag
  tags[tag.gps] = refreshed_tag

  -- Ensure tag is written to persistent storage (sanitized)
  local sanitized_tag = Cache.sanitize_for_storage(refreshed_tag)
  tags[tag.gps] = sanitized_tag

  -- Ensure tag_data.tag.chart_tag is the latest refreshed chart tag
  if tag_data.tag and tag_data.chart_tag and tag_data.tag.chart_tag ~= tag_data.chart_tag then
    tag_data.tag.chart_tag = tag_data.chart_tag
    tags[tag.gps].chart_tag = tag_data.chart_tag
  end

  -- Handle favorite operations only on confirm
  if is_favorite then
    -- Check for available slot before proceeding
    local player_favorites = PlayerFavorites.new(player)
    local _, error_msg = player_favorites:add_favorite(tag.gps)
    if error_msg then
      return show_tag_editor_error(player, tag_data,
        LocaleUtils.get_error_string(player, "favorite_slots_full") or error_msg)
    end

    tag.faved_by_players[player.index] = true
  else
    -- Remove favorite if it exists
    local player_favorites = PlayerFavorites.new(player)
    player_favorites:remove_favorite(tag.gps)
    -- Remove the player's index from tag's faved_by_players
    tag.faved_by_players[player.index] = nil
  end

  -- After updating faved_by_players, re-sanitize and persist the tag
  local sanitized_tag = Cache.sanitize_for_storage(tag)
  tags[tag.gps] = sanitized_tag
  tag_data.tag = sanitized_tag

  -- Notify observers of tag creation or modification
  local event_type = is_new_tag and "tag_created" or "tag_modified"
  GuiEventBus.notify(event_type, {
    player = player,
    gps = tag.gps,
    tag = tag,
    type = event_type,
    is_new = is_new_tag
  })

  close_tag_editor(player)
  -- Always refresh the favorites bar after confirm
  local ok, fave_bar = pcall(require, "gui.favorites_bar.fave_bar")
  if ok and fave_bar and type(fave_bar.build) == "function" then
    fave_bar.build(player)
  end
  GameHelpers.player_print(player, { "tf-command.tag_editor_confirmed" })
end

local function unregister_move_handlers(script)
  -- Restore the original handlers instead of setting to nil
  script.on_event(defines.events.on_player_alt_selected_area, nil)
end

local function handle_move_btn(player, tag_data, script)
  TagEditorMoveMode.enter_move_mode(player, tag_data, refresh_tag_editor, script)
end

local function handle_favorite_btn(player, tag_data)
  -- Validate player first
  if not player or not player.valid then
    ErrorHandler.debug_log("Handle favorite button - invalid player", {
      player_exists = player ~= nil,
      player_valid = player and player.valid
    })
    return
  end

  if not tag_data then
    tag_data = {}
  end

  -- Simply toggle the is_favorite state in tag_editor_data
  -- Actual favorite creation/removal happens on confirm
  if type(tag_data.is_favorite) ~= "boolean" then
    tag_data.is_favorite = false
  end

  tag_data.is_favorite = not tag_data.is_favorite

  ErrorHandler.debug_log("Favorite button toggled", {
    player = (player and player.valid and player.name) or "unknown",
    new_state = tag_data.is_favorite,
    gps = tag_data.tag and tag_data.tag.gps or tag_data.gps
  })

  -- Update the tag_data and refresh the UI to show new state
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)
end

local function handle_delete_confirm(player)
  -- Get the tag data from the tag_editor_data cache
  local tag_data = Cache.get_tag_editor_data(player)
  if not tag_data then
    -- No cached data, just close the dialogs
    GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    close_tag_editor(player)
    return
  end

  -- User confirmed deletion - execute deletion logic
  local tag = tag_data.tag
  if not tag then
    -- Close both confirmation dialog and tag editor
    GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    close_tag_editor(player)
    -- Reset delete mode
    Cache.reset_tag_editor_delete_mode(player)
    return
  end

  -- Use AdminUtils to validate deletion permissions
  local can_delete, is_owner, is_admin_override, reason = AdminUtils.can_delete_chart_tag(player, tag.chart_tag, tag)

  if not can_delete then
    GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    show_tag_editor_error(player, tag_data, reason or LocaleUtils.get_error_string(player, "tag_deletion_forbidden"))
    -- Reset delete mode
    Cache.reset_tag_editor_delete_mode(player)
    return
  end

  -- Log admin action if this is an admin override
  if is_admin_override then
    AdminUtils.log_admin_action(player, "delete_chart_tag", tag.chart_tag, {
      had_other_favorites = tag.faved_by_players and #tag.faved_by_players > 1,
      override_reason = "admin_privileges"
    })
  end

  -- Store tag info for observers before deletion
  local tag_gps = tag.gps

  -- Execute deletion
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)

  -- Notify observers of tag deletion
  GuiEventBus.notify("tag_deleted", {
    player = player,
    gps = tag_gps,
    type = "tag_deleted",
    deleted_by = player.name
  })

  -- Close both dialogs
  GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  close_tag_editor(player)
  -- Reset delete mode
  Cache.reset_tag_editor_delete_mode(player)

  -- get the player settings value for teleport messages on and make the next line conitional
  local player_settings = SettingsAccess:getPlayerSettings(player)
  if player_settings.destination_msg_on then
    GameHelpers.player_print(player, { "tf-gui.tag_deleted" })
  end
end

local function handle_delete_cancel(player)
  -- User cancelled deletion - close confirmation dialog and return to tag editor
  GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  player.opened = GuiUtils.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  -- Reset delete mode
  Cache.reset_tag_editor_delete_mode(player)
end

local function handle_delete_btn(player, tag_data)
  ErrorHandler.debug_log("Tag editor handle_delete_btn called", {
    player_name = player and player.name or "<unknown>"
  })

  -- Standard player validation
  if not player or not player.valid then return end

  -- Always destroy any existing confirmation dialog before creating a new one
  GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)

  -- Set delete mode in tag_editor_data
  Cache.set_tag_editor_delete_mode(player, true)

  -- Create the real confirmation dialog
  local frame, confirm_btn, cancel_btn = tag_editor.build_confirmation_dialog(player, {
    message = { "tf-gui.confirm_delete_message" }
  })

  -- DO NOT set player.opened to the confirm dialog!
  -- Keep player.opened as the tag editor frame so it remains modal and open
  player.opened = GuiUtils.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  ErrorHandler.debug_log("Confirmation dialog opened successfully", {
    player_name = player.name,
    frame_lua_type = type(frame)
  })
end

local function handle_teleport_btn(player, map_position)
  if not player or not map_position then return end
  GameHelpers.safe_teleport(player, map_position)
  close_tag_editor(player)
end

--- Tag editor GUI click handler for shared dispatcher
local function on_tag_editor_gui_click(event, script)
  ErrorHandler.debug_log("[TAG_EDITOR] on_tag_editor_gui_click called", {
    element_name = event and event.element and event.element.name or "<none>",
    button = event and event.button,
    event_type = event and event.input_name or "<no input_name>"
  })

  local element = event.element
  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  local tag_data = Cache.get_tag_editor_data(player) or {}

  -- Robust close for all close/cancel buttons
  if element.name == "tag_editor_title_row_close" then
    close_tag_editor(player)
    return
  elseif element.name == "last_row_confirm_button" then
    -- Accept all button clicks for confirm button
    return handle_confirm_btn(player, element, tag_data)
  elseif element.name == "tag_editor_move_button" then
    return handle_move_btn(player, tag_data, script)
  elseif element.name == "tag_editor_delete_button" then
    -- Accept any mouse button click for delete button
    ErrorHandler.debug_log("Tag editor delete button clicked", {
      button = event.button
    })
    return handle_delete_btn(player, tag_data)
  elseif element.name == "tag_editor_is_favorite_button" then
    return handle_favorite_btn(player, tag_data)
  elseif element.name == "tag_editor_teleport_button" then
    local tele_pos = GPSUtils.map_position_from_gps(tag_data.gps)
    return handle_teleport_btn(player, tele_pos)
  elseif element.name == "tag_editor_icon_button" then
    -- Icon selection changed - immediately save to storage
    local new_icon = element.elem_value or element.signal or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)
    -- Update confirm button state based on new icon selection
    tag_editor.update_confirm_button_state(player, tag_data)
    return
  end
  -- Handle confirmation dialog buttons without checking button type
  if element.name == "tf_confirm_dialog_confirm_btn" then
    ErrorHandler.debug_log("Confirm dialog confirm button clicked", {
      button = event.button
    })
    return handle_delete_confirm(player)
  elseif element.name == "tf_confirm_dialog_cancel_btn" then
    ErrorHandler.debug_log("Confirm dialog cancel button clicked", {
      button = event.button
    })
    return handle_delete_cancel(player)
  end

  ErrorHandler.debug_log("Tag editor GUI click handler: no matching element", {
    element_name = element.name
  })
end

--- Handle text input changes - save immediately to storage
local function on_tag_editor_gui_text_changed(event)
  local element = event.element
  if not element or not element.valid then return end
  local name = element.name or ""
  if not name:find("tag_editor") then return end

  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if element.name == "tag_editor_rich_text_input" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    tag_data.text = (element.text or ""):gsub("%s+$", "")
    Cache.set_tag_editor_data(player, tag_data)
    -- Update confirm button state based on new text content
    tag_editor.update_confirm_button_state(player, tag_data)
  end
end

--- Handle element changes (for icon selection) - save immediately to storage
local function on_tag_editor_gui_elem_changed(event)
  local element = event.element
  if not element or not element.valid then return end
  local name = element.name or ""
  if not name:find("tag_editor") then return end

  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if element.name == "tag_editor_icon_button" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    -- Get the new icon value from the element change event
    local new_icon = element.elem_value or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)

    ErrorHandler.debug_log("Icon selection changed", {
      player = player.name,
      new_icon = new_icon,
      icon_type = type(new_icon)
    })

    -- Update confirm button state based on new icon selection
    tag_editor.update_confirm_button_state(player, tag_data)
  end
end

M.close_tag_editor = close_tag_editor
M.on_tag_editor_gui_click = on_tag_editor_gui_click
M.on_tag_editor_gui_text_changed = on_tag_editor_gui_text_changed
M.on_tag_editor_gui_elem_changed = on_tag_editor_gui_elem_changed

return M
