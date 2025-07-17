local Constants = require("constants")

---@diagnostic disable-next-line: undefined-global, param-type-mismatch, missing-parameter, duplicate-set-field
data:extend({
  {
    name = "favorites_on",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "ka",
  },
  {
    name = "enable_teleport_history",
    type = "bool-setting",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "ka-1",
  },
  {
    name = "history-update-interval", 
    type = "int-setting",
    setting_type = "runtime-global",
    ---@diagnostic disable-next-line: undefined-field
    default_value = Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL,
    ---@diagnostic disable-next-line: undefined-field
    minimum_value = Constants.settings.MIN_UPDATE_INTERVAL,
    ---@diagnostic disable-next-line: undefined-field
    maximum_value = Constants.settings.MAX_UPDATE_INTERVAL,
    order = "kb",
  },
  {
    name = "chart-tag-click-radius",
    type = "int-setting",
    setting_type = "runtime-per-user",
    ---@diagnostic disable-next-line: undefined-field
    default_value = Constants.settings.CHART_TAG_CLICK_RADIUS,
    ---@diagnostic disable-next-line: assign-type-mismatch
    minimum_value = 1,
    ---@diagnostic disable-next-line: assign-type-mismatch
    maximum_value = 25,
    allowed_values = {1, 5, 10, 15, 20, 25},
    order = "kc",
  }
})
