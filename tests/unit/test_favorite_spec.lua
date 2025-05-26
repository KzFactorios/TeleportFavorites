-- luacheck: globals describe it assert before_each after_each
-- EmmyLua/sumneko: ignore undefined test framework globals in this file
-- This file is intended to be run with Busted, which provides these globals.

-- tests/unit/test_favorite_spec.lua
-- Unit tests for core.favorite.favorite
local Favorite = require("core.favorite.favorite")
local BLANK_GPS = "1000000.1000000.1"

describe("Favorite 100% coverage edge cases", function()
  it("is_blank_favorite returns true for blank favorite", function()
    assert.is_true(Favorite.is_blank_favorite({ gps = BLANK_GPS }))
    assert.is_true(Favorite.is_blank_favorite({ gps = BLANK_GPS, text = "", locked = false }))
  end)

  it("is_blank_favorite returns false for non-blank favorite", function()
    assert.is_false(Favorite.is_blank_favorite({ gps = "1.2.1" }))
    assert.is_false(Favorite.is_blank_favorite({ gps = "1.2.1", text = "foo", locked = true }))
  end)

  it("get_blank_favorite returns a blank favorite", function()
    local blank = Favorite.get_blank_favorite()
    assert.is_true(Favorite.is_blank_favorite(blank))
  end)

  it("new returns a favorite with correct fields", function()
    local fav = Favorite.new("1.2.1", true, { text = "foo" })
    assert.equals("1.2.1", fav.gps)
    assert.is_true(fav.locked)
    assert.equals("foo", fav.tag.text)
  end)

  it("new returns blank favorite for nil gps", function()
    local fav = Favorite.new(nil, false, nil)
    assert.is_true(Favorite.is_blank_favorite(fav))
  end)

  it("copy returns a deep copy", function()
    local fav = Favorite.new("1.2.1", false, { text = "foo" })
    local copy = Favorite.copy(fav)
    assert.same(fav, copy)
    if copy and copy.tag then
      copy.tag.text = "bar"
      assert.not_equals(fav.tag.text, copy.tag.text)
    else
      error("copy or copy.tag is nil")
    end
  end)

  it("equals returns true for identical favorites", function()
    local a = Favorite.new("1.2.1", false, { text = "foo" })
    local b = Favorite.new("1.2.1", false, { text = "foo" })
    assert.is_true(Favorite.equals(a, b))
  end)

  it("equals returns false for different favorites", function()
    local a = Favorite.new("1.2.1", false, { text = "foo" })
    local b = Favorite.new("2.2.2", false, { text = "foo" })
    assert.is_false(Favorite.equals(a, b))
  end)

  it("equals returns false for nil or non-table", function()
    local a = Favorite.new("1.2.1", false, { text = "foo" })
    assert.is_false(Favorite.equals(a, nil))
    assert.is_false(Favorite.equals(a, 42))
  end)

  it("alternate constructor (:) and __call metamethod", function()
    local fav1 = Favorite:new("1.2.1", false, { text = "foo" })
    local fav2 = Favorite("1.2.1", false, { text = "foo" })
    assert.equals(fav1.gps, fav2.gps)
    assert.equals(fav1.locked, fav2.locked)
    assert.same(fav1.tag, fav2.tag)
  end)

  it("[gps=x,y,s] parsing: valid and invalid", function()
    local valid = Favorite.new("[gps=10,20,1]", false, { text = "foo" })
    assert.is_true(valid.gps ~= BLANK_GPS)
    local invalid = Favorite.new("[gps=bad,20,1]", false, { text = "foo" })
    assert.equals(BLANK_GPS, invalid.gps)
  end)

  it("get_blank_favorite returns a blank favorite (function coverage)", function()
    local blank = Favorite.get_blank_favorite()
    assert.is_true(Favorite.is_blank_favorite(blank))
  end)

  it("is_blank_favorite handles non-table and empty table", function()
    assert.is_false(Favorite.is_blank_favorite(nil))
    assert.is_false(Favorite.is_blank_favorite(42))
    assert.is_true(Favorite.is_blank_favorite({}))
    assert.is_true(Favorite.is_blank_favorite({ gps = nil, locked = nil }))
  end)

  it("valid method", function()
    local fav = Favorite.new("1.2.1", false, { text = "foo" })
    assert.is_true(fav:valid())
    local blank = Favorite.get_blank_favorite()
    assert.is_false(blank:valid())
  end)

  it("formatted_tooltip covers all branches", function()
    local fav = Favorite.new("1.2.1", false, { text = "foo" })
    assert.is_true(type(fav:formatted_tooltip()) == "string")
    local blank = Favorite.get_blank_favorite()
    assert.equals("Empty favorite slot", blank:formatted_tooltip())
    local no_text = Favorite.new("1.2.1", false, {})
    assert.is_true(type(no_text:formatted_tooltip()) == "string")
  end)

  it("copy handles non-table and nil tag", function()
    assert.is_nil(Favorite.copy(nil))
    local fav = Favorite.new("1.2.1", false, nil)
    local copy = Favorite.copy(fav)
    assert.same(fav, copy)
  end)

  it("equals handles non-table and nil tag", function()
    assert.is_false(Favorite.equals(nil, nil))
    local a = Favorite.new("1.2.1", false, nil)
    local b = Favorite.new("1.2.1", false, nil)
    assert.is_true(Favorite.equals(a, b))
    local c = Favorite.new("1.2.1", false, { text = "foo" })
    assert.is_false(Favorite.equals(a, c))
  end)

  it("static method coverage for luacov", function()
    -- Favorite.new as static
    local f1 = Favorite.new("1.2.1", false, nil)
    assert.is_true(f1.gps == "1.2.1")
    -- Favorite.copy
    local c1 = Favorite.copy(f1)
    assert.is_true(type(c1) == "table")
    -- Favorite.equals
    assert.is_true(Favorite.equals(f1, c1))
    assert.is_false(Favorite.equals(f1, nil))
    -- Favorite.get_blank_favorite
    local blank = Favorite.get_blank_favorite()
    assert.is_true(type(blank) == "table")
    -- Favorite.is_blank_favorite
    assert.is_true(Favorite.is_blank_favorite(blank))
    assert.is_false(Favorite.is_blank_favorite(f1))
    -- Edge: blank favorite with extra fields
    local blank2 = Favorite.get_blank_favorite()
    blank2.extra = 123
    assert.is_true(Favorite.is_blank_favorite(blank2))
  end)

  it("Favorite static methods and constructor edge/error branches for luacov", function()
    -- Alternate constructor path
    local alt = Favorite.new(Favorite, "1.2.1", false, nil)
    assert.is_true(alt.gps == "1.2.1")
    -- [gps=x,y,s] parsing error branch
    local badgps = Favorite.new("[gps=bad,20,1]", false, nil)
    assert.is_true(badgps.gps == BLANK_GPS)
    -- copy error branch
    assert.is_nil(Favorite.copy(nil))
    -- equals error branch
    assert.is_false(Favorite.equals(nil, nil))
    assert.is_false(Favorite.equals({}, nil))
    -- is_blank_favorite error branches
    assert.is_false(Favorite.is_blank_favorite(nil))
    assert.is_true(Favorite.is_blank_favorite({}))
    assert.is_true(Favorite.is_blank_favorite({ gps = nil, locked = nil }))
    assert.is_true(Favorite.is_blank_favorite({ gps = BLANK_GPS, locked = false }))
    assert.is_false(Favorite.is_blank_favorite({ gps = "1.2.1", locked = false }))
    -- valid error branch
    local blank = Favorite.get_blank_favorite()
    assert.is_false(blank:valid())
    -- formatted_tooltip error branch
    assert.equals("Empty favorite slot", blank:formatted_tooltip())
  end)

  it("GPS must always be a string in canonical format", function()
    local gps_helpers = require("core.utils.gps_helpers")
    -- Canonical GPS string with padding
    local valid = Favorite.new("-123.456.1", false, nil)
    assert.equals("-123.456.1", valid.gps)
    -- Legacy vanilla format is normalized to canonical
    local legacy = Favorite.new("[gps=-123,456,1]", false, nil)
    assert.equals("-123.456.1", legacy.gps)
    local blank = Favorite.get_blank_favorite()
    assert.is_true(type(blank.gps) == "string")
    assert.is_true(blank.gps == BLANK_GPS)
    -- Negative numbers may appear without zero-padding after the minus sign; this is canonical and expected for Factorio GPS strings.
    local gps_str = gps_helpers.gps_from_map_position({x = -123, y = 456}, 1)
    assert.equals('-123.456.1', gps_str)
    local fav = Favorite.new(gps_str, false, nil)
    assert.equals('-123.456.1', fav.gps) -- This is the correct canonical output for negative numbers
  end)
end)
