-- core/constants_impl.lua
-- Defines mod constants for TeleportFavorites.
-- Loaded via require("core.constants_impl") so Factorio resolves from mod root (see bare require fix).
-- Root constants.lua may delegate here for tooling compatibility.

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
    --DEFAULT_LOG_LEVEL = "debug",

    -- ========================================
    -- Profiling Configuration
    -- ========================================
    -- Set to "profile" to auto-start profiling on init/config-change; any other value disables auto-start.
    PROFILER_CONTROL_MODE = "off",
    -- Auto-stop: number of game ticks after profiler start (not calendar time if paused). 0 = manual /tf_profile_stop only.
    PROFILER_MAX_TICKS = 35 * 60,
    -- Output file under write-data/script-output.
    PROFILER_OUTPUT_FILE = "teleport-favorites-profile.txt",

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
    DEFAULT_SLOT_LABEL_MODE = "off",                      -- Default slot label mode (off/short/long)
    SLOT_LABEL_MODE_SETTING = "slot-label-mode",          -- Setting name for slot label display mode
    -- Deferred fave bar: sync this many blank slot cells on the build() tick; rest via blank_slots queue (UPS).
    -- Lower if LuaProfiler first-tick ms must stay under a budget (e.g. under 5 ms with 30 max slots).
    FAVE_BAR_SYNC_BLANK_BUILD_CAP = 15,
    -- Max blank slots to add per process_slot_build_queue when finishing the tail after the sync cap.
    FAVE_BAR_TAIL_BLANK_BATCH_MAX = 10,
    -- Max single-slot GUI updates per on_nth_tick(2) flush (all players). Spreads dirty-slot work across ticks in MP.
    FAVE_BAR_DIRTY_SLOT_FLUSH_BUDGET = 48,

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
    -- Teleport History
    -- ========================================
    SEQUENTIAL_HISTORY_RESOLUTION = 32, -- Sequential mode: FROM→TO hops within this many tiles are not recorded

    -- ========================================
    -- Feature Toggles
    -- ========================================
    FAVORITES_ON = "favorites_on",                     -- Setting name for enabling/disabling favorites feature
    SHOW_TELEPORT_HISTORY = "enable_teleport_history", -- Setting name for enabling/disabling teleport history
    --- Runtime-global; MP desync bisection only. See core/utils/mp_bisect.lua and settings.lua.
    MP_BISECT_MODE_SETTING = "tf-mp-bisect-mode",

    -- ========================================
    -- Physics & Collision
    -- ========================================
    BOUNDING_BOX_TOLERANCE = 4, -- Tolerance in tiles for bounding box calculations
  },
}

return Constants
