-- tests/mock/mock_storage.lua
-- Mock for the Factorio global storage table

local storage = {}

-- Add any default/mock data here as needed for tests
storage._tf_debug_mode = false
storage.players = {}

return storage
