local SETTING_NAME = "tf-mp-bisect-mode"
local function raw_mode()
  local g = settings and settings.global
  if not g then return "none" end
  local s = g[SETTING_NAME]
  if s and s.value ~= nil then
    return tostring(s.value)
  end
  return "none"
end
local M = {}
function M.raw_mode()
  return raw_mode()
end
function M.no_fave_bar_queue()
  return raw_mode() == "no_fave_bar_queue"
end
function M.no_tag_editor()
  return raw_mode() == "no_tag_editor"
end
function M.no_history_modal()
  return raw_mode() == "no_history_modal"
end
function M.no_lookups_sweep()
  return raw_mode() == "no_lookups_sweep"
end
function M.no_chart_and_remote()
  return raw_mode() == "no_chart_and_remote"
end
return M
