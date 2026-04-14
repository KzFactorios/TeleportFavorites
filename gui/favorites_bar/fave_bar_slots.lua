---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- gui/favorites_bar/fave_bar_slots.lua
-- Slot building, updating, and refresh functions extracted from fave_bar.lua.
-- Extend pattern: receives (fave_bar, helpers) where helpers contains shared private functions.

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
return function(fave_bar, helpers)
  local is_build_in_flight        = helpers.is_build_in_flight
  local get_fave_bar_gui_refs     = helpers.get_fave_bar_gui_refs
  local get_slot_label_text       = helpers.get_slot_label_text
  local get_slot_btn_props        = helpers.get_slot_btn_props
  local build_single_slot         = helpers.build_single_slot
  local cancel_progressive_build_for = helpers.cancel_progressive_build_for
  local prune_stale_favorites     = helpers.prune_stale_favorites
  local last_build_tick           = helpers.last_build_tick
  local _destroy_fave_bar         = helpers._destroy_fave_bar

  local function apply_slot_visuals(btn, fav, slot_index)
    local icon, tooltip, style = get_slot_btn_props(slot_index, fav)
    btn.sprite  = icon or ""
    btn.tooltip = tooltip
    btn.style   = style
    local lock_el = btn["tf_slot_lock"]
    if not lock_el or not lock_el.valid then
      lock_el = btn.add {
        type                   = "sprite",
        name                   = "tf_slot_lock",
        sprite                 = "tf_fave_slot_lock",
        ignored_by_interaction = true,
        style                  = "tf_fave_slot_lock_overlay",
      }
    end
    if lock_el and lock_el.valid then
      lock_el.visible = BasicHelpers.is_locked_favorite(fav)
    end
  end

  local function clear_element_children(el)
    if not el or not el.valid then return end
    local ch = el.children
    if not ch then return end
    -- Do not use `#ch` on LuaCustomTable — count can disagree between peers; always peel index 1.
    for _ = 1, 512 do
      local c = ch[1]
      if c == nil or not c.valid then break end
      c.destroy()
    end
  end

  --- Attempt to update all slot buttons in place (no destroy/recreate).
  --- Returns true on success; false means structure changed and a full rebuild is needed.
  local function try_update_slots_in_place(slots_frame, player, pfaves)
    local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    local use_labels = label_mode ~= "off"
    local children = slots_frame.children
    local child_count = GuiHelpers.count_direct_children(slots_frame)

    if child_count ~= max_slots then
      log("[TeleportFavorites][FAVE_BAR] try_update_slots_in_place: count mismatch children="
        .. tostring(child_count) .. " max_slots=" .. tostring(max_slots))
      return false
    end

    local rehydrated = {}
    for i = 1, max_slots do
      local fav = pfaves and pfaves[i] or nil
      local r = fav and PlayerFavorites.rehydrate_favorite_at_runtime(player, fav) or nil
      rehydrated[i] = r or FavoriteUtils.get_blank_favorite()
    end

    for i = 1, max_slots do
      local fav = rehydrated[i]
      local child = children[i]
      if not child or not child.valid then return false end

      local btn, label_el
      if use_labels then
        if child.type ~= "flow" then return false end
        btn = child["fave_bar_slot_" .. i]
        label_el = child["fave_bar_slot_label_" .. i]
      else
        btn = child
      end
      if not btn or not btn.valid then return false end

      apply_slot_visuals(btn, fav, i)

      if label_el and label_el.valid then
        label_el.caption = get_slot_label_text(fav, label_mode)
      end
    end

    return true
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
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    local use_labels = label_mode ~= "off"

    for i = 1, max_slots do
      build_single_slot(parent, player, pfaves, i, use_labels, label_mode)
    end

    return parent
  end

  fave_bar.build_favorite_buttons_row = build_favorite_buttons_row

  --- Build the full favorites bar frame and all slots.
  ---@param player LuaPlayer
  ---@param force_show boolean|nil
  ---@param deferred_slots boolean|nil
  function fave_bar.build(player, force_show, deferred_slots)
    if not BasicHelpers.is_valid_player(player) then return end

    if not force_show then
      if not BasicHelpers.is_planet_surface(player.surface) or BasicHelpers.is_restricted_controller(player) then
        _destroy_fave_bar(player)
        return
      end
    end

    local tick = game and game.tick or 0
    local prev_build_tick = last_build_tick[player.index]
    last_build_tick[player.index] = tick

    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    if not bar_frame or not bar_frame.valid then
      bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "vertical", "tf_fave_bar_frame")
    end
    if not force_show then
      if prev_build_tick == tick and bar_frame and bar_frame.valid then
        return
      end
    end

    local success, result = pcall(function()
      local player_settings = Cache.Settings.get_player_settings(player)
      local player_data = Cache.get_player_data(player)

      if not player_settings.favorites_on and not player_settings.enable_teleport_history then
        _destroy_fave_bar(player)
        return
      end

      if BasicHelpers.is_restricted_controller(player) then
        _destroy_fave_bar(player)
        return
      end

      local existing_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      local has_valid_structure = false
      if existing_frame and existing_frame.valid then
        local bar_flow = existing_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
        has_valid_structure = bar_flow and bar_flow.valid and GuiHelpers.count_direct_children(bar_flow) > 0
      end
      local needs_rebuild = not has_valid_structure
      if needs_rebuild then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end

      local fave_bar_frame
      if needs_rebuild then
        fave_bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "horizontal", "tf_fave_bar_frame")
      else
        fave_bar_frame = existing_frame
      end
      local _bar_flow, slots_frame, _toggle_button, _toggle_container, _history_toggle_button, _history_mode_toggle
      if needs_rebuild then
        _bar_flow, slots_frame, _toggle_button, _toggle_container, _history_toggle_button, _history_mode_toggle =
          fave_bar.build_quickbar_style(player, fave_bar_frame)
      else
        _bar_flow = fave_bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
        slots_frame = _bar_flow and _bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
        _toggle_container = _bar_flow and _bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
        _toggle_button = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON]
        _history_toggle_button = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON]
        _history_mode_toggle = _toggle_container and _toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON]
      end

      local favorites_enabled = player_settings.favorites_on
      local history_enabled = player_settings.enable_teleport_history

      if _history_toggle_button and _history_toggle_button.valid then
        _history_toggle_button.visible = history_enabled
      end
      if _history_mode_toggle and _history_mode_toggle.valid then
        _history_mode_toggle.visible = history_enabled
        local is_sequential = player_data.sequential_history_mode or false
        _history_mode_toggle.sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
        _history_mode_toggle.tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
      end

      if not favorites_enabled then
        if _toggle_button and _toggle_button.valid then _toggle_button.visible = false end
        if slots_frame and slots_frame.valid then slots_frame.visible = false end
      else
        local surface_index = player.surface.index
        local pfaves = Cache.get_player_favorites(player, surface_index)

        local recently_built = prev_build_tick ~= nil
          and tick >= prev_build_tick and (tick - prev_build_tick) < 3

        if not recently_built then
          prune_stale_favorites(player, surface_index, pfaves)
        end

        if _toggle_button and _toggle_button.valid then _toggle_button.visible = true end

        if slots_frame and slots_frame.valid then
          local slots_visible = player_data.fave_bar_slots_visible
          if slots_visible == nil then
            slots_visible = true
            player_data.fave_bar_slots_visible = true
          end
          slots_frame.visible = slots_visible
        end

        local slots_already_current = recently_built
          and slots_frame and slots_frame.valid and GuiHelpers.count_direct_children(slots_frame) > 0
        if not slots_already_current then
          if deferred_slots then
            storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
            cancel_progressive_build_for(player.index)
            clear_element_children(slots_frame)
            table.insert(storage._tf_slot_build_queue, {
              player_index   = player.index,
              surface_index  = player.surface.index,
              stage          = "slots",
              next_slot      = 1,
              expected_built = 0,
            })
          else
            cancel_progressive_build_for(player.index)
            local slots_updated = slots_frame and slots_frame.valid
              and GuiHelpers.count_direct_children(slots_frame) > 0
              and try_update_slots_in_place(slots_frame, player, pfaves)
            if not slots_updated then
              clear_element_children(slots_frame)
              fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)
            end
          end
        end

        local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
        if pfaves and #pfaves > max_slots then
          GuiElementBuilders.show_simple_error_label(fave_bar_frame, "tf-gui.fave_bar_overflow_error")
        end
      end

      return fave_bar_frame
    end)
    if not success then
      log("[TeleportFavorites][FAVE_BAR] build() pcall failed for player="
        .. tostring(player and player.name) .. " error=" .. tostring(result))
      ErrorHandler.warn_log("Favorites bar build failed", { player = player and player.name, error = result })
      return nil
    end
    return result
  end

  --- Refresh only the slot buttons if the bar exists, otherwise do a full build.
  ---@param player LuaPlayer
  function fave_bar.refresh_slots(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
    if bar_flow and bar_flow.valid and slots_frame and slots_frame.valid then
      if is_build_in_flight(player.index) then return end
      fave_bar.update_slot_row(player, bar_flow)
    elseif not is_build_in_flight(player.index) then
      fave_bar.build(player)
    end
  end

  --- Update only the slots row without rebuilding the entire bar.
  --- Attempts an in-place update first; falls back to clear+rebuild only when slot
  --- count or structure has changed (e.g. settings change or first build).
  ---@param player LuaPlayer
  ---@param parent_flow LuaGuiElement
  function fave_bar.update_slot_row(player, parent_flow)
    if not BasicHelpers.is_valid_player(player) then return end
    if not parent_flow or not parent_flow.valid then return end

    local slots_frame = parent_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
    if not slots_frame or not slots_frame.valid then return end

    local surface_index = player.surface.index
    local pfaves = Cache.get_player_favorites(player, surface_index)

    -- Fast path: update buttons in-place (no destroy/recreate).
    if try_update_slots_in_place(slots_frame, player, pfaves) then
      return slots_frame
    end

    -- Slow path: structure changed, clear and rebuild.
    clear_element_children(slots_frame)
    fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

    return slots_frame
  end

  --- Apply visuals for one slot when refs, pfaves, and label_mode are already resolved.
  ---@param slots_frame LuaGuiElement
  ---@param player LuaPlayer
  ---@param pfaves table
  ---@param label_mode string
  ---@param slot_index number
  local function apply_one_slot_at_index(slots_frame, player, pfaves, label_mode, slot_index)
    local wrapper = slots_frame["fave_bar_slot_wrapper_" .. slot_index]
    local slot_button
    if wrapper and wrapper.valid then
      slot_button = wrapper["fave_bar_slot_" .. slot_index]
    else
      slot_button = slots_frame["fave_bar_slot_" .. slot_index]
    end
    if not slot_button then return end

    local fav = pfaves[slot_index]
    local rehydrated_fav
    if fav then
      rehydrated_fav = PlayerFavorites.rehydrate_favorite_at_runtime(player, fav)
    end
    if not rehydrated_fav then
      rehydrated_fav = FavoriteUtils.get_blank_favorite()
    end

    apply_slot_visuals(slot_button, rehydrated_fav, slot_index)

    if wrapper and wrapper.valid then
      local slot_label = wrapper["fave_bar_slot_label_" .. slot_index]
      if slot_label and slot_label.valid then
        slot_label.caption = get_slot_label_text(rehydrated_fav, label_mode)
      end
    end
  end

  --- Update several slot buttons after one storage change (e.g. drag-drop): one GUI ref resolve and one settings read.
  ---@param player LuaPlayer
  ---@param indices uint[] 1-based slot indices
  function fave_bar.update_slots_batch(player, indices)
    if not BasicHelpers.is_valid_player(player) then return end
    if not indices or #indices == 0 then return end
    local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
    if not slots_frame or not slots_frame.valid then return end
    local surface_index = player.surface.index
    local pfaves = Cache.get_player_favorites(player, surface_index)
    if not pfaves then return end
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    for _, slot_index in ipairs(indices) do
      apply_one_slot_at_index(slots_frame, player, pfaves, label_mode, slot_index)
    end
  end

  --- Update a single slot button without rebuilding the entire row.
  ---@param player LuaPlayer
  ---@param slot_index number Slot index (1-based)
  function fave_bar.update_single_slot(player, slot_index)
    if not BasicHelpers.is_valid_player(player) then return end
    local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
    if not slots_frame or not slots_frame.valid then return end
    local surface_index = player.surface.index
    local pfaves = Cache.get_player_favorites(player, surface_index)
    if not pfaves then return end
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    apply_one_slot_at_index(slots_frame, player, pfaves, label_mode, slot_index)
  end

  --- Update toggle button visibility state.
  ---@param player LuaPlayer
  ---@param slots_visible boolean
  function fave_bar.update_toggle_state(player, slots_visible)
    if not BasicHelpers.is_valid_player(player) then return end
    if slots_visible == nil then slots_visible = true end

    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)

    if bar_flow and bar_flow.valid then
      local toggle_container = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
      if toggle_container and toggle_container.valid then
        local toggle_visibility_button = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON]
        if toggle_visibility_button and toggle_visibility_button.valid then
          toggle_visibility_button.sprite = slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE
        end
      end
    end

    if slots_frame then
      slots_frame.visible = slots_visible
    end
  end

  --- Update history mode button sprite, tooltip, and visibility without rebuilding the bar.
  --- Falls back to full build if chrome is missing or invalid.
  ---@param player LuaPlayer
  function fave_bar.update_history_mode_button(player)
    if not BasicHelpers.is_valid_player(player) then return end

    local _, _, bar_flow = get_fave_bar_gui_refs(player)
    if not bar_flow or not bar_flow.valid then
      fave_bar.build(player, true)
      return
    end
    local toggle_container = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
    if not toggle_container or not toggle_container.valid then
      fave_bar.build(player, true)
      return
    end
    local mode_btn = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON]
    if not mode_btn or not mode_btn.valid then
      fave_bar.build(player, true)
      return
    end

    local player_settings = Cache.Settings.get_player_settings(player)
    local history_enabled = player_settings.enable_teleport_history
    mode_btn.visible = history_enabled

    local is_sequential = Cache.get_sequential_history_mode(player)
    mode_btn.sprite = is_sequential and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE
    mode_btn.tooltip = is_sequential and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" }
  end

  -- Dirty-slot tracking for deferred partial rehydrates.
  -- Slots are marked dirty by DataObserver:update (on the notification tick) and
  -- flushed on the next on_nth_tick(2) by process_slot_build_queue, spreading the
  -- GUI write cost across ticks instead of spiking on the notification tick.
  local dirty_slots = {}

  -- Session-local flag: true when any player has dirty slots pending.
  -- Avoids iterating game.players in flush_all_dirty_slots when nothing is queued.
  -- Never stored in storage (session-local); always starts false after on_load.
  local _dirty_slots_has_work = false

  --- Mark a single slot as dirty for deferred rehydration.
  ---@param player LuaPlayer
  ---@param slot_index number
  function fave_bar.mark_slot_dirty(player, slot_index)
    if not BasicHelpers.is_valid_player(player) then return end
    if type(slot_index) ~= "number" then return end
    local pidx = player.index
    dirty_slots[pidx] = dirty_slots[pidx] or {}
    dirty_slots[pidx][slot_index] = true
    _dirty_slots_has_work = true
  end

  --- Partially rehydrate any dirty slots for a single player and clear their dirty set.
  --- Called directly when an immediate update is required (e.g. slot-row rebuild path).
  ---@param player LuaPlayer
  function fave_bar.partial_rehydrate(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local pidx = player.index
    local set = dirty_slots[pidx]
    if not set then return end
    local slot_indices = {}
    for slot_index, _ in pairs(set) do
      slot_indices[#slot_indices + 1] = slot_index
    end
    table.sort(slot_indices, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for si = 1, #slot_indices do
      local slot_index = slot_indices[si]
      local ok, err = pcall(function()
        fave_bar.update_single_slot(player, slot_index)
      end)
      if not ok then
        if ErrorHandler and ErrorHandler.warn_log then
          ErrorHandler.warn_log("[FAVE_BAR] partial_rehydrate failed", { player = player.name, slot = slot_index, error = err })
        end
      end
    end
    dirty_slots[pidx] = nil
    -- Re-check flag: leave true if other players still have dirty work.
    if next(dirty_slots) == nil then
      _dirty_slots_has_work = false
    end
  end

  --- Flush all pending dirty slots for every player with queued work.
  --- Called from process_slot_build_queue (on_nth_tick(2)) to spread GUI write cost
  --- across ticks rather than spiking on the notification tick.
  function fave_bar.flush_all_dirty_slots()
    -- Do not trust _dirty_slots_has_work alone — same failure mode as the slot build queue:
    -- always derive from `dirty_slots` so peers never skip a flush while work exists.
    if not next(dirty_slots) then
      _dirty_slots_has_work = false
      return
    end
    _dirty_slots_has_work = true
    local pidx_list = {}
    for pidx in pairs(dirty_slots) do
      pidx_list[#pidx_list + 1] = pidx
    end
    table.sort(pidx_list, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for pi = 1, #pidx_list do
      local pidx = pidx_list[pi]
      local set = dirty_slots[pidx]
      if set then
        local player = game.players[pidx]
        if player and player.valid then
          local slot_indices = {}
          for slot_index, _ in pairs(set) do
            slot_indices[#slot_indices + 1] = slot_index
          end
          table.sort(slot_indices, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
          for si = 1, #slot_indices do
            local slot_index = slot_indices[si]
            local ok, err = pcall(function()
              fave_bar.update_single_slot(player, slot_index)
            end)
            if not ok then
              if ErrorHandler and ErrorHandler.warn_log then
                ErrorHandler.warn_log("[FAVE_BAR] flush_all_dirty_slots failed", { player = player.name, slot = slot_index, error = err })
              end
            end
          end
        end
        dirty_slots[pidx] = nil
      end
    end
    _dirty_slots_has_work = false
  end
end
