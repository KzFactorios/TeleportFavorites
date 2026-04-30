---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- gui/favorites_bar/fave_bar_slots.lua
-- Slot building, updating, and refresh functions extracted from fave_bar.lua.
-- Extend pattern: receives (fave_bar, helpers) where helpers contains shared private functions.

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Enum, Constants =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum, Deps.Constants
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
return function(fave_bar, helpers)
  local function max_favorite_slots_for(player)
    return Cache.Settings.get_player_max_favorite_slots(player)
      or math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
  end

  local is_build_in_flight        = helpers.is_build_in_flight
  local get_fave_bar_gui_refs     = helpers.get_fave_bar_gui_refs
  local get_slot_label_text       = helpers.get_slot_label_text
  local get_slot_btn_props        = helpers.get_slot_btn_props
  local build_single_slot         = helpers.build_single_slot
  local cancel_progressive_build_for = helpers.cancel_progressive_build_for
  local prune_stale_favorites     = helpers.prune_stale_favorites
  local last_build_tick           = helpers.last_build_tick
  local _destroy_fave_bar         = helpers._destroy_fave_bar
  local clear_session_gui_refs    = helpers.clear_session_gui_refs

  --- Invariant: child label `n` is always the fixed slot index (1..max_slots), never tied to
  --- favorite "identity order" after reorder or chart-tag moves. Only sprite, tooltip, and
  --- optional text labels reflect favorite/tag content.
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
    local n_el = btn["n"]
    if not n_el or not n_el.valid then
      n_el = btn.add {
        type    = "label",
        name    = "n",
        caption = tostring(slot_index),
        style   = "tf_fave_bar_slot_number",
      }
    end
    if n_el and n_el.valid then
      n_el.caption = tostring(slot_index)
    end
  end

  local function clear_element_children(el)
    GuiHelpers.peel_destroy_all_children(el)
  end

  --- Peel twice if anything remains (defensive against LuaCustomTable edge cases).
  local function clear_slots_row_children(slots_frame)
    if not slots_frame or not slots_frame.valid then return end
    clear_element_children(slots_frame)
    if GuiHelpers.count_direct_children(slots_frame) > 0 then
      log("[TeleportFavorites][FAVE_BAR] clear_slots_row_children: second peel pass")
      clear_element_children(slots_frame)
    end
  end

  local function resolve_slots_frame_from_bar(fave_bar_frame)
    if not fave_bar_frame or not fave_bar_frame.valid then return nil end
    local bf = fave_bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
    if not bf or not bf.valid then return nil end
    local sf = bf[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
    if sf and sf.valid then return sf end
    return nil
  end

  local function is_duplicate_name_gui_err(msg)
    local s = type(msg) == "string" and msg or tostring(msg)
    return s:find("already present", 1, true) ~= nil or s:find("already exists", 1, true) ~= nil
  end

  ---@param player LuaPlayer
  ---@param fave_bar_frame LuaGuiElement
  ---@param add_fn fun(slots_frame: LuaGuiElement)
  local function run_slot_creation_with_retry(player, fave_bar_frame, add_fn)
    local sf = resolve_slots_frame_from_bar(fave_bar_frame)
    if not sf then return false end
    local ok, err = pcall(add_fn, sf)
    if ok then return true end
    if not is_duplicate_name_gui_err(err) then
      error(err)
    end
    ErrorHandler.warn_log("[FAVE_BAR] duplicate slot name on add; clearing refs and row, retrying once", {
      player = player and player.name,
      tick = game and game.tick or 0,
      err = tostring(err),
    })
    clear_session_gui_refs(player.index)
    sf = resolve_slots_frame_from_bar(fave_bar_frame)
    if not sf or not sf.valid then error(err) end
    clear_slots_row_children(sf)
    ok, err = pcall(add_fn, sf)
    if not ok then error(err) end
    return true
  end

  --- Attempt to update all slot buttons in place (no destroy/recreate).
  --- Returns true on success; false means structure changed and a full rebuild is needed.
  local function try_update_slots_in_place(slots_frame, player, pfaves)
    local max_slots = max_favorite_slots_for(player)
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    local use_labels = label_mode ~= "off"
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
      local child = use_labels and slots_frame["fave_bar_slot_wrapper_" .. i]
        or slots_frame["fave_bar_slot_" .. i]
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

      local n_el = btn["n"]
      if not n_el or not n_el.valid then
        btn.add {
          type    = "label",
          name    = "n",
          caption = tostring(i),
          style   = "tf_fave_bar_slot_number",
        }
      end

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

    local max_slots = max_favorite_slots_for(player)
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
        clear_session_gui_refs(player.index)
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

      -- Always cancel any in-flight progressive build when a synchronous build runs.
      -- This prevents a lingering frame_init entry from running chrome1 (which destroys
      -- FAVE_BAR_FLOW) after the sync build has already populated the bar, leaving an
      -- invisible empty frame. Must run regardless of recently_built or slots_already_current.
      cancel_progressive_build_for(player.index)

      if not favorites_enabled then
        if _toggle_button and _toggle_button.valid then _toggle_button.visible = false end
        if slots_frame and slots_frame.valid then slots_frame.visible = false end
      else
        local surface_index = player.surface.index
        local pfaves = Cache.get_player_favorites(player, surface_index)
        local max_slots = max_favorite_slots_for(player)
        local label_mode = Cache.Settings.get_player_slot_label_mode(player)
        local use_labels = label_mode ~= "off"

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

        -- Layer 1 + 5: always try in-place refresh first (fixed 1..N labels + storage-backed visuals).
        -- Never skip all slot work after cancel_progressive_build_for — that left stale `n` and icons.
        slots_frame = resolve_slots_frame_from_bar(fave_bar_frame) or slots_frame
        local in_place_ok = false
        if slots_frame and slots_frame.valid then
          in_place_ok = try_update_slots_in_place(slots_frame, player, pfaves)
        end

        if in_place_ok and deferred_slots then
          -- Row already matches storage; skip blank/hydrate queue (avoids duplicate-name + wasted ticks).
        elseif not in_place_ok then
          if deferred_slots then
            storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
            clear_session_gui_refs(player.index)
            slots_frame = resolve_slots_frame_from_bar(fave_bar_frame)
            if not slots_frame or not slots_frame.valid then
              ErrorHandler.warn_log("[FAVE_BAR] deferred build: slots_frame missing after ref resolve", {
                player = player.name,
              })
            else
              clear_slots_row_children(slots_frame)
              local build_blanks = helpers.build_blank_slot_range
              local cap = math.floor(tonumber(Constants.settings.FAVE_BAR_SYNC_BLANK_BUILD_CAP) or 22)
              local tail_batch_max = math.floor(tonumber(Constants.settings.FAVE_BAR_TAIL_BLANK_BATCH_MAX) or 10)
              if use_labels then
                cap = math.min(cap, 14)
              end
              local n_first = math.min(cap, max_slots)
              if build_blanks then
                run_slot_creation_with_retry(player, fave_bar_frame, function(sf)
                  build_blanks(sf, 1, n_first, use_labels)
                end)
              end
              if max_slots > n_first then
                local remaining = max_slots - n_first
                table.insert(storage._tf_slot_build_queue, {
                  player_index         = player.index,
                  surface_index        = player.surface.index,
                  stage                = "blank_slots",
                  next_slot            = n_first + 1,
                  expected_blank       = n_first,
                  max_slots            = max_slots,
                  use_labels           = use_labels,
                  label_mode           = label_mode,
                  stop_after_blank     = false,
                  blank_batch_override = math.min(tail_batch_max, remaining),
                })
              else
                table.insert(storage._tf_slot_build_queue, {
                  player_index  = player.index,
                  surface_index = player.surface.index,
                  stage         = "hydrate_slots",
                  next_slot     = 1,
                  max_slots     = max_slots,
                  use_labels    = use_labels,
                  label_mode    = label_mode,
                })
              end
            end
          else
            clear_session_gui_refs(player.index)
            slots_frame = resolve_slots_frame_from_bar(fave_bar_frame)
            if slots_frame and slots_frame.valid then
              clear_slots_row_children(slots_frame)
              run_slot_creation_with_retry(player, fave_bar_frame, function(sf)
                fave_bar.build_favorite_buttons_row(sf, player, pfaves)
              end)
            end
          end
        end

        if pfaves and #pfaves > max_slots then
          GuiElementBuilders.show_simple_error_label(fave_bar_frame, "tf-gui.fave_bar_overflow_error")
        end
      end

      fave_bar_frame.visible = true
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
      fave_bar.build(player, true, true)
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
    local bar_root = parent_flow.parent
    clear_slots_row_children(slots_frame)
    if bar_root and bar_root.valid then
      run_slot_creation_with_retry(player, bar_root, function(sf)
        fave_bar.build_favorite_buttons_row(sf, player, pfaves)
      end)
    else
      fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)
    end

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
      fave_bar.build(player, true, true)
      return
    end
    local toggle_container = bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
    if not toggle_container or not toggle_container.valid then
      fave_bar.build(player, true, true)
      return
    end
    local mode_btn = toggle_container[Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON]
    if not mode_btn or not mode_btn.valid then
      fave_bar.build(player, true, true)
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

  --- Flush pending dirty slots (bounded per tick) for deterministic MP ordering.
  --- Called from process_slot_build_queue (on_nth_tick(2)) to spread GUI write cost
  --- across ticks rather than spiking on the notification tick.
  function fave_bar.flush_all_dirty_slots()
    -- Do not trust _dirty_slots_has_work alone — same failure mode as the slot build queue:
    -- always derive from `dirty_slots` so peers never skip a flush while work exists.
    if not next(dirty_slots) then
      _dirty_slots_has_work = false
      return
    end
    local budget = math.max(1, math.floor(tonumber(Constants.settings.FAVE_BAR_DIRTY_SLOT_FLUSH_BUDGET) or 48))
    local pending = {}
    for pidx, set in pairs(dirty_slots) do
      for slot_index in pairs(set) do
        pending[#pending + 1] = { tonumber(pidx) or 0, tonumber(slot_index) or 0 }
      end
    end
    if #pending == 0 then
      _dirty_slots_has_work = false
      return
    end
    table.sort(pending, function(a, b)
      if a[1] ~= b[1] then return a[1] < b[1] end
      return a[2] < b[2]
    end)
    for i = 1, #pending do
      if budget <= 0 then break end
      local pidx, slot_index = pending[i][1], pending[i][2]
      local set = dirty_slots[pidx]
      if set and set[slot_index] then
        local player = game.players[pidx]
        if player and player.valid then
          local ok, err = pcall(function()
            fave_bar.update_single_slot(player, slot_index)
          end)
          if not ok then
            if ErrorHandler and ErrorHandler.warn_log then
              ErrorHandler.warn_log("[FAVE_BAR] flush_all_dirty_slots failed", { player = player.name, slot = slot_index, error = err })
            end
          end
        end
        set[slot_index] = nil
        if next(set) == nil then
          dirty_slots[pidx] = nil
        end
        budget = budget - 1
      end
    end
    _dirty_slots_has_work = next(dirty_slots) ~= nil
  end
end
