---@diagnostic disable: undefined-global
--[[
Favorites Bar GUI for TeleportFavorites
======================================
Module: gui/favorites_bar/fave_bar.lua

Builds the favorites bar UI for the TeleportFavorites mod, providing quick-access favorite teleport slots.


Element Hierarchy Diagram:

fave_bar_frame (frame)
└─ fave_bar_flow (flow, horizontal)
   ├─ fave_bar_toggle_container (frame, vertical)
   │  └─ fave_bar_visible_btns_toggle (sprite-button)
   └─ fave_bar_slots_flow (frame, horizontal, visible toggled at runtime)
      ├─ fave_bar_slot_1 (sprite-button)
      ├─ fave_bar_slot_2 (sprite-button)
      ├─ ...
      └─ fave_bar_slot_N (sprite-button)

- All element names use the {gui_context}_{purpose}_{type} convention.
- The number of slot buttons depends on the user’s settings (MAX_FAVORITE_SLOTS).
- The bar is parented to tf_main_gui_flow in the player's top GUI.

Features:
- Renders a horizontal bar of favorite slots, each as an icon button with tooltip and slot number.
- Handles locked, blank, and overflow slot states with distinct visuals and tooltips.
- Supports drag-and-drop visuals for slot reordering (Factorio 2.0+).
- Integrates with PlayerFavorites and Favorite modules for data, and uses shared gui helpers.
- Displays error feedback if the number of favorites exceeds the allowed maximum.

Main Function:
- fave_bar.build(player, parent):
    Constructs and returns the favorites bar frame for the given player and parent GUI element.
    Handles all slot rendering, tooltips, drag/locked visuals, and overflow error display.

Event handling for slot clicks and drag is managed externally (see control.lua).
--]]

local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite")
local PlayerFavorites = require("core.favorite.player_favorites")
local Helpers = require("core.utils.helpers_suite")
local Settings = require("settings")
local Cache = require("core.cache.cache")
local Enum = require("prototypes.enums.enum")

local fave_bar = {}



--[[
Element Hierarchy Diagram:
fave_bar_frame (frame)
  └─ fave_bar_flow (flow, horizontal)
      ├─ fave_bar_toggle_container (frame, vertical)
      │   └─ fave_bar_visible_btns_toggle (sprite-button)
      └─ fave_bar_slots_flow (frame, horizontal, visible toggled at runtime)
          ├─ fave_bar_slot_1 (sprite-button)
          ├─ fave_bar_slot_2 (sprite-button)
          ├─ ...
          └─ fave_bar_slot_N (sprite-button)
]]


local function get_or_create_gui_flow_from_gui_top(parent)
  local flow = parent.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = parent.add {
      type = "flow",
      name = "tf_main_gui_flow",
      direction = "vertical",
      style = "tf_main_gui_flow"
    }
  end
  return flow
end

-- Build the favorites bar to visually match the quickbar top row
function fave_bar.build_quickbar_style(player, parent)
  -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = parent.add {
    type = "flow",
    name = "fave_bar_flow",
    direction = "horizontal"
  }

  --[[local fave_drag = GuiBase.create_draggable(bar_flow, "fave_bar_draggable")
  fave_drag.style = "tf_fave_bar_draggable"
  fave_drag.drag_target = parent]]

  -- Add a thin dark background frame for the toggle button
  local toggle_container = bar_flow.add {
    type = "frame",
    name = "fave_bar_toggle_container",
    style = "tf_fave_toggle_container",
    direction = "vertical"
  }
  local toggle_btn = toggle_container.add {
    type = "sprite-button",
    name = "fave_bar_visible_btns_toggle",
    style = "tf_fave_toggle_button", -- no slot background
    sprite = "logo_36"
  }

  -- Add slots frame and return it for visibility toggling
  local slots_frame = parent.add {
    type = "frame",
    name = "fave_bar_slots_flow", -- unified name for slot row
    style = "tf_fave_slots_row",
    direction = "horizontal",
  }

  return bar_flow, slots_frame, toggle_btn
end

local function handle_overflow_error(frame, fav_btns, pfaves)
  if pfaves and #pfaves > Constants.settings.MAX_FAVORITE_SLOTS then
    Helpers.show_error_label(frame, { "tf-gui.fave_bar_overflow_error" })
  else
    Helpers.clear_error_label(frame)
  end
end

local _fave_bar_building_guard = _G._fave_bar_building_guard or {}
_G._fave_bar_building_guard = _fave_bar_building_guard

local function set_slot_row_visibility(slots_frame, visibility)
  print("[TF DEBUG] set_slot_row_visibility called with:", visibility)
  slots_frame.visible = visibility
end

function fave_bar.build(player, force_show)
  local pid = player.index
  if _fave_bar_building_guard[pid] then return end
  _fave_bar_building_guard[pid] = true
  local success, result = pcall(function()
    local player_settings = Settings:getPlayerSettings(player)
    if not player_settings.favorites_on then return end

    local mode = player and player.render_mode
    if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
      return
    end

    -- Use shared vertical flow
    local main_flow = get_or_create_gui_flow_from_gui_top(player.gui.top)

    Helpers.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

    -- add the fave bar frame
    -- Outer frame for the bar (matches quickbar background)
    local fave_bar_frame = main_flow.add {
      type = "frame",
      name = Enum.GuiEnum.GUI_FRAME.FAVE_BAR,
      style = "tf_fave_bar_frame",
      direction = "horizontal"
    }

    -- Use the new quickbar-style builder for the favorites bar
    local bar_flow, slots_frame, toggle_button = fave_bar.build_quickbar_style(player, fave_bar_frame)
    
    -- Only one toggle button: the one created in build_quickbar_style
    local pfaves = Cache.get_player_favorites(player)
    local drag_index = Cache.get_player_data(player).drag_favorite_index

    -- By default, show the slots row when building the bar
    set_slot_row_visibility(slots_frame, true)

    -- Build slot buttons
    fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)

    -- Do NOT update toggle state in pdata here! Only the event handler should do that.

    -- Do NOT set toggle_container.visible here; toggle button always visible unless a future setting overrides it
    handle_overflow_error(fave_bar_frame, slots_frame, pfaves)

    return fave_bar_frame
  end)

  _fave_bar_building_guard[pid] = nil
  if not success then error(result) end
    
  return result
end

-- Build a row of favorite slot buttons for the favorites bar
function fave_bar.build_favorite_buttons_row(parent, player, pfaves, drag_index)
  drag_index = drag_index or -1
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10
  for i = 1, max_slots do
    local fav = pfaves[i]
    local icon = pfaves[i].icon or nil
    local tooltip = { "tf-gui.fave_slot_tooltip", i }
    local style = "tf_slot_button_smallfont"    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      if fav.icon and fav.icon ~= "" then
        icon = fav.icon
      else
        icon = Enum.SpriteEnum.PIN  -- Use PIN as default icon for non-blank favorites
      end
      tooltip = Helpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }
      if fav.locked then style = "tf_slot_button_locked" end
      if drag_index == i then style = "tf_slot_button_dragged" end
    end
    local btn = Helpers.create_slot_button(parent, "fave_bar_slot_" .. i, icon, tooltip, { style = style })
    btn.style = style
    btn.caption = tostring(i)
    -- All alignment, font, and padding must be set in the style prototype, not at runtime
  end
  return parent
end

--- Efficiently update only the slot row (fave_bar_slots_flow) for the given player
-- parent: the bar_flow container (parent of fave_bar_slots_flow)
function fave_bar.update_slot_row(player, bar_flow)
  if not (bar_flow and bar_flow.valid and bar_flow.children) then return end
  -- Destroy all children named fave_bar_slots_flow (robust to any state)
  for _, child in pairs(bar_flow.children) do
    if child.name == "fave_bar_slots_flow" then
      child.destroy()
      _G.print("[TF DEBUG] Destroyed fave_bar_slots_flow row.")
    end
  end
  local slots_frame = bar_flow.add {
    type = "frame",
    name = "fave_bar_slots_flow",
    style = "tf_fave_slots_row",
    direction = "horizontal"
  }
  local pfaves = Cache.get_player_favorites(player)
  local drag_index = Cache.get_player_data(player).drag_favorite_index or -1
  local fav_btns = build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)
  set_slot_row_visibility(slots_frame, true)
  _G.print("[TF DEBUG] Built new fave_bar_slots_flow row.")
  return fav_btns
end

fave_bar.update_slot_row = update_slot_row
fave_bar.get_or_create_gui_flow_from_gui_top = get_or_create_gui_flow_from_gui_top
return fave_bar
