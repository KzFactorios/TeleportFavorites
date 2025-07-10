---@diagnostic disable: undefined-global
--[[
Favorites Bar GUI for TeleportFavorites
======================================
Module: gui/favorites_bar/fave_bar.lua

Builds the favorites bar UI for the TeleportFavorites mod, providing quick-access favorite teleport slots.


Element Hierarchy Diagram:

fave_bar_frame (frame)
└─ fave_bar_flow (flow, horizontal)
          -- First capture the tooltip and ensure children are properly referenced
        local tooltip = toggle_visibility_button.tooltip
        
        -- Force an immediate visual update by recreating the button with the correct state
        toggle_visibility_button.destroy()
        
        -- Create new button with correct sprite and style
        local new_sprite = slots_visible and Enum.SpriteEnum.EYE or Enum.SpriteEnum.EYELASH
        local new_style = slots_visible and "tf_fave_bar_visibility_on" or "tf_fave_bar_visibility_off"
        
        -- Create the new button
        local new_button = GuiBase.create_sprite_button(toggle_container, "fave_bar_visibility_toggle", new_sprite, tooltip, new_style)
        if new_button and new_button.valid then
          new_button.bring_to_front()
        }gle_container (frame, vertical)
   │  └─ fave_bar_visibility_toggle (sprite-button)
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
local GuiHelpers = require("core.utils.gui_helpers")
local Settings = require("core.utils.settings_access")
local Cache = require("core.cache.cache")
local Enum = require("prototypes.enums.enum")
local FaveBarGuiLabelsManager = require("core.control.fave_bar_gui_labels_manager")

local fave_bar = {}

local last_build_tick = {}



-- Build the favorites bar to visually match the quickbar top row
---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent)           -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, "fave_bar_flow") -- Add a thin dark background frame for the toggle button
  local toggle_container = GuiBase.create_frame(bar_flow, "fave_bar_toggle_container", "vertical",
    "tf_fave_toggle_container")

  -- Create a centering flow inside the toggle container
  local toggle_flow = GuiBase.create_hflow(toggle_container, "fave_bar_toggle_flow", "tf_fave_toggle_flow")

  ---@type LocalisedString
  local toggle_tooltip = { "tf-gui.toggle_fave_bar" }  
  -- Determine which visibility icon to use based on slots visibility state
  -- Icon logic: eyelash (closed eye) when slots visible, eye (open) when slots hidden
  local player_data = Cache.get_player_data(player)  
  local visibility_icon = player_data.fave_bar_slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
  local visibility_style = player_data.fave_bar_slots_visible and "tf_fave_bar_visibility_on" or "tf_fave_bar_visibility_off"
  local toggle_visibility_button = GuiBase.create_sprite_button(toggle_flow, "fave_bar_visibility_toggle", 
  visibility_icon, toggle_tooltip, visibility_style)

  -- history/position info
  local teleport_history= GuiBase.create_label(toggle_container, "fave_bar_teleport_history_label", "", "fave_bar_teleport_history_label_style")
  local player_coords = GuiBase.create_label(toggle_container, "fave_bar_coords_label", "", "fave_bar_coords_label_style")

  -- Add slots frame to the same flow for proper layout
  local slots_frame = GuiBase.create_frame(bar_flow, "fave_bar_slots_flow", "horizontal", "tf_fave_slots_row")
  return bar_flow, slots_frame, toggle_visibility_button
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
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  local bar_flow = bar_frame and GuiValidation.find_child_by_name(bar_frame, "fave_bar_flow")
  local slots_frame = bar_flow and GuiValidation.find_child_by_name(bar_flow, "fave_bar_slots_flow")
  return main_flow, bar_frame, bar_flow, slots_frame
end

function fave_bar.build(player, force_show)
  if not player or not player.valid then return end

  -- Hide favorites bar when editing space platforms
  -- Allow force_show to override all checks for initialization
  if not force_show then
    -- Use shared space platform detection logic
    if fave_bar.SmallHelpers == nil then
      fave_bar.SmallHelpers = SmallHelpers or (remote and remote.interfaces and remote.interfaces["SmallHelpers"] and remote.interfaces["SmallHelpers"]) or nil
    end
    local should_hide = false
    if fave_bar.SmallHelpers and fave_bar.SmallHelpers.should_hide_favorites_bar_for_space_platform then
      should_hide = fave_bar.SmallHelpers.should_hide_favorites_bar_for_space_platform(player)
    end
    if should_hide then
      return
    end

    -- Also skip for god mode and spectator mode
    if player.controller_type == defines.controllers.god or 
       player.controller_type == defines.controllers.spectator then
      return
    end
  end

  
  local tick = game and game.tick or 0
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if last_build_tick[player.index] == tick and bar_frame and bar_frame.valid then
    return
  end
  last_build_tick[player.index] = tick

  local success, result = pcall(function()
    local player_settings = Settings:getPlayerSettings(player)
    if not player_settings.favorites_on then 
      return 
    end

    local mode = player and player.render_mode
    if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
      return
    end

    -- Use shared vertical flow
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)

    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

    -- add the fave bar frame
    -- Outer frame for the bar (matches quickbar background)
    local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal",
      "tf_fave_bar_frame")
    local _bar_flow, slots_frame, _toggle_button = fave_bar.build_quickbar_style(player, fave_bar_frame)

    -- Only one toggle button: the one created in build_quickbar_style
    local pfaves = Cache.get_player_favorites(player)
    local drag_index = Cache.get_player_data(player).drag_favorite_index

    -- By default, show the slots row when building the bar
    if slots_frame and slots_frame.valid then
        slots_frame.visible = true
    end

    -- Build slot buttons
    fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)

    -- Do NOT update toggle state in pdata here! Only the event handler should do that.

    -- Do NOT set toggle_container.visible here; toggle button always visible unless a future setting overrides it
    handle_overflow_error(fave_bar_frame, slots_frame, pfaves)

    -- Force update labels after favorites bar is built
    FaveBarGuiLabelsManager.force_update_labels_for_player(player)

    return fave_bar_frame
  end)
  if not success then
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
    -- Safely rehydrate favorite, catch any errors and return blank favorite
    local rehydrated_fav = nil
    local rehydrate_success, rehydrate_error = pcall(function()
      rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    end)
    
    if not rehydrate_success or not rehydrated_fav then
      -- Rehydration failed, treat as blank favorite
      rehydrated_fav = FavoriteUtils.get_blank_favorite()
    end
    
    fav = rehydrated_fav
    
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      -- Icon comes from chart_tag.icon only (tags do not have icon property)
      -- Safely check chart_tag validity before accessing its properties
      local icon = nil
      if fav.tag and fav.tag.chart_tag then
        local valid_check_success, is_valid = pcall(function() return fav.tag.chart_tag.valid end)
        if valid_check_success and is_valid then
          icon = fav.tag.chart_tag.icon
        else
          -- Chart tag is invalid, treat this favorite as blank
          return nil, { "tf-gui.favorite_slot_empty" }, "slot_button", false
        end
      end
      -- Normalize icon type for virtual signals before any debug or sprite logic
      local norm_icon = icon
      if type(icon) == "table" and icon.type == "virtual" then
        norm_icon = {}
        for k, v in pairs(icon) do norm_icon[k] = v end
        norm_icon.type = "virtual-signal"
      end

      local btn_icon, used_fallback, debug_info = GuiValidation.get_validated_sprite_path(norm_icon, { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })

      local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
      if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
      return btn_icon, GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style, fav.locked
    else
      return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont", false
    end
  end

  for i = 1, max_slots do
    local fav = pfaves[i]
    fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    local btn_icon, tooltip, style, locked = get_slot_btn_props(i, fav)
    local btn = GuiHelpers.create_slot_button(parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip, { style = style })
    if btn and btn.valid then
      local label_style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
      -- slot #10 shuold show as 0
      local slot_num = (i == 10) and 0 or i
      GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(slot_num), label_style)
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

  local pfaves = Cache.get_player_favorites(player)

  -- Rebuild only the slot buttons
  fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

  return slots_frame
end

--- Destroy/hide the favorites bar for a player
---@param player LuaPlayer
function fave_bar.destroy(player)
  if not player or not player.valid then return end

  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end

  GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
end

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
  
  -- Safely rehydrate favorite, catch any errors and return blank favorite
  local rehydrated_fav = nil
  local rehydrate_success, rehydrate_error = pcall(function()
    rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  end)
  
  if not rehydrate_success or not rehydrated_fav then
    -- Rehydration failed, treat as blank favorite
    rehydrated_fav = FavoriteUtils.get_blank_favorite()
  end
  
  fav = rehydrated_fav
  
  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    -- Icon comes from chart_tag.icon only (tags do not have icon property)
    -- Safely check chart_tag validity before accessing its properties
    local icon = nil
    if fav.tag and fav.tag.chart_tag then
      local valid_check_success, is_valid = pcall(function() return fav.tag.chart_tag.valid end)
      if valid_check_success and is_valid then
        icon = fav.tag.chart_tag.icon
      else
        -- Chart tag is invalid, treat as blank favorite
        slot_button.sprite = ""
        slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
        return
      end
    end
    local norm_icon = icon
    if type(icon) == "table" and icon.type == "virtual" then
      norm_icon = {}
      for k, v in pairs(icon) do norm_icon[k] = v end
      norm_icon.type = "virtual-signal"
    end
    slot_button.sprite = GuiValidation.get_validated_sprite_path(norm_icon, { fallback = Enum.SpriteEnum.PIN, log_context = { slot = slot_index, fav_gps = fav.gps, fav_tag = fav.tag } })
    ---@type LocalisedString
    slot_button.tooltip = GuiHelpers.build_favorite_tooltip(fav, { slot = slot_index })
  else
    slot_button.sprite = ""
    slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
  end
end

--- Update toggle button visibility state
---@param player LuaPlayer
---@param slots_visible boolean Whether slots should be visible
function fave_bar.update_toggle_state(player, slots_visible)
  if not player or not player.valid then return end
  
  local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
  
  -- First update the toggle button sprite
  if bar_flow then
    local toggle_container = GuiValidation.find_child_by_name(bar_flow, "fave_bar_toggle_container")
    if toggle_container then
      -- Update the visibility toggle button (fave_bar_visibility_toggle)
      local toggle_visibility_button = GuiValidation.find_child_by_name(toggle_container, "fave_bar_visibility_toggle")
      if toggle_visibility_button and toggle_visibility_button.valid then
        -- Simple approach - just update the sprite property
        -- Swapped sprites: eyelash (closed eye) when visible, eye (open) when hidden
        toggle_visibility_button.sprite = slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
      end
    end
  end
  
  -- Then update slots frame visibility
  if slots_frame then
    slots_frame.visible = slots_visible
  end
end

--- Check if favorites bar exists and is valid for a player
---@param player LuaPlayer
---@return boolean exists
function fave_bar.exists(player)
  if not player or not player.valid then return false end
  
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  return bar_frame and bar_frame.valid or false
end

return fave_bar
