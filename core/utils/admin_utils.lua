---@diagnostic disable: undefined-global
--[[
core/utils/admin_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Admin utilities for handling administrative permissions and overrides.

This module provides:
- Admin permission checks using Factorio's built-in admin system
- Admin override logic for chart tag editing regardless of ownership
- Automatic ownership transfer to admin when last_user is unspecified
- Consistent admin privilege validation across the mod

Features:
---------
- Uses Factorio's native LuaPlayer.admin property for permission checks
- Provides clear distinction between owner permissions and admin overrides
- Handles ownership transfer when admins edit tags with no specified owner
- Comprehensive logging for admin actions for audit purposes
--]]

local ErrorHandler = require("core.utils.error_handler")
local ValidationUtils = require("core.utils.validation_utils")

---@class AdminUtils
local AdminUtils = {}

-- ========================================
-- ADMIN PERMISSION CHECKS
-- ========================================

--- Check if a player has admin privileges
---@param player LuaPlayer|nil Player to check
---@return boolean is_admin True if player has admin privileges
function AdminUtils.is_admin(player)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    ErrorHandler.debug_log("Admin check failed: invalid player", {
      error = player_error
    })
    return false
  end
  
  ---@cast player LuaPlayer
  -- Use Factorio's built-in admin property
  local is_admin = player.admin == true
  
  ErrorHandler.debug_log("Admin permission check", {
    player_name = player.name,
    is_admin = is_admin
  })
  
  return is_admin
end

--- Check if a player can edit a chart tag (either owner or admin)
---@param player LuaPlayer Player to check
---@param chart_tag LuaCustomChartTag|nil Chart tag to check permissions for
---@return boolean can_edit True if player can edit the chart tag
---@return boolean is_owner True if player is the owner (not admin override)
---@return boolean is_admin_override True if editing is allowed due to admin privileges
function AdminUtils.can_edit_chart_tag(player, chart_tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    ErrorHandler.debug_log("Chart tag edit permission check failed: invalid player", {
      error = player_error
    })
    return false, false, false
  end
  
  -- Check if chart tag is valid
  if not chart_tag or not chart_tag.valid then
    ErrorHandler.debug_log("Chart tag edit permission check: invalid chart tag")
    return false, false, false
  end
  
  -- Check if player is admin
  local is_admin = AdminUtils.is_admin(player)
  
  -- Check ownership
  local last_user = chart_tag.last_user or ""
  local is_owner = (last_user == "" or last_user == player.name)
  
  -- Determine edit permissions
  local can_edit = is_owner or is_admin
  local is_admin_override = is_admin and not is_owner
  
  ErrorHandler.debug_log("Chart tag edit permission result", {
    player_name = player.name,
    last_user = last_user,
    is_owner = is_owner,
    is_admin = is_admin,
    can_edit = can_edit,
    is_admin_override = is_admin_override
  })
  
  return can_edit, is_owner, is_admin_override
end

--- Check if a player can delete a chart tag (owner + no other favorites, or admin override)
---@param player LuaPlayer Player to check
---@param chart_tag LuaCustomChartTag|nil Chart tag to check
---@param tag table|nil Tag object with faved_by_players data
---@return boolean can_delete True if player can delete the chart tag
---@return boolean is_owner True if player is the owner
---@return boolean is_admin_override True if deletion is allowed due to admin privileges
---@return string? reason Reason why deletion is not allowed (if can_delete is false)
function AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    return false, false, false, "Invalid player: " .. (player_error or "unknown error")
  end
  
  if not chart_tag or not chart_tag.valid then
    return false, false, false, "Invalid chart tag"
  end
  
  -- Check admin status
  local is_admin = AdminUtils.is_admin(player)
  
  -- Check ownership
  local last_user = chart_tag.last_user or ""
  local is_owner = (last_user == "" or last_user == player.name)
  
  -- Check if other players have favorited this tag
  local has_other_favorites = false
  if tag and tag.faved_by_players then
    for _, fav_player_index in ipairs(tag.faved_by_players) do
      if fav_player_index ~= player.index then
        has_other_favorites = true
        break
      end
    end
  end
  
  -- Determine deletion permissions
  local can_delete_as_owner = is_owner and not has_other_favorites
  local can_delete_as_admin = is_admin  -- Admins can delete any tag
  local can_delete = can_delete_as_owner or can_delete_as_admin
  local is_admin_override = is_admin and not can_delete_as_owner
  
  -- Determine reason if deletion is not allowed
  local reason = nil
  if not can_delete then
    if not is_owner and not is_admin then
      reason = "You are not the owner of this tag and do not have admin privileges"
    elseif is_owner and has_other_favorites and not is_admin then
      reason = "Cannot delete tag: other players have favorited this tag"
    end
  end
  
  ErrorHandler.debug_log("Chart tag deletion permission result", {
    player_name = player.name,
    last_user = last_user,
    is_owner = is_owner,
    is_admin = is_admin,
    has_other_favorites = has_other_favorites,
    can_delete = can_delete,
    is_admin_override = is_admin_override,
    reason = reason
  })
  
  return can_delete, is_owner, is_admin_override, reason
end

-- ========================================
-- ADMIN OWNERSHIP MANAGEMENT
-- ========================================

--- Transfer ownership of a chart tag to an admin if last_user is unspecified
---@param chart_tag LuaCustomChartTag Chart tag to potentially transfer ownership
---@param admin_player LuaPlayer Admin player who will become the new owner
---@return boolean ownership_transferred True if ownership was transferred
function AdminUtils.transfer_ownership_to_admin(chart_tag, admin_player)
  local player_valid, player_error = ValidationUtils.validate_player(admin_player)
  if not player_valid then
    ErrorHandler.debug_log("Cannot transfer ownership: invalid admin player", {
      error = player_error
    })
    return false
  end
  
  ---@cast admin_player LuaPlayer
  
  if not chart_tag or not chart_tag.valid then
    ErrorHandler.debug_log("Cannot transfer ownership: invalid chart tag")
    return false
  end
  
  -- Only transfer if admin and last_user is empty or nil
  local is_admin = AdminUtils.is_admin(admin_player)
  local last_user = chart_tag.last_user or ""
    if is_admin and last_user == "" then
    -- Note: chart_tag.last_user expects a string, not a LuaPlayer
    -- Using rawset to work around type checking issues
    rawset(chart_tag, "last_user", admin_player.name)
    
    ErrorHandler.debug_log("Admin ownership transferred", {
      admin_name = admin_player.name,
      chart_tag_position = chart_tag.position,
      chart_tag_text = chart_tag.text or ""
    })
    
    return true
  end
  
  ErrorHandler.debug_log("Admin ownership transfer skipped", {
    player_name = admin_player.name,
    is_admin = is_admin,
    last_user = last_user,
    reason = not is_admin and "not admin" or "last_user already specified"
  })
  
  return false
end

--- Log admin action for audit purposes
---@param admin_player LuaPlayer Admin who performed the action
---@param action string Description of the action performed
---@param chart_tag LuaCustomChartTag|nil Chart tag involved in the action
---@param additional_data table? Additional data to log
function AdminUtils.log_admin_action(admin_player, action, chart_tag, additional_data)
  local player_valid, _ = ValidationUtils.validate_player(admin_player)
  if not player_valid then
    return
  end
  
  ---@cast admin_player LuaPlayer
  
  local log_data = {
    admin_name = admin_player.name,
    action = action,
    timestamp = game.tick
  }
  
  if chart_tag and chart_tag.valid then
    log_data.chart_tag_position = chart_tag.position
    log_data.chart_tag_text = chart_tag.text or ""
    log_data.chart_tag_last_user = chart_tag.last_user or ""
  end
  
  if additional_data then
    for key, value in pairs(additional_data) do
      log_data[key] = value
    end
  end
  
  ErrorHandler.debug_log("Admin action performed", log_data)
end

return AdminUtils
