-- mock_cache.lua
-- Mock implementation of cache module

local mock_cache = {}
local Constants = require("constants")

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

function mock_cache.reset_transient_player_states(player)
    return true
end

function mock_cache.get_favorites_render_snapshot(player, surface_index, max_slots)
    if not player or not player.index then return {} end
    local player_data = mock_cache.get_player_data(player)
    player_data.surfaces = player_data.surfaces or {}
    local idx = surface_index or (player.surface and player.surface.index) or 1
    player_data.surfaces[idx] = player_data.surfaces[idx] or {}
    local snapshot = player_data.surfaces[idx].favorites_render_snapshot
    if type(snapshot) ~= "table" then return {} end

    local limit = max_slots or #snapshot
    local result = {}
    for i = 1, limit do
        local entry = snapshot[i]
        if type(entry) == "table" and type(entry.gps) == "string" and entry.gps ~= "" then
            result[i] = {
                gps = entry.gps,
                locked = entry.locked == true,
                tag = entry.icon and {
                    chart_tag = {
                        valid = true,
                        icon = entry.icon,
                        text = entry.text or ""
                    }
                } or nil
            }
        else
            result[i] = { gps = Constants.settings.BLANK_GPS, locked = false }
        end
    end
    return result
end

return mock_cache