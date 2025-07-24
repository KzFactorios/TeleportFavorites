---@diagnostic disable: undefined-global

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

---@param player LuaPlayer Player to get favorites bar frame for
---@return LuaGuiElement? fave_bar_frame The favorites bar frame or nil if not found
local function _get_fave_bar_frame(player)
  if not ValidationUtils.validate_player(player) then return nil end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end
  return GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
end

---@param player LuaPlayer Player whose favorites bar visibility should be updated
function fave_bar.update_fave_bar_visibility(player)
  if not ValidationUtils.validate_player(player) then return end

  local fave_bar_frame = _get_fave_bar_frame(player)
  if not fave_bar_frame or not fave_bar_frame.valid then return end

  local should_hide = BasicHelpers.should_hide_favorites_bar_for_space_platform(player)

  if player.controller_type == defines.controllers.god or
      player.controller_type == defines.controllers.spectator then
    should_hide = true
  end

  fave_bar_frame.visible = not should_hide
end

---@param event table Player controller change event
function fave_bar.on_player_controller_changed(event)
  if not event or not event.player_index then return end
  local player = game.players[event.player_index]
  if not player or not player.valid then return end


  local modal_was_open = Cache.get_modal_dialog_type(player) == "teleport_history"
  local is_chart_view = player.render_mode == defines.render_mode.chart or
  player.render_mode == defines.render_mode.chart_zoomed_in
  if (player.controller_type == defines.controllers.remote or is_chart_view) and modal_was_open then
    teleport_history_modal.destroy(player, true)
    teleport_history_modal.build(player)
  end

  fave_bar.update_fave_bar_visibility(player)

  if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
    fave_bar.build(player)
  end
end

---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent)
  local bar_flow = GuiBase.create_hflow(parent, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)

  local toggle_container = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER, "horizontal",
    "tf_fave_toggle_container")

  local history_toggle_button = GuiBase.create_sprite_button(
    toggle_container,
    Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON,
    Enum.SpriteEnum.SCROLL_HISTORY,
    { "tf-gui.teleport_history_tooltip" },
    "tf_fave_history_toggle_button"
  )

  ---@type LocalisedString
  local toggle_tooltip = { "tf-gui.toggle_fave_bar" }
  local player_data = Cache.get_player_data(player)
  local slots_visible = player_data.fave_bar_slots_visible
  if slots_visible == nil then slots_visible = true end

  local toggle_visibility_button = GuiElementBuilders.create_visibility_toggle_button(
    toggle_container, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON, slots_visible, toggle_tooltip)

  local slots_frame = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW, "horizontal",
    "tf_fave_slots_row")
  return bar_flow, slots_frame, toggle_visibility_button, toggle_container, history_toggle_button
end

local function get_fave_bar_gui_refs(player)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
  local bar_flow = bar_frame and GuiValidation.find_child_by_name(bar_frame, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)
  local slots_frame = bar_flow and GuiValidation.find_child_by_name(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW)
  return main_flow, bar_frame, bar_flow, slots_frame
end

function fave_bar.build(player, force_show)
  if not ValidationUtils.validate_player(player) then return end

  if not force_show then
    local should_hide = BasicHelpers.should_hide_favorites_bar_for_space_platform(player)
    if should_hide then
      fave_bar.destroy()
      return
    end

    if player.controller_type == defines.controllers.god or
        player.controller_type == defines.controllers.spectator then
      fave_bar.destroy()
      return
    end
  end

  local tick = game and game.tick or 0
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if not force_show and last_build_tick[player.index] == tick and bar_frame and bar_frame.valid then
    return
  end
  last_build_tick[player.index] = tick

  local success, result = pcall(function()
    local player_settings = Cache.Settings.get_player_settings(player)

    if not player_settings.favorites_on and not player_settings.enable_teleport_history then
      local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
      return
    end

    local mode = player and player.render_mode
    if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
      return
    end

    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)

    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)

    local fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal",
      "tf_fave_bar_frame")
    local _bar_flow, slots_frame, _toggle_button, _toggle_container, _history_toggle_button = fave_bar
        .build_quickbar_style(player, fave_bar_frame)

    local favorites_enabled = player_settings.favorites_on
    local history_enabled = player_settings.enable_teleport_history

    if _history_toggle_button and _history_toggle_button.valid then
      _history_toggle_button.visible = history_enabled
    end

    if not favorites_enabled then
      local toggle_container = GuiValidation.find_child_by_name(_bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT
        .TOGGLE_CONTAINER)
      if toggle_container and toggle_container.valid then
        local visibility_toggle_button = GuiValidation.find_child_by_name(toggle_container,
          Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON)
        if visibility_toggle_button and visibility_toggle_button.valid then
          visibility_toggle_button.visible = false
        end
      end

      if slots_frame and slots_frame.valid then
        slots_frame.visible = false
      end
    else
      local pfaves = Cache.get_player_favorites(player)

      local toggle_container = GuiValidation.find_child_by_name(_bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT
        .TOGGLE_CONTAINER)
      if toggle_container and toggle_container.valid then
        local visibility_toggle_button = GuiValidation.find_child_by_name(toggle_container,
          Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON)
        if visibility_toggle_button and visibility_toggle_button.valid then
          visibility_toggle_button.visible = true
        end
      end

      if slots_frame and slots_frame.valid then
        local player_data = Cache.get_player_data(player)
        local slots_visible = player_data.fave_bar_slots_visible
        if slots_visible == nil then slots_visible = true end
        slots_frame.visible = slots_visible
      end

      fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)


      if pfaves and #pfaves > Constants.settings.MAX_FAVORITE_SLOTS then
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

function fave_bar.build_favorite_buttons_row(parent, player, pfaves)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10

  local function get_slot_btn_props(i, fav)
    local rehydrated_fav = nil
    local rehydrate_success = pcall(function()
      rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    end)

    if not rehydrate_success or not rehydrated_fav then
      rehydrated_fav = FavoriteUtils.get_blank_favorite()
    end

    fav = rehydrated_fav

    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      local icon = nil
      if fav.tag and fav.tag.chart_tag then
        local valid_check_success, is_valid = pcall(function() return fav.tag.chart_tag.valid end)
        if valid_check_success and is_valid then
          icon = fav.tag.chart_tag.icon
        else
          return nil, { "tf-gui.favorite_slot_empty" }, "slot_button", false
        end
      end
      local norm_icon = icon
      if type(icon) == "table" and icon.type == "virtual" then
        norm_icon = {}
        for k, v in pairs(icon) do norm_icon[k] = v end
        norm_icon.type = "virtual_signal"
      end
      local sprite_icon = norm_icon
      if type(norm_icon) == "table" and norm_icon.type == "virtual_signal" then
        sprite_icon = {}
        for k, v in pairs(norm_icon) do sprite_icon[k] = v end
        sprite_icon.type = "virtual-signal"
      end

      ErrorHandler.debug_log("Favorites bar icon processing", {
        slot = i,
        fav_gps = fav.gps,
        original_icon = icon,
        normalized_icon = norm_icon,
        sprite_icon = sprite_icon,
        icon_type = norm_icon and norm_icon.type,
        icon_name = norm_icon and norm_icon.name
      })

      local btn_icon = GuiValidation.get_validated_sprite_path(sprite_icon,
        { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })

      ErrorHandler.debug_log("Favorites bar sprite path result", {
        slot = i,
        btn_icon = btn_icon,
        used_fallback = btn_icon == Enum.SpriteEnum.PIN
      })

      local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
      if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
      return btn_icon, GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style,
          fav.locked
    else
      return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont", false
    end
  end

  for i = 1, max_slots do
    local fav = pfaves[i]
    local btn_icon, tooltip, style, locked = get_slot_btn_props(i, fav)
    local btn = GuiHelpers.create_slot_button(parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip,
      { style = style })
    if btn and btn.valid then
      local label_style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
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
      ErrorHandler.warn_log("[FAVE_BAR] Failed to create slot button", { slot = i, icon = btn_icon })
    end
  end
  return parent
end

function fave_bar.update_slot_row(player, parent_flow)
  if not ValidationUtils.validate_player(player) then return end
  if not parent_flow or not parent_flow.valid then return end

  local slots_frame = GuiValidation.find_child_by_name(parent_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW)
  if not slots_frame or not slots_frame.valid then return end

  for _, child in pairs(slots_frame.children) do
    if child and child.valid then
      child.destroy()
    end
  end

  local pfaves = Cache.get_player_favorites(player)

  fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

  return slots_frame
end

---@param player LuaPlayer
---@param slot_index number Slot index (1-based)
function fave_bar.update_single_slot(player, slot_index)
  if not ValidationUtils.validate_player(player) then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame then return end
  local slot_button = GuiValidation.find_child_by_name(slots_frame, "fave_bar_slot_" .. slot_index)
  if not slot_button then return end

  local pfaves = Cache.get_player_favorites(player)
  if not pfaves then return end
  local fav = pfaves[slot_index]

  local rehydrated_fav = nil
  local rehydrate_success = pcall(function()
    if fav then
      rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
    end
  end)

  if not rehydrate_success or not rehydrated_fav then
    rehydrated_fav = FavoriteUtils.get_blank_favorite()
  end

  fav = rehydrated_fav

  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    local icon = nil
    if fav.tag and fav.tag.chart_tag then
      local valid_check_success, is_valid = pcall(function() return fav.tag.chart_tag.valid end)
      if valid_check_success and is_valid then
        icon = fav.tag.chart_tag.icon
      else
        slot_button.sprite = ""
        ---@diagnostic disable-next-line: assign-type-mismatch
        slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
        return
      end
    end
    local norm_icon = icon
    if type(icon) == "table" and icon.type == "virtual" then
      norm_icon = {}
      for k, v in pairs(icon) do norm_icon[k] = v end
      norm_icon.type = "virtual_signal"
    end
    local sprite_icon = norm_icon
    if type(norm_icon) == "table" and norm_icon.type == "virtual_signal" then
      sprite_icon = {}
      for k, v in pairs(norm_icon) do sprite_icon[k] = v end
      sprite_icon.type = "virtual-signal"
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
end

---@param player LuaPlayer
---@param slots_visible boolean Whether slots should be visible
function fave_bar.update_toggle_state(player, slots_visible)
  if not ValidationUtils.validate_player(player) then return end

  if slots_visible == nil then slots_visible = true end

  local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)

  if bar_flow then
    local toggle_container = GuiValidation.find_child_by_name(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER)
    if toggle_container then
      local toggle_visibility_button = GuiValidation.find_child_by_name(toggle_container,
        Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON)
      if toggle_visibility_button and toggle_visibility_button.valid then
        toggle_visibility_button.sprite = slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
      end
    end
  end

  if slots_frame then
    slots_frame.visible = slots_visible
  end
end

return fave_bar
