-- Enhanced mock player factory for vehicle testing

local mock_luaPlayer = require("tests.mocks.mock_luaPlayer")

local VehicleMocks = {}

--- Create a mock vehicle
---@param vehicle_type string Vehicle type (car, tank, etc.)
---@param is_valid boolean? Whether vehicle is valid (default true)
---@return table Mock vehicle
function VehicleMocks.create_mock_vehicle(vehicle_type, is_valid)
  vehicle_type = vehicle_type or "car"
  is_valid = is_valid ~= false
  
  return {
    name = vehicle_type,
    valid = is_valid,
    position = {x = 10, y = 10},
    teleport = function(position, surface, raise_built)
      if not is_valid then return false end
      return true
    end,
    type = vehicle_type,
    prototype = {
      name = vehicle_type
    }
  }
end

--- Create a mock player in a vehicle
---@param index number? Player index (default 1)
---@param name string? Player name (default "TestPlayer")
---@param surface_index number? Surface index (default 1)
---@param vehicle_type string? Vehicle type (default "car")
---@param is_driving_actively boolean? Whether actively driving (default false)
---@param vehicle_valid boolean? Whether vehicle is valid (default true)
---@return table Mock player in vehicle
function VehicleMocks.create_player_in_vehicle(index, name, surface_index, vehicle_type, is_driving_actively, vehicle_valid)
  local player = mock_luaPlayer(index, name, surface_index)
  local vehicle = VehicleMocks.create_mock_vehicle(vehicle_type, vehicle_valid)
  
  player.driving = true
  player.vehicle = vehicle
  player.riding_state = is_driving_actively and 1 or 0 -- 1 = accelerating, 0 = nothing
  
  return player
end

--- Create a mock player on foot (not in vehicle)
---@param index number? Player index (default 1) 
---@param name string? Player name (default "TestPlayer")
---@param surface_index number? Surface index (default 1)
---@return table Mock player on foot
function VehicleMocks.create_player_on_foot(index, name, surface_index)
  local player = mock_luaPlayer(index, name, surface_index)
  
  player.driving = false
  player.vehicle = nil
  player.riding_state = 0 -- nothing
  
  return player
end

return VehicleMocks
