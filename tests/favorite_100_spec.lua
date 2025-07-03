-- Complete test for Favorite utility functions to achieve 100% coverage

-- Mock _G.constants if needed
if not _G.constants then _G.constants = {} end
if not _G.constants.settings then _G.constants.settings = {} end
if not _G.constants.settings.BLANK_GPS then _G.constants.settings.BLANK_GPS = "-1.-1.-1" end

local Constants = require("constants")
local CollectionUtils = require("core.utils.collection_utils")
local FavoriteUtils = require("core.favorite.favorite")

describe("FavoriteUtils 100% coverage", function()
  
  it("should handle check_state with invalid check type", function()
    -- Test the final return false branch of check_state
    local result = FavoriteUtils.check_state({gps = "1.2.3"}, "invalid_check_type")
    assert.is_false(result)
  end)
  
  it("should handle check_state for empty table", function()
    -- Test the condition where next(fav) == nil
    local result = FavoriteUtils.check_state({}, "blank")
    assert.is_true(result)
  end)
  
  it("should properly check all state types", function()
    local fav = FavoriteUtils.new("1.2.3", false, { text = "Test" })
    local blank_fav = FavoriteUtils.get_blank_favorite()
    local locked_fav = FavoriteUtils.new("1.2.3", true)
    
    -- Test blank state checks
    assert.is_false(FavoriteUtils.check_state(fav, "blank"))
    assert.is_true(FavoriteUtils.check_state(blank_fav, "blank"))
    assert.is_false(FavoriteUtils.check_state(nil, "blank"))
    assert.is_false(FavoriteUtils.check_state(123, "blank"))
    
    -- Test valid state checks
    assert.is_true(FavoriteUtils.check_state(fav, "valid"))
    assert.is_false(FavoriteUtils.check_state(blank_fav, "valid"))
    assert.is_false(FavoriteUtils.check_state({}, "valid"))
    
    -- Test locked state checks
    assert.is_false(FavoriteUtils.check_state(fav, "locked"))
    assert.is_true(FavoriteUtils.check_state(locked_fav, "locked"))
    
    -- Test empty state checks
    assert.is_false(FavoriteUtils.check_state(fav, "empty"))
    assert.is_true(FavoriteUtils.check_state({}, "empty"))
    assert.is_true(FavoriteUtils.check_state(nil, "empty"))
  end)
  
  it("should handle copy with non-table input", function()
    assert.is_nil(FavoriteUtils.copy(nil))
    assert.is_nil(FavoriteUtils.copy("not a table"))
    assert.is_nil(FavoriteUtils.copy(123))
  end)
  
  it("should copy favorites with additional fields", function()
    local fav = FavoriteUtils.new("1.2.3", false, { text = "Test" })
    fav.custom_field = "custom value" -- Add a custom field
    
    local copy = FavoriteUtils.copy(fav)
    assert.is_not_nil(copy)
    assert.equals(fav.gps, copy.gps)
    assert.equals(fav.locked, copy.locked)
    assert.equals(fav.tag.text, copy.tag.text)
    assert.equals(fav.custom_field, copy.custom_field)
  end)
  
  it("should handle equals with non-table inputs", function()
    local fav = FavoriteUtils.new("1.2.3")
    assert.is_false(FavoriteUtils.equals(fav, nil))
    assert.is_false(FavoriteUtils.equals(nil, fav))
    assert.is_false(FavoriteUtils.equals(fav, "not a table"))
    assert.is_false(FavoriteUtils.equals("not a table", fav))
  end)
  
  it("should correctly compare favorites with tags", function()
    local fav1 = FavoriteUtils.new("1.2.3", false, { text = "Test" })
    local fav2 = FavoriteUtils.new("1.2.3", false, { text = "Test" })
    local fav3 = FavoriteUtils.new("1.2.3", false, { text = "Different" })
    local fav4 = FavoriteUtils.new("1.2.3", false)
    
    assert.is_true(FavoriteUtils.equals(fav1, fav2))
    assert.is_false(FavoriteUtils.equals(fav1, fav3))
    assert.is_false(FavoriteUtils.equals(fav1, fav4))
  end)
  
  it("should update all properties correctly", function()
    local fav = FavoriteUtils.new("1.2.3", false)
    
    -- Update GPS
    FavoriteUtils.update_property(fav, "gps", "4.5.6")
    assert.equals("4.5.6", fav.gps)
    
    -- Update tag
    local tag = { text = "Test Tag" }
    FavoriteUtils.update_property(fav, "tag", tag)
    assert.equals(tag, fav.tag)
    
    -- Update locked with explicit value
    FavoriteUtils.update_property(fav, "locked", true)
    assert.is_true(fav.locked)
    
    -- Toggle locked (no value)
    FavoriteUtils.update_property(fav, "locked")
    assert.is_false(fav.locked)
    
    -- Test with invalid property (should do nothing)
    local before = CollectionUtils.deep_copy(fav)
    FavoriteUtils.update_property(fav, "invalid_property", "some value")
    assert.same(before, fav)
  end)
  
end)
