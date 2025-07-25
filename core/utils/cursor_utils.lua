---@diagnostic disable: undefined-global

-- core/utils/cursor_utils.lua
-- TeleportFavorites Factorio Mod
-- Cursor utilities for drag-and-drop operations in the favorites bar.
-- Provides multiplayer-safe helpers for starting, ending, and checking drag state.
-- Integrates with Cache and FavoriteUtils for robust player data management.
--
-- API:
--   CursorUtils.start_drag_favorite(player, favorite, slot_index): Begin dragging a favorite slot.
--   CursorUtils.end_drag_favorite(player): End drag and reset player state.
--   CursorUtils.is_dragging_favorite(player): Check if player is currently dragging a favorite.

local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite_utils")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")

local CursorUtils = {}

---@param player LuaPlayer The player
---@param favorite Favorite The favorite being dragged
---@param slot_index number The slot index being dragged from (1-based)
---@return boolean success
function CursorUtils.start_drag_favorite(player, favorite, slot_index)
  if not BasicHelpers.is_valid_player(player) then return false end
  
  if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
    return false
  end
  
  -- Update player data to track drag state
  local player_data = Cache.get_player_data(player)
  player_data.drag_favorite.active = true
  player_data.drag_favorite.source_slot = slot_index
  player_data.drag_favorite.favorite = FavoriteUtils.copy(favorite)
  
  local success = pcall(function()
    player.clear_cursor()    
    -- Use cursor_ghost for visual feedback during drag
    -- Using blueprint as it represents planning/positioning theme
    ---@diagnostic disable-next-line: undefined-field
    player.cursor_ghost = "blueprint"
  end)
  
  if not success then
    ErrorHandler.debug_log("[CURSOR_UTILS] Failed to set cursor ghost", {
      player = player.name
    })
  end
  
  -- Success - both data and visual indicator are set
  return true
end

--- End dragging a favorite - clean up player cache state
---@param player LuaPlayer The player
---@return boolean success
function CursorUtils.end_drag_favorite(player)
  if not BasicHelpers.is_valid_player(player) then
    ErrorHandler.log_error("CursorUtils.end_drag_favorite: Invalid player")
    return false
  end
  
  -- Remove cursor item and clear cursor
  pcall(function()
    player.clear_cursor()
    -- Also clear cursor_ghost if it was set
    ---@diagnostic disable-next-line: undefined-field
    player.cursor_ghost = nil
  end)
  
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
  if not BasicHelpers.is_valid_player(player) then return false, nil end
  
  local player_data = Cache.get_player_data(player)
  
  -- Handle the case where drag_favorite might not be initialized properly
  if not player_data.drag_favorite then
    player_data.drag_favorite = {
      active = false,
      source_slot = nil,
      favorite = nil
    }
    return false, nil
  end
  
  -- Return early if not active
  if not player_data.drag_favorite.active then
    return false, nil
  end
  
  -- Return early if no source slot
  if not player_data.drag_favorite.source_slot then
    return false, nil
  end
  
  return true, player_data.drag_favorite.source_slot
end

return CursorUtils
