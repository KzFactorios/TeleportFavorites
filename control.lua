---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch

--[[
TeleportFavorites Factorio Mod - Control Script
Main event handler and public API entry points.

Features:
- Robust, multiplayer-safe GUI and data handling for favorites, tags, and teleportation.
- Centralized event wiring for all GUIs (favorites bar, tag editor, data viewer).
- EmmyLua-annotated helpers for safe player messaging, teleportation, and GUI frame destruction.
- Move-mode UX for tag editor, with robust state management and multiplayer safety.
- All persistent data access is via the Cache module for consistency and safety.
- All new/changed features are documented inline and in notes/ as appropriate.
]]

-- Import controllers for various mod components
-- Required for favorites bar functionality
local control_fave_bar = require("core.control.control_fave_bar")
-- Required for tag editor functionality
local control_tag_editor = require("core.control.control_tag_editor")
-- Used for data viewer registration
local control_data_viewer = require("core.control.control_data_viewer")

-- Import event handling components
local event_registration_dispatcher = require("core.events.event_registration_dispatcher")
local handlers = require("core.events.handlers")
-- Import error handler for logging
local ErrorHandler = require("core.utils.error_handler")
-- Import enhanced error handler with debug levels
local Logger = require("core.utils.enhanced_error_handler")
-- Import debug commands for runtime control
local DebugCommands = require("core.commands.debug_commands")

local gui_observer = nil
local did_run_fave_bar_startup = false

-- Optional modules - load safely
local success, module = pcall(require, "core.pattern.gui_observer")
if success then gui_observer = module end

-- Log control.lua loading
if log then log("[TeleportFavorites] control.lua loaded") end

-- Development environment initialization removed
-- All dev mode functionality has been removed from the codebase

-- Core lifecycle event registration through centralized dispatcher

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  -- Initialize debug system first
  Logger.initialize()
  
  -- Register debug commands
  DebugCommands.register_commands()
  
  -- Set debug mode based on development indicators
  if storage and storage._tf_debug_mode then
    Logger.info("Development mode detected - enabling debug logging")
  else
    Logger.info("Production mode - using minimal logging")
  end
  
  handlers.on_init()
end

script.on_init(custom_on_init)
script.on_load(handlers.on_load)

-- KEEP THIS CODE for development (disabled in production)
-- Instantly skip any cutscene (including intro) for all players
--script.on_event(defines.events.on_cutscene_started, function(event)
-- Cutscene skipping disabled due to API compatibility issues
-- If needed in development, uncomment and implement for faster testing
--  local player = game.players[event.player_index]
--  player.exit_cutscene()
--end)

-- Register all mod events through centralized dispatcher
event_registration_dispatcher.register_all_events(script)

-- Run-once startup handler for favorites bar initialization

script.on_event(defines.events.on_tick, function(event)
  if not did_run_fave_bar_startup then
    did_run_fave_bar_startup = true
    if gui_observer and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
      for _, player in pairs(game.players) do
        gui_observer.GuiEventBus.register_player_observers(player)
        local freeplay = remote.interfaces["freeplay"]
        if freeplay and freeplay["set_skip_intro"] then
          remote.call("freeplay", "set_skip_intro", true)
        end
        
        -- Hide skip_cutscene_label in any GUI position if it exists
        if player.valid and player.name == "kurtzilla" then
          local success, err = pcall(function()
            -- Check in all possible GUI positions where the label might exist
            for _, gui_type in pairs({"left", "center", "relative", "goal"}) do
              -- Check if this GUI type exists and safely access it
              if player.gui[gui_type] then
                local skip_label = player.gui[gui_type]["skip_cutscene_label"] 
                if skip_label and skip_label.valid then
                  skip_label.visible = false
                  ErrorHandler.debug_log("[STARTUP] Hidden skip_cutscene_label", {
                    player = player.name,
                    gui_type = gui_type
                  })
                  break -- Found and hidden the label, no need to check other locations
                end
              end
            end
          end)
          
          if not success then
            ErrorHandler.warn_log("[STARTUP] Error while hiding skip_cutscene_label", {
              player = player.name,
              error = tostring(err)
            })
          end
        end
      end
    end
    -- Remove this handler after first run
    script.on_event(defines.events.on_tick, nil)
  end
end)

-- Register the TeleportFavorites interface for testing
remote.add_interface("TeleportFavorites", {
  test_button_values = require("tests.test_button_values").log_button_values,
  test_debug_commands = function(player_name)
    local player = game.get_player(player_name)
    if not player then return end
    
    local DebugCommandsTest = require("tests.test_debug_commands")
    local results = DebugCommandsTest.run_all_tests(player)
    DebugCommandsTest.print_results(player, results)
    
    return results
  end,
  test_performance_monitor = function(player_name)
    local player = game.get_player(player_name)
    if not player then return end
    
    local PerfMonitorTest = require("tests.test_dev_performance_monitor")
    local results = PerfMonitorTest.run_all_tests(player)
    PerfMonitorTest.print_results(player, results)
    
    return results
  end
})
