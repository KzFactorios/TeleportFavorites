-- tests/unit/test_player_favorites.lua
-- Unit tests for core.favorite.player_favorites
local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")
local Constants = require("constants")

local function mock_player(index)
  local player = {
    index = index or 1,
    surface = { index = 1 },
    mod_settings = {},
    print = function(self, message) return message end,
    display_scale = 1.0,
    display_resolution = {width=1920, height=1080},
    name = "TestPlayer",
    valid = true,
    character = true,
    driving = false,
    vehicle = nil,
    riding_state = nil,
    force = { is_chunk_charted = function() return true end },
    render_mode = 0,
    opened_self = false,
  }
  setmetatable(player, {
    __index = function(_, key)
      return function() end -- Return a dummy function for any missing method
    end
  })
  return player
end

local function test_new_and_get_all()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  local all = pf:get_all()
  assert(type(all) == "table" and #all == Constants.settings.MAX_FAVORITE_SLOTS, "Should have correct number of slots")
end

local function test_add_and_remove_favorite()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  local gps = "1.2.1"
  assert(pf:add_favorite(gps), "Should add favorite")
  assert(pf:get_favorite_by_gps(gps), "Should retrieve added favorite")
  pf:remove_favorite(gps)
  assert(not pf:get_favorite_by_gps(gps), "Should remove favorite")
end

local function run_all()
  test_new_and_get_all()
  test_add_and_remove_favorite()
  print("All PlayerFavorites tests passed.")
end

run_all()
