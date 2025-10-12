-- Mocks for FavoriteUtils
-- These mocks are used by tests to avoid requiring real mod infrastructure

local favorite_utils_mock = {}

favorite_utils_mock.MAX_FAVORITE_SLOTS = 10

favorite_utils_mock.rehydrate_favorite = function(favorite_data)
    return {
        gps = favorite_data.gps or "1000000.1000000.1",
        name = favorite_data.name or "",
        surface = favorite_data.surface or "nauvis",
        locked = favorite_data.locked or false,
        hidden = favorite_data.hidden or false
    }
end

favorite_utils_mock.create_empty_favorites_data = function()
    return {
        slots = {},
        favorites = {},
        bar_visible = true
    }
end

favorite_utils_mock.get_slot_index_from_element_name = function(element_name)
    if not element_name then return nil end
    local slot_prefix = "fave_bar_slot_"
    if element_name:find(slot_prefix) then
        return tonumber(element_name:sub(#slot_prefix + 1))
    end
    return nil
end

favorite_utils_mock.get_button_type_from_element_name = function(element_name)
    if element_name and element_name:find("teleport_button") then
        return "teleport"
    elseif element_name and element_name:find("hide_button") then
        return "hide"
    elseif element_name and element_name:find("lock_button") then
        return "lock"
    end
    return nil
end

return favorite_utils_mock