

-- core/utils/locale_utils.lua
-- TeleportFavorites Factorio Mod
-- Centralized localization helper for consistent localized string access and parameter substitution.

local BasicHelpers = require("core.utils.basic_helpers")

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
Core function to get any localized string
@param player - The player object for localization context
@param category - The category (gui, error, command, handler, etc.)
@param key - The locale key (without prefix)
@param params - Optional table of parameters for string substitution
@return localized string
]]
function LocaleUtils.get_string(player, category, key, params)
    if not BasicHelpers.is_valid_player(player) then
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
    end    
    
    local locale_key = prefix .. "." .. key
    
    -- Return a localized string table that Factorio can process
    if params and type(params) == "table" and #params > 0 then
        -- Lua 5.1 compatibility: use unpack instead of table.unpack
        return {locale_key, (table.unpack or unpack)(params)}
    else
        return {locale_key}
    end
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
            unknown_error = "Unknown error",
            move_mode_failed = "Move failed",
            invalid_location_chosen = "invalid location chosen"
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
Enable or disable debug mode for missing translations
@param enabled - Boolean to enable/disable debug mode
]]
function LocaleUtils.set_debug_mode(enabled)
    DEBUG_MISSING_TRANSLATIONS = enabled
end

return LocaleUtils
