local Constants = require("constants")

data:extend({
  {
    name = "teleport-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.TELEPORT_RADIUS_DEFAULT,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = Constants.settings.TELEPORT_RADIUS_MIN,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = Constants.settings.TELEPORT_RADIUS_MAX,
    order = "kg",
  },
  {
    name = "favorites-on",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "ka",
  },
  {
    name = "destination-msg-on",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "kd",
  }
})
