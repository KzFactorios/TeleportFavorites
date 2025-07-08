-- tests/control/control_shared_utils_spec.lua

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local SharedUtils = require("core.control.control_shared_utils")

describe("SharedUtils", function()
    it("should be a table/module", function()
        assert.is_table(SharedUtils)
    end)
    -- Add more tests for exported functions as needed
end)
