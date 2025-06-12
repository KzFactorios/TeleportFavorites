-- Test script for CustomInputDispatcher
print("Testing CustomInputDispatcher...")

-- Mock dependencies
local mock_script = {
  registered_events = {}
}

function mock_script:on_event(event_name, handler)
  self.registered_events[event_name] = handler
  return true
end

-- Mock Factorio globals for testing
_G.log = print
_G.game = {
  get_player = function(index) 
    return { 
      valid = true, 
      print = function(msg) 
        print("Player " .. index .. ": " .. (type(msg) == "table" and msg[1] or msg))
      end 
    } 
  end
}

-- Load the module
local success, CustomInputDispatcher = pcall(function()
  return dofile("core/events/custom_input_dispatcher.lua")
end)

if not success then
  print("✗ Failed to load CustomInputDispatcher:", CustomInputDispatcher)
  return
end

print("✓ CustomInputDispatcher loaded successfully")

-- Test 1: Register default handlers
local default_success = CustomInputDispatcher.register_default_inputs(mock_script)
print("✓ Default registration:", default_success and "SUCCESS" or "FAILED")

-- Test 2: Register custom handlers
local custom_handlers = {
  ["test-input"] = function(event) 
    print("Test input triggered by player", event.player_index) 
  end,
  ["another-test"] = function(event) 
    print("Another test input") 
  end
}

local custom_success = CustomInputDispatcher.register_custom_inputs(mock_script, custom_handlers)
print("✓ Custom registration:", custom_success and "SUCCESS" or "FAILED")

-- Test 3: Error handling
local error_handlers = {
  ["error-input"] = function(event) 
    error("Intentional test error") 
  end
}

local error_success = CustomInputDispatcher.register_custom_inputs(mock_script, error_handlers)
print("✓ Error handler registration:", error_success and "SUCCESS" or "FAILED")

-- Test 4: Test safe handler execution
print("\n--- Testing handler execution ---")
if mock_script.registered_events["test-input"] then
  mock_script.registered_events["test-input"]({player_index = 1})
end

if mock_script.registered_events["error-input"] then
  mock_script.registered_events["error-input"]({player_index = 2})
end

print("\n--- Testing validation ---")

-- Test 5: Invalid script object
local invalid_success = pcall(function()
  CustomInputDispatcher.register_custom_inputs(nil, custom_handlers)
end)
print("✓ Invalid script validation:", not invalid_success and "SUCCESS" or "FAILED")

-- Test 6: Invalid handlers
local invalid_handlers_success = pcall(function()
  CustomInputDispatcher.register_custom_inputs(mock_script, "not a table")
end)
print("✓ Invalid handlers validation:", not invalid_handlers_success and "SUCCESS" or "FAILED")

print("\n✓ All tests completed!")
-- Count registered events
local count = 0
for _ in pairs(mock_script.registered_events or {}) do count = count + 1 end
print("Total registered events:", count)
