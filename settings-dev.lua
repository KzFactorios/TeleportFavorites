-- Developer Tools Settings
-- This file contains settings that are only used in development mode

data:extend({
  {
    type = "bool-setting",
    name = "teleport-favorites-dev-positionator-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "z-a"
  },
  {
    type = "bool-setting",
    name = "teleport-favorites-dev-debug-mode",
    setting_type = "runtime-global",
    default_value = false,
    order = "z-b"
  }
})
