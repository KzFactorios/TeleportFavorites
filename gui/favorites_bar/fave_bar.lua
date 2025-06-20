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
- Integrates with Favorite modules for data, and uses shared gui helpers.
- Displays error feedback if the number of favorites exceeds the allowed maximum.

Main Function:
- fave_bar.build(player, parent):
    Constructs and returns the favorites bar frame for the given player and parent GUI element.
    Handles all slot rendering, tooltips, drag/locked visuals, and overflow error display.

Event handling for slot clicks and drag is managed externally (see control.lua).
--]]

local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite")
local FavoriteRuntimeUtils = require("core.utils.favorite_utils")
local GuiUtils = require("core.utils.gui_utils")
local Settings = require("core.utils.settings_access")
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


-- Removed local function: get_or_create_gui_flow_from_gui_top
-- Now using GuiUtils.get_or_create_gui_flow_from_gui_top

-- Build the favorites bar to visually match the quickbar top row
---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent)  -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, "fave_bar_flow")  -- Add a thin dark background frame for the toggle button
  local toggle_container = GuiBase.create_frame(bar_flow, "fave_bar_toggle_container", "vertical", "tf_fave_toggle_container")
  local toggle_btn = GuiBase.create_icon_button(toggle_container, "fave_bar_visible_btns_toggle", "logo_36", {"tf-gui.toggle_fave_bar"}, "tf_fave_toggle_button")

  -- Add slots frame to the same flow for proper layout
  local slots_frame = GuiBase.create_frame(bar_flow, "fave_bar_slots_flow", "horizontal", "tf_fave_slots_row")
  return bar_flow, slots_frame, toggle_btn
end
---@diagnostic enable: assign-type-mismatch, param-type-mismatch

local function handle_overflow_error(frame, fav_btns, pfaves)
  if pfaves and #pfaves > Constants.settings.MAX_FAVORITE_SLOTS then
    GuiUtils.show_error_label(frame, "tf-gui.fave_bar_overflow_error")
  else
    GuiUtils.clear_error_label(frame)
  end
end

local _fave_bar_building_guard = _G._fave_bar_building_guard or {}
_G._fave_bar_building_guard = _fave_bar_building_guard

local function set_slot_row_visibility(slots_frame, visibility)
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
    local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)

    GuiUtils.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
    
    -- add the fave bar frame
    -- Outer frame for the bar (matches quickbar background)
    local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal", "tf_fave_bar_frame")    -- Use the new quickbar-style builder for the favorites bar
    ErrorHandler.debug_log("Favorites bar: Building quickbar style")
    local bar_flow, slots_frame, toggle_button = fave_bar.build_quickbar_style(player, fave_bar_frame)
    
    -- Only one toggle button: the one created in build_quickbar_style
    ErrorHandler.debug_log("Favorites bar: Getting player favorites")
    local pfaves = Cache.get_player_favorites(player)
    local drag_index = Cache.get_player_data(player).drag_favorite_index

    -- By default, show the slots row when building the bar
    ErrorHandler.debug_log("Favorites bar: Setting slot visibility")
    set_slot_row_visibility(slots_frame, true)

    -- Build slot buttons
    ErrorHandler.debug_log("Favorites bar: Building favorite buttons row")
    fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)

    -- Do NOT update toggle state in pdata here! Only the event handler should do that.

    -- Do NOT set toggle_container.visible here; toggle button always visible unless a future setting overrides it
    handle_overflow_error(fave_bar_frame, slots_frame, pfaves)

    return fave_bar_frame  end)
  _fave_bar_building_guard[pid] = nil
  if not success then
    ErrorHandler.warn_log("Favorites bar build failed for player " .. (player and player.name or "unknown") .. ": " .. tostring(result))
    ErrorHandler.debug_log("Favorites bar build failed", {
      player = player and player.name,
      error = result
    })
    return nil
  end
    
  return result
end

-- Build a row of favorite slot buttons for the favorites bar
function fave_bar.build_favorite_buttons_row(parent, player, pfaves, drag_index)
  drag_index = drag_index or -1
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10
  
  -- Create slot buttons for all slots (both blank and non-blank)
  for i = 1, max_slots do
    local fav = pfaves[i]
    -- Rehydrate favorite (tag and chart_tag) from GPS using runtime utils
    fav = FavoriteRuntimeUtils.rehydrate_favorite(fav)
    ---@cast fav Favorite
    local icon = nil
    local tooltip = { "tf-gui.favorite_slot_empty" }
    local style = "tf_slot_button_smallfont"
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      -- Non-blank favorite - show icon and full tooltip
      if fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.icon and fav.tag.chart_tag.icon.name and fav.tag.chart_tag.icon.name ~= "" then
        icon = fav.tag.chart_tag.icon.name
      else
        -- Use PIN as default icon for non-blank favorites
        icon = Enum.SpriteEnum.PIN
      end
      tooltip = GuiUtils.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }
      if fav.locked then style = "tf_slot_button_locked" end
      if drag_index == i then style = "tf_slot_button_dragged" end
    else
      -- Blank favorite - show empty slot with just slot number
      icon = nil  -- No icon for empty slots
      tooltip = { "tf-gui.favorite_slot_empty" }
      style = "tf_slot_button_smallfont"
    end    
    
    local btn = GuiUtils.create_slot_button(parent, "fave_bar_slot_" .. i, icon or "", tooltip, { style = style })
    if btn and btn.valid then
      ---@diagnostic disable-next-line: assign-type-mismatch
      btn.caption = tostring(i)
    end
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
    end
  end  local slots_frame = GuiBase.create_frame(bar_flow, "fave_bar_slots_flow", "horizontal", "tf_fave_slots_row")
  local pfaves = Cache.get_player_favorites(player)
  local drag_index = Cache.get_player_data(player).drag_favorite_index or -1
  local fav_btns = fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)
  set_slot_row_visibility(slots_frame, true)  return fav_btns
end

--- Destroy/hide the favorites bar for a player
---@param player LuaPlayer
function fave_bar.destroy(player)
  if not player or not player.valid then return end
  
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  GuiUtils.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
end

return fave_bar
