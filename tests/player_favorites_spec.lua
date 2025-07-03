-- Mock Factorio settings global (must be global before any require)
if not settings then
    _G.settings = {}
    settings = _G.settings
end
function settings.get_player_settings(player)
    return {
        ["show-player-coords"] = {
            value = true
        }
    }
end

if not storage then
    _G.storage = {}
    storage = _G.storage
end

-- Mock Factorio defines (enums)
if not defines then
    defines = {
        render_mode = {
            chart = "chart",
            chart_zoomed_in = "chart-zoomed-in",
            game = "game"
        },
        direction = {},
        gui_type = {},
        inventory = {},
        print_sound = {},
        print_skip = {},
        chunk_generated_status = {},
        controllers = {},
        riding = {
            acceleration = {},
            direction = {}
        },
        alert_type = {},
        wire_type = {},
        circuit_connector_id = {},
        rail_direction = {},
        rail_connection_direction = {}
    }
end

if not game then
    _G.game = {
        tick = 123456,
        players = {},
        print = function()
        end
    }
    game = _G.game
end


remote = remote or {}
script = script or {}
rcon = rcon or {}
commands = commands or {}
mod = mod or {}
rendering = rendering or {}

if not settings then
    settings = {}
end
function settings.get_player_settings(player)
    return {
        ["show-player-coords"] = {
            value = true
        }
    }
end

-- Mock player factory (must be defined before any use)
local function mock_player(index, name, surface_index)
    return {
        index = index or 1,
        name = name or "Guinan",
        valid = true,
        surface = {
            index = surface_index or 1
        },
        mod_settings = {
            ["favorites-on"] = {
                value = true
            },
            ["show-player-coords"] = {
                value = true
            },
            ["show-teleport-history"] = {
                value = true
            },
            ["chart-tag-click-radius"] = {
                value = 10
            }
        },
        settings = {},
        admin = false,
        render_mode = defines.render_mode.game,
        print = function()
        end,
        play_sound = function()
        end
    }
end

local FavoriteUtils = require("core.favorite.favorite")
local Constants = require("constants")
local notified = {}
_G.game = {
    players = {
        [1] = mock_player(1)
    },
    tick = 123456
}
local function reset_notified()
    for k in pairs(notified) do
        notified[k] = nil
    end
end
_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            notified[event_type] = data
            if event_type == "favorite_removed" then
                    -- ...
            end
        end
    }
}
-- Now require the production observer module, so it uses the test mock
require("core.events.gui_observer")

-- Require PlayerFavorites only after all mocks are set up
local PlayerFavorites = require("core.favorite.player_favorites")

if not global then
    global = {}
end
if not global.cache then
    global.cache = {}
end

if not storage then
    storage = {}
end



-- Mock Cache
local Cache = require("core.cache.cache")
if not Cache.get_player_favorites then
    function Cache.get_player_favorites(player)
    end
end
if not Cache.get_tag_by_gps then
    function Cache.get_tag_by_gps(player, gps)
        return nil
    end
end


-- Now require the production observer module, so it uses the test mock
require("core.events.gui_observer")

-- Tests

describe("PlayerFavorites", function()
    before_each(function()
        reset_notified()
        -- Always set game.players[1] to the test player before each test
        local player = mock_player(1)
        game.players[1] = player
        -- Ensure game.tick is always set for observer
        if not game.tick then
            game.tick = 123456
        end
        -- Reset persistent storage to avoid cross-test contamination
        for k in pairs(storage) do
            storage[k] = nil
        end
    end)

    it("should construct with blank favorites if none in storage", function()
        local player = game.players[1]
        local pf = PlayerFavorites.new(player)
        assert.is_table(pf.favorites)
        assert.equals(#pf.favorites, Constants.settings.MAX_FAVORITE_SLOTS)
        for _, fav in ipairs(pf.favorites) do
            assert.is_true(FavoriteUtils.is_blank_favorite(fav))
        end
    end)

    it("should add and remove a favorite", function()
        local player = game.players[1]
        local pf = PlayerFavorites.new(player)
        local fav, err = pf:add_favorite("gps1")
        assert.is_table(fav)
        assert.is_nil(err)
        assert.equals(fav.gps, "gps1")
        assert.is_true(notified["favorite_added"] ~= nil)
        local found_fav, found_slot = pf:get_favorite_by_gps("gps1")
            -- ...
        for i, f in ipairs(pf.favorites) do
                -- ...
        end
    assert.is_not_nil(found_fav)
    assert.equals(found_fav.gps, "gps1")
    assert.is_not_nil(found_slot)
        local ok, err2 = pf:remove_favorite("gps1")
        assert.is_true(ok)
        assert.is_nil(err2)
            -- ...
        assert.is_true(notified["favorite_removed"] ~= nil)
    end)

    it("should not add duplicate favorite", function()
        local player = game.players[1]
        local pf = PlayerFavorites.new(player)
        pf:add_favorite("gps1")
        local fav2, err2 = pf:add_favorite("gps1")
        assert.is_table(fav2)
        assert.is_nil(err2)
    end)

    it("should toggle favorite lock", function()
        local player = mock_player(1)
        local pf = PlayerFavorites.new(player)
        pf:add_favorite("gps1")
        local ok, err = pf:toggle_favorite_lock(1)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_true(pf.favorites[1].locked)
    end)

    it("should update gps coordinates", function()
        local player = mock_player(1)
        local pf = PlayerFavorites.new(player)
        pf:add_favorite("gps1")
        local ok = pf:update_gps_coordinates("gps1", "gps2")
        assert.is_true(ok)
        assert.equals(pf.favorites[1].gps, "gps2")
    end)

    it("should count available slots", function()
        local player = mock_player(1)
        local pf = PlayerFavorites.new(player)
        assert.equals(pf:available_slots(), Constants.settings.MAX_FAVORITE_SLOTS)
        pf:add_favorite("gps1")
        assert.equals(pf:available_slots(), Constants.settings.MAX_FAVORITE_SLOTS - 1)
    end)

    it("diagnostic: is_blank_favorite and slot count after add/remove", function()
        local player = mock_player(1)
        local pf = PlayerFavorites.new(player)
        -- Initial state: all blank
        -- ...
        for i, fav in ipairs(pf.favorites) do
            if not FavoriteUtils.is_blank_favorite(fav) then
            -- ...
            end
            assert.is_true(FavoriteUtils.is_blank_favorite(fav), "Slot " .. i .. " should be blank at start")
        end
        assert.equals(pf:available_slots(), Constants.settings.MAX_FAVORITE_SLOTS)

        -- Add a favorite
        local fav, err = pf:add_favorite("gps1")
        assert.is_nil(err)
        -- ...
        local blank_count = 0
        for i, f in ipairs(pf.favorites) do
            if not FavoriteUtils.is_blank_favorite(f) then
            -- ...
            end
            if FavoriteUtils.is_blank_favorite(f) then
                blank_count = blank_count + 1
            end
        end
        assert.equals(blank_count, Constants.settings.MAX_FAVORITE_SLOTS - 1, "Should have one less blank after add")
        assert.equals(pf:available_slots(), Constants.settings.MAX_FAVORITE_SLOTS - 1)

        -- Remove the favorite
        local ok, err2 = pf:remove_favorite("gps1")
        assert.is_true(ok)
        -- ...
        blank_count = 0
        for i, f in ipairs(pf.favorites) do
            if not FavoriteUtils.is_blank_favorite(f) then
            -- ...
            end
            if FavoriteUtils.is_blank_favorite(f) then
                blank_count = blank_count + 1
            end
        end
        assert.equals(blank_count, Constants.settings.MAX_FAVORITE_SLOTS, "Should return to all blank after remove")
        assert.equals(pf:available_slots(), Constants.settings.MAX_FAVORITE_SLOTS)
    end)
end)
