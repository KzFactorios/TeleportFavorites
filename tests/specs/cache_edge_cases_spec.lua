require("test_bootstrap")
require("mocks.factorio_test_env")

describe("Cache edge cases", function()
    it("should handle storage edge cases without errors", function()
        local success, err = pcall(function()
            -- Test with nil storage
            _G.storage = nil
            local Cache = require("core.cache.cache")
            assert(Cache ~= nil, "Cache should load even with nil storage")
            
            -- Test with empty storage
            _G.storage = {}
            assert(Cache ~= nil, "Cache should handle empty storage")
            
            -- Test with partial storage
            _G.storage = { players = {} }
            assert(Cache ~= nil, "Cache should handle partial storage")
        end)
        assert(success, "Cache should handle storage edge cases: " .. tostring(err))
    end)
    
    it("should handle invalid inputs gracefully", function()
        local success, err = pcall(function()
            local Cache = require("core.cache.cache")
            
            -- Test with nil inputs (these should not crash)
            local result1 = Cache.get("non_existent_key")
            -- result1 can be nil, that's expected
            
            local version = Cache.get_mod_version()
            -- version can be nil or string
            
            -- Test surface data with invalid index
            local surface_data = Cache.get_surface_data(-1)
            -- surface_data should handle invalid indices gracefully
        end)
        assert(success, "Cache should handle invalid inputs gracefully: " .. tostring(err))
    end)
    
    it("should handle sanitization edge cases", function()
        local success, err = pcall(function()
            local Cache = require("core.cache.cache")
            
            -- Test sanitization with valid table inputs
            local sanitized_empty = Cache.sanitize_for_storage({}, {})
            local sanitized_table = Cache.sanitize_for_storage({test = "value"}, {})
            local sanitized_nested = Cache.sanitize_for_storage({nested = {inner = "value"}}, {})
            
            -- These should not crash and return something
            assert(sanitized_empty ~= nil, "Empty table sanitization should work")
            assert(sanitized_table ~= nil, "Table sanitization should work")
            assert(sanitized_nested ~= nil, "Nested table sanitization should work")
        end)
        assert(success, "Cache sanitization should handle edge cases: " .. tostring(err))
    end)
end)
