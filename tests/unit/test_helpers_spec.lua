-- tests/unit/test_helpers.lua
-- Unit tests for core.utils.Helpers
local Helpers = require("core.utils.helpers")
local mock_game = require("tests.mocks.mock_game")
local mock_helpers = require("tests.mocks.mock_helpers")
mock_helpers.set_global_game(mock_game)

describe("Helpers", function()
  it("should trim leading/trailing spaces", function()
    assert.equals("foo", Helpers.trim("  foo  "))
  end)
  it("should trim tabs/newlines", function()
    assert.equals("bar", Helpers.trim("\tbar\n"))
  end)
  it("should return empty string when trimming empty string", function()
    assert.equals("", Helpers.trim(""))
  end)
  it("should pad with leading zeros", function()
    assert.equals("005", Helpers.pad(5, 3))
  end)
  it("should not truncate when padding", function()
    assert.equals("123", Helpers.pad(123, 2))
  end)
  it("should count dense arrays", function()
    local arr = {1,2,3}
    assert.equals(3, Helpers.table_count(arr))
  end)
  it("should count sparse arrays", function()
    local sparse = { [1]=1, [3]=3, [10]=10 }
    assert.equals(3, Helpers.table_count(sparse))
  end)
  it("should count empty table as 0", function()
    local empty = {}
    assert.equals(0, Helpers.table_count(empty))
  end)
  it("should count nil as 0", function()
    assert.equals(0, Helpers.table_count(nil))
  end)
  it("should count non-table as 0", function()
    assert.equals(0, Helpers.table_count(123))
  end)
end)

describe("Helpers edge cases", function()
  local Helpers = require("core.utils.helpers")

  it("should handle math_round with non-number", function()
    assert.equals(0, Helpers.math_round(nil))
    assert.equals(0, Helpers.math_round("foo"))
  end)

  it("should handle tables_equal with non-tables", function()
    assert.is_true(Helpers.tables_equal(nil, nil))
    assert.is_false(Helpers.tables_equal({}, nil))
    assert.is_false(Helpers.tables_equal(nil, {}))
    assert.is_true(Helpers.tables_equal({}, {}))
  end)

  it("should handle deep_copy with non-table", function()
    assert.equals(123, Helpers.deep_copy(123))
    assert.equals("foo", Helpers.deep_copy("foo"))
  end)

  it("should handle table_is_empty with non-table", function()
    assert.is_true(Helpers.table_is_empty(nil))
    assert.is_true(Helpers.table_is_empty(123))
  end)

  it("should handle remove_first with missing value", function()
    local t = { 1, 2, 3 }
    assert.is_false(Helpers.remove_first(t, 99))
    assert.same({ 1, 2, 3 }, t)
  end)

  it("should handle split_string with bad input", function()
    assert.same({}, Helpers.split_string(nil, ","))
    assert.same({}, Helpers.split_string("foo", nil))
    assert.same({}, Helpers.split_string("foo", ""))
  end)
end)

describe("Helpers additional coverage", function()
  local Helpers = require("core.utils.helpers")

  it("format_sprite_path returns empty if _G.helpers is missing", function()
    _G.helpers = nil
    assert.equals("", Helpers.format_sprite_path("item", "iron-plate"))
  end)

  it("format_sprite_path returns empty if is_valid_sprite_path returns false", function()
    _G.helpers = { is_valid_sprite_path = function() return false end }
    assert.equals("", Helpers.format_sprite_path("item", "iron-plate"))
  end)

  it("format_sprite_path handles virtual signal type", function()
    _G.helpers = { is_valid_sprite_path = function() return true end }
    assert.equals("virtual-signal/iron-plate", Helpers.format_sprite_path("virtual", "iron-plate"))
  end)

  it("is_on_space_platform returns false for nil player or surface", function()
    assert.is_false(Helpers.is_on_space_platform(nil))
    assert.is_false(Helpers.is_on_space_platform({}))
    assert.is_false(Helpers.is_on_space_platform({ surface = {} }))
  end)

  it("is_on_space_platform returns true if surface name contains 'space'", function()
    local player = { surface = { name = "space-foo" } }
    assert.is_true(Helpers.is_on_space_platform(player))
  end)

  it("position_has_colliding_tag returns nil if player.force.find_chart_tags returns nil or empty", function()
    local player = { force = { find_chart_tags = function() return nil end }, surface = {} }
    local pos = { x = 0, y = 0 }
    assert.is_nil(Helpers.position_has_colliding_tag(player, pos, 1))
    player.force.find_chart_tags = function() return {} end
    assert.is_nil(Helpers.position_has_colliding_tag(player, pos, 1))
  end)

  it("position_has_colliding_tag returns first tag if present", function()
    local player = { force = { find_chart_tags = function() return { { id = 42 } } end }, surface = {} }
    local pos = { x = 0, y = 0 }
    local result = Helpers.position_has_colliding_tag(player, pos, 1)
    assert.is_table(result)
    assert.equals(42, result.id)
  end)

  it("is_water_tile returns false if surface or get_tile is missing", function()
    assert.is_false(Helpers.is_water_tile(nil, { x = 1, y = 2 }))
    assert.is_false(Helpers.is_water_tile({}, { x = 1, y = 2 }))
  end)

  it("is_water_tile returns false if collision_mask is missing or not water-tile", function()
    local surface = { get_tile = function() return { prototype = { collision_mask = { "ground-tile" } } } end }
    assert.is_false(Helpers.is_water_tile(surface, { x = 1, y = 2 }))
    surface.get_tile = function() return { prototype = { collision_mask = {} } } end
    assert.is_false(Helpers.is_water_tile(surface, { x = 1, y = 2 }))
  end)

  it("is_water_tile returns true if collision_mask contains water-tile", function()
    local surface = { get_tile = function() return { prototype = { collision_mask = { "water-tile", "ground-tile" } } } end }
    assert.is_true(Helpers.is_water_tile(surface, { x = 1, y = 2 }))
  end)

  it("normalize_player_index handles string and nil", function()
    assert.equals(0, Helpers.normalize_player_index(nil))
    assert.equals(42, Helpers.normalize_player_index("42"))
  end)

  it("normalize_surface_index handles string and nil", function()
    assert.equals(0, Helpers.normalize_surface_index(nil))
    assert.equals(99, Helpers.normalize_surface_index("99"))
  end)
end)
