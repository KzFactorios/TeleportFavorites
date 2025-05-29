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

if _G.log then _G.log("[TeleportFavorites] control.lua loaded") end

-- Modular event handler registration
local handlers = require("core.events.handlers")

local script = _G.script
local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local control_data_viewer = require("core.control.control_data_viewer")
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")

-- Custom on_init to allow easy toggling of intro cutscene skip
local function custom_on_init()
  handlers.on_init()
end

-- Core lifecycle and area selection event wiring
script.on_init(custom_on_init)
script.on_load(handlers.on_load)
script.on_event(_G.defines.events.on_player_created, handlers.on_player_created)
script.on_event(_G.defines.events.on_player_changed_surface, handlers.on_player_changed_surface)
script.on_event(_G.defines.events.on_player_selected_area, handlers.on_player_selected_area)
script.on_event(_G.defines.events.on_player_joined_game, handlers.on_player_created)
script.on_event("tf-open-tag-editor", handlers.on_open_tag_editor_custom_input)

-- TODO remove this for production
-- Instantly skip any cutscene (including intro) for all players
script.on_event(defines.events.on_cutscene_started, function(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then
    player.exit_cutscene()
  end
end)

-- Handle mod setting changes (e.g., slot count change)
script.on_event(_G.defines.events.on_runtime_mod_setting_changed, function(event)
  -- TODO: If the changed setting is the favorite slot count, rebuild the favorites bar for all players
  -- Example stub:
  -- if event.setting == "your_slot_count_setting_name" then
  --   for _, player in pairs(game.connected_players) do
  --     require("gui.favorites_bar.fave_bar").build(player, player.gui.top)
  --   end
  -- end
end)

-- Register data viewer hotkey and GUI events
control_data_viewer.register(script)

-- Register the shared GUI event handler for all GUIs
-- Pass both script and defines so gui_event_dispatcher can register the dispatcher
gui_event_dispatcher.register_gui_handlers(script)

-- Register custom input (keyboard shortcut) handlers
custom_input_dispatcher.register_custom_inputs(script)
