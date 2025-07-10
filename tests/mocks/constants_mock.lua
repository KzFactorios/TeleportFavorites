-- tests/mocks/constants_mock.lua
-- Provides a robust global Constants mock for tests


local constants_mock = {
    settings = {
        CHART_TAG_CLICK_RADIUS = 10,
        MAX_FAVORITE_SLOTS = 10,
        DEFAULT_COORDS_UPDATE_INTERVAL = 15,
        DEFAULT_HISTORY_UPDATE_INTERVAL = 30,
        MIN_UPDATE_INTERVAL = 5,
        MAX_UPDATE_INTERVAL = 59,
        BLANK_GPS = "1000000.1000000.1",
        FAVORITES_ON = "favorites_on",
        BOUNDING_BOX_TOLERANCE = 4,
        TAG_TEXT_MAX_LENGTH = 256,
        CHART_TAG_TEXT_MAX_LENGTH = 1024,
        -- Add other settings as needed for tests
    },
    COMMANDS = {
        DELETE_FAVORITE_BY_SLOT = "tf-delete-favorite-slot"
    }
}

_G.Constants = constants_mock
return constants_mock

