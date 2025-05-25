-- tests/mocks/mock_game.lua
-- Minimal mock for the global `game` object and surfaces

local mock_game = {}

mock_game.surfaces = {
  ["nauvis"] = { index = 1, name = "nauvis" },
  [1] = { index = 1, name = "nauvis" },
  ["surface-2"] = { index = 2, name = "surface-2" },
  [2] = { index = 2, name = "surface-2" },
}

function mock_game.get_surface_by_index(index)
  for _, surface in pairs(mock_game.surfaces) do
    if surface.index == index then
      return surface
    end
  end
  return nil
end

return mock_game
