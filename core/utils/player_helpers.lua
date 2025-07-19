

-- core/utils/player_helpers.lua
-- TeleportFavorites Factorio Mod
-- Consolidates common player interaction patterns to reduce code duplication.
-- Provides standardized methods for player messaging, settings access, and common validations.

local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local ValidationUtils = require("core.utils.validation_utils")

local PlayerHelpers = {}

--- Safely print a message to a player
---@param player LuaPlayer|nil The player to send message to
---@param message LocalisedString|string The message to send
---@param log_fallback boolean? Whether to log if player print fails (default: true)
function PlayerHelpers.safe_player_print(player, message, log_fallback)
    if log_fallback == nil then log_fallback = true end
    
    local valid = ValidationUtils.validate_player(player)
    if valid then
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

--- Send an error message to a player with standardized formatting
---@param player LuaPlayer|nil The player to send message to
---@param error_key string Error localization key or raw message
---@param context table? Optional context for logging
function PlayerHelpers.error_message_to_player(player, error_key, context)
    local valid = ValidationUtils.validate_player(player)
    if not valid then return end
    
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

--- Check if player should have favorites bar hidden (space platform, god mode, etc.)
---@param player LuaPlayer|nil The player to check
---@return boolean should_hide True if favorites bar should be hidden
function PlayerHelpers.should_hide_favorites_bar(player)
    local valid = ValidationUtils.validate_player(player)
    if not valid then return true end
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

--- Execute a function for all valid connected players
---@param func function Function to execute (receives player as argument)
---@param include_restricted boolean? Whether to include players in restricted modes (default: false)
function PlayerHelpers.for_all_players(func, include_restricted)
    if not game or not game.connected_players then return end
    
    for _, player in pairs(game.connected_players) do
    local valid = ValidationUtils.validate_player(player)
    if valid then
            if include_restricted or not PlayerHelpers.should_hide_favorites_bar(player) then
                pcall(func, player)
            end
        end
    end
end

return PlayerHelpers
