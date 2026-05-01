---@diagnostic disable: undefined-global

-- gui/favorites_bar/fave_bar_progressive.lua
-- Progressive startup bar builder extracted from fave_bar.lua.
-- Extend pattern: receives (fave_bar, helpers) where helpers contains shared private functions.
--
-- Stages in storage._tf_slot_build_queue:
--   frame_init     → create fave_bar_frame (1 tick, 1 GUI add)
--   chrome1        → build bar_flow + toggle_container (1 tick, 2 GUI adds)
--   chrome2a       → build history + mode buttons (1 tick, 2 GUI adds)
--   chrome2b       → build visibility toggle + slots frame (1 tick, 2 GUI adds)
--   blank_slots    → add empty slot GUI elements BLANK_BATCH_SIZE per tick
--   prune          → run prune_stale_favorites (1 tick, no GUI adds)
--   hydrate_slots  → write data into blank slots HYDRATE_BATCH_SIZE per tick
--   slots          → legacy stage kept for old save files

local Deps                                    = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Enum, Constants =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum, Deps.Constants
local GuiBase                                 = require("gui.gui_base")
local GuiHelpers                              = require("core.utils.gui_helpers")
local FavoriteUtils                           = require("core.favorite.favorite_utils")
local PlayerFavorites                         = require("core.favorite.player_favorites")

-- Batches spread GUI adds across ticks; slightly larger than legacy (~10–15% fewer ticks).
-- BLANK_BATCH_SIZE slots/tick × 2 adds/slot (button + number label "n" + lock sprite).
local BLANK_BATCH_SIZE                        = 3
local HYDRATE_BATCH_SIZE                      = 5

local function default_max_favorite_slots()
  return math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
end

--- Create empty slot buttons for indices [start_idx, end_idx]. Shared by blank_slots queue stage and
--- fave_bar.build(..., deferred_slots) so placeholder DOM matches before hydrate runs.
--- Each slot is built inside pcall; on failure any partial element for that index is destroyed so retry
--- does not leave duplicate-name orphans.
---@param slots_frame LuaGuiElement
---@param start_idx uint
---@param end_idx uint
local function build_blank_slot_range(slots_frame, start_idx, end_idx)
  for i = start_idx, end_idx do
    local slot_ok, slot_err = pcall(function()
      local btn = slots_frame.add {
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
    end)
    if not slot_ok then
      local w = slots_frame["fave_bar_slot_wrapper_" .. i]
      if w and w.valid then
        w.destroy()
      else
        local b = slots_frame["fave_bar_slot_" .. i]
        if b and b.valid then b.destroy() end
      end
      error(slot_err)
    end
  end
end

return function(fave_bar, helpers)
  helpers.build_blank_slot_range = build_blank_slot_range

  local cancel_progressive_build_for = helpers.cancel_progressive_build_for
  local clear_session_gui_refs         = helpers.clear_session_gui_refs
  local last_build_tick              = helpers.last_build_tick
  local create_toggle_chrome         = helpers.create_toggle_chrome
  local prune_stale_favorites        = helpers.prune_stale_favorites
  local get_fave_bar_gui_refs        = helpers.get_fave_bar_gui_refs
  local get_slot_btn_props           = helpers.get_slot_btn_props
  local build_single_slot            = helpers.build_single_slot
  local is_build_in_flight           = helpers.is_build_in_flight
  local GuiElementBuilders           = helpers.GuiElementBuilders

  -- Session-local hint (kept in sync with storage in process_slot_build_queue / on_load_cleanup).
  -- Do not use it to skip processing: other modules may enqueue into storage without touching this flag.
  local _fave_bar_queue_has_work = false

  --- Init the build queue and cancel any in-flight build. Does NOT create GUI elements.
  --- The bar_frame is created lazily in the frame_init queue stage on the next on_nth_tick(2).
  ---@param player LuaPlayer
  ---@return boolean ok
  local function prepare_queue_only(player)
    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    cancel_progressive_build_for(player.index)
    return true
  end

  --- Used by chrome1 and later stages to get the existing bar_frame (must already exist).
  ---@param player LuaPlayer
  ---@return LuaGuiElement|nil
  local function get_bar_frame(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    return main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  end

  --- Resolve main_flow → bar_frame → bar_flow → slots_frame for a player.
  ---@param player LuaPlayer
  ---@return LuaGuiElement|nil slots_frame
  local function get_bar_slots_frame(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
    local bar_flow  = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
    return bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  end

  --- Drop the current queue head (failed stage) and restart full progressive chrome for this player.
  local function replace_queue_head_with_frame_init(player, surface_index, stop_after_blank)
    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    if #storage._tf_slot_build_queue > 0 then
      table.remove(storage._tf_slot_build_queue, 1)
    end
    table.insert(storage._tf_slot_build_queue, 1, {
      player_index     = player.index,
      surface_index    = surface_index,
      stage            = "frame_init",
      stop_after_blank = stop_after_blank and true or false,
    })
    last_build_tick[player.index] = game.tick
    _fave_bar_queue_has_work = true
  end

  --- Called from process_deferred_init_queue when a full progressive build is needed.
  --- frame_init runs on the next on_nth_tick(2), keeping the enqueue tick free of element.add().
  ---@param player LuaPlayer
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

  --- Called from on_player_joined_game / on_player_created / ensure_fave_bar_for_session_players.
  --- Defers all GUI creation — frame_init runs on the next on_nth_tick(2), keeping tick 1
  --- free of element.add() cost. Hydration is enqueued later by enqueue_hydrate().
  ---@param player LuaPlayer
  ---@param enqueue_reason string? caller id for MP desync tracing (factorio-current.log)
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

  --- Returns true when the blank bar is fully built and no build is in flight.
  ---@param player LuaPlayer
  ---@return boolean
  function fave_bar.blank_bar_is_ready(player)
    if not BasicHelpers.is_valid_player(player) then return false end
    if is_build_in_flight(player.index) then return false end
    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
    if not bar_flow or not bar_flow.valid then return false end
    if not slots_frame or not slots_frame.valid then return false end
    local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or default_max_favorite_slots()
    return GuiHelpers.slot_row_matches_expected(slots_frame, max_slots)
  end

  --- Enqueues only the hydrate_slots stage for a player whose blank bar is already built.
  ---@param player LuaPlayer
  function fave_bar.enqueue_hydrate(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local max_slots              = Cache.Settings.get_player_max_favorite_slots(player) or default_max_favorite_slots()

    local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
    if not slots_frame or not slots_frame.valid
        or not GuiHelpers.slot_row_matches_expected(slots_frame, max_slots) then
      fave_bar.build(player, true, true)
      return
    end

    storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
    cancel_progressive_build_for(player.index)

    table.insert(storage._tf_slot_build_queue, {
      player_index  = player.index,
      surface_index = player.surface.index,
      stage         = "hydrate_slots",
      next_slot     = 1,
      max_slots     = max_slots,
    })
    last_build_tick[player.index] = game.tick
    _fave_bar_queue_has_work = true
  end

  --- Called on every on_nth_tick(2); processes one queue stage per call.
  function fave_bar.process_slot_build_queue()
    -- Skip tick 0: on_nth_tick(2) fires at tick 0 (0 % 2 == 0).
    if game.tick < 2 then return end
    -- Never trust the session flag alone: `fave_bar_slots` (and similar) may insert into
    -- `storage._tf_slot_build_queue` without setting `_fave_bar_queue_has_work`. If one peer
    -- skips processing while another drains the queue, `storage` diverges → MP desync.
    if not storage or not storage._tf_slot_build_queue or #storage._tf_slot_build_queue == 0 then
      _fave_bar_queue_has_work = false
      return
    end
    _fave_bar_queue_has_work = true

    local entry  = storage._tf_slot_build_queue[1]
    -- Deferred rebuild from fave_bar_slots used next_slot/expected_built without stage (legacy "slots" worker).
    if entry and entry.stage == nil and type(entry.next_slot) == "number" and type(entry.expected_built) == "number" then
      entry.stage = "slots"
    end
    local player = game.players[entry.player_index]
    if not player or not player.valid then
      table.remove(storage._tf_slot_build_queue, 1)
      return
    end

    -- ── Frame init stage: create bar_frame (1 GUI add) ───────────────────────────
    -- Deferred from the enqueue call so the calling tick pays zero element.add() cost.
    -- Performs feature-toggle and controller checks here
    -- so we bail before the first GUI add if the bar shouldn't be built at all.
    -- MP: `get_player_settings` reads `player.mod_settings` / `settings.get_player_settings(player)`;
    -- controller checks use `LuaPlayer` state — all replicated identically on every peer for the same tick.
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

    -- ── Chrome stage 1: bar_flow + toggle_container (2 GUI adds) ─────────────────
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
      clear_session_gui_refs(entry.player_index)

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

    -- ── Chrome stage 2a: history toggle + mode buttons (2 GUI adds) ─────────────
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

    -- ── Chrome stage 2b: visibility toggle + slots frame (2 GUI adds) ────────────
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

      local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or default_max_favorite_slots()

      storage._tf_slot_build_queue[1] = {
        player_index     = entry.player_index,
        surface_index    = entry.surface_index,
        stage            = "blank_slots",
        next_slot        = 1,
        expected_blank   = 0,
        max_slots        = max_slots,
        stop_after_blank = entry.stop_after_blank,
      }
      return
    end

    -- ── Legacy chrome stage (queue entries created before the frame_init split) ───
    if entry.stage == "chrome" then
      storage._tf_slot_build_queue[1] = {
        player_index  = entry.player_index,
        surface_index = entry.surface_index,
        stage         = "frame_init",
      }
      return
    end

    -- ── Blank slots stage: create empty GUI structure, no data lookups ───────────
    if entry.stage == "blank_slots" then
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        ErrorHandler.warn_log("[TF_MP][blank_slots] slots_frame missing, re-queuing frame_init", {
          tick         = game.tick,
          player_index = entry.player_index,
        })
        replace_queue_head_with_frame_init(player, entry.surface_index, entry.stop_after_blank)
        return
      end

      -- blank_batch_override: optional (e.g. deferred build — full tail in one pass).
      local batch_size
      if type(entry.blank_batch_override) == "number" and entry.blank_batch_override > 0 then
        batch_size = entry.blank_batch_override
      else
        batch_size = BLANK_BATCH_SIZE
      end
      local start_idx  = entry.next_slot
      local end_idx    = math.min(start_idx + batch_size - 1, entry.max_slots)

      local function try_blank_range(sf)
        build_blank_slot_range(sf, start_idx, end_idx)
      end
      local ok, err = pcall(try_blank_range, slots_frame)
      if not ok then
        local msg = tostring(err)
        if msg:find("already present", 1, true) or msg:find("already exists", 1, true) then
          ErrorHandler.warn_log("[TF_MP][blank_slots] duplicate slot name; clearing refs and row, retrying once", {
            player_index = entry.player_index,
            tick = game.tick,
            err = msg,
            start_idx = start_idx,
            end_idx = end_idx,
          })
          clear_session_gui_refs(entry.player_index)
          slots_frame = get_bar_slots_frame(player)
          if slots_frame and slots_frame.valid then
            GuiHelpers.peel_destroy_all_children(slots_frame)
            local function try_blank_range_after_peel(sf)
              -- Rebuild 1..end_idx so earlier batches are not left missing after peel.
              build_blank_slot_range(sf, 1, end_idx)
            end
            ok, err = pcall(try_blank_range_after_peel, slots_frame)
          end
        end
      end
      if not ok then
        ErrorHandler.warn_log("[TF_MP][blank_slots] build_blank_slot_range failed, re-queuing frame_init", {
          player_index = entry.player_index,
          tick = game.tick,
          err = tostring(err),
        })
        replace_queue_head_with_frame_init(player, entry.surface_index, entry.stop_after_blank)
        return
      end

      if end_idx >= entry.max_slots then
        if entry.stop_after_blank then
          -- Blank bar is fully built — reveal it now.
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
          -- Transition to the prune stage: runs prune_stale_favorites alone on the
          -- next tick so it doesn't pile on top of the first hydrate batch.
          storage._tf_slot_build_queue[1] = {
            player_index  = entry.player_index,
            surface_index = entry.surface_index,
            stage         = "prune",
            max_slots     = entry.max_slots,
          }
        end
      else
        entry.next_slot      = end_idx + 1
        entry.expected_blank = end_idx
      end
      return
    end

    -- ── Prune stage: clear stale GPS favorites before hydration (no GUI adds) ────
    if entry.stage == "prune" then
      local pfaves_pre = Cache.get_player_favorites(player, entry.surface_index)
      prune_stale_favorites(player, entry.surface_index, pfaves_pre)
      storage._tf_slot_build_queue[1] = {
        player_index  = entry.player_index,
        surface_index = entry.surface_index,
        stage         = "hydrate_slots",
        next_slot     = 1,
        max_slots     = entry.max_slots,
      }
      return
    end

    -- ── Hydrate slots stage: fill existing blank buttons with data ───────────────
    if entry.stage == "hydrate_slots" then
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        table.remove(storage._tf_slot_build_queue, 1)
        fave_bar.build(player, true, true)
        return
      end

      -- Pruning is handled by the preceding "prune" stage; nothing to do here.
      local pfaves    = Cache.get_player_favorites(player, entry.surface_index)
      local start_idx = entry.next_slot
      local end_idx   = math.min(start_idx + HYDRATE_BATCH_SIZE - 1, entry.max_slots)

      for i = start_idx, end_idx do
        local btn = slots_frame["fave_bar_slot_" .. i]
        if not btn or not btn.valid then goto next_hydrate end

        local n_el = btn["n"]
        if not n_el or not n_el.valid then
          btn.add {
            type    = "label",
            name    = "n",
            caption = tostring(i),
            style   = "tf_fave_bar_slot_number",
          }
        else
          n_el.caption = tostring(i)
        end

        local fav_raw = pfaves and pfaves[i]
        if fav_raw and not FavoriteUtils.is_blank_favorite(fav_raw) then
          local fav                  = PlayerFavorites.rehydrate_favorite_at_runtime(player, fav_raw)
              or FavoriteUtils.get_blank_favorite()
          local icon, tooltip, style = get_slot_btn_props(i, fav)
          btn.sprite                 = icon or ""
          btn.tooltip                = tooltip
          -- Blank buttons are built with "tf_slot_button_smallfont"; skip the
          -- style write for the common case (unlocked, non-pin) to avoid
          -- Factorio's style-recalculation cost on every hydrated slot.
          if style ~= "tf_slot_button_smallfont" or BasicHelpers.is_locked_favorite(fav) then
            btn.style = style
          end
          local lock_el = btn["tf_slot_lock"]
          if lock_el and lock_el.valid then
            lock_el.visible = BasicHelpers.is_locked_favorite(fav)
          end
        end
        ::next_hydrate::
      end


      if end_idx >= entry.max_slots then
        if not GuiHelpers.slot_row_matches_expected(slots_frame, entry.max_slots) then
          ErrorHandler.warn_log("[TF_MP][hydrate_slots] row invalid after hydrate; forcing sync rebuild", {
            player_index = entry.player_index,
            tick = game.tick,
            max_slots = entry.max_slots,
            child_count = GuiHelpers.count_direct_children(slots_frame),
          })
          table.remove(storage._tf_slot_build_queue, 1)
          cancel_progressive_build_for(player.index)
          fave_bar.build(player, true, false)
          last_build_tick[entry.player_index] = game.tick
          return
        end
        -- Hydration complete — reveal the bar now that it has real content.
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

    -- ── Legacy slots stage (saves created before blank/hydrate split) ─────────
    if entry.stage == "slots" then
      local slots_frame = get_bar_slots_frame(player)

      if not slots_frame or not slots_frame.valid then
        table.remove(storage._tf_slot_build_queue, 1)
        return
      end
      if GuiHelpers.count_direct_children(slots_frame) ~= entry.expected_built then
        ErrorHandler.warn_log("[TF_MP][slots] legacy row count mismatch, re-queuing frame_init", {
          player_index = entry.player_index,
          tick = game.tick,
          expected = entry.expected_built,
          actual = GuiHelpers.count_direct_children(slots_frame),
        })
        replace_queue_head_with_frame_init(player, entry.surface_index, false)
        return
      end

      local max_slots  = Cache.Settings.get_player_max_favorite_slots(player) or default_max_favorite_slots()
      local pfaves     = Cache.get_player_favorites(player, entry.surface_index)
      local start_idx  = entry.next_slot
      local end_idx    = math.min(start_idx + 2 - 1, max_slots)

      for i = start_idx, end_idx do
        build_single_slot(slots_frame, player, pfaves, i)
      end


      if end_idx >= max_slots then
        -- Legacy build complete — reveal the bar.
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

  --- Clear the build queue on save-load (stale GUI references, fresh state needed).
  --- on_load_cleanup must NOT mutate storage (see .cursor rules / Factorio CRC rules)
  function fave_bar.on_load_cleanup()
    -- Rehydrate the session-local queue flag from storage (read-only).
    -- On reload, we cannot assume the queue is empty (a build may have been in-flight
    -- when the game was saved), so we check the storage table and set the flag accordingly.
    if storage and storage._tf_slot_build_queue and #storage._tf_slot_build_queue > 0 then
      _fave_bar_queue_has_work = true
    else
      _fave_bar_queue_has_work = false
    end
  end
end
