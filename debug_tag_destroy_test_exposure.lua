-- Debug script for tag_destroy_helper test exposure
print("=== Debug: Tag Destroy Helper Test Exposure ===")

-- CRITICAL: Set test exposure flag BEFORE any requires
_G._TEST_EXPOSE_TAG_DESTROY_HELPERS = true
print("1. Set _G._TEST_EXPOSE_TAG_DESTROY_HELPERS =", _G._TEST_EXPOSE_TAG_DESTROY_HELPERS)

-- Setup minimal test environment
_G.global = _G.global or {}
_G.storage = _G.storage or { players = {}, surfaces = {}, cache = {} }
_G.game = _G.game or { players = {} }
_G.surfaces = _G.surfaces or {}

-- Setup required mocks
package.path = "./?.lua;" .. package.path
_G.FavoriteUtils = require("tests.mocks.favorite_utils_mock")
print("2. FavoriteUtils loaded:", type(_G.FavoriteUtils))

package.loaded["core.favorite.favorite_utils"] = _G.FavoriteUtils

local ErrorHandler = require("core.utils.error_handler")
print("3. ErrorHandler loaded:", type(ErrorHandler))

local Cache = require("core.cache.cache")
print("4. Cache loaded:", type(Cache))

-- Require the module with test exposure
print("5. About to require core.tag.tag_destroy_helper...")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
print("6. tag_destroy_helper loaded:", type(tag_destroy_helper))

print("7. tag_destroy_helper keys:")
for k, v in pairs(tag_destroy_helper) do
    print("   " .. tostring(k) .. " = " .. type(v))
end

local helpers = tag_destroy_helper._test_expose
print("8. helpers (_test_expose):", type(helpers))

if helpers then
    print("9. helpers keys:")
    for k, v in pairs(helpers) do
        print("   " .. tostring(k) .. " = " .. type(v))
    end
else
    print("9. helpers is nil - test exposure failed")
end

print("=== End Debug ===")
