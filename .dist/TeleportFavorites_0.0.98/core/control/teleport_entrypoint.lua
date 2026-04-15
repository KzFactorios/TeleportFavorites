local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler =
  Deps.BasicHelpers, Deps.ErrorHandler
local TeleportStrategy = require("core.utils.teleport_strategy")
local ProfilerExport = require("core.utils.profiler_export")
local M = {}
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
  local ok, call_success, call_result = pcall(
    TeleportStrategy.teleport_to_gps,
    player,
    gps,
    opts.add_to_history,
    action_id
  )
  local end_on_success = opts.end_action_on_success == true
  local end_on_failure = opts.end_action_on_failure ~= false
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
