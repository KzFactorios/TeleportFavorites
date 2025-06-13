---@diagnostic disable
--[[
validation_strategy.lua
TeleportFavorites Factorio Mod
-----------------------------
Concrete Strategy pattern implementation for position validation.

This demonstrates the Strategy pattern by providing different validation approaches
that can be swapped based on context. The codebase currently uses multiple validation
strategies scattered throughout the code - this pattern unifies them.

PATTERN BENEFITS:
- Encapsulates validation algorithms in separate strategy classes
- Easy to add new validation strategies without modifying existing code
- Allows runtime selection of validation strategy based on context
- Improves testability and maintainability of validation logic

USAGE SCENARIOS:
- Different validation rules for different surface types
- Strict vs. lenient validation modes
- Development vs. production validation strategies
- Mod compatibility validation strategies
]]

local Strategy = require("core.pattern.strategy")
local ErrorHandler = require("core.utils.error_handler")

---@class ValidationStrategy: Strategy
-- Context class that uses different validation strategies
local ValidationStrategy = {}
ValidationStrategy.__index = ValidationStrategy

--- Create a new validation strategy context
---@param strategy Strategy The validation strategy to use
---@return ValidationStrategy
function ValidationStrategy:new(strategy)
    local obj = setmetatable({}, self)
    obj.strategy = strategy
    return obj
end

--- Set a new validation strategy
---@param strategy Strategy
function ValidationStrategy:set_strategy(strategy)
    self.strategy = strategy
end

--- Execute validation using the current strategy
---@param player LuaPlayer
---@param position MapPosition
---@param context table? Optional validation context
---@return boolean is_valid
---@return string? error_message
function ValidationStrategy:validate(player, position, context)
    if not self.strategy then
        ErrorHandler.debug_log("No validation strategy set")
        return false, "No validation strategy configured"
    end
    
    return self.strategy:execute(player, position, context)
end

-- =====================================
-- CONCRETE VALIDATION STRATEGIES
-- =====================================

---@class BasicValidationStrategy: Strategy
-- Basic validation: chunk charted, not water/space
local BasicValidationStrategy = setmetatable({}, { __index = Strategy })

---@param player LuaPlayer
---@param position MapPosition 
---@param context table?
---@return boolean is_valid
---@return string? error_message
function BasicValidationStrategy:execute(player, position, context)
    ErrorHandler.debug_log("BasicValidationStrategy: Validating position", {
        position = position,
        player_name = player and player.name
    })
    
    -- Player and surface validation
    if not (player and player.valid and player.force and player.surface) then
        return false, "Invalid player or surface"
    end
    
    if not position then
        return false, "Invalid position"
    end
    
    -- Chunk charted validation
    local chunk = { x = math.floor(position.x / 32), y = math.floor(position.y / 32) }
    if not player.force.is_chunk_charted(player.surface, chunk) then
        return false, "Position is not in charted territory"
    end
    
    -- Water/space tile validation (simplified - actual implementation would use helpers)
    local tile = player.surface.get_tile(position.x, position.y)
    if tile and tile.valid then
        if tile.name:find("water") or tile.name:find("space") then
            return false, "Cannot place on water or space tiles"
        end
    end
    
    ErrorHandler.debug_log("BasicValidationStrategy: Validation successful")
    return true, nil
end

---@class StrictValidationStrategy: Strategy  
-- Strict validation: includes entity collision detection and additional checks
local StrictValidationStrategy = setmetatable({}, { __index = Strategy })

---@param player LuaPlayer
---@param position MapPosition
---@param context table?
---@return boolean is_valid
---@return string? error_message
function StrictValidationStrategy:execute(player, position, context)
    ErrorHandler.debug_log("StrictValidationStrategy: Validating position", {
        position = position,
        player_name = player and player.name
    })
    
    -- First run basic validation
    local basic_strategy = BasicValidationStrategy
    local basic_valid, basic_error = basic_strategy:execute(player, position, context)
    if not basic_valid then
        return false, basic_error
    end
    
    -- Additional strict validation checks
    local search_radius = (context and context.search_radius) or 5
    
    -- Check for entity collisions in the area
    local entities = player.surface.find_entities_filtered{
        position = position,
        radius = search_radius
    }
    
    -- Check for important entities that might block placement
    for _, entity in pairs(entities) do
        if entity.valid and entity.type then
            -- Block placement near important entities
            if entity.type == "electric-pole" or 
               entity.type == "inserter" or 
               entity.type == "assembling-machine" then
                return false, "Position too close to important entities"
            end
        end
    end
    
    -- Check distance from player (prevent teleporting too far without proper validation)
    local max_distance = (context and context.max_distance) or 1000
    local distance = math.sqrt((position.x - player.position.x)^2 + (position.y - player.position.y)^2)
    if distance > max_distance then
        return false, "Position too far from player location"
    end
    
    ErrorHandler.debug_log("StrictValidationStrategy: Strict validation successful")
    return true, nil
end

---@class PermissiveValidationStrategy: Strategy
-- Permissive validation: minimal checks for development/testing
local PermissiveValidationStrategy = setmetatable({}, { __index = Strategy })

---@param player LuaPlayer
---@param position MapPosition
---@param context table?
---@return boolean is_valid
---@return string? error_message  
function PermissiveValidationStrategy:execute(player, position, context)
    ErrorHandler.debug_log("PermissiveValidationStrategy: Permissive validation", {
        position = position,
        player_name = player and player.name
    })
    
    -- Minimal validation - just check player and position exist
    if not (player and player.valid) then
        return false, "Invalid player"
    end
    
    if not position then
        return false, "Invalid position" 
    end
    
    -- Allow almost everything in permissive mode
    ErrorHandler.debug_log("PermissiveValidationStrategy: Permissive validation passed")
    return true, nil
end

---@class CreateThenValidateStrategy: Strategy
-- Create-then-validate strategy: matches current codebase pattern
local CreateThenValidateStrategy = setmetatable({}, { __index = Strategy })

---@param player LuaPlayer
---@param position MapPosition
---@param context table?
---@return boolean is_valid
---@return string? error_message
function CreateThenValidateStrategy:execute(player, position, context)
    ErrorHandler.debug_log("CreateThenValidateStrategy: Using create-then-validate pattern", {
        position = position,
        player_name = player and player.name
    })
    
    -- First run basic validation to catch obvious issues
    local basic_strategy = BasicValidationStrategy
    local basic_valid, basic_error = basic_strategy:execute(player, position, context)
    if not basic_valid then
        return false, basic_error
    end
      -- Create temporary chart tag to test Factorio's internal validation
    local chart_tag_spec = {
        position = position,
        text = "temp_validation_tag",
        last_user = player.name    }    local temp_chart_tag = nil
    local GPSChartHelpers = require("core.utils.gps_chart_helpers")
    local success = pcall(function()
        temp_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, player.surface, chart_tag_spec)
    end)
    
    if not success or not temp_chart_tag then
        ErrorHandler.debug_log("CreateThenValidateStrategy: Chart tag creation failed")
        return false, "Position rejected by Factorio API"
    end
    
    -- Validation successful - clean up temp chart tag
    if temp_chart_tag and temp_chart_tag.valid then
        temp_chart_tag.destroy()
    end
    
    ErrorHandler.debug_log("CreateThenValidateStrategy: Create-then-validate successful")
    return true, nil
end

-- Export strategy classes for external use
return {
    ValidationStrategy = ValidationStrategy,
    BasicValidationStrategy = BasicValidationStrategy,
    StrictValidationStrategy = StrictValidationStrategy,
    PermissiveValidationStrategy = PermissiveValidationStrategy,
    CreateThenValidateStrategy = CreateThenValidateStrategy
}
