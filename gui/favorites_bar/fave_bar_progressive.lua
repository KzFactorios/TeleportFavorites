---@diagnostic disable: undefined-global

-- gui/favorites_bar/fave_bar_progressive.lua
-- Progressive startup bar builder extracted from fave_bar.lua.
-- Extend pattern: receives (fave_bar, helpers) where helpers contains shared private functions.
--
-- Stages in storage._tf_slot_build_queue:
--   chrome1        → build bar_flow + toggle_container (1 tick)
--   chrome2        → build 3 toggle buttons + slots frame (1 tick)
--   blank_slots    → add empty slot GUI elements BLANK_BATCH_SIZE per tick
--   hydrate_slots  → write data into blank slots HYDRATE_BATCH_SIZE per tick
--   slots          → legacy stage kept for old save files

local Deps = require("deps")
local BasicHelpers, ErrorHandler, Cache, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiHelpers = require("core.utils.gui_helpers")
local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local ProfilerExport = require("core.utils.profiler_export")

local BLANK_BATCH_SIZE   = 5
local HYDRATE_BATCH_SIZE = 5

return function(fave_bar, helpers)
  local cancel_progressive_build_for = helpers.cancel_progressive_build_for
  local last_build_tick               = helpers.last_build_tick
  local create_toggle_chrome          = helpers.create_toggle_chrome
  local prune_stale_favorites         = helpers.prune_stale_favorites
  local get_fave_bar_gui_refs         = helpers.get_fave_bar_gui_refs
  local get_slot_btn_props            = helpers.get_slot_btn_props
  local get_slot_label_text           = helpers.get_slot_label_text
  local build_single_slot             = helpers.build_single_slot
  local is_build_in_flight            = helpers.is_build_in_flight

  --- Ensure the bar_frame exists, init the build queue, cancel any in-flight build.
  --- Returns bar_frame on success or nil if setup failed.
  ---@param player LuaPlayer
  ---@return LuaGuiElement|nil
  local function prepare_bar_frame_and_queue(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow then return nil end
    local bar_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    if not bar_frame or not bar_frame.valid then
      bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "vertical", "tf_fave_bar_frame")
    end
    if not bar_frame or not bar_frame.valid then return nil end
    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    cancel_progressive_build_for(player.index)
    return bar_frame
  end

  --- Resolve main_flow → bar_frame → bar_flow → slots_frame for a player.
  ---@param player LuaPlayer
  ---@return LuaGuiElement|nil slots_frame
  local function get_bar_slots_frame(player)
    local main_flow   = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame   = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    local bar_flow    = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
    return bar_flow  and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  end

  --- Called from process_deferred_init_queue (tick 60+).
  --- Creates the empty outer frame and enqueues chrome + slots stages.
  ---@param player LuaPlayer
  function fave_bar.enqueue_progressive_build(player)
    if not BasicHelpers.is_valid_player(player) then return end
    if not prepare_bar_frame_and_queue(player) then return end

    table.insert(storage._tf_slot_build_queue, {
      player_index  = player.index,
      surface_index = player.surface.index,
      stage         = "chrome1",
    })
    last_build_tick[player.index] = game.tick
  end

  --- Called from on_player_joined_game / on_player_created (tick 0).
  --- Builds the blank bar structure immediately so slots are visible by tick ~4,
  --- then stops. Hydration is enqueued later by enqueue_hydrate().
  ---@param player LuaPlayer
  function fave_bar.enqueue_blank_bar(player)
    if not BasicHelpers.is_valid_player(player) then return end
    if BasicHelpers.is_restricted_controller(player) then return end
    if not prepare_bar_frame_and_queue(player) then return end

    table.insert(storage._tf_slot_build_queue, {
      player_index     = player.index,
      surface_index    = player.surface.index,
      stage            = "chrome1",
      stop_after_blank = true,
    })
    last_build_tick[player.index] = game.tick
  end

  --- Returns true when the blank bar is fully built and no build is in flight.
  ---@param player LuaPlayer
  ---@return boolean
  function fave_bar.blank_bar_is_ready(player)
    if not BasicHelpers.is_valid_player(player) then return false end
    if is_build_in_flight(player.index) then return false end
    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
    if not bar_flow or not bar_flow.valid then return false end
    if not slots_frame or not slots_frame.valid then return false end
    local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 30
    return #slots_frame.children >= max_slots
  end

  --- Enqueues only the hydrate_slots stage for a player whose blank bar is already built.
  ---@param player LuaPlayer
  function fave_bar.enqueue_hydrate(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or 30
    local label_mode = Cache.Settings.get_player_slot_label_mode(player)
    local use_labels = label_mode ~= "off"

    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    cancel_progressive_build_for(player.index)

    table.insert(storage._tf_slot_build_queue, {
      player_index  = player.index,
      surface_index = player.surface.index,
      stage         = "hydrate_slots",
      next_slot     = 1,
      max_slots     = max_slots,
      use_labels    = use_labels,
      label_mode    = label_mode,
    })
    last_build_tick[player.index] = game.tick
  end

  --- Called on every on_nth_tick(2); processes one queue stage per call.
  function fave_bar.process_slot_build_queue()
    -- Skip tick 0: on_nth_tick(2) fires at tick 0 (0 % 2 == 0).
    if game.tick < 2 then return end
    if not storage or not storage._tf_slot_build_queue then return end
    if #storage._tf_slot_build_queue == 0 then return end

    local entry  = storage._tf_slot_build_queue[1]
    local player = game.players[entry.player_index]
    if not player or not player.valid then
      table.remove(storage._tf_slot_build_queue, 1)
      return
    end

    -- ── Chrome stage 1: bar_flow + toggle_container (~2 GUI adds ≈ 1.7 ms) ──────
    if entry.stage == "chrome1" then
      ProfilerExport.start_section("pb_chrome1")
      local player_settings = Cache.Settings.get_player_settings(player)
      if not player_settings.favorites_on and not player_settings.enable_teleport_history then
        ProfilerExport.stop_section("pb_chrome1")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      if BasicHelpers.is_restricted_controller(player) then
        ProfilerExport.stop_section("pb_chrome1")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      if not bar_frame or not bar_frame.valid then
        ProfilerExport.stop_section("pb_chrome1")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      local existing_flow = bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      if existing_flow and existing_flow.valid then existing_flow.destroy() end

      GuiBase.create_hflow(bar_frame, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)
      local bar_flow = bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      if bar_flow and bar_flow.valid then
        GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER,
          "horizontal", "tf_fave_toggle_container")
      end

      ProfilerExport.stop_section("pb_chrome1")
      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "chrome2",
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end

    -- ── Chrome stage 2: 3 buttons + slots frame (~4 adds ≈ 3.5 ms) ─────────────
    if entry.stage == "chrome2" then
      ProfilerExport.start_section("pb_chrome2")
      local player_settings = Cache.Settings.get_player_settings(player)
      local main_flow  = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      local bar_frame  = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      local bar_flow   = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      local tog_cont   = bar_flow  and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
      if not bar_frame or not bar_frame.valid or not bar_flow or not tog_cont then
        ProfilerExport.stop_section("pb_chrome2")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      local history_enabled = player_settings.enable_teleport_history
      local slots_frame, _toggle_btn, _hist_btn, _mode_btn = create_toggle_chrome(tog_cont, bar_flow, player)
      if _hist_btn  and _hist_btn.valid  then _hist_btn.visible  = history_enabled end
      if _mode_btn  and _mode_btn.valid  then _mode_btn.visible  = history_enabled end
      if _toggle_btn and _toggle_btn.valid then _toggle_btn.visible = true end

      local player_data = Cache.get_player_data(player)
      local slots_vis   = player_data and player_data.fave_bar_slots_visible
      if slots_vis == nil then slots_vis = true end
      if slots_frame and slots_frame.valid then slots_frame.visible = slots_vis end

      local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or 30
      local label_mode = Cache.Settings.get_player_slot_label_mode(player)
      local use_labels = label_mode ~= "off"

      ProfilerExport.stop_section("pb_chrome2")
      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "blank_slots",
        next_slot        = 1,
        expected_blank   = 0,
        max_slots        = max_slots,
        use_labels       = use_labels,
        label_mode       = label_mode,
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end

    -- ── Legacy chrome stage (queue entries created before the chrome split) ──────
    if entry.stage == "chrome" then
      storage._tf_slot_build_queue[1] = {
        player_index  = entry.player_index,
        surface_index = entry.surface_index,
        stage         = "chrome1",
      }
      return
    end

    -- ── Blank slots stage: create empty GUI structure, no data lookups ───────────
    if entry.stage == "blank_slots" then
      ProfilerExport.start_section("pb_blank")
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        ProfilerExport.stop_section("pb_blank")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      -- Labels mode adds 4 GUI elements per slot (flow+button+child-label+slot-label)
      -- vs 2 without labels. Halve the batch when labels are on to keep per-tick
      -- GUI work roughly constant and avoid >10 ms blank-build spikes.
      local batch_size = entry.use_labels and 3 or BLANK_BATCH_SIZE
      local start_idx  = entry.next_slot
      local end_idx    = math.min(start_idx + batch_size - 1, entry.max_slots)

      for i = start_idx, end_idx do
        local btn_parent = slots_frame
        if entry.use_labels then
          btn_parent = slots_frame.add {
            type      = "flow",
            name      = "fave_bar_slot_wrapper_" .. i,
            direction = "vertical",
            style     = "tf_fave_bar_slot_wrapper",
          }
        end
        local btn = btn_parent.add {
          type    = "sprite-button",
          name    = "fave_bar_slot_" .. i,
          sprite  = "",
          style   = "tf_slot_button_smallfont",
          tooltip = { "tf-gui.favorite_slot_empty" },
        }
        btn.add { type = "label", name = "n", caption = tostring(i), style = "tf_fave_bar_slot_number" }
        if entry.use_labels then
          btn_parent.add {
            type    = "label",
            name    = "fave_bar_slot_label_" .. i,
            caption = "",
            style   = "tf_fave_bar_slot_label",
          }
        end
      end

      ProfilerExport.stop_section("pb_blank")

      if end_idx >= entry.max_slots then
        if entry.stop_after_blank then
          table.remove(storage._tf_slot_build_queue, 1)
          last_build_tick[entry.player_index] = game.tick
        else
          storage._tf_slot_build_queue[1] = {
            player_index  = entry.player_index,
            surface_index = entry.surface_index,
            stage         = "hydrate_slots",
            next_slot     = 1,
            max_slots     = entry.max_slots,
            use_labels    = entry.use_labels,
            label_mode    = entry.label_mode,
          }
        end
      else
        entry.next_slot      = end_idx + 1
        entry.expected_blank = end_idx
      end
      return
    end

    -- ── Hydrate slots stage: fill existing blank buttons with data ───────────────
    if entry.stage == "hydrate_slots" then
      ProfilerExport.start_section("pb_hydrate")
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        ProfilerExport.stop_section("pb_hydrate")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      -- Prune stale GPS favorites on the first hydrate batch.
      if entry.next_slot == 1 then
        local pfaves_pre = Cache.get_player_favorites(player, entry.surface_index)
        prune_stale_favorites(player, entry.surface_index, pfaves_pre)
      end

      local pfaves    = Cache.get_player_favorites(player, entry.surface_index)
      local start_idx = entry.next_slot
      local end_idx   = math.min(start_idx + HYDRATE_BATCH_SIZE - 1, entry.max_slots)

      for i = start_idx, end_idx do
        local child = slots_frame.children[i]
        if not child or not child.valid then goto next_hydrate end

        local btn = entry.use_labels and child["fave_bar_slot_" .. i] or child
        if not btn or not btn.valid then goto next_hydrate end

        local fav_raw = pfaves and pfaves[i]
        if fav_raw and not FavoriteUtils.is_blank_favorite(fav_raw) then
          local fav = PlayerFavorites.rehydrate_favorite_at_runtime(player, fav_raw)
                      or FavoriteUtils.get_blank_favorite()
          local icon, tooltip, style = get_slot_btn_props(i, fav)
          btn.sprite  = icon or ""
          btn.tooltip = tooltip
          -- Blank buttons are built with "tf_slot_button_smallfont"; skip the
          -- style write for the common case (non-locked, non-pin) to avoid
          -- Factorio's style-recalculation cost on every hydrated slot.
          if style ~= "tf_slot_button_smallfont" then
            btn.style = style
          end
          if entry.use_labels then
            local lbl = child["fave_bar_slot_label_" .. i]
            if lbl and lbl.valid then
              lbl.caption = get_slot_label_text(fav, entry.label_mode)
            end
          end
        end
        ::next_hydrate::
      end

      ProfilerExport.stop_section("pb_hydrate")

      if end_idx >= entry.max_slots then
        table.remove(storage._tf_slot_build_queue, 1)
        last_build_tick[entry.player_index] = game.tick
      else
        entry.next_slot = end_idx + 1
      end
      return
    end

    -- ── Legacy slots stage (saves created before blank/hydrate split) ─────────
    if entry.stage == "slots" then
      ProfilerExport.start_section("pb_slots")
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        ProfilerExport.stop_section("pb_slots")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      if #slots_frame.children ~= entry.expected_built then
        ProfilerExport.stop_section("pb_slots")
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end

      local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or 30
      local pfaves     = Cache.get_player_favorites(player, entry.surface_index)
      local label_mode = Cache.Settings.get_player_slot_label_mode(player)
      local use_labels = label_mode ~= "off"
      local start_idx  = entry.next_slot
      local end_idx    = math.min(start_idx + 2 - 1, max_slots)

      for i = start_idx, end_idx do
        build_single_slot(slots_frame, player, pfaves, i, use_labels, label_mode)
      end

      ProfilerExport.stop_section("pb_slots")

      if end_idx >= max_slots then
        table.remove(storage._tf_slot_build_queue, 1)
        last_build_tick[entry.player_index] = game.tick
      else
        entry.next_slot      = end_idx + 1
        entry.expected_built = end_idx
      end
    end
  end

  --- Clear the build queue on save-load (stale GUI references, fresh state needed).
  function fave_bar.on_load_cleanup()
    if storage then
      storage._tf_slot_build_queue = {}
    end
  end
end
