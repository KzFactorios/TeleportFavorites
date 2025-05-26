local Constants = require("constants")
local Tag = require("core.tag.tag")
local PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local GPS = require("core.gps.gps")
local handlers = require("core.events.handlers")
local gui = require("gui.gui")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local data_viewer = require("gui.data_viewer.data_viewer")
local defines = _G.defines
local script = _G.script
local Favorite = require("core.favorite.favorite")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.Helpers")
local player_print = Helpers.player_print
local safe_teleport = Helpers.safe_teleport
local safe_destroy_frame = Helpers.safe_destroy_frame
local safe_play_sound = Helpers.safe_play_sound

-- Factorio 2.0: ensure 'game' is available in control.lua event handlers
---@diagnostic disable-next-line: undefined-global
local game = game

--[[
TeleportFavorites Factorio Mod - Control Script
Main event handler and public API entry points.

Features:
- Robust, multiplayer-safe GUI and data handling for favorites, tags, and teleportation.
- Centralized event wiring for all GUIs (favorites bar, tag editor, data viewer).
- EmmyLua-annotated helpers for safe player messaging, teleportation, and GUI frame destruction.
- Move-mode UX for tag editor, with robust state management and multiplayer safety.
- All persistent data access is via the Cache module for consistency and safety.
- All new/changed features are documented inline and in notes/ as appropriate.
]]

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  ---@diagnostic disable-next-line: cast-local-type
  if not element or not element.valid then return end
  ---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(event.player_index)
  if not player then return end
  local favorites = PlayerFavorites.new(player)
  -- Helper for drag state
  local function clear_drag_state()
    if _G.storage and _G.storage.players and _G.storage.players[player.index] then
      _G.storage.players[player.index].drag_favorite_index = nil
    end
  end
  -- Favorite bar slot buttons
  if element.name:find("^favorite_slot_") then
    local slot = tonumber(element.name:match("favorite_slot_(%d+)"))
    if not slot then return end
    local fav = favorites.favorites[slot]
    local drag_index = _G.storage.players[player.index].drag_favorite_index
    ---@diagnostic disable-next-line: cast-local-type
    if event.button == defines.mouse_button_type.left and not event.control then
      if not drag_index then
        if fav and not Favorite.is_blank_favorite(fav) and not fav.locked then
          _G.storage.players[player.index].drag_favorite_index = slot
          ---@cast _ LocalisedString
          player_print(player, {"tf-gui.fave_bar_drag_start", slot})
        end
      else
        if drag_index ~= slot then
          local favs = favorites.favorites
          ---@diagnostic disable-next-line: cast-local-type
          if favs[drag_index] and favs[drag_index].locked then
            player_print(player, {"tf-gui.fave_bar_locked_move"})
            clear_drag_state()
            return
          end
          local moved = table.remove(favs, drag_index)
          table.insert(favs, slot, moved)
          favorites:set_favorites(favs)
          local parent = player.gui.top
          safe_destroy_frame(parent, "fave_bar_frame")
          fave_bar.build(player, parent)
          ---@cast _ LocalisedString
          player_print(player, {"tf-gui.fave_bar_reordered", drag_index, slot})
        end
        clear_drag_state()
      end
    ---@diagnostic disable-next-line: cast-local-type
    elseif event.button == defines.mouse_button_type.left and drag_index and drag_index == slot then
      clear_drag_state()
    end
    if event.button == defines.mouse_button_type.left and not event.control then
      if fav and not Favorite.is_blank_favorite(fav) then
        local pos = GPS.map_position_from_gps(fav.gps)
        if pos then
          safe_teleport(player, pos, player.surface)
          ---@cast _ LocalisedString
          player_print(player, {"tf-gui.teleported_to_favorite", slot})
        else
          player_print(player, {"tf-gui.teleport_failed"})
        end
      end
    elseif event.button == defines.mouse_button_type.right then
      if fav and not Favorite.is_blank_favorite(fav) then
        local parent = player.gui.screen
        safe_destroy_frame(parent, "tag_editor_frame")
        tag_editor.build(player, parent, fav.tag or {})
      end
    ---@diagnostic disable-next-line: cast-local-type
    elseif event.button == defines.mouse_button_type.left and event.control then
      if fav and not Favorite.is_blank_favorite(fav) then
        fav.locked = not fav.locked
        ---@cast _ LocalisedString
        player_print(player, {"tf-gui.favorite_lock_toggled", slot, tostring(fav.locked)})
      end
    end
  elseif element.name == "fave_toggle" then
    local parent = player.gui.top
    ---@diagnostic disable-next-line: cast-local-type
    if parent["fave_bar_frame"] and parent["fave_bar_frame"].valid then
      parent["fave_bar_frame"].visible = not parent["fave_bar_frame"].visible
    end
  end
  -- Tag editor button actions
  if element.parent and element.parent.name == "tag_editor_frame" then
    if element.name == "confirm_btn" then
      -- Confirm: validate and save tag edits
      local tag_data = Cache.get_tag_editor_data(player) or {}
      local text = (element.parent.text_box and element.parent.text_box.text or ""):gsub("%s+$", "")
      local icon = tag_data.icon or ""
      local is_favorite = tag_data.is_favorite
      local max_len = Constants.settings.TAG_TEXT_MAX_LENGTH or 256
      local error_label = element.parent.error_row_error_message
      if #text > max_len then
        if error_label then error_label.caption = {"tf-gui.tag_editor_text_too_long", max_len} end
        return
      end
      if text == "" and (not icon or icon == "") then
        if error_label then error_label.caption = {"tf-gui.tag_editor_empty"} end
        return
      end
      -- Save tag/chart_tag fields
      local tag = tag_data.tag or {}
      tag.chart_tag = tag.chart_tag or {}
      tag.chart_tag.text = text
      tag.chart_tag.icon = icon
      if not tag.chart_tag.last_user or tag.chart_tag.last_user == "" then
        tag.chart_tag.last_user = player.name
      end
      -- Save favorite state
      local pfaves = PlayerFavorites.new(player)
      if is_favorite then
        pfaves:add_favorite(tag.gps)
      else
        pfaves:remove_favorite(tag.gps)
      end
      -- Save tag to persistent storage (as a map, not array)
      local surface_index = player.surface.index
      local tags = require("core.cache.cache").get_surface_tags(surface_index)
      tags[tag.gps] = tag
      Cache.set_tag_editor_data(player, nil)
      ---@type LocalisedString
      local msg_confirmed = {"tf-gui.tag_editor_confirmed"}
      player_print(player, msg_confirmed)
      element.parent:destroy()
    elseif element.name == "cancel_btn" then
      Cache.set_tag_editor_data(player, nil)
      ---@type LocalisedString
      local msg_cancelled = {"tf-gui.tag_editor_cancelled"}
      player_print(player, msg_cancelled)
      element.parent:destroy()
    elseif element.name == "move_btn" then
      -- Move: set move_mode state (TODO: implement full move logic)
      local tag_data = Cache.get_tag_editor_data(player) or {}
      tag_data.move_mode = true
      Cache.set_tag_editor_data(player, tag_data)
      ---@type LocalisedString
      local msg_move_mode = {"tf-gui.tag_editor_move_mode"}
      player_print(player, msg_move_mode)
      -- TODO: Implement move mode logic
    elseif element.name == "delete_btn" then
      -- Delete: confirm, then delete tag/chart_tag and update favorites
      local tag_data = Cache.get_tag_editor_data(player) or {}
      local tag = tag_data.tag or {}
      if not tag or not tag.gps then return end
      if not tag.chart_tag or not tag.chart_tag.last_user or tag.chart_tag.last_user ~= player.name then
        ---@type LocalisedString
        local msg_delete_denied = {"tf-gui.tag_editor_delete_denied"}
        player_print(player, msg_delete_denied)
        return
      end
      -- Confirm dialog (simple for now)
      if not tag_data.delete_confirmed then
        tag_data.delete_confirmed = true
        Cache.set_tag_editor_data(player, tag_data)
        ---@type LocalisedString
        local msg_delete_confirm = {"tf-gui.tag_editor_delete_confirm"}
        player_print(player, msg_delete_confirm)
        return
      end
      -- Actually delete
      tag_destroy_helper.unlink_and_destroy(tag)
      Cache.set_tag_editor_data(player, nil)
      ---@type LocalisedString
      local msg_deleted = {"tf-gui.tag_editor_deleted"}
      player_print(player, msg_deleted)
      element.parent:destroy()
    elseif element.name == "teleport_btn" then
      -- Teleport: teleport to tag location and close dialog
      local tag_data = Cache.get_tag_editor_data(player) or {}
      local tag = tag_data.tag or {}
      if not tag or not tag.gps then return end
      local pos = GPS.map_position_from_gps(tag.gps)
      if pos then
        safe_teleport(player, pos, player.surface)
        ---@type LocalisedString
        local msg_teleport = {"tf-gui.tag_editor_teleport"}
        player_print(player, msg_teleport)
        element.parent:destroy()
      else
        local error_label = element.parent.error_row_error_message
        if error_label then error_label.caption = {"tf-gui.tag_editor_teleport_failed"} end
      end
    elseif element.name == "favorite_btn" then
      -- Favorite: toggle favorite state in dialog (not persistent until confirm)
      local tag_data = Cache.get_tag_editor_data(player) or {}
      tag_data.is_favorite = not tag_data.is_favorite
      Cache.set_tag_editor_data(player, tag_data)
      ---@type LocalisedString
      local msg_fav_toggled = {"tf-gui.tag_editor_favorite_toggled", tostring(tag_data.is_favorite)}
      player_print(player, msg_fav_toggled)
      -- TODO: Update button icon/state
    elseif element.name == "icon_btn" then
      -- Icon: open icon selector (stub)
      ---@type LocalisedString
      local msg_icon_select = {"tf-gui.tag_editor_icon_select"}
      player_print(player, msg_icon_select)
      -- TODO: Implement icon selector logic (see notes/tag_editor.md for requirements)
    elseif element.name == "icon_elem_btn" then
      -- Icon elem-button: update icon in tag_editor_data immediately
      local tag_data = Cache.get_tag_editor_data(player) or {}
      tag_data.icon = element.elem_value
      Cache.set_tag_editor_data(player, tag_data)
      ---@type LocalisedString
      local msg_icon_selected = {"tf-gui.tag_editor_icon_selected", tostring(element.elem_value or "none")}
      player_print(player, msg_icon_selected)
      -- Rebuild tag editor to update confirm button enablement
      local parent = player.gui.screen
      safe_destroy_frame(parent, "tag_editor_frame")
      require("gui.tag_editor.tag_editor").build(player, parent, tag_data)
    elseif element.name == "text_box" and element.type == "textfield" then
      -- Live update confirm button enablement on text change
      local tag_data = Cache.get_tag_editor_data(player) or {}
      tag_data.text = element.text
      Cache.set_tag_editor_data(player, tag_data)
      local parent = player.gui.screen
      safe_destroy_frame(parent, "tag_editor_frame")
      require("gui.tag_editor.tag_editor").build(player, parent, tag_data)
    end
  end
  -- Data viewer button actions
  ---@diagnostic disable-next-line: cast-local-type
  if element.parent and element.parent.parent and element.parent.parent.name == "data_viewer_frame" then
    local Cache = require("core.cache.cache")
    local player_data = Cache.get_player_data(player)
    local data_viewer_state = player_data.data_viewer_state or {}
    local font_size = player_data.data_viewer_font_size or 12
    local opacity = player_data.data_viewer_opacity or 1
    local active_tab = data_viewer_state.active_tab or "player_data"
    local function clamp(val, min, max) return math.max(min, math.min(max, val)) end
    local function update_data_viewer()
      -- Destroy and rebuild the data viewer for immediate feedback
      local parent = player.gui.top
      pcall(function()
        parent.data_viewer_frame:destroy()
      end)
      data_viewer.build(player, parent, {})
    end
    if element.name:find("^tab_") then
      -- Tab switch
      local tab = element.name:match("^tab_(.+)")
      player_data.data_viewer_state = player_data.data_viewer_state or {}
      player_data.data_viewer_state.active_tab = tab
      Cache.set("players", _G.storage.players)
      ---@type LocalisedString
      local msg_tab_switched = {"tf-gui.data_viewer_tab_switched", tab}
      player_print(player, msg_tab_switched)
      update_data_viewer()
    elseif element.name == "opacity_btn" then
      -- Cycle opacity: 1 -> 0.75 -> 0.5 -> 0.25 -> 1
      local opacities = {1, 0.75, 0.5, 0.25}
      local idx = 1
      for i, v in ipairs(opacities) do if math.abs((opacity or 1) - v) < 0.01 then idx = i break end end
      idx = idx % #opacities + 1
      player_data.data_viewer_opacity = opacities[idx]
      Cache.set("players", _G.storage.players)
      ---@type LocalisedString
      local msg_opacity_changed = {"tf-gui.data_viewer_opacity_changed", math.floor(opacities[idx]*100)}
      player_print(player, msg_opacity_changed)
      update_data_viewer()
    elseif element.name == "font_plus_btn" then
      -- Increase font size (max 24)
      local new_size = clamp(font_size + 1, 8, 24)
      if new_size ~= font_size then
        player_data.data_viewer_font_size = new_size
        Cache.set("players", _G.storage.players)
        ---@type LocalisedString
        local msg_font_plus = {"tf-gui.data_viewer_font_plus", new_size}
        player_print(player, msg_font_plus)
        update_data_viewer()
      else
        ---@type LocalisedString
        local msg_font_max = {"tf-gui.data_viewer_font_max"}
        player_print(player, msg_font_max)
      end
    elseif element.name == "font_minus_btn" then
      -- Decrease font size (min 8)
      local new_size = clamp(font_size - 1, 8, 24)
      if new_size ~= font_size then
        player_data.data_viewer_font_size = new_size
        Cache.set("players", _G.storage.players)
        ---@type LocalisedString
        local msg_font_minus = {"tf-gui.data_viewer_font_minus", new_size}
        player_print(player, msg_font_minus)
        update_data_viewer()
      else
        ---@type LocalisedString
        local msg_font_min = {"tf-gui.data_viewer_font_min"}
        player_print(player, msg_font_min)
      end
    elseif element.name == "refresh_btn" then
      -- Refresh data panel (reload snapshot)
      ---@type LocalisedString
      local msg_refreshed = {"tf-gui.data_viewer_refreshed"}
      player_print(player, msg_refreshed)
      update_data_viewer()
    elseif element.name == "close_btn" then
      ---@type LocalisedString
      local msg_closed = {"tf-gui.data_viewer_closed"}
      player_print(player, msg_closed)
      pcall(function()
        element.parent.parent:destroy()
      end)
    end
  end
end)

-- Remove legacy direct event handler registration for GUIs (now handled by extension modules)
-- Remove duplicate or redundant event handler logic for tf-open-fave-bar, tf-open-tag-editor, tf-open-data-viewer
-- Remove any helper functions that are now only used in extension modules
-- Remove unnecessary comments and whitespace

---
--- Move mode helpers for tag editor GUI.
---
--- @param player LuaPlayer The player to check or clear move mode for
--- @return boolean True if player is in move mode
local function is_in_move_mode(player)
  local data = Cache.get_tag_editor_data(player)
  return (data and data.move_mode) and true or false
end

---
--- Clears move mode state for the tag editor for the given player.
--- @param player LuaPlayer
local function clear_move_mode(player)
  local data = Cache.get_tag_editor_data(player)
  if data then data.move_mode = nil; Cache.set_tag_editor_data(player, data) end
end

script.on_event(defines.events.on_player_selected_area, function(event)
  ---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(event.player_index)
  if not player or not player.valid or not is_in_move_mode(player) then return end
  if player.render_mode ~= defines.render_mode.chart and player.render_mode ~= defines.render_mode.chart_zoomed_in then return end
  local tag_data = Cache.get_tag_editor_data(player) or {}
  local tag = tag_data.tag or {}
  if not tag or not tag.gps then return end
  local area = event.area
  local pos = {x = (area.left_top.x + area.right_bottom.x)/2, y = (area.left_top.y + area.right_bottom.y)/2}
  local surface = player.surface
  local err, new_chart_tag = Tag.rehome_chart_tag(tag, player, GPS.gps_from_map_position(pos, surface.index))
  ---@diagnostic disable-next-line: cast-local-type
  if err then
    if player and player.valid then
      safe_play_sound(player, {path="utility/cannot_build"})
    end
    ---@type LocalisedString
    local msg_move_failed = {"tf-gui.tag_editor_move_failed", err}
    player_print(player, msg_move_failed)
    return
  end
  clear_move_mode(player)
  if player and player.valid then
    safe_play_sound(player, {path="utility/confirm"})
  end
  ---@type LocalisedString
  local msg_move_success = {"tf-gui.tag_editor_move_success"}
  player_print(player, msg_move_success)
  Cache.set_tag_editor_data(player, nil)
  local parent = player.gui.screen
  safe_destroy_frame(parent, "tag_editor_frame")
  require("gui.tag_editor.tag_editor").build(player, parent, {tag = tag})
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  ---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(event.player_index)
  if not player or not player.valid or not is_in_move_mode(player) then return end
  clear_move_mode(player)
  if player and player.valid then
    safe_play_sound(player, {path="utility/cannot_build"})
  end
  ---@type LocalisedString
  local msg_move_cancelled = {"tf-gui.tag_editor_move_cancelled"}
  player_print(player, msg_move_cancelled)
end)

local old_on_gui_click = script.get_event_handler and script.get_event_handler(defines.events.on_gui_click)
script.on_event(defines.events.on_gui_click, function(event)
  ---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(event.player_index)
  if is_in_move_mode(player) then
    if event.button and defines.mouse_button_type and event.button == defines.mouse_button_type.right then
      clear_move_mode(player)
      if player and player.valid then
        safe_play_sound(player, {path="utility/cannot_build"})
      end
      ---@type LocalisedString
      local msg_move_cancelled = {"tf-gui.tag_editor_move_cancelled"}
      player_print(player, msg_move_cancelled)
      return
    end
  end
  ---@diagnostic disable-next-line: cast-local-type
  if old_on_gui_click then old_on_gui_click(event) end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  ---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(event.player_index)
  if player then
    Cache.set_tag_editor_data(player, nil)
  end
end)

-- Modular event handler registration
local control_fave_bar = require("control_fave_bar")
local control_tag_editor = require("control_tag_editor")
local control_data_viewer = require("control_data_viewer")

control_fave_bar.register(script)
control_tag_editor.register(script)
control_data_viewer.register(script)

-- TODO: Add more GUI event wiring for button clicks, drag-and-drop, etc.
-- Use the builder/command pattern: GUI modules build, event handlers command
