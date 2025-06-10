-- Test file to verify circular dependencies are resolved
-- This file just requires the main modules to check for circular dependency errors

print("Testing module loading...")

local gps_helpers = require("core.utils.gps_helpers")
print("✓ gps_helpers loaded")

local position_helpers = require("core.utils.position_helpers")
print("✓ position_helpers loaded")

local cache = require("core.cache.cache")
print("✓ cache loaded")

local lookups = require("core.cache.lookups")
print("✓ lookups loaded")

local favorite = require("core.favorite.favorite")
print("✓ favorite loaded")

local gps = require("core.gps.gps")
print("✓ gps loaded")

print("All modules loaded successfully! Circular dependency issue resolved.")
