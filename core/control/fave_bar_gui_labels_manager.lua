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

local FaveBarGuiLabelsManager = {}

-- Prevent duplicate registrations
local _registration_state = {
    commands_registered = false,
    remote_registered = false
}

-- ====== PLAYER COORDS LABEL ======
local function get_coords_caption(player)
    return GPSUtils.coords_string_from_map_position(player.position)
end

-- ====== TELEPORT HISTORY LABEL ======
local function get_history_caption(player)
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    local pointer = hist.pointer or 0
    return #stack .. "|" .. pointer
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
    if not main_flow or not main_flow.valid then return nil end
    return GuiValidation.find_child_by_name(main_flow, label_name)
end

local function _should_register_handler(setting_name)
    if not game then return false end
    for _, player in pairs(game.players) do
        local player_settings = settings.get_player_settings(player)
        if player_settings and player_settings[setting_name] and player_settings[setting_name].value == true then
            return true
        end
    end
    return false
end

local function _update_label(player, label_name, get_caption)
    if not player or not player.valid then return end
    local label = _get_label(player, label_name)
    if not label or not label.valid then
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Could not find label " .. label_name .. " for player " .. player.name)
        return
    end
    label.caption = get_caption(player)
end

function FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
    local state = _get_state(updater_name)
    if not player or not player.valid then return end
    local label = _get_label(player, label_name)
    if not label or not label.valid then
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Could not find label " .. label_name .. " for player " .. player.name)
        return
    end
    local player_settings = settings.get_player_settings(player)
    local show = player_settings and player_settings[setting_name] and player_settings[setting_name].value == true
    if show then
        _update_label(player, label_name, get_caption)
        state.enabled_players[player.index] = true
    else
        label.caption = nil -- fallback: clear label if empty string/LocalisedString fails
        -- If this still errors, try label.caption = nil as a last resort
        state.enabled_players[player.index] = nil
    end
    FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj, setting_name, label_name, get_caption)
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
    if (event.tick - state.last_update_tick) < 30 then
        return
    end
    state.last_update_tick = event.tick
    for player_index, _ in pairs(state.enabled_players) do
        local player = game.get_player(player_index)
        if not player or not player.valid then
            state.enabled_players[player_index] = nil
        else
            _update_label(player, label_name, get_caption)
        end
    end
    if next(state.enabled_players) == nil then
        FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj)
    end
end

function FaveBarGuiLabelsManager.initialize(updater_name, script_obj, setting_name, label_name, get_caption)
    local state = _get_state(updater_name)
    if not game then
        ErrorHandler.warn_log("[FAVE_BAR_LABELS] Cannot initialize, game object not available")
        return
    end
    for _, player in pairs(game.players) do
        if player and player.valid and player.connected then
            FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
        end
    end
    FaveBarGuiLabelsManager.update_handler_registration(updater_name, script_obj, setting_name, label_name, get_caption)
end

function FaveBarGuiLabelsManager.register_label_events(updater_name, script_obj, setting_name, label_name, get_caption)
    script_obj.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
        if not event or not event.player_index then return end
        if event.setting ~= setting_name then return end
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
    end)
    script_obj.on_event(defines.events.on_player_created, function(event)
        local player = game.get_player(event.player_index)
        FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
    end)
    FaveBarGuiLabelsManager.initialize(updater_name, script_obj, setting_name, label_name, get_caption)
    if game and game.connected_players then
        for _, player in pairs(game.connected_players) do
            FaveBarGuiLabelsManager.update_label_for_player(updater_name, player, script_obj, setting_name, label_name, get_caption)
        end
    end
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
    
    ErrorHandler.debug_log("[FAVE_BAR_LABELS] Force updating labels for player " .. player.name)
    
    -- Update coordinates label
    local coords_label = _get_label(player, "fave_bar_coords_label")
    if coords_label and coords_label.valid then
        coords_label.caption = get_coords_caption(player)
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Updated coords label: " .. tostring(coords_label.caption))
    else
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Could not find coords label for player " .. player.name)
    end
    
    -- Update teleport history label
    local history_label = _get_label(player, "fave_bar_teleport_history_label")
    if history_label and history_label.valid then
        history_label.caption = get_history_caption(player)
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Updated history label: " .. tostring(history_label.caption))
    else
        ErrorHandler.debug_log("[FAVE_BAR_LABELS] Could not find history label for player " .. player.name)
    end
end

function FaveBarGuiLabelsManager.register_all(script_obj)
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

return FaveBarGuiLabelsManager
