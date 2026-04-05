require("test_bootstrap")
require("mocks.factorio_test_env")

-- Tests run with a mock cache installed by the test framework; unset it to load the real module.
package.loaded["core.cache.cache"] = nil
local Cache = require("core.cache.cache")

describe("Cache.sanitize_for_storage", function()
    it("removes functions and userdata and handles cycles", function()
        local t = {
            a = 1,
            b = function() return 2 end,
            c = { d = function() end, e = "str" }
        }
        t.self = t

        local s = Cache.sanitize_for_storage(t)
        assert(type(s) == "table", "sanitized result should be a table")
        assert(s.a == 1, "numeric values should be preserved")
        assert(s.b == nil, "functions should be removed from top-level")
        assert(type(s.c) == "table", "nested tables should be preserved")
        assert(s.c.e == "str", "nested scalar should be preserved")

        local function has_bad(val, seen)
            if type(val) == "function" or type(val) == "userdata" then return true end
            if type(val) ~= "table" then return false end
            seen = seen or {}
            if seen[val] then return false end
            seen[val] = true
            for k, v in pairs(val) do
                if has_bad(k, seen) or has_bad(v, seen) then return true end
            end
            return false
        end

        assert(not has_bad(s), "sanitized table must not contain functions or userdata")
    end)
end)
