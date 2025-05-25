---@diagnostic disable: assign-type-mismatch, param-type-mismatch, return-type-mismatch
-- tests/unit/test_player_favorites.lua
-- Unit tests for core.favorite.player_favorites
local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")
local Constants = require("constants")

local defines = _G.defines or { render_mode = { game = 0, chart = 1, chart_zoomed_in = 2, chart_zoomed_out = 3 } }

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
    character = nil,
    driving = false,
    vehicle = nil,
    riding_state = nil,
    force = { is_chunk_charted = function() return true end },
    ---@diagnostic disable-next-line: assign-type-mismatch
    render_mode = defines.render_mode.game,
    opened_self = false,
    clear_personal_trash = function() end,
    clear_personal_logistics = function() end,
    clear_items_inside = function() end,
    clear_cursor = function() end,
    clear = function() end,
    get_inventory = function() return {} end,
    get_main_inventory = function() return {} end,
    get_quick_bar = function() return {} end,
    get_active_quick_bar = function() return {} end,
    is_shortcut_toggled = function() return false end,
    teleport = function() return true end,
    set_controller = function() end,
    promote = function() end,
    update_selected_entity = function() end,
    add_item = function() end,
    play_sound = function() end,
    get_crafting_queue_size = function() return 0 end,
    request_translation = function() end,
    create_local_flying_text = function() end,
    cancel_crafting = function() end,
    -- Add more stubs as needed for strict static analysis
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

local function test_fill_all_slots_and_overflow()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  -- Fill all slots
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local gps = tostring(i) .. ".0.0"
    assert(pf:add_favorite(gps), "Should add favorite to slot " .. i)
  end
  -- All slots should be filled
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local gps = tostring(i) .. ".0.0"
    assert(pf:get_favorite_by_gps(gps), "Favorite should exist for " .. gps)
  end
  -- Try to add one more (should fail)
  assert(not pf:add_favorite("overflow.gps"), "Should not add favorite when full")
end

local function test_first_and_last_slot()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  local first_gps = "first.1.1"
  local last_gps = "last.9.9"
  assert(pf:add_favorite(first_gps), "Should add to first slot")
  for i = 2, Constants.settings.MAX_FAVORITE_SLOTS - 1 do
    pf:add_favorite("mid." .. i)
  end
  assert(pf:add_favorite(last_gps), "Should add to last slot")
  assert(pf:get_favorite_by_gps(first_gps), "First slot favorite exists")
  assert(pf:get_favorite_by_gps(last_gps), "Last slot favorite exists")
  pf:remove_favorite(first_gps)
  pf:remove_favorite(last_gps)
  assert(not pf:get_favorite_by_gps(first_gps), "First slot favorite removed")
  assert(not pf:get_favorite_by_gps(last_gps), "Last slot favorite removed")
end

local function test_remove_nonexistent()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  pf:remove_favorite("not.exists") -- Should not error
  assert(true, "Removing non-existent favorite should not error")
end

local function test_duplicate_gps()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  local gps = "dup.1.1"
  assert(pf:add_favorite(gps), "Should add first instance")
  -- Try to add again (should add to next slot, not overwrite)
  assert(pf:add_favorite(gps), "Should add duplicate GPS to next slot")
  -- Both slots should reference the same GPS string, but only one should be in the lookup
  local count = 0
  for _, fav in ipairs(pf:get_all()) do
    if fav.gps == gps then count = count + 1 end
  end
  assert(count == 2, "Duplicate GPS should appear in two slots")
end

local function test_set_favorites()
  local player = mock_player(1)
  local pf = PlayerFavorites.new(player)
  local new_faves = {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    new_faves[i] = Favorite.get_blank_favorite()
    new_faves[i].gps = "set." .. i
  end
  pf:set_favorites(new_faves)
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    assert(pf:get_all()[i].gps == "set." .. i, "set_favorites should update all slots")
  end
end

local function test_validate_gps()
  assert(PlayerFavorites.validate_gps("1.2.3"), "Valid GPS should pass")
  local ok, msg = PlayerFavorites.validate_gps("")
  assert(not ok and msg, "Empty GPS should fail validation")
  ok, msg = PlayerFavorites.validate_gps(nil)
  assert(not ok and msg, "Nil GPS should fail validation")
end

local function run_all()
  test_new_and_get_all()
  test_add_and_remove_favorite()
  test_fill_all_slots_and_overflow()
  test_first_and_last_slot()
  test_remove_nonexistent()
  test_duplicate_gps()
  test_set_favorites()
  test_validate_gps()
  print("All PlayerFavorites tests passed.")
end

run_all()
