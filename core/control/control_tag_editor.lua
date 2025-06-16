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
  local player_favorites = PlayerFavorites.new(player)
  
  if is_favorite then
    -- Add favorite    local favorite, error_msg = player_favorites:add_favorite(tag.gps)
    if not favorite then
      GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_add_favorite", {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
      return
    end
  else
    -- Remove favorite
    local success, error_msg = player_favorites:remove_favorite(tag.gps)
    if not success then
      GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_remove_favorite", {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
      return
    end
  end
  
  -- Observer notifications are now sent from PlayerFavorites methods
  -- No need to send them here as they're already handled in add_favorite/remove_favorite
end

local function update_tag_chart_fields(tag, text, icon, player)
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
  -- Always clear tag_editor_data and close all tag editor frames
  Cache.set_tag_editor_data(player, {})
  GuiUtils.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  GuiUtils.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  player.opened = nil
end

local function handle_confirm_btn(player, element, tag_data)
  -- Get values directly from storage (tag_data), not from UI elements
  local text = (tag_data.text or ""):gsub("%s+$", "")
  local icon = tag_data.icon or ""
  local is_favorite = tag_data.is_favorite  local max_len = Constants.settings.TAG_TEXT_MAX_LENGTH
  if #text > max_len then
    return show_tag_editor_error(player, tag_data,
      LocaleUtils.get_error_string(player, "tag_text_length_exceeded", {tostring(max_len)}))
  end
  if text == "" and (not icon or icon == "") then
    return show_tag_editor_error(player, tag_data,
      LocaleUtils.get_error_string(player, "tag_requires_icon_or_text"))
  end

  local surface_index = player.surface.index
  local tags = Cache.get_surface_tags(surface_index)
  local tag = tag_data.tag or {}
  local is_new_tag = not tags[tag.gps]

  update_tag_chart_fields(tag, text, icon, player)
  update_favorite_state(player, tag, is_favorite)

  tags[tag.gps] = tag

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
  GameHelpers.player_print(player, { "tf-gui.tag_editor_confirmed" })
end

local function unregister_move_handlers(script)
  -- Restore the original handlers instead of setting to nil
  script.on_event(defines.events.on_player_alt_selected_area, nil)
end

local function handle_move_btn(player, tag_data, script)
  tag_data.move_mode = true
  show_tag_editor_error(player, tag_data,
    LocaleUtils.get_error_string(player, "move_mode_select_destination"))
  local function on_move(event)
    if event.player_index ~= player.index then return end    local pos = event.area and event.area.left_top or nil
    if not pos then
      return show_tag_editor_error(player, tag_data, LocaleUtils.get_error_string(player, "invalid_location_chosen"))
    end
    -- Store the new position in move_gps first
    local new_gps = GPSUtils.gps_from_map_position(pos, player.surface.index)
    tag_data.move_gps = new_gps

    local tag = tag_data.tag or {}
    local chart_tag = tag.chart_tag

    -- Use position validation when moving the tag
    local position_validation_callback = function(action, updated_tag_data)
      if action == "move" then
        -- Update tag with new validated position
        tag.gps = updated_tag_data.gps

        -- Update the main gps field to the new location
        tag_data.gps = updated_tag_data.gps
        tag_data.tag = tag

        -- Store in surface tags
        local tags = Cache.get_surface_tags(player.surface.index)
        tags[tag.gps] = tag

        -- Finish move process
        tag_data.move_mode = false
        tag_data.error_message = nil
        tag_data.move_gps = "" -- Clear move_gps since move is complete
        Cache.set_tag_editor_data(player, nil)
        GameHelpers.player_print(player, { "tf-gui.tag_editor_move_success", "The tag has been relocated" })
        refresh_tag_editor(player, tag_data)
      elseif action == "delete" then
        -- Delete the tag
        local tags = Cache.get_surface_tags(player.surface.index)
        tags[tag.gps] = nil

        -- Clean up chart tag if it exists
        if chart_tag and chart_tag.valid then
          chart_tag.destroy()
        end

        -- Close tag editor
        tag_data.move_mode = false
        Cache.set_tag_editor_data(player, nil)
        GuiUtils.safe_destroy_frame(player.gui.screen, "tag_editor_frame")
      else
        -- Action was canceled, reset move mode
        tag_data.move_mode = false
        tag_data.move_gps = "" -- Clear move_gps on cancel
        tag_data.error_message = nil
        refresh_tag_editor(player, tag_data)
      end
    end

    -- Get player settings for search radius
  local player_settings = Cache.get_player_data(player)
    local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
    -- Validate and move the tag to the selected position
    local success = PositionUtils.move_tag_to_selected_position(
      player, tag, chart_tag, pos, search_radius, position_validation_callback
    )

    -- If the function returns true, it means the position was valid and move was successful
    if success == true then
      -- Update cached data and refresh UI
      tag_data.move_mode = false
      tag_data.error_message = nil
      tag_data.move_gps = "" -- Clear move_gps since move is complete
      Cache.set_tag_editor_data(player, nil)
      refresh_tag_editor(player, tag_data)
    end

    -- Always unregister handlers when done processing the move event
    unregister_move_handlers(script)
  end
  local function on_cancel(event)
    if event.player_index ~= player.index then return end
    tag_data.move_mode = false
    tag_data.move_gps = "" -- Clear move_gps on cancel
    show_tag_editor_error(player, tag_data, LocaleUtils.get_error_string(player, "tag_move_cancelled"))
    unregister_move_handlers(script)
  end

  script.on_event(defines.events.on_player_selected_area, on_move)
  script.on_event(defines.events.on_player_alt_selected_area, on_cancel)
end

local function handle_favorite_btn(player, tag_data)
  if not tag_data then
    tag_data = {}
  end
  -- Ensure is_favorite is a boolean
  if type(tag_data.is_favorite) ~= "boolean" then
    tag_data.is_favorite = false
  end
  local old_state = tag_data.is_favorite
  tag_data.is_favorite = not tag_data.is_favorite

  -- Actually create or remove the favorite from storage
  local player_favorites = PlayerFavorites.new(player)
  local gps = tag_data.tag and tag_data.tag.gps or tag_data.gps
  
  if gps then
    if tag_data.is_favorite then
      -- Add favorite      local favorite, error_msg = player_favorites:add_favorite(gps)
      if not favorite then
        GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_add_favorite", {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
        -- Revert state
        tag_data.is_favorite = old_state
        Cache.set_tag_editor_data(player, tag_data)
        refresh_tag_editor(player, tag_data)
        return
      end
    else
      -- Remove favorite
      local success, error_msg = player_favorites:remove_favorite(gps)
      if not success then
        GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_remove_favorite", {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
        -- Revert state
        tag_data.is_favorite = old_state
        Cache.set_tag_editor_data(player, tag_data)
        refresh_tag_editor(player, tag_data)
        return
      end
    end
  end

  -- Update the tag_data and refresh the UI
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)

  -- Observer notifications are now sent from PlayerFavorites methods
  -- No need to send them here as they're already handled in add_favorite/remove_favorite
end

local function handle_delete_btn(player, tag_data, element)
  -- Open confirmation dialog instead of deleting immediately
  tag_editor.build_confirmation_dialog(player, {
    message = { "tf-gui.confirm_delete_message" }
  })
end

local function handle_delete_confirm(player, tag_data)
  -- User confirmed deletion - execute deletion logic
  local tag = tag_data.tag
  if not tag then
    -- Close both confirmation dialog and tag editor
    GuiUtils.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
    close_tag_editor(player)
    return
  end

  -- Validate deletion is still allowed (ownership + no other favorites)
  local can_delete = false
  if tag.chart_tag then
    local last_user = tag.chart_tag.last_user or ""
    local is_owner = (last_user == "" or last_user == player.name)
    local has_other_favorites = #(tag.faved_by_players or {}) > 1
    can_delete = is_owner and not has_other_favorites
  else
    can_delete = true
  end  if not can_delete then
    GuiUtils.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
    show_tag_editor_error(player, tag_data,
      LocaleUtils.get_error_string(player, "tag_deletion_forbidden"))
    return
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
  GuiUtils.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  close_tag_editor(player)
  GameHelpers.player_print(player, { "tf-gui.tag_deleted" })
end

local function handle_delete_cancel(player, tag_data)
  -- User cancelled deletion - close confirmation dialog and return to tag editor
  GuiUtils.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  player.opened = GuiUtils.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
end

local function handle_teleport_btn(player, map_position)
  if not player or not map_position then return end
  GameHelpers.safe_teleport(player, map_position)
  close_tag_editor(player)
end

--- Tag editor GUI click handler for shared dispatcher
local function on_tag_editor_gui_click(event, script)  local element = event.element
  if not element or not element.valid then return end
  -- Only handle clicks on our tag editor GUI elements (must start with or contain 'tag_editor')
  local name = element.name or ""
  if not name:find("tag_editor") then
    -- Not our GUI, ignore
    return
  end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  local tag_data = Cache.get_tag_editor_data(player) or {}
  -- Robust close for all close/cancel buttons
  if element.name == "tag_editor_title_row_close" then
    close_tag_editor(player)
    return
  elseif element.name == "last_row_confirm_button" then
    return handle_confirm_btn(player, element, tag_data)
  elseif element.name == "tag_editor_move_button" then
    return handle_move_btn(player, tag_data, script)
  elseif element.name == "tag_editor_delete_button" then
    return handle_delete_btn(player, tag_data, element)
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
    -- Confirmation dialog event handlers
  elseif element.name == "tf_confirm_dialog_confirm_btn" then
    return handle_delete_confirm(player, tag_data)
  elseif element.name == "tf_confirm_dialog_cancel_btn" then
    return handle_delete_cancel(player, tag_data)
  end
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

M.close_tag_editor = close_tag_editor
M.on_tag_editor_gui_click = on_tag_editor_gui_click
M.on_tag_editor_gui_text_changed = on_tag_editor_gui_text_changed

return M
