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
  
  -- Handle both array-style [x, y] and object-style {x = ..., y = ...} positions
  local x, y
  if map_position.x ~= nil and map_position.y ~= nil then
    x, y = map_position.x, map_position.y
  elseif type(map_position) == "table" and #map_position >= 2 then
    x, y = map_position[1], map_position[2]
  else
    return {x = 0, y = 0}
  end
  
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

-- ===========================
-- SPACE PLATFORM DETECTION
-- ===========================

--- Check if player should have favorites bar hidden due to space platform editing
---@param player LuaPlayer The player to check
---@return boolean should_hide_bar True if the bar should be hidden
function SmallHelpers.should_hide_favorites_bar_for_space_platform(player)
  if not player or not player.valid then return false end
  
  local surface = player.surface
  
  -- Check if player is on a space platform surface
  if surface and surface.platform then
    return true
  end
  
  -- Check if player is in editor mode and the surface appears to be space-related
  -- This handles the case where player is editing a space platform but not physically on it
  if player.controller_type == defines.controllers.editor then
    local surface_name = surface and surface.name or ""
    -- Hide bar if editing any space-related surface
    if surface_name:lower():find("space") or surface_name:lower():find("platform") then
      return true
    end
  end
  
  return false
end

return SmallHelpers
