-- tests/commands/delete_favorite_command_spec.lua
-- Minimal smoke test for delete_favorite_command registration


-- Patch Factorio commands global for test environment (must be first)
if not _G.commands then
    _G.commands = { add_command = function() end }
end
require("tests.test_bootstrap")
-- Patch Factorio commands global for test environment
if not _G.commands then
    _G.commands = { add_command = function() end }
end
local mock_game_helpers = require("tests.mocks.mock_game_helpers")
local mock_cache = require("tests.mocks.mock_cache")
local mock_player_favorites = require("tests.mocks.mock_player_favorites")
local mock_tag_destroy_helper = require("tests.mocks.mock_tag_destroy_helper")
local mock_error_handler = require("tests.mocks.mock_error_handler")

-- Patch globals and dependencies
local old_require = require
local function fake_require(name)
    if name == "core.utils.game_helpers" then return mock_game_helpers end
    if name == "core.cache.cache" then return mock_cache end
    if name == "core.favorite.player_favorites" then return mock_player_favorites end
    if name == "core.tag.tag_destroy_helper" then return mock_tag_destroy_helper end
    if name == "core.utils.error_handler" then return mock_error_handler end
    return old_require(name)
end
_G.require = fake_require

local DeleteFavoriteCommand = old_require("core.commands.delete_favorite_command")
local handler = old_require("core.commands.delete_favorite_command")._handle_delete_favorite_by_slot or
old_require("core.commands.delete_favorite_command").handle_delete_favorite_by_slot

local function make_player(valid)
    return {
        valid = valid ~= false,
        index = 1,
        surface = { index = 1 },
    }
end

describe("DeleteFavoriteCommand", function()
    before_each(function()
        mock_game_helpers.clear()
        mock_cache.clear()
        mock_player_favorites.clear()
        mock_tag_destroy_helper.clear()
        mock_error_handler.clear()
    end)

    it("should have a register_commands function", function()
        assert.is_function = assert.is_function or function(f)
            assert(type(f) == "function", "Expected a function")
        end
        assert.is_function(DeleteFavoriteCommand.register_commands)
    end)

    it("should handle invalid player", function()
        _G.game = { get_player = function() return nil end }
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle invalid slot number format", function()
        _G.game = { get_player = function() return make_player() end }
        local cmd = { player_index = 1, parameter = "notanumber" }
        handler(cmd)
    end)

    it("should handle no favorites found", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites(nil)
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle invalid slot", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({})
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle blank favorite", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "BLANK" } })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle successful favorite deletion", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "GPS1" } })
        mock_cache.set_tag_by_gps({ chart_tag = { valid = true } })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle tag with invalid chart_tag", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "GPS2" } })
        mock_cache.set_tag_by_gps({ chart_tag = { valid = false } })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should handle failed favorite deletion", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "GPS3" } })
        mock_cache.set_tag_by_gps({ chart_tag = { valid = true } })
        mock_player_favorites.set_remove_result({ false, "fail" })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }
        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
    end)

    it("should notify GUI observer if present", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "GPS_NOTIFY" } })
        mock_cache.set_tag_by_gps({ chart_tag = { valid = true } })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }

        -- Mock GuiObserver with a spy on notify
        local notified = {}
        local gui_observer_mock = {
            GuiEventBus = {
                notify = function(event_type, data)
                    notified[event_type] = data
                end
            }
        }
        -- Patch require to return our mock for this test
        local old_require = _G.require
        _G.require = function(name)
            if name == "core.events.gui_observer" then return gui_observer_mock end
            return old_require(name)
        end

        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
        assert.is_not_nil(notified["favorite_removed"])
        assert.equals(1, notified["favorite_removed"].player_index)

        -- Restore require
        _G.require = old_require
    end)

    it("should call remote interface fallback if present", function()
        _G.game = { get_player = function() return make_player() end }
        mock_cache.set_player_favorites({ [1] = { gps = "GPS_REMOTE" } })
        mock_cache.set_tag_by_gps({ chart_tag = { valid = true } })
        _G.Constants = { settings = { BLANK_GPS = "BLANK" } }

        -- Remove GuiObserver to force remote path
        _G.GuiObserver = nil

        -- Mock remote interface
        local called = {}
        _G.remote = {
            interfaces = {
                TeleportFavorites = {
                    refresh_favorites_bar = function(player_index)
                        called[player_index] = true
                    end
                }
            },
            call = function(interface, method, player_index)
                if _G.remote.interfaces[interface] and _G.remote.interfaces[interface][method] then
                    _G.remote.interfaces[interface][method](player_index)
                end
            end
        }

        local cmd = { player_index = 1, parameter = "1" }
        handler(cmd)
        assert(called[1], "Expected remote interface to be called")
    end)

    it("should call register_commands and cover registration logic", function()
        local called = {}
        _G.commands = {
            add_command = function(name, help, handler_fn)
                called[#called+1] = { name = name, help = help, handler_fn = handler_fn }
            end
        }
        _G.Constants = { COMMANDS = { DELETE_FAVORITE_BY_SLOT = "tf-delete-favorite-slot" } }
        -- Patch require to allow handler to be called
        local old_require = _G.require
        _G.require = function(name)
            if name == "core.utils.game_helpers" then return mock_game_helpers end
            if name == "core.cache.cache" then return mock_cache end
            if name == "core.favorite.player_favorites" then return mock_player_favorites end
            if name == "core.tag.tag_destroy_helper" then return mock_tag_destroy_helper end
            if name == "core.utils.error_handler" then return mock_error_handler end
            return old_require(name)
        end
        DeleteFavoriteCommand.register_commands()
        assert(#called > 0, "Expected add_command to be called")
        _G.require = old_require
    end)
end)
