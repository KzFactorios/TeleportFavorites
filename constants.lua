--[[
constants.lua
Defines mod constants for TeleportFavorites.
This is the central configuration point for the mod with values used throughout the codebase.
]]--

--- @class Constants
--- @field PREFIX string Prefix used for mod-specific element names
--- @field settings table<string, number|string|boolean> Configuration settings
local Constants = {
  PREFIX = "tf_",
    settings = {
    -- Chart tag settings
    CHART_TAG_CLICK_RADIUS = 10,    -- Radius in tiles for detecting chart tag clicks on the map
    CHART_TAG_TEXT_MAX_LENGTH = 1024, -- Maximum length for chart tag text (1024 chars)
    
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

    -- Text limits
    -- Maximum character length for tag text
    TAG_TEXT_MAX_LENGTH = 256
  }
}

return Constants
