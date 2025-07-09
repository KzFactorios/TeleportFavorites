-- tests/mocks/mock_enhanced_error_handler.lua
-- Minimal mock for core.utils.enhanced_error_handler

local mock_logger = {}

function mock_logger.info(msg)
    -- No-op for tests
end

return mock_logger
