---@diagnostic disable: undefined-global

-- gui/favorites_bar/fave_bar.lua
-- TeleportFavorites Factorio Mod
-- Builds the favorites bar UI for quick-access teleport slots.
--
-- Element Hierarchy:
-- fave_bar_frame (frame)
-- └─ fave_bar_flow (flow, horizontal)
--    ├─ fave_bar_toggle_container (frame, vertical)
--    │  ├─ fave_bar_history_toggle (sprite-button)
--    │  ├─ fave_bar_history_mode_toggle (sprite-button)
--    │  └─ fave_bar_visibility_toggle (sprite-button)
--    └─ fave_bar_slots_flow (frame, horizontal)
--       ├─ [mode=off] fave_bar_slot_1 (sprite-button) ... fave_bar_slot_N
--       └─ [mode=short/long] fave_bar_slot_wrapper_1 (flow, vertical)
--          ├─ fave_bar_slot_1 (sprite-button)
--          └─ fave_bar_slot_label_1 (label)

local GuiBase = require("gui.gui_base")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local ErrorMessageHelpers = require("core.utils.error_message_helpers")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite_utils")
local FavoriteRehydration = require("core.favorite.favorite_rehydration")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local Cache = require("core.cache.cache")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")

local fave_bar = {}

local last_build_tick = {}

-- DEBUG: Log module load time
if ErrorHandler and ErrorHandler.debug_log then
  ErrorHandler.debug_log("[FAVE_BAR] Module loaded", {
    tick = game and game.tick or 0,
    game_exists = game ~= nil,
    debug_enabled = ErrorHandler.is_debug()
  })
end

--- Function to get the favorites bar frame for a player
---@param player LuaPlayer Player to get favorites bar frame for
---@return LuaGuiElement? fave_bar_frame The favorites bar frame or nil if not found
local function _get_fave_bar_frame(player)
  if not ValidationUtils.validate_player(player) then return nil end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end
  return GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
end

--- Destroy the favorites bar frame for a player
---@param player LuaPlayer Player whose favorites bar should be destroyed
local function _destroy_fave_bar(player)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if main_flow and main_flow.valid then
    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
  end
end

--- Function to show/hide the entire favorites bar based on surface type and controller
---@param player LuaPlayer Player whose favorites bar visibility should be updated
function fave_bar.update_fave_bar_visibility(player)
  if not ValidationUtils.validate_player(player) then return end

  local fave_bar_frame = _get_fave_bar_frame(player)
  if not fave_bar_frame or not fave_bar_frame.valid then return end

  local surface = player.surface
  if not surface or not surface.valid then
    fave_bar_frame.visible = false
    return
  end

  -- Show bar only on planet surfaces (not space platforms) in appropriate controller modes
  -- Hide for: god mode, spectator mode, space platforms, or unsupported controllers
  local is_planet = BasicHelpers.is_planet_surface(surface)
  local is_supported_mode = BasicHelpers.is_supported_controller(player)
  local is_restricted_mode = BasicHelpers.is_restricted_controller(player)

  fave_bar_frame.visible = is_planet and is_supported_mode and not is_restricted_mode
end

--- Event handler for controller changes
---@param event table Player controller change event
function fave_bar.on_player_controller_changed(event)
  if not event or not event.player_index then return end
  local player = game.players[event.player_index]
  if not player or not player.valid then return end


  -- Restore teleport history modal if it was open before switching to map/chart view, regardless of pin state
  local modal_was_open = Cache.get_modal_dialog_type(player) == "teleport_history"
  -- CRITICAL: Do NOT use player.render_mode here - it's client-specific and causes desyncs!
  -- The modal state is tracked in storage which is synchronized, so we can safely rebuild based on that.
  local is_remote_controller = player.controller_type == defines.controllers.remote
  if is_remote_controller and modal_was_open then
    -- Destroy modal (if present) but preserve state, then rebuild
    teleport_history_modal.destroy(player, true)
    teleport_history_modal.build(player)
  end

  -- Update favorites bar visibility based on new controller type
  fave_bar.update_fave_bar_visibility(player)

  -- Build bar when switching to character, cutscene, or remote mode (for planet view)
  if BasicHelpers.is_supported_controller(player) then
    fave_bar.build(player)
    
  end
end

-- Build the favorites bar to visually match the quickbar top row
---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent) -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)

  local toggle_container = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER, "horizontal",
    "tf_fave_toggle_container")

  -- Add history toggle button inside the history container
  local history_toggle_button = GuiBase.create_sprite_button(
    toggle_container,
    Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON,
    Enum.SpriteEnum.SCROLL_HISTORY,
    { "tf-gui.teleport_history_tooltip" },
    "tf_fave_history_toggle_button"
  )

  -- Add history mode toggle button (standard vs sequential)
  local is_sequential = Cache.get_sequential_history_mode(player)
  local mode_sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
  local mode_tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
  local history_mode_toggle = GuiBase.create_sprite_button(
    toggle_container,
    Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON,
    mode_sprite,
    mode_tooltip,
    "tf_fave_history_toggle_button"
  )

  ---@type LocalisedString
  local toggle_tooltip = { "tf-gui.toggle_fave_bar" }
  local player_data = Cache.get_player_data(player)
  local slots_visible = player_data and player_data.fave_bar_slots_visible
  if slots_visible == nil then slots_visible = true end -- Additional safety default

  local toggle_visibility_button = GuiElementBuilders.create_visibility_toggle_button(
    toggle_container, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON, slots_visible, toggle_tooltip)

  -- Add slots frame to the same flow for proper layout
  local slots_frame = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW, "horizontal",
    "tf_fave_slots_row")
  return bar_flow, slots_frame, toggle_visibility_button, toggle_container, history_toggle_button, history_mode_toggle
end

local function get_fave_bar_gui_refs(player)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  local bar_flow = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
  local slots_frame = bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  return main_flow, bar_frame, bar_flow, slots_frame
end

function fave_bar.build(player, force_show)
  
  local tick = game and game.tick or 0
  ErrorHandler.debug_log("[SPIKE_DEBUG] fave_bar.build called", { tick = tick, player = player and player.name or "<no player>" })

  ErrorHandler.debug_log("[FAVE_BAR] ========== BUILD CALLED ==========", {
    player = player and player.name or "<no player>",
    force_show = force_show or false,
    tick = game.tick
  })
  
  if not ValidationUtils.validate_player(player) then 
    ErrorHandler.debug_log("[FAVE_BAR] Build skipped - invalid player")
    return 
  end

  -- Hide favorites bar when editing or viewing space platforms (including remote view)
  -- Allow force_show to override all checks for initialization
  if not force_show then
    local should_hide = not BasicHelpers.is_planet_surface(player.surface) or BasicHelpers.is_restricted_controller(player)
    if should_hide then
      ErrorHandler.debug_log("[FAVE_BAR] Build skipped", {
        reason = not BasicHelpers.is_planet_surface(player.surface) and "space platform" or "god/spectator mode"
      })
      _destroy_fave_bar(player)
      return
    end
  end
  
  ErrorHandler.debug_log("[FAVE_BAR] Proceeding with bar build", {
    player = player.name
  })

  local tick = game and game.tick or 0
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  -- Always recreate bar_frame if missing or invalid
  if not bar_frame or not bar_frame.valid then
    bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "vertical", "tf_fave_bar_frame")
  end
  if not force_show then
    if last_build_tick[player.index] == tick and bar_frame and bar_frame.valid then
      return
    end
    last_build_tick[player.index] = tick
  end

  local success, result = pcall(function()
    local player_settings = Cache.Settings.get_player_settings(player)

    -- Handle case where both favorites and teleport history are disabled
    if not player_settings.favorites_on and not player_settings.enable_teleport_history then
      _destroy_fave_bar(player)
      return
    end

    -- CRITICAL: Do NOT use player.render_mode to decide whether to destroy the bar!
    -- render_mode is client-specific and causes desyncs in multiplayer.
    -- Only check controller_type which is synchronized game state.
    if BasicHelpers.is_restricted_controller(player) then
      _destroy_fave_bar(player)
      return
    end

    -- Use shared vertical flow
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)

    -- PERFORMANCE: Only destroy and recreate if GUI structure needs to change
    -- Check if existing frame is valid AND has child elements
    local existing_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    local has_valid_structure = false
    if existing_frame and existing_frame.valid then
      -- Check if the frame has the expected child structure
      local bar_flow = existing_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      has_valid_structure = bar_flow and bar_flow.valid and #bar_flow.children > 0
    end
    local needs_rebuild = not has_valid_structure
    -- Only destroy if we actually need to rebuild
    if needs_rebuild then
      GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
    end

    -- Create frame only if needed, otherwise reuse existing
    local fave_bar_frame
    if needs_rebuild then
      -- Outer frame for the bar (matches quickbar background)
      fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal",
        "tf_fave_bar_frame")
    else
      fave_bar_frame = existing_frame
    end
    -- Build or retrieve GUI structure
    local _bar_flow, slots_frame, _toggle_button, _toggle_container, _history_toggle_button, _history_mode_toggle
    if needs_rebuild then
      _bar_flow, slots_frame, _toggle_button, _toggle_container, _history_toggle_button, _history_mode_toggle = fave_bar
          .build_quickbar_style(player, fave_bar_frame)
    else
      -- Retrieve existing GUI elements via direct indexing instead of recursive search
      _bar_flow = fave_bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      slots_frame = _bar_flow and _bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
      _toggle_container = _bar_flow and _bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
      _toggle_button = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON]
      _history_toggle_button = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON]
      _history_mode_toggle = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON]
    end

    -- Handle visibility based on settings
    local favorites_enabled = player_settings.favorites_on
    local history_enabled = player_settings.enable_teleport_history

    -- Hide/show history toggle button based on settings
    if _history_toggle_button and _history_toggle_button.valid then
      _history_toggle_button.visible = history_enabled
    end
    if _history_mode_toggle and _history_mode_toggle.valid then
      _history_mode_toggle.visible = history_enabled
      -- Always refresh sprite/tooltip to reflect current mode state
      local is_sequential = Cache.get_sequential_history_mode(player)
      _history_mode_toggle.sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
      _history_mode_toggle.tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
    end

    -- Hide/show toggle container and slots based on favorites setting
    if not favorites_enabled then
      -- Hide the visibility toggle button
      if _toggle_button and _toggle_button.valid then
        _toggle_button.visible = false
      end

      -- Hide slots frame
      if slots_frame and slots_frame.valid then
        slots_frame.visible = false
      end
    else
      -- Only build slots and set visibility if favorites are enabled
      local surface_index = player.surface.index
      local pfaves = Cache.get_player_favorites(player, surface_index)

      -- Show the visibility toggle button
      if _toggle_button and _toggle_button.valid then
        _toggle_button.visible = true
      end

      -- Set slots visibility based on player's saved preference
      if slots_frame and slots_frame.valid then
        local player_data = Cache.get_player_data(player)
        local slots_visible = player_data.fave_bar_slots_visible
        -- Default to true for new players or when preference not set
        if slots_visible == nil then 
          slots_visible = true
          player_data.fave_bar_slots_visible = true -- Save the default
        end
        slots_frame.visible = slots_visible
      end

      -- Build slot buttons (destroy existing ones first for non-rebuild path)
      if slots_frame and slots_frame.valid then
        local children = slots_frame.children
        for i = #children, 1, -1 do
          local child = children[i]
          if child and child.valid then
            child.destroy()
          end
        end
      end
      fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

      -- Do NOT update toggle state in pdata here! Only the event handler should do that.

      local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
      if pfaves and #pfaves > max_slots then
        ErrorMessageHelpers.show_simple_error_label(fave_bar_frame, "tf-gui.fave_bar_overflow_error")
      end
    end

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




--- Get truncated label text for a slot based on the label mode setting
---@param fav table|nil Rehydrated favorite object
---@param mode string "off", "short", or "long"
---@return string label_text Truncated text or empty string
local function get_slot_label_text(fav, mode)
  if mode == "off" then return "" end
  if not fav or FavoriteUtils.is_blank_favorite(fav) then return "" end
  local text = ""
  if fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.valid then
    text = fav.tag.chart_tag.text or ""
  end
  if text == "" then return "" end
  if mode == "short" then
    return string.sub(text, 1, 5)
  elseif mode == "long" then
    if #text > 64 then
      return string.sub(text, 1, 64) .. "..."
    end
    return text
  end
  return ""
end


local function build_favorite_buttons_row(parent, player, pfaves)
  if not parent or not parent.valid then
    ErrorHandler.warn_log("[FAVE_BAR] build_favorite_buttons_row called with invalid parent", {
      parent_exists = parent ~= nil,
      player = player and player.name
    })
    return parent
  end

  local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10

  -- Rehydrate all favorites for correct icon and tag references
  local rehydrated_pfaves = {}
  for i = 1, max_slots do
    local fav = pfaves and pfaves[i] or nil
    if fav then
      local rehydrated = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
      rehydrated_pfaves[i] = rehydrated or FavoriteUtils.get_blank_favorite()
    else
      rehydrated_pfaves[i] = FavoriteUtils.get_blank_favorite()
    end
  end

  local function get_slot_btn_props(i, fav)
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      local icon = nil
      local chart_tag = fav.tag and fav.tag.chart_tag or nil
      if chart_tag and chart_tag.valid then
        icon = chart_tag.icon
      else
        local chart_tag_lookup = fav.gps and Cache.Lookups.get_chart_tag_by_gps(fav.gps) or nil
        if chart_tag_lookup and chart_tag_lookup.valid then
          icon = chart_tag_lookup.icon
        end
      end
      local sprite_icon = icon
      if type(icon) == "table" then
        local icon_type = icon.type
        if icon_type == "virtual" or icon_type == "virtual_signal" then
          sprite_icon = { type = "virtual-signal" }
          for k, v in pairs(icon) do
            if k ~= "type" then sprite_icon[k] = v end
          end
        end
      end
      local btn_icon = GuiValidation.get_validated_sprite_path(sprite_icon,
        { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
      local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
      if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
      return btn_icon, GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style, fav.locked
    else
      return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont", false
    end
  end

  local label_mode = Cache.Settings.get_player_slot_label_mode(player)
  local use_labels = label_mode ~= "off"

  for i = 1, max_slots do
    local fav = rehydrated_pfaves[i]
    local btn_icon, tooltip, style, locked = get_slot_btn_props(i, fav)

    -- When labels are enabled, wrap button + label in a vertical flow
    local btn_parent = parent
    if use_labels then
      local wrapper = parent.add {
        type = "flow",
        name = "fave_bar_slot_wrapper_" .. i,
        direction = "vertical",
        style = "tf_fave_bar_slot_wrapper"
      }
      btn_parent = wrapper
    end

    local btn = GuiHelpers.create_slot_button(btn_parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip, { style = style })
    if btn and btn.valid then
      local number_label_style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
      local slot_num = i
      GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(slot_num), number_label_style)
      if locked then
        btn.add {
          type = "sprite",
          name = "slot_lock_sprite_" .. tostring(i),
          sprite = Enum.SpriteEnum.LOCK,
          style = "tf_fave_bar_slot_lock_sprite"
        }
      end
      -- Add text label below button when labels are enabled
      if use_labels then
        local label_text = get_slot_label_text(fav, label_mode)
        GuiBase.create_label(btn_parent, "fave_bar_slot_label_" .. i, label_text, "tf_fave_bar_slot_label")
      end
    else
      ErrorHandler.warn_log("[FAVE_BAR] Failed to create slot button", { slot = i, icon = btn_icon })
    end
  end

  return parent
end

-- Export the function on the fave_bar table (in case it was not attached)
fave_bar.build_favorite_buttons_row = build_favorite_buttons_row

--- Refresh only the slot buttons if the bar exists, otherwise do a full build.
--- This is the preferred entry point for observer-driven updates.
---@param player LuaPlayer
function fave_bar.refresh_slots(player)
  if not ValidationUtils.validate_player(player) then return end
  -- update_all_slots_in_place does a single batched pass (one rehydration, one settings read)
  -- and falls back to build() if the bar structure is missing.
  fave_bar.update_all_slots_in_place(player)
end

-- Update only the slots row without rebuilding the entire bar.
-- parent_flow is accepted for backward compatibility but not needed — the batch updater
-- resolves its own refs. Delegates to update_all_slots_in_place for a single-pass update.
function fave_bar.update_slot_row(player, parent_flow)
  if not ValidationUtils.validate_player(player) then return end
  if parent_flow and not parent_flow.valid then return end

  -- Fast-path: check for slot existence without recursive search
  local slots_frame
  if parent_flow and parent_flow.valid then
    slots_frame = parent_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  end
  if slots_frame and slots_frame.valid then
    local first_slot = slots_frame["fave_bar_slot_1"] or slots_frame["fave_bar_slot_wrapper_1"]
    if not first_slot then
      -- Slots don't exist yet — fall back to destroy+recreate
      local pfaves = Cache.get_player_favorites(player, player.surface.index)
      fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)
      return slots_frame
    end
  end

  -- Delegate to the batch updater: one rehydration pass, one settings read, direct indexing.
  fave_bar.update_all_slots_in_place(player)
  return slots_frame
end

--- Update a single slot button without rebuilding the entire row
---@param player LuaPlayer
---@param slot_index number Slot index (1-based)
function fave_bar.update_single_slot(player, slot_index)
  if not ValidationUtils.validate_player(player) then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end

  -- Find the slot button — may be directly in slots_frame or inside a wrapper flow
  local wrapper = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_wrapper_" .. slot_index)
  local slot_button
  if wrapper and wrapper.valid then
    slot_button = GuiValidation.find_child_by_name(wrapper, "fave_bar_slot_" .. slot_index)
  else
    slot_button = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_" .. slot_index)
  end
  if not slot_button then return end

  local surface_index = player.surface.index
  local pfaves = Cache.get_player_favorites(player, surface_index)
  if not pfaves then return end -- Safety check for nil pfaves
  local fav = pfaves[slot_index]

  -- Rehydrate favorite for correct icon and tag references
  local rehydrated_fav
  if fav then
    rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  end
  if not rehydrated_fav then
    rehydrated_fav = FavoriteUtils.get_blank_favorite()
  end

  fav = rehydrated_fav

  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    -- Icon comes from chart_tag.icon only (tags do not have icon property)
    local icon = nil
    local chart_tag = fav.tag and fav.tag.chart_tag or nil
    if chart_tag and chart_tag.valid then
      icon = chart_tag.icon
    else
      local chart_tag_lookup = fav.gps and Cache.Lookups.get_chart_tag_by_gps(fav.gps) or nil
      if chart_tag_lookup and chart_tag_lookup.valid then
        icon = chart_tag_lookup.icon
      end
    end
    local sprite_icon = icon
    if type(icon) == "table" then
      local icon_type = icon.type
      if icon_type == "virtual" or icon_type == "virtual_signal" then
        sprite_icon = { type = "virtual-signal" }
        for k, v in pairs(icon) do
          if k ~= "type" then sprite_icon[k] = v end
        end
      end
    end
    slot_button.sprite = GuiValidation.get_validated_sprite_path(sprite_icon,
      { fallback = Enum.SpriteEnum.PIN, log_context = { slot = slot_index, fav_gps = fav.gps, fav_tag = fav.tag } })
    ---@type LocalisedString
    slot_button.tooltip = GuiHelpers.build_favorite_tooltip(fav, { slot = slot_index })
  else
    slot_button.sprite = ""
    ---@diagnostic disable-next-line: assign-type-mismatch
    slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
  end

  -- Update slot label text if wrapper exists
  if wrapper and wrapper.valid then
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    local slot_label = GuiValidation.find_child_by_name(wrapper, "fave_bar_slot_label_" .. slot_index)
    if slot_label and slot_label.valid then
      slot_label.caption = get_slot_label_text(fav, label_mode)
    end
  end
end

--- Update toggle button visibility state
---@param player LuaPlayer
---@param slots_visible boolean Whether slots should be visible
function fave_bar.update_toggle_state(player, slots_visible)
  if not ValidationUtils.validate_player(player) then return end

  -- Ensure slots_visible is a proper boolean
  if slots_visible == nil then slots_visible = true end

  local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)

  -- First update the toggle button sprite
  if bar_flow then
    local toggle_container = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
    if toggle_container then
      -- Update the visibility toggle button (fave_bar_visibility_toggle)
      local toggle_visibility_button = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON]
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




--- Update all slot buttons in-place without destroying/recreating GUI elements.
--- UPS OPTIMIZATION: Fetches GUI refs, favorites, and rehydrated data ONCE,
--- then patches each slot directly. Eliminates N redundant GUI traversals,
--- N redundant storage lookups, and N individual rehydrations.
--- Falls back to build() if bar structure is missing.
---@param player LuaPlayer
function fave_bar.update_all_slots_in_place(player)
  if not ValidationUtils.validate_player(player) then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame or not slots_frame.valid then
    -- Bar structure missing — fall back to full build
    fave_bar.build(player)
    return
  end

  local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10
  local surface_index = player.surface.index

  -- Batch rehydrate all favorites once (uses 1-second TTL cache)
  local rehydrated = Cache.get_rehydrated_favorites(player, surface_index)
  local label_mode = Cache.Settings.get_player_slot_label_mode(player)

  for i = 1, max_slots do
    -- Direct child access by name (O(1)) instead of recursive find_child_by_name
    local wrapper = slots_frame["fave_bar_slot_wrapper_" .. i]
    local slot_button
    if wrapper and wrapper.valid then
      slot_button = wrapper["fave_bar_slot_" .. i]
    else
      slot_button = slots_frame["fave_bar_slot_" .. i]
    end
    if slot_button and slot_button.valid then
      local fav = rehydrated and rehydrated[i] or FavoriteUtils.get_blank_favorite()

      local did_update = false
      if fav and not FavoriteUtils.is_blank_favorite(fav) then
        local icon = nil
        local chart_tag = fav.tag and fav.tag.chart_tag or nil
        if chart_tag and chart_tag.valid then
          icon = chart_tag.icon
        else
          local chart_tag_lookup = fav.gps and Cache.Lookups.get_chart_tag_by_gps(fav.gps) or nil
          if chart_tag_lookup and chart_tag_lookup.valid then
            icon = chart_tag_lookup.icon
          end
        end
        if icon ~= nil then
          local sprite_icon = icon
          if type(icon) == "table" then
            local icon_type = icon.type
            if icon_type == "virtual" or icon_type == "virtual_signal" then
              sprite_icon = { type = "virtual-signal" }
              for k, v in pairs(icon) do
                if k ~= "type" then sprite_icon[k] = v end
              end
            end
          end
          slot_button.sprite = GuiValidation.get_validated_sprite_path(sprite_icon,
            { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
          ---@type LocalisedString
          slot_button.tooltip = GuiHelpers.build_favorite_tooltip(fav, { slot = i })
          did_update = true
        end
      end
      if not did_update then
        slot_button.sprite = ""
        ---@diagnostic disable-next-line: assign-type-mismatch
        slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
      end

      -- Update slot label text
      if wrapper and wrapper.valid then
        local slot_label = wrapper["fave_bar_slot_label_" .. i]
        if slot_label and slot_label.valid then
          slot_label.caption = get_slot_label_text(fav, label_mode)
        end
      end
    end
  end
end

-- DEBUG: Log all keys in fave_bar at module load time
if ErrorHandler and ErrorHandler.debug_log then
  local keys = {}
  for k, v in pairs(fave_bar) do table.insert(keys, tostring(k)) end
  ErrorHandler.debug_log("[FAVE_BAR] Exported keys at module load", { keys = table.concat(keys, ", ") })
end

return fave_bar
