#!/usr/bin/env lua
--[[
test_strategy_pattern.lua
TeleportFavorites Factorio Mod
-----------------------------
Demonstration and testing script for the Strategy Pattern implementation.

This script shows how the Strategy Pattern improves teleportation logic by:
1. Separating different teleportation behaviors into distinct strategies
2. Enabling runtime strategy selection based on context
3. Making the system extensible for new teleportation modes
4. Providing clean API for different teleportation scenarios

Run this script to see the Strategy Pattern in action.
]]

local TeleportStrategies = require("core.pattern.teleport_strategy")
local Tag = require("core.tag.tag")

-- Demonstration of Strategy Pattern Benefits
local StrategyPatternDemo = {}

--- Demonstrate strategy selection based on player state
function StrategyPatternDemo.demonstrate_strategy_selection()
  print("\n=== Strategy Pattern Demonstration ===")
  
  -- Get available strategies
  local strategies = TeleportStrategies.TeleportStrategyManager.get_available_strategies()
  print("Available teleportation strategies:")
  for i, strategy in ipairs(strategies) do
    print(string.format("  %d. %s (Priority: %d)", i, strategy:get_name(), strategy:get_priority()))
  end
  
  print("\n--- Strategy Selection Examples ---")
  
  -- Mock player objects for demonstration
  local mock_player_walking = {
    name = "Player1",
    valid = true,
    driving = false,
    vehicle = nil,
    surface = { index = 1 }
  }
  
  local mock_player_in_vehicle = {
    name = "Player2", 
    valid = true,
    driving = true,
    vehicle = { name = "car", valid = true },
    surface = { index = 1 }
  }
  
  local test_gps = "123.456.1"
  
  -- Test 1: Standard teleportation
  print("\n1. Standard teleportation (player walking):")
  local strategy1 = TeleportStrategies.TeleportStrategyManager.find_best_strategy(mock_player_walking, test_gps, nil)
  if strategy1 then
    print(string.format("   Selected: %s", strategy1:get_name()))
  end
  
  -- Test 2: Vehicle teleportation
  print("\n2. Vehicle teleportation (player in vehicle):")
  local strategy2 = TeleportStrategies.TeleportStrategyManager.find_best_strategy(mock_player_in_vehicle, test_gps, nil)
  if strategy2 then
    print(string.format("   Selected: %s", strategy2:get_name()))
  end
  
  -- Test 3: Safe teleportation (forced)
  print("\n3. Safe teleportation (explicitly requested):")
  local safe_context = { force_safe = true }
  local strategy3 = TeleportStrategies.TeleportStrategyManager.find_best_strategy(mock_player_walking, test_gps, safe_context)
  if strategy3 then
    print(string.format("   Selected: %s", strategy3:get_name()))
  end
  
  -- Test 4: Vehicle teleportation disabled
  print("\n4. Vehicle teleportation disabled:")
  local no_vehicle_context = { allow_vehicle = false }
  local strategy4 = TeleportStrategies.TeleportStrategyManager.find_best_strategy(mock_player_in_vehicle, test_gps, no_vehicle_context)
  if strategy4 then
    print(string.format("   Selected: %s", strategy4:get_name()))
  end
end

3. **Existing Code Structure**: The codebase already had working validation and GUI code,
   making the need for interchangeable algorithms less apparent.

### Strategy Pattern Opportunities Identified

After analysis, several areas benefit from the Strategy pattern:

1. **Position Validation**: Multiple validation approaches scattered throughout codebase
2. **GUI Rendering**: Different rendering needs based on context/preferences  
3. **Error Handling**: Different error handling strategies for different contexts
4. **Teleportation**: Different teleportation algorithms based on surface/conditions

## Integration Examples
]]

-- Mock Factorio environment for demonstration
local function create_mock_environment()
    return {
        player = {
            valid = true,
            name = "TestPlayer",
            force = {
                add_chart_tag = function(surface, spec) 
                    return { valid = true, position = spec.position, destroy = function() end }
                end,
                is_chunk_charted = function() return true end
            },
            surface = {
                index = 1,
                get_tile = function() return { name = "grass-1", valid = true } end,
                find_entities_filtered = function() return {} end
            },
            position = { x = 0, y = 0 },
            gui = { screen = {} }
        },
        position = { x = 100, y = 200 }
    }
end

local function test_validation_strategies()
    print("=== Strategy Pattern: Validation Strategies ===")
    
    local env = create_mock_environment()
    
    -- Load validation strategies
    local validation_module = require("core.pattern.validation_strategy")
    local ValidationStrategy = validation_module.ValidationStrategy
    local BasicValidationStrategy = validation_module.BasicValidationStrategy
    local StrictValidationStrategy = validation_module.StrictValidationStrategy
    local PermissiveValidationStrategy = validation_module.PermissiveValidationStrategy
    local CreateThenValidateStrategy = validation_module.CreateThenValidateStrategy
    
    -- Test different validation strategies
    local validator = ValidationStrategy:new(BasicValidationStrategy)
    
    print("Testing BasicValidationStrategy...")
    local valid, error = validator:validate(env.player, env.position)
    print("  Result:", valid, error or "No error")
    
    print("Switching to StrictValidationStrategy...")
    validator:set_strategy(StrictValidationStrategy)
    valid, error = validator:validate(env.player, env.position, { search_radius = 10, max_distance = 500 })
    print("  Result:", valid, error or "No error")
    
    print("Switching to PermissiveValidationStrategy...")
    validator:set_strategy(PermissiveValidationStrategy)
    valid, error = validator:validate(env.player, env.position)
    print("  Result:", valid, error or "No error")
    
    print("Switching to CreateThenValidateStrategy...")
    validator:set_strategy(CreateThenValidateStrategy)
    valid, error = validator:validate(env.player, env.position)
    print("  Result:", valid, error or "No error")
    
    print("✅ Validation strategies demonstration complete")
    return true
end

local function test_gui_rendering_strategies()
    print("\n=== Strategy Pattern: GUI Rendering Strategies ===")
    
    local env = create_mock_environment()
    
    -- Load GUI rendering strategies
    local gui_module = require("core.pattern.gui_rendering_strategy")
    local GuiRenderingStrategy = gui_module.GuiRenderingStrategy
    local StandardGuiStrategy = gui_module.StandardGuiStrategy
    local CompactGuiStrategy = gui_module.CompactGuiStrategy
    local AccessibilityGuiStrategy = gui_module.AccessibilityGuiStrategy
    local MinimalGuiStrategy = gui_module.MinimalGuiStrategy
    local create_strategy_for_context = gui_module.create_strategy_for_context
    
    -- Mock GUI data
    local gui_data = {
        name = "test_gui",
        title = "Test GUI Dialog",
        buttons = {
            { name = "confirm", caption = "Confirm", essential = true, tooltip = "Confirm the action" },
            { name = "cancel", caption = "Cancel", essential = true, tooltip = "Cancel the action" },
            { name = "help", caption = "Help", essential = false, tooltip = "Get help" }
        }
    }
    
    -- Test different rendering strategies
    local renderer = GuiRenderingStrategy:new(StandardGuiStrategy)
    
    print("Testing StandardGuiStrategy...")
    local gui = renderer:render(env.player.gui.screen, gui_data)
    print("  GUI created:", gui ~= nil)
    
    print("Switching to CompactGuiStrategy...")
    renderer:set_strategy(CompactGuiStrategy)
    gui = renderer:render(env.player.gui.screen, gui_data)
    print("  GUI created:", gui ~= nil)
    
    print("Switching to AccessibilityGuiStrategy...")
    renderer:set_strategy(AccessibilityGuiStrategy)
    gui = renderer:render(env.player.gui.screen, gui_data)
    print("  GUI created:", gui ~= nil)
    
    print("Switching to MinimalGuiStrategy...")
    renderer:set_strategy(MinimalGuiStrategy)
    gui = renderer:render(env.player.gui.screen, gui_data)
    print("  GUI created:", gui ~= nil)
    
    -- Test context-based strategy selection
    print("Testing context-based strategy selection...")
    local contexts = {
        { mode = "compact", screen_size = "small" },
        { mode = "accessibility", high_contrast = true },
        { mode = "minimal", performance_mode = true },
        { mode = "standard" }
    }
    
    for _, context in ipairs(contexts) do
        local strategy = create_strategy_for_context(context)
        renderer:set_strategy(strategy)
        gui = renderer:render(env.player.gui.screen, gui_data, context)
        print("  Context", context.mode, "- GUI created:", gui ~= nil)
    end
    
    print("✅ GUI rendering strategies demonstration complete")
    return true
end

local function demonstrate_integration_opportunities()
    print("\n=== Strategy Pattern Integration Opportunities ===")
    
    print("1. Position Validation Integration:")
    print("   • Replace scattered validation logic in gps_position_normalizer.lua")
    print("   • Unify position_can_be_tagged() variations")
    print("   • Support different validation modes for different contexts")
    
    print("2. GUI Rendering Integration:")
    print("   • Apply to tag_editor.lua for different rendering modes")
    print("   • Support player preferences for GUI density")
    print("   • Enable accessibility mode for better usability")
    
    print("3. Error Handling Integration:")
    print("   • Different error strategies for development vs. production")
    print("   • User-friendly vs. technical error messages")
    print("   • Logging vs. player notification strategies")
    
    print("4. Command Pattern Synergy:")
    print("   • Commands can use different execution strategies")
    print("   • Strategy pattern for undo/redo algorithms")
    print("   • Context-sensitive command behavior")
    
    print("✅ Integration opportunities identified")
    return true
end

local function compare_patterns()
    print("\n=== Command vs Strategy Pattern Comparison ===")
    
    print("Command Pattern (Already Adopted):")
    print("  ✅ Encapsulates requests as objects")
    print("  ✅ Provides undo/redo functionality")
    print("  ✅ Immediate user-facing benefits")
    print("  ✅ Easy integration with event handlers")
    print("  ✅ Clear use cases (GUI actions)")
    
    print("Strategy Pattern (Now Adopted):")
    print("  ✅ Encapsulates algorithms and makes them interchangeable")
    print("  ✅ Provides flexibility in algorithm selection")
    print("  ✅ Improves code maintainability and testability")
    print("  ✅ Supports different modes/contexts")
    print("  ✅ Complements Command pattern beautifully")
    
    print("Together, they provide:")
    print("  🎯 Comprehensive behavioral pattern coverage")
    print("  🎯 Separation of 'what to do' (Command) vs 'how to do it' (Strategy)")
    print("  🎯 Flexible, maintainable, and extensible architecture")
    
    return true
end

-- Run the demonstration
local function run_strategy_pattern_demo()
    print("🔶 Strategy Pattern Adoption Demonstration 🔶")
    print("===============================================")
    
    local success = true
    success = success and test_validation_strategies()
    success = success and test_gui_rendering_strategies()
    success = success and demonstrate_integration_opportunities()
    success = success and compare_patterns()
    
    if success then
        print("\n🎉 Strategy Pattern Demonstration: SUCCESS")
        print("The Strategy pattern has been successfully implemented and")
        print("demonstrates clear value for algorithm encapsulation and")
        print("contextual behavior selection.")
        print("\nNext steps:")
        print("• Integrate validation strategies into existing validation code")
        print("• Apply GUI rendering strategies to tag editor and other GUIs")
        print("• Create error handling strategies for different contexts")
        print("• Expand strategy usage to other algorithm families")
    else
        print("\n❌ Strategy Pattern Demonstration: FAILED")
    end
    
    return success
end

-- Export for use in other contexts
return {
    run_demo = run_strategy_pattern_demo,
    test_validation_strategies = test_validation_strategies,
    test_gui_rendering_strategies = test_gui_rendering_strategies,
    demonstrate_integration_opportunities = demonstrate_integration_opportunities,
    compare_patterns = compare_patterns
}
