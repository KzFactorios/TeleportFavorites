---@diagnostic disable: undefined-global

local BasicHelpers = require("core.utils.basic_helpers")

local LocaleUtils = {}

local LOCALE_PREFIXES = {
    gui = "tf-gui",
    error = "tf-error",
    command = "tf-command",
    handler = "tf-handler",
    setting_name = "mod-setting-name",
    setting_desc = "mod-setting-description"
}

local DEBUG_MISSING_TRANSLATIONS = true

function LocaleUtils.get_gui_string(player, key, params)
    return LocaleUtils.get_string(player, "gui", key, params)
end

function LocaleUtils.get_error_string(player, key, params)
    return LocaleUtils.get_string(player, "error", key, params)
end

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
        return key
    end

    local locale_key = prefix .. "." .. key

    if params and type(params) == "table" and #params > 0 then
        return {locale_key, (table.unpack or unpack)(params)}
    else
        return {locale_key}
    end
end

function LocaleUtils.get_fallback_string(category, key, params)
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

    return "[" .. (category or "unknown") .. ":" .. (key or "unknown") .. "]"
end

function LocaleUtils.substitute_parameters(text, params)
    if not text or not params then
        return text or ""
    end

    if type(params) == "table" then
        for i, value in ipairs(params) do
            local placeholder = "__" .. i .. "__"
            text = text:gsub(placeholder, tostring(value))
        end

        for key, value in pairs(params) do
            if type(key) == "string" then
                local placeholder = "__" .. key .. "__"
                text = text:gsub(placeholder, tostring(value))
            end
        end
    end

    return text
end

function LocaleUtils.set_debug_mode(enabled)
    DEBUG_MISSING_TRANSLATIONS = enabled
end

return LocaleUtils
