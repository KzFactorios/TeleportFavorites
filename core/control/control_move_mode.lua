-- filepath: core/control/control_move_mode.lua
-- Handles tag editor move mode logic for TeleportFavorites
-- Extracted for clarity and single responsibility

local GPSUtils = require("core.utils.gps_utils")
local Cache = require("core.cache.cache")
local LocaleUtils = require("core.utils.locale_utils")
local Tag = require("core.tag.tag")
local PositionUtils = require("core.utils.position_utils")

local M = {}

local function safe_player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    pcall(function() player.print(message) end)
  end
end

--- Enter move mode: set flag, show instructions, refresh UI
function M.enter_move_mode(player, tag_data, refresh_tag_editor, script)
  tag_data.move_mode = true
  tag_data.error_message = LocaleUtils.get_error_string(player, "move_mode_select_destination")
  Cache.set_tag_editor_data(player, tag_data)
  refresh_tag_editor(player, tag_data)

  -- Give the player the custom selection tool for move mode
  local stack = player.cursor_stack
  if stack and (not stack.valid_for_read or stack.name ~= "tf-move-tag-selector") then
    player.clear_cursor()
    player.cursor_stack.set_stack("tf-move-tag-selector")
  end
  -- Register map selection handler for the custom tool
  local function on_move(event)
    if event.player_index ~= player.index then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if event.item ~= "tf-move-tag-selector" then return end

    local pos = nil
    if event.area then
      -- Calculate center of selected area
      local left_top = event.area.left_top
      local right_bottom = event.area.right_bottom
      local x = (left_top.x + right_bottom.x) / 2
      local y = (left_top.y + right_bottom.y) / 2
      if not require("core.utils.basic_helpers").is_whole_number(x) or not require("core.utils.basic_helpers").is_whole_number(y) then
        x = require("core.utils.basic_helpers").normalize_index(x)
        y = require("core.utils.basic_helpers").normalize_index(y)
      end
      pos = { x = x, y = y }
    end

    if not pos then
      tag_data.error_message = LocaleUtils.get_error_string(player, "invalid_location_chosen")
      Cache.set_tag_editor_data(player, tag_data)
      refresh_tag_editor(player, tag_data)
      if player and player.valid then
        -- Use correct locale key and string for player_print
        local msg = LocaleUtils.get_error_string(player, "invalid_location_chosen") or "[TeleportFavorites] Invalid location selected."
        safe_player_print(player, msg)
        local ok, err = pcall(function()
          -- GameHelpers.safe_play_sound(player, {path = "utility/cannot_build"})
        end)
        if not ok then
          safe_player_print(player, "[TeleportFavorites] Could not play error sound: " .. tostring(err))
        end
      end
      return
    end

    -- Validate the selected position before moving the tag
    if not PositionUtils.position_can_be_tagged(player, pos) then
      tag_data.error_message = LocaleUtils.get_error_string(player, "invalid_location_chosen")
      Cache.set_tag_editor_data(player, tag_data)
      refresh_tag_editor(player, tag_data)
      if player and player.valid then
        local msg = LocaleUtils.get_error_string(player, "invalid_location_chosen") or "[TeleportFavorites] Invalid location selected."
        safe_player_print(player, msg)
        local ok, err = pcall(function()
          -- GameHelpers.safe_play_sound(player, {path = "utility/cannot_build"})
        end)
        if not ok then
          safe_player_print(player, "[TeleportFavorites] Could not play error sound: " .. tostring(err))
        end
      end
      return
    end

    -- Use the robust tag move utility to move the tag and update all references
    local old_tag = tag_data.tag
    local old_chart_tag = old_tag and old_tag.chart_tag
    local new_gps = GPSUtils.gps_from_map_position(pos, player.surface.index)
    local new_chart_tag = nil
    if old_tag and old_chart_tag and old_chart_tag.valid then
      new_chart_tag = Tag.rehome_chart_tag(player, old_chart_tag, new_gps)

      if new_chart_tag and new_chart_tag.valid then
        old_tag.chart_tag = new_chart_tag
        tag_data.chart_tag = new_chart_tag
        tag_data.gps = new_gps
      else
        tag_data.error_message = LocaleUtils.get_error_string(player, "move_mode_failed")
      end
    else
      tag_data.error_message = LocaleUtils.get_error_string(player, "move_mode_failed")
    end

    tag_data.move_mode = false
    Cache.set_tag_editor_data(player, tag_data)
    refresh_tag_editor(player, tag_data)
    -- Remove the selection tool from the player's cursor
    player.clear_cursor()
    -- Unregister handler
    script.on_event(defines.events.on_player_selected_area, nil)
  end

  script.on_event(defines.events.on_player_selected_area, on_move)
end

--- Cancel move mode and clean up state
---@param player LuaPlayer
---@param tag_data table
---@param refresh_tag_editor function
---@param script table
function M.cancel_move_mode(player, tag_data, refresh_tag_editor, script)
  if not player or not player.valid or not tag_data then return end
  
  -- Reset move mode state
  tag_data.move_mode = false
  tag_data.error_message = ""
  
  -- Clear cursor and remove selection tool
  pcall(function()
    player.clear_cursor()
  end)
  
  -- Update cache and refresh UI
  local Cache = require("core.cache.cache")
  Cache.set_tag_editor_data(player, tag_data)
  if refresh_tag_editor then
    refresh_tag_editor(player, tag_data)
  end
  
  -- Clean up event handler to prevent memory leak
  if script and script.on_event then
    script.on_event(defines.events.on_player_selected_area, nil)
  end
  
  require("core.utils.error_handler").debug_log("Move mode canceled and cleaned up", {
    player = player.name,
    player_index = player.index
  })
end

return M
