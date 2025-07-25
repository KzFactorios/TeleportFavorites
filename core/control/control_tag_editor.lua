---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- core/control/control_tag_editor.lua
-- TeleportFavorites Factorio Mod
-- Handles tag editor GUI events, modal dialogs, tag creation/editing/deletion, and multiplayer-safe tag management.

local tag_editor = require("gui.tag_editor.tag_editor")
local Cache = require("core.cache.cache")
local GuiValidation = require("core.utils.gui_validation")
local PlayerHelpers = require("core.utils.player_helpers")
local GPSUtils = require("core.utils.gps_utils")
local Constants = require("constants")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local PlayerFavorites = require("core.favorite.player_favorites")
local LocaleUtils = require("core.utils.locale_utils")
local ErrorHandler = require("core.utils.error_handler")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ValidationUtils = require("core.utils.validation_utils")
local AdminUtils = require("core.utils.admin_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
local SharedUtils = require("core.control.control_shared_utils")
local TeleportStrategy = require("core.utils.teleport_strategy")
local Enum = require("prototypes.enums.enum")


local M = {}

--- Handles GUI close events for tag editor and related modals
---@param event table GUI close event from Factorio
function M.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  if not event.element or not event.element.valid then return end

  local gui_frame = GuiValidation.get_gui_frame_by_element(event.element)
  if gui_frame and (gui_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or 
                    gui_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM) then
    M.close_tag_editor(player)
    return
  end

  local tag_editor_frame = Cache.get_player_data(player).tag_editor_frame
  if tag_editor_frame and tag_editor_frame.valid and event.element == tag_editor_frame then
    M.close_tag_editor(player)
    return
  end
end

-- Shared error message update using centralized helper
local function show_tag_editor_error(player, tag_data, message)
  tag_data.error_message = message
  BasicHelpers.update_error_message(tag_editor.update_error_message, player, message)
  Cache.set_tag_editor_data(player, tag_data)
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
    local chart_tag_spec = ChartTagSpecBuilder.build(map_position, nil, player, text, true)
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
  SharedUtils.notify_observer("tag_modified", {
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

-- Shared tag editor close using centralized helpers
local function close_tag_editor(player)
  local tag_data = Cache.get_tag_editor_data(player)
  local was_move_mode = tag_data and tag_data.move_mode == true
  if was_move_mode then
    if BasicHelpers.is_valid_player(player) then
      player.clear_cursor()
    end
    if script and script.on_event then
      script.on_event(defines.events.on_player_selected_area, nil)
      script.on_event(defines.events.on_player_alt_selected_area, nil)
    end
  end
  Cache.set_tag_editor_data(player, {})
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  player.opened = nil
end

local function handle_confirm_btn(player, element, tag_data)
  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn: entry", {
    gps = tag_data and tag_data.gps,
    is_favorite = tag_data and tag_data.is_favorite
  })
  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn called", {
    player = player and player.name or "<nil>",
    tag_data_gps = tag_data and tag_data.gps or "<nil>"
  })
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

  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn: about to save tag to cache", {
    gps = tag.gps,
    tag_present = tag ~= nil,
    chart_tag_present = tag and tag.chart_tag ~= nil,
    icon_present = tag and tag.chart_tag and (function()
      local valid_check_success, is_valid = pcall(function() return tag.chart_tag.valid end)
      return valid_check_success and is_valid and tag.chart_tag.icon ~= nil or false
    end)(),
    icon_info = tag and tag.chart_tag and (function()
      local valid_check_success, is_valid = pcall(function() return tag.chart_tag.valid end)
      if valid_check_success and is_valid and tag.chart_tag.icon then
        return (tag.chart_tag.icon.type or "<no type>") .. "/" .. (tag.chart_tag.icon.name or "<no name>")
      end
      return nil
    end)()
  })
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
    local _, error_msg = player_favorites:add_favorite(refreshed_tag.gps)
    if error_msg then
      return show_tag_editor_error(player, tag_data,
        LocaleUtils.get_error_string(player, "favorite_slots_full") or error_msg)
    end

    refreshed_tag.faved_by_players[player.index] = player.index
    -- Notify favorites bar to update after adding favorite
    ErrorHandler.debug_log("[TAG_EDITOR] Sending favorites_bar_updated notification (ADD)", {
      player = player.name,
      gps = refreshed_tag.gps,
      action = "add"
    })
    SharedUtils.notify_observer("favorites_bar_updated", {
      player = player,
      gps = refreshed_tag.gps,
      action = "add",
      tag = refreshed_tag
    })
  else
    local player_favorites = PlayerFavorites.new(player)
    player_favorites:remove_favorite(refreshed_tag.gps)
    refreshed_tag.faved_by_players[player.index] = nil
    -- Notify favorites bar to update after removing favorite
    ErrorHandler.debug_log("[TAG_EDITOR] Sending favorites_bar_updated notification (REMOVE)", {
      player = player.name,
      gps = refreshed_tag.gps,
      action = "remove"
    })
    SharedUtils.notify_observer("favorites_bar_updated", {
      player = player,
      gps = refreshed_tag.gps,
      action = "remove",
      tag = refreshed_tag
    })
  end

  -- After updating faved_by_players, re-sanitize and persist the tag
  local sanitized_tag = Cache.sanitize_for_storage(refreshed_tag)
  tags[refreshed_tag.gps] = sanitized_tag
  tag_data.tag = sanitized_tag

  -- Notify observers of tag creation or modification
  local event_type = is_new_tag and "tag_created" or "tag_modified"
  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn: Notifying observers", {
    event_type = event_type,
    player = player and player.name or "<nil>",
    gps = tag.gps
  })
  SharedUtils.notify_observer(event_type, {
    player = player,
    gps = tag.gps,
    tag = tag,
    type = event_type,
    is_new = is_new_tag
  })
  -- Fire multiplayer-safe tag collection changed event
  SharedUtils.notify_observer("tag_collection_changed", {
    gps = tag.gps
  })
  -- Fire cache_updated event for DataObserver
  SharedUtils.notify_observer("cache_updated", {
    type = "tag_editor_confirmed",
    gps = tag.gps
  })

  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn: after notify, about to close_tag_editor", {
    player = player and player.name or "<nil>",
    gps = tag.gps
  })
  close_tag_editor(player)
end

-- Shared favorite button handler using centralized helpers
local function handle_favorite_btn(player, tag_data)
  if not BasicHelpers.is_valid_player(player) then
    ErrorHandler.debug_log("Handle favorite button - invalid player", {
      player_exists = player ~= nil,
      player_valid = player and player.valid
    })
    return
  end
  tag_data = tag_data or {}
  if type(tag_data.is_favorite) ~= "boolean" then
    tag_data.is_favorite = false
  end
  tag_data.is_favorite = not tag_data.is_favorite
  ErrorHandler.debug_log("[TAG_EDITOR] handle_favorite_btn: toggled", {
    gps = tag_data and tag_data.gps,
    is_favorite = tag_data and tag_data.is_favorite
  })
  Cache.set_tag_editor_data(player, tag_data)
  BasicHelpers.update_state(tag_editor.update_favorite_state, player, tag_data.is_favorite)
end

local function handle_delete_confirm(player)
  -- Get the tag data from the tag_editor_data cache
  local tag_data = Cache.get_tag_editor_data(player)
  if not tag_data then
    -- No cached data, just close the dialogs
    GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    Cache.set_modal_dialog_state(player, nil) -- Clear modal state
    close_tag_editor(player)
    return
  end

  -- User confirmed deletion - execute deletion logic
  local tag = tag_data.tag
  if not tag then
    -- Close both confirmation dialog and tag editor
    GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    Cache.set_modal_dialog_state(player, nil) -- Clear modal state
    close_tag_editor(player)
    -- Reset delete mode
    Cache.reset_tag_editor_delete_mode(player)
    return
  end

  -- Use AdminUtils to validate deletion permissions
  local can_delete, _is_owner, is_admin_override, reason = AdminUtils.can_delete_chart_tag(player, tag.chart_tag, tag)

  if not can_delete then
    GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
    Cache.set_modal_dialog_state(player, nil) -- Clear modal state
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

  -- Remove favorite for this GPS before destroying tag
  local player_favorites = PlayerFavorites.new(player)
  player_favorites:remove_favorite(tag_gps)

  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)

  -- Notify observers of tag deletion
  SharedUtils.notify_observer("tag_deleted", {
    player = player,
    gps = tag_gps,
    type = "tag_deleted",
    deleted_by = player.name
  })
  -- Fire multiplayer-safe tag collection changed event
  SharedUtils.notify_observer("tag_collection_changed", {
    gps = tag_gps
  })

  -- Close both dialogs
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  Cache.set_modal_dialog_state(player, nil) -- Clear modal state
  close_tag_editor(player)
 
  Cache.reset_tag_editor_delete_mode(player)

  -- Always show destination messages
  PlayerHelpers.safe_player_print(player, "tf-gui.tag_deleted")

  -- Force favorites bar rebuild to update UI and remove stale icon
  local ok, fave_bar = pcall(require, "gui.favorites_bar.fave_bar")
  if ok and fave_bar and type(fave_bar.build) == "function" then
    fave_bar.build(player, true)
  end
end

-- User cancelled deletion - close confirmation dialog and return to tag editor
local function handle_delete_cancel(player)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  Cache.set_modal_dialog_state(player, nil) -- Clear modal state
  player.opened = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  -- Reset delete mode
  Cache.reset_tag_editor_delete_mode(player)
end

-- Shared delete button handler using centralized helpers
local function handle_delete_btn(player, tag_data)
  ErrorHandler.debug_log("Tag editor handle_delete_btn called", {
    player_name = player and player.name or "<unknown>"
  })
  if not BasicHelpers.is_valid_player(player) then return end
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  Cache.set_tag_editor_delete_mode(player, true)
  local frame, confirm_btn, cancel_btn = tag_editor.build_confirmation_dialog(player, {
    message = { "tf-gui.confirm_delete_message" }
  })
  Cache.set_modal_dialog_state(player, "delete_confirmation")
  player.opened = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  ErrorHandler.debug_log("Confirmation dialog opened successfully", {
    player_name = player.name,
    frame_lua_type = type(frame),
    modal_state_set = true
  })
end

local function handle_teleport_btn(player, map_position)
  if not player or not map_position then 
    ErrorHandler.warn_log("Invalid teleport parameters", {
      player_valid = player and player.valid or false,
      map_position_provided = map_position ~= nil
    })
    return 
  end
  
  if not player.valid then
    ErrorHandler.warn_log("Player invalid during teleport", {
      player_name = "invalid_player"
    })
    return
  end
  
  local gps = GPSUtils.gps_from_map_position(map_position, player.surface.index)
  if not gps or gps == "" then
    ErrorHandler.warn_log("Failed to create GPS from map position", {
      player_name = player.name,
      map_position_x = map_position.x,
      map_position_y = map_position.y,
      surface_index = player.surface.index
    })
    return
  end
  
  TeleportStrategy.teleport_to_gps(player, gps)
  close_tag_editor(player)
end

--- Tag editor GUI click handler for shared dispatcher
local function on_tag_editor_gui_click(event)
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return end

  -- Ignore right-clicks except for delete button
  if event.button == defines.mouse_button_type.right and element.name ~= "tag_editor_delete_button" then
    return
  end

  local player = game.get_player(event.player_index)
  if not BasicHelpers.is_valid_player(player) then return end

  local tag_data
  local success, result = pcall(function()
    return Cache.get_tag_editor_data(player)
  end)

  if success and result then
    tag_data = result
  else
    ErrorHandler.warn_log("Failed to get tag editor data", {
      player_name = player and player.name or "unknown",
      error = tostring(result),
      element_name = element and element.name or "unknown"
    })
    tag_data = {}
  end

  -- Robust close for all close/cancel buttons
  if element.name == "tag_editor_title_row_close" then
    close_tag_editor(player)
    return
  elseif element.name == "tag_editor_confirm_button" then
    -- Accept all button clicks for confirm button
    return handle_confirm_btn(player, element, tag_data)
  elseif element.name == "tag_editor_delete_button" then
    -- Accept any mouse button click for delete button
    ErrorHandler.debug_log("Tag editor delete button clicked", {
      button = event.button
    })
    return handle_delete_btn(player, tag_data)
  elseif element.name == "tag_editor_is_favorite_button" then
    return handle_favorite_btn(player, tag_data)
  elseif element.name == "tag_editor_teleport_button" then
    if not tag_data.gps or tag_data.gps == "" then
      ErrorHandler.warn_log("Teleport button clicked with invalid GPS", {
        player_name = player and player.name or "unknown",
        gps = tostring(tag_data.gps),
        tag_data_type = type(tag_data)
      })
      return
    end
    local tele_pos = GPSUtils.map_position_from_gps(tag_data.gps)
    if not tele_pos then
      ErrorHandler.warn_log("Failed to parse GPS for teleport", {
        player_name = player and player.name or "unknown",
        gps = tostring(tag_data.gps)
      })
      return
    end
    return handle_teleport_btn(player, tele_pos)
  elseif element.name == "tag_editor_icon_button" then
    -- Icon selection changed - immediately save to storage
    local new_icon = element.elem_value or element.signal or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)
    -- Update confirm button state based on new icon selection
    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
    return
  elseif element.name == "tag_editor_rich_text_row" then
    -- Handle clicks on the rich text row container - usually these are propagated clicks
    -- from child elements, so we don't need to do anything special here
    ErrorHandler.debug_log("Tag editor rich text row clicked", {
      element_name = element.name,
      player = player and player.name or "unknown"
    })
    return
  end
  -- Handle confirmation dialog buttons without checking button type
  if element.name == "tf_confirm_dialog_confirm_btn" then
    return handle_delete_confirm(player)
  elseif element.name == "tf_confirm_dialog_cancel_btn" then
    return handle_delete_cancel(player)
  end

  ErrorHandler.debug_log("Tag editor GUI click handler: no matching element", {
    element_name = element.name
  })
end

--- Handle text input changes - save immediately to storage
local function on_tag_editor_gui_text_changed(event)
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return end
  local name = element.name or ""
  if not name:find("tag_editor") then return end

  local player = game.get_player(event.player_index)
  if not BasicHelpers.is_valid_player(player) then return end

  if element.name == "tag_editor_rich_text_input" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    local raw_text = element.text or ""
    local trimmed_text = raw_text:gsub("%s+$", "")
    
    -- Validate text length
    local is_valid, error_msg = ValidationUtils.validate_text_length(trimmed_text, nil, "Chart tag text")
    if not is_valid then
      -- Store error in tag_data and revert to previous valid text
      tag_data.error_message = error_msg
      if tag_data.text then
        element.text = tag_data.text
      else
        element.text = ""
      end
    else
      -- Clear any previous error and store the valid text
      tag_data.error_message = nil
      tag_data.text = trimmed_text
    end
    
    Cache.set_tag_editor_data(player, tag_data)
    
    if tag_data.error_message then
      tag_editor.update_error_message(player, tag_data.error_message)
    else
      tag_editor.update_error_message(player, nil)
    end
    -- Update confirm button state based on new text content
    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
  end
end

--- Handle element changes (for icon selection) - save immediately to storage
local function on_tag_editor_gui_elem_changed(event)
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return end
  local name = element.name or ""
  if not name:find("tag_editor") then return end

  local player = game.get_player(event.player_index)
  if not BasicHelpers.is_valid_player(player) then return end

  if element.name == "tag_editor_icon_button" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    -- Get the new icon value from the element change event
    local new_icon = element.elem_value or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)

    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
  end
end

M.close_tag_editor = close_tag_editor
M.on_tag_editor_gui_click = on_tag_editor_gui_click
M.on_tag_editor_gui_text_changed = on_tag_editor_gui_text_changed
M.on_tag_editor_gui_elem_changed = on_tag_editor_gui_elem_changed

return M
