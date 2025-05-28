--[[
core/events/handlers.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized event handler implementations for TeleportFavorites.

- Handles Factorio events for tag creation, modification, removal, and player actions.
- Ensures robust multiplayer and surface-aware updates to tags, chart tags, and player favorites.
- Uses helpers for tag destruction, GPS conversion, and cache management.
- All event logic is routed through this module for maintainability and separation of concerns.

API:
-----
- handlers.on_init()                  -- Mod initialization logic.
- handlers.on_load()                  -- Runtime-only structure re-initialization.
- handlers.on_player_changed_surface(event) -- Ensures surface cache for player after surface change.
- handlers.on_open_tag_editor(event)  -- (Stub) Handles opening the tag editor GUI.
- handlers.on_teleport_to_favorite(event, i) -- Teleports player to favorite location.
- handlers.on_chart_tag_added(event)  -- (Stub) Handles chart tag creation.
- handlers.on_chart_tag_modified(event) -- Handles chart tag modification, GPS and favorite updates.
- handlers.on_chart_tag_removed(event) -- Handles chart tag removal and cleanup.

--]]

---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- Centralized event handler implementations for TeleportFavorites

local Tag = require("core.tag.tag")
local _PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local GPS = require("core.gps.gps")
local Constants = require("constants")
local Lookups = require("core.cache.lookups")
local _Favorite = require("core.favorite.favorite")
local Cache = require("core.cache.cache")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local _Settings = require("settings")
local Helpers = require("core.utils.helpers_suite")

local handlers = {}

function handlers.on_init()
  for _, player in pairs(game.players) do
    local parent = player.gui.top
    fave_bar.build(player, parent)
  end
end

function handlers.on_load()
  -- Re-initialize runtime-only structures if needed
end

function handlers.on_player_created(event)
  local player = game.get_player(event.player_index)
  if player then
    local parent = player.gui.top
    fave_bar.build(player, parent)
  end
end

function handlers.on_player_changed_surface(event)
  local player = game.get_player(event.player_index)
  if player then
    local parent = player.gui.top
    fave_bar.build(player, parent)
  end
end

function handlers.on_open_tag_editor(_event)
  --TagEditorGUI.on_open_tag_editor(event)
  local stub = ""
end

function handlers.on_open_tag_editor_custom_input(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if player.render_mode ~= defines.render_mode.chart and player.render_mode ~= defines.render_mode.chart_zoomed_in then return end
  local surface = player.surface
  if not surface then
    return
  end
  if not surface.valid or surface.valid ~= true then
    return
  end
  local pos = player.position
  local surface_id
  if surface and surface.valid then
    surface_id = surface
  else
    surface_id = 1
  end
  -- Use dot accessor and pass surface_id and area as arguments (no implicit self)
  local tags = player.force.find_chart_tags(surface_id) or {}
  local parent = player.gui.screen
  if tags and #tags > 0 then
    local tag = tags[1]
    if tag then
      tag_editor.build(player, tag)
    end
  else
    tag_editor.build(player)
  end
end

function handlers.on_teleport_to_favorite(event, i)
  ---@diagnostic disable-next-line: undefined-global
  local player = game.get_player(event.player_index)
  if not player then return end
  local favorites = Cache.get_player_favorites(player)
  if type(favorites) ~= "table" or not i or not favorites[i] then
    player:print({ "teleport-favorite-no-location" })
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
      player:print(result)
    end
  else
    player:print({ "teleport-favorite-no-location" })
  end
end

function handlers.on_chart_tag_added(_event)
  -- if no matching tag exists in the cache create a matching tag and save in storage.
  -- update the map that tracks tags
end

local function is_valid_tag_modification(event, player)
  if not player or not event.tag or not event.tag.valid then return false end
  if not event.tag.last_user or event.tag.last_user == "" then
    event.tag.last_user = player.name
  end
  if not event.tag.last_user or event.tag.last_user ~= player.name then
    return false
  end
  return true
end

local function extract_gps(event, player)
  local new_gps = (event.tag.position and GPS.gps_from_map_position(event.tag.position, event.tag.surface and event.tag.surface.index or player.surface.index))
  local old_gps = (event.old_position and GPS.gps_from_map_position(event.old_position, event.old_surface and event.old_surface.index or player.surface.index))
  return new_gps, old_gps
end

local function get_or_create_chart_tag(new_gps, event, player)
  local old_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
  if not old_chart_tag then
    Lookups.clear_chart_tag_cache(event.tag.surface and event.tag.surface.index or player.surface.index)
    old_chart_tag = Lookups.get_chart_tag_by_gps(new_gps)
    if not old_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end
  return old_chart_tag
end

local function update_tag_and_cleanup(old_gps, new_gps, event, player)
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
end

local function update_favorites_gps(old_gps, new_gps)
  for _, p in pairs(game.players) do
    for _, fav in ipairs(Cache.get_player_favorites(p)) do
      if fav.gps == old_gps then fav.gps = new_gps end
    end
  end
end

function handlers.on_chart_tag_modified(event)
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not is_valid_tag_modification(event, player) then return end
  local new_gps, old_gps = extract_gps(event, player)
  if not new_gps or not old_gps then return end
  update_tag_and_cleanup(old_gps, new_gps, event, player)
  update_favorites_gps(old_gps, new_gps)
end

function handlers.on_chart_tag_removed(event)
  if not event or not event.tag or not event.tag.valid then return end
  local chart_tag = event.tag
  local gps = GPS.gps_from_map_position(chart_tag.position, chart_tag.surface and chart_tag.surface.index or 1)
  local tag = Cache.get_tag_by_gps(gps)
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end

return handlers
