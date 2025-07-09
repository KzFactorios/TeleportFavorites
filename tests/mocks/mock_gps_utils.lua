-- tests/mocks/mock_gps_utils.lua
-- Minimal mock for core.utils.gps_utils

local mock_gps_utils = {}

function mock_gps_utils.coords_string_from_gps(gps)
    return "0, 0"
end

function mock_gps_utils.gps_from_map_position(map_position, surface_index)
    return "gps:0.0.1"
end

function mock_gps_utils.map_position_from_gps(gps)
    return {x=0, y=0}
end

function mock_gps_utils.get_surface_index_from_gps(gps)
    return 1
end

return mock_gps_utils
