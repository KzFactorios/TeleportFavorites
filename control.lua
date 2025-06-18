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

-- Optional modules - load safely
local gui_observer

do
  local success, module = pcall(require, "core.pattern.gui_observer")
  if success then gui_observer = module end
end

-- Log control.lua loading
if log then log("[TeleportFavorites] control.lua loaded") end

-- Development environment initialization removed
-- All dev mode functionality has been removed from the codebase

-- Core lifecycle event registration through centralized dispatcher

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  handlers.on_init()
end

script.on_init(custom_on_init)
script.on_load(handlers.on_load)

-- KEEP THIS CODE for development (disabled in production)
-- Instantly skip any cutscene (including intro) for all players
script.on_event(defines.events.on_cutscene_started, function(event)
  -- Cutscene skipping disabled due to API compatibility issues
  -- If needed in development, uncomment and implement for faster testing
  local player = game.players[event.player_index]
  player.exit_cutscene()
end)

-- Register all mod events through centralized dispatcher
event_registration_dispatcher.register_all_events(script)

