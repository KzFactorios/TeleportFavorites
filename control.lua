---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch, param-type-mismatch, undefined-field

local util = require("util")
local control_tag_editor = require("core.control.control_tag_editor")
local control_fave_bar = require("core.control.control_fave_bar")
local event_registration_dispatcher = require("core.events.event_registration_dispatcher")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local handlers = require("core.events.handlers")
local TeleportHistory = require("core.teleport.teleport_history")

-- Initialize logging immediately using single source of truth
ErrorHandler.initialize(Constants.settings.DEFAULT_LOG_LEVEL)
ErrorHandler.debug_log("[CONTROL] control.lua loaded", { level = tostring(Constants.settings.DEFAULT_LOG_LEVEL) })


local gui_observer = nil


-- Optional modules - load safely
local success, module = pcall(require, "core.events.gui_observer")
if success then gui_observer = module end

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  -- Register teleport history remote interface
  TeleportHistory.register_remote_interface()

  -- Set debug mode based on development indicators
  local configured_level = (Constants and Constants.settings and Constants.settings.DEFAULT_LOG_LEVEL) or "production"
  local storage_flag = storage and storage._tf_debug_mode
  if storage_flag then
    ErrorHandler.debug_log("Development mode detected via storage._tf_debug_mode - enabling debug logging", { configured_level = configured_level })
  else
    ErrorHandler.debug_log("Startup log mode", { configured_level = configured_level, storage_debug_flag = tostring(storage_flag) })
  end

  handlers.on_init()
end

-- Custom on_load to ensure commands are registered
local function custom_on_load()
  
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

-- UPS OPTIMIZATION: on_tick handler eliminated (was 60 no-op dispatches/sec).
-- Observer setup now happens in on_nth_tick(60) alongside the deferred init queue.
-- on_nth_tick(2) is permanently registered for deferred GUI notification processing.
-- DO NOT register conflicting on_nth_tick(2) or on_nth_tick(60) handlers!



-- TURN THIS OFF BEFORE DEPLOYMENT TO AVOID - Cannot join. The following mod event handlers are not identical between you and the server. 
-- This indicates that the following mods are not multiplayer (save/load) safe. (See the log file for more details):

-- TODO TODO TODO TODO TODO
--if script.active_mods["gvv"] then require("__gvv__.gvv")() end
