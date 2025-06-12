-- prototypes/settings.lua
-- Defines mod settings for TeleportFavorites

---@diagnostic disable-next-line: undefined-global
data:extend({
  {
    type = "bool-setting",
    name = "favorites-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "sa",
    localised_name = {"setting-name.favorites-on"},
    localised_description = {"setting-description.favorites-on"}
  },
  {
    type = "int-setting",
    name = "teleport-radius",
    setting_type = "runtime-per-user",
    default_value = 8,
    minimum_value = 1,
    maximum_value = 32,
    order = "sb",
    localised_name = {"setting-name.teleport-radius"},
    localised_description = {"setting-description.teleport-radius"}
  },  {
    type = "bool-setting",
    name = "destination-msg-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "sc",
    localised_name = {"setting-name.destination-msg-on"},
    localised_description = {"setting-description.destination-msg-on"}
  },
  {
    type = "bool-setting",
    name = "map-reticle-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "sd",
    localised_name = {"setting-name.map-reticle-on"},
    localised_description = {"setting-description.map-reticle-on"}
  }
})
