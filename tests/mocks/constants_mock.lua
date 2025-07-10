-- tests/mocks/constants_mock.lua
-- Provides a robust global Constants mock for tests


local constants_mock = {
    settings = {
        MAX_FAVORITE_SLOTS = 10,
        -- Add other settings as needed for tests
    },
    COMMANDS = {
        DELETE_FAVORITE_BY_SLOT = "tf-delete-favorite-slot"
    }
}

_G.Constants = constants_mock
return constants_mock

