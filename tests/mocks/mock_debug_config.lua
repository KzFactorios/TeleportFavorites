-- tests/mocks/mock_debug_config.lua
-- Minimal mock for core.utils.debug_config

local mock_debug_config = {
    LEVELS = { NONE = 0, ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4, TRACE = 5 },
    _level = 1
}

function mock_debug_config.get_level()
    return mock_debug_config._level
end

function mock_debug_config.get_level_name(level)
    local names = { [0] = "NONE", [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG", [5] = "TRACE" }
    return names[level or mock_debug_config._level] or "UNKNOWN"
end

function mock_debug_config.set_level(level)
    mock_debug_config._level = level
end

function mock_debug_config.enable_production_mode()
    mock_debug_config._level = 1
end

function mock_debug_config.enable_development_mode()
    mock_debug_config._level = 5
end

return mock_debug_config
