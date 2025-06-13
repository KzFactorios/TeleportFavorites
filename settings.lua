---@diagnostic disable: undefined-global
-- Simple settings approach for TeleportFavorites
-- Testing if we can define settings without data:extend()

-- Check if data global exists, if not, skip settings for now
if data then
  data:extend({
    {
      type = "bool-setting",
      name = "favorites-on",
      setting_type = "runtime-per-user",
      default_value = true,
      order = "sa"
    },
    {
      type = "int-setting", 
      name = "teleport-radius",
      setting_type = "runtime-per-user",
      default_value = 8,
      minimum_value = 1,
      maximum_value = 32,
      order = "sb"
    },
    {
      type = "bool-setting",
      name = "destination-msg-on",
      setting_type = "runtime-per-user", 
      default_value = true,
      order = "sc"
    },
    {
      type = "bool-setting",
      name = "map-reticle-on",
      setting_type = "runtime-per-user",
      default_value = true,
      order = "sd"
    }
  })
else
  -- Log that settings couldn't be loaded
  log("TeleportFavorites: data global not available during settings stage")
end

