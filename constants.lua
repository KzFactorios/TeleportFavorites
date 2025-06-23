--[[
constants.lua
Defines mod constants for TeleportFavorites.
This is the central configuration point for the mod with values used throughout the codebase.
]]--

local Enum = require("prototypes.enums.enum")

--- @class Constants
--- @field PREFIX string Prefix used for mod-specific element names
--- @field settings table<string, number|string|boolean> Configuration settings
local Constants = {
  PREFIX = "tf_",
    settings = {
    -- Chart tag settings
    CHART_TAG_CLICK_RADIUS = 10,    -- Radius in tiles for detecting chart tag clicks on the map
    
    -- UI settings
    DEFAULT_SNAP_SCALE = 1,          -- Scale factor for position snapping
    MAX_FAVORITE_SLOTS = 10,         -- Maximum number of favorite slots per player
    FAVE_BAR_SLOT_PREFIX = "fave_bar_slot_", -- Prefix for favorite bar slot element names
    
    -- GPS settings
    GPS_PAD_NUMBER = 3,              -- Min digits for GPS coordinate display
    BLANK_GPS = "1000000.1000000.1", -- Default empty GPS string for initialization
    
    -- Data display settings
    DATA_VIEWER_INDENT = 4,          -- Number of spaces for indentation in data viewer
    
    -- Feature toggles
    FAVORITES_ON = "favorites_on",   -- Setting name for enabling/disabling favorites feature
      -- Physics
    BOUNDING_BOX_TOLERANCE = 4,      -- Tolerance in tiles for bounding box calculations    
    
    -- Terrain Protection
    TERRAIN_PROTECTION_DEFAULT = 3,  -- Default protection radius (for 3x3 area)
    TERRAIN_PROTECTION_MIN = 0,      -- Minimum protection radius (0 = owner-only protection)
    TERRAIN_PROTECTION_MAX = 9,      -- Maximum protection radius (for 19x19 area)
      -- Text limits
    -- Maximum character length for tag text
    TAG_TEXT_MAX_LENGTH = 256
  }
}

return Constants
