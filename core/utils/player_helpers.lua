--[[
Player Interaction Helpers for TeleportFavorites
===============================================
Module:function PlayerHelpers.favorites_enabled_for_player(player)
    if not BasicHelpers.is_valid_player(player) then return false end
    ---@cast player LuaPlayer
    
    local player_settings = Settings:getPlayerSettings(player)
    return player_settings and player_settings.favorites_on or true
endtils/player_helpers.lua

Consolidates common player interaction patterns to reduce code duplication.
Provides standardized methods for player messaging, settings access, and common validations.
]]

local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")

local PlayerHelpers = {}

-- ===========================
-- PLAYER RETRIEVAL
-- ===========================

--- Safely get a player from an event
---@param event table The event containing player_index
---@return LuaPlayer|nil player The player if valid, nil otherwise
function PlayerHelpers.get_event_player(event)
    if not event or not event.player_index then return nil end
    local player = game.players[event.player_index]
    return BasicHelpers.is_valid_player(player) and player or nil
end

--- Safely get a player from a command
---@param command table The command containing player_index
---@return LuaPlayer|nil player The player if valid, nil otherwise
function PlayerHelpers.get_command_player(command)
    if not command or not command.player_index then return nil end
    local player = game.players[command.player_index]
    return BasicHelpers.is_valid_player(player) and player or nil
end

-- ===========================
-- PLAYER MESSAGING
-- ===========================

--- Safely print a message to a player
---@param player LuaPlayer|nil The player to send message to
---@param message LocalisedString|string The message to send
---@param log_fallback boolean? Whether to log if player print fails (default: true)
function PlayerHelpers.safe_player_print(player, message, log_fallback)
    if log_fallback == nil then log_fallback = true end
    
    if BasicHelpers.is_valid_player(player) then
        ---@cast player LuaPlayer
        local success = pcall(function() player.print(message) end)
        if not success and log_fallback then
            ErrorHandler.debug_log("Failed to print message to player", {
                player_name = player.name or "unknown",
                message_type = type(message)
            })
        end
        return success
    end
    
    if log_fallback then
        ErrorHandler.debug_log("Player not available for messaging", {
            player_valid = player and player.valid or false,
            message_type = type(message)
        })
    end
    return false
end

--- Send a debug message to a player (only in development mode)
---@param player LuaPlayer|nil The player to send message to
---@param message string The debug message
---@param context table? Optional context data
function PlayerHelpers.debug_print_to_player(player, message, context)
    if not BasicHelpers.is_valid_player(player) then return end
    
    -- Log debug information
    ErrorHandler.debug_log("[PLAYER DEBUG] " .. message, context)
    
    -- Send to player if valid
    local debug_message = "[DEBUG] " .. message
    if context then
        debug_message = debug_message .. " (see log for details)"
    end
    PlayerHelpers.safe_player_print(player, debug_message, false)
end

--- Send an error message to a player with standardized formatting
---@param player LuaPlayer|nil The player to send message to
---@param error_key string Error localization key or raw message
---@param context table? Optional context for logging
function PlayerHelpers.error_message_to_player(player, error_key, context)
    if not BasicHelpers.is_valid_player(player) then return end
    
    -- Log the error
    ErrorHandler.debug_log("Sending error message to player", {
        player_name = player.name,
        error_key = error_key,
        context = context
    })
    
    -- Send formatted error message as string
    local message_text = "[TeleportFavorites] " .. error_key
    PlayerHelpers.safe_player_print(player, message_text)
end

-- ===========================
-- SETTINGS ACCESS
-- ===========================

--- Check if favorites are enabled for a player
---@param player LuaPlayer|nil The player to check
---@return boolean enabled Whether favorites are enabled
function PlayerHelpers.are_favorites_enabled(player)
    if not BasicHelpers.is_valid_player(player) then return true end
    
    local player_settings = Cache.Settings.get_player_settings(player)
    return player_settings and player_settings.favorites_on or true
end

--- Check if teleport history should be shown for a player
---@param player LuaPlayer|nil The player to check
---@return boolean enabled Whether history should be shown
function PlayerHelpers.should_show_history(player)
    if not BasicHelpers.is_valid_player(player) then return true end
    
    local player_settings = Cache.Settings.get_player_settings(player)
    return player_settings and player_settings.enable_teleport_history or true
end

-- ===========================
-- PLAYER STATE HELPERS
-- ===========================

--- Check if player should have favorites bar hidden (space platform, god mode, etc.)
---@param player LuaPlayer|nil The player to check
---@return boolean should_hide True if favorites bar should be hidden
function PlayerHelpers.should_hide_favorites_bar(player)
    if not BasicHelpers.is_valid_player(player) then return true end
    ---@cast player LuaPlayer
    
    -- Check space platform (use existing logic)
    if BasicHelpers.should_hide_favorites_bar_for_space_platform(player) then
        return true
    end
    
    -- Check controller type
    if player.controller_type == defines.controllers.god or 
       player.controller_type == defines.controllers.spectator then
        return true
    end
    
    return false
end

--- Check if player is in a valid state for mod interactions
---@param player LuaPlayer|nil The player to check
---@return boolean valid True if player can interact with mod features
---@return string? reason Reason why player is not valid (if applicable)
function PlayerHelpers.is_player_interaction_ready(player)
    if not BasicHelpers.is_valid_player(player) then
        return false, "Invalid player"
    end
    ---@cast player LuaPlayer
    
    if not player.connected then
        return false, "Player not connected"
    end
    
    if PlayerHelpers.should_hide_favorites_bar(player) then
        return false, "Player in restricted mode"
    end
    
    if not PlayerHelpers.are_favorites_enabled(player) then
        return false, "Favorites disabled"
    end
    
    return true
end

-- ===========================
-- BATCH OPERATIONS
-- ===========================

--- Execute a function for all valid connected players
---@param func function Function to execute (receives player as argument)
---@param include_restricted boolean? Whether to include players in restricted modes (default: false)
function PlayerHelpers.for_all_players(func, include_restricted)
    if not game or not game.connected_players then return end
    
    for _, player in pairs(game.connected_players) do
        if BasicHelpers.is_valid_player(player) then
            if include_restricted or not PlayerHelpers.should_hide_favorites_bar(player) then
                pcall(func, player)
            end
        end
    end
end

--- Send a message to all connected players
---@param message LocalisedString|string The message to send
---@param include_restricted boolean? Whether to include restricted players (default: true)
function PlayerHelpers.broadcast_message(message, include_restricted)
    if include_restricted == nil then include_restricted = true end
    
    PlayerHelpers.for_all_players(function(player)
        PlayerHelpers.safe_player_print(player, message)
    end, include_restricted)
end

return PlayerHelpers
