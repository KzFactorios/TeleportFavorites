--[[
dev_mode.lua
TeleportFavorites Factorio Mod
-----------------------------
Development environment detection and utility functions.
Provides a way to detect whether the mod is running in a development
or production environment, and toggle development features.
]]

local Cache = require("core.cache.cache")
local Constants = require("constants")

---@class DevMode
local DevMode = {}

-- File paths used for dev environment detection
local DEV_MARKERS = {
    ["v:\\Fac2orios\\2_Gemini\\"] = true,  -- Main development folder path
    ["v:/Fac2orios/2_Gemini/"] = true,     -- Alternative separator
    [".vscode/settings.json"] = true,       -- Presence of VS Code settings
    ["tests"] = true                        -- Test directory
}

-- Enable or disable specific development features
local DEV_FEATURES = {
    POSITION_ADJUSTMENT_DIALOG = true,     -- Show position adjustment dialog
    DEBUG_LOGGING = true,                  -- Enhanced logging
    DATA_INSPECTION = true,                -- Data viewer enhancements
    PERFORMANCE_METRICS = true             -- Performance measurement
}

--- Detect if mod is running in development environment
--- @return boolean is_dev_env True if detected as development environment
function DevMode.is_dev_environment()
    -- Check if we've already determined and cached the environment type
    if Cache and Cache.get_runtime_data then
        local cached = Cache.get_runtime_data("dev_environment")
        if cached ~= nil then
            return cached
        end
    end

    -- Try to detect using file system checks
    local is_dev = false
    
    -- First check: try to access development markers
    for marker, _ in pairs(DEV_MARKERS) do
        -- Use pcall since attempting to read files may throw errors in production
        local success = pcall(function()
            -- For directories, check if they exist using a dummy file access
            local dummy_file = marker .. "/.dev_check"
            local test = io.open(dummy_file, "r")
            if test then
                test:close()
                is_dev = true
                return true
            end
        end)
        
        if success and is_dev then
            break
        end
    end
    
    -- Second check: look for dev mods that are only installed in development
    if not is_dev and script and script.active_mods then
        local dev_mods = {"debugadapter", "EditorExtensions", "creative-mode"}
        for _, mod_name in ipairs(dev_mods) do
            if script.active_mods[mod_name] then
                is_dev = true
                break
            end
        end
    end
    
    -- Cache the result for subsequent calls
    if Cache and Cache.set_runtime_data then
        Cache.set_runtime_data("dev_environment", is_dev)
    end
    
    return is_dev
end

--- Check if a specific development feature is enabled
--- @param feature_name string Name of the feature to check
--- @return boolean enabled True if feature is enabled in dev mode
function DevMode.is_feature_enabled(feature_name)
    -- Only check features if in dev environment
    if not DevMode.is_dev_environment() then
        return false
    end
    
    -- Check if feature exists and is enabled
    if DEV_FEATURES[feature_name] ~= nil then
        return DEV_FEATURES[feature_name]
    end
    
    return false
end

--- Get player's development mode preference
--- @param player LuaPlayer
--- @param feature_name string? Optional specific feature to check
--- @return boolean enabled True if player has enabled dev features
function DevMode.is_enabled_for_player(player, feature_name)
    -- Check if we're in a dev environment first
    if not DevMode.is_dev_environment() then
        return false
    end
    
    -- Check player data for dev mode preference
    if player and player.valid then
        local pdata = Cache.get_player_data(player)
        
        -- If player has explicitly disabled dev features, respect that
        if pdata.dev_features_disabled == true then
            return false
        end
        
        -- If checking for specific feature
        if feature_name and pdata.dev_features then
            if pdata.dev_features[feature_name] ~= nil then
                return pdata.dev_features[feature_name]
            end
        end
        
        -- Default to enabled in dev environment if not explicitly disabled
        return true
    end
    
    return false
end

--- Enable or disable development features for a player
--- @param player LuaPlayer
--- @param enabled boolean True to enable, false to disable
--- @param feature_name string? Optional specific feature to toggle
function DevMode.set_enabled_for_player(player, enabled, feature_name)
    -- Only applicable in dev environment
    if not DevMode.is_dev_environment() then
        return
    end
    
    if player and player.valid then
        local pdata = Cache.get_player_data(player)
        
        -- If toggling specific feature
        if feature_name then
            pdata.dev_features = pdata.dev_features or {}
            pdata.dev_features[feature_name] = enabled
        else
            -- Toggle all features
            pdata.dev_features_disabled = not enabled
        end
        
        -- Notify player
        player.print("[Dev Mode] " .. (enabled and "Enabled" or "Disabled") .. 
                    (feature_name and (" feature: " .. feature_name) or ""))
    end
end

--- Get the constant value based on environment
--- @param prod_value any Value to use in production environment
--- @param dev_value any Value to use in development environment
--- @return any value The appropriate value for current environment
function DevMode.get_env_value(prod_value, dev_value)
    if DevMode.is_dev_environment() then
        return dev_value
    else
        return prod_value
    end
end

return DevMode
