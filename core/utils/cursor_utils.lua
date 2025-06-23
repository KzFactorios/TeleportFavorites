-- core/utils/cursor_utils.lua
-- Utilities for visual indicators during drag-and-drop operations

local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite")
local GameHelpers = require("core.utils.game_helpers")
local Cache = require("core.cache.cache")

---@class CursorUtils
local CursorUtils = {}

--- Start dragging a favorite - updates player cache state and sets cursor visuals
---@param player LuaPlayer The player
---@param favorite Favorite The favorite being dragged
---@param slot_index number The slot index being dragged from (1-based)
---@return boolean success
function CursorUtils.start_drag_favorite(player, favorite, slot_index)
  if not player or not player.valid then
    ErrorHandler.log_error("CursorUtils.start_drag_favorite: Invalid player")
    return false
  end
  
  if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
    return false
  end
  
  -- Update player data to track drag state
  local player_data = Cache.get_player_data(player)
  player_data.drag_favorite.active = true
  player_data.drag_favorite.source_slot = slot_index
  player_data.drag_favorite.favorite = FavoriteUtils.copy(favorite)
  
  -- Clear cursor first
  player.clear_cursor()
  
  -- Try to set a visual indicator in the cursor with the favorite's icon if possible
  if player.cursor_stack and player.cursor_stack.valid then
    -- Blueprint approach for visual feedback
    if player.cursor_stack.set_stack("blueprint") then
      -- Blueprint successfully set in cursor
      local label = "Favorite " .. slot_index
      
      -- Use tag text for the label if available
      if favorite.tag and favorite.tag.chart_tag and favorite.tag.chart_tag.text and favorite.tag.chart_tag.text ~= "" then
        label = favorite.tag.chart_tag.text
      end
      
      -- Set the blueprint label
      player.cursor_stack.label = label
      
      -- Try to create a blueprint with a constant combinator holding the signal
      if favorite.tag and favorite.tag.chart_tag and favorite.tag.chart_tag.icon then
        local icon = favorite.tag.chart_tag.icon
        -- pcall here to handle any potential API errors safely
        pcall(function()
          -- Try to set the blueprint signal using entities
          local signal = {type = icon.type, name = icon.name}
          player.cursor_stack.set_blueprint_entities({{
            entity_number = 1,
            name = "constant-combinator",
            position = {x = 0, y = 0},
            control_behavior = {
              filters = {{
                count = 1,
                index = 1,
                signal = signal
              }}
            }
          }})
        end)
      end
      
      -- Provide user feedback
      GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_start", slot_index, label})
      ErrorHandler.debug_log("Set cursor to blueprint with label", { label = label })
    else
      -- Blueprint set failed, try a simpler approach (just text)
      GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_start", slot_index})
    end
  end
  
  -- Success - both data and visual indicator are set
  return true
end

--- End dragging a favorite - clean up player cache state
---@param player LuaPlayer The player
---@return boolean success
function CursorUtils.end_drag_favorite(player)
  if not player or not player.valid then
    ErrorHandler.log_error("CursorUtils.end_drag_favorite: Invalid player")
    return false
  end
  
  -- Clear cursor first to ensure visual indicator is removed
  player.clear_cursor()
  
  -- Reset drag state in player data
  local player_data = Cache.get_player_data(player)
  
  -- Initialize drag_favorite if it doesn't exist
  if not player_data.drag_favorite then
    player_data.drag_favorite = {}
  end
  
  -- Reset all drag state values
  player_data.drag_favorite.active = false
  player_data.drag_favorite.source_slot = nil
  player_data.drag_favorite.favorite = nil
  
  return true
end

--- Check if player is currently dragging a favorite
---@param player LuaPlayer The player
---@return boolean is_dragging
---@return number|nil source_slot
function CursorUtils.is_dragging_favorite(player)
  if not player or not player.valid then return false, nil end
  
  local player_data = Cache.get_player_data(player)
  
  -- Handle the case where drag_favorite might not be initialized properly
  if not player_data.drag_favorite then
    player_data.drag_favorite = {
      active = false,
      source_slot = nil,
      favorite = nil
    }
  end
  
  -- Check if drag is active and has a valid source slot
  if player_data.drag_favorite.active and player_data.drag_favorite.source_slot then
    -- Log the active drag state for debugging
    ErrorHandler.debug_log("[CURSOR_UTILS] Detected active drag operation", {
      player = player.name,
      source_slot = player_data.drag_favorite.source_slot,
      active = player_data.drag_favorite.active
    })
    return true, player_data.drag_favorite.source_slot
  end
  
  return false, nil
end

return CursorUtils
