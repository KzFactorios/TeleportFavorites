-- tests/mocks/constants_mock.lua
-- Provides a robust global Constants mock for tests

local constants_mock = {
    settings = {
        MAX_FAVORITE_SLOTS = 10,
        -- Add other settings as needed for tests
    }
}

_G.Constants = constants_mock
return constants_mock

