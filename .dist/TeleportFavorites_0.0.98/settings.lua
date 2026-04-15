local Constants = require("core.constants_impl")
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
  {
    name = "slot-label-mode",
    type = "string-setting",
    setting_type = "runtime-per-user",
    allowed_values = { "off", "short", "long" },
    default_value = Constants.settings.DEFAULT_SLOT_LABEL_MODE,
    order = "ka-3",
    localised_name = {"mod-setting-name.slot-label-mode"},
    localised_description = {"mod-setting-description.slot-label-mode"}
  },
  {
    name = Constants.settings.MP_BISECT_MODE_SETTING,
    type = "string-setting",
    setting_type = "runtime-global",
    default_value = "none",
    allowed_values = {
      "none",
      "no_fave_bar_queue",
      "no_tag_editor",
      "no_history_modal",
      "no_lookups_sweep",
      "no_chart_and_remote",
    },
    order = "zz-mp-bisect",
    localised_name = { "mod-setting-name.tf-mp-bisect-mode" },
    localised_description = { "mod-setting-description.tf-mp-bisect-mode" },
  },
})
