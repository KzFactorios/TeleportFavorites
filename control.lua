---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch, param-type-mismatch, undefined-field

-- control.lua
-- TeleportFavorites Factorio Mod
-- Main event handler and public API entry point for the mod.
-- Centralizes event registration, GUI wiring, and lifecycle management for multiplayer-safe operation.
-- All persistent data access is via the Cache module for consistency and safety.
-- Integrates favorites bar, tag editor, teleport history, debug commands, and GUI observers.
-- All new/changed features are documented inline and in .project/ as appropriate.

-- Import controllers for various mod components

-- Required for favorites bar functionality
local control_tag_editor = require("core.control.control_tag_editor")
local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")


local event_registration_dispatcher = require("core.events.event_registration_dispatcher")
local handlers = require("core.events.handlers")
local ErrorHandler = require("core.utils.error_handler")
local DebugCommands = require("core.commands.debug_commands")
local DeleteFavoriteCommand = require("core.commands.delete_favorite_command")
local TeleportHistory = require("core.teleport.teleport_history")


local gui_observer = nil
local did_run_fave_bar_startup = false

-- Optional modules - load safely
local success, module = pcall(require, "core.events.gui_observer")
if success then gui_observer = module end

-- Register all commands

local function register_commands()
  -- Register debug commands
  DebugCommands.register_commands()
  -- Register delete favorite command
  DeleteFavoriteCommand.register_commands()
end

-- Core lifecycle event registration through centralized dispatcher

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  -- Initialize debug system first
  ErrorHandler.initialize()

  -- Register all commands
  register_commands()
  
  -- Register teleport history remote interface
  TeleportHistory.register_remote_interface()

  -- Set debug mode based on development indicators
  if storage and storage._tf_debug_mode then
    ErrorHandler.info("Development mode detected - enabling debug logging")
  else
    ErrorHandler.info("Production mode - using minimal logging")
  end

  handlers.on_init()
end

-- Custom on_load to ensure commands are registered
local function custom_on_load()
  -- Register all commands
  register_commands()
  
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
      end
    end
    -- Remove this handler after first run
    script.on_event(defines.events.on_tick, nil)
  end
end)

if script.active_mods["gvv"] then require("__gvv__.gvv")() end
