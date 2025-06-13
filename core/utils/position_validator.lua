---@diagnostic disable: undefined-global
--[[
core/utils/position_validator.lua
TeleportFavorites Factorio Mod
-----------------------------
Position validation and correction utilities for map locations.

This module handles:
- Validation of positions for teleportation (water, space, etc.)
- Finding alternative valid positions when needed
- Position correction notifications
- Managing tag/chart_tag relocation
]]

local Helpers = require("core.utils.helpers_suite")
local ErrorHandler = require("core.utils.error_handler")
local GPSCore = require("core.utils.gps_core")
local Cache = require("core.cache.cache")
local gui_base = require("gui.gui_base")
local lstr = require("core.utils.helpers_suite").get_localized_string
local basic_helpers = require("core.utils.basic_helpers")

---@class PositionValidator
local PositionValidator = {}

--- Check if a position is valid for tagging (no water/space)
---@param player LuaPlayer
---@param map_position MapPosition
---@param skip_notification boolean? Whether to skip player notification on failure
---@return boolean is_valid
function PositionValidator.is_valid_tag_position(player, map_position, skip_notification)
  if not player or not player.valid or not map_position then 
    return false 
  end
  
  -- Check for water or space tiles
  local is_water = Helpers.is_water_tile(player.surface, map_position)
  local is_space = Helpers.is_space_tile(player.surface, map_position)
  
  -- Debug log for position validation
  ErrorHandler.debug_log("Validating position for tagging", {
    position = map_position,
    is_water = is_water,
    is_space = is_space,
    surface = player.surface.name
  })
  
  if is_water or is_space then
    if not skip_notification and player and player.valid then
      local location_gps = GPSCore.gps_from_map_position(map_position, player.surface.index)
      local reason = is_water and "water" or "space"
      player.print("[TeleportFavorites] Cannot tag " .. reason .. " location: " .. location_gps)
    end
    return false
  end
  
  return true
end

--- Find a valid position near a potentially invalid one
---@param player LuaPlayer
---@param map_position MapPosition
---@param search_radius number
---@return MapPosition? valid_position
function PositionValidator.find_valid_position(player, map_position, search_radius)
  if not player or not player.valid or not map_position then 
    return nil
  end

  -- First normalize the position to grid coordinates
  local x = basic_helpers.normalize_index(map_position.x)
  local y = basic_helpers.normalize_index(map_position.y)
  local normalized_pos = { x = x, y = y }
  
  -- First check if the normalized position itself is valid
  if PositionValidator.is_valid_tag_position(player, normalized_pos, true) then
    return normalized_pos
  end
  
  -- Use Factorio's built-in collision detection to find a valid spot
  local valid_position = player.surface:find_non_colliding_position(
    "character", 
    normalized_pos, 
    search_radius or 50, 
    1.0  -- 1.0 precision ensures we check whole tiles
  )
  
  if valid_position then
    -- Re-normalize to ensure whole numbers
    valid_position.x = basic_helpers.normalize_index(valid_position.x)
    valid_position.y = basic_helpers.normalize_index(valid_position.y)
    
    -- Final check to ensure we have a valid position
    if PositionValidator.is_valid_tag_position(player, valid_position, true) then
      return valid_position
    end
  end
  
  return nil
end

--- Show an interactive dialog for the player to choose what to do with an invalid position
---@param player LuaPlayer
---@param tag_data table
---@param callback function
function PositionValidator.show_invalid_position_dialog(player, tag_data, callback)
  if not player or not player.valid or not tag_data then return end
  
  local position = GPSCore.map_position_from_gps(tag_data.gps)
  if not position then return end
  
  -- Get player settings for search radius
  local player_settings = Cache.get_player_data(player)
  local search_radius = player_settings.teleport_radius or 50
  
  -- Try to find a valid position nearby
  local valid_position = PositionValidator.find_valid_position(player, position, search_radius)
  local has_valid_nearby = valid_position ~= nil
  
  -- Determine if player can delete this tag
  local can_delete = tag_data.tag and 
                    (tag_data.tag.player.name == player.name) and 
                    (tag_data.tag.faved_by_players == nil or #tag_data.tag.faved_by_players == 0)
  
  -- Set up dialog
  local dialog_frame = player.gui.screen.add{
    type = "frame",
    name = "tf_invalid_position_dialog",
    direction = "vertical",
    style = "inner_frame_in_outer_frame"
  }
  dialog_frame.auto_center = true
  
  -- Dialog title
  local title_flow = dialog_frame.add{
    type = "flow", 
    direction = "horizontal",
    style = "flib_titlebar_flow"
  }
  title_flow.add{
    type = "label",
    caption = {"", "[img=warning-white] ", lstr("tf-gui.invalid_position_title")},
    style = "frame_title"
  }
  title_flow.add{
    type = "empty-widget",
    style = "flib_titlebar_drag_handle",
    ignored_by_interaction = true
  }
  
  -- Close button
  local close_button = title_flow.add{
    type = "sprite-button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button",
    name = "tf_invalid_position_dialog_close"
  }
  
  -- Message
  local content_frame = dialog_frame.add{
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  }
  content_frame.style.width = 350
  
  local reason = Helpers.is_water_tile(player.surface, position) and "water" or "space"
  content_frame.add{
    type = "label",
    caption = lstr("tf-gui.invalid_position_message", reason, tag_data.gps),
    style = "label"
  }
  
  if has_valid_nearby then
    local new_gps = GPSCore.gps_from_map_position(valid_position, player.surface.index)
    content_frame.add{
      type = "label",
      caption = lstr("tf-gui.valid_position_nearby", new_gps),
      style = "label"
    }
  end
  
  -- Buttons
  local button_flow = content_frame.add{
    type = "flow",
    direction = "horizontal",
    style = "dialog_buttons_horizontal_flow"
  }
  button_flow.style.top_margin = 8
  button_flow.style.horizontal_align = "right"
  
  button_flow.add{type = "empty-widget", style = "flib_dialog_button_spacer"}
  
  if can_delete then
    local delete_button = button_flow.add{
      type = "button",
      name = "tf_invalid_position_dialog_delete",
      caption = lstr("tf-gui.delete_tag"),
      style = "red_button"
    }
  end
  
  if has_valid_nearby then
    local move_button = button_flow.add{
      type = "button",
      name = "tf_invalid_position_dialog_move",
      caption = lstr("tf-gui.move_to_valid"),
      style = "confirm_button"
    }
  end
  
  local cancel_button = button_flow.add{
    type = "button",
    name = "tf_invalid_position_dialog_cancel",
    caption = lstr("tf-gui.cancel"),
    style = "back_button"
  }
  
  -- Store data for the GUI handlers
  gui_base.store_gui_data(dialog_frame, {
    player = player,
    tag_data = tag_data,
    valid_position = valid_position,
    callback = callback
  })
  
  -- Register handlers
  gui_base.register_handlers(
    dialog_frame,
    { 
      on_gui_click = {
        tf_invalid_position_dialog_close = function(e)
          gui_base.close_dialog(e)
        end,
        tf_invalid_position_dialog_cancel = function(e)
          gui_base.close_dialog(e)
        end,
        tf_invalid_position_dialog_delete = function(e)
          local data = gui_base.get_gui_data(e.element.parent.parent.parent)
          gui_base.close_dialog(e)
          if data and data.callback then
            data.callback("delete", data.tag_data)
          end
        end,
        tf_invalid_position_dialog_move = function(e)
          local data = gui_base.get_gui_data(e.element.parent.parent.parent)
          gui_base.close_dialog(e)
          if data and data.callback and data.valid_position then
            local new_gps = GPSCore.gps_from_map_position(
              data.valid_position, 
              data.player.surface.index
            )
            data.tag_data.gps = new_gps
            data.callback("move", data.tag_data)
          end
        end
      }
    }
  )
end

--- Validates a raw position input and then moves a tag to a valid position
--- Wrapper around move_tag_to_valid_position that handles position validation
---@param player LuaPlayer
---@param tag table
---@param chart_tag LuaCustomChartTag
---@param selected_position MapPosition
---@param search_radius number? Optional search radius for finding valid positions
---@param callback function? Optional callback for invalid position dialog response
---@return boolean|nil success If nil, dialog is waiting for user input
function PositionValidator.move_tag_to_selected_position(player, tag, chart_tag, selected_position, search_radius, callback)
  ErrorHandler.debug_log("Validating selected position for tag movement", {
    player_name = player and player.name,
    position = selected_position
  })
  
  if not player or not player.valid or not tag or not selected_position then
    return false
  end
  
  -- Get player settings for search radius if not provided
  if not search_radius then
    local player_settings = Cache.get_player_data(player)
    search_radius = player_settings.teleport_radius or 50
  end
    -- First normalize the position to grid coordinates
  local x = basic_helpers.normalize_index(selected_position.x) or selected_position.x
  local y = basic_helpers.normalize_index(selected_position.y) or selected_position.y
  local normalized_pos = { x = x, y = y }
  
  -- Check if the position is valid
  if PositionValidator.is_valid_tag_position(player, normalized_pos, true) then
    -- Position is valid, proceed with move
    ErrorHandler.debug_log("Position is valid, proceeding with tag movement", {
      normalized_position = normalized_pos
    })
    return PositionValidator.move_tag_to_valid_position(player, tag, chart_tag, normalized_pos)
  else
    -- Position is invalid (water/space), try to find a valid position nearby
    local valid_position = PositionValidator.find_valid_position(player, normalized_pos, search_radius)
    
    if valid_position then
      -- Found a valid position nearby, prompt user
      ErrorHandler.debug_log("Found valid position nearby for invalid selected position", {
        original = normalized_pos,
        valid = valid_position
      })
      
      -- Create tag_data structure for the dialog
      local tag_data = {
        tag = tag,
        chart_tag = chart_tag,
        gps = GPSCore.gps_from_map_position(normalized_pos, player.surface.index)
      }
      
      -- If no callback is provided, use default behavior
      local response_callback = callback or function(action, updated_tag_data)
        if action == "move" then
          local new_position = GPSCore.map_position_from_gps(updated_tag_data.gps)
          if new_position then
            PositionValidator.move_tag_to_valid_position(player, tag, chart_tag, new_position)
            player.print("[TeleportFavorites] Tag moved to valid position: " .. updated_tag_data.gps)
          end
        end
      end
      
      -- Show dialog and let user decide
      PositionValidator.show_invalid_position_dialog(player, tag_data, response_callback)
      return nil -- Dialog opened, waiting for user input
    else
      -- No valid position found nearby
      ErrorHandler.debug_log("No valid position found nearby", {
        search_radius = search_radius,
        position = normalized_pos
      })
      player.print("[TeleportFavorites] No valid position found nearby. Tag movement failed.")
      return false
    end
  end
end

--- Moves a tag to a valid position and updates all related references
---@param player LuaPlayer
---@param tag table
---@param chart_tag LuaCustomChartTag
---@param new_position MapPosition
---@return boolean success
function PositionValidator.move_tag_to_valid_position(player, tag, chart_tag, new_position)
  if not player or not player.valid or not tag or not new_position then
    return false
  end
  
  local new_gps = GPSCore.gps_from_map_position(new_position, player.surface.index)
  if not new_gps then return false end
  
  -- Update tag GPS 
  tag.gps = new_gps
  
  -- Create a new chart tag at the new position (can't directly move existing ones)
  local chart_tag_spec = {
    position = new_position,
    icon = chart_tag and chart_tag.icon or {},
    text = chart_tag and chart_tag.text or ("Tag at " .. new_gps),
    last_user = player.name
  }
  -- First destroy the old chart tag
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end
    -- Create a new chart tag at the valid position using safe wrapper
  local GPSChartHelpers = require("core.utils.gps_chart_helpers")
  local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, player.surface, chart_tag_spec)
  
  if not new_chart_tag or not new_chart_tag.valid then
    player.print("[TeleportFavorites] Failed to move tag to valid position")
    return false
  end
  
  -- Update tag reference to new chart_tag
  tag.chart_tag = new_chart_tag
  
  -- Update all favorites that reference this tag
  for _, fav_player_index in ipairs(tag.faved_by_players or {}) do
    local fav_player = game.players[fav_player_index]
    if fav_player and fav_player.valid then
      local favorites = Cache.get_player_favorites(fav_player)
      
      for i, fav in ipairs(favorites) do
        if fav.gps == tag.gps then
          fav.position = new_position
          -- Notify the player whose favorite was moved
          if fav_player.index ~= player.index then -- Don't notify the player who initiated the move
            fav_player.print({"", "[TeleportFavorites] Your favorite tag at ", tag.gps, 
              " was moved to ", new_gps, " because the original location was invalid."})
          end
        end
      end
    end
  end
  
  return true
end

return PositionValidator
