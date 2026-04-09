---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch, undefined-field
-- core/utils/profiler_export.lua
-- Lua profiler capture with optional auto-stop. Auto-stop uses storage + on_tick (not on_nth_tick),
-- because on_nth_tick(period) fires on tick % period == 0; it does not mean "once after N ticks".
--
-- Factorio 2.x: LuaProfiler has no :report(); embed it in a LocalisedString for helpers.write_file.
-- File output uses helpers.write_file (not game.write_file). Profiling uses helpers.create_profiler.

local Constants = require("constants")

local M = {}

---@type any
local active_profiler = nil
---@type uint|nil
local active_profiler_started_tick = nil

-- Section profiling: named sub-profilers for startup phase breakdown.
-- Each entry in section_results: { name=string, profiler=any, start_tick=uint, end_tick=uint }
local section_profilers = {}
local section_results = {}

local STORAGE_END_KEY = "_tf_profile_end_tick"
-- Legacy saves may still have this key; clear it on first tick in on_game_tick (never during on_load).
local LEGACY_DEFER_APPLY_KEY = "_tf_defer_profile_apply"
-- Set in schedule_deferred_profile_apply (on_load only); consumed on first on_game_tick. Must not use storage during on_load.
local defer_profile_apply_next_tick = false
local commands_registered = false

local function profiler_mode()
  return tostring(Constants.settings.PROFILER_CONTROL_MODE or "off")
end

local function profiler_auto_stop_ticks()
  local raw_value = tonumber(Constants.settings.PROFILER_MAX_TICKS) or 0
  if raw_value < 0 then
    return 0
  end
  return math.floor(raw_value)
end

local function profile_file_name()
  return tostring(Constants.settings.PROFILER_OUTPUT_FILE or "teleport-favorites-profile.txt")
end

local function profile_notify(player_index, message)
  local player = player_index and game.get_player(player_index) or nil
  if player then
    player.print(message)
    return
  end
  log(message)
end

function M.start_profiler_capture(player_index)
  if active_profiler then
    return false
  end

  local ok, prof_or_err = pcall(function()
    return helpers.create_profiler() -- no arg = start running immediately
  end)
  if not ok or not prof_or_err then
    log("[TeleportFavorites] helpers.create_profiler failed: " .. tostring(prof_or_err))
    return false
  end
  active_profiler = prof_or_err
  active_profiler_started_tick = game.tick
  log("[TeleportFavorites] LuaProfiler capture started at tick " .. tostring(game.tick))
  return true
end

--- Begin timing a named section. No-op if no main profiler is active.
---@param name string
function M.start_section(name)
  if not active_profiler then return end
  if section_profilers[name] then return end
  local ok, prof = pcall(function() return helpers.create_profiler() end)
  if ok and prof then
    section_profilers[name] = { profiler = prof, start_tick = game.tick }
  end
end

--- Stop a named section and record its result for the final report.
---@param name string
function M.stop_section(name)
  local entry = section_profilers[name]
  if not entry then return end
  pcall(function() entry.profiler.stop() end)
  table.insert(section_results, {
    name = name,
    profiler = entry.profiler,
    start_tick = entry.start_tick,
    end_tick = game.tick,
  })
  section_profilers[name] = nil
end

--- Write profiler output; falls back to header-only text if embed/write fails.
---@param payload table LocalisedString array
---@param filename string
local function write_profiler_file(payload, filename)
  local ok, err = pcall(function()
    helpers.write_file(filename, payload, false)
  end)
  if ok then
    return true
  end
  log("[TeleportFavorites] helpers.write_file (with LuaProfiler) failed: " .. tostring(err))
  local ok2, err2 = pcall(function()
    helpers.write_file(
      filename,
      payload[2] .. "(Could not embed LuaProfiler in file; see factorio-current.log.)\n",
      false
    )
  end)
  if not ok2 then
    log("[TeleportFavorites] helpers.write_file fallback failed: " .. tostring(err2))
  end
  return ok
end

function M.stop_profiler_capture(player_index)
  if not active_profiler then
    return false
  end

  local profiler = active_profiler
  local ok_stop, err_stop = pcall(function()
    profiler.stop()
  end)
  if not ok_stop then
    log("[TeleportFavorites] LuaProfiler stop() failed: " .. tostring(err_stop))
  end

  local elapsed = 0
  local start_tick = active_profiler_started_tick or 0
  if active_profiler_started_tick then
    elapsed = game.tick - active_profiler_started_tick
  end

  local header = "TeleportFavorites profile report\n"
    .. "Started at:    tick " .. tostring(start_tick) .. "\n"
    .. "Stopped at:    tick " .. tostring(game.tick) .. "\n"
    .. "Ticks elapsed: " .. tostring(elapsed) .. " (" .. tostring(math.floor(elapsed / 60)) .. "s at 60 UPS)\n\n"

  -- Build LocalisedString payload: overall profiler + any named sections.
  -- Factorio hard-caps any single LocalisedString array at 20 parameters.
  -- Strategy: payload = { "", header, overall_block, sections_title, chunk1, chunk2, ... }
  --   payload slots 1-4 are fixed (5 elements including ""); remaining 15 slots hold section chunks.
  --   Each chunk: { "", entry1, ..., entry17 } = 18 elements ≤ 20.
  --   Max sections = 15 chunks × 17 entries = 255 (far more than needed).
  local PAYLOAD_FIXED = 5   -- "", header, "== Overall ==\n", profiler, "\n"
  local PAYLOAD_TITLE = 1   -- "\n== Startup Sections ==\n"
  local PAYLOAD_MAX   = 20  -- Factorio hard cap
  local CHUNK_ENTRIES = 17  -- entries per chunk (+ 1 leading "" = 18 elements ≤ 20)
  local CHUNK_SLOTS   = PAYLOAD_MAX - PAYLOAD_FIXED - PAYLOAD_TITLE  -- 14 chunk slots

  local payload = { "", header, "== Overall ==\n", profiler, "\n" }
  if #section_results > 0 then
    table.insert(payload, "\n== Startup Sections ==\n")
    local current_chunk = { "" }
    for _, sec in ipairs(section_results) do
      local sec_elapsed = sec.end_tick - sec.start_tick
      local label = string.format(
        "  [%-30s]  tick %d \xE2\x86\x92 %d  (%d ticks, ~%ds)\n    ",
        sec.name, sec.start_tick, sec.end_tick, sec_elapsed, math.floor(sec_elapsed / 60)
      )
      table.insert(current_chunk, { "", label, sec.profiler, "\n" })
      if #current_chunk > CHUNK_ENTRIES then
        if #payload < PAYLOAD_MAX then
          table.insert(payload, current_chunk)
        end
        current_chunk = { "" }
      end
    end
    if #current_chunk > 1 and #payload < PAYLOAD_MAX then
      table.insert(payload, current_chunk)
    end
  end

  -- Embed start tick in filename so each run produces a distinct file.
  local base = profile_file_name()
  local stem, ext = base:match("^(.+)(%.[^%.]+)$")
  local filename = stem and (stem .. "-t" .. tostring(start_tick) .. ext) or (base .. "-t" .. tostring(start_tick))
  write_profiler_file(payload, filename)

  active_profiler = nil
  active_profiler_started_tick = nil
  section_profilers = {}
  section_results = {}
  profile_notify(player_index, "[TeleportFavorites] Profile saved to script-output/" .. filename)
  return true
end

function M.clear_profile_auto_stop()
  if storage then
    storage[STORAGE_END_KEY] = nil
  end
end

function M.arm_profile_auto_stop_from_settings()
  M.clear_profile_auto_stop()
  local max_ticks = profiler_auto_stop_ticks()
  if max_ticks <= 0 or not active_profiler then
    return
  end
  if storage then
    storage[STORAGE_END_KEY] = game.tick + max_ticks
  end
end

--- After load only: start profiler on first `on_game_tick`. Uses session-local flag — never writes `storage` in `on_load`.
function M.schedule_deferred_profile_apply()
  if profiler_mode() ~= "profile" then
    return
  end
  defer_profile_apply_next_tick = true
  log("[TeleportFavorites] PROFILER_CONTROL_MODE=profile: deferred capture will start on first tick (new game or load).")
end

--- Call from the single mod on_tick handler (event_registration_dispatcher).
---@param event { tick: uint }
function M.on_game_tick(event)
  if not storage then
    return
  end

  if defer_profile_apply_next_tick then
    defer_profile_apply_next_tick = false
    M.apply_profile_mode_from_constants()
  elseif storage[LEGACY_DEFER_APPLY_KEY] then
    storage[LEGACY_DEFER_APPLY_KEY] = nil
    M.apply_profile_mode_from_constants()
  end

  if not storage[STORAGE_END_KEY] then
    return
  end
  if not active_profiler then
    storage[STORAGE_END_KEY] = nil
    return
  end
  local end_tick = storage[STORAGE_END_KEY]
  if event.tick < end_tick then
    return
  end

  storage[STORAGE_END_KEY] = nil
  if M.stop_profiler_capture(nil) then
    profile_notify(nil, "[TeleportFavorites] Auto profile window complete.")
  end
end

--- Profiler userdata does not persist across save/load. Must not mutate `storage` here (Factorio on_load CRC rule).
function M.on_load_cleanup()
  defer_profile_apply_next_tick = false
  active_profiler = nil
  active_profiler_started_tick = nil
  section_profilers = {}
  section_results = {}
end

function M.apply_profile_mode_from_constants()
  if profiler_mode() ~= "profile" then
    M.clear_profile_auto_stop()
    return
  end

  if M.start_profiler_capture(nil) then
    local max_ticks = profiler_auto_stop_ticks()
    if max_ticks > 0 then
      profile_notify(nil, "[TeleportFavorites] Auto profiler started. Auto-stop in " .. tostring(max_ticks) .. " ticks.")
    else
      profile_notify(nil, "[TeleportFavorites] Auto profiler started. Auto-stop disabled (PROFILER_MAX_TICKS = 0).")
    end
  end
  M.arm_profile_auto_stop_from_settings()
end

function M.cmd_tf_profile_start(cmd)
  if not M.start_profiler_capture(cmd.player_index) then
    profile_notify(cmd.player_index, "[TeleportFavorites] Profiler is already running. Use /tf_profile_stop first.")
    return
  end
  M.arm_profile_auto_stop_from_settings()
  profile_notify(cmd.player_index, "[TeleportFavorites] Profiler started.")
end

function M.cmd_tf_profile_stop(cmd)
  M.clear_profile_auto_stop()
  if not M.stop_profiler_capture(cmd.player_index) then
    profile_notify(cmd.player_index, "[TeleportFavorites] No active profiler. Run /tf_profile_start first.")
    return
  end
end

function M.register_profiling_commands()
  if commands_registered then
    return
  end
  commands_registered = true
  commands.add_command(
    "tf_profile_start",
    "Start TeleportFavorites profiling capture.",
    M.cmd_tf_profile_start
  )
  commands.add_command(
    "tf_profile_stop",
    "Stop profiling and save report to script-output.",
    M.cmd_tf_profile_stop
  )
end

return M
