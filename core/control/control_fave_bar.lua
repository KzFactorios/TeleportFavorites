---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites

local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local tag_editor = require("gui.tag_editor.tag_editor")
local gps_helpers = require("core.utils.gps_helpers")
local gps_core = require("core.utils.gps_utils")
local PositionValidator = require("core.utils.position_validator")
local GameHelpers = require("core.utils.game_helpers")

-- Observer Pattern Integration
local GuiObserver = require("core.pattern.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local M = {}
local script = script

local function lstr(key, ...)
  return { key, ... }
end

local function clear_drag_state(player)
  local pdata = Cache.get_player_data(player)
  pdata.drag_favorite_index = nil
end

local function is_locked_favorite(fav)
  -- Defensive: treat nil as not locked
  return fav and fav.locked == true
end

local function start_drag(player, fav, slot)
  local pdata = Cache.get_player_data(player)
  pdata.drag_favorite_index = slot
  Helpers.player_print(player, lstr("tf-gui.fave_bar_drag_start", slot))
end

local function find_favorite_buttons_container(bar_flow)
  if not (bar_flow and bar_flow.valid and bar_flow.children) then return nil end
  for _, child in pairs(bar_flow.children) do
    if child.name == "fave_bar_slots_flow" then return child end
  end
  return nil
end

local function reorder_favorites(player, favorites, drag_index, slot)
  local favs = favorites.favorites
  local valid_drag = type(favs) == "table"
      and type(drag_index) == "number"
      and drag_index > 0
      and drag_index <= #favs
  if valid_drag then
    local drag_fav = favs[drag_index]    if is_locked_favorite(drag_fav) then
      Helpers.player_print(player, lstr("tf-gui.fave_bar_locked_move"))
      clear_drag_state(player)
      -- handled
      return true
    end
    local moved = table.remove(favs, drag_index)
    table.insert(favs, slot, moved)
    favorites:set_favorites(favs)

    -- Notify observers of favorites reorder
    GuiEventBus.notify("favorites_reordered", {
      player = player,
      from_slot = drag_index,
      to_slot = slot,
      type = "favorites_reordered"
    })

    -- Efficiently update only the slot row, not the whole bar
    local parent = player.gui.top
    local bar_frame = parent and parent.fave_bar_frame
    local bar_flow = bar_frame and bar_frame.fave_bar_flow
    if bar_flow then
      fave_bar.update_slot_row(player, bar_flow)
    end    Helpers.player_print(player, lstr("tf-gui.fave_bar_reordered", drag_index, slot))
    clear_drag_state(player)
    -- handled
    return true
  end
  clear_drag_state(player)
  return false
end

---@param player LuaPlayer
---@param fav Favorite
-- Check if we need to add nil check annotation
local function teleport_to_favorite(player, fav)
  if not fav or not fav.gps then return end
  GameHelpers.safe_teleport(player, gps_core.map_position_from_gps(fav.gps))
end

local function open_tag_editor_from_favorite(player, favorite)
  local tag_data = {}
  if favorite then
    -- Create initial tag data from favorite
    tag_data = Cache.create_tag_editor_data({
      gps = favorite.gps,
      locked = favorite.locked,
      is_favorite = Cache.is_player_favorite(player, favorite.gps),
      icon = favorite.tag.chart_tag.icon or "",
      text = favorite.chart_tag.text,
      tag = favorite.tag,
      chart_tag = favorite.chart_tag
    })

    -- Get position from GPS
    local position = gps_helpers.map_position_from_gps(favorite.gps)
    if position then
      -- Check if the position is valid (not water or space)
      if not PositionValidator.is_valid_tag_position(player, position, true) then
        -- Show dialog to handle invalid position
        PositionValidator.show_invalid_position_dialog(player, tag_data, function(action, updated_tag_data)          if action == "delete" then
            -- Delete the tag if player owns it and no other favorites are attached
            if tag_data.tag and tag_data.tag.player.name == player.name then
              if not tag_data.tag.faved_by_players or #tag_data.tag.faved_by_players == 0 then
                -- Delete the tag and chart tag
                if tag_data.chart_tag and tag_data.chart_tag.valid then
                  tag_data.chart_tag.destroy()
                end
                -- Remove from storage
                Cache.remove_stored_tag(tag_data.tag.gps)
                GameHelpers.player_print(player, "[TeleportFavorites] Tag deleted")
              else
                GameHelpers.player_print(player, "[TeleportFavorites] Cannot delete tag as other players have favorited it")
              end
            end
          elseif action == "move" then
            -- Move tag to valid position
            local new_position = gps_helpers.map_position_from_gps(updated_tag_data.gps)
            if new_position and tag_data.tag and tag_data.chart_tag then              local success = PositionValidator.move_tag_to_valid_position(
                player,
                tag_data.tag,
                tag_data.chart_tag,
                new_position
              )
              if success then
                GameHelpers.player_print(player, "[TeleportFavorites] Tag moved to valid position: " .. updated_tag_data.gps)
                -- Continue with opening tag editor with updated position
                Cache.set_tag_editor_data(player, updated_tag_data)
                tag_editor.build(player)
              end
            end
          end        end)
        -- Don't continue with normal tag editor opening
        return
      end
    end
  else
    tag_data = Cache.create_tag_editor_data()
  end

  -- Persist gps in tag_editor_data
  Cache.set_tag_editor_data(player, tag_data)
  tag_editor.build(player)
end

local function can_start_drag(fav)
  return fav and not FavoriteUtils.is_blank_favorite(fav) and not is_locked_favorite(fav)
end

local function handle_drag_start(event, player, fav, slot)
  if event.button == defines.mouse_button_type.left and not event.control and can_start_drag(fav) then
    start_drag(player, fav, slot)
    return true
  end
  return false
end

local function handle_reorder(event, player, favorites, drag_index, slot)
  if event.button == defines.mouse_button_type.left and not event.control and drag_index and drag_index ~= slot then
    return reorder_favorites(player, favorites, drag_index, slot)
  elseif event.button == defines.mouse_button_type.left and not event.control and drag_index and drag_index == slot then
    clear_drag_state(player)
    return true
  end
  return false
end

local function handle_teleport(event, player, fav, slot, did_drag)
  if event.button == defines.mouse_button_type.left and not event.control and not did_drag then
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      teleport_to_favorite(player, fav)
      return true
    end
  end
  return false
end

local function handle_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      -- removed extra gps argument
      open_tag_editor_from_favorite(player, fav)
      return true
    end
  end
  return false
end

local function handle_favorite_slot_click(event, player, favorites)  local element = event.element
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  if not slot then return end
  local fav = favorites.favorites[slot]
  if fav == nil then
    return
  end
  if FavoriteUtils.is_blank_favorite(fav) then
    return
  end
  local pdata = Cache.get_player_data(player)
  local drag_index = pdata.drag_favorite_index
  local did_drag = false
  if not drag_index then
    did_drag = handle_drag_start(event, player, fav, slot)
  else
    did_drag = handle_reorder(event, player, favorites, drag_index, slot)
    if did_drag then return end
  end
  if handle_teleport(event, player, fav, slot, did_drag) then return end
  handle_tag_editor(event, player, fav, slot)
  -- Always update the slot row after any favorite action to ensure button is visible
  local main_flow = fave_bar.get_or_create_gui_flow_from_gui_top(player.gui.top)
  local bar_frame = main_flow and main_flow.fave_bar_frame
  local bar_flow = bar_frame and bar_frame.fave_bar_flow
  if bar_flow then
    fave_bar.update_slot_row(player, bar_flow)
  else
    -- If bar_flow is missing, rebuild the entire favorites bar
    if main_flow then
      fave_bar.build(player, main_flow)
    end
  end
end

local function handle_visible_fave_btns_toggle_click(player)
  local main_flow = fave_bar.get_or_create_gui_flow_from_gui_top(player.gui.top)  if not main_flow or not main_flow.valid then return end
  local slots_row = Helpers.find_child_by_name(main_flow, "fave_bar_slots_flow")
  if not slots_row or not slots_row.valid then
    return
  end

  local currently_visible = slots_row.visible
  slots_row.visible = not currently_visible
end

--- Handle favorites bar GUI click events
local function on_fave_bar_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if element.name:find("^fave_bar_slot_") then
    local favorites = PlayerFavorites.new(player)
    handle_favorite_slot_click(event, player, favorites)
    return
  end

  if element.name == "fave_bar_visible_btns_toggle" then
    local success, err = pcall(handle_visible_fave_btns_toggle_click, player)
    if not success then
      ErrorHandler.debug_log("Handle visible fave buttons toggle failed", {
        player = player.name,
        error = err
      })
    end
  end
end

M.on_fave_bar_gui_click = on_fave_bar_gui_click
M.on_fave_bar_gui_click_impl = on_fave_bar_gui_click

--- Register favorites bar event handlers (deprecated: use central dispatcher)
--- @param script table The Factorio script object
function M.register(script)
  -- Deprecated: do not register directly. Use central dispatcher in control.lua
end

return M
