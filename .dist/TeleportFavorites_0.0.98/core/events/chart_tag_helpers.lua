local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, GPSUtils =
  Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils
local BasicHelpers = Deps.BasicHelpers
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local Tag = require("core.tag.tag")
local fave_bar = require("gui.favorites_bar.fave_bar")
local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus
local function rebuild_bars(players)
  for _, p in ipairs(players) do
    if p and p.valid then fave_bar.build(p) end
  end
end
local ChartTagHelpers = {}
function ChartTagHelpers.is_valid_tag_modification(event, player)
  if not player or not player.valid then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid player", { event = event })
    return false
  end
  if not event.tag or not event.tag.valid then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid tag", { event = event, player = player and player.name or nil })
    return false
  end
  if not event.tag.position then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid tag position", { event = event, player = player and player.name or nil })
    return false
  end
  if not event.old_position then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid old position", { event = event, player = player and player.name or nil })
    return false
  end
  local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
  local old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
  local tag = old_gps and Cache.get_tag_by_gps(player, old_gps) or nil
  local can_edit, _is_owner, is_admin_override = ChartTagUtils.can_edit_chart_tag(player, tag)
  if not can_edit then
    ErrorHandler.debug_log("Chart tag modification rejected: insufficient permissions", {
      player_name = player and player.name or nil,
      tag_owner = tag and tag.owner_name or "",
      is_admin = ChartTagUtils.is_admin(player)
    })
    return false
  end
  if is_admin_override then
    ChartTagUtils.log_admin_action(player, "modify_chart_tag", tag, {})
  end
  return true
end
function ChartTagHelpers.extract_gps(event, player)
  local new_gps = nil
  local old_gps = nil
  if event.tag and event.tag.valid then
    local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
    new_gps = GPSUtils.gps_from_map_position(event.tag.position, surface_index)
  end
  if event.old_position then
    local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
    old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
  else
    ErrorHandler.debug_log("WARNING: No old_position provided in chart tag modification event", {
      tag_text = event.tag and event.tag.text or "nil",
      new_gps = new_gps
    })
  end
  return new_gps, old_gps
end
function ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, preserve_owner_name)
  if not old_gps or not new_gps then return end
  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end
  local modified_chart_tag = event.tag
  if old_gps then
    Cache.Lookups.evict_chart_tag_cache_entry(old_gps)
  end
  Tag.update_gps_and_surface_mapping(old_gps, new_gps, modified_chart_tag, player, preserve_owner_name)
end
function ChartTagHelpers.update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end
  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil
  local all_affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, nil)
  if acting_player and acting_player.valid then
    local acting_player_favorites = PlayerFavorites.new(acting_player)
    local acting_player_updated = acting_player_favorites:update_gps_coordinates(old_gps, new_gps)
    local acting_player_already_included = false
    for _, player in ipairs(all_affected_players) do
      if player.index == acting_player_index then
        acting_player_already_included = true
      end
    end
    if acting_player_updated and not acting_player_already_included then
      table.insert(all_affected_players, acting_player)
    end
    Cache.Lookups.evict_chart_tag_cache_entry(old_gps)
  end
  rebuild_bars(all_affected_players)
  local notification_players = {}
  for _, player in ipairs(all_affected_players) do
    if player and player.index and player.index ~= acting_player_index then
      table.insert(notification_players, player)
    end
  end
  if #notification_players > 0 then
    local old_position = GPSUtils.map_position_from_gps(old_gps)
    local new_position = GPSUtils.map_position_from_gps(new_gps)
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)
    for _, affected_player in ipairs(notification_players) do
      if affected_player and affected_player.valid then
        local position_msg = BasicHelpers.format_tag_position_change_notification(
          affected_player, chart_tag, old_position or { x = 0, y = 0 }, new_position or { x = 0, y = 0 }
        )
        BasicHelpers.safe_player_print(affected_player, position_msg)
      end
    end
  end
end
function ChartTagHelpers.update_tag_metadata(gps, chart_tag, acting_player)
  if not gps or not chart_tag or not chart_tag.valid then return end
  if not acting_player or not acting_player.valid then return end
  local surface_tags = Cache.get_surface_tags(acting_player.surface.index)
  local stored_tag = surface_tags and surface_tags[gps]
  local function notify_one(game_player)
    local player_favorites = PlayerFavorites.new(game_player)
    if not player_favorites:get_favorite_by_gps(gps) then return false end
    local affected_slot = nil
    for i, fav in ipairs(player_favorites.favorites) do
      if fav and fav.gps == gps then
        affected_slot = i
        break
      end
    end
    GuiEventBus.notify("cache_updated", {
      type = "tag_metadata_changed",
      player_index = game_player.index,
      gps = gps,
      slot = affected_slot,
    })
    return true
  end
  local notify_indices = {}
  local fbp = stored_tag and stored_tag.faved_by_players
  if fbp and type(fbp) == "table" and next(fbp) ~= nil then
    local seen = {}
    for k, v in pairs(fbp) do
      local pid = nil
      if type(v) == "number" and v >= 1 then
        pid = v
      elseif type(k) == "number" and k >= 1 and (v == true or v == k) then
        pid = k
      end
      if pid and not seen[pid] then
        seen[pid] = true
        local game_player = game.players[pid]
        if game_player and game_player.valid and game_player.connected then
          notify_indices[#notify_indices + 1] = pid
        end
      end
    end
  else
    BasicHelpers.for_each_connected_player_by_index_asc(function(game_player)
      notify_indices[#notify_indices + 1] = game_player.index
    end)
  end
  table.sort(notify_indices)
  local notified = 0
  for _, pid in ipairs(notify_indices) do
    local game_player = game.players[pid]
    if game_player and game_player.valid and notify_one(game_player) then
      notified = notified + 1
    end
  end
  ErrorHandler.debug_log("Deferred tag metadata update for affected players", {
    gps = gps,
    players_notified = notified,
    new_text = chart_tag.text or "",
    acting_player = acting_player.name
  })
end
return ChartTagHelpers
