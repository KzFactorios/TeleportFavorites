---@diagnostic disable: undefined-global

-- control_tag_editor.lua
-- Handles tag editor GUI events for TeleportFavorites

local tag_editor = require("gui.tag_editor.tag_editor")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")
local safe_destroy_frame = Helpers.safe_destroy_frame
local player_print = Helpers.player_print
local Tag = require("core.tag.tag")
local PlayerFavorites = require("core.favorite.player_favorites")
local GPS = require("core.gps.gps")
local Constants = require("constants")

local M = {}

local clear_and_close_tag_editor, update_tag_data_and_refresh

local function refresh_tag_editor(player, tag_data)
  Cache.set_tag_editor_data(player, tag_data)
  Helpers.safe_destroy_frame(player.gui.screen, "tag_editor_frame")
  tag_editor.build(player, tag_data)
end

local function show_tag_editor_error(player, tag_data, message)
  tag_data.error_message = message
  refresh_tag_editor(player, tag_data)
end

local function handle_icon_selection(player, elem_value)
  local tag_data = Cache.get_tag_editor_data(player) or {}
  tag_data.icon = elem_value
  Cache.set_tag_editor_data(player, tag_data)
  Helpers.player_print(player, {"tf-gui.tag_editor_icon_selected", tostring(elem_value or "none")})
  refresh_tag_editor(player, tag_data)
end

local function update_favorite_state(player, tag, is_favorite)
  Helpers.update_favorite_state(player, tag, is_favorite, PlayerFavorites)
end

local function update_tag_chart_fields(tag, text, icon, player)
  Helpers.update_tag_chart_fields(tag, text, icon, player)
end

local function update_tag_position(tag, pos, gps)
  Helpers.update_tag_position(tag, pos, gps)
end

local function handle_confirm_btn(player, element, tag_data)
  local text = (element.parent.text_box and element.parent.text_box.text or ""):gsub("%s+$", "")
  local icon = tag_data.icon or ""
  local is_favorite = tag_data.is_favorite
  local max_len = Constants.settings.TAG_TEXT_MAX_LENGTH
  if #text > max_len then
    return show_tag_editor_error(player, tag_data, "The ancient glyphs exceed the permitted length ("..max_len.." runes).")
  end
  if text == "" and (not icon or icon == "") then
    return show_tag_editor_error(player, tag_data, "A tag must bear a symbol or inscription to be remembered by the ether.")
  end
  local surface_index = player.surface.index
  local tags = Cache.get_surface_tags(surface_index)
  local tag = tag_data.tag or {}
  update_tag_chart_fields(tag, text, icon, player)
  update_favorite_state(player, tag, is_favorite)
  tags[tag.gps] = tag
  clear_and_close_tag_editor(player, element)
  Helpers.player_print(player, {"tf-gui.tag_editor_confirmed"})
end

local function unregister_move_handlers(script)
  script.on_event(defines.events.on_player_selected_area, nil)
  script.on_event(defines.events.on_player_alt_selected_area, nil)
end

local function handle_move_btn(player, tag_data, script)
  tag_data.move_mode = true
  show_tag_editor_error(player, tag_data, "The aether shimmers... Select a new destination for this tag, or right-click to cancel.")

  local function on_move(event)
    if event.player_index ~= player.index then return end
    local pos = event.area and event.area.left_top or nil
    if not pos then
      return show_tag_editor_error(player, tag_data, "The aether rejects this location. Please select a valid destination.")
    end
    local tag = tag_data.tag or {}
    update_tag_position(tag, pos, GPS.gps_from_map_position(pos, player.surface.index))
    tag_data.tag = tag
    local tags = Cache.get_surface_tags(player.surface.index)
    tags[tag.gps] = tag
    tag_data.move_mode = false
    tag_data.error_message = nil
    Cache.set_tag_editor_data(player, nil)
    player_print(player, {"tf-gui.tag_editor_move_success", "The tag's essence has been relocated through the veil!"})
    refresh_tag_editor(player, tag_data)
    unregister_move_handlers(script)
  end

  local function on_cancel(event)
    if event.player_index ~= player.index then return end
    tag_data.move_mode = false
    show_tag_editor_error(player, tag_data, "The spirits sigh. Move mode cancelled.")
    unregister_move_handlers(script)
  end

  script.on_event(defines.events.on_player_selected_area, on_move)
  script.on_event(defines.events.on_player_alt_selected_area, on_cancel)
end

local function handle_favorite_btn(player, tag_data)
  tag_data.is_favorite = not tag_data.is_favorite
  local pfaves = PlayerFavorites.new(player)
  local tag = tag_data.tag or {}
  if tag_data.is_favorite then
    pfaves:add_favorite(tag.gps)
    player_print(player, {"tf-gui.tag_editor_favorite_added", "The tag is now marked as a favorite in the Book of Portals!"})
  else
    pfaves:remove_favorite(tag.gps)
    player_print(player, {"tf-gui.tag_editor_favorite_removed", "The tag's star has faded from your astral ledger."})
  end
  update_tag_data_and_refresh(player, tag_data, {})
end

local function handle_delete_btn(player, tag_data, element)
  -- Open confirmation dialog instead of deleting immediately
  tag_editor.build_confirmation_dialog(player, {
    message = {"tf-gui.confirm_delete_message"}
  })
end

local function handle_teleport_btn(player, tag_data)
  if not tag_data or not tag_data.tag or not tag_data.tag.chart_tag or not tag_data.tag.chart_tag.position then
    return show_tag_editor_error(player, tag_data, "The ley lines cannot be traced to this tag's location.")
  end
  local pos = tag_data.tag.chart_tag.position
  local surface = player.surface
  if surface and pos then
    player.teleport(pos, surface)
    player_print(player, {"tf-gui.tag_editor_teleported", "You have traversed the ether to your tag's location!"})
    update_tag_data_and_refresh(player, tag_data, {error_message = nil})
  else
    show_tag_editor_error(player, tag_data, "The ether resists your passage. Teleportation failed.")
  end
end

clear_and_close_tag_editor = function(player, _)
  Cache.set_tag_editor_data(player, nil)
  Helpers.safe_destroy_frame(player.gui.screen, "tag_editor_outer_frame")
  Helpers.safe_destroy_frame(player.gui.screen, "tag_editor_inner_frame")
  Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
  player.opened = nil
end

update_tag_data_and_refresh = function(player, tag_data, updates)
  for k, v in pairs(updates) do
    tag_data[k] = v
  end
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)
end

local function handle_icon_button_click(player, tag_data)
  player_print(player, {"tf-gui.tag_editor_icon_select"})
  update_tag_data_and_refresh(player, tag_data, {error_message = nil})
end

--- Tag editor GUI click handler for shared dispatcher
local function on_tag_editor_gui_click(event, script)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local tag_data = Cache.get_tag_editor_data(player) or {}
  if element.parent and element.parent.name == "tag_editor_frame" then
    if element.name == "tag_editor_confirm_btn" then
      return handle_confirm_btn(player, element, tag_data)
    elseif element.name == "tag_editor_cancel_btn" or element.name == "last_row_cancel_button" then
      if element and (element.name == "tag_editor_cancel_btn" or element.name == "last_row_cancel_button") then
        local parent = element.parent
        while parent do
          if parent.name == "tag_editor_frame" or parent.name == "tag_editor_outer_frame" then
            player_print(player, {"tf-gui.tag_editor_cancelled"})
            clear_and_close_tag_editor(player, parent)
            return
          end
          parent = parent.parent
        end
      end
    elseif element.name == "tag_editor_move_btn" then
      return handle_move_btn(player, tag_data, script)
    elseif element.name == "tag_editor_delete_btn" then
      return handle_delete_btn(player, tag_data, element)
    elseif element.name == "tag_editor_teleport_btn" then
      return handle_teleport_btn(player, tag_data)
    elseif element.name == "tag_editor_favorite_btn" then
      return handle_favorite_btn(player, tag_data)
    elseif element.name == "icon_row_icon_button" then
      handle_icon_button_click(player, tag_data)
    elseif element.name == "tag_editor_icon_elem_btn" then
      handle_icon_selection(player, element.elem_value)
    elseif element.name == "tag_editor_text_box" and element.type == "textfield" then
      update_tag_data_and_refresh(player, tag_data, {text = element.text})
    end
  end
  if element.name == "tf_confirm_dialog_confirm_btn" then
    local tag = tag_data and tag_data.tag
    local gps = tag and tag.gps
    local chart_tag = tag and tag.chart_tag
    local tag_destroy_helper = require("core.tag.tag_destroy_helper")
    if not gps or type(gps) ~= "string" or gps == "" then
      Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
      show_tag_editor_error(player, tag_data, "The tag has already faded from existence.")
      return
    end
    if not chart_tag then
      local cached_tag = Cache.get_tag_by_gps(gps)
      if cached_tag then
        tag = cached_tag
        chart_tag = cached_tag.chart_tag
      end
    end
    if tag then
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
      if game and type(game.players) == "table" then
        for _, p in pairs(game.players) do
          local pfaves = PlayerFavorites.new(p)
          pfaves:remove_favorite(gps)
        end
      end
      Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
      clear_and_close_tag_editor(player, element)
      player_print(player, {"tf-gui.tag_editor_deleted", "The tag has been banished to the void!"})
    else
      Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
      show_tag_editor_error(player, tag_data, "The tag has already faded from existence.")
    end
  elseif element.name == "tf_confirm_dialog_cancel_btn" then
    Helpers.safe_destroy_frame(player.gui.screen, "tf_confirm_dialog_frame")
    local tag_editor_frame = player.gui.screen["tag_editor_outer_frame"]
    if tag_editor_frame then player.opened = tag_editor_frame end
  end
end

M.on_tag_editor_gui_click = on_tag_editor_gui_click

--- Register tag editor event handlers (deprecated: use shared dispatcher)
function M.register(script)
  -- Deprecated: do not register directly. Use shared dispatcher in gui_base.lua
end

return M
