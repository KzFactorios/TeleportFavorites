---@diagnostic disable: undefined-global


local BasicHelpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local CursorUtils = require("core.utils.cursor_utils")
local tag_editor = require("gui.tag_editor.tag_editor")
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Enum = require("prototypes.enums.enum")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ChartTagHelpers = require("core.events.chart_tag_helpers")

---@param player_index number Player index from event
---@param handler_fn function Function to call with validated player
---@param ... any Additional arguments to pass to handler
---@return any Result from handler function, or nil if player invalid
local function with_valid_player(player_index, handler_fn, ...)
  if not player_index then return nil end
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return nil end
  return handler_fn(player, ...)
end

local handlers = {}

local function register_gui_observers(player)
  local ok, gui_observer = pcall(require, "core.pattern.gui_observer")
end

function handlers.on_player_changed_surface(event)
  with_valid_player(event.player_index, function(player)
    if player.surface and player.surface.valid and player.surface.index ~= event.surface_index then
      Cache.ensure_surface_cache(event.surface_index)


    end
  end)
end

function handlers.on_init()
  Cache.init()

  for _, player in pairs(game.players) do
    if Cache.get_player_data(player) == nil then
      Cache.reset_transient_player_states(player)

      storage.players[player.index].data_viewer_settings = nil
    end

    register_gui_observers(player)
    fave_bar.build(player, true)
  end

end

function handlers.on_load()
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    Cache.reset_transient_player_states(player)
    fave_bar.build(player, true)
    register_gui_observers(player)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    fave_bar.build(player, true)
  end)
end

function handlers.on_open_tag_editor_custom_input(event)
  with_valid_player(event.player_index, function(player)
    local can_open, reason = TagEditorEventHelpers.validate_tag_editor_opening(player)
    if not can_open then
      if reason == "Drag mode active" then
        CursorUtils.end_drag_favorite(player)
        if player and player.play_sound then
          player.play_sound { path = "utility/cancel" }
        end
      end
      return
    end

    local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
    local cursor_position = event.cursor_position
    local chart_tag = cursor_position and cursor_position.x and cursor_position.y and
        TagEditorEventHelpers.find_nearby_chart_tag(cursor_position, player.surface.index,
          Cache.Settings.get_chart_tag_click_radius(player))

    if chart_tag and chart_tag.valid then
      local gps = GPSUtils.gps_from_map_position(chart_tag.position,
        tonumber(chart_tag.surface and chart_tag.surface.index or player.surface.index) or 1)
      local player_favorites = PlayerFavorites.new(player)
      local favorite_entry = player_favorites:get_favorite_by_gps(gps)
      local icon = chart_tag.icon

      tag_data.chart_tag = chart_tag
      tag_data.tag = {
        chart_tag = chart_tag,
        gps = gps,
        icon = icon,
        text = chart_tag.text,
        last_user = chart_tag.last_user,
      }
      tag_data.gps = gps
      tag_data.is_favorite = favorite_entry ~= nil
      tag_data.icon = icon
      tag_data.text = chart_tag.text
    elseif tag_data.tag and tag_data.tag.gps and tag_data.tag.gps ~= "" then
      tag_data.gps = tag_data.tag.gps
    elseif cursor_position and cursor_position.x and cursor_position.y then
      tag_data.gps = GPSUtils.gps_from_map_position(cursor_position, tonumber(player.surface.index) or 1)
    end

    Cache.set_tag_editor_data(player, tag_data)
    tag_editor.build(player)
  end)
end

function handlers.on_chart_tag_added(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag added with fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position
      })
      local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
    end
  end

  Cache.Lookups.invalidate_surface_chart_tags(player.surface.index)
end

function handlers.on_chart_tag_modified(event)
  if not event or not event.old_position then return end
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  if not ChartTagHelpers.is_valid_tag_modification(event, player) then
    ErrorHandler.debug_log("Chart tag modification validation failed", {
      player_name = player.name
    })
    return
  end

  local new_gps, old_gps = ChartTagHelpers.extract_gps(event, player)
  local tag_editor_data = Cache.get_tag_editor_data(player)
  if tag_editor_data and tag_editor_data.gps == old_gps then
    tag_editor_data.gps = new_gps
    if tag_editor_data.tag then
      tag_editor_data.tag.gps = new_gps
    end
    Cache.set_tag_editor_data(player, tag_editor_data)
    local tag_editor_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
    if tag_editor_frame and tag_editor_frame.valid then
      local teleport_btn = GuiValidation.find_child_by_name(tag_editor_frame, "tag_editor_teleport_button")
      if teleport_btn and teleport_btn.valid then
        ---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
        local coords_result = GPSUtils.coords_string_from_gps(new_gps)
        local coords = coords_result or ""
        ---@diagnostic disable-next-line: assign-type-mismatch
        teleport_btn.caption = { "tf-gui.teleport_to", coords }
      end
    end
  end
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag has fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position,
        old_gps = old_gps,
        new_gps = new_gps
      })

      local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
      if new_chart_tag then
        local surface_index = new_chart_tag.surface and new_chart_tag.surface.index or 1
        local normalized_gps = GPSUtils.gps_from_map_position(new_chart_tag.position, tonumber(surface_index) or 1)
        if old_gps and normalized_gps and old_gps ~= normalized_gps then
          local normalized_event = {
            tag = new_chart_tag,
            old_position = event.old_position,
            player_index = event.player_index
          }
          ChartTagHelpers.update_tag_and_cleanup(old_gps, normalized_gps, normalized_event, player)
          ChartTagHelpers.update_favorites_gps(old_gps, normalized_gps, player)
        end
      end
      if old_gps and new_gps and old_gps ~= new_gps then
        ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
        ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
      end
    elseif old_gps and new_gps and old_gps ~= new_gps then
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
      ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
    end
  end
end

function handlers.on_chart_tag_removed(event)
  with_valid_player(event.player_index, function(player)
    local chart_tag = event.tag
    if not chart_tag or not chart_tag.valid then return end

    local is_admin = player.admin
    local is_owner = (chart_tag.last_user and chart_tag.last_user.name == player.name)
    if not is_admin and not is_owner then
      if chart_tag.position and chart_tag.surface then
        player.surface.create_entity {
          name = chart_tag.name or "tf-chart-tag",
          position = chart_tag.position,
          force = player.force,
          text = chart_tag.text or "",
          icon = chart_tag.icon,
          last_user = player
        }
      end
      if Cache and Cache.Lookups and Cache.Lookups.invalidate_surface_chart_tags then
        Cache.Lookups.invalidate_surface_chart_tags(player.surface.index)
      end
      return
    end

    local gps = GPSUtils.gps_from_map_position(chart_tag.position,
      chart_tag.surface and chart_tag.surface.index or player.surface.index)
    local tag = Cache.get_tag_by_gps(player, gps)
    if tag then
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
    end

    Cache.Lookups.invalidate_surface_chart_tags(player.surface.index)

  end)
end

return handlers
