---@diagnostic disable: undefined-global
-- Initialize the development environment module
local DevEnvironment = require("core.utils.dev_environment")

-- Register on_init and on_load handlers for development environment detection
script.on_init(function()
  DevEnvironment.init()
end)

script.on_load(function()
  DevEnvironment.init()
end)

-- Register the development environment detection with settings changes
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  -- Re-initialize environment detection if settings change
  if event.setting_type == "runtime-global" or event.setting_type == "runtime-per-user" then
    DevEnvironment.init()
  end
end)

-- If the Positionator module is available, initialize it
local success, Positionator = pcall(function() return require("core.utils.positionator") end)
if success and Positionator and Positionator.init then
  -- Pass the script object to properly register events
  Positionator.init(script)
end
