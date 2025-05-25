-- core/events/handlers.lua
-- Centralized event handler implementations for TeleportFavorites

local Tag = require("core.tag.tag")
local PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local GPS = require("core.gps.gps")
local Constants = require("constants")
local Lookups = require("core.lookup.lookups")
local Favorite = require("core.favorite.favorite")

-- Lazy require to break cycles
local function get_cache()
  return require("core.cache.cache")
end

local handlers = {}

function handlers.on_init()
  -- Add any additional initialization logic here
end

function handlers.on_load()
  -- Re-initialize runtime-only structures if needed
end

function handlers.on_player_changed_surface(event)
  ---@diagnostic disable-next-line: undefined-global
  local player = game.get_player(event.player_index)
  if not player then return end
  local surface_index = player.surface.index
  Lookups.ensure_surface_cache(surface_index)
end

function handlers.on_open_tag_editor(event)
  --TagEditorGUI.on_open_tag_editor(event)
end

function handlers.on_teleport_to_favorite(event, i)
  ---@diagnostic disable-next-line: undefined-global
  local player = game.get_player(event.player_index)
  if not player then return end
  local Cache = get_cache()
  local favorites = Cache.get_player_favorites(player)
  if type(favorites) ~= "table" or not i or not favorites[i] then
    player.print(player, { "teleport-favorite-no-location" })
    return
  end
  local favorite = favorites[i]
  if type(favorite) == "table" and favorite.gps ~= nil then
    local gps = favorite.gps
    local pos = GPS.map_position_from_gps(gps)
    if not pos then 
      error({'teleport-favorite-no-matching-position'})
    end
    local surface_index = GPS.get_surface_index(gps)
    ---@diagnostic disable-next-line: undefined-global
    local surface = game.surfaces[surface_index]
    local result = Tag.teleport_player_with_messaging(player, pos, surface)
    if result ~= Constants.enums.return_state.SUCCESS then
      player.print(player, result)
    end
  else
    player.print(player, { "teleport-favorite-no-location" })
  end
end

function handlers.on_chart_tag_added(event)
  -- if no matching tag exists in the cache create a matching tag and save in storage.
  -- update the map that tracks tags
end

function handlers.on_chart_tag_modified(event)
  local Cache = get_cache()
---@diagnostic disable-next-line: undefined-global
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not player or not event.tag or not event.tag.valid then return end
  if not event.tag.last_user or event.tag.last_user == "" then
    event.tag.last_user = player.name
  end
  if not event.tag.last_user or event.tag.last_user ~= player.name then
    return
  end
  local new_gps = (event.tag.position and GPS.gps_from_map_position(event.tag.position, event.tag.surface and event.tag.surface.index or player.surface.index))
  local old_gps = (event.old_position and GPS.gps_from_map_position(event.old_position, event.old_surface and event.old_surface.index or player.surface.index))
  if not new_gps or not old_gps then return end
  local old_chart_tag = Lookups.get_chart_tag_by_gps(old_gps)
  local new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
  if not new_chart_tag then
    Lookups.clear_chart_tag_cache(event.tag.surface and event.tag.surface.index or player.surface.index)
    new_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    if not new_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end
  local old_tag = Cache.get_tag_by_gps(old_gps)
  if not old_tag then
    old_tag = Tag.new(new_gps, {})
  end
  old_tag.gps = new_gps
  old_tag.chart_tag = new_chart_tag
  if old_chart_tag ~= nil and old_chart_tag.valid then
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag)
  end
  
---@diagnostic disable-next-line: undefined-global
  for _, p in pairs(game.players) do
    local faves = Cache.get_player_favorites(p)
    for _, fav in ipairs(faves) do
      if fav.gps == old_gps then
        fav.gps = new_gps
      end
    end
  end
end

function handlers.on_chart_tag_removed(event)
  local Cache = get_cache()
  if not event or not event.tag or not event.tag.valid then return end
  local chart_tag = event.tag
  local gps = GPS.gps_from_map_position(chart_tag.position, chart_tag.surface and chart_tag.surface.index or 1)
  local tag = Cache.get_tag_by_gps(gps)
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end

return handlers
