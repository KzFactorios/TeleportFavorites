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
local FavoriteRehydration = require("core.favorite.favorite_rehydration")
local GuiValidation = require("core.utils.gui_validation")
local GuiStyling = require("core.utils.gui_styling")
local GuiFormatting = require("core.utils.gui_formatting")
local GuiAccessibility = require("core.utils.gui_accessibility")
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
-- Now using GuiAccessibility.get_or_create_gui_flow_from_gui_top

-- Build the favorites bar to visually match the quickbar top row
---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent)           -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, "fave_bar_flow") -- Add a thin dark background frame for the toggle button
  local toggle_container = GuiBase.create_frame(bar_flow, "fave_bar_toggle_container", "vertical",
    "tf_fave_toggle_container")
  ---@type LocalisedString
  local toggle_tooltip = { "tf-gui.toggle_fave_bar" }
  local toggle_btn = GuiBase.create_icon_button(toggle_container, "fave_bar_visible_btns_toggle", "logo_36", toggle_tooltip, "tf_fave_toggle_button")

  -- Add slots frame to the same flow for proper layout
  local slots_frame = GuiBase.create_frame(bar_flow, "fave_bar_slots_flow", "horizontal", "tf_fave_slots_row")
  return bar_flow, slots_frame, toggle_btn
end

---@diagnostic enable: assign-type-mismatch, param-type-mismatch

local function handle_overflow_error(frame, fav_btns, pfaves)
  if pfaves and #pfaves > Constants.settings.MAX_FAVORITE_SLOTS then
    GuiValidation.show_error_label(frame, "tf-gui.fave_bar_overflow_error")
  else
    GuiValidation.clear_error_label(frame)
  end
end

local function get_fave_bar_gui_refs(player)
  local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  local bar_flow = bar_frame and GuiValidation.find_child_by_name(bar_frame, "fave_bar_flow")
  local slots_frame = bar_flow and GuiValidation.find_child_by_name(bar_flow, "fave_bar_slots_flow")
  return main_flow, bar_frame, bar_flow, slots_frame
end

function fave_bar.build(player, force_show)
  if not player or not player.valid then return end
  local tick = game and game.tick or 0
  local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
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
    local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)

    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

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
    if slots_frame and slots_frame.valid then
        slots_frame.visible = true
    end

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
  local player_data = Cache.get_player_data(player)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10

  local function get_slot_btn_props(i, fav)
    fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      -- Icon comes from chart_tag.icon only (tags do not have icon property)
      local icon = fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.icon or nil
      ErrorHandler.debug_log("[FAVE_BAR] Icon resolution for slot", {
        slot = i,
        has_tag = fav.tag ~= nil,
        has_chart_tag = fav.tag and fav.tag.chart_tag ~= nil,
        has_icon = icon ~= nil,
        icon_type = icon and icon.type or nil,
        icon_name = icon and icon.name or nil,
        icon_full = icon and icon.type and icon.name and (icon.type .. "/" .. icon.name) or nil,
        icon_raw = icon -- Show the entire icon object
      })
      local btn_icon, used_fallback, debug_info = GuiValidation.get_validated_sprite_path(icon, { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
      ErrorHandler.debug_log("[FAVE_BAR] Sprite validation result", {
        slot = i,
        btn_icon = btn_icon,
        used_fallback = used_fallback,
        debug_info = debug_info
      })
      local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
      if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
      return btn_icon, GuiFormatting.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style, fav.locked
    else
      return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont", false
    end
  end

  for i = 1, max_slots do
    local fav = pfaves[i]
    fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    local btn_icon, tooltip, style, locked = get_slot_btn_props(i, fav)
    local btn = GuiStyling.create_slot_button(parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip, { style = style })
    if btn and btn.valid then
      local label_style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
      GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(i), label_style)
      if locked then
        btn.add {
          type = "sprite",
          name = "slot_lock_sprite_" .. tostring(i),
          sprite = Enum.SpriteEnum.LOCK,
          style = "tf_fave_bar_slot_lock_sprite"
        }
      end
    else
      ErrorHandler.warn_log("[FAVE_BAR] Failed to create slot button", {slot = i, icon = btn_icon})
    end
  end
  return parent
end

-- Update only the slots row without rebuilding the entire bar
-- parent: the bar_flow container (parent of fave_bar_slots_flow)
function fave_bar.update_slot_row(player, parent_flow)
  if not player or not player.valid then return end
  if not parent_flow or not parent_flow.valid then return end

  local slots_frame = GuiValidation.find_child_by_name(parent_flow, "fave_bar_slots_flow")
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

  local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end

  GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
end

-- Enhanced partial update functions for favorites bar

--- Update a single slot button without rebuilding the entire row
---@param player LuaPlayer
---@param slot_index number Slot index (1-based)
function fave_bar.update_single_slot(player, slot_index)
  if not player or not player.valid then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end
  local slot_button = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_" .. slot_index)
  if not slot_button then return end
  local pfaves = Cache.get_player_favorites(player)
  local fav = pfaves[slot_index]
  fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    -- Icon comes from chart_tag.icon only (tags do not have icon property)
    local icon = fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.icon or nil
    slot_button.sprite = GuiValidation.get_validated_sprite_path(icon, { fallback = Enum.SpriteEnum.PIN, log_context = { slot = slot_index, fav_gps = fav.gps, fav_tag = fav.tag } })
    ---@type LocalisedString
    slot_button.tooltip = GuiFormatting.build_favorite_tooltip(fav, { slot = slot_index })
  else
    slot_button.sprite = ""
    slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
  end
end

--- Update lock state styling for a specific slot
---@param player LuaPlayer
---@param slot_index number Slot index (1-based) 
---@param locked boolean Lock state
function fave_bar.update_slot_lock_state(player, slot_index, locked)
  if not player or not player.valid then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end
  local slot_button = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_" .. slot_index)
  if not slot_button then return end
  -- Style must be set at creation; cannot change after
end

--- Update drag visual styling for slots
---@param player LuaPlayer
---@param drag_state table? Drag state with source_slot and active flag
function fave_bar.update_drag_visuals(player, drag_state)
  if not player or not player.valid then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10
  for i = 1, max_slots do
    local slot_button = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_" .. i)
    if slot_button then
      if drag_state and drag_state.active and drag_state.source_slot == i then
        -- Style must be set at creation; cannot change after
      else
        fave_bar.update_single_slot(player, i)
      end
    end
  end
end

--- Update toggle button visibility state
---@param player LuaPlayer
---@param slots_visible boolean Whether slots should be visible
function fave_bar.update_toggle_state(player, slots_visible)
  if not player or not player.valid then return end
  
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if slots_frame then
    slots_frame.visible = slots_visible
  end
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
  if is_fave_bar_slot_button(element) and event.button == defines.mouse_button_type.left then
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
