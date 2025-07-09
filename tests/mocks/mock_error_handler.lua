-- tests/mocks/mock_error_handler.lua
-- Minimal mock for core.utils.error_handler

local mock_error_handler = {}

function mock_error_handler.handle_error(err)
    -- No-op for tests
end

return mock_error_handler
