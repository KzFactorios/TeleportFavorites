-- tests/mocks/admin_utils_mock.lua
-- Test mock for AdminUtils and log_calls for admin override tests

if not _G.log_calls then _G.log_calls = {} end
if not _G.AdminUtils then _G.AdminUtils = {} end

-- luacheck: ignore
local admin_utils_mock = {}
admin_utils_mock.can_edit_chart_tag = function(player)
  if player and player.admin then
    return true, false, true -- can_edit, is_owner, is_admin_override
  end
  return false, false, false
end
admin_utils_mock.log_admin_action = function(...)
  if type(_G.log_calls) ~= "table" then _G.log_calls = {} end
  table.insert(_G.log_calls, true)
end
admin_utils_mock.is_admin = function(player)
  return player and player.admin or false
end
admin_utils_mock.transfer_ownership_to_admin = function() end
admin_utils_mock.reset_log_calls = function()
  _G.log_calls = {}
end

_G.AdminUtils = admin_utils_mock
package.loaded["core.utils.admin_utils"] = admin_utils_mock
package.loaded["AdminUtils"] = admin_utils_mock

return admin_utils_mock
