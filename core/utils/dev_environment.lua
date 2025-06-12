-- Dev Environment Detection Module
-- Provides reliable detection of development vs. production environments
-- and configuration for development tools

local DevEnvironment = {}

-- Configuration options with defaults
DevEnvironment.config = {
    is_dev_mode = false,           -- Master switch for development mode
    dev_file_marker = ".dev_mode", -- File that indicates dev environment when present
    positionator_enabled = true,   -- Whether the position adjustment dialog is enabled in dev mode
}

-- Load developer mod settings
local function load_settings()
    -- We need to use _G to access game and settings to avoid errors
    if not _G.game or not _G.settings then return end
    
    -- Read settings if they exist
    if _G.settings.global["teleport-favorites-dev-positionator-enabled"] then
        DevEnvironment.config.positionator_enabled = 
            _G.settings.global["teleport-favorites-dev-positionator-enabled"].value
    end
    
    if _G.settings.global["teleport-favorites-dev-debug-mode"] then
        DevEnvironment.config.debug_mode = 
            _G.settings.global["teleport-favorites-dev-debug-mode"].value
    end
end

-- Initialize the module
function DevEnvironment.init()
    -- Check for dev mode file marker at mod root
    local marker_path = "__TeleportFavorites__/" .. DevEnvironment.config.dev_file_marker
    
    -- Attempt to read the marker file - its existence confirms dev mode
    -- We use pcall because attempting to read a non-existent file will error
    local success = false
    if _G.game then
        success = pcall(function() 
            _G.game.read_file(marker_path) 
        end)
    end
      -- Set dev mode based on marker file existence
    DevEnvironment.config.is_dev_mode = success
    
    -- Log detection result
    if DevEnvironment.is_dev_mode() and _G.log then
        _G.log("[TeleportFavorites] Development environment detected")
    end
    
    -- Load mod settings if available
    load_settings()
end

-- Check if we're in development mode
function DevEnvironment.is_dev_mode()
    return DevEnvironment.config.is_dev_mode
end

-- Check if a specific dev feature is enabled
function DevEnvironment.is_feature_enabled(feature_name)
    -- First check if we're in dev mode at all
    if not DevEnvironment.is_dev_mode() then
        return false
    end
    
    -- Then check if the specific feature is enabled
    return DevEnvironment.config[feature_name .. "_enabled"] or false
end

-- Check if positionator is enabled
function DevEnvironment.is_positionator_enabled()
    return DevEnvironment.is_dev_mode() and DevEnvironment.config.positionator_enabled
end

-- Toggle a development feature
function DevEnvironment.toggle_feature(feature_name)
    local config_name = feature_name .. "_enabled"
    if DevEnvironment.config[config_name] ~= nil then
        DevEnvironment.config[config_name] = not DevEnvironment.config[config_name]
        return DevEnvironment.config[config_name]
    end
    return nil
end

-- Set a development feature
function DevEnvironment.set_feature(feature_name, value)
    local config_name = feature_name .. "_enabled"
    if DevEnvironment.config[config_name] ~= nil then
        DevEnvironment.config[config_name] = value
        return true
    end
    return false
end

return DevEnvironment
