-- test_delete_favorite_command.lua
-- Tests for the /tf-delete-favorite-slot command

local DeleteFavoriteCommand = require("core.commands.delete_favorite_command")
local Cache = require("core.cache.cache")
local Constants = require("constants")
local GameHelpers = require("core.utils.game_helpers")

-- Mock player and game objects
local function mock_player(index)
    return {
        index = index,
        valid = true,
        name = "TestPlayer" .. tostring(index),
        print = function(self, msg) self.last_message = msg end
    }
end

global = { }
game = {
    get_player = function(idx) return mock_player(idx) end,
    players = { [1] = mock_player(1) }
}

-- Mock Cache.get_player_favorites
Cache.get_player_favorites = function(player)
    return {
        [1] = { gps = "gps:1,1,1", locked = false, tag = { gps = "gps:1,1,1", chart_tag = { valid = true, destroy = function() end } } },
        [2] = { gps = "", locked = false, tag = nil },
    }
end

-- Mock tag_destroy_helper
package.loaded["core.tag.tag_destroy_helper"] = {
    destroy_tag_and_chart_tag = function(tag, chart_tag)
        return true
    end
}

-- Test: valid slot deletion
local command = { player_index = 1, parameter = "1" }
DeleteFavoriteCommand.register_commands()
-- Simulate command handler call
local handler = debug.getinfo(DeleteFavoriteCommand.register_commands).func
handler(command)

-- Test: invalid slot (blank)
command.parameter = "2"
handler(command)

-- Test: invalid slot (out of range)
command.parameter = "99"
handler(command)

print("test_delete_favorite_command.lua: All tests executed (manual validation required for print output)")
