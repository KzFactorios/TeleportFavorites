--
-- CANONICAL MOCK LuaPlayer FACTORY FOR ALL TESTS
-- Use mock_luaPlayer for any LuaPlayer mock in tests.
--

local function mock_luaPlayer(index, name, surface_index)
    local player = {
        index = index or 1,
        name = name or ("Player" .. tostring(index)),
        valid = true,
        surface = {
            index = surface_index or 1,
            valid = true,
            name = "nauvis",
            get_tile = function() return { name = "grass-1" } end
        },
        mod_settings = {
            ["favorites_on"] = { value = true },
            ["show-player-coords"] = { value = true },
            ["enable_teleport_history"] = { value = true },
            ["chart-tag-click-radius"] = { value = 10 }
        },
        settings = {},
        admin = false,
        render_mode = (defines and defines.render_mode and defines.render_mode.game) or "game",
        controller_type = "character",
        position = { x = 0, y = 0 },
        driving = false,
        vehicle = nil,
        riding_state = (defines and defines.riding and defines.riding.acceleration and defines.riding.acceleration.nothing) or 0,
        character = {
            position = { x = 0, y = 0 },
            valid = true,
            teleport = function() return true end
        },
        print = function() end,
        play_sound = function() end,
        get_main_inventory = function() return { valid = true, is_empty = function() return true end } end,
        connect_to_server = function() end,
        enable_tutorial = function() end,
        cancel_crafting = function() end,
        is_shortcut_toggled = function() return false end,
        set_shortcut_toggled = function() end,
        is_cursor_blueprint = function() return false end,
        is_cursor_empty = function() return true end,
        is_cursor_ghost = function() return false end,
        is_cursor_item = function() return false end,
        is_cursor_tile = function() return false end,
        is_flashlight_enabled = function() return true end,
        enable_flashlight = function() end,
        disable_flashlight = function() end,
        get_friends = function() return {} end,
        get_associated_characters = function() return {} end,
        get_inventory = function() return { valid = true, is_empty = function() return true end } end,
        get_quick_bar = function() return {} end,
        get_blueprint_entities = function() return {} end,
        get_vehicle = function() return nil end,
        get_item_count = function() return 0 end,
        get_player = function() return player end,
        get_mod_setting = function() return true end,
        get_permissions = function() return {} end,
        get_shortcut_state = function() return false end,
        set_shortcut_state = function() end,
        clear_personal_trash = function() end,
        clear_cursor = function() end,
        clear_items_inside = function() end,
        add_alert = function() end,
        add_custom_alert = function() end,
        add_item = function() end,
        remove_alert = function() end,
        remove_item = function() end,
        remove_shortcut = function() end,
        teleport = function() end,
        walking_state = {},
        gui = { top = {}, left = {}, center = {}, screen = {}, mod = {}, relative = {}, valid = true },
        display_resolution = { width = 1920, height = 1080 },
        display_scale = 1,
        get_active_quick_bar_page = function() return 1 end,
        set_active_quick_bar_page = function() end,
        get_inventory_definitions = function() return {} end,
        get_associated_force = function() return { name = "player" } end,
        get_associated_surface = function() return player.surface end,
        get_associated_position = function() return player.position end,
        get_associated_gui = function() return { top = {}, left = {}, center = {}, screen = {}, mod = {}, relative = {}, valid = true } end,
        opened_self = false,
        permissions = {},
        request_translation = function() end,
        unlock_achievement = function() end,
        open_map = function() end,
        begin_crafting = function() end,
        -- ...add more as needed for full LuaPlayer compatibility
    }
    -- Add type marker and type method for compatibility with type checks
    player.__self = "LuaPlayer"
    player.is_player = true
    player.type = function() return "player" end
    setmetatable(player, {
        __type = "LuaPlayer",
        __index = player,
        __tostring = function() return "[MockLuaPlayer]" end
    })
    return player
end

return mock_luaPlayer
