-- core/events/handlers_chart_tag.lua
-- Chart-tag event handlers extracted from handlers.lua.
-- Extend pattern: called with the handlers table to add functions to it.

local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, GPSUtils, Enum, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils, Deps.Enum, Deps.BasicHelpers
local TagClass = require("core.tag.tag")
local ControlTagEditor = require("core.control.control_tag_editor")
local CursorUtils = require("core.utils.cursor_utils")
local tag_editor = require("gui.tag_editor.tag_editor")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local ChartTagUtils = require("core.utils.chart_tag_utils")

local with_valid_player = BasicHelpers.with_valid_player

-- ===========================
-- TAG EDITOR EVENT HELPERS (from tag_editor_event_helpers.lua)
-- ===========================

local function validate_tag_editor_opening(player)
  if not BasicHelpers.is_valid_player(player) then
    return false, "Invalid player"
  end
  if player.opened ~= nil then
    local opened_type = "unknown"
    if type(player.opened) == "table" then
      if player.opened.object_name == "LuaGuiElement" then
        opened_type = "GUI: " .. (player.opened.name or "unnamed")
      elseif player.opened.object_name then
        opened_type = player.opened.object_name
      end
    end
    return false, "Another GUI is open: " .. opened_type
  end
  if player.opened_gui_type and player.opened_gui_type ~= defines.gui_type.none then
    local gui_type_names = {
      [defines.gui_type.entity] = "entity",
      [defines.gui_type.blueprint_library] = "blueprint_library",
      [defines.gui_type.bonus] = "bonus",
      [defines.gui_type.trains] = "trains",
      [defines.gui_type.achievement] = "achievement",
      [defines.gui_type.item] = "item",
      [defines.gui_type.logistic] = "logistic",
      [defines.gui_type.other_player] = "other_player",
      [defines.gui_type.permissions] = "permissions",
      [defines.gui_type.custom] = "custom",
      [defines.gui_type.server_management] = "server_management",
      [defines.gui_type.player_management] = "player_management",
      [defines.gui_type.tile] = "tile",
      [defines.gui_type.controller] = "controller",
    }
    local gui_type_name = gui_type_names[player.opened_gui_type] or tostring(player.opened_gui_type)
    return false, "Factorio GUI open: " .. gui_type_name
  end
  if Cache.is_modal_dialog_active and Cache.is_modal_dialog_active(player) then
    local modal_type = Cache.get_modal_dialog_type and Cache.get_modal_dialog_type(player)
    return false, "Modal dialog active: " .. (modal_type or "unknown")
  end
  local player_data = Cache.get_player_data(player)
  if player_data and player_data.drag_favorite and player_data.drag_favorite.active then
    return false, "Drag mode active"
  end
  local tag_editor_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if tag_editor_frame and tag_editor_frame.valid then
    return false, "Tag editor already open"
  end
  return true, nil
end

-- MP smoke (manual): two clients, open tag editor from chart and from favorites bar; edit tag text — both bars refresh, no desync.


---@param player LuaPlayer
---@param chart_tag LuaCustomChartTag
---@param tag table?
local function restore_chart_tag_and_refresh(player, chart_tag, tag)
  -- Guard here in addition to the on_chart_tag_removed outer check: if the object became
  -- invalid between the two call sites, accessing chart_tag.position would raise a Lua error
  -- that the outer xpcall would swallow silently, leaving the tag un-restored on that peer.
  if not chart_tag or not chart_tag.valid then return end
  if chart_tag.position and chart_tag.surface then
    local new_chart_tag = player.force.add_chart_tag(
      chart_tag.surface,  -- use the tag's own surface, not the player's current surface
      {
        position  = chart_tag.position,
        text      = chart_tag.text or "",
        icon      = chart_tag.icon,
        last_user = chart_tag.last_user,
      }
    )
    if tag then
      tag.chart_tag = new_chart_tag
    end
  end
  Cache.ensure_surface_cache(tonumber(player.surface.index) or 1)
  fave_bar.build(player)
end

---@param handlers table The handlers table to extend
return function(handlers)

  local function apply_gps_move(old_gps, new_gps, event, player, owner_name)
    ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, owner_name)
    ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
  end

  function handlers.on_open_tag_editor_custom_input(event)
    with_valid_player(event.player_index, function(player)
      if not BasicHelpers.is_chart_render_mode(player) then
        return
      end
      local can_open, reason = validate_tag_editor_opening(player)
      if not can_open then
        if reason == "Drag mode active" then
          CursorUtils.end_drag_favorite(player)
          if player and player.play_sound then
            player.play_sound { path = "utility/cannot_build" }
          end
        end
        return
      end

      local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
      local cursor_position = event.cursor_position
      local chart_tag = cursor_position and cursor_position.x and cursor_position.y and
          ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position)

      if chart_tag and chart_tag.valid then
        local gps = GPSUtils.gps_from_map_position(chart_tag.position,
          tonumber(GPSUtils.get_context_surface_index(chart_tag, player)) or 1)

        -- Seed the GPS cache with the tag we just found so Cache.get_tag_by_gps below
        -- doesn't fire a second find_chart_tags area query for the same tag.
        if gps then Cache.Lookups.seed_chart_tag_in_cache(gps, chart_tag) end

        local player_favorites = PlayerFavorites.new(player)
        local favorite_entry = player_favorites:get_favorite_by_gps(gps)
        local icon = chart_tag.icon

        local tag = Cache.get_tag_by_gps(player, gps)

        tag_data.chart_tag = chart_tag
        if tag then
          tag_data.tag = tag
        else
          tag_data.tag = {
            chart_tag = chart_tag,
            gps = gps,
            icon = icon,
            text = chart_tag.text,
            owner_name = nil,
            faved_by_players = {},
          }
        end
        tag_data.gps = gps
        tag_data.is_favorite = favorite_entry ~= nil
        tag_data.icon = icon
        local chart_text = chart_tag.text
        tag_data.text = type(chart_text) == "string" and chart_text or ""
      elseif tag_data.tag and tag_data.tag.gps and tag_data.tag.gps ~= "" then
        tag_data.gps = tag_data.tag.gps
      elseif cursor_position and cursor_position.x and cursor_position.y then
        tag_data.gps = GPSUtils.gps_from_map_position(cursor_position, tonumber(player.surface.index) or 1)
      end

      Cache.set_tag_editor_data(player, tag_data)
      if storage._tf_tag_editor_marker_defer_at then
        storage._tf_tag_editor_marker_defer_at[player.index] = nil
      end
      tag_editor.build(player)
    end)
  end

  function handlers.on_chart_tag_added(event)
    if not event.player_index then
      ErrorHandler.debug_log("Chart tag added without player_index (added by script or other mod)")
      return
    end

    local player = game.players[event.player_index]
    if not player or not player.valid then return end

    local chart_tag = event.tag
    if not chart_tag or not chart_tag.valid or not chart_tag.position then return end

    local surface_index = player.surface and player.surface.valid and player.surface.index or 1
    Cache.ensure_surface_cache(tonumber(surface_index) or 1)

    local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(surface_index) or 1)
    if gps then
      -- Seed the GPS point cache directly from the event tag; avoids the find_chart_tags
      -- area query that Cache.get_tag_by_gps would otherwise fire on a cache miss.
      Cache.Lookups.seed_chart_tag_in_cache(gps, chart_tag)

      -- Now read back from storage (no Factorio API call, just table lookup).
      local surface_tags = Cache.get_surface_tags(surface_index)
      local tag = surface_tags and surface_tags[gps]
      if not tag then
        tag = TagClass.new(gps, {}, player.name)
        surface_tags[gps] = tag
      else
        tag.owner_name = player.name
      end
    end
  end

  function handlers.on_chart_tag_modified(event)
    if not event or not event.old_position then return end
    if not event.player_index then
      ErrorHandler.debug_log("Chart tag modified without player_index (modified by script or other mod)")
      return
    end

    local player = game.players[event.player_index]
    if not player or not player.valid then return end

    local original_owner_name = nil

    local new_gps, old_gps = ChartTagHelpers.extract_gps(event, player)

    if old_gps then
      local old_tag = Cache.get_tag_by_gps(player, old_gps)
      if old_tag and type(old_tag) == "table" and old_tag.owner_name then
        original_owner_name = old_tag.owner_name
      end
    end

    if not original_owner_name and event.old_player_index then
      local original_owner = game.players[event.old_player_index]
      if original_owner and original_owner.valid then
        original_owner_name = original_owner.name
      end
    end

    if not original_owner_name then
      original_owner_name = player.name
    end

    if not ChartTagHelpers.is_valid_tag_modification(event, player) then
      return
    end

    local chart_tag = event.tag
    if chart_tag and chart_tag.valid and chart_tag.position then
      local surface = chart_tag.surface or player.surface
      local force = chart_tag.force or player.force

      if surface and surface.valid and force and force.valid then
        local chunk_x = math.floor(chart_tag.position.x / 32)
        local chunk_y = math.floor(chart_tag.position.y / 32)
        local is_charted = force.is_chunk_charted(surface, { chunk_x, chunk_y })

        if not is_charted then
          chart_tag.position = event.old_position
          player.play_sound({ path = "utility/cannot_build" })
          ErrorHandler.debug_log("Prevented tag move to uncharted territory", {
            player_name = player.name,
            attempted_position = chart_tag.position,
            attempted_chunk = { chunk_x, chunk_y },
            old_position = event.old_position,
            surface_name = surface.name
          })
          return
        end
      end
    end

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
          local gps_string = new_gps --[[@as string]]
          local coords = GPSUtils.coords_string_from_gps(gps_string) or ""
          ---@diagnostic disable-next-line: assign-type-mismatch
          teleport_btn.caption = { "tf-gui.teleport_to", coords }
        end
      end
    end

    if chart_tag and chart_tag.valid and chart_tag.position then
      local position_changed = old_gps and new_gps and old_gps ~= new_gps
      if position_changed then
        apply_gps_move(old_gps, new_gps, event, player, original_owner_name)
      elseif new_gps then
        ChartTagHelpers.update_tag_metadata(new_gps, chart_tag, player)
      end
    end
  end

  function handlers.on_chart_tag_removed(event)
    with_valid_player(event.player_index, function(player)
      local chart_tag = event.tag
      if not chart_tag or not chart_tag.valid then return end

      local gps = GPSUtils.gps_from_map_position(chart_tag.position,
        GPSUtils.get_context_surface_index(chart_tag, player))
      local tag = Cache.get_tag_by_gps(player, gps)

      local is_admin = player.admin
      local is_owner = tag and (not tag.owner_name or tag.owner_name == "" or tag.owner_name == player.name)

      if not is_admin and not is_owner then
        restore_chart_tag_and_refresh(player, chart_tag, tag)
        return
      end

      local player_favorites = Cache.get_player_favorites(player, chart_tag.surface.index) or {}
      local is_locked = false

      for _, v in ipairs(player_favorites) do
        if v.gps and v.gps == gps and v.locked == true then
          is_locked = true
          break
        end
      end

      if is_locked == true then
        BasicHelpers.player_print(player, { "tf-gui.favorite_locked_cant_delete" })
        restore_chart_tag_and_refresh(player, chart_tag, tag)
        return
      end

      tag = tag or { gps = gps }
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)

      Cache.ensure_surface_cache(tonumber(player.surface.index) or 1)
      fave_bar.build(player)
    end)
  end

end
