---@diagnostic disable: undefined-global

-- core/control/teleport_entrypoint.lua
-- Shared teleport entry helper for UI/control paths.
-- Keeps one common execution path while allowing per-source behavior hooks.

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler =
  Deps.BasicHelpers, Deps.ErrorHandler

local TeleportStrategy = require("core.utils.teleport_strategy")
local ProfilerExport = require("core.utils.profiler_export")

---@class TeleportEntrypointOptions
---@field source string|nil
---@field add_to_history boolean|nil Defaults to TeleportStrategy default when nil.
---@field action_name string|nil
---@field action_id string|nil
---@field silent_already_at_target boolean|nil
---@field end_action_on_success boolean|nil Default false.
---@field end_action_on_failure boolean|nil Default true.
---@field on_success fun(player: LuaPlayer, resulting_gps: string|nil, action_id: string|nil)|nil
---@field on_failure fun(player: LuaPlayer, error_code: string, action_id: string|nil)|nil

local M = {}

---@param player LuaPlayer
---@param gps string
---@param opts TeleportEntrypointOptions|nil
---@return boolean success, string result_or_error
function M.execute(player, gps, opts)
  opts = opts or {}
  local source = tostring(opts.source or "unknown")

  if not BasicHelpers.is_valid_player(player) then
    return false, "invalid_player"
  end
  if type(gps) ~= "string" or gps == "" then
    ErrorHandler.warn_log("[TELEPORT_ENTRYPOINT] Invalid GPS", {
      source = source,
      player = player.name,
      gps = gps
    })
    return false, "invalid_gps"
  end

  local action_id = opts.action_id
  if (not action_id or action_id == "") and opts.action_name then
    action_id = ProfilerExport.begin_action_trace(opts.action_name, player.index)
  end

  local end_on_failure = opts.end_action_on_failure ~= false
  if player.surface and BasicHelpers.is_space_platform_surface(player.surface) then
    ErrorHandler.warn_log("[TELEPORT_ENTRYPOINT] Teleport blocked on space platform", {
      source = source,
      player = player.name,
    })
    BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "space_platform_teleport_blocked"))
    if end_on_failure and action_id then
      ProfilerExport.end_action_trace(player.index, action_id)
    end
    return false, "space_platform_teleport_blocked"
  end

  local ok, call_success, call_result = pcall(
    TeleportStrategy.teleport_to_gps,
    player,
    gps,
    opts.add_to_history,
    action_id
  )

  local end_on_success = opts.end_action_on_success == true

  if not ok then
    local call_error = tostring(call_success)
    ErrorHandler.warn_log("[TELEPORT_ENTRYPOINT] Teleport call error", {
      source = source,
      player = player.name,
      error = call_error,
      gps = gps
    })
    if end_on_failure and action_id then
      ProfilerExport.end_action_trace(player.index, action_id)
    end
    return false, call_error
  end

  if call_success then
    if opts.on_success then
      local cb_ok, cb_err = pcall(opts.on_success, player, call_result, action_id)
      if not cb_ok then
        ErrorHandler.warn_log("[TELEPORT_ENTRYPOINT] on_success callback error", {
          source = source,
          player = player.name,
          error = tostring(cb_err)
        })
      end
    end
    if end_on_success and action_id then
      ProfilerExport.end_action_trace(player.index, action_id)
    end
    return true, tostring(call_result or "")
  end

  local err_code = tostring(call_result or "teleport_failed")
  local silent_already = opts.silent_already_at_target and err_code == "already_at_target"
  if (not silent_already) and opts.on_failure then
    local cb_ok, cb_err = pcall(opts.on_failure, player, err_code, action_id)
    if not cb_ok then
      ErrorHandler.warn_log("[TELEPORT_ENTRYPOINT] on_failure callback error", {
        source = source,
        player = player.name,
        error = tostring(cb_err)
      })
    end
  end
  if end_on_failure and action_id then
    ProfilerExport.end_action_trace(player.index, action_id)
  end
  return false, err_code
end

return M
