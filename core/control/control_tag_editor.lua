---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- control_tag_editor.lua
-- Handles tag editor GUI events for TeleportFavorites

local tag_editor = require("gui.tag_editor.tag_editor")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")
local game_helpers = require("core.utils.game_helpers")
local safe_destroy_frame = Helpers.safe_destroy_frame
local PlayerFavorites = require("core.favorite.player_favorites")
local gps_parser = require("core.utils.gps_parser")
local gps_core = require("core.utils.gps_core")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local PositionValidator = require("core.utils.position_validator")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")

-- Observer Pattern Integration
local GuiObserver = require("core.pattern.gui_observer")
local gps_helpers = require("core.utils.gps_helpers")
local GuiEventBus = GuiObserver.GuiEventBus

local M = {}

local function refresh_tag_editor(player, tag_data)
  Cache.set_tag_editor_data(player, tag_data)
  Helpers.safe_destroy_frame(player.gui.screen, "tag_editor_frame")
  tag_editor.build(player)
end

local function show_tag_editor_error(player, tag_data, message)
  tag_data.error_message = message
  refresh_tag_editor(player, tag_data)
end

local function update_favorite_state(player, tag, is_favorite)
  Helpers.update_favorite_state(player, tag, is_favorite, PlayerFavorites)

  -- Notify observers of favorite change
  GuiEventBus.notify(is_favorite and "favorite_added" or "favorite_removed", {
    player = player,
    gps = tag.gps,
    tag = tag,
    type = is_favorite and "favorite_added" or "favorite_removed"
  })
end

local function update_tag_chart_fields(tag, text, icon, player)
  Helpers.update_tag_chart_fields(tag, text, icon, player)

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
  Helpers.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
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
      "The ancient glyphs exceed the permitted length (" .. max_len .. " runes).")
  end
  if text == "" and (not icon or icon == "") then
    return show_tag_editor_error(player, tag_data,
      "A tag must bear a symbol or inscription to be remembered by the ether.")
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
  Helpers.player_print(player, { "tf-gui.tag_editor_confirmed" })
end

local function unregister_move_handlers(script)
  script.on_event(defines.events.on_player_selected_area, nil)
  script.on_event(defines.events.on_player_alt_selected_area, nil)
end

local function handle_move_btn(player, tag_data, script)
  tag_data.move_mode = true
  show_tag_editor_error(player, tag_data,
    "The aether shimmers... Select a new destination for this tag, or right-click to cancel.")
  local function on_move(event)
    if event.player_index ~= player.index then return end
    local pos = event.area and event.area.left_top or nil
    if not pos then
      return show_tag_editor_error(player, tag_data,
        "The aether rejects this location. Please select a valid destination.")
    end

    -- Store the new position in move_gps first
    local new_gps = gps_parser.gps_from_map_position(pos, player.surface.index)
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
        player_print(player,
          { "tf-gui.tag_editor_move_success", "The tag's essence has been relocated through the veil!" })
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
        safe_destroy_frame(player.gui.screen, "tag_editor_frame")
        player_print(player, { "tf-gui.tag_editor_delete_success", "The tag has been removed from existence!" })
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
    local success = PositionValidator.move_tag_to_selected_position(
      player, tag, chart_tag, pos, search_radius, position_validation_callback
    )

    -- If the function returns true, it means the position was valid and move was successful
    if success == true then
      -- Update cached data and refresh UI
      tag_data.move_mode = false
      tag_data.error_message = nil
      tag_data.move_gps = "" -- Clear move_gps since move is complete
      Cache.set_tag_editor_data(player, nil)
      player_print(player, { "tf-gui.tag_editor_move_success", "The tag's essence has been relocated through the veil!" })
      refresh_tag_editor(player, tag_data)
    end

    -- Always unregister handlers when done processing the move event
    unregister_move_handlers(script)
  end

  local function on_cancel(event)
    if event.player_index ~= player.index then return end
    tag_data.move_mode = false
    tag_data.move_gps = "" -- Clear move_gps on cancel
    show_tag_editor_error(player, tag_data, "The spirits sigh. Move mode cancelled.")
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

  -- Update the tag_data and refresh the UI
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)

  -- Notify observers of favorite toggle
  if tag_data.tag then
    GuiEventBus.notify(tag_data.is_favorite and "favorite_added" or "favorite_removed", {
      player = player,
      gps = tag_data.tag.gps or tag_data.gps,
      tag = tag_data.tag,
      type = tag_data.is_favorite and "favorite_added" or "favorite_removed"
    })
  end
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
    Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
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
  end
  if not can_delete then
    Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
    show_tag_editor_error(player, tag_data,
      "The spirits whisper: others claim this place, or you lack dominion.")
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
  Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  close_tag_editor(player)
  Helpers.player_print(player, { "tf-gui.tag_deleted" })
end

local function handle_delete_cancel(player, tag_data)
  -- User cancelled deletion - close confirmation dialog and return to tag editor
  Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  player.opened = Helpers.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
end

local function handle_teleport_btn(player, map_position)
  if not player or not map_position then return end

  Helpers.safe_teleport(player, map_position)
  close_tag_editor(player)
end

local update_tag_data_and_refresh = function(player, tag_data, updates)
  for k, v in pairs(updates) do
    tag_data[k] = v
  end
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)
end

--- Tag editor GUI click handler for shared dispatcher
local function on_tag_editor_gui_click(event, script)
  local element = event.element
  if not element or not element.valid then return end
  -- Only handle clicks on our tag editor GUI elements (must start with or contain 'tag_editor')
  local name = element.name or ""
  if not name:find("tag_editor") then
    return -- Not our GUI, ignore
  end
  local player = game.get_player(event.player_index)
  if not player then return end

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
    local tele_pos = gps_helpers.map_position_from_gps(tag_data.gps)
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
  if not player then return end
  if element.name == "tag_editor_rich_text_input" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    tag_data.text = (element.text or ""):gsub("%s+$", "")
    Cache.set_tag_editor_data(player, tag_data)
    -- Update confirm button state based on new text content
    tag_editor.update_confirm_button_state(player, tag_data)
  end
end

M.update_tag_data_and_refresh = update_tag_data_and_refresh
M.close_tag_editor = close_tag_editor
M.on_tag_editor_gui_click = on_tag_editor_gui_click
M.on_tag_editor_gui_text_changed = on_tag_editor_gui_text_changed

--- Register tag editor event handlers (deprecated: use shared dispatcher)
function M.register(script)
  -- Deprecated: do not register directly. Use shared dispatcher in gui_base.lua
end

return M
