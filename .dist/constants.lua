---@class Constants
---@field PREFIX string
---@field settings table<string, number|string|boolean>
local Constants = {
  PREFIX = "tf_",
    settings = {
    CHART_TAG_CLICK_RADIUS = 10,
    CHART_TAG_TEXT_MAX_LENGTH = 1024,

    DEFAULT_SNAP_SCALE = 1,
    MAX_FAVORITE_SLOTS = 10,
    FAVE_BAR_SLOT_PREFIX = "fave_bar_slot_",

    DEFAULT_HISTORY_UPDATE_INTERVAL = 30,
    MIN_UPDATE_INTERVAL = 5,
    MAX_UPDATE_INTERVAL = 59,

    GPS_PAD_NUMBER = 3,
    BLANK_GPS = "1000000.1000000.1",

    FAVORITES_ON = "favorites_on",
    SHOW_TELEPORT_HISTORY = "enable_teleport_history",
    BOUNDING_BOX_TOLERANCE = 4,

  TAG_TEXT_MAX_LENGTH = 256,

  TELEPORT_HISTORY_LABEL_MAX_DISPLAY = 27
  },

  COMMANDS = {
    DELETE_FAVORITE_BY_SLOT = "tf-delete-favorite-slot"
  }
}

return Constants
