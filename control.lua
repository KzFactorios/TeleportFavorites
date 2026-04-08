---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch, param-type-mismatch, undefined-field


local control_tag_editor = require("core.control.control_tag_editor")
local control_fave_bar = require("core.control.control_fave_bar")
local event_registration_dispatcher = require("core.events.event_registration_dispatcher")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local handlers = require("core.events.handlers")
local TeleportHistory = require("core.teleport.teleport_history")
local ProfilerExport = require("core.utils.profiler_export")

-- Initialize logging immediately using single source of truth
ErrorHandler.initialize(Constants.settings.DEFAULT_LOG_LEVEL)

local gui_observer = nil


-- Optional modules - load safely
local success, module = pcall(require, "core.events.gui_observer")
if success then gui_observer = module end

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  -- Initialize debug system first
  ErrorHandler.initialize(Constants.settings.DEFAULT_LOG_LEVEL)
  ProfilerExport.register_profiling_commands()
  -- Start profiler immediately: storage + helpers.create_profiler are reliable in on_init for new games.
  -- This lets sections inside handlers.on_init() be captured (Cache.init, player setup, etc.).
  ProfilerExport.apply_profile_mode_from_constants()

  -- Register teleport history remote interface
  TeleportHistory.register_remote_interface()

  -- Set debug mode based on development indicators
  if storage and storage._tf_debug_mode then
    ErrorHandler.debug_log("Development mode detected - enabling debug logging")
  else
    ErrorHandler.debug_log("Production mode - using minimal logging")
  end

  handlers.on_init()
end

-- Custom on_load to ensure commands are registered
local function custom_on_load()
  ProfilerExport.register_profiling_commands()
  ProfilerExport.on_load_cleanup()
  require("gui.favorites_bar.fave_bar").on_load_cleanup()
  -- on_init does not run when loading a save; profiler must not start inside on_load (API limits). Defer to first tick.
  ProfilerExport.schedule_deferred_profile_apply()

  -- Register teleport history remote interface
  TeleportHistory.register_remote_interface()

  -- Call the original handlers.on_load
  handlers.on_load()
end

-- Register script lifecycle handlers
script.on_init(function()
  custom_on_init()
end)

script.on_load(function()
  custom_on_load()
end)

script.on_configuration_changed(function(data)
  handlers.on_configuration_changed(data)
  ProfilerExport.apply_profile_mode_from_constants()
end)

-- KEEP THIS CODE for development (disabled in production)
-- Instantly skip any cutscene (including intro) for all players
--script.on_event(defines.events.on_cutscene_started, function(event)
-- Cutscene skipping disabled due to API compatibility issues
-- If needed in development, uncomment and implement for faster testing
--  local player = game.players[event.player_index]
--  player.exit_cutscene()
--end)


ErrorHandler.debug_log("[CONTROL] Registering all mod events through centralized dispatcher", {})
event_registration_dispatcher.register_all_events(script)

-- The dispatcher registers on_tick permanently (no-op after first tick) for observer setup.
-- Profiler auto-stop is handled inside that on_tick via ProfilerExport.on_game_tick (helpers.write_file).
-- on_nth_tick(2) is registered/unregistered dynamically for deferred GUI notification processing.
-- DO NOT register conflicting on_tick or on_nth_tick(2) handlers!



-- TURN THIS OFF BEFORE DEPLOYMENT TO AVOID - Cannot join. The following mod event handlers are not identical between you and the server.
-- This indicates that the following mods are not multiplayer (save/load) safe. (See the log file for more details):

-- TODO TODO TODO TODO TODO
--if script.active_mods["gvv"] then require("__gvv__.gvv")() end
