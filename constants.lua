-- constants.lua
-- Defines mod constants

--- @class Constants
--- @field PREFIX string
--- @field events table
--- @field settings table
--- @field enums any
local constants = {}

constants.PREFIX = "tf_"

constants.events = {
  ADD_TAG_INPUT = "add-tag-input",
  TELEPORT_TO_FAVORITE = "teleport_to_favorite-",
  ON_OPEN_TAG_EDITOR = "on_open_tag_editor",
  CACHE_DUMP = "cache_dump"
}

constants.settings = {
  TELEPORT_RADIUS_DEFAULT = 8,
  TELEPORT_RADIUS_MIN = 1,
  TELEPORT_RADIUS_MAX = 64,
  MAX_FAVORITE_SLOTS = 10,
  GPS_PAD_NUMBER = 3, -- minimum number of digits to display in a gps x or y

  FAVORITES_ON = "favorites_on",
  BOUNDING_BOX_TOLERANCE = 10,
  SNAP_SCALE_FOR_CLICKED_TAG = 4
}

constants.enums = {
  return_state = {
    SUCCESS = "sucess",
    FAILURE = "failure"
  }
}

return constants
