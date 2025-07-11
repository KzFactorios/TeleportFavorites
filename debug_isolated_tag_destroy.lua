-- Minimal test for tag_destroy_helper in isolation
print("=== ISOLATED TAG_DESTROY_HELPER TEST ===")

-- Setup minimal Lua environment
package.path = "./?.lua;" .. package.path

-- CRITICAL: Set test exposure flag BEFORE any requires
_G._TEST_EXPOSE_TAG_DESTROY_HELPERS = true
print("1. Test exposure flag set:", _G._TEST_EXPOSE_TAG_DESTROY_HELPERS)

-- Setup minimal globals
_G.global = {}
_G.storage = { players = {}, surfaces = {}, cache = {} }
_G.game = { players = {} }

-- Setup mocks  
_G.FavoriteUtils = require("tests.mocks.favorite_utils_mock")
package.loaded["core.favorite.favorite_utils"] = _G.FavoriteUtils

-- Require the modules
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")

print("2. About to require tag_destroy_helper...")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
print("3. tag_destroy_helper type:", type(tag_destroy_helper))

print("4. tag_destroy_helper keys:")
for k, v in pairs(tag_destroy_helper) do
    print("   " .. k .. " = " .. type(v))
end

local helpers = tag_destroy_helper._test_expose
print("5. helpers type:", type(helpers))

if helpers then
    print("6. Test exposure SUCCESS - helpers available")
    
    -- Test a simple function
    local result = helpers.has_any_favorites(nil)
    print("7. has_any_favorites(nil):", result)
    
    local result2 = helpers.has_any_favorites({faved_by_players = {1}})
    print("8. has_any_favorites({faved_by_players = {1}}):", result2)
    
    print("SUCCESS: Test exposure is working in isolation")
else
    print("6. Test exposure FAILED - helpers is nil")
end

print("=== END ISOLATED TEST ===")
