local Cache = require("core/cache/cache")
local Lookups = Cache.lookups

---@diagnostic disable: undefined-global
---@class Control
local Control = {}
Control.__index = Control

--- Called once when the mod is first initialized (new save or mod added)
script.on_init(function()
  Cache.init()
  -- Add any additional initialization logic here
end)

--- Called every time a save is loaded (including after on_init)
script.on_load(function()
  -- Re-initialize runtime-only structures if needed
  -- (Persistent data is already loaded by Factorio)
  -- Add any runtime re-initialization logic here
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  -- event.surface is not guaranteed, so use player.surface.index
  -- TODO test for player surface being the new surface
  local surface_index = player.surface.index
  Lookups.ensure_surface_cache(surface_index)
  -- TODO init any other surface oriented data structures
end)

return Control
