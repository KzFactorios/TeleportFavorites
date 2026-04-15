local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache
local FavoriteUtils = require("core.favorite.favorite_utils")
local CursorUtils = {}
function CursorUtils.start_drag_favorite(player, favorite, slot_index)
  if not BasicHelpers.is_valid_player(player) then return false end
  if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
    return false
  end
  local player_data = Cache.get_player_data(player)
  player_data.drag_favorite.active = true
  player_data.drag_favorite.source_slot = slot_index
  player_data.drag_favorite.favorite = FavoriteUtils.copy(favorite)
  local success = pcall(function()
    player.clear_cursor()
    player.cursor_ghost = "blueprint"
  end)
  if not success then
    ErrorHandler.debug_log("[CURSOR_UTILS] Failed to set cursor ghost", {
      player = player.name
    })
  end
  return true
end
function CursorUtils.end_drag_favorite(player)
  if not BasicHelpers.is_valid_player(player) then
    ErrorHandler.log_error("CursorUtils.end_drag_favorite: Invalid player")
    return false
  end
  pcall(function()
    player.clear_cursor()
    player.cursor_ghost = nil
  end)
  local player_data = Cache.get_player_data(player)
  if not player_data.drag_favorite then
    player_data.drag_favorite = {}
  end
  player_data.drag_favorite.active = false
  player_data.drag_favorite.source_slot = nil
  player_data.drag_favorite.favorite = nil
  return true
end
function CursorUtils.is_dragging_favorite(player)
  if not BasicHelpers.is_valid_player(player) then return false, nil end
  local player_data = Cache.get_player_data(player)
  if not player_data.drag_favorite then
    player_data.drag_favorite = {
      active = false,
      source_slot = nil,
      favorite = nil
    }
    return false, nil
  end
  if not player_data.drag_favorite.active then
    return false, nil
  end
  if not player_data.drag_favorite.source_slot then
    return false, nil
  end
  return true, player_data.drag_favorite.source_slot
end
return CursorUtils
