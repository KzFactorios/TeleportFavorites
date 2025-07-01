--[[
Small Helper Utilities for TeleportFavorites
===========================================
Module: core/utils/small_helpers.lua

Consolidated small helper utilities that were under 20 lines each.
Combines functionality from favorite_slot_utils.lua, position_tile_helpers.lua, 
and gui_partial_update_utils.lua.
]]

local basic_helpers = require("core.utils.basic_helpers")

local SmallHelpers = {}

-- ===========================
-- FAVORITE SLOT UTILITIES
-- ===========================

function SmallHelpers.is_locked_favorite(fav)
  return fav and fav.locked == true
end

function SmallHelpers.is_empty_favorite(fav)
  return not fav or not fav.gps or fav.gps == ""
end

function SmallHelpers.is_blank_favorite(fav)
  return not fav or (not fav.gps and not fav.text)
end

-- ===========================
-- POSITION TILE HELPERS
-- ===========================

function SmallHelpers.normalize_position(map_position)
  if not map_position then
    return {x = 0, y = 0}
  end
  
  local x, y = basic_helpers.get_position_x_y(map_position)
  return {x = math.floor(x), y = math.floor(y)}
end

function SmallHelpers.needs_normalization(position)
  return position and (not basic_helpers.is_whole_number(position.x) or
    not basic_helpers.is_whole_number(position.y))
end

function SmallHelpers.is_valid_position(position)
  return position and position.x and position.y and true or false
end

-- ===========================
-- GUI PARTIAL UPDATE HELPERS
-- ===========================

function SmallHelpers.update_error_message(update_fn, player, message)
  if update_fn and player then
    update_fn(player, message)
  end
end

function SmallHelpers.update_state_toggle(toggle_fn, player, state)
  if toggle_fn and player then
    toggle_fn(player, state)
  end
end

function SmallHelpers.update_state(update_fn, player, state)
  if update_fn then
    update_fn(player, state)
  end
end

function SmallHelpers.update_success_message(update_fn, player, message)
  if update_fn and player then
    update_fn(player, message)
  end
end

return SmallHelpers
