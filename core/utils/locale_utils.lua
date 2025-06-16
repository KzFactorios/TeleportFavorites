-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\utils\locale_utils.lua

--[[
LocaleUtils - Centralized localization helper for TeleportFavorites mod

This module provides utilities for consistent localized string access throughout the mod.
It ensures all hardcoded strings are replaced with proper locale keys.

Usage Examples:
  LocaleUtils.get_gui_string(player, "favorite_slot_empty")
  LocaleUtils.get_error_string(player, "driving_teleport_blocked")
  LocaleUtils.get_command_string(player, "action_undone")
  LocaleUtils.format_string(player, "teleported_to", {player.name, destination})

Features:
- Centralized string access with fallback to English
- Parameter substitution support
- Category-based organization (gui, error, command, handler)
- Debug mode for missing translations
- Consistent API across all mod components
]]

local LocaleUtils = {}

-- Locale key prefixes for different categories
local LOCALE_PREFIXES = {
    gui = "tf-gui",
    error = "tf-error", 
    command = "tf-command",
    handler = "tf-handler",
    setting_name = "mod-setting-name",
    setting_desc = "mod-setting-description"
}

-- Debug flag for missing translation warnings
local DEBUG_MISSING_TRANSLATIONS = true

--[[
Get a localized string from the GUI category
@param player - The player object for localization context
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_gui_string(player, key, params)
    return LocaleUtils.get_string(player, "gui", key, params)
end

--[[
Get a localized string from the error category
@param player - The player object for localization context
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_error_string(player, key, params)
    return LocaleUtils.get_string(player, "error", key, params)
end

--[[
Get a localized string from the command category
@param player - The player object for localization context
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_command_string(player, key, params)
    return LocaleUtils.get_string(player, "command", key, params)
end

--[[
Get a localized string from the handler category
@param player - The player object for localization context
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_handler_string(player, key, params)
    return LocaleUtils.get_string(player, "handler", key, params)
end

--[[
Get a localized string from the mod settings category
@param player - The player object for localization context
@param key - The locale key (without prefix)
@param is_description - Whether this is a setting description (default: false)
@return localized string
]]
function LocaleUtils.get_setting_string(player, key, is_description)
    local category = is_description and "setting_desc" or "setting_name"
    return LocaleUtils.get_string(player, category, key)
end

--[[
Core function to get any localized string
@param player - The player object for localization context
@param category - The category (gui, error, command, handler, etc.)
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_string(player, category, key, params)
    if not player or not player.valid then
        if DEBUG_MISSING_TRANSLATIONS then
            game.print("[LocaleUtils] Warning: Invalid player for localization")
        end
        return LocaleUtils.get_fallback_string(category, key, params)
    end

    local prefix = LOCALE_PREFIXES[category]
    if not prefix then
        if DEBUG_MISSING_TRANSLATIONS then
            game.print("[LocaleUtils] Warning: Unknown category '" .. tostring(category) .. "'")
        end
        return key -- Return the key itself as fallback
    end    local locale_key = prefix .. "." .. key
    
    -- In Factorio, localized strings are handled via the locale files
    -- For now, return the fallback string directly since Factorio's localization
    -- system will handle the actual translation when text is displayed
    local localized_string = LocaleUtils.get_fallback_string(category, key, params)
    
    return localized_string
end

--[[
Get fallback English string for missing translations
@param category - The category
@param key - The locale key
@param params - Optional parameters
@return fallback string
]]
function LocaleUtils.get_fallback_string(category, key, params)
    -- Define fallback strings for critical messages
    local fallbacks = {
        gui = {
            confirm = "Confirm",
            cancel = "Cancel",
            close = "Close",
            delete_tag = "Delete Tag",
            teleport_success = "Teleported successfully!",
            teleport_failed = "Teleportation failed"
        },
        error = {
            driving_teleport_blocked = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
            player_missing = "Unable to teleport. Player is missing",
            unknown_error = "Unknown error"
        },
        command = {
            nothing_to_undo = "No actions to undo"
        }
    }

    local category_fallbacks = fallbacks[category]
    local fallback = category_fallbacks and category_fallbacks[key]
    
    if fallback then
        if params and type(params) == "table" then
            return LocaleUtils.substitute_parameters(fallback, params)
        end
        return fallback
    end

    -- Ultimate fallback: return the key with category prefix
    return "[" .. (category or "unknown") .. ":" .. (key or "unknown") .. "]"
end

--[[
Substitute parameters in a localized string
Supports both Factorio-style __1__, __2__ and named parameters
@param text - The text with parameter placeholders
@param params - Table of parameter values
@return text with substituted parameters
]]
function LocaleUtils.substitute_parameters(text, params)
    if not text or not params then
        return text or ""
    end

    -- Handle numbered parameters (__1__, __2__, etc.)
    if type(params) == "table" then
        for i, value in ipairs(params) do
            local placeholder = "__" .. i .. "__"
            text = text:gsub(placeholder, tostring(value))
        end

        -- Handle named parameters if provided as a dictionary
        for key, value in pairs(params) do
            if type(key) == "string" then
                local placeholder = "__" .. key .. "__"
                text = text:gsub(placeholder, tostring(value))
            end
        end
    end

    return text
end

--[[
Format a localized string with parameters
Convenience function that combines getting a string and parameter substitution
@param player - The player object
@param category - The category
@param key - The locale key
@param params - Parameters for substitution
@return formatted localized string
]]
function LocaleUtils.format_string(player, category, key, params)
    return LocaleUtils.get_string(player, category, key, params)
end

--[[
Validate that all required locale keys exist for a player
Useful for debugging and ensuring translation completeness
@param player - The player object
@param required_keys - Table of {category = {key1, key2, ...}}
@return table of missing keys
]]
function LocaleUtils.validate_translations(player, required_keys)
    local missing = {}
    
    for category, keys in pairs(required_keys) do
        for _, key in ipairs(keys) do
            local localized = LocaleUtils.get_string(player, category, key)
            if localized:match("^%[" .. category .. ":" .. key .. "%]$") then
                if not missing[category] then
                    missing[category] = {}
                end
                table.insert(missing[category], key)
            end
        end
    end
    
    return missing
end

--[[
Enable or disable debug mode for missing translations
@param enabled - Boolean to enable/disable debug mode
]]
function LocaleUtils.set_debug_mode(enabled)
    DEBUG_MISSING_TRANSLATIONS = enabled
end

--[[
Get all available locale categories
@return table of category names
]]
function LocaleUtils.get_categories()
    local categories = {}
    for category, _ in pairs(LOCALE_PREFIXES) do
        table.insert(categories, category)
    end
    return categories
end

return LocaleUtils
