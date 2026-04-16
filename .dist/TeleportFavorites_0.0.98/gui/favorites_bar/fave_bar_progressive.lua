local Deps                                    = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Enum =
    Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum
local GuiBase                                 = require("gui.gui_base")
local GuiHelpers                              = require("core.utils.gui_helpers")
local FavoriteUtils                           = require("core.favorite.favorite_utils")
local PlayerFavorites                         = require("core.favorite.player_favorites")
local BLANK_BATCH_SIZE                        = 3
local HYDRATE_BATCH_SIZE                      = 5
return function(fave_bar, helpers)
  local cancel_progressive_build_for = helpers.cancel_progressive_build_for
  local last_build_tick              = helpers.last_build_tick
  local create_toggle_chrome         = helpers.create_toggle_chrome
  local prune_stale_favorites        = helpers.prune_stale_favorites
  local get_fave_bar_gui_refs        = helpers.get_fave_bar_gui_refs
  local get_slot_btn_props           = helpers.get_slot_btn_props
  local get_slot_label_text          = helpers.get_slot_label_text
  local build_single_slot            = helpers.build_single_slot
  local is_build_in_flight           = helpers.is_build_in_flight
  local GuiElementBuilders           = helpers.GuiElementBuilders
  local _fave_bar_queue_has_work = false
  local function prepare_queue_only(player)
    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    cancel_progressive_build_for(player.index)
    return true
  end
  local function get_bar_frame(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    return main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  end
  local function get_bar_slots_frame(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    local bar_flow  = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
    return bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  end
  function fave_bar.enqueue_progressive_build(player)
    if not BasicHelpers.is_valid_player(player) then return end
    prepare_queue_only(player)
    table.insert(storage._tf_slot_build_queue, {
      player_index  = player.index,
      surface_index = player.surface.index,
      stage         = "frame_init",
    })
    last_build_tick[player.index] = game.tick
    _fave_bar_queue_has_work = true
  end
  function fave_bar.enqueue_blank_bar(player, enqueue_reason)
    local reason = enqueue_reason or "unknown"
    if not BasicHelpers.is_valid_player(player) then
      ErrorHandler.warn_log("[TF_MP][enqueue_blank_bar] skip invalid_player", { reason = reason, tick = game.tick })
      return
    end
    if BasicHelpers.is_restricted_controller(player) then
      ErrorHandler.warn_log("[TF_MP][enqueue_blank_bar] skip restricted_controller", {
        reason = reason, tick = game.tick, player_index = player.index, player_name = player.name,
      })
      return
    end
    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    local qlen_before = #storage._tf_slot_build_queue
    prepare_queue_only(player)
    table.insert(storage._tf_slot_build_queue, {
      player_index     = player.index,
      surface_index    = player.surface.index,
      stage            = "frame_init",
      stop_after_blank = true,
    })
    last_build_tick[player.index] = game.tick
    _fave_bar_queue_has_work = true
    ErrorHandler.warn_log("[TF_MP][enqueue_blank_bar] enqueued frame_init (stop_after_blank)", {
      reason          = reason,
      tick            = game.tick,
      player_index    = player.index,
      player_name     = player.name,
      qlen_before     = qlen_before,
      qlen_after      = #storage._tf_slot_build_queue,
      surface_index   = player.surface.index,
    })
  end
  function fave_bar.blank_bar_is_ready(player)
    if not BasicHelpers.is_valid_player(player) then return false end
    if is_build_in_flight(player.index) then return false end
    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
    if not bar_flow or not bar_flow.valid then return false end
    if not slots_frame or not slots_frame.valid then return false end
    local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 30
    return GuiHelpers.count_direct_children(slots_frame) >= max_slots
  end
  function fave_bar.enqueue_hydrate(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local max_slots              = Cache.Settings.get_player_max_favorite_slots(player) or 30
    local label_mode             = Cache.Settings.get_player_slot_label_mode(player)
    local use_labels             = label_mode ~= "off"
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
    _fave_bar_queue_has_work = true
  end
  function fave_bar.process_slot_build_queue()
    if game.tick < 2 then return end
    if not storage or not storage._tf_slot_build_queue or #storage._tf_slot_build_queue == 0 then
      _fave_bar_queue_has_work = false
      return
    end
    _fave_bar_queue_has_work = true
    local entry  = storage._tf_slot_build_queue[1]
    if entry and entry.stage == nil and type(entry.next_slot) == "number" and type(entry.expected_built) == "number" then
      entry.stage = "slots"
    end
    local player = game.players[entry.player_index]
    if not player or not player.valid then
      table.remove(storage._tf_slot_build_queue, 1)
      return
    end
    if entry.stage == "frame_init" then
      local player_settings = Cache.Settings.get_player_settings(player)
      if not player_settings.favorites_on and not player_settings.enable_teleport_history then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      if BasicHelpers.is_restricted_controller(player) then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      if not main_flow then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      local bar_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      if not bar_frame or not bar_frame.valid then
        bar_frame = GuiBase.create_element("frame", main_flow, {
          name      = Enum.GuiEnum.GUI_FRAME.FAVE_BAR,
          direction = "vertical",
          style     = "tf_fave_bar_frame",
          index     = 1,
          visible   = false,
        })
      end
      if not bar_frame or not bar_frame.valid then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "chrome1",
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end
    if entry.stage == "chrome1" then
      local bar_frame = get_bar_frame(player)
      if not bar_frame or not bar_frame.valid then
        ErrorHandler.warn_log("[TF_MP][chrome1] bar_frame missing, aborting build", {
          player_index = entry.player_index, tick = game.tick,
        })
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
      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "chrome2a",
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end
    if entry.stage == "chrome2" or entry.stage == "chrome2a" then
      local player_settings = Cache.Settings.get_player_settings(player)
      local main_flow       = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      local bar_frame       = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      local bar_flow        = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      local tog_cont        = bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
      if not bar_frame or not bar_frame.valid or not bar_flow or not tog_cont then
        ErrorHandler.warn_log("[TF_MP][chrome2a] chrome structure missing, aborting build", {
          player_index = entry.player_index, tick = game.tick,
          bar_frame_valid = bar_frame and bar_frame.valid or false,
          bar_flow_valid  = bar_flow  and bar_flow.valid  or false,
          tog_cont_valid  = tog_cont  and tog_cont.valid  or false,
        })
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      local history_enabled = player_settings.enable_teleport_history
      local player_data     = Cache.get_player_data(player)
      local is_seq          = player_data and (player_data.sequential_history_mode or false) or false
      local hist_btn = GuiBase.create_sprite_button(tog_cont,
        Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_TOGGLE_BUTTON,
        Enum.SpriteEnum.SCROLL_HISTORY,
        { "tf-gui.teleport_history_tooltip" },
        "tf_fave_history_toggle_button")
      local mode_btn = GuiBase.create_sprite_button(tog_cont,
        Enum.GuiEnum.FAVE_BAR_ELEMENT.HISTORY_MODE_TOGGLE_BUTTON,
        is_seq and Enum.SpriteEnum.SEQUENTIAL_HISTORY_MODE or Enum.SpriteEnum.STD_HISTORY_MODE,
        is_seq and { "tf-gui.history_mode_sequential_tooltip" } or { "tf-gui.history_mode_std_tooltip" },
        "tf_fave_history_toggle_button")
      if hist_btn and hist_btn.valid then hist_btn.visible = history_enabled end
      if mode_btn and mode_btn.valid then mode_btn.visible = history_enabled end
      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "chrome2b",
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end
    if entry.stage == "chrome2b" then
      local main_flow   = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
      local bar_frame   = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
      local bar_flow    = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
      local tog_cont    = bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER]
      if not bar_frame or not bar_frame.valid or not bar_flow or not tog_cont then
        ErrorHandler.warn_log("[TF_MP][chrome2b] chrome structure missing, aborting build", {
          player_index = entry.player_index, tick = game.tick,
          bar_frame_valid = bar_frame and bar_frame.valid or false,
          bar_flow_valid  = bar_flow  and bar_flow.valid  or false,
          tog_cont_valid  = tog_cont  and tog_cont.valid  or false,
        })
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      local player_data = Cache.get_player_data(player)
      local slots_vis   = player_data and player_data.fave_bar_slots_visible
      if slots_vis == nil then
        slots_vis = true
        if player_data then player_data.fave_bar_slots_visible = true end
      end
      local toggle_btn = GuiElementBuilders.create_visibility_toggle_button(
        tog_cont, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON, slots_vis,
        { "tf-gui.toggle_fave_bar" })
      local slots_frame = GuiBase.create_frame(bar_flow,
        Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW, "horizontal", "tf_fave_slots_row")
      if toggle_btn  and toggle_btn.valid  then toggle_btn.visible  = true     end
      if slots_frame and slots_frame.valid then slots_frame.visible = slots_vis end
      local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or 30
      local label_mode = Cache.Settings.get_player_slot_label_mode(player)
      local use_labels = label_mode ~= "off"
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
    if entry.stage == "chrome" then
      storage._tf_slot_build_queue[1] = {
        player_index  = entry.player_index,
        surface_index = entry.surface_index,
        stage         = "frame_init",
      }
      return
    end
    if entry.stage == "blank_slots" then
      local slots_frame = get_bar_slots_frame(player)
      if not slots_frame or not slots_frame.valid then
        ErrorHandler.warn_log("[TF_MP][blank_slots] slots_frame missing, aborting build", {
          tick         = game.tick,
          player_index = entry.player_index,
        })
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      local batch_size = entry.use_labels and 1 or BLANK_BATCH_SIZE
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
        btn.add {
          type                   = "sprite",
          name                   = "tf_slot_lock",
          sprite                 = "tf_fave_slot_lock",
          visible                = false,
          ignored_by_interaction = true,
          style                  = "tf_fave_slot_lock_overlay",
        }
        if entry.use_labels then
          btn_parent.add {
            type    = "label",
            name    = "fave_bar_slot_label_" .. i,
            caption = "",
            style   = "tf_fave_bar_slot_label",
          }
        end
      end
      if end_idx >= entry.max_slots then
        if entry.stop_after_blank then
          local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
          local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
          if bar_frame and bar_frame.valid then bar_frame.visible = true end
          table.remove(storage._tf_slot_build_queue, 1)
          last_build_tick[entry.player_index] = game.tick
          local need_hydrate = storage._tf_hydrate_after_blank
              and storage._tf_hydrate_after_blank[entry.player_index]
          if need_hydrate then
            storage._tf_hydrate_after_blank[entry.player_index] = nil
            local pfaves_pre = Cache.get_player_favorites(player, entry.surface_index)
            prune_stale_favorites(player, entry.surface_index, pfaves_pre)
            fave_bar.enqueue_hydrate(player)
          end
        else
          storage._tf_slot_build_queue[1] = {
            player_index  = entry.player_index,
            surface_index = entry.surface_index,
            stage         = "prune",
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
    if entry.stage == "prune" then
      local pfaves_pre = Cache.get_player_favorites(player, entry.surface_index)
      prune_stale_favorites(player, entry.surface_index, pfaves_pre)
      storage._tf_slot_build_queue[1] = {
        player_index  = entry.player_index,
        surface_index = entry.surface_index,
        stage         = "hydrate_slots",
        next_slot     = 1,
        max_slots     = entry.max_slots,
        use_labels    = entry.use_labels,
        label_mode    = entry.label_mode,
      }
      return
    end
    if entry.stage == "hydrate_slots" then
      local slots_frame = get_bar_slots_frame(player)
      if not slots_frame or not slots_frame.valid then
        table.remove(storage._tf_slot_build_queue, 1)
        return
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
          local fav                  = PlayerFavorites.rehydrate_favorite_at_runtime(player, fav_raw)
              or FavoriteUtils.get_blank_favorite()
          local icon, tooltip, style = get_slot_btn_props(i, fav)
          btn.sprite                 = icon or ""
          btn.tooltip                = tooltip
          if style ~= "tf_slot_button_smallfont" or BasicHelpers.is_locked_favorite(fav) then
            btn.style = style
          end
          local lock_el = btn["tf_slot_lock"]
          if lock_el and lock_el.valid then
            lock_el.visible = BasicHelpers.is_locked_favorite(fav)
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
      if end_idx >= entry.max_slots then
        local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
        local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
        if bar_frame and bar_frame.valid then bar_frame.visible = true end
        table.remove(storage._tf_slot_build_queue, 1)
        last_build_tick[entry.player_index] = game.tick
      else
        entry.next_slot = end_idx + 1
      end
      return
    end
    if entry.stage == "slots" then
      local slots_frame = get_bar_slots_frame(player)
      if not slots_frame or not slots_frame.valid then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      if GuiHelpers.count_direct_children(slots_frame) ~= entry.expected_built then
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
      if end_idx >= max_slots then
        local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
        local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
        if bar_frame and bar_frame.valid then bar_frame.visible = true end
        table.remove(storage._tf_slot_build_queue, 1)
        last_build_tick[entry.player_index] = game.tick
      else
        entry.next_slot      = end_idx + 1
        entry.expected_built = end_idx
      end
    end
  end
  function fave_bar.on_load_cleanup()
    if storage and storage._tf_slot_build_queue and #storage._tf_slot_build_queue > 0 then
      _fave_bar_queue_has_work = true
    else
      _fave_bar_queue_has_work = false
    end
  end
end
