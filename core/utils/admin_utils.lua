---@diagnostic disable: undefined-global

-- core/utils/admin_utils.lua
-- TeleportFavorites Factorio Mod
-- Admin utilities for handling permissions, overrides, and ownership transfer.
-- Provides multiplayer-safe helpers for admin checks, override logic, and audit logging.
-- Uses Factorio's native LuaPlayer.admin property for permission checks.



local ErrorHandler = require("core.utils.error_handler")
local ValidationUtils = require("core.utils.validation_utils")

--- Safely extract last user name from chart tag
---@param chart_tag LuaCustomChartTag
---@return string
local function get_chart_tag_last_user_name(chart_tag)
  if not chart_tag or not chart_tag.valid then return "" end
  local last_user = chart_tag.last_user
  if type(last_user) == "string" then
    return last_user
  elseif type(last_user) == "table" and last_user.name then
    return last_user.name
  end
  return ""
end


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
---@param chart_tag LuaCustomChartTag
---@return boolean can_edit True if player can edit
---@return boolean is_owner True if player is owner
---@return boolean is_admin_override True if admin override
function AdminUtils.can_edit_chart_tag(player, chart_tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid or not chart_tag or not chart_tag.valid then
    return false, false, false
  end
  local last_user_name = get_chart_tag_last_user_name(chart_tag)
  local is_owner = (last_user_name ~= "" and player.name == last_user_name)
  local is_admin = AdminUtils.is_admin(player)
  local can_edit = is_owner or is_admin
  local is_admin_override = (not is_owner) and is_admin
  return can_edit, is_owner, is_admin_override
end

---Checks if the given player can delete a chart tag.
---@param player LuaPlayer
---@param chart_tag LuaCustomChartTag
---@param tag table # Tag object with faved_by_players field
---@return boolean can_delete True if player can delete
---@return boolean is_owner True if player is owner
---@return boolean is_admin_override True if admin override
---@return string|nil reason Reason for denial, or nil if allowed
function AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    return false, false, false, "Invalid player: " .. (player_error or "unknown error")
  end
  if not chart_tag or not chart_tag.valid then
    return false, false, false, "Invalid chart tag"
  end
  local is_admin = AdminUtils.is_admin(player)
  local last_user = get_chart_tag_last_user_name(chart_tag)
  local is_owner = (last_user == "" or last_user == player.name)
  local has_other_favorites = tag and tag.faved_by_players and #tag.faved_by_players > 1
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

---Transfers ownership of a chart tag to an admin player if needed.
---@param chart_tag LuaCustomChartTag
---@param admin_player LuaPlayer
---@return boolean success True if ownership transferred
function AdminUtils.transfer_ownership_to_admin(chart_tag, admin_player)
  local player_valid, player_error = ValidationUtils.validate_player(admin_player)
  if not player_valid then
    ErrorHandler.debug_log("Cannot transfer ownership: invalid admin player", { error = player_error })
    return false
  end
  if not chart_tag or not chart_tag.valid then
    ErrorHandler.debug_log("Cannot transfer ownership: invalid chart tag")
    return false
  end
  local is_admin = AdminUtils.is_admin(admin_player)
  local last_user = get_chart_tag_last_user_name(chart_tag)
  if is_admin and last_user == "" then
    -- Never use rawset on Factorio engine objects; assign via the public property (LuaPlayer).
    -- MULTIPLAYER WARNING: Direct property modification may cause desync
    -- TODO: Replace with destroy-and-recreate pattern for full multiplayer safety
    chart_tag.last_user = admin_player
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

---Logs an admin action for audit purposes.
---@param admin_player LuaPlayer
---@param action string
---@param chart_tag LuaCustomChartTag
---@param additional_data table|nil
function AdminUtils.log_admin_action(admin_player, action, chart_tag, additional_data)
  local player_valid, _ = ValidationUtils.validate_player(admin_player)
  if not player_valid then return end
  local log_data = {
    admin_name = admin_player.name,
    action = action,
    timestamp = game.tick
  }
  if chart_tag and chart_tag.valid then
    log_data.chart_tag_position = chart_tag.position
    log_data.chart_tag_text = chart_tag.text or ""
    log_data.chart_tag_last_user = chart_tag.last_user and chart_tag.last_user.name or ""
  end
  if additional_data then
    for key, value in pairs(additional_data) do
      log_data[key] = value
    end
  end
  ErrorHandler.debug_log("Admin action performed", log_data)
end

return AdminUtils
