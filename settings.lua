---@diagnostic disable: undefined-global

local Constants = require("constants")


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
    name = "max-favorite-slots",
    type = "string-setting",
    setting_type = "runtime-per-user",
    allowed_values = { "10", "20", "30" },
    default_value = tostring(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS),
    order = "ka-2",
    localised_name = {"mod-setting-name.max-favorite-slots"},
    localised_description = {"mod-setting-description.max-favorite-slots"}
  },
})
