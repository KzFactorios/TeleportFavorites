--
-- CANONICAL MOCK LuaPlayer FACTORY FOR ALL TESTS
-- Use mock_luaPlayer for any LuaPlayer mock in tests.
--

local function mock_luaPlayer(index, name, surface_index)
    local player = {}
    player.index = index or 1
    player.name = name or ("Player" .. tostring(index))
    player.valid = true
    player.surface = {
        index = surface_index or 1,
        valid = true,
        name = "nauvis",
        get_tile = function() return { name = "grass-1" } end
    }
    player.mod_settings = {
        ["favorites_on"] = { value = true },
        ["show-player-coords"] = { value = true },
        ["enable_teleport_history"] = { value = true },
        ["chart-tag-click-radius"] = { value = 10 }
    }
    player.settings = {}
    player.admin = false
    player.render_mode = "game"
    player.controller_type = "character"
    player.position = { x = 0, y = 0 }
    player.driving = false
    player.vehicle = nil
    player.riding_state = 0
    player.character = {
        position = { x = 0, y = 0 },
        valid = true,
        teleport = function() return true end
    }
    player.print = function() end
    player.play_sound = function() end
    player.get_main_inventory = function() return { valid = true, is_empty = function() return true end } end
    player.connect_to_server = function() end
    player.enable_tutorial = function() end
    player.cancel_crafting = function() end
    player.is_shortcut_toggled = function() return false end
    player.set_shortcut_toggled = function() end
    player.is_cursor_blueprint = function() return false end
    player.is_cursor_empty = function() return true end
    player.is_cursor_ghost = function() return false end
    player.is_cursor_item = function() return false end
    player.is_cursor_tile = function() return false end
    player.is_flashlight_enabled = function() return true end
    player.enable_flashlight = function() end
    player.disable_flashlight = function() end
    player.get_friends = function() return {} end
    player.get_associated_characters = function() return {} end
    player.get_inventory = function() return { valid = true, is_empty = function() return true end } end
    player.get_quick_bar = function() return {} end
    player.get_blueprint_entities = function() return {} end
    player.get_vehicle = function() return nil end
    player.get_item_count = function() return 0 end
    player.get_player = function() return player end
    player.get_mod_setting = function() return true end
    player.get_permissions = function() return {} end
    player.get_shortcut_state = function() return false end
    player.set_shortcut_state = function() end
    player.clear_personal_trash = function() end
    player.clear_cursor = function() end
    player.clear_items_inside = function() end
    player.add_alert = function() end
    player.add_custom_alert = function() end
    player.add_item = function() end
    player.remove_alert = function() end
    player.remove_item = function() end
    player.remove_shortcut = function() end
    player.teleport = function() end
    player.walking_state = {}
    player.gui = { top = {}, left = {}, center = {}, screen = {}, mod = {}, relative = {}, valid = true }
    player.display_resolution = { width = 1920, height = 1080 }
    player.display_scale = 1
    player.get_active_quick_bar_page = function() return 1 end
    player.set_active_quick_bar_page = function() end
    player.get_inventory_definitions = function() return {} end
    player.get_associated_force = function() return { name = "player" } end
    player.get_associated_surface = function() return player.surface end
    player.get_associated_position = function() return player.position end
    player.get_associated_gui = function() return player.gui end
    player.opened_self = false
    player.permissions = {}
    player.request_translation = function() end
    player.unlock_achievement = function() end
    player.open_map = function() end
    player.begin_crafting = function() end
    -- ...add more as needed for full LuaPlayer compatibility
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
