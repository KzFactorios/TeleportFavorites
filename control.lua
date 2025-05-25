local Constants = require("constants")
local Tag = require("core.tag.tag")
local PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local GPS = require("core.gps.gps")

---@diagnostic disable: undefined-global
---@class Control
local Control = {}
Control.__index = Control

--- Called once when the mod is first initialized (new save or mod added)
script.on_init(function()
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

-- Register custom input for opening tag editor (right-click or hotkey)
--[[script.on_event(Constants.events.ON_OPEN_TAG_EDITOR, function(event)
  --TagEditorGUI.on_open_tag_editor(event)
end)]]

-- Register teleport hotkeys
for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
  local event_name = Constants.events.TELEPORT_TO_FAVORITE .. tostring(i)
  script.on_event(event_name, function(event)
    Favorite.on_teleport_to_favorite(event, i)
  end)
end

-- Factorio chart tag events (see https://lua-api.factorio.com/latest/events.html)
-- These are the correct event names:
-- on_chart_tag_added, on_chart_tag_modified, on_chart_tag_removed

script.on_event(defines.events.on_chart_tag_added, function(event)
  -- if no matching tag exists in the cache create a matching tag and save in storage.
  -- update the map that tracks tags
end)

-- Move require inside function to break require cycle
local function get_cache()
  return require("core.cache.cache")
end

script.on_event(defines.events.on_chart_tag_modified, function(event)
  local Cache = get_cache()
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not player or not event.tag or not event.tag.valid then return end

  -- Assign last_user if missing
  if not event.tag.last_user or event.tag.last_user == "" then
    event.tag.last_user = player.name
  end
  if not event.tag.last_user or event.tag.last_user ~= player.name then
    return -- Only allow the owner to modify
  end

  ---@type string?
  local new_gps = (event.tag.position and GPS.gps_from_map_position(event.tag.position, event.tag.surface and event.tag.surface.index or player.surface.index))
  ---@type string?
  local old_gps = (event.old_position and GPS.gps_from_map_position(event.old_position, event.old_surface and event.old_surface.index or player.surface.index))
  if not new_gps or not old_gps then return end

  ---@type LuaCustomChartTag
  local old_chart_tag = Lookups.get_chart_tag_by_gps(old_gps)
  ---@type LuaCustomChartTag
  local new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)

  if not new_chart_tag then
    local chart_tag_spec = {
      -- fill as needed
    }
    -- Add new_chart_tag to storage and refresh Lookups
    Lookups.clear_chart_tag_cache(event.tag.surface and event.tag.surface.index or player.surface.index)
    new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    if not new_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end

  local old_tag = Cache.get_tag_by_gps(old_gps)
  if not old_tag then
    ---@type Tag
    old_tag = Tag.new(new_gps, {})
  end

  -- Update the tag's GPS and chart_tag
  old_tag.gps = new_gps
  old_tag.chart_tag = new_chart_tag

  if old_chart_tag ~= nil and old_chart_tag.valid then
    -- Use the destruction helper to avoid recursion/stack overflow
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag)
  end

  -- Update all player favorites referencing old_gps
  for _, p in pairs(game.players) do
    local faves = Cache.get_player_favorites(p)
    for _, fav in ipairs(faves) do
      if fav.gps == old_gps then
        fav.gps = new_gps
      end
    end
  end
end)

script.on_event(defines.events.on_chart_tag_removed, function(event)
  local Cache = get_cache()
  if not event or not event.tag or not event.tag.valid then return end
  -- Find the tag associated with this chart_tag (if any)
  local chart_tag = event.tag
  local gps = GPS.gps_from_map_position(chart_tag.position, chart_tag.surface and chart_tag.surface.index or 1)
  local tag = Cache.get_tag_by_gps(gps)
  -- Only destroy if not already being destroyed
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end)

return Control
