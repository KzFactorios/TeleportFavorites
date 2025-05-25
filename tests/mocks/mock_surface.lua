-- tests/mocks/mock_surface.lua
-- Minimal mock for a LuaSurface object

return function(index)
  return setmetatable({
    index = index,
    name = "nauvis",
    find_non_colliding_position = function() return {x=0, y=0} end,
    -- Add any other required Factorio LuaSurface API fields/methods here
  }, {
    __index = function(_, k)
      return function() end
    end
  })
end
