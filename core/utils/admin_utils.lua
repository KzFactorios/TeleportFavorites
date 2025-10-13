---@diagnostic disable: undefined-global

-- core/utils/admin_utils.lua
-- TeleportFavorites Factorio Mod
-- Admin utilities for handling permissions, overrides, and ownership transfer.
-- Provides multiplayer-safe helpers for admin checks, override logic, and audit logging.
-- Uses Factorio's native LuaPlayer.admin property for permission checks.
-- NOTE: This mod uses Tag.owner_name as the source of truth for ownership, NOT chart_tag.last_user


local ErrorHandler = require("core.utils.error_handler")
local ValidationUtils = require("core.utils.validation_utils")


---@class AdminUtils
local AdminUtils = {}


---Checks if the given player is an admin.
---@param player LuaPlayer
---@return boolean is_admin True if player is admin, false otherwise
function AdminUtils.is_admin(player)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    ErrorHandler.debug_log("Chart tag edit permission check failed: invalid player", { error = player_error })
    return false
  end
  return player.admin == true
end

---Checks if the given player can edit a chart tag (owner or admin override).
---@param player LuaPlayer
---@param tag table Tag object with owner_name field
---@return boolean can_edit True if player can edit
---@return boolean is_owner True if player is owner
---@return boolean is_admin_override True if admin override
function AdminUtils.can_edit_chart_tag(player, tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid or not tag then
    return false, false, false
  end
  
  local owner_name = tag.owner_name or ""
  local is_owner = (owner_name ~= "" and player.name == owner_name)
  local is_admin = AdminUtils.is_admin(player)
  local can_edit = is_owner or is_admin
  local is_admin_override = (not is_owner) and is_admin
  return can_edit, is_owner, is_admin_override
end

---Checks if the given player can delete a chart tag.
---@param player LuaPlayer
---@param tag table Tag object with owner_name and faved_by_players fields
---@return boolean can_delete True if player can delete
---@return boolean is_owner True if player is owner
---@return boolean is_admin_override True if admin override
---@return string|nil reason Reason for denial, or nil if allowed
function AdminUtils.can_delete_chart_tag(player, tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    return false, false, false, "Invalid player: " .. (player_error or "unknown error")
  end
  if not tag then
    return false, false, false, "Invalid tag"
  end
  
  local is_admin = AdminUtils.is_admin(player)
  local owner_name = tag.owner_name or ""
  local is_owner = (owner_name == "" or owner_name == player.name)
  
  -- Check if OTHER players (not the current player) have favorited this tag
  local has_other_favorites = false
  if tag.faved_by_players then
    for _, player_index in ipairs(tag.faved_by_players) do
      if player_index ~= player.index then
        has_other_favorites = true
        break
      end
    end
  end
  
  local can_delete = (is_owner and not has_other_favorites) or is_admin
  local is_admin_override = is_admin and not (is_owner and not has_other_favorites)
  local reason = nil
  if not can_delete then
    if not is_owner and not is_admin then
      reason = "You are not the owner of this tag and do not have admin privileges"
    elseif is_owner and has_other_favorites and not is_admin then
      reason = "Cannot delete tag: other players have favorited this tag"
    end
  end
  return can_delete, is_owner, is_admin_override, reason
end

---Logs an admin action for audit purposes.
---@param admin_player LuaPlayer
---@param action string
---@param tag table|nil Tag object with owner_name
---@param additional_data table|nil
function AdminUtils.log_admin_action(admin_player, action, tag, additional_data)
  local player_valid, _ = ValidationUtils.validate_player(admin_player)
  if not player_valid then return end
  local log_data = {
    admin_name = admin_player.name,
    action = action,
    timestamp = game.tick
  }
  if tag then
    log_data.tag_owner = tag.owner_name or ""
    log_data.tag_gps = tag.gps or ""
  end
  if additional_data then
    for key, value in pairs(additional_data) do
      log_data[key] = value
    end
  end
  ErrorHandler.debug_log("Admin action performed", log_data)
end

return AdminUtils
