--[[
constants.lua
Defines mod constants for TeleportFavorites.

  -- precision - double The step length from the given position as it searches, in tiles. Minimum value is 0.01.
    --  Lower precision (e.g., 0.5) means the search checks more points and is more likely to find a spot in tight spaces, but it is slower.
    --  Higher precision (e.g., 2 or 5) is faster but may miss valid positions in dense areas
--]]

--- @class Constants
--- @field PREFIX string
--- @field events table
--- @field settings table
--- @field enums any
local constants = {
  PREFIX = "tf_",
  settings = {
    TELEPORT_RADIUS_DEFAULT = 8,
    TELEPORT_RADIUS_MIN = 1,
    TELEPORT_RADIUS_MAX = 32,
    TELEPORT_PRECISION = 2,
    DEFAULT_SNAP_SCALE = 1, -- TODO review this setting
    MAX_FAVORITE_SLOTS = 10,
    FAVE_BAR_SLOT_PREFIX = "fave_bar_slot_",
    GPS_PAD_NUMBER = 3, -- min digits for gps x/y
    BLANK_GPS = "1000000.1000000.1",
    DATA_VIEWER_INDENT = 4,
    FAVORITES_ON = "favorites_on",
    BOUNDING_BOX_TOLERANCE = 8,
    TAG_TEXT_MAX_LENGTH = 256
  },
  enums = {
    return_state = { SUCCESS = "success", FAILURE = "failure" },
    events = {
      ADD_TAG_INPUT = "add-tag-input",
      TELEPORT_TO_FAVORITE = "teleport_to_favorite-",
      ON_OPEN_TAG_EDITOR = "on_open_tag_editor",
      CACHE_DUMP = "cache_dump"
    }
  }
}

return constants
