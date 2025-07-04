local Constants = require("constants")

describe("Constants.settings", function()
  it("should have correct default values", function()
    assert.equals(Constants.settings.CHART_TAG_CLICK_RADIUS, 10)
    assert.equals(Constants.settings.MAX_FAVORITE_SLOTS, 10)
    assert.equals(Constants.settings.DEFAULT_COORDS_UPDATE_INTERVAL, 15)
    assert.equals(Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL, 30)
    assert.equals(Constants.settings.MIN_UPDATE_INTERVAL, 5)
    assert.equals(Constants.settings.MAX_UPDATE_INTERVAL, 59)
    assert.equals(Constants.settings.BLANK_GPS, "1000000.1000000.1")
    assert.equals(Constants.settings.DATA_VIEWER_INDENT, 4)
    assert.equals(Constants.settings.FAVORITES_ON, "favorites_on")
    assert.equals(Constants.settings.BOUNDING_BOX_TOLERANCE, 4)
    assert.equals(Constants.settings.TAG_TEXT_MAX_LENGTH, 256)
  end)

  it("should have correct command definitions", function()
    assert.equals(Constants.COMMANDS.DELETE_FAVORITE_BY_SLOT, "tf-delete-favorite-slot")
  end)
end)
