local Constants = require("constants")

data:extend({  {
    name = "teleport-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.TELEPORT_RADIUS_DEFAULT,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = Constants.settings.TELEPORT_RADIUS_MIN,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = Constants.settings.TELEPORT_RADIUS_MAX,
    allowed_values = {1, 2, 4, 8, 16, 32},
    order = "kg",
  },
  {
    name = "favorites-on",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "ka",
  },  {
    name = "destination-msg-on",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "kd",
  },  {
    name = "terrain-protection-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.TERRAIN_PROTECTION_DEFAULT,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = Constants.settings.TERRAIN_PROTECTION_MIN,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = Constants.settings.TERRAIN_PROTECTION_MAX,
    order = "ke",
  },
  {
    name = "chart-tag-click-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.CHART_TAG_CLICK_RADIUS,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = 1,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = 32,
    allowed_values = {1, 2, 4, 8, 16, 32},
    order = "kf",
  }
})
