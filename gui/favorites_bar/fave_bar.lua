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

local last_build_tick = {}

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
function fave_bar.build_quickbar_style(player, parent)           -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, "fave_bar_flow") -- Add a thin dark background frame for the toggle button
  local toggle_container = GuiBase.create_frame(bar_flow, "fave_bar_toggle_container", "vertical",
    "tf_fave_toggle_container")
  local toggle_btn = GuiBase.create_icon_button(toggle_container, "fave_bar_visible_btns_toggle", "logo_36",
    { "tf-gui.toggle_fave_bar" }, "tf_fave_toggle_button")

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

local function set_slot_row_visibility(slots_frame, visibility)
  slots_frame.visible = visibility
end

function fave_bar.build(player, force_show)
  if not player or not player.valid then return end
  local tick = game and game.tick or 0
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if last_build_tick[player.index] == tick and bar_frame and bar_frame.valid then
    ErrorHandler.debug_log("[FAVE_BAR] build skipped (already built this tick, bar present)",
      { player = player.name, tick = tick })
    return
  end
  last_build_tick[player.index] = tick
  ErrorHandler.debug_log("[FAVE_BAR] build called", {
    player = player and player.name or "<nil>"
  })
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
    local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal",
      "tf_fave_bar_frame")
    ErrorHandler.debug_log("Favorites bar: Building quickbar style")
    local _bar_flow, slots_frame, _toggle_button = fave_bar.build_quickbar_style(player, fave_bar_frame)

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

    return fave_bar_frame
  end)
  if not success then
    ErrorHandler.warn_log("Favorites bar build failed for player " ..
    (player and player.name or "unknown") .. ": " .. tostring(result))
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
  -- Get drag state from player data instead of legacy drag_index parameter
  local player_data = Cache.get_player_data(player)
  local drag_active = player_data.drag_favorite and player_data.drag_favorite.active
  local drag_source = player_data.drag_favorite and player_data.drag_favorite.source_slot

  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10

  for i = 1, max_slots do
    local fav = pfaves[i]
    fav = FavoriteRuntimeUtils.rehydrate_favorite(player, fav)
    ---@cast fav Favorite

    local icon_name = nil
    local tooltip = { "tf-gui.favorite_slot_empty" }
    local style = "tf_slot_button_smallfont"
    local used_fallback = false
    local btn_icon, debug_info

    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      local icon = fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.icon or nil
      btn_icon, used_fallback, debug_info = GuiUtils.get_validated_sprite_path(icon,
        { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
      if used_fallback then
        ErrorHandler.debug_log("[FAVE_BAR] Fallback icon used for slot",
          { slot = i, icon = btn_icon, debug_info = debug_info })
      end
      tooltip = GuiUtils.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }
      -- Only apply locked style, never drag styles
      if fav.locked then
        style = "tf_slot_button_locked"
      end
    else
      -- Blank slot: default style, no drag styling
      btn_icon = ""
      tooltip = { "tf-gui.favorite_slot_empty" }
      style = "tf_slot_button_smallfont"
    end
    if btn_icon == "tf_tag_in_map_view_small" then
      style = "tf_slot_button_smallfont_map_pin"
    end
    -- Create the button with proper name pattern for event handling
    -- Note: Factorio has NO native drag/drop - our implementation is custom
    local btn = GuiUtils.create_slot_button(parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip, { style = style })
    if btn and btn.valid then
      -- Also add child label for visual consistency with project standards
      local nbr = GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(i), "tf_fave_bar_slot_number")

      if fav.locked then
        nbr.style = "tf_fave_bar_locked_slot_number"
        btn.add {
          type = "sprite",
          name = "slot_lock_sprite_" .. tostring(i),
          sprite = Enum.SpriteEnum.LOCK,
          style = "tf_fave_bar_slot_lock_sprite"
        }
      end
    end
  end
  return parent
end

-- Update only the slots row without rebuilding the entire bar
-- parent: the bar_flow container (parent of fave_bar_slots_flow)
function fave_bar.update_slot_row(player, parent_flow)
  if not player or not player.valid then return end
  if not parent_flow or not parent_flow.valid then return end

  local slots_frame = GuiUtils.find_child_by_name(parent_flow, "fave_bar_slots_flow")
  if not slots_frame or not slots_frame.valid then return end

  -- Remove all children
  for _, child in pairs(slots_frame.children) do
    if child and child.valid then
      child.destroy()
    end
  end

  -- Get player favorites
  local pfaves = Cache.get_player_favorites(player)

  -- Rebuild only the slot buttons
  fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

  return slots_frame
end

--- Destroy/hide the favorites bar for a player
---@param player LuaPlayer
function fave_bar.destroy(player)
  if not player or not player.valid then return end

  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  GuiUtils.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
end

function fave_bar.handle_toggle_button_click(player, element)
  if not player or not player.valid then return end
  local player_data = Cache.get_player_data(player)

  -- Check if drag mode is active
  if player_data.drag_favorite and player_data.drag_favorite.active then
    ErrorHandler.debug_log("[FAVE_BAR] Drag mode canceled due to toggle button click", { player = player.name })
    player_data.drag_favorite.active = false
    player_data.drag_favorite.source_slot = nil

    -- Prevent event propagation
    return true
  end

  return false
end

function fave_bar.cancel_drag_mode(player, reason)
  if not player or not player.valid then return end
  local player_data = Cache.get_player_data(player)

  -- Check if drag mode is active
  if player_data.drag_favorite and player_data.drag_favorite.active then
    ErrorHandler.debug_log("[FAVE_BAR] Drag mode canceled", { player = player.name, reason = reason })
    player_data.drag_favorite.active = false
    player_data.drag_favorite.source_slot = nil

    -- Prevent event propagation
    return true
  end

  return false
end

-- Update the GUI click handling
function fave_bar.on_gui_click(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  local element = event.element
  if not element or not element.valid then return end

  -- Prioritize drag mode cancellation for right-click
  if event.button == defines.mouse_button_type.right then
    if fave_bar.cancel_drag_mode(player, "right-click") then
      return
    end
  end

  -- Prioritize drag mode cancellation for toggle button click
  if element.name == "fave_bar_visible_btns_toggle" then
    if fave_bar.cancel_drag_mode(player, "toggle button click") then
      return
    end
  end

  -- Prevent left-click on locked slots in map view from closing map view or triggering any action
  if element.name and element.name:find("^fave_bar_slot_") and event.button == defines.mouse_button_type.left then
    local slot_num = tonumber(element.name:match("fave_bar_slot_(%d+)$"))
    if slot_num then
      local pfaves = Cache.get_player_favorites(player)
      local fav = pfaves[slot_num]
      if fav and fav.locked then
        local player_data = Cache.get_player_data(player)
        local drag_active = player_data.drag_favorite and player_data.drag_favorite.active
        if not drag_active and player.render_mode == defines.render_mode.chart then
          ErrorHandler.debug_log("[FAVE_BAR] Ignoring left-click on locked slot in map view", {player=player.name, slot=slot_num})
          return
        end
      end
    end
  end
  -- Handle other GUI events after drag mode cancellation
  -- ...existing code...
end

return fave_bar
