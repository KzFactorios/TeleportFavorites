---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch, param-type-mismatch, undefined-field

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

local success, module = pcall(require, "core.events.gui_observer")
if success then gui_observer = module end


local function register_commands()
  DebugCommands.register_commands()
  DeleteFavoriteCommand.register_commands()
end


local function custom_on_init()
  ErrorHandler.initialize()

  register_commands()

  TeleportHistory.register_remote_interface()

  if storage and storage._tf_debug_mode then
    ErrorHandler.info("Development mode detected - enabling debug logging")
  else
    ErrorHandler.info("Production mode - using minimal logging")
  end

  handlers.on_init()
end

local function custom_on_load()
  register_commands()

  TeleportHistory.register_remote_interface()

  handlers.on_load()
end

script.on_init(function()
  custom_on_init()
end)

script.on_load(function()
  custom_on_load()
end)



event_registration_dispatcher.register_all_events(script)

script.on_event(defines.events.on_tick, function(event)
  if not did_run_fave_bar_startup then
    did_run_fave_bar_startup = true
    if gui_observer and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
      for _, player in pairs(game.players) do
        gui_observer.GuiEventBus.register_player_observers(player)
      end
    end
    script.on_event(defines.events.on_tick, nil)
  end
end)

if script.active_mods["gvv"] then require("__gvv__.gvv")() end
