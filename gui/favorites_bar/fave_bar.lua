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
local ProfilerExport = require("core.utils.profiler_export")
local BasicHelpers = require("core.utils.basic_helpers")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")

local fave_bar = {}

local last_build_tick = {}

-- Forward declarations for local functions used in fave_bar.build before they are defined.
local get_slot_label_text
local try_update_slots_in_place

--- Scan a player's favorites array for entries whose GPS no longer exists in the
--- surface tag cache, replace them with blank slots, and persist the change.
--- Returns true when at least one slot was cleared.
---@param player LuaPlayer
---@param surface_index uint
---@param pfaves table|nil
---@return boolean changed
local function prune_stale_favorites(player, surface_index, pfaves)
  if not pfaves then return false end
  local tag_cache = Cache.get_surface_tags(surface_index)
  local valid_gps = {}
  if tag_cache then
    for gps in pairs(tag_cache) do valid_gps[gps] = true end
  end
  local changed = false
  for i = 1, #pfaves do
    local fav = pfaves[i]
    if fav and fav.gps and not valid_gps[fav.gps] and not FavoriteUtils.is_blank_favorite(fav) then
      ErrorHandler.debug_log("[FAVE_BAR][FAILSAFE] Clearing stale favorite slot referencing invalid GPS", {
        slot = i, fav_gps = fav.gps
      })
      pfaves[i] = FavoriteUtils.get_blank_favorite()
      changed = true
    end
  end
  if changed then Cache.set_player_favorites(player, pfaves) end
  return changed
end

--- Normalize a SignalID-style icon table so that Factorio's "virtual-signal" type is
--- always spelled with a hyphen.  Chart tags may carry legacy variants "virtual" or
--- "virtual_signal"; returns a shallow copy with the type fixed, or the original table
--- unchanged when no normalization is needed.  Non-table values are returned as-is.
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
  if not BasicHelpers.is_valid_player(player) then return nil end
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
  if not BasicHelpers.is_valid_player(player) then return end

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

--- Returns true when a progressive bar build is pending for this player.
--- Used to guard synchronous fave_bar.build calls during the startup window.
---@param player_index uint
---@return boolean
local function is_build_in_flight(player_index)
  if not storage or not storage._tf_slot_build_queue then return false end
  for _, entry in ipairs(storage._tf_slot_build_queue) do
    if entry.player_index == player_index then return true end
  end
  return false
end

--- Remove all build-queue entries for a player (cancels any in-flight progressive build).
--- Iterates in reverse so table.remove doesn't shift unvisited indices.
---@param player_index uint
local function cancel_progressive_build_for(player_index)
  if not storage or not storage._tf_slot_build_queue then return end
  for i = #storage._tf_slot_build_queue, 1, -1 do
    if storage._tf_slot_build_queue[i].player_index == player_index then
      table.remove(storage._tf_slot_build_queue, i)
    end
  end
end

--- Event handler for controller changes
---@param event table Player controller change event
function fave_bar.on_player_controller_changed(event)
  if not event or not event.player_index then return end
  -- Before tick 60 the deferred init queue hasn't fired yet.
  -- Factorio fires on_player_controller_changed at tick 0 AND again at tick 2
  -- as the character is fully initialized, but the bar must not be built
  -- synchronously here — it costs ~30 ms and is torn down moments later.
  -- Also skip when a progressive build is still mid-flight (e.g. exactly tick 60
  -- when on_nth_tick(60) just enqueued chrome1) — the build will complete on its own.
  if game.tick < 60 then return end
  if is_build_in_flight(event.player_index) then return end
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

--- Create the 3 toggle buttons (history, mode, visibility) and the slots frame
--- inside an existing toggle_container and bar_flow.  Shared between the
--- synchronous build_quickbar_style path and the progressive chrome2 stage.
--- Visibility of individual buttons is NOT set here — each caller manages that
--- according to current player settings.
---@param tog_cont LuaGuiElement  TOGGLE_CONTAINER frame
---@param bar_flow LuaGuiElement  FAVE_BAR_FLOW hflow (parent of the slots frame)
---@param player LuaPlayer
---@return LuaGuiElement slots_frame
---@return LuaGuiElement toggle_btn
---@return LuaGuiElement hist_btn
---@return LuaGuiElement mode_btn
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

-- Build the favorites bar to visually match the quickbar top row
---@diagnostic disable: assign-type-mismatch, param-type-mismatch
function fave_bar.build_quickbar_style(player, parent)
  local bar_flow = GuiBase.create_hflow(parent, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)
  local toggle_container = GuiBase.create_frame(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER,
    "horizontal", "tf_fave_toggle_container")
  local slots_frame, toggle_btn, hist_btn, mode_btn = create_toggle_chrome(toggle_container, bar_flow, player)
  return bar_flow, slots_frame, toggle_btn, toggle_container, hist_btn, mode_btn
end

local function get_fave_bar_gui_refs(player)
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
  local bar_flow = bar_frame and GuiValidation.find_child_by_name(bar_frame, Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW)
  local slots_frame = bar_flow and GuiValidation.find_child_by_name(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW)
  return main_flow, bar_frame, bar_flow, slots_frame
end

function fave_bar.build(player, force_show, deferred_slots)
  
  ErrorHandler.debug_log("[FAVE_BAR] ========== BUILD CALLED ==========", {
    player = player and player.name or "<no player>",
    force_show = force_show or false,
    tick = game.tick
  })
  
  if not BasicHelpers.is_valid_player(player) then 
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
  local prev_build_tick = last_build_tick[player.index]
  last_build_tick[player.index] = tick  -- always record; used for slot-rebuild debouncing below

  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  -- Always recreate bar_frame if missing or invalid
  if not bar_frame or not bar_frame.valid then
    bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "vertical", "tf_fave_bar_frame")
  end
  if not force_show then
    if prev_build_tick == tick and bar_frame and bar_frame.valid then
      return
    end
  end

  local success, result = pcall(function()
    ProfilerExport.start_section("fb_settings_lookup")
    local player_settings = Cache.Settings.get_player_settings(player)
    -- Fetch player_data once; reused everywhere below to avoid repeated init_player_data calls.
    local player_data = Cache.get_player_data(player)
    ProfilerExport.stop_section("fb_settings_lookup")

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

    -- main_flow was already fetched before the pcall; reuse the captured upvalue.
    -- Do NOT call get_or_create_gui_flow_from_gui_top again here.
    ProfilerExport.start_section("fb_structure_check")

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
    ProfilerExport.stop_section("fb_structure_check")

    -- Create frame only if needed, otherwise reuse existing
    ProfilerExport.start_section("fb_frame_create")
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
    ProfilerExport.stop_section("fb_frame_create")

    -- Handle visibility based on settings
    local favorites_enabled = player_settings.favorites_on
    local history_enabled = player_settings.enable_teleport_history

    -- Hide/show history toggle button based on settings
    if _history_toggle_button and _history_toggle_button.valid then
      _history_toggle_button.visible = history_enabled
    end
    if _history_mode_toggle and _history_mode_toggle.valid then
      _history_mode_toggle.visible = history_enabled
      -- Always refresh sprite/tooltip to reflect current mode state.
      -- Use already-fetched player_data instead of a second get_player_data call.
      local is_sequential = player_data.sequential_history_mode or false
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

      -- FAILSAFE: Remove any slots referencing an old GPS that is no longer valid.
      -- Skip during the 3-tick startup window: GPS state cannot change between tick 0 and tick 2.
      ProfilerExport.start_section("fb_gps_validation")
      local recently_built_for_gps = prev_build_tick ~= nil
        and tick >= prev_build_tick
        and (tick - prev_build_tick) < 3
      if not recently_built_for_gps then
        prune_stale_favorites(player, surface_index, pfaves)
      end
      ProfilerExport.stop_section("fb_gps_validation")

      -- Show the visibility toggle button
      if _toggle_button and _toggle_button.valid then
        _toggle_button.visible = true
      end

      -- Set slots visibility based on player's saved preference.
      -- Reuse the player_data already fetched at the top of this pcall block.
      if slots_frame and slots_frame.valid then
        local slots_visible = player_data.fave_bar_slots_visible
        if slots_visible == nil then
          slots_visible = true
          player_data.fave_bar_slots_visible = true
        end
        slots_frame.visible = slots_visible
      end

      -- Update slot buttons: try in-place mutation first (fast path, no DOM destroy/recreate).
      -- Fall back to destroy+rebuild only when structure changes (slot count, label mode).
      ProfilerExport.start_section("fb_buttons_row")
      -- Startup debounce: if slots were already built very recently (within 3 ticks of init),
      -- skip the update entirely.  Player actions (teleport, settings) happen far later.
      local recently_built = prev_build_tick ~= nil
        and tick >= prev_build_tick
        and (tick - prev_build_tick) < 3
      local slots_already_current = recently_built
        and slots_frame and slots_frame.valid
        and #slots_frame.children > 0
      if not slots_already_current then
        if deferred_slots then
          -- Progressive startup build: clear the frame and enqueue slot filling across ticks.
          -- Any previous deferred entries for this player are replaced.
          storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
          cancel_progressive_build_for(player.index)
          if slots_frame and slots_frame.valid then
            local children = slots_frame.children
            for i = #children, 1, -1 do
              if children[i] and children[i].valid then children[i].destroy() end
            end
          end
          table.insert(storage._tf_slot_build_queue, {
            player_index    = player.index,
            surface_index   = player.surface.index,
            next_slot       = 1,
            expected_built  = 0,  -- how many slots should be in the frame right now
          })
        else
          -- Immediate build: synchronous destroy + rebuild (used for in-game updates).
          -- Cancel any pending deferred build for this player since we're doing it now.
          cancel_progressive_build_for(player.index)
          local slots_updated = slots_frame and slots_frame.valid
            and #slots_frame.children > 0
            and try_update_slots_in_place(slots_frame, player, pfaves)
          if not slots_updated then
            if slots_frame and slots_frame.valid then
              local children = slots_frame.children
              for i = #children, 1, -1 do
                local child = children[i]
                if child and child.valid then child.destroy() end
              end
            end
            fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)
          end
        end
      end
      ProfilerExport.stop_section("fb_buttons_row")

      -- Do NOT update toggle state in pdata here! Only the event handler should do that.

      local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
      if pfaves and #pfaves > max_slots then
        ErrorMessageHelpers.show_simple_error_label(fave_bar_frame, "tf-gui.fave_bar_overflow_error")
      end
    end

    return fave_bar_frame
  end)
  if not success then
    -- Always log at warn level (not debug) so this is visible in production mode.
    log("[TeleportFavorites][FAVE_BAR] build() pcall failed for player="
      .. tostring(player and player.name) .. " error=" .. tostring(result))
    ErrorHandler.warn_log("Favorites bar build failed", {
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
get_slot_label_text = function(fav, mode)
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


--- Attempt to update all slot buttons in place (no destroy/recreate).
--- Returns true on success; false means structure changed and a full rebuild is needed.
try_update_slots_in_place = function(slots_frame, player, pfaves)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(player) or 10
  local label_mode = Cache.Settings.get_player_slot_label_mode(player)
  local use_labels = label_mode ~= "off"
  local children = slots_frame.children

  -- Slot count or label structure mismatch — caller must rebuild.
  if #children ~= max_slots then
    log("[TeleportFavorites][FAVE_BAR] try_update_slots_in_place: count mismatch children="
      .. tostring(#children) .. " max_slots=" .. tostring(max_slots) .. " use_labels=" .. tostring(use_labels))
    return false
  end

  -- Rehydrate all favorites up front (same as the build path).
  local rehydrated = {}
  for i = 1, max_slots do
    local fav = pfaves and pfaves[i] or nil
    local r = fav and FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav) or nil
    rehydrated[i] = r or FavoriteUtils.get_blank_favorite()
  end

  for i = 1, max_slots do
    local fav = rehydrated[i]
    local child = children[i]
    if not child or not child.valid then return false end

    -- Locate button and optional label inside wrapper or directly in frame.
    local btn, label_el
    if use_labels then
      if child.type ~= "flow" then
        log("[TeleportFavorites][FAVE_BAR] try_update_slots_in_place: child type mismatch slot="
          .. tostring(i) .. " type=" .. tostring(child.type) .. " expected=flow")
        return false
      end
      btn = child["fave_bar_slot_" .. i]
      label_el = child["fave_bar_slot_label_" .. i]
    else
      btn = child
    end
    if not btn or not btn.valid then return false end

    if FavoriteUtils.is_blank_favorite(fav) then
      btn.sprite = ""
      btn.tooltip = { "tf-gui.favorite_slot_empty" }
      btn.style = "tf_slot_button_smallfont"
      local ls = btn["slot_lock_sprite_" .. i]
      if ls and ls.valid then ls.destroy() end
    else
      local icon = nil
      if fav.tag and fav.tag.chart_tag then
        if fav.tag.chart_tag.valid then
          icon = fav.tag.chart_tag.icon
        else
          btn.sprite = ""
          btn.tooltip = { "tf-gui.favorite_slot_empty" }
          goto next_slot
        end
      end
    local btn_icon = GuiValidation.get_validated_sprite_path(normalize_icon_type(icon),
      { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps } })
      local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
      if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end

      btn.sprite = btn_icon
      btn.tooltip = GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }
      btn.style = style

      local ls = btn["slot_lock_sprite_" .. i]
      if fav.locked then
        if not ls or not ls.valid then
          btn.add { type = "sprite", name = "slot_lock_sprite_" .. i,
                    sprite = Enum.SpriteEnum.LOCK, style = "tf_fave_bar_slot_lock_sprite" }
        end
      else
        if ls and ls.valid then ls.destroy() end
      end
    end

    if label_el and label_el.valid then
      label_el.caption = get_slot_label_text(fav, label_mode)
    end

    ::next_slot::
  end

  return true
end

-- Build properties (icon, tooltip, style, locked) for a single slot's button.
local function get_slot_btn_props(i, fav)
  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    local icon = nil
    if fav.tag and fav.tag.chart_tag then
      if fav.tag.chart_tag.valid then
        icon = fav.tag.chart_tag.icon
      else
        return nil, { "tf-gui.favorite_slot_empty" }, "slot_button", false
      end
    end
    local btn_icon = GuiValidation.get_validated_sprite_path(normalize_icon_type(icon),
      { fallback = Enum.SpriteEnum.PIN, log_context = { slot = i, fav_gps = fav.gps, fav_tag = fav.tag } })
    local style = fav.locked and "tf_slot_button_locked" or "tf_slot_button_smallfont"
    if btn_icon == "tf_tag_in_map_view_small" then style = "tf_slot_button_smallfont_map_pin" end
    return btn_icon, GuiHelpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }, style, fav.locked
  else
    return "", { "tf-gui.favorite_slot_empty" }, "tf_slot_button_smallfont", false
  end
end

-- Add one slot button (and optional label wrapper) to slots_frame.
-- Shared by build_favorite_buttons_row and the deferred progressive builder.
local function build_single_slot(parent, player, pfaves, i, use_labels, label_mode)
  local fav_raw = pfaves and pfaves[i] or nil
  -- Skip rehydration entirely for blank slots — it only creates an identical blank table.
  local fav
  if fav_raw and not FavoriteUtils.is_blank_favorite(fav_raw) then
    fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav_raw)
          or FavoriteUtils.get_blank_favorite()
  else
    fav = FavoriteUtils.get_blank_favorite()
  end

  local btn_icon, tooltip, style, locked = get_slot_btn_props(i, fav)

  local btn_parent = parent
  if use_labels then
    btn_parent = parent.add {
      type      = "flow",
      name      = "fave_bar_slot_wrapper_" .. i,
      direction = "vertical",
      style     = "tf_fave_bar_slot_wrapper",
    }
  end

  local btn = GuiHelpers.create_slot_button(btn_parent, "fave_bar_slot_" .. i, tostring(btn_icon), tooltip, { style = style })
  if btn and btn.valid then
    local num_style = locked and "tf_fave_bar_locked_slot_number" or "tf_fave_bar_slot_number"
    GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(i), num_style)
    if locked then
      btn.add { type = "sprite", name = "slot_lock_sprite_" .. tostring(i),
                sprite = Enum.SpriteEnum.LOCK, style = "tf_fave_bar_slot_lock_sprite" }
    end
    if use_labels then
      GuiBase.create_label(btn_parent, "fave_bar_slot_label_" .. i,
                           get_slot_label_text(fav, label_mode), "tf_fave_bar_slot_label")
    end
  else
    ErrorHandler.warn_log("[FAVE_BAR] Failed to create slot button", { slot = i, icon = btn_icon })
  end
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

-- Export the function on the fave_bar table (in case it was not attached)
fave_bar.build_favorite_buttons_row = build_favorite_buttons_row

--- Refresh only the slot buttons if the bar exists, otherwise do a full build.
--- This is the preferred entry point for observer-driven updates.
---@param player LuaPlayer
function fave_bar.refresh_slots(player)
  if not BasicHelpers.is_valid_player(player) then return end
  local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)
  if bar_flow and bar_flow.valid and slots_frame and slots_frame.valid then
    fave_bar.update_slot_row(player, bar_flow)
  elseif not is_build_in_flight(player.index) then
    -- Bar structure missing and no progressive build pending — fall back to full build.
    -- If a progressive build is in-flight, skip: it will complete on the next on_nth_tick(2).
    fave_bar.build(player)
  end
end

-- Update only the slots row without rebuilding the entire bar
-- parent: the bar_flow container (parent of fave_bar_slots_flow)
function fave_bar.update_slot_row(player, parent_flow)
  if not BasicHelpers.is_valid_player(player) then return end
  if not parent_flow or not parent_flow.valid then return end

  local slots_frame = GuiValidation.find_child_by_name(parent_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW)
  if not slots_frame or not slots_frame.valid then return end

  -- Remove all children in deterministic order
  -- CRITICAL: Use ipairs() not pairs() - pairs() iteration order is non-deterministic
  -- and causes desyncs in multiplayer when destroying/creating GUI elements
  local children = slots_frame.children
  for i = 1, #children do
    local child = children[i]
    if child and child.valid then
      child.destroy()
    end
  end

  local surface_index = player.surface.index
  local pfaves = Cache.get_player_favorites(player, surface_index)

  -- Rebuild only the slot buttons (using cached rehydrated favorites internally)
  fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves)

  return slots_frame
end

--- Update a single slot button without rebuilding the entire row
---@param player LuaPlayer
---@param slot_index number Slot index (1-based)
function fave_bar.update_single_slot(player, slot_index)
  if not BasicHelpers.is_valid_player(player) then return end
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

  -- Deep Debug: Log full favorite slot state before rehydration
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[DEEP][fave_bar.update_single_slot] before rehydrate", {
      player = player and player.name or "<nil>",
      slot = slot_index,
      fav_gps = fav and fav.gps or "<nil>",
      fav_full = fav,
      pfaves_snapshot = pfaves
    })
  end

  -- Rehydrate favorite for correct icon and tag references
  local rehydrated_fav
  if fav then
    rehydrated_fav = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  end
  if not rehydrated_fav then
    rehydrated_fav = FavoriteUtils.get_blank_favorite()
  end

  -- Deep Debug: Log full favorite slot state after rehydration
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[DEEP][fave_bar.update_single_slot] after rehydrate", {
      player = player and player.name or "<nil>",
      slot = slot_index,
      fav_gps = rehydrated_fav and rehydrated_fav.gps or "<nil>",
      tag_gps = rehydrated_fav and rehydrated_fav.tag and rehydrated_fav.tag.gps or "<nil>",
      rehydrated_fav_full = rehydrated_fav,
      pfaves_snapshot = pfaves
    })
  end

  fav = rehydrated_fav

  if fav and not FavoriteUtils.is_blank_favorite(fav) then
    -- Icon comes from chart_tag.icon only (tags do not have icon property)
    -- Safely check chart_tag validity before accessing its properties
    local icon = nil
    if fav.tag and fav.tag.chart_tag then
      if fav.tag.chart_tag.valid then
        icon = fav.tag.chart_tag.icon
      else
        -- Chart tag is invalid, treat as blank favorite
        slot_button.sprite = ""
        ---@diagnostic disable-next-line: assign-type-mismatch
        slot_button.tooltip = { "tf-gui.favorite_slot_empty" }
        return
      end
    end
    slot_button.sprite = GuiValidation.get_validated_sprite_path(normalize_icon_type(icon),
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
  if not BasicHelpers.is_valid_player(player) then return end

  -- Ensure slots_visible is a proper boolean
  if slots_visible == nil then slots_visible = true end

  local _, _, bar_flow, slots_frame = get_fave_bar_gui_refs(player)

  -- First update the toggle button sprite
  if bar_flow then
    local toggle_container = GuiValidation.find_child_by_name(bar_flow, Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_CONTAINER)
    if toggle_container then
      -- Update the visibility toggle button (fave_bar_visibility_toggle)
      local toggle_visibility_button = GuiValidation.find_child_by_name(toggle_container,
        Enum.GuiEnum.FAVE_BAR_ELEMENT.TOGGLE_BUTTON)
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

-- Dirty-slot tracking for targeted partial rehydrates
local dirty_slots = {}

--- Mark a single slot as dirty for a player so it can be partially rehydrated
---@param player LuaPlayer
---@param slot_index number
function fave_bar.mark_slot_dirty(player, slot_index)
  if not BasicHelpers.is_valid_player(player) then return end
  if type(slot_index) ~= "number" then return end
  local pidx = player.index
  dirty_slots[pidx] = dirty_slots[pidx] or {}
  dirty_slots[pidx][slot_index] = true
end

--- Partially rehydrate any dirty slots for the player and clear the dirty set
---@param player LuaPlayer
function fave_bar.partial_rehydrate(player)
  if not BasicHelpers.is_valid_player(player) then return end
  local pidx = player.index
  local set = dirty_slots[pidx]
  if not set then return end
  for slot_index, _ in pairs(set) do
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
end




-- ============================================================
-- Progressive startup bar builder
-- ============================================================
-- Factorio GUI element creation costs ~0.87 ms per element via the C++ API.
-- Building the full bar (6 chrome + 30 slot elements) synchronously would cost
-- ~31 ms on one tick. Instead, initialization is split into stages processed
-- SLOT_BATCH_SIZE elements per on_nth_tick(2) call so no single tick exceeds ~5 ms.
--
-- Stages in storage._tf_slot_build_queue:
--   stage = "chrome"  → build bar chrome (toggle buttons, slots frame) in one tick
--   stage = "slots"   → add SLOT_BATCH_SIZE slot buttons per tick until done
--
-- In-game updates (teleport, settings change) call fave_bar.build() synchronously
-- and bypass this queue entirely.

-- Each slot creates 2 GUI elements (sprite-button + slot-number label inside it).
-- 2 slots × 2 elements = 4 GUI adds ≈ 3.5 ms — safely under the 5 ms target.
-- Increasing this causes 8+ ms spikes per batch tick.
local SLOT_BATCH_SIZE = 2

--- Called from process_deferred_init_queue (at tick 60+).
--- Creates the bare outer frame (1 element) and enqueues chrome + slots for later ticks.
function fave_bar.enqueue_progressive_build(player)
  if not BasicHelpers.is_valid_player(player) then return end

  -- Create the empty outer frame so the bar area is reserved in the UI.
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow then return end
  local bar_frame = main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  if not bar_frame or not bar_frame.valid then
    bar_frame = GuiBase.create_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR, "vertical", "tf_fave_bar_frame")
  end
  if not bar_frame or not bar_frame.valid then return end

  -- Cancel any existing deferred build for this player.
  storage._tf_slot_build_queue = storage._tf_slot_build_queue or {}
  cancel_progressive_build_for(player.index)

  -- Enqueue chrome1 first; it chains chrome1 → chrome2 → slots automatically.
  table.insert(storage._tf_slot_build_queue, {
    player_index  = player.index,
    surface_index = player.surface.index,
    stage         = "chrome1",
  })
  last_build_tick[player.index] = game.tick
end

--- Called on every on_nth_tick(2); processes one stage per call.
function fave_bar.process_slot_build_queue()
  if not storage or not storage._tf_slot_build_queue then return end
  if #storage._tf_slot_build_queue == 0 then return end

  local entry  = storage._tf_slot_build_queue[1]
  local player = game.players[entry.player_index]
  if not player or not player.valid then
    table.remove(storage._tf_slot_build_queue, 1)
    return
  end

  -- ── Chrome stage 1: bar_flow + toggle_container  (~2 GUI adds ≈ 1.7 ms) ──────
  -- Splitting the 6-element chrome build across two ticks keeps each tick
  -- well under the 5 ms target.  chrome1 → chrome2 → slots.
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
      player_index  = entry.player_index,
      surface_index = entry.surface_index,
      stage         = "chrome2",
    }
    return
  end

  -- ── Chrome stage 2: 3 buttons + slots frame + GPS validation (~4 adds ≈ 3.5 ms) ─
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

    local surface_index = entry.surface_index
    local pfaves        = Cache.get_player_favorites(player, surface_index)
    prune_stale_favorites(player, surface_index, pfaves)

    if slots_frame and slots_frame.valid then slots_frame.visible = slots_vis end

    ProfilerExport.stop_section("pb_chrome2")
    storage._tf_slot_build_queue[1] = {
      player_index   = entry.player_index,
      surface_index  = surface_index,
      stage          = "slots",
      next_slot      = 1,
      expected_built = 0,
    }
    return
  end

  -- ── Legacy chrome stage (kept for queue entries created before the split) ──
  if entry.stage == "chrome" then
    -- Re-queue as the new two-stage chrome.
    storage._tf_slot_build_queue[1] = {
      player_index  = entry.player_index,
      surface_index = entry.surface_index,
      stage         = "chrome1",
    }
    return
  end

  -- ── Slots stage ────────────────────────────────────────────────────────────
  ProfilerExport.start_section("pb_slots")
  local main_flow   = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame   = main_flow and main_flow[Enum.GuiEnum.GUI_FRAME.FAVE_BAR]
  local bar_flow    = bar_frame and bar_frame[Enum.GuiEnum.FAVE_BAR_ELEMENT.FAVE_BAR_FLOW]
  local slots_frame = bar_flow  and bar_flow[Enum.GuiEnum.FAVE_BAR_ELEMENT.SLOTS_FLOW]

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
  local end_idx    = math.min(start_idx + SLOT_BATCH_SIZE - 1, max_slots)

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

--- Clear the build queue on save-load (stale GUI references, fresh state needed).
function fave_bar.on_load_cleanup()
  if storage then
    storage._tf_slot_build_queue = {}
  end
end

-- DEBUG: Log all keys in fave_bar at module load time
if ErrorHandler and ErrorHandler.debug_log then
  local keys = {}
  for k, v in pairs(fave_bar) do table.insert(keys, tostring(k)) end
  ErrorHandler.debug_log("[FAVE_BAR] Exported keys at module load", { keys = table.concat(keys, ", ") })
end

return fave_bar
