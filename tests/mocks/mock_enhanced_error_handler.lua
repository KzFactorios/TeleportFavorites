-- tests/mocks/mock_enhanced_error_handler.lua
-- Complete mock for core.utils.enhanced_error_handler

local mock_logger = {}

function mock_logger.info(msg)
    -- No-op for tests
end

function mock_logger.debug_log(msg, data)
    -- No-op for tests - this is what DragDropUtils needs
end

function mock_logger.warn(msg)
    -- No-op for tests
end

function mock_logger.error(msg)
    -- No-op for tests
end

function mock_logger.trace(msg)
    -- No-op for tests
end

function mock_logger.debug(msg)
    -- No-op for tests
end

return mock_logger
