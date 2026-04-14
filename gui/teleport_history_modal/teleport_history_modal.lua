---@diagnostic disable: undefined-global

-- gui/teleport_history_modal/teleport_history_modal.lua
-- TeleportFavorites Factorio Mod
-- Modal Teleport History interface for viewing and navigating teleport history.
local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Constants, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.GpsUtils, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local HistoryItem = Cache.HistoryItem
local Lookups = require("core.cache.lookups")
local TeleportHistory = require("core.teleport.teleport_history")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ProfilerExport = require("core.utils.profiler_export")


local teleport_history_modal = {}
if teleport_history_modal._observer_registered == nil then
  teleport_history_modal._observer_registered = false
end

local THM_DIRTY_PLAYERS_KEY = "_tf_thm_dirty_players"
local THM_RENDER_STATE_KEY = "_tf_thm_render_state"
local THM_PROGRESSIVE_ROWS_KEY = "_tf_thm_progressive_rows"
local THM_BUILD_QUEUE_KEY = "_tf_thm_build_queue"
local THM_INITIAL_ROWS = 20
local THM_APPEND_ROWS_PER_PASS = 10
local THM_APPEND_MIN_ROWS = 5
local THM_APPEND_MID_ROWS = 8
local process_progressive_row_jobs

-- Session-local flag: true when any dirty-history or progressive-row work is pending.
-- Avoids the O(#game.players) loops in flush_dirty_history_lists and
-- process_progressive_row_jobs on every on_nth_tick(2) when nothing is queued.
-- Must NOT be stored in storage (session-local only); rehydrated in on_load_cleanup.
local _thm_has_work = false

--- True when any THM queue has pending work (matches `on_load_cleanup` / session flag semantics).
---@return boolean
local function thm_storage_has_pending_work()
  if not storage then return false end
  local build_q = storage[THM_BUILD_QUEUE_KEY]
  local prog_q  = storage[THM_PROGRESSIVE_ROWS_KEY]
  local dirty_q = storage[THM_DIRTY_PLAYERS_KEY]
  return (build_q  and #build_q  > 0)
      or  (prog_q   and next(prog_q)   ~= nil)
      or  (dirty_q  and next(dirty_q)  ~= nil)
end

---@param remaining number
---@return number
local function get_adaptive_append_chunk_size(remaining)
  if remaining > 80 then
    return THM_APPEND_MIN_ROWS
  end
  if remaining > 40 then
    return THM_APPEND_MID_ROWS
  end
  return THM_APPEND_ROWS_PER_PASS
end

---@param action_id string|boolean|nil
local function mark_history_list_dirty(player_index, action_id)
  if not storage then return end
  if type(player_index) ~= "number" then return end
  storage[THM_DIRTY_PLAYERS_KEY] = storage[THM_DIRTY_PLAYERS_KEY] or {}
  storage[THM_DIRTY_PLAYERS_KEY][player_index] = action_id or true
  _thm_has_work = true
end

local function flush_dirty_history_lists()
  if not storage then return end
  local dirty = storage[THM_DIRTY_PLAYERS_KEY]
  if not dirty then return end

  -- Deterministic order across peers: iterate players by numeric index.
  for player_index = 1, #game.players do
    if dirty[player_index] then
      local dirty_action_id = dirty[player_index]
      dirty[player_index] = nil
      local player = game.players[player_index]
      if player and player.valid and teleport_history_modal.is_open(player) then
        teleport_history_modal.update_history_list(player, type(dirty_action_id) == "string" and dirty_action_id or nil)
      end
    end
  end
  -- Nil-out the table when empty so next on_load can detect cleanly.
  if next(dirty) == nil then
    storage[THM_DIRTY_PLAYERS_KEY] = nil
  end
end

---@param player_index number
---@param surface_index number
---@return table|nil
local function get_render_state(player_index, surface_index)
  if not storage then return nil end
  local by_player = storage[THM_RENDER_STATE_KEY]
  if not by_player then return nil end
  local by_surface = by_player[player_index]
  if not by_surface then return nil end
  return by_surface[surface_index]
end

---@param player_index number
---@param surface_index number
---@param state table
local function set_render_state(player_index, surface_index, state)
  if not storage then return end
  storage[THM_RENDER_STATE_KEY] = storage[THM_RENDER_STATE_KEY] or {}
  local by_player = storage[THM_RENDER_STATE_KEY]
  by_player[player_index] = by_player[player_index] or {}
  by_player[player_index][surface_index] = state
end

---@param player_index number
local function clear_render_state_for_player(player_index)
  if not storage then return end
  if not storage[THM_RENDER_STATE_KEY] then return end
  storage[THM_RENDER_STATE_KEY][player_index] = nil
end

---@param player_index number
---@param job table
local function set_progressive_row_job(player_index, job)
  if not storage then return end
  storage[THM_PROGRESSIVE_ROWS_KEY] = storage[THM_PROGRESSIVE_ROWS_KEY] or {}
  storage[THM_PROGRESSIVE_ROWS_KEY][player_index] = job
  _thm_has_work = true
end

---@param player_index number
local function clear_progressive_row_job(player_index)
  if not storage then return end
  if not storage[THM_PROGRESSIVE_ROWS_KEY] then return end
  storage[THM_PROGRESSIVE_ROWS_KEY][player_index] = nil
end

---@param history_list LuaGuiElement
---@param old_pointer number
---@param new_pointer number
---@return boolean
local function update_pointer_highlight(history_list, old_pointer, new_pointer)
  if old_pointer == new_pointer then return true end

  if type(old_pointer) == "number" and old_pointer > 0 then
    local old_btn = GuiValidation.find_child_by_name(
      history_list,
      "teleport_history_item_" .. tostring(old_pointer)
    )
    if old_btn and old_btn.valid then
      ---@diagnostic disable-next-line: assign-type-mismatch
      old_btn.style = "tf_teleport_history_item"
    end
  end

  if type(new_pointer) ~= "number" or new_pointer < 1 then
    return true
  end

  local new_btn = GuiValidation.find_child_by_name(
    history_list,
    "teleport_history_item_" .. tostring(new_pointer)
  )
  if new_btn and new_btn.valid then
    ---@diagnostic disable-next-line: assign-type-mismatch
    new_btn.style = "tf_teleport_history_item_current"
    return true
  end
  -- Fallback: if target row isn't present yet (progressive render timing), force full rebuild path.
  return false
end


--- Check if the teleport history modal is open for the player
---@param player LuaPlayer
---@return boolean
function teleport_history_modal.is_open(player)
  if not BasicHelpers.is_valid_player(player) then return false end
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  return modal_frame and modal_frame.valid or false
end

--- Handles GUI close events for teleport history modal
---@param event table GUI close event from Factorio
function teleport_history_modal.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  if not event.element or not event.element.valid then return end

  -- Fallback for gui_closed_reason if not defined
  local gui_closed_reason = { closed = 0, escaped = 1, switch_guis = 2, unknown = 3 }

  local gui_frame = GuiValidation.get_gui_frame_by_element(event.element)
  if (gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL) or event.element.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
    -- Only clear modal state for user-initiated closes (ESC, close button)
    local reason = event.reason or gui_closed_reason.unknown
    if reason == gui_closed_reason.escaped or reason == gui_closed_reason.closed then
      teleport_history_modal.destroy(player, false) -- user-initiated, clear state
    else
      teleport_history_modal.destroy(player, true)  -- view switch, preserve state
    end
    return
  end
end

-- Stage A: titlebar chrome — flow + label + draggable + close button.
-- Runs on the first on_nth_tick(2) after build().
---@param player LuaPlayer
---@param modal_frame LuaGuiElement
---@param _action_id string|nil
local function build_interior_a(player, modal_frame, _action_id)
  local titlebar = GuiBase.create_element('flow', modal_frame, {
    name = "teleport_history_modal_titlebar",
    direction = "horizontal",
    style = "tf_titlebar_flow"
  })

  GuiBase.create_label(titlebar, "teleport_history_modal_title_label",
    { "tf-gui.teleport_history_modal_title" }, "tf_frame_title")

  local draggable = GuiBase.create_draggable(titlebar, "tf_titlebar_draggable")
  if draggable and draggable.valid then
    draggable.drag_target = modal_frame
  end

  GuiBase.create_icon_button(titlebar, "teleport_history_modal_close_button",
    Enum.SpriteEnum.CLOSE, { "tf-gui.close" }, "tf_frame_action_button")

end

-- Stage B: content frame + scroll pane + history list shell only.
-- Runs on the second on_nth_tick(2) after build().
---@param player LuaPlayer
---@param modal_frame LuaGuiElement
---@param _action_id string|nil
local function build_interior_b(player, modal_frame, _action_id)
  local content_frame = GuiBase.create_frame(modal_frame, "teleport_history_modal_content", "vertical",
    "tf_teleport_history_modal_content")

  local scroll_pane = GuiBase.create_element("scroll-pane", content_frame, {
    name = "teleport_history_scroll_pane",
    direction = "vertical"
  })

  GuiBase.create_frame(scroll_pane, "teleport_history_list", "vertical", "inside_shallow_frame")

  -- Do not set player.opened; ESC key should not close this modal.
  player.opened = nil

end

-- Stage C: populate history list after shell creation.
-- Runs on the third on_nth_tick(2) after build().
---@param player LuaPlayer
---@param modal_frame LuaGuiElement
---@param action_id string|nil
local function build_interior_c(player, modal_frame, action_id)
  teleport_history_modal.update_history_list(player, action_id)
end

--- Build the teleport history modal dialog.
--- Tick 0 (click handler): creates the outer frame and positions it immediately.
--- Interior elements are enqueued for the next on_nth_tick(2).
---@param player LuaPlayer
---@param action_id string|nil
function teleport_history_modal.build(player, action_id)
  -- One-time observer registration (no GUI cost).
  if not teleport_history_modal._observer_registered then
    TeleportHistory.register_observer(function(obs_player)
      if obs_player and obs_player.valid and teleport_history_modal.is_open(obs_player) then
        local ctx_action = ProfilerExport.get_action_trace_id(obs_player.index)
        mark_history_list_dirty(obs_player.index, ctx_action)
      end
    end)
    teleport_history_modal._observer_registered = true
  end

  if not BasicHelpers.is_valid_player(player) then return end
  if not BasicHelpers.is_planet_surface(player.surface) then return end
  local effective_action_id = action_id or ProfilerExport.get_action_trace_id(player.index)

  -- Destroy any existing modal first.
  teleport_history_modal.destroy(player, true)

  local modal_width = 350
  local modal_height = 392

  -- Create the outer frame only — interior is deferred.
  local modal_frame = GuiBase.create_frame(
    player.gui.screen,
    Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL,
    "vertical",
    "tf_teleport_history_modal_frame"
  )

  if not modal_frame or not modal_frame.valid then
    ErrorHandler.debug_log("CRITICAL: Modal frame creation failed", {
      modal_frame_nil = modal_frame == nil,
      modal_frame_valid = modal_frame and modal_frame.valid or false,
      player_valid = player and player.valid,
      screen_valid = player.gui and player.gui.screen and player.gui.screen.valid
    })
    return
  end

  -- Position immediately so the frame appears in the right place even before interior renders.
  local pos = Cache.get_history_modal_position(player)
  if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
    local screen_resolution = player.display_resolution
    local screen_scale = player.display_scale
    local x = (screen_resolution.width / screen_scale - modal_width) / 2
    local y = (screen_resolution.height / screen_scale - modal_height) / 2
    modal_frame.location = { x = x, y = y }
    Cache.set_history_modal_position(player, { x = x, y = y })
  else
    modal_frame.location = { x = pos.x, y = pos.y }
  end

  -- Enqueue interior build for the next on_nth_tick(2).
  storage[THM_BUILD_QUEUE_KEY] = storage[THM_BUILD_QUEUE_KEY] or {}
  for i = #storage[THM_BUILD_QUEUE_KEY], 1, -1 do
    if storage[THM_BUILD_QUEUE_KEY][i].player_index == player.index then
      table.remove(storage[THM_BUILD_QUEUE_KEY], i)
    end
  end
  table.insert(storage[THM_BUILD_QUEUE_KEY], {
    player_index = player.index,
    stage = "a",
    action_id = effective_action_id,
  })
  _thm_has_work = true

  return modal_frame
end

--- Called from on_nth_tick(2). Pops one queued THM build entry and advances it one stage.
-- Stage "a": builds titlebar chrome, re-enqueues stage "b" at the front.
-- Stage "b": builds content frame + list shell.
-- Stage "c": populates history list.
function teleport_history_modal.process_build_queue()
  -- Derive work from storage — do not skip when `_thm_has_work` is stale (MP parity with favorites bar queue).
  if not storage then return end
  if not thm_storage_has_pending_work() then
    _thm_has_work = false
    return
  end
  _thm_has_work = true

  storage[THM_BUILD_QUEUE_KEY] = storage[THM_BUILD_QUEUE_KEY] or {}
  if #storage[THM_BUILD_QUEUE_KEY] > 0 then
    local entry = table.remove(storage[THM_BUILD_QUEUE_KEY], 1)
    local player = game.players[entry.player_index]
    if player and player.valid then
      local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
      if modal_frame and modal_frame.valid then
        if entry.stage == "a" then
          build_interior_a(player, modal_frame, entry.action_id)
          -- Insert stage B at the front so it runs on the very next on_nth_tick(2).
          table.insert(storage[THM_BUILD_QUEUE_KEY], 1, {
            player_index = player.index,
            stage        = "b",
            action_id    = entry.action_id,
          })
        elseif entry.stage == "b" then
          build_interior_b(player, modal_frame, entry.action_id)
          -- Insert stage C at the front so it runs on the very next on_nth_tick(2).
          table.insert(storage[THM_BUILD_QUEUE_KEY], 1, {
            player_index = player.index,
            stage        = "c",
            action_id    = entry.action_id,
          })
        elseif entry.stage == "c" then
          build_interior_c(player, modal_frame, entry.action_id)
        end
      end
    end
  end

  -- Append progressive rows in bounded chunks after first paint.
  process_progressive_row_jobs()

  -- Flush coalesced observer updates once per on_nth_tick(2).
  flush_dirty_history_lists()

  -- Re-evaluate flag: clear it if all three queues are now empty.
  local build_q = storage[THM_BUILD_QUEUE_KEY]
  local prog_q  = storage[THM_PROGRESSIVE_ROWS_KEY]
  local dirty_q = storage[THM_DIRTY_PLAYERS_KEY]
  if (not build_q or #build_q == 0)
      and (not prog_q  or next(prog_q)  == nil)
      and (not dirty_q or next(dirty_q) == nil) then
    _thm_has_work = false
  end
end

--- Destroy the teleport history modal
---@param player LuaPlayer|nil
---@param preserve_state boolean|nil If true, do not clear modal dialog state in cache
function teleport_history_modal.destroy(player, preserve_state)
  if not player or not player.valid then return end
  if not BasicHelpers.is_valid_player(player) then return end
  -- Always clear modal dialog state when closing teleport history modal (should never block input)
  Cache.set_modal_dialog_state(player, nil)

  -- Close the modal if it exists
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if modal_frame and modal_frame.valid then
    -- Save modal position before destroying (do not attempt to read style.width/height)
    if modal_frame.location and type(modal_frame.location.x) == "number" and type(modal_frame.location.y) == "number" then
      Cache.set_history_modal_position(player, { x = modal_frame.location.x, y = modal_frame.location.y })
    end
    player.opened = nil
    modal_frame.destroy()
  end
  ProfilerExport.end_action_trace(player.index, nil)
  clear_progressive_row_job(player.index)
  clear_render_state_for_player(player.index)
end

---@param modal_frame LuaGuiElement
---@return LuaGuiElement|nil
local function resolve_history_list(modal_frame)
  local content = modal_frame["teleport_history_modal_content"]
  if content and content.valid then
    local scroll_pane = content["teleport_history_scroll_pane"]
    if scroll_pane and scroll_pane.valid then
      local history_list = scroll_pane["teleport_history_list"]
      if history_list and history_list.valid then
        return history_list
      end
    end
  end
  return GuiValidation.find_child_by_name(modal_frame, "teleport_history_list")
end

---@param history_list LuaGuiElement
---@param player LuaPlayer
---@param entry table
---@param index number
---@param pointer number
local function create_history_row(history_list, player, entry, index, pointer)
  local is_current = (index == pointer)
  local coords_string = GPSUtils.coords_string_from_gps(entry.gps)
  local chart_tag = Lookups.get_chart_tag_by_gps(entry.gps)
  local tag_icon = chart_tag and chart_tag.icon

  local row_flow = GuiBase.create_element("flow", history_list, {
    name = "teleport_history_row_" .. tostring(index),
    direction = "horizontal",
    style = "tf_teleport_history_flow"
  })

  local trash_button = GuiBase.create_icon_button(row_flow,
    "teleport_history_trash_button_" .. tostring(index),
    Enum.SpriteEnum.TRASH,
    { "tf-gui.delete_tooltip" },
    "tf_teleport_history_trash_button", true)
  if trash_button and trash_button.valid then
    trash_button.tags = { teleport_history_index = index }
  end

  local button_style = is_current and "tf_teleport_history_item_current" or "tf_teleport_history_item"
  local button_name = "teleport_history_item_" .. tostring(index)
  local chart_tag_text = chart_tag and chart_tag.text or ""
  local max_label_len = tonumber(Constants.settings.TELEPORT_HISTORY_LABEL_MAX_DISPLAY) or 27
  local truncated_text = BasicHelpers.truncate_rich_text(chart_tag_text, max_label_len)

  local icon_prefix = ""
  if tag_icon and tag_icon.name then
    icon_prefix = ChartTagUtils.format_icon_as_rich_text(tag_icon) .. " "
  end

  local date_string = HistoryItem.get_locale_time(player, entry)

  local display_text = icon_prefix .. truncated_text .. "   " .. (coords_string or entry.gps or "Invalid GPS")
    .. "  [font=tf_font_8][color=0.4,0.4,0.4]" .. date_string .. "[/color][/font]"

  local success_button, item_button = pcall(function()
    return GuiBase.create_button(
      row_flow,
      button_name,
      display_text,
      button_style
    )
  end)
  if success_button and item_button and item_button.valid then
    local coords_str = tostring(coords_string or entry.gps or "")
    item_button.tooltip = { "tf-gui.teleport_history_item_tooltip", coords_str }
    item_button.tags = { teleport_history_index = index }
  end
end

process_progressive_row_jobs = function()
  if not storage then return end
  local jobs = storage[THM_PROGRESSIVE_ROWS_KEY]
  if not jobs then return end
  if next(jobs) == nil then return end

  for player_index = 1, #game.players do
    local job = jobs[player_index]
    if job then
      local player = game.players[player_index]
      if not player or not player.valid or not teleport_history_modal.is_open(player) then
        if job.action_id then
          ProfilerExport.end_action_trace(player_index, job.action_id)
        end
        jobs[player_index] = nil
      else
        local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
        local history_list = modal_frame and modal_frame.valid and resolve_history_list(modal_frame) or nil
        local current_surface = player.surface and player.surface.valid and player.surface.index or nil
        if not history_list or not history_list.valid or current_surface ~= job.surface_index then
          if job.action_id then
            ProfilerExport.end_action_trace(player_index, job.action_id)
          end
          jobs[player_index] = nil
        else
          local hist = Cache.get_player_teleport_history(player, job.surface_index)
          local stack = hist and hist.stack or nil
          local stack_revision = tonumber(hist and hist.stack_revision) or 0
          if not stack
              or stack_revision ~= job.stack_revision
              or job.next_index < 1
              or job.next_index > #stack then
            if job.action_id then
              ProfilerExport.end_action_trace(player_index, job.action_id)
            end
            jobs[player_index] = nil
            mark_history_list_dirty(player_index, job.action_id)
          else
            local pointer = hist.pointer
            local remaining_rows = job.next_index
            local chunk_size = get_adaptive_append_chunk_size(remaining_rows)
            local stop_index = math.max(1, job.next_index - chunk_size + 1)
            for i = job.next_index, stop_index, -1 do
              local entry = stack[i]
              if entry and type(entry) == "table" and entry.gps then
                create_history_row(history_list, player, entry, i, pointer)
              end
            end
            job.next_index = stop_index - 1
            set_render_state(player_index, job.surface_index, {
              stack_revision = stack_revision,
              stack_size = #stack,
              pointer = pointer,
            })
            if job.next_index < 1 then
              if job.action_id then
                ProfilerExport.end_action_trace(player_index, job.action_id)
              end
              jobs[player_index] = nil
            end
          end
        end
      end
    end
  end
end

--- Update the history list display
---@param player LuaPlayer
---@param action_id string|nil
function teleport_history_modal.update_history_list(player, action_id)
  local effective_action_id = action_id or ProfilerExport.get_action_trace_id(player and player.index or nil)
  if not BasicHelpers.is_valid_player(player) then
    return
  end

  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if not modal_frame or not modal_frame.valid then
    return
  end

  local history_list = resolve_history_list(modal_frame)
  if not history_list or not history_list.valid then
    return
  end

  -- Get teleport history for current surface
  local surface_index = player.surface.index
  local hist = Cache.get_player_teleport_history(player, surface_index)
  local stack = hist.stack
  local pointer = hist.pointer
  local stack_revision = tonumber(hist.stack_revision) or 0
  local prior = get_render_state(player.index, surface_index)

  -- Fast path: same stack content and size, only pointer changed (or no change at all).
  if prior
      and prior.stack_revision == stack_revision
      and prior.stack_size == #stack then
    if prior.pointer == pointer then
      return
    end
    if update_pointer_highlight(history_list, prior.pointer, pointer) then
      prior.pointer = pointer
      set_render_state(player.index, surface_index, prior)
      if effective_action_id then
        ProfilerExport.end_action_trace(player.index, effective_action_id)
      end
      return
    end
  end

  -- Full rebuild path.
  -- Clear existing list items in deterministic order
  -- CRITICAL: Use deterministic iteration, not pairs() - prevents multiplayer desyncs
  local children = history_list.children
  for i = #children, 1, -1 do
    if children[i] and children[i].valid then
      children[i].destroy()
    end
  end

  if #stack == 0 then
    clear_progressive_row_job(player.index)
    GuiBase.create_label(history_list, "empty_history_label",
      { "tf-gui.teleport_history_empty" }, "tf_teleport_history_empty_label")
    set_render_state(player.index, surface_index, {
      stack_revision = stack_revision,
      stack_size = 0,
      pointer = 0,
    })
    if effective_action_id then
      ProfilerExport.end_action_trace(player.index, effective_action_id)
    end
    return
  end

  -- Initial paint: render a bounded number of newest rows.
  local initial_count = math.min(#stack, THM_INITIAL_ROWS)
  local first_index = #stack
  local last_index = #stack - initial_count + 1
  for i = first_index, last_index, -1 do
    local entry = stack[i]
    if entry and type(entry) == "table" and entry.gps then
      create_history_row(history_list, player, entry, i, pointer)
    end
  end

  local next_index = last_index - 1
  if next_index >= 1 then
    set_progressive_row_job(player.index, {
      surface_index = surface_index,
      stack_revision = stack_revision,
      next_index = next_index,
      action_id = effective_action_id,
    })
  else
    if effective_action_id then
      ProfilerExport.end_action_trace(player.index, effective_action_id)
    end
    clear_progressive_row_job(player.index)
  end

  set_render_state(player.index, surface_index, {
    stack_revision = stack_revision,
    stack_size = #stack,
    pointer = pointer,
  })
end

--- Rehydrate session-local state from storage after an on_load event.
--- Must NOT mutate storage (Factorio CRC / multiplayer safety rule).
--- Only reads storage to decide whether any work is pending for _thm_has_work.
function teleport_history_modal.on_load_cleanup()
  if not storage then
    _thm_has_work = false
    return
  end
  _thm_has_work = thm_storage_has_pending_work()
end

return teleport_history_modal
