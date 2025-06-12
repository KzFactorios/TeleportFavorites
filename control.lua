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

-- Log control.lua loading
---@diagnostic disable-next-line: need-check-nil
if _G.log then _G.log("[TeleportFavorites] control.lua loaded") end

-- Modular event handler registration
local handlers = require("core.events.handlers")

-- Observer Pattern Integration
local function setup_observers_for_player(player)
  local success, gui_observer = pcall(require, "core.pattern.gui_observer")
  if not success then
    if _G.log then _G.log("[TeleportFavorites] Failed to require gui_observer: " .. tostring(gui_observer)) end
    return
  end
  
  if gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
    gui_observer.GuiEventBus.register_player_observers(player)
  else
    if _G.log then _G.log("[TeleportFavorites] GuiEventBus or register_player_observers not available") end
  end
end

local function cleanup_observers_for_player(player_index)
  local success, gui_observer = pcall(require, "core.pattern.gui_observer")
  if not success then
    if _G.log then _G.log("[TeleportFavorites] Failed to require gui_observer: " .. tostring(gui_observer)) end
    return
  end
  
  if gui_observer.GuiEventBus and gui_observer.GuiEventBus.cleanup_all then
    -- For now, clean up all observers since there's no player-specific cleanup
    gui_observer.GuiEventBus.cleanup_all()
  else
    if _G.log then _G.log("[TeleportFavorites] GuiEventBus or cleanup_all not available") end
  end
end

local script = _G.script

-- Import controllers for various mod components
local control_fave_bar = require("core.control.control_fave_bar")      -- Required for favorites bar functionality
local control_tag_editor = require("core.control.control_tag_editor")   -- Required for tag editor functionality
local control_data_viewer = require("core.control.control_data_viewer") -- Used for data viewer registration

-- Import event handling components
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local on_gui_closed_handler = require("core.events.on_gui_closed_handler")

-- Import mod constants and settings
local Constants = require("constants")
local Settings = require("settings")

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  handlers.on_init()
end

-- Core lifecycle and area selection event wiring

-- Handle player join or creation events with a common function
local function handle_player_join_or_create(event)
  handlers.on_player_created(event)
  ---@type LuaPlayer?
  local player = game.get_player(event.player_index)
  if player and player.valid then
    setup_observers_for_player(player)
  end
end

script.on_init(custom_on_init)
script.on_load(handlers.on_load)
script.on_event(_G.defines.events.on_player_created, handle_player_join_or_create)
script.on_event(_G.defines.events.on_player_changed_surface, handlers.on_player_changed_surface)
script.on_event(_G.defines.events.on_player_selected_area, handlers.on_player_selected_area)
script.on_event(_G.defines.events.on_player_joined_game, handle_player_join_or_create)
script.on_event("tf-open-tag-editor", handlers.on_open_tag_editor_custom_input)

-- KEEP THIS CODE for development (disabled in production)
-- Instantly skip any cutscene (including intro) for all players
-- script.on_event(_G.defines.events.on_cutscene_started, function(event)
--   -- Cutscene skipping disabled due to API compatibility issues
--   -- If needed in development, uncomment and implement for faster testing
-- end)

-- Handle mod setting changes
script.on_event(_G.defines.events.on_runtime_mod_setting_changed, function(event)
  -- Get the fave_bar module only when needed
  local fave_bar = require("gui.favorites_bar.fave_bar")
  
  -- Handle changes to the favorites on/off setting
  if event.setting == "favorites-on" then
    for _, player in pairs(game.connected_players) do
      -- Update the favorites bar visibility based on the setting
      local player_settings = Settings.getPlayerSettings(player)
      if player_settings.favorites_on then
        -- Show or rebuild the favorites bar
        fave_bar.build(player, player.gui.top)
      else
        -- Hide the favorites bar
        fave_bar.destroy(player)
      end
    end
    return
  end
  
  -- Handle changes to the teleport radius
  if event.setting == "teleport-radius" then
    -- No UI needs updating, but we could log the change
    if _G.log then _G.log("[TeleportFavorites] Teleport radius setting changed for player " .. event.player_index) end
    return
  end
  
  -- Handle changes to the destination message setting
  if event.setting == "destination-msg-on" then
    -- This setting affects messaging only, no UI changes required
    if _G.log then _G.log("[TeleportFavorites] Destination message setting changed for player " .. event.player_index) end
    return
  end
end)

-- Register data viewer hotkey and GUI events
control_data_viewer.register(script)

-- Register the shared GUI event handler for all GUIs
-- Pass both script and defines so gui_event_dispatcher can register the dispatcher
gui_event_dispatcher.register_gui_handlers(script)

-- Register custom input (keyboard shortcut) handlers
custom_input_dispatcher.register_default_inputs(script)

-- Register on_gui_closed handler for ESC key/modal close support
script.on_event(_G.defines.events.on_gui_closed, on_gui_closed_handler.on_gui_closed)

-- Clean up command history and observers when players leave
script.on_event(_G.defines.events.on_player_left_game, function(event)
  local WorkingCommandManager = require("core.pattern.working_command_manager")
  WorkingCommandManager.cleanup_player_history(event.player_index)
  cleanup_observers_for_player(event.player_index)
end)
