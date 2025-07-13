require("test_bootstrap")
require("mocks.factorio_test_env")

describe("Cache module", function()
    it("should load cache module without errors", function()
        local success, err = pcall(function()
            -- Cache module requires complex Factorio API integration
            -- This test just ensures the module can be loaded
            local Cache = require("core.cache.cache")
            assert(Cache ~= nil, "Cache module should load")
            assert(type(Cache) == "table", "Cache should be a table")
        end)
        assert(success, "Cache module should load without errors: " .. tostring(err))
    end)
    
    it("should expose expected cache API methods", function()
        local success, err = pcall(function()
            local Cache = require("core.cache.cache")
            
            -- Check that key API methods exist
            assert(type(Cache.init) == "function", "Cache.init should be a function")
            assert(type(Cache.get_player_data) == "function", "Cache.get_player_data should be a function")
            assert(type(Cache.get_surface_data) == "function", "Cache.get_surface_data should be a function")
            assert(type(Cache.get_player_favorites) == "function", "Cache.get_player_favorites should be a function")
            -- Note: get_surface_tags may require additional dependencies
        end)
        assert(success, "Cache API methods should exist: " .. tostring(err))
    end)
end)
