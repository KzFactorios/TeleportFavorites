---@diagnostic disable: undefined-global

-- gui/favorites_bar/fave_bar.lua
-- TeleportFavorites Factorio Mod
-- Core favorites bar module. Shared private helpers, chrome, controller handling.
-- Slot functions live in fave_bar_slots.lua; progressive builder in fave_bar_progressive.lua.
--
-- Element Hierarchy:
-- fave_bar_frame (frame)
-- └─ fave_bar_flow (flow, horizontal)
--    ├─ fave_bar_toggle_container (frame, vertical)
--    │  ├─ fave_bar_history_toggle (sprite-button)
--    │  ├─ fave_bar_history_mode_toggle (sprite-button)
--    │  └─ fave_bar_visibility_toggle (sprite-button)
--    └─ fave_bar_slots_flow (frame, horizontal)
--       └─ fave_bar_slot_1 ... fave_bar_slot_N (sprite-button: children label "n", sprite tf_slot_lock when locked)

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Enum, Constants =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Enum, Deps.Constants
local GuiBase = require("gui.gui_base")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local fave_bar_slots_extend = require("gui.favorites_bar.fave_bar_slots")
local fave_bar_progressive_extend = require("gui.favorites_bar.fave_bar_progressive")

local fave_bar = {}
local last_build_tick = {}

--- Session-local cached GUI element refs (not in storage). Invalidates on teardown / surface change / player removed.
---@type table<uint, { main_flow: LuaGuiElement, bar_frame: LuaGuiElement, bar_flow: LuaGuiElement, slots_frame: LuaGuiElement }>
local session_fave_bar_refs = {}

-- ============================================================
-- Shared private helpers (closed over by extend modules via helpers table)
-- ============================================================

--- Scan a player's favorites for stale GPS entries and replace with blank slots.
---@param player LuaPlayer
---@param surface_index uint
---@param pfaves table|nil
---@return boolean changed
local function prune_stale_favorites(player, surface_index, pfaves)
  if not pfaves then return false end
  local tag_cache = Cache.get_surface_tags(surface_index)
  -- pairs(tag_cache): order irrelevant; valid_gps is a set used only for membership.
  local valid_gps = {}
  if tag_cache then
    for gps in pairs(tag_cache) do valid_gps[gps] = true end
  end
  local changed = false
  for i = 1, #pfaves do
    local fav = pfaves[i]
    if fav and fav.gps and not valid_gps[fav.gps] and not FavoriteUtils.is_blank_favorite(fav) then
      ErrorHandler.debug_log("[FAVE_BAR][FAILSAFE] Clearing stale favorite slot", {
        slot = i, fav_gps = fav.gps
      })
      pfaves[i] = FavoriteUtils.get_blank_favorite()
      changed = true
    end
  end
  if changed then Cache.set_player_favorites(player, pfaves) end
  return changed
end

--- Normalize a SignalID-style icon's type field for legacy variants.
---@param icon any
---@return any
local function normalize_icon_type(icon)
  if type(icon) ~= "table" then return icon end
  if icon.type == "virtual" or icon.type == "virtual_signal" then
    local copy = {}
    for k, v in pairs(icon) do copy[k] = v end
    copy.type = "virtual-signal"
    return copy
  end
  return icon
end

if ErrorHandler and ErrorHandler.debug_log then
  ErrorHandler.debug_log("[FAVE_BAR] Module loaded", {
    tick = game and game.tick or 0,
    debug_enabled = ErrorHandler.is_debug()
  })
end

local function _get_fave_bar_frame(player)
  if not BasicHelpers.is_valid_player(player) then return nil end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end
  return GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
end

local function _destroy_fave_bar(player)
  if player and player.index then
    session_fave_bar_refs[player.index] = nil
  end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if main_flow and main_flow.valid then
    local ph = main_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.LOADER_PLACEHOLDER]
    if ph and ph.valid then ph.destroy() end
    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
  end
end

--- Returns true when a progressive bar build is pending for this player.
---@param player_index uint
---@return boolean
local function is_build_in_flight(player_index)
  if not storage or not storage._tf_slot_build_queue then return false end
  for _, entry in ipairs(storage._tf_slot_build_queue) do
    if entry.player_index == player_index then return true end
  end
  return false
end

--- True if this player has any entry in the slot build queue (blank-first or full progressive).
---@param player_index uint
---@return boolean
function fave_bar.has_pending_slot_build(player_index)
  return is_build_in_flight(player_index)
end

--- Remove all build-queue entries for a player (cancels any in-flight progressive build).
---@param player_index uint
local function cancel_progressive_build_for(player_index)
  if not storage or not storage._tf_slot_build_queue then return end
  for i = #storage._tf_slot_build_queue, 1, -1 do
    if storage._tf_slot_build_queue[i].player_index == player_index then
      table.remove(storage._tf_slot_build_queue, i)
    end
  end
end

local function get_fave_bar_gui_refs(player)
  if not BasicHelpers.is_valid_player(player) then
    return nil, nil, nil, nil
  end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then
    session_fave_bar_refs[player.index] = nil
    return nil, nil, nil, nil
  end
  local cached = session_fave_bar_refs[player.index]
  if cached and cached.main_flow == main_flow
      and cached.main_flow.valid
      and cached.bar_frame and cached.bar_frame.valid
      and cached.bar_flow and cached.bar_flow.valid
      and cached.slots_frame and cached.slots_frame.valid then
    return cached.main_flow, cached.bar_frame, cached.bar_flow, cached.slots_frame
  end
  local bar_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  local bar_flow = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
  local slots_frame = bar_flow and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]
  if bar_frame and bar_frame.valid and bar_flow and bar_flow.valid and slots_frame and slots_frame.valid then
    session_fave_bar_refs[player.index] = {
      main_flow = main_flow,
      bar_frame = bar_frame,
      bar_flow = bar_flow,
      slots_frame = slots_frame,
    }
  else
    session_fave_bar_refs[player.index] = nil
  end
  return main_flow, bar_frame, bar_flow, slots_frame
end

--- Clear session GUI ref cache for a player (surface change, removal, or explicit teardown).
---@param player_index uint?
function fave_bar.clear_session_gui_refs(player_index)
  if player_index then
    session_fave_bar_refs[player_index] = nil
  end
end

--- Build properties (icon, tooltip, style) for a single slot's button.
---@param i number slot index
---@param fav table rehydrated favorite
---@return string|nil icon, LocalisedString tooltip, string style
local function get_slot_btn_props(i, fav)
  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    local icon = nil
    if fav.tag and fav.tag.chart_tag then
      if fav.tag.chart_tag.valid then
        icon = fav.tag.chart_tag.icon
      else
        return nil, { "tf-gui.favorite_slot_empty" }, "slot_button"
      end
    end
    local btn_icon = GuiValidation.get_validated_sprite_path(normalize_icon_type(icon),
      { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
    local style = "tf_slot_button_smallfont"
    if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
    if fav.locked then
      if style == "tf_slot_button_smallfont_map_pin" then
        style = "tf_slot_button_smallfont_map_pin_locked"
      else
        style = "tf_slot_button_smallfont_locked"
      end
    end
    return btn_icon, GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style
  else
    return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont"
  end
end

--- Add one slot button to parent.
--- Shared by build_favorite_buttons_row and the progressive builder.
---@param parent LuaGuiElement
---@param player LuaPlayer
---@param pfaves table|nil
---@param i number slot index
local function build_single_slot(parent, player, pfaves, i)
  local fav_raw = pfaves and pfaves[i] or nil
  local fav
  if fav_raw and not FavoriteUtils.is_blank_favorite(fav_raw) then
    fav = PlayerFavorites.rehydrate_favorite_at_runtime(player, fav_raw)
          or FavoriteUtils.get_blank_favorite()
  else
    fav = FavoriteUtils.get_blank_favorite()
  end

  local btn_icon, tooltip, style = get_slot_btn_props(i, fav)

  local btn = parent.add {
    type    = "sprite-button",
    name    = "fave_bar_slot_" .. i,
    sprite  = btn_icon or "",
    tooltip = tooltip,
    style   = style,
  }
  if btn and btn.valid then
    btn.add { type = "label", name = "n", caption = tostring(i), style = "tf_fave_bar_slot_number" }
    btn.add {
      type                   = "sprite",
      name                   = "tf_slot_lock",
      sprite                 = "tf_fave_slot_lock",
      visible                = BasicHelpers.is_locked_favorite(fav),
      ignored_by_interaction = true,
      style                  = "tf_fave_slot_lock_overlay",
    }
  else
    ErrorHandler.warn_log("[FAVE_BAR] Failed to create slot button", { slot = i, icon = btn_icon })
  end
end

--- Create toggle buttons + slots frame inside an existing toggle_container and bar_flow.
---@param tog_cont LuaGuiElement
---@param bar_flow LuaGuiElement
---@param player LuaPlayer
---@return LuaGuiElement slots_frame, LuaGuiElement toggle_btn, LuaGuiElement hist_btn, LuaGuiElement mode_btn
local function create_toggle_chrome(tog_cont, bar_flow, player)
  local player_data = Cache.get_player_data(player)
  local is_seq = player_data.sequential_history_mode or false

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

  local slots_vis = player_data.fave_bar_slots_visible
  if slots_vis == nil then
    slots_vis = true
    player_data.fave_bar_slots_visible = true
  end

  local toggle_btn = GuiElementBuilders.create_visibility_toggle_button(
    tog_cont, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON, slots_vis,
    { "tf-gui.toggle_fave_bar" })

  local slots_frame = GuiBase.create_frame(bar_flow,
    Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW, "horizontal", "tf_fave_slots_row")

  return slots_frame, toggle_btn, hist_btn, mode_btn
end

-- ============================================================
-- Public API on fave_bar
-- ============================================================

--- Show/hide the favorites bar based on surface type and controller.
---@param player LuaPlayer
function fave_bar.update_fave_bar_visibility(player)
  if not BasicHelpers.is_valid_player(player) then return end

  local fave_bar_frame = _get_fave_bar_frame(player)
  if not fave_bar_frame or not fave_bar_frame.valid then return end

  local surface = player.surface
  if not surface or not surface.valid then
    fave_bar_frame.visible = false
    return
  end

  local is_planet = BasicHelpers.is_planet_surface(surface)
  local is_supported_mode = BasicHelpers.is_supported_controller(player)
  local is_restricted_mode = BasicHelpers.is_restricted_controller(player)

  fave_bar_frame.visible = is_planet and is_supported_mode and not is_restricted_mode
end

--- Event handler for controller changes.
---@param event table
function fave_bar.on_player_controller_changed(event)
  if not event or not event.player_index then return end
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  -- Always update visibility before the in-flight guard: bar_frame may exist as
  -- visible=false (created by frame_init) even while the progressive build runs.
  fave_bar.update_fave_bar_visibility(player)
  if is_build_in_flight(event.player_index) then return end

  local modal_was_open = Cache.get_modal_dialog_type(player) == "teleport_history"
  local is_remote_controller = player.controller_type == defines.controllers.remote
  if is_remote_controller and modal_was_open then
    teleport_history_modal.destroy(player, true)
    teleport_history_modal.build(player)
  end

  if BasicHelpers.is_supported_controller(player) then
    local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
    if bar_flow and bar_flow.valid and slots_frame and slots_frame.valid then
      fave_bar.enqueue_hydrate(player)
    else
      fave_bar.build(player, true, true)
    end
  end
end

--- Build the bar chrome (bar_flow, toggle_container, buttons, slots_frame).
--- Shared between the synchronous build path and the progressive chrome2 stage.
---@param player LuaPlayer
---@param parent LuaGuiElement
---@return LuaGuiElement bar_flow, LuaGuiElement slots_frame, LuaGuiElement toggle_btn, LuaGuiElement toggle_container, LuaGuiElement hist_btn, LuaGuiElement mode_btn
function fave_bar.build_quickbar_style(player, parent)
  local bar_flow = GuiBase.create_hflow(parent, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)
  local toggle_container = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER,
    "horizontal", "tf_fave_toggle_container")
  local slots_frame, toggle_btn, hist_btn, mode_btn = create_toggle_chrome(toggle_container, bar_flow, player)
  return bar_flow, slots_frame, toggle_btn, toggle_container, hist_btn, mode_btn
end

-- ============================================================
-- Wire in extend modules
-- ============================================================

local helpers = {
  is_build_in_flight           = is_build_in_flight,
  normalize_icon_type          = normalize_icon_type,
  get_fave_bar_gui_refs        = get_fave_bar_gui_refs,
  get_slot_btn_props           = get_slot_btn_props,
  build_single_slot            = build_single_slot,
  cancel_progressive_build_for = cancel_progressive_build_for,
  prune_stale_favorites        = prune_stale_favorites,
  last_build_tick              = last_build_tick,
  create_toggle_chrome         = create_toggle_chrome,
  _destroy_fave_bar            = _destroy_fave_bar,
  GuiElementBuilders           = GuiElementBuilders,
  clear_session_gui_refs       = function(player_index) fave_bar.clear_session_gui_refs(player_index) end,
}

fave_bar_slots_extend(fave_bar, helpers)
fave_bar_progressive_extend(fave_bar, helpers)

--- Low-frequency self-heal when slot row child count or structure drifts from settings (e.g. queue aborted).
--- One connected player per call; driven by on_nth_tick(120).
function fave_bar.tick_slot_row_watchdog()
  if not game or not game.players or not storage then return end
  local default_max = math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
  local plist = {}
  BasicHelpers.for_each_connected_player_by_index_asc(function(player)
    if player and player.valid then plist[#plist + 1] = player end
  end)
  if #plist == 0 then return end
  storage._tf_slot_watch_next_index = storage._tf_slot_watch_next_index or 1
  local idx = storage._tf_slot_watch_next_index
  if idx < 1 or idx > #plist then idx = 1 end
  local player = plist[idx]
  storage._tf_slot_watch_next_index = (idx % #plist) + 1
  if BasicHelpers.is_restricted_controller(player) then return end
  if not player.surface or not player.surface.valid then return end
  if not BasicHelpers.is_planet_surface(player.surface) then return end
  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on and not player_settings.enable_teleport_history then return end
  if is_build_in_flight(player.index) then return end
  local _, _, _, slots_frame = get_fave_bar_gui_refs(player)
  if not slots_frame or not slots_frame.valid then return end
  local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or default_max
  if GuiHelpers.slot_row_matches_expected(slots_frame, max_slots) then return end
  ErrorHandler.warn_log("[FAVE_BAR] slot row watchdog: mismatch, scheduling rebuild", {
    player = player.name,
    tick = game and game.tick or 0,
    max_slots = max_slots,
    child_count = GuiHelpers.count_direct_children(slots_frame),
  })
  fave_bar.build(player, true, true)
end

-- Loader sprite is removed immediately (delay=0) so it is gone before the first bar frame element appears.
local FAVE_BAR_LOADER_DELAY_TICKS = 0

--- Remove loader placeholder sprite from main GUI flow if present.
---@param player LuaPlayer
function fave_bar.destroy_loader_placeholder(player)
  if not BasicHelpers.is_valid_player(player) then return end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end
  local ph = main_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.LOADER_PLACEHOLDER]
  if ph and ph.valid then
    ph.destroy()
  end
end

function fave_bar.flush_loader_placeholder_defer_if_ready()
  if not storage or not storage._tf_loader_placeholder_defer then return end
  local list = storage._tf_loader_placeholder_defer
  if #list == 0 then return end
  local now = game.tick
  for i = #list, 1, -1 do
    local e = list[i]
    if now >= e.until_tick then
      local p = game.get_player(e.player_index)
      if p and p.valid then
        fave_bar.destroy_loader_placeholder(p)
        fave_bar.enqueue_blank_bar(p, "loader_placeholder_defer_flush")
      end
      table.remove(list, i)
    end
  end
end

--- First paint: loader sprite where the bar will appear; after a few ticks, progressive build runs.
---@param player LuaPlayer
function fave_bar.begin_bar_with_loader_placeholder(player)
  if not BasicHelpers.is_valid_player(player) then return end
  if BasicHelpers.is_restricted_controller(player) then return end
  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on and not player_settings.enable_teleport_history then
    fave_bar.enqueue_blank_bar(player, "begin_bar_with_loader_both_features_off")
    return
  end
  fave_bar.destroy_loader_placeholder(player)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end
  local ph = main_flow.add({
    type = "sprite",
    name = Enum.GuiEnum.FAVE_BAR_ELEMENT.LOADER_PLACEHOLDER,
    sprite = "tf_fave_bar_loader_sprite",
    index = 1,
  })
  if ph and ph.valid then
    ph.style.minimal_width = 128
    ph.style.minimal_height = 40
    ph.style.maximal_height = 40
  end
  storage._tf_loader_placeholder_defer = storage._tf_loader_placeholder_defer or {}
  local until_tick = game.tick + FAVE_BAR_LOADER_DELAY_TICKS
  for _, row in ipairs(storage._tf_loader_placeholder_defer) do
    if row.player_index == player.index then
      row.until_tick = until_tick
      return
    end
  end
  table.insert(storage._tf_loader_placeholder_defer, { player_index = player.index, until_tick = until_tick })
end

local _process_slot_build_queue = fave_bar.process_slot_build_queue
function fave_bar.process_slot_build_queue()
  fave_bar.flush_loader_placeholder_defer_if_ready()
  _process_slot_build_queue()
end

if ErrorHandler and ErrorHandler.debug_log then
  local keys = {}
  for k, _ in pairs(fave_bar) do table.insert(keys, tostring(k)) end
  ErrorHandler.debug_log("[FAVE_BAR] Exported keys at module load", { keys = table.concat(keys, ", ") })
end

return fave_bar
