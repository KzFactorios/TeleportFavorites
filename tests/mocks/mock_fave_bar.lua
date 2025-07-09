-- tests/mocks/mock_fave_bar.lua
-- Minimal mock for gui.favorites_bar.fave_bar

local mock_fave_bar = {}

function mock_fave_bar.build(player, force)
    -- No-op for tests
    return true
end

return mock_fave_bar
