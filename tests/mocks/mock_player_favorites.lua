-- tests/mocks/mock_player_favorites.lua
local calls = {}
local MockPlayerFavorites = {}
MockPlayerFavorites._remove_result = { true, nil }

function MockPlayerFavorites.new(player)
    return setmetatable({ player = player }, { __index = MockPlayerFavorites })
end

function MockPlayerFavorites:remove_favorite(gps)
    table.insert(calls, { action = "remove_favorite", player = self.player, gps = gps })
    -- Lua 5.1 compatibility: use unpack instead of table.unpack
    return (table.unpack or unpack)(MockPlayerFavorites._remove_result)
end

function MockPlayerFavorites.set_remove_result(result)
    MockPlayerFavorites._remove_result = result
end

function MockPlayerFavorites.clear()
    for i = #calls, 1, -1 do table.remove(calls, i) end
    MockPlayerFavorites._remove_result = { true, nil }
end

function MockPlayerFavorites.get_calls()
    return calls
end

return MockPlayerFavorites
