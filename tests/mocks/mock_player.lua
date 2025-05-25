-- tests/mocks/mock_player.lua
-- Minimal mock for a LuaPlayer object

local function make_player(index, name)
  local obj = {
    index = index,
    name = name or ("TestPlayer" .. tostring(index)),
    print = function() end,
    surface = { name = "nauvis" },
    can_insert = function() return true end,
    get_inventory = function() return {} end,
    get_main_inventory = function() return {} end,
    is_player = true,
    force = { name = "player" },
    character = {}, -- Ensure player.character is present for teleport tests
    valid = true,
    driving = false,
    vehicle = nil,
  }
  function obj:teleport(...) return true end -- method, not field
  return setmetatable(obj, {
    __index = function(self, k)
      if k == "teleport" then return nil end -- do not shadow the real method
      return function() end
    end
  })
end

return make_player
