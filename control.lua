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

-- Modular event handler registration
local handlers = require("core.events.handlers")

local script = _G.script
local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local control_data_viewer = require("core.control.control_data_viewer")

control_fave_bar.register(script)
control_tag_editor.register(script)
control_data_viewer.register(script)

-- Core lifecycle and area selection event wiring
script.on_init(handlers.on_init)
script.on_load(handlers.on_load)
script.on_event(_G.defines.events.on_player_created, handlers.on_player_created)
script.on_event(_G.defines.events.on_player_changed_surface, handlers.on_player_changed_surface)
script.on_event(_G.defines.events.on_player_selected_area, handlers.on_player_selected_area)
