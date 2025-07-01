-- test_player_coords_updater.lua
-- This file contains tests for the player coordinates display feature

local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")

-- Tests to manually run and verify:
--
-- 1. Enable show-player-coords setting (default is true):
--    - Verify that coordinates are visible in the favorites bar
--    - Verify that coordinates update as the player moves
--    - Verify that coords only update every COORDS_UPDATE_TICK_INTERVAL ticks
--
-- 2. Disable show-player-coords setting:
--    - Verify that coordinates disappear from favorites bar
--    - Verify that on_tick handler is unregistered if no players have coords enabled
--
-- 3. Re-enable show-player-coords setting:
--    - Verify that coordinates appear again
--    - Verify that on_tick handler is registered again
--
-- 4. With multiple players, verify:
--    - Individual settings work per player
--    - Handler remains active as long as at least one player has coords enabled
--    - Only updates coordinates for players with the setting enabled

-- Helper function to get coords label text for a player
local function get_coords_text(player)
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow or not main_flow.valid then return nil end
    local fave_bar_frame = GuiHelpers.find_child_by_name(main_flow, "fave_bar_frame")
    if not fave_bar_frame or not fave_bar_frame.valid then return nil end
    local fave_bar_flow = GuiHelpers.find_child_by_name(fave_bar_frame, "fave_bar_flow")
    if not fave_bar_flow or not fave_bar_flow.valid then return nil end
    local toggle_container = GuiHelpers.find_child_by_name(fave_bar_flow, "fave_bar_toggle_container")
    if not toggle_container or not toggle_container.valid then return nil end
    local coords_label = GuiHelpers.find_child_by_name(toggle_container, "fave_bar_coords_label")
    if not coords_label or not coords_label.valid then return nil end
    return coords_label.caption
end

-- Print test instructions
ErrorHandler.info_log("[TEST] Player Coordinates Feature Test")
ErrorHandler.info_log("[TEST] 1. Enable show-player-coords setting (default is true):")
ErrorHandler.info_log("[TEST]    - Verify that coordinates are visible in the favorites bar")
ErrorHandler.info_log("[TEST]    - Verify that coordinates update as the player moves")
ErrorHandler.info_log("[TEST]    - Verify that coords only update every " .. Constants.settings.COORDS_UPDATE_TICK_INTERVAL .. " ticks")
ErrorHandler.info_log("[TEST] 2. Disable show-player-coords setting:")
ErrorHandler.info_log("[TEST]    - Verify that coordinates disappear from favorites bar")
ErrorHandler.info_log("[TEST]    - Verify that on_tick handler is unregistered if no players have coords enabled")
ErrorHandler.info_log("[TEST] 3. Re-enable show-player-coords setting:")
ErrorHandler.info_log("[TEST]    - Verify that coordinates appear again")
ErrorHandler.info_log("[TEST]    - Verify that on_tick handler is registered again")

-- Print current state
local player = game.player
if player and player.valid then
local Settings = require("core.utils.settings_access")
local player_settings = Settings:getPlayerSettings(player)
    local coords_enabled = player_settings and player_settings["show-player-coords"] and player_settings["show-player-coords"].value
    local coords_text = get_coords_text(player)
    
    ErrorHandler.info_log("[TEST] Current state for player " .. player.name .. ":")
    ErrorHandler.info_log("[TEST] - show-player-coords setting: " .. tostring(coords_enabled))
    ErrorHandler.info_log("[TEST] - Current coords text: " .. tostring(coords_text))
end
