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
    setting_type = "startup",
    default_value = Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL,
    minimum_value = Constants.settings.MIN_UPDATE_INTERVAL,
    maximum_value = Constants.settings.MAX_UPDATE_INTERVAL,
    hidden = true,
    order = "kb",
  },
  {
    name = "chart-tag-click-radius",
    type = "int-setting",
    setting_type = "startup",
    default_value = Constants.settings.CHART_TAG_CLICK_RADIUS,
    minimum_value = 1,
    maximum_value = 25,
    allowed_values = {1, 5, 10, 15, 20, 25},
    hidden = true,
    order = "kc",
  }
})
