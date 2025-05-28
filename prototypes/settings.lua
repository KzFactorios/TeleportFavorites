-- prototypes/settings.lua
-- Defines mod settings for TeleportFavorites

---@diagnostic disable-next-line: undefined-global
data:extend({
  {
    type = "bool-setting",
    name = "favorites-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a"
  }
})
