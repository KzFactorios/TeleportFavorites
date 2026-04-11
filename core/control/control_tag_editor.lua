---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- core/control/control_tag_editor.lua
-- TeleportFavorites Factorio Mod
-- Handles tag editor GUI events: click dispatch, text change, elem change.
-- Heavy-lifting (chart tag create/update/delete) lives in control_tag_editor_core.lua.
--
-- CRITICAL MULTIPLAYER SAFETY PATTERN:
-- LuaChartTag objects CANNOT be directly modified in multiplayer without causing desynchronization.
-- Direct property assignment (chart_tag.text = "foo", chart_tag.icon = {...}) causes CRC mismatches.
-- CORRECT PATTERN: Destroy and recreate chart tags instead. See control_tag_editor_core.lua.

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils, Deps.Enum
local tag_editor = require("gui.tag_editor.tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local TeleportEntrypoint = require("core.control.teleport_entrypoint")
local Core = require("core.control.control_tag_editor_core")

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
    Core.close_tag_editor(player)
    return
  end

  local tag_editor_frame = Cache.get_player_data(player).tag_editor_frame
  if tag_editor_frame and tag_editor_frame.valid and event.element == tag_editor_frame then
    Core.close_tag_editor(player)
    return
  end
end

--- Toggle the favorite state in the tag editor
---@param player LuaPlayer
---@param tag_data table
local function handle_favorite_btn(player, tag_data)
  tag_data = tag_data or {}
  if type(tag_data.is_favorite) ~= "boolean" then
    tag_data.is_favorite = false
  end
  tag_data.is_favorite = not tag_data.is_favorite
  Cache.set_tag_editor_data(player, tag_data)
  BasicHelpers.update_state(tag_editor.update_favorite_state, player, tag_data.is_favorite)
end

--- Show the delete confirmation dialog
---@param player LuaPlayer
---@param tag_data table
local function handle_delete_btn(player, tag_data)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  Cache.set_tag_editor_delete_mode(player, true)
  tag_editor.build_confirmation_dialog(player, { message = { "tf-gui.confirm_delete_message" } })
  Cache.set_modal_dialog_state(player, "delete_confirmation")
  player.opened = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
end

--- Cancel deletion and return to tag editor
---@param player LuaPlayer
local function handle_delete_cancel(player)
  Core.dismiss_delete_confirm(player)
  player.opened = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  Cache.set_tag_editor_delete_mode(player, false)
end

--- Teleport player to tag position and close editor
---@param player LuaPlayer
---@param map_position MapPosition
local function handle_teleport_btn(player, map_position)
  if not player or not map_position then
    ErrorHandler.warn_log("Invalid teleport parameters", {
      player_valid = player and player.valid or false,
      map_position_provided = map_position ~= nil
    })
    return
  end
  if not player.valid then
    ErrorHandler.warn_log("Player invalid during teleport", { player_name = "invalid_player" })
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

  TeleportEntrypoint.execute(player, gps, {
    source = "tag_editor",
    add_to_history = true,
  })
  -- Keep current UX: close editor immediately after teleport action.
  Core.close_tag_editor(player)
end

--- Tag editor GUI click dispatcher
---@param event table on_gui_click event
local function on_tag_editor_gui_click(event)
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return end

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

  if element.name == "tag_editor_title_row_close" then
    Core.close_tag_editor(player)
    return
  elseif element.name == "tag_editor_confirm_button" then
    return Core.handle_confirm_btn(player, element, tag_data)
  elseif element.name == "tag_editor_delete_button" then
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
    local new_icon = element.elem_value or element.signal or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)
    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
    return
  elseif element.name == "tag_editor_rich_text_row" then
    return
  end

  if element.name == "tf_confirm_dialog_confirm_btn" then
    return Core.handle_delete_confirm(player)
  elseif element.name == "tf_confirm_dialog_cancel_btn" then
    return handle_delete_cancel(player)
  end
end

--- Validate and resolve element + player from a tag_editor GUI event
---@param event table
---@return LuaGuiElement|nil, LuaPlayer|nil
local function tag_editor_event_context(event)
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return nil, nil end
  local name = element.name or ""
  if not name:find("tag_editor") then return nil, nil end
  local player = game.get_player(event.player_index)
  if not BasicHelpers.is_valid_player(player) then return nil, nil end
  return element, player
end

--- Handle text input changes — save immediately to storage
---@param event table on_gui_text_changed event
local function on_tag_editor_gui_text_changed(event)
  local element, player = tag_editor_event_context(event)
  if not element then return end

  if element.name == "tag_editor_rich_text_input" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    local raw_text = element.text or ""
    local trimmed_text = raw_text:gsub("%s+$", "")

    local is_valid, error_msg = GuiValidation.validate_text_length(trimmed_text, nil, "Chart tag text")
    if not is_valid then
      tag_data.error_message = error_msg
      element.text = tag_data.text or ""
    else
      tag_data.error_message = nil
      tag_data.text = trimmed_text
    end

    Cache.set_tag_editor_data(player, tag_data)

    if tag_data.error_message then
      tag_editor.update_error_message(player, tag_data.error_message)
    else
      tag_editor.update_error_message(player, nil)
    end
    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
  end
end

--- Handle element changes (icon selection) — save immediately to storage
---@param event table on_gui_elem_changed event
local function on_tag_editor_gui_elem_changed(event)
  local element, player = tag_editor_event_context(event)
  if not element then return end

  if element.name == "tag_editor_icon_button" then
    local tag_data = Cache.get_tag_editor_data(player) or {}
    local new_icon = element.elem_value or ""
    tag_data.icon = new_icon
    Cache.set_tag_editor_data(player, tag_data)
    BasicHelpers.update_state(tag_editor.update_confirm_button_state, player, tag_data)
  end
end

M.close_tag_editor = Core.close_tag_editor
M.on_tag_editor_gui_click = on_tag_editor_gui_click
M.on_tag_editor_gui_text_changed = on_tag_editor_gui_text_changed
M.on_tag_editor_gui_elem_changed = on_tag_editor_gui_elem_changed

return M
