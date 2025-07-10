-- tests/mocks/mock_fave_bar.lua
-- Minimal mock for gui.favorites_bar.fave_bar

local mock_fave_bar = {}

function mock_fave_bar.build(player, force)
    if player and player.valid then
        player._fave_bar_built = (force and "forced" or "normal")
    end
    return true
end

return mock_fave_bar
