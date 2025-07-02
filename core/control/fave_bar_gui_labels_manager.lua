---@diagnostic disable: undefined-global

--[[
fave_bar_gui_labels_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Unified manager for updating player coordinates and teleport history labels in the favorites bar.
Handles all label updating, event registration, and teleport history navigation/commands/remote logic.
]]

local GPSUtils = require("core.utils.gps_utils")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local TeleportHistory = require("core.teleport.teleport_history")
local GameHelpers = require("core.utils.game_helpers")
local Settings = require("core.utils.settings_access")
local Constants = require("constants")

local FaveBarGuiLabelsManager = {}

-- Helper function to count table entries
local function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Helper function to get update interval from global settings
local function get_update_interval(updater_name)
    if not settings or not settings.global then
        -- Fallback to constants if settings not available
        return (updater_name == "player_coords") and Constants.settings.DEFAULT_COORDS_UPDATE_INTERVAL or Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL
    end
    
    local setting_name = (updater_name == "player_coords") and "coords-update-interval" or "history-update-interval"
    local setting_value = settings.global[setting_name]
    if setting_value and setting_value.value then
        return setting_value.value
    end
    
    -- Fallback to constants
    return (updater_name == "player_coords") and Constants.settings.DEFAULT_COORDS_UPDATE_INTERVAL or Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL
end

-- Prevent duplicate registrations
local _registration_state = {
    commands_registered = false,
    remote_registered = false
}

-- ====== PLAYER COORDS LABEL ======
function FaveBarGuiLabelsManager.get_coords_caption(player)
    local coords_string = GPSUtils.coords_string_from_map_position(player.position)
    return coords_string
end

-- ====== TELEPORT HISTORY LABEL ======
function FaveBarGuiLabelsManager.get_history_caption(player)
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    local pointer = hist.pointer or 0
    --return "→ " .. pointer .. " | " .. #stack
    --return #stack .. " → " .. pointer
    return pointer .. " → " .. #stack
end

-- Keep the local versions for backwards compatibility
local function get_coords_caption(player)
    return FaveBarGuiLabelsManager.get_coords_caption(player)
end

local function get_history_caption(player)
    return FaveBarGuiLabelsManager.get_history_caption(player)
end

-- ====== GENERIC LABEL UPDATER ======
local _updater_state = {}

local function _get_state(updater_name)
    if not _updater_state[updater_name] then
        _updater_state[updater_name] = {
            last_update_tick = 0,
            is_handler_registered = false,
            enabled_players = {}
        }
    end
    return _updater_state[updater_name]
end

local function _get_label(player, label_name)
    if not player or not player.valid then return nil end
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow or not main_flow.valid then 
        return nil 
    end
    
    -- Use recursive search to find the label anywhere within the main flow
    local label = GuiValidation.find_child_by_name(main_flow, label_name)
    if not label or not label.valid then
        return nil
    end
    
    return label
end

local function _should_register_handler(setting_name)
    if not game then return false end
    
    -- Convert setting name to the correct format used by Settings module
    local setting_key = (setting_name == "show-player-coords") and "show_player_coords" or "show_teleport_history"
    
    for _, player in pairs(game.players) do
        if player and player.valid then
            local player_settings = Settings:getPlayerSettings(player)
            if player_settings and player_settings[setting_key] then
                return true
            end
        end
    end
    return false
end

local function _update_label(player, label_name, get_caption)
    if not player or not player.valid then return end
    local label = _get_label(player, label_name)
    if not label or not label.valid then
        return
    end
    local new_caption = get_caption(player)
    label.caption = new_caption
end

function FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
    local state = _get_state(updater_name)
    if not player or not player.valid then return end
    
    local label = _get_label(player, label_name)
    if not label or not label.valid then
        return
    end
    
    -- Convert setting name to the correct format used by Settings module
    local setting_key = (setting_name == "show-player-coords") and "show_player_coords" or "show_teleport_history"
    local player_settings = Settings:getPlayerSettings(player)
    local show = player_settings and player_settings[setting_key]
    
    if show then
        -- Setting is enabled - show label and add to enabled players
        _update_label(player, label_name, get_caption)
        state.enabled_players[player.index] = true
        -- Ensure label is visible
        label.visible = true
    else
        -- Setting is disabled - hide label and remove from enabled players
        label.caption = ""  -- Clear label with empty string
        label.visible = false  -- Hide the label
        state.enabled_players[player.index] = nil
    end
    
    -- Only update handler registration if player's enabled state changed or if handler needs registration
    local has_enabled_players = next(state.enabled_players) ~= nil
    local needs_handler = has_enabled_players and not state.is_handler_registered
    local needs_unregister = not has_enabled_players and state.is_handler_registered
    
    if needs_handler or needs_unregister then
        local update_interval = get_update_interval(updater_name)
        FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj, setting_name, label_name, get_caption, update_interval)
    end
end

function FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj, setting_name, label_name, get_caption, update_interval)
    local state = _get_state(updater_name)
    update_interval = update_interval or 30
    local should_be_registered = _should_register_handler(setting_name)
    
    if should_be_registered and not state.is_handler_registered then

        script_obj.on_nth_tick(update_interval, function(event)
            FaveBarGuiLabelsManager.on_tick_handler(updater_name, event, script_obj, label_name, get_caption)
        end)
        state.is_handler_registered = true
    elseif not should_be_registered and state.is_handler_registered then

        script_obj.on_nth_tick(update_interval, nil)
        state.is_handler_registered = false
    end
    for player_index, _ in pairs(state.enabled_players) do
        local player = game.get_player(player_index)
        _update_label(player, label_name, get_caption)
    end
end

function FaveBarGuiLabelsManager.on_tick_handler(updater_name, event, script_obj, label_name, get_caption)
    local state = _get_state(updater_name)
    -- Get current update interval from settings
    local min_tick_interval = get_update_interval(updater_name)
    if (event.tick - state.last_update_tick) < min_tick_interval then
        return
    end
    state.last_update_tick = event.tick
    
    
    -- Determine which setting to check based on updater name
    local setting_key = (updater_name == "player_coords") and "show_player_coords" or "show_teleport_history"
    
    for player_index, _ in pairs(state.enabled_players) do
        local player = game.get_player(player_index)
        if not player or not player.valid then
            state.enabled_players[player_index] = nil
        else
            -- Check if the setting is still enabled for this player
            local player_settings = Settings:getPlayerSettings(player)
            if player_settings and player_settings[setting_key] then
                _update_label(player, label_name, get_caption)
            else
                -- Setting is disabled, remove from enabled players and clear label
                state.enabled_players[player_index] = nil
                local label = _get_label(player, label_name)
                if label and label.valid then
                    label.caption = ""
                end
            end
        end
    end
    if next(state.enabled_players) == nil then
        -- Unregister the tick handler if no players are enabled
        local update_interval = get_update_interval(updater_name)
        script_obj.on_nth_tick(update_interval, nil)
        state.is_handler_registered = false

    end
end

function FaveBarGuiLabelsManager.initialize(updater_name, script_obj, setting_name, label_name, get_caption)
    local state = _get_state(updater_name)
    if not game then
        return
    end
    
    for _, player in pairs(game.players) do
        if player and player.valid and player.connected then
            FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
        end
    end
    
    -- Force handler registration check after all players are processed
    FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj, setting_name, label_name, get_caption)
end

function FaveBarGuiLabelsManager.register_label_events(updater_name, script_obj, setting_name, label_name, get_caption)
    -- Don't register the main setting change event here - it will be registered once in register_all
    
    script_obj.on_event(defines.events.on_player_created, function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        -- Delay initialization slightly to ensure player settings are available
        script_obj.on_nth_tick(60, function()
            FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
            script_obj.on_nth_tick(60, nil) -- Unregister this one-time handler
        end)
    end)
    
    script_obj.on_event(defines.events.on_player_joined_game, function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        -- Initialize label system when player joins
        FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
    end)
    
    -- Don't initialize immediately - let the handlers do it when appropriate
end

-- ====== TELEPORT HISTORY NAVIGATION & REMOTE LOGIC ======

local teleport_history_in_progress = {}

local function mark_teleport_history(player_index)
    teleport_history_in_progress[player_index] = true
end

local function clear_teleport_history(player_index)
    teleport_history_in_progress[player_index] = nil
end

local function _get_valid_player(event)
    if not event.player_index then return nil end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return nil end
    return player
end

local function _handle_history_navigation(event, direction, is_endpoint)
    local player = _get_valid_player(event)
    if not player then return end
    local player_index = event.player_index
    mark_teleport_history(player_index)
    TeleportHistory.move_pointer(player, direction, is_endpoint)
    -- clear_teleport_history will be called after script_raised_teleported
end

function FaveBarGuiLabelsManager.register_history_controls(script)
    script.on_event("teleport_history-prev", function(event)
        _handle_history_navigation(event, -1, false)
    end)
    script.on_event("teleport_history-next", function(event)
        _handle_history_navigation(event, 1, false)
    end)
    script.on_event("teleport_history-first", function(event)
        _handle_history_navigation(event, -1, true)
    end)
    script.on_event("teleport_history-last", function(event)
        _handle_history_navigation(event, 1, true)
    end)
    script.on_event("teleport_history-clear", function(event)
        local player = _get_valid_player(event)
        if not player then return end
        TeleportHistory.clear(player)
    end)
    
    -- Only register commands once
    if not _registration_state.commands_registered then
        commands.add_command("tf-history", "Show teleport history debug info", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            TeleportHistory.print_history(player)
        end)
        commands.add_command("tf-add-position", "Add current position to teleport history", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            local gps = {
                x = math.floor(player.position.x),
                y = math.floor(player.position.y),
                surface = player.surface.index
            }
            TeleportHistory.add_gps(player, gps)
            TeleportHistory.print_history(player)
        end)
        commands.add_command("tf-update-coords", "Force update coordinate labels", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            FaveBarGuiLabelsManager.force_update_labels_for_player(player)
            GameHelpers.player_print(player, "Forced coordinate label update")
        end)
        commands.add_command("tf-debug-labels", "Debug label system", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            
            GameHelpers.player_print(player, "=== LABEL DEBUG INFO ===")
            
            -- Check if settings are enabled
            local player_settings = Settings:getPlayerSettings(player)
            local coords_enabled = player_settings and player_settings.show_player_coords
            local history_enabled = player_settings and player_settings.show_teleport_history
            GameHelpers.player_print(player, "show-player-coords setting: " .. tostring(coords_enabled))
            GameHelpers.player_print(player, "show-teleport-history setting: " .. tostring(history_enabled))
            
            -- Check GUI hierarchy
            local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
            GameHelpers.player_print(player, "main_flow exists: " .. tostring(main_flow ~= nil))
            
            if main_flow then
                local fave_bar_frame = GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
                GameHelpers.player_print(player, "fave_bar_frame exists: " .. tostring(fave_bar_frame ~= nil))
                
                -- Check if labels exist
                local coords_label = _get_label(player, "fave_bar_coords_label")
                local history_label = _get_label(player, "fave_bar_teleport_history_label")
                GameHelpers.player_print(player, "coords_label found: " .. tostring(coords_label ~= nil))
                GameHelpers.player_print(player, "history_label found: " .. tostring(history_label ~= nil))
                
                if coords_label then
                    GameHelpers.player_print(player, "coords_label current caption: " .. tostring(coords_label.caption))
                    GameHelpers.player_print(player, "coords_label visible: " .. tostring(coords_label.visible))
                end
                
                if history_label then
                    GameHelpers.player_print(player, "history_label current caption: " .. tostring(history_label.caption))
                    GameHelpers.player_print(player, "history_label visible: " .. tostring(history_label.visible))
                end
            end
            
            -- Check handler state for coords
            local coords_state = _get_state("player_coords")
            GameHelpers.player_print(player, "=== COORDS HANDLER STATE ===")
            GameHelpers.player_print(player, "tick handler registered: " .. tostring(coords_state.is_handler_registered))
            GameHelpers.player_print(player, "enabled players count: " .. tostring(table_size(coords_state.enabled_players)))
            GameHelpers.player_print(player, "this player enabled: " .. tostring(coords_state.enabled_players[player.index] ~= nil))
            GameHelpers.player_print(player, "last update tick: " .. tostring(coords_state.last_update_tick))
            
            -- Check handler state for history
            local history_state = _get_state("teleport_history")
            GameHelpers.player_print(player, "=== HISTORY HANDLER STATE ===")
            GameHelpers.player_print(player, "tick handler registered: " .. tostring(history_state.is_handler_registered))
            GameHelpers.player_print(player, "enabled players count: " .. tostring(table_size(history_state.enabled_players)))
            GameHelpers.player_print(player, "this player enabled: " .. tostring(history_state.enabled_players[player.index] ~= nil))
            GameHelpers.player_print(player, "last update tick: " .. tostring(history_state.last_update_tick))
            
            -- Check current position
            GameHelpers.player_print(player, "Current position: " .. tostring(player.position.x) .. ", " .. tostring(player.position.y))
            GameHelpers.player_print(player, "Current tick: " .. tostring(game.tick))
            
            -- Try to update manually
            GameHelpers.player_print(player, "=== FORCING UPDATE ===")
            FaveBarGuiLabelsManager.force_update_labels_for_player(player)
            
            -- Try to register the player manually if not registered
            if coords_enabled and not coords_state.enabled_players[player.index] then
                GameHelpers.player_print(player, "=== MANUALLY REGISTERING PLAYER ===")
                -- Use public function instead of local
                FaveBarGuiLabelsManager.force_update_labels_for_player(player)
            end
        end)
        commands.add_command("tf-reinit-labels", "Re-initialize label system", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            
            GameHelpers.player_print(player, "=== RE-INITIALIZING LABELS ===")
            
            -- Force re-initialization for this player by calling the public register functions
            GameHelpers.player_print(player, "Calling initialize_all_players to re-initialize...")
            FaveBarGuiLabelsManager.initialize_all_players(script)
            
            GameHelpers.player_print(player, "Re-initialization complete!")
        end)
        commands.add_command("tf-init-player", "Initialize label system for current player", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            
            GameHelpers.player_print(player, "=== INITIALIZING PLAYER LABELS ===")
            
            -- Initialize just this player
            FaveBarGuiLabelsManager.update_label_for_player("player_coords", player, script, "show-player-coords", "fave_bar_coords_label", get_coords_caption)
            FaveBarGuiLabelsManager.update_label_for_player("teleport_history", player, script, "show-teleport-history", "fave_bar_teleport_history_label", get_history_caption)
            
            GameHelpers.player_print(player, "Player initialization complete!")
        end)
        commands.add_command("tf-force-coords-test", "Force coordinates to update every second visibly", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            
            GameHelpers.player_print(player, "=== FORCING VISIBLE COORDS TEST ===")
            
            -- Force enable the player for coords updates
            local coords_state = _get_state("player_coords")
            coords_state.enabled_players[player.index] = true
            
            -- Set up a very frequent update (every 60 ticks = 1 second) to make it visible
            script.on_nth_tick(60, function(event)
                local coords_label = _get_label(player, "fave_bar_coords_label")
                if coords_label and coords_label.valid then
                    local coords_string = get_coords_caption(player)
                    coords_label.caption = coords_string .. " [TICK:" .. tostring(event.tick) .. "]"
                    GameHelpers.player_print(player, "FORCED UPDATE: " .. coords_string)
                else
                    GameHelpers.player_print(player, "ERROR: coords_label not found during forced update!")
                    -- Stop the test if label is not found
                    script.on_nth_tick(60, nil)
                end
            end)
            
            GameHelpers.player_print(player, "Forced coords test started - should update every second with tick number")
            GameHelpers.player_print(player, "Use /tf-stop-coords-test to stop")
        end)
        commands.add_command("tf-stop-coords-test", "Stop the forced coordinates test", function(command)
            local player = game.get_player(command.player_index)
            if not player or not player.valid then return end
            
            script.on_nth_tick(60, nil)
            GameHelpers.player_print(player, "Forced coords test stopped")
            
            -- Reset the label to normal
            local coords_label = _get_label(player, "fave_bar_coords_label")
            if coords_label and coords_label.valid then
                local coords_string = get_coords_caption(player)
                coords_label.caption = coords_string
            end
        end)
        _registration_state.commands_registered = true
    end
    
    -- Only register remote interface once
    if not _registration_state.remote_registered and remote and not remote.interfaces["TeleportFavorites_History"] then
        remote.add_interface("TeleportFavorites_History", {
            add_to_history = function(player_index)
                local player = game.get_player(player_index)
                if not player or not player.valid then return end
                if teleport_history_in_progress[player_index] then
                    clear_teleport_history(player_index)
                    return
                end
                local gps = {
                    x = math.floor(player.position.x),
                    y = math.floor(player.position.y),
                    surface = player.surface.index
                }
                TeleportHistory.add_gps(player, gps)
            end
        })
        _registration_state.remote_registered = true
    end
end

-- ====== PUBLIC REGISTRATION ======

-- Simple function to force update labels for a player
function FaveBarGuiLabelsManager.force_update_labels_for_player(player)
    if not player or not player.valid then return end
    
    local player_settings = Settings:getPlayerSettings(player)
    
    -- Update coordinates label only if setting is enabled
    local coords_label = _get_label(player, "fave_bar_coords_label")
    if coords_label and coords_label.valid then
        if player_settings and player_settings.show_player_coords then
            local coords_string = get_coords_caption(player)
            coords_label.caption = coords_string
            coords_label.visible = true
        else
            coords_label.caption = ""
            coords_label.visible = false
        end
    end
    
    -- Update teleport history label only if setting is enabled
    local history_label = _get_label(player, "fave_bar_teleport_history_label")
    if history_label and history_label.valid then
        if player_settings and player_settings.show_teleport_history then
            local history_string = get_history_caption(player)
            history_label.caption = history_string
            history_label.visible = true
        else
            history_label.caption = ""
            history_label.visible = false
        end
    end
end

function FaveBarGuiLabelsManager.register_all(script_obj)
    -- Register a single consolidated event handler for all setting changes
    script_obj.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
        if not event then return end
        
        -- Handle player setting changes (show/hide labels)
        if event.player_index then
            local player = game.get_player(event.player_index)
            if not player or not player.valid then return end
            
            if event.setting == "show-player-coords" then
                FaveBarGuiLabelsManager.update_label_for_player("player_coords", player, script_obj, "show-player-coords", "fave_bar_coords_label", get_coords_caption)
                -- Force immediate update after setting change
                FaveBarGuiLabelsManager.force_update_labels_for_player(player)
                return
            elseif event.setting == "show-teleport-history" then
                FaveBarGuiLabelsManager.update_label_for_player("teleport_history", player, script_obj, "show-teleport-history", "fave_bar_teleport_history_label", get_history_caption)
                -- Force immediate update after setting change
                FaveBarGuiLabelsManager.force_update_labels_for_player(player)
                return
            end
        end
        
        -- Handle global setting changes (update intervals) - admin only
        if event.setting == "coords-update-interval" then
            -- Re-register handler with new interval for coords
            FaveBarGuiLabelsManager.update_handler_registration("player_coords", script_obj, "show-player-coords", "fave_bar_coords_label", get_coords_caption)
        elseif event.setting == "history-update-interval" then
            -- Re-register handler with new interval for history
            FaveBarGuiLabelsManager.update_handler_registration("teleport_history", script_obj, "show-teleport-history", "fave_bar_teleport_history_label", get_history_caption)
        end
    end)
    
    -- Register player coords label updater (matches label name in GUI)
    FaveBarGuiLabelsManager.register_label_events(
        "player_coords",
        script_obj,
        "show-player-coords",
        "fave_bar_coords_label",
        get_coords_caption
    )
    -- Register teleport history label updater (must match label name in GUI)
    FaveBarGuiLabelsManager.register_label_events(
        "teleport_history",
        script_obj,
        "show-teleport-history",
        "fave_bar_teleport_history_label",
        get_history_caption
    )
    FaveBarGuiLabelsManager.register_history_controls(script_obj)
end

-- Initialize labels for all existing players (called after GUI is built)
function FaveBarGuiLabelsManager.initialize_all_players(script_obj)
    if not game then
        return
    end
    
    -- Initialize with a small delay to ensure GUIs are ready
    script_obj.on_nth_tick(10, function() -- Very short delay
        
        for _, player in pairs(game.players) do
            if player and player.valid and player.connected then
                -- Only initialize if player is in character or cutscene mode
                if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
                    -- Initialize both coords and history labels
                    FaveBarGuiLabelsManager.update_label_for_player("player_coords", player, script_obj, "show-player-coords", "fave_bar_coords_label", get_coords_caption)
                    FaveBarGuiLabelsManager.update_label_for_player("teleport_history", player, script_obj, "show-teleport-history", "fave_bar_teleport_history_label", get_history_caption)
                end
            end
        end
        
        -- Unregister this one-time initialization handler
        script_obj.on_nth_tick(10, nil)
    end)
    
    -- Also use a longer delay as a backup, in case settings take time to load
    script_obj.on_nth_tick(60, function() -- 1 second delay as backup
        
        for _, player in pairs(game.players) do
            if player and player.valid and player.connected then
                -- Only initialize if player is in character or cutscene mode
                if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
                    -- Initialize both coords and history labels again as backup
                    FaveBarGuiLabelsManager.update_label_for_player("player_coords", player, script_obj, "show-player-coords", "fave_bar_coords_label", get_coords_caption)
                    FaveBarGuiLabelsManager.update_label_for_player("teleport_history", player, script_obj, "show-teleport-history", "fave_bar_teleport_history_label", get_history_caption)
                end
            end
        end
        
        -- Unregister this one-time initialization handler
        script_obj.on_nth_tick(60, nil)
    end)
end

return FaveBarGuiLabelsManager
