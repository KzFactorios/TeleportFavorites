local Constants = require("constants")

data:extend({
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
    name = "chart-tag-click-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.CHART_TAG_CLICK_RADIUS,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = 1,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = 25,
    allowed_values = {1, 5, 10, 15, 20, 25},
    order = "kf",
  }
})
