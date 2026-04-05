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


-- icon typing merged into IconUtils
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
local IconUtils = require("core.cache.icon_utils")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")

local fave_bar = {}

local last_build_tick = {}
local STARTUP_SLOT_CHUNK_SIZE = 3
local STARTUP_SHELL_HYDRATION_CHUNK_SIZE = 3
local startup_slot_build_queue = {}
local startup_full_build_queue = {}
local player_slot_trees = {}
local STARTUP_LOADING_PLACEHOLDER = "fave_bar_startup_loading_placeholder"

---@param phase string
---@param player LuaPlayer|nil
---@param context table|nil
local function log_startup_phase(phase, player, context)
  if not ErrorHandler.should_log_debug() then return end
  local log_context = context or {}
  log_context.tick = game and game.tick or 0
  if player and player.valid then
    log_context.player_index = player.index
    log_context.player_name = player.name
  end
  ErrorHandler.debug_log("[STARTUP_BAR] " .. phase, log_context)
end

---@param player_index uint
local function invalidate_player_slot_tree(player_index)
  if not player_index then return end
  player_slot_trees[player_index] = nil
end

---@param player LuaPlayer
---@param slots_frame LuaGuiElement|nil
---@return table|nil
local function get_or_create_slot_tree(player, slots_frame)
  if not player or not player.valid then return nil end
  local player_index = player.index
  local slot_tree = player_slot_trees[player_index]
  if slot_tree and slot_tree.slots_frame and slot_tree.slots_frame.valid then
    if not slots_frame or slot_tree.slots_frame == slots_frame then
      return slot_tree
    end
  end

  if not slots_frame or not slots_frame.valid then return nil end
  slot_tree = {
    slots_frame = slots_frame,
    wrappers = {},
    slot_buttons = {},
    slot_labels = {},
    slot_number_labels = {},
    slot_lock_sprites = {},
    label_mode = nil,
    max_slots = 0,
  }
  player_slot_trees[player_index] = slot_tree
  return slot_tree
end

---@param slot_tree table|nil
---@param slots_frame LuaGuiElement|nil
---@param label_mode string|nil
---@param max_slots integer|nil
local function reset_slot_tree(slot_tree, slots_frame, label_mode, max_slots)
  if not slot_tree then return end
  slot_tree.slots_frame = slots_frame
  slot_tree.wrappers = {}
  slot_tree.slot_buttons = {}
  slot_tree.slot_labels = {}
  slot_tree.slot_number_labels = {}
  slot_tree.slot_lock_sprites = {}
  slot_tree.label_mode = label_mode
  slot_tree.max_slots = max_slots or 0
end

---@param slots_frame LuaGuiElement|nil
local function destroy_all_slot_children(slots_frame)
  if not (slots_frame and slots_frame.valid) then return end
  local children = slots_frame.children
  for i = #children, 1, -1 do
    local child = children[i]
    if child and child.valid then
      child.destroy()
    end
  end
end

---@param slots_frame LuaGuiElement|nil
---@param slot_tree table|nil
---@param slot_index integer
local function destroy_slot_shell(slots_frame, slot_tree, slot_index)
  if not (slots_frame and slots_frame.valid) then return end

  local wrapper = slot_tree and slot_tree.wrappers[slot_index] or nil
  local slot_button = slot_tree and slot_tree.slot_buttons[slot_index] or nil
  if wrapper and not wrapper.valid then wrapper = nil end
  if slot_button and not slot_button.valid then slot_button = nil end

  if not wrapper then
    wrapper = slots_frame["fave_bar_slot_wrapper_" .. slot_index]
  end

  if not slot_button then
    if wrapper and wrapper.valid then
      slot_button = wrapper["fave_bar_slot_" .. slot_index]
    else
      slot_button = slots_frame["fave_bar_slot_" .. slot_index]
    end
  end

  if wrapper and wrapper.valid then
    wrapper.destroy()
  elseif slot_button and slot_button.valid then
    slot_button.destroy()
  end

  if slot_tree then
    slot_tree.wrappers[slot_index] = nil
    slot_tree.slot_buttons[slot_index] = nil
    slot_tree.slot_labels[slot_index] = nil
    slot_tree.slot_number_labels[slot_index] = nil
    slot_tree.slot_lock_sprites[slot_index] = nil
  end
end

---@param bar_flow LuaGuiElement|nil
local function remove_startup_loading_placeholder(bar_flow)
  if not (bar_flow and bar_flow.valid) then return end
  local loading = bar_flow[STARTUP_LOADING_PLACEHOLDER]
  if loading and loading.valid then
    loading.destroy()
  end
end

---@param bar_flow LuaGuiElement|nil
local function ensure_startup_loading_placeholder(bar_flow)
  if not (bar_flow and bar_flow.valid) then return nil end
  local loading = bar_flow[STARTUP_LOADING_PLACEHOLDER]
  if loading and loading.valid then
    return loading
  end
  return bar_flow.add {
    type = "label",
    name = STARTUP_LOADING_PLACEHOLDER,
    caption = "..."
  }
end

---@param slot_tree table|nil
---@param slot_index number
---@param wrapper LuaGuiElement|nil
---@param slot_button LuaGuiElement|nil
---@param slot_number_label LuaGuiElement|nil
---@param slot_label LuaGuiElement|nil
local function cache_slot_refs(slot_tree, slot_index, wrapper, slot_button, slot_number_label, slot_label)
  if not slot_tree then return end
  slot_tree.wrappers[slot_index] = wrapper and wrapper.valid and wrapper or nil
  slot_tree.slot_buttons[slot_index] = slot_button and slot_button.valid and slot_button or nil
  slot_tree.slot_number_labels[slot_index] = slot_number_label and slot_number_label.valid and slot_number_label or nil
  slot_tree.slot_labels[slot_index] = slot_label and slot_label.valid and slot_label or nil
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

---@param fav table|nil
---@return string sprite
---@return LocalisedString tooltip
---@return boolean locked
local function get_slot_runtime_visuals(fav)

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
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[FAVE_BAR] Slot hydration", {
        gps = fav.gps,
        chart_tag_found = chart_tag and chart_tag.valid or false,
        icon = icon
      })
    end
    local validated_sprite = IconUtils.to_sprite_path(icon, {
      fallback = Enum.SpriteEnum.PIN,
      log_context = { fav_gps = fav.gps, fav_tag = fav.tag }
    })
    ---@type LocalisedString
    local tooltip = GuiHelpers.build_favorite_tooltip(fav)
    local is_locked = fav.locked == true
    return validated_sprite, tooltip, is_locked
  end

  ---@type LocalisedString
  local empty_tooltip = { "tf-gui.favorite_slot_empty" }
  return "", empty_tooltip, false
end

---@param player LuaPlayer
---@param slots_frame LuaGuiElement
---@param slot_index number
---@return LuaGuiElement|nil wrapper
---@return LuaGuiElement|nil slot_button
---@return table|nil slot_tree
local function get_slot_gui_refs(player, slots_frame, slot_index)
  if not slots_frame or not slots_frame.valid then return nil, nil, nil end
  local slot_tree = get_or_create_slot_tree(player, slots_frame)

  local wrapper = slot_tree and slot_tree.wrappers[slot_index] or nil
  local slot_button = slot_tree and slot_tree.slot_buttons[slot_index] or nil
  if wrapper and not wrapper.valid then wrapper = nil end
  if slot_button and not slot_button.valid then slot_button = nil end

  if wrapper and slot_button then
    return wrapper, slot_button, slot_tree
  end

  wrapper = slots_frame["fave_bar_slot_wrapper_" .. slot_index]
  local slot_button = nil
  if wrapper and wrapper.valid then
    slot_button = wrapper["fave_bar_slot_" .. slot_index]
  else
    slot_button = slots_frame["fave_bar_slot_" .. slot_index]
  end
  if not (wrapper and wrapper.valid) then wrapper = nil end
  if not (slot_button and slot_button.valid) then slot_button = nil end

  if slot_tree then
    local slot_number_label = slot_button and slot_button["tf_fave_bar_slot_number_" .. tostring(slot_index)] or nil
    local slot_label = wrapper and wrapper["fave_bar_slot_label_" .. slot_index] or nil
    cache_slot_refs(slot_tree, slot_index, wrapper, slot_button, slot_number_label, slot_label)
  end

  return wrapper, slot_button, slot_tree
end

---@param slot_button LuaGuiElement|nil
---@param wrapper LuaGuiElement|nil
---@param slot_index number
---@param fav table|nil
---@param label_mode string
---@param slot_tree table|nil
local function hydrate_slot_in_place(slot_button, wrapper, slot_index, fav, label_mode, slot_tree)
  if not slot_button or not slot_button.valid then return end

  local sprite, tooltip, locked = get_slot_runtime_visuals(fav)
  slot_button.sprite = sprite
  slot_button.tooltip = tooltip

  local number_label = slot_tree and slot_tree.slot_number_labels[slot_index] or nil
  if number_label and not number_label.valid then number_label = nil end
  if not number_label then
    number_label = slot_button["tf_fave_bar_slot_number_" .. tostring(slot_index)]
  end
  if number_label and number_label.valid then
    number_label.style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
    if slot_tree then
      slot_tree.slot_number_labels[slot_index] = number_label
    end
  end

  local lock_sprite = slot_tree and slot_tree.slot_lock_sprites[slot_index] or nil
  if lock_sprite and not lock_sprite.valid then lock_sprite = nil end
  if not lock_sprite then
    lock_sprite = slot_button["slot_lock_sprite_" .. tostring(slot_index)]
  end
  if locked then
    if not (lock_sprite and lock_sprite.valid) then
      lock_sprite = slot_button.add {
        type = "sprite",
        name = "slot_lock_sprite_" .. tostring(slot_index),
        sprite = Enum.SpriteEnum.LOCK,
        style = "tf_fave_bar_slot_lock_sprite"
      }
    end
    if slot_tree then
      slot_tree.slot_lock_sprites[slot_index] = lock_sprite
    end
  elseif lock_sprite and lock_sprite.valid then
    lock_sprite.destroy()
    if slot_tree then
      slot_tree.slot_lock_sprites[slot_index] = nil
    end
  end

  if wrapper and wrapper.valid and label_mode ~= "off" then
    local slot_label = slot_tree and slot_tree.slot_labels[slot_index] or nil
    if slot_label and not slot_label.valid then slot_label = nil end
    if not slot_label then
      slot_label = wrapper["fave_bar_slot_label_" .. slot_index]
    end
    if not (slot_label and slot_label.valid) then
      slot_label = GuiBase.create_label(wrapper, "fave_bar_slot_label_" .. slot_index, "", "tf_fave_bar_slot_label")
    end
    if slot_label and slot_label.valid then
      slot_label.caption = get_slot_label_text(fav, label_mode)
      if slot_tree then
        slot_tree.slot_labels[slot_index] = slot_label
      end
    end
  end
end

---@param slots_frame LuaGuiElement
---@param player LuaPlayer
---@param start_slot number
---@param end_slot number
---@param label_mode string|nil
local function build_startup_slot_shells(slots_frame, player, start_slot, end_slot, label_mode)
  if not slots_frame or not slots_frame.valid then return end
  local resolved_label_mode = label_mode or Cache.Settings.get_player_slot_label_mode(player)
  local use_labels = resolved_label_mode ~= "off"
  local slot_tree = get_or_create_slot_tree(player, slots_frame)
  for i = start_slot, end_slot do
    local btn_parent = slots_frame
    local wrapper = nil
    if use_labels then
      wrapper = slots_frame.add {
        type = "flow",
        name = "fave_bar_slot_wrapper_" .. i,
        direction = "vertical",
        style = "tf_fave_bar_slot_wrapper"
      }
      btn_parent = wrapper
    end

    local btn = GuiHelpers.create_slot_button(btn_parent, "fave_bar_slot_" .. i, "",
      { "tf-gui.favorite_slot_empty" }, { style = "tf_slot_button_smallfont" })
    if btn and btn.valid then
      local slot_number_label = GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(i),
        "tf_fave_bar_slot_number")
      cache_slot_refs(slot_tree, i, wrapper, btn, slot_number_label, nil)
    else
      cache_slot_refs(slot_tree, i, wrapper, nil, nil, nil)
    end
  end

  if slot_tree then
    slot_tree.label_mode = resolved_label_mode
    slot_tree.max_slots = math.max(slot_tree.max_slots or 0, end_slot)
  end
end

---@param player LuaPlayer
---@param slots_frame LuaGuiElement|nil
---@param max_slots integer
---@param label_mode string
---@return table|nil
local function ensure_slot_shells(player, slots_frame, max_slots, label_mode)
  if not (player and player.valid and slots_frame and slots_frame.valid) then return nil end

  local slot_tree = get_or_create_slot_tree(player, slots_frame)
  if not slot_tree then return nil end

  local has_cached_structure = slot_tree.label_mode ~= nil
  local has_existing_gui = slots_frame["fave_bar_slot_1"] or slots_frame["fave_bar_slot_wrapper_1"]
  local needs_full_reset = false

  if has_cached_structure then
    needs_full_reset = slot_tree.label_mode ~= label_mode
  elseif has_existing_gui then
    needs_full_reset = true
  else
    reset_slot_tree(slot_tree, slots_frame, label_mode, 0)
  end

  if needs_full_reset then
    destroy_all_slot_children(slots_frame)
    reset_slot_tree(slot_tree, slots_frame, label_mode, 0)
  else
    slot_tree.slots_frame = slots_frame
    slot_tree.label_mode = label_mode
    slot_tree.max_slots = slot_tree.max_slots or 0
  end

  if slot_tree.max_slots > max_slots then
    for i = slot_tree.max_slots, max_slots + 1, -1 do
      destroy_slot_shell(slots_frame, slot_tree, i)
    end
  elseif slot_tree.max_slots < max_slots then
    build_startup_slot_shells(slots_frame, player, slot_tree.max_slots + 1, max_slots, label_mode)
  end

  slot_tree.label_mode = label_mode
  slot_tree.max_slots = max_slots
  return slot_tree
end

---@param player LuaPlayer
---@param slots_frame LuaGuiElement|nil
---@param max_slots integer
---@param label_mode string
---@param rehydrated_pfaves table|nil
local function hydrate_all_slots(player, slots_frame, max_slots, label_mode, rehydrated_pfaves)
  if not (player and player.valid and slots_frame and slots_frame.valid) then return end

  ensure_slot_shells(player, slots_frame, max_slots, label_mode)

  for i = 1, max_slots do
    local wrapper, slot_button, slot_tree = get_slot_gui_refs(player, slots_frame, i)
    if slot_button and slot_button.valid then
      local fav = rehydrated_pfaves and rehydrated_pfaves[i] or FavoriteUtils.get_blank_favorite()
      hydrate_slot_in_place(slot_button, wrapper, i, fav, label_mode, slot_tree)
    end
  end
end

---@param slots_frame LuaGuiElement|nil
---@param player LuaPlayer
---@param state table
---@param start_slot number
---@param end_slot number
local function hydrate_startup_slot_chunk(slots_frame, player, state, start_slot, end_slot)
  if not slots_frame or not slots_frame.valid then return end
  local label_mode = state.label_mode or Cache.Settings.get_player_slot_label_mode(player)
  for i = start_slot, end_slot do
    local wrapper, slot_button, slot_tree = get_slot_gui_refs(player, slots_frame, i)
    local fav = state.rehydrated_pfaves and state.rehydrated_pfaves[i] or FavoriteUtils.get_blank_favorite()
    hydrate_slot_in_place(slot_button, wrapper, i, fav, label_mode, slot_tree)
  end
end

---@param player LuaPlayer
---@param state table
---@param start_slot number
---@param end_slot number
---@return table
local function rehydrate_startup_slot_range(player, state, start_slot, end_slot)
  if not player or not player.valid then return {} end

  state.rehydrated_pfaves = state.rehydrated_pfaves or {}
  state.startup_snapshot = state.startup_snapshot or
      Cache.get_favorites_render_snapshot(player, state.surface_index, state.max_slots)

  if not state.raw_pfaves then
    state.raw_pfaves = Cache.get_player_favorites(player, state.surface_index) or {}
  end

  local gps_to_warm = {}
  local slots_needing_rehydrate = {}
  local seen_gps = {}
  local blank_gps = Constants.settings.BLANK_GPS

  for i = start_slot, end_slot do
    if state.rehydrated_pfaves[i] == nil then
      local snapshot_fav = state.startup_snapshot and state.startup_snapshot[i] or nil
      if snapshot_fav and type(snapshot_fav) == "table" and snapshot_fav.gps and
          snapshot_fav.gps ~= "" and not FavoriteUtils.is_blank_favorite(snapshot_fav) then
        state.rehydrated_pfaves[i] = snapshot_fav
      else
        table.insert(slots_needing_rehydrate, i)
      end
    end
  end

  for _, i in ipairs(slots_needing_rehydrate) do
    local fav = state.raw_pfaves[i]
    local gps = fav and fav.gps or nil
    if type(gps) == "string" and gps ~= "" and gps ~= blank_gps and not seen_gps[gps] then
      seen_gps[gps] = true
      table.insert(gps_to_warm, gps)
    end
  end

  if #gps_to_warm > 0 then
    Cache.Lookups.warm_gps_entries(gps_to_warm)
  end

  for _, i in ipairs(slots_needing_rehydrate) do
    if state.rehydrated_pfaves[i] == nil then
      local fav = state.raw_pfaves[i]
      if fav and type(fav) == "table" and fav.gps and fav.gps ~= "" and not FavoriteUtils.is_blank_favorite(fav) then
        state.rehydrated_pfaves[i] = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
      else
        state.rehydrated_pfaves[i] = FavoriteUtils.get_blank_favorite()
      end
    end
  end

  return state.rehydrated_pfaves
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
  if player and player.valid then
    invalidate_player_slot_tree(player.index)
    startup_slot_build_queue[player.index] = nil
    startup_full_build_queue[player.index] = nil
  end
end

local function clear_startup_slot_queue(player)
  if player and player.valid then
    startup_slot_build_queue[player.index] = nil
  end
end

---@param player LuaPlayer
---@param force_show boolean|nil
function fave_bar.enqueue_startup_build(player, force_show)
  if not player or not player.valid then return end
  startup_full_build_queue[player.index] = {
    force_show = force_show == true,
    phase = "frame",
    ready_tick = (game and game.tick or 0) + 1,
  }
end

---@param player LuaPlayer
---@param toggle_container LuaGuiElement
---@return LuaGuiElement|nil history_toggle_button
local function ensure_history_toggle_control(player, toggle_container)
  if not toggle_container or not toggle_container.valid then return nil end

  local history_toggle_button = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON]
  if not (history_toggle_button and history_toggle_button.valid) then
    history_toggle_button = GuiBase.create_sprite_button(
      toggle_container,
      Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON,
      Enum.SpriteEnum.SCROLL_HISTORY,
      { "tf-gui.teleport_history_tooltip" },
      "tf_fave_history_toggle_button"
    )
  end

  return history_toggle_button
end

---@param player LuaPlayer
---@param toggle_container LuaGuiElement
---@return LuaGuiElement|nil history_mode_toggle
local function ensure_history_mode_control(player, toggle_container)
  if not toggle_container or not toggle_container.valid then return nil end
  local history_mode_toggle = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON]
  if not (history_mode_toggle and history_mode_toggle.valid) then
    local is_sequential = Cache.get_sequential_history_mode(player)
    local mode_sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
    local mode_tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
    history_mode_toggle = GuiBase.create_sprite_button(
      toggle_container,
      Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON,
      mode_sprite,
      mode_tooltip,
      "tf_fave_history_toggle_button"
    )
  end
  return history_mode_toggle
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
---@param player_settings table
---@param opts table|nil
function fave_bar.build_quickbar_style(player, parent, player_settings, opts) -- Add a horizontal flow to contain the toggle and slots row
  local bar_flow = GuiBase.create_hflow(parent, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)

  local toggle_container = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER, "horizontal",
    "tf_fave_toggle_container")

  local history_toggle_button = nil
  local history_mode_toggle = nil
  if player_settings and player_settings.enable_teleport_history then
    -- Build the history toggle and mode toggle immediately if history is enabled.
    history_toggle_button = ensure_history_toggle_control(player, toggle_container)
    history_mode_toggle = ensure_history_mode_control(player, toggle_container)
  end

  ---@type LocalisedString
  local toggle_tooltip = { "tf-gui.toggle_fave_bar" }
  local slots_visible = true

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

---@param player LuaPlayer
---@param force_show boolean|nil
---@return LuaGuiElement|nil
---Helper: validate player and settings; return true if bar should be built, false if should be destroyed
---@param player LuaPlayer
---@param force_show boolean|nil
---@return boolean should_build
local function validate_and_check_bar_build(player, force_show)
  if not ValidationUtils.validate_player(player) then return false end

  if not force_show then
    local should_hide = not BasicHelpers.is_planet_surface(player.surface) or BasicHelpers.is_restricted_controller(player)
    if should_hide then return false end
  end

  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on and not player_settings.enable_teleport_history then
    return false
  end

  if BasicHelpers.is_restricted_controller(player) then
    return false
  end

  return true
end

---Phase 1: Validate settings and destroy old bar if needed
local function startup_phase_validate_destroy(player, force_show)
  log_startup_phase("startup_phase_validate_destroy.begin", player)
  local should_build = validate_and_check_bar_build(player, force_show)
  if not should_build then
    _destroy_fave_bar(player)
    log_startup_phase("startup_phase_validate_destroy.end - destroying", player)
    return false
  end
  log_startup_phase("startup_phase_validate_destroy.end - proceed", player)
  return true
end

---Phase 2: Create just the outer frame element
local function startup_phase_create_frame(player)
  if not ValidationUtils.validate_player(player) then return nil end
  log_startup_phase("startup_phase_create_frame.begin", player)

  clear_startup_slot_queue(player)
  invalidate_player_slot_tree(player.index)

  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then
    log_startup_phase("startup_phase_create_frame.end - no main_flow", player)
    return nil
  end

  GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

  local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal", "tf_fave_bar_frame")
  if not fave_bar_frame or not fave_bar_frame.valid then
    log_startup_phase("startup_phase_create_frame.end - frame failed", player)
    return nil
  end

  log_startup_phase("startup_phase_create_frame.end", player)
  return fave_bar_frame
end

---Legacy function for backward compatibility if called directly
local function build_startup_shell_frame(player, force_show)
  if not ValidationUtils.validate_player(player) then return nil end
  log_startup_phase("build_startup_shell_frame.begin", player)

  if not validate_and_check_bar_build(player, force_show) then
    _destroy_fave_bar(player)
    return nil
  end

  clear_startup_slot_queue(player)
  invalidate_player_slot_tree(player.index)

  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end

  GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

  local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal", "tf_fave_bar_frame")
  if not fave_bar_frame or not fave_bar_frame.valid then return nil end

  log_startup_phase("build_startup_shell_frame.end", player)

  return fave_bar_frame
end

---@param player LuaPlayer
---@param force_show boolean|nil
---@return LuaGuiElement|nil
local function build_startup_shell_controls(player, force_show)
  if not ValidationUtils.validate_player(player) then return nil end
  log_startup_phase("build_startup_shell_controls.begin", player)

  if not force_show then
    local should_hide = not BasicHelpers.is_planet_surface(player.surface) or BasicHelpers.is_restricted_controller(player)
    if should_hide then
      _destroy_fave_bar(player)
      return nil
    end
  end

  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on and not player_settings.enable_teleport_history then
    _destroy_fave_bar(player)
    return nil
  end

  if BasicHelpers.is_restricted_controller(player) then
    _destroy_fave_bar(player)
    return nil
  end

  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end

  local fave_bar_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if not fave_bar_frame or not fave_bar_frame.valid then
    fave_bar_frame = build_startup_shell_frame(player, force_show)
  end
  if not fave_bar_frame or not fave_bar_frame.valid then return nil end

  local bar_flow, slots_frame, toggle_button, toggle_container, history_toggle_button, history_mode_toggle =
    fave_bar.build_quickbar_style(player, fave_bar_frame, player_settings)

  local favorites_enabled = player_settings.favorites_on
  local history_enabled = player_settings.enable_teleport_history

  if history_enabled and toggle_container and toggle_container.valid then
    if not (history_toggle_button and history_toggle_button.valid) then
      history_toggle_button = ensure_history_toggle_control(player, toggle_container)
    end
  end

  if history_toggle_button and history_toggle_button.valid then
    history_toggle_button.visible = history_enabled
  end

  if history_mode_toggle and history_mode_toggle.valid then
    history_mode_toggle.visible = history_enabled
    local is_sequential = Cache.get_sequential_history_mode(player)
    history_mode_toggle.sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
    history_mode_toggle.tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
  end

  if toggle_button and toggle_button.valid then
    toggle_button.visible = favorites_enabled
  end

  if not slots_frame or not slots_frame.valid then return fave_bar_frame end

  if not favorites_enabled then
    slots_frame.visible = false
    return fave_bar_frame
  end

  local player_data = Cache.get_player_data(player)
  local slots_visible = player_data.fave_bar_slots_visible
  if slots_visible == nil then
    slots_visible = true
    player_data.fave_bar_slots_visible = true
  end

  if toggle_button and toggle_button.valid then
    toggle_button.sprite = slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
  end

  local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10
  local label_mode = Cache.Settings.get_player_slot_label_mode(player)
  local surface_idx = player.surface and player.surface.valid and player.surface.index or nil

  ensure_startup_loading_placeholder(bar_flow)
  slots_frame.visible = false
  startup_slot_build_queue[player.index] = {
    next_slot = 1,
    max_slots = max_slots,
    rehydrated_pfaves = nil,
    surface_index = surface_idx,
    hydrate_only = true,
    label_mode = label_mode,
    shells_chunked = true,
    prebuilt_until = 0,
    reveal_after_ready = slots_visible == true,
    ready_tick = (game and game.tick or 0) + 1,
  }

  log_startup_phase("build_startup_shell_controls.end", player, {
    max_slots = max_slots,
    label_mode = label_mode,
    slots_visible = slots_visible == true,
  })

  return fave_bar_frame
end

function fave_bar.build(player, force_show)

  if not ValidationUtils.validate_player(player) then 
    return 
  end

  -- Hide favorites bar when editing or viewing space platforms (including remote view)
  -- Allow force_show to override all checks for initialization
  if not force_show then
    local should_hide = not BasicHelpers.is_planet_surface(player.surface) or BasicHelpers.is_restricted_controller(player)
    if should_hide then
      _destroy_fave_bar(player)
      return
    end
  end

  local tick = game and game.tick or 0
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if not force_show then
    if last_build_tick[player.index] == tick and bar_frame and bar_frame.valid then
      return
    end
    last_build_tick[player.index] = tick
  end

  local success, result = pcall(function()
    clear_startup_slot_queue(player)
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
      if bar_flow and bar_flow.valid and #bar_flow.children > 0 then
        local toggle_container = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
        local has_toggle_container = toggle_container and toggle_container.valid
        local has_slots_flow = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW] and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW].valid
        has_valid_structure = has_toggle_container and has_slots_flow
      end
    end
    local needs_rebuild = not has_valid_structure
    -- Only destroy if we actually need to rebuild
    if needs_rebuild then
      invalidate_player_slot_tree(player.index)
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
          .build_quickbar_style(player, fave_bar_frame, player_settings)
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

    remove_startup_loading_placeholder(_bar_flow)

    if history_enabled and _toggle_container and _toggle_container.valid then
      if not (_history_toggle_button and _history_toggle_button.valid) then
        _history_toggle_button = ensure_history_toggle_control(player, _toggle_container)
      end
    end

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
      clear_startup_slot_queue(player)
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
      local pfaves = nil

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
        if _toggle_button and _toggle_button.valid then
          _toggle_button.sprite = slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
        end
      end

      local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10
      local label_mode = Cache.Settings.get_player_slot_label_mode(player)
      local use_chunked_startup_build = force_show and needs_rebuild and max_slots > STARTUP_SLOT_CHUNK_SIZE
      if use_chunked_startup_build then
        local surface_idx = player.surface and player.surface.valid and player.surface.index
        local reveal_after_ready = slots_frame.visible == true
        ensure_startup_loading_placeholder(_bar_flow)
        slots_frame.visible = false
        startup_slot_build_queue[player.index] = {
          next_slot = 1,
          max_slots = max_slots,
          rehydrated_pfaves = nil,
          surface_index = surface_idx,
          hydrate_only = true,
          label_mode = label_mode,
          shells_chunked = true,
          prebuilt_until = 0,
          reveal_after_ready = reveal_after_ready,
          ready_tick = (game and game.tick or 0) + 1,
        }
      else
        local surface_index = player.surface.index
        pfaves = Cache.get_player_favorites(player, surface_index) or {}
        local rehydrated_pfaves = Cache.get_rehydrated_favorites(player, surface_index, max_slots) or {}
        hydrate_all_slots(player, slots_frame, max_slots, label_mode, rehydrated_pfaves)
      end

      -- Do NOT update toggle state in pdata here! Only the event handler should do that.

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

function fave_bar.process_startup_slot_build_queue()
  if next(startup_full_build_queue) == nil and next(startup_slot_build_queue) == nil then
    return
  end

  local current_tick = game and game.tick or 0
  local built_startup_shell_this_tick = false

  -- Spread full bar builds across 4 ticks: validate_destroy -> create_frame -> build_quickbar -> populate_slots
  for player_index, state in pairs(startup_full_build_queue) do
    local player = game.players[player_index]
    if not player or not player.valid or not player.connected then
      startup_full_build_queue[player_index] = nil
    elseif not state.ready_tick or current_tick >= state.ready_tick then
      local phase = state.phase or "validate_destroy"
      log_startup_phase("process_startup_slot_build_queue.full_queue", player, { phase = phase })

      if phase == "validate_destroy" then
        local should_proceed = startup_phase_validate_destroy(player, state.force_show)
        if not should_proceed then
          startup_full_build_queue[player_index] = nil
        else
          state.phase = "create_frame"
          state.ready_tick = current_tick + 1
        end

      elseif phase == "create_frame" then
        local frame = startup_phase_create_frame(player)
        if not frame then
          startup_full_build_queue[player_index] = nil
        else
          state.phase = "build_quickbar"
          state.ready_tick = current_tick + 1
        end

      elseif phase == "build_quickbar" then
        build_startup_shell_controls(player, state.force_show)
        startup_full_build_queue[player_index] = nil

      else
        startup_full_build_queue[player_index] = nil
      end

      built_startup_shell_this_tick = true
      break
    end
  end

  -- Do not combine shell build and slot hydration in the same tick.
  -- This lowers startup max-frame spikes on brand-new games.
  if built_startup_shell_this_tick then
    return
  end

  for player_index, state in pairs(startup_slot_build_queue) do
    local player = game.players[player_index]
    if not player or not player.valid or not player.connected then
      invalidate_player_slot_tree(player_index)
      startup_slot_build_queue[player_index] = nil
    else
      local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
      if not slots_frame or not slots_frame.valid then
        invalidate_player_slot_tree(player_index)
        startup_slot_build_queue[player_index] = nil
      else
        if not state.ready_tick or current_tick >= state.ready_tick then
          local start_slot = state.next_slot
          local chunk_size = state.shells_chunked and STARTUP_SHELL_HYDRATION_CHUNK_SIZE or STARTUP_SLOT_CHUNK_SIZE
          local end_slot = math.min(start_slot + chunk_size - 1, state.max_slots)
          log_startup_phase("process_startup_slot_build_queue.slot_chunk", player, {
            start_slot = start_slot,
            end_slot = end_slot,
            max_slots = state.max_slots,
          })
          rehydrate_startup_slot_range(player, state, start_slot, end_slot)
          if state.hydrate_only then
            if state.shells_chunked then
              local prebuilt_until = state.prebuilt_until or 0
              local shell_start = math.max(start_slot, prebuilt_until + 1)
              if shell_start <= end_slot then
                build_startup_slot_shells(slots_frame, player, shell_start, end_slot, state.label_mode)
                state.prebuilt_until = end_slot
              end
            end
            hydrate_startup_slot_chunk(slots_frame, player, state, start_slot, end_slot)

            -- Perceived responsiveness: reveal as soon as first chunk is hydrated
            -- instead of waiting for every slot to finish.
            if state.reveal_after_ready and start_slot == 1 and slots_frame and slots_frame.valid then
              slots_frame.visible = true
            end
          end
          if end_slot >= state.max_slots then
            remove_startup_loading_placeholder(bar_flow)
            if state.reveal_after_ready and slots_frame and slots_frame.valid then
              slots_frame.visible = true
            end
            startup_slot_build_queue[player_index] = nil
          else
            state.next_slot = end_slot + 1
          end

          break
        end
      end
    end
  end
end

---@param player LuaPlayer
---@return LuaGuiElement|nil
function fave_bar.ensure_history_mode_toggle(player)
  if not ValidationUtils.validate_player(player) then return nil end
  local _, _, bar_flow, _ = get_fave_bar_gui_refs(player)
  local toggle_container = bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
  if not toggle_container or not toggle_container.valid then return nil end

  local mode_toggle = ensure_history_mode_control(player, toggle_container)
  if mode_toggle and mode_toggle.valid then
    mode_toggle.visible = true
  end
  return mode_toggle
end

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

  -- Delegate to the batch updater: one rehydration pass, one settings read, direct indexing.
  fave_bar.update_all_slots_in_place(player)
  if parent_flow and parent_flow.valid then
    return parent_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  end
  return nil
end

--- Update a single slot button without rebuilding the entire row
---@param player LuaPlayer
---@param slot_index number Slot index (1-based)
function fave_bar.update_single_slot(player, slot_index)
  if not ValidationUtils.validate_player(player) then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end

  local wrapper, slot_button, slot_tree = get_slot_gui_refs(player, slots_frame, slot_index)
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
  local label_mode = Cache.Settings.get_player_slot_label_mode(player)
  hydrate_slot_in_place(slot_button, wrapper, slot_index, rehydrated_fav, label_mode, slot_tree)
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

  hydrate_all_slots(player, slots_frame, max_slots, label_mode, rehydrated)
end

return fave_bar
