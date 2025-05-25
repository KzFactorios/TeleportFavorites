-- tests/mocks/mock_player.lua
-- Minimal mock for a LuaPlayer object
-- print("[MOCK_PLAYER] mock_player.lua loaded!")

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
  obj.teleport = function(self, ...)
    -- Accept both : and . calls
    if type(self) == "table" and self.index and self.valid ~= false then
      return true
    end
    return true
  end
  return setmetatable(obj, {
    __index = function(self, k)
      if k == "teleport" then return obj.teleport end
      if rawget(self, k) ~= nil then return rawget(self, k) end
      return function() end
    end
  })
end

return make_player
