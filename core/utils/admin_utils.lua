

-- core/utils/admin_utils.lua
-- TeleportFavorites Factorio Mod
-- Admin utilities for handling permissions, overrides, and ownership transfer.
-- Provides multiplayer-safe helpers for admin checks, override logic, and audit logging.
-- Uses Factorio's native LuaPlayer.admin property for permission checks.
--
-- API:
--   AdminUtils.is_admin(player): Returns true if player is admin.
--   AdminUtils.can_edit_chart_tag(player, chart_tag): Checks if player can edit chart tag (owner or admin).
--   AdminUtils.can_delete_chart_tag(player, chart_tag, tag): Checks if player can delete chart tag.
--   AdminUtils.transfer_ownership_to_admin(chart_tag, admin_player): Transfers ownership to admin if needed.
--   AdminUtils.log_admin_action(admin_player, action, chart_tag, additional_data): Logs admin actions for audit.
---@diagnostic disable: undefined-global
local AdminUtils = {}

function AdminUtils.is_admin(player)
  if player_valid then
    return player.admin == true
  end
  if not player_valid then
    ErrorHandler.debug_log("Chart tag edit permission check failed: invalid player", { error = player_error })
    return false, false, false
  end
  if not chart_tag or not chart_tag.valid then
    ErrorHandler.debug_log("Chart tag edit permission check: invalid chart tag", {})
    return false, false, false
  end
  local is_admin = AdminUtils.is_admin(player)
  local is_owner = (get_last_user_name(chart_tag) == "" or get_last_user_name(chart_tag) == player.name)
  return is_owner or is_admin, is_owner, is_admin and not is_owner
end

function AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    return false, false, false, "Invalid player: " .. (player_error or "unknown error")
  end
  if not chart_tag or not chart_tag.valid then
    return false, false, false, "Invalid chart tag"
  end
  local is_admin = AdminUtils.is_admin(player)
  local last_user = get_last_user_name(chart_tag)
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
  local last_user = get_last_user_name(chart_tag)
  if is_admin and last_user == "" then
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
    log_data.chart_tag_last_user = get_last_user_name(chart_tag)
  end
  if additional_data then
    for key, value in pairs(additional_data) do
      log_data[key] = value
    end
  end
  ErrorHandler.debug_log("Admin action performed", log_data)
end

return AdminUtils
