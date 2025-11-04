-- constants.lua
-- Defines mod constants for TeleportFavorites.
-- This is the central configuration point for the mod with values used throughout the codebase.

---@class Constants
---@field PREFIX string
---@field settings table<string, number|string|boolean>
local Constants = {
  PREFIX = "tf_",
  
  settings = {
    -- ========================================
    -- Logging Configuration
    -- ========================================
    -- One place to set runtime log level: "production" | "warn" | "error" | "debug"
    DEFAULT_LOG_LEVEL = "production",
    
    -- ========================================
    -- Chart Tag Settings
    -- ========================================
    CHART_TAG_CLICK_RADIUS = 10,      -- Radius in tiles for detecting chart tag clicks on the map
    CHART_TAG_TEXT_MAX_LENGTH = 1024, -- Maximum length for chart tag text (1024 chars)
    TAG_TEXT_MAX_LENGTH = 256,        -- Maximum character length for tag text in editor
    
    -- ========================================
    -- UI Settings
    -- ========================================
    DEFAULT_SNAP_SCALE = 1,                              -- Scale factor for position snapping
    DEFAULT_MAX_FAVORITE_SLOTS = 10,                     -- Default max number of favorite slots per player
    MAX_FAVORITE_SLOTS_SETTING = "max-favorite-slots",   -- Setting name for per-player max slots
    FAVE_BAR_SLOT_PREFIX = "fave_bar_slot_",             -- Prefix for favorite bar slot element names
    TELEPORT_HISTORY_LABEL_MAX_DISPLAY = 27,             -- Teleport history label max display length
    
    -- ========================================
    -- Update Intervals (in ticks)
    -- ========================================
    DEFAULT_HISTORY_UPDATE_INTERVAL = 30, -- Default tick interval for teleport history (0.5 seconds)
    MIN_UPDATE_INTERVAL = 5,              -- Minimum allowed update interval (0.083 seconds)
    MAX_UPDATE_INTERVAL = 59,             -- Maximum allowed update interval (0.983 seconds)
    
    -- ========================================
    -- GPS Settings
    -- ========================================
    GPS_PAD_NUMBER = 3,              -- Min digits for GPS coordinate display
    BLANK_GPS = "1000000.1000000.1", -- Default empty GPS string for initialization
    
    -- ========================================
    -- Feature Toggles
    -- ========================================
    FAVORITES_ON = "favorites_on",                     -- Setting name for enabling/disabling favorites feature
    SHOW_TELEPORT_HISTORY = "enable_teleport_history", -- Setting name for enabling/disabling teleport history
    
    -- ========================================
    -- Physics & Collision
    -- ========================================
    BOUNDING_BOX_TOLERANCE = 4, -- Tolerance in tiles for bounding box calculations
  },
}

return Constants
