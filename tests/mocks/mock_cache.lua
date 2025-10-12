-- mock_cache.lua
-- Mock implementation of cache module

local mock_cache = {}

mock_cache.storage = {
    players = {},
    surfaces = {},
    latest_created_tag_by_player = {}
}

function mock_cache.initialize()
    return true
end

function mock_cache.get_player_data(player)
    local index = player.index
    mock_cache.storage.players[index] = mock_cache.storage.players[index] or {
        surfaces = {},
        settings = {},
        tag_editor_data = {},
        slots = {},
        favorites = {}
    }
    return mock_cache.storage.players[index]
end

function mock_cache.get_surface_data(surface_index)
    mock_cache.storage.surfaces[surface_index] = mock_cache.storage.surfaces[surface_index] or {
        tags = {}
    }
    return mock_cache.storage.surfaces[surface_index]
end

function mock_cache.get_surface_tags(surface_index)
    local surface_data = mock_cache.get_surface_data(surface_index)
    return surface_data.tags
end

function mock_cache.get_tag_data(surface_index, gps)
    local surface_tags = mock_cache.get_surface_tags(surface_index)
    return surface_tags[gps]
end

function mock_cache.set_tag_data(surface_index, gps, tag_data)
    local surface_tags = mock_cache.get_surface_tags(surface_index)
    surface_tags[gps] = tag_data
end

function mock_cache.get_tag_editor_data(player)
    local player_data = mock_cache.get_player_data(player)
    player_data.tag_editor_data = player_data.tag_editor_data or {}
    return player_data.tag_editor_data
end

function mock_cache.set_tag_editor_data(player, editor_data)
    local player_data = mock_cache.get_player_data(player)
    player_data.tag_editor_data = editor_data
end

function mock_cache.clear_tag_editor_data(player)
    local player_data = mock_cache.get_player_data(player)
    player_data.tag_editor_data = {}
end

function mock_cache.remove_tag(surface_index, gps)
    local surface_tags = mock_cache.get_surface_tags(surface_index)
    surface_tags[gps] = nil
end

return mock_cache