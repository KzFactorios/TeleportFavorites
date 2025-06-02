print("[DEBUG] control_fave_bar.lua loaded")

---@diagnostic disable: undefined-global

-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites

local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")
local GPS = require("core.gps.gps")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")
local tag_editor = require("gui.tag_editor.tag_editor")

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
    local drag_fav = favs[drag_index]
    if is_locked_favorite(drag_fav) then
      Helpers.player_print(player, lstr("tf-gui.fave_bar_locked_move"))
      clear_drag_state(player)
      return true -- handled
    end
    local moved = table.remove(favs, drag_index)
    table.insert(favs, slot, moved)
    favorites:set_favorites(favs)
    -- Efficiently update only the slot row, not the whole bar
    local parent = player.gui.top
    local bar_frame = parent and parent.fave_bar_frame
    local bar_flow = bar_frame and bar_frame.fave_bar_flow
    if bar_flow then
      fave_bar.update_slot_row(player, bar_flow)
    end
    Helpers.player_print(player, lstr("tf-gui.fave_bar_reordered", drag_index, slot))
    clear_drag_state(player)
    return true -- handled
  end
  clear_drag_state(player)
  return false
end

local function teleport_to_favorite(player, fav, slot)
  local pos = GPS.map_position_from_gps(fav.gps)
  if pos then
    Helpers.safe_teleport(player, pos, player.surface)
    Helpers.player_print(player, lstr("tf-gui.teleported_to", player.name, slot.gps))
  else
    Helpers.player_print(player, lstr("tf-gui.teleport_failed"))
  end
end

local function open_tag_editor(player, favorite, gps)
  local parent = player.gui.screen
  Helpers.safe_destroy_frame(parent, "tag_editor_frame")
  tag_editor.build(player, favorite.tag or {})
end

local function can_start_drag(fav)
  return fav and not Favorite.is_blank_favorite(fav) and not is_locked_favorite(fav)
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
    if fav and not Favorite.is_blank_favorite(fav) then
      teleport_to_favorite(player, fav, slot)
      return true
    end
  end
  return false
end

local function handle_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then
    if fav and not Favorite.is_blank_favorite(fav) then
      open_tag_editor(player, fav, fav.gps or "")
      return true
    end
  end
  return false
end

local function handle_favorite_slot_click(event, player, favorites)
  local element = event.element
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  print("[TF DEBUG] handle_favorite_slot_click: slot=" .. tostring(slot))
  if not slot then return end
  local fav = favorites.favorites[slot]
  if fav == nil then
    print("[TF DEBUG] handle_favorite_slot_click: fav is nil, ignoring click.")
    return
  end
  if Favorite.is_blank_favorite(fav) then
    print("[TF DEBUG] handle_favorite_slot_click: blank favorite, ignoring click.")
    return
  end
  print("[TF DEBUG] handle_favorite_slot_click: fav=" .. (fav and (fav.gps or "<no gps>") or "<nil fav>"))
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
  local main_flow = fave_bar.get_or_create_main_flow(player.gui.top)
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
  local main_flow = fave_bar.get_or_create_main_flow(player.gui.top)
  if not main_flow or not main_flow.valid then return end
  local slots_row = Helpers.find_child_by_name(main_flow, "fave_bar_slots_flow")
  if not slots_row or not slots_row.valid then
    print("[TF DEBUG] fave_bar_slots_flow not found, cannot toggle visibility.")
    return
  end

  local currently_visible = slots_row.visible
  slots_row.visible = not currently_visible
  print("[TF DEBUG] fave_bar_slots_flow visibility toggled to:", slots_row.visible)
end

--- Handle favorites bar GUI click events
local function on_fave_bar_gui_click(event)
  print("[HANDLER DEBUG] on_fave_bar_gui_click called")
  local element = event.element
  print("[HANDLER DEBUG] event.element.name:", element and element.name)
  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  if element.name:find("^fave_bar_slot_") then
    local favorites = PlayerFavorites.new(player)
    handle_favorite_slot_click(event, player, favorites)
    return
  end
  if element.name == "fave_bar_visible_btns_toggle" then
    print("[TF DEBUG] fave_bar_visible_btns_toggle clicked by player:", player and player.name)
    print("[TF DEBUG] handle_visible_fave_btns_toggle_click pointer:", tostring(handle_visible_fave_btns_toggle_click))
    print("[TF DEBUG] calling handle_visible_fave_btns_toggle_click")
    local ok, err = pcall(handle_visible_fave_btns_toggle_click, player)
    print("[TF DEBUG] after handle_visible_fave_btns_toggle_click, ok=", tostring(ok), "err=", tostring(err))
    if not ok then
      print("[TF ERROR] handle_visible_fave_btns_toggle_click failed:", err)
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
