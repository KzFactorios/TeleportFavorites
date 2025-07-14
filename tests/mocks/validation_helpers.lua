-- tests/mocks/validation_helpers.lua
-- Centralized validation patterns for test code reduction

local ValidationHelpers = {}

--- Standard success assertion pattern for handler functions
---@param handler_fn function Handler function to test
---@param event table Event data to pass to handler
---@param error_message string Custom error message prefix
function ValidationHelpers.assert_handler_success(handler_fn, event, error_message)
  local success, err = pcall(function()
    handler_fn(event)
  end)
  assert(success, error_message .. ": " .. tostring(err))
end

--- Validate that a handler can be called without errors
---@param module_path string Module path to require
---@param handler_name string Handler function name
---@param event table Event data
---@param error_message string? Custom error message
function ValidationHelpers.validate_handler_execution(module_path, handler_name, event, error_message)
  local default_message = handler_name .. " should execute without errors"
  ValidationHelpers.assert_handler_success(function(e)
    local Handler = require(module_path)
    Handler[handler_name](e)
  end, event, error_message or default_message)
end

--- Validate chart tag handler execution
---@param handler_name string Handler function name (e.g., "on_chart_tag_added")
---@param event table Event data
---@param error_message string? Custom error message
function ValidationHelpers.validate_chart_tag_handler(handler_name, event, error_message)
  ValidationHelpers.validate_handler_execution("core.events.handlers", handler_name, event, error_message)
end

--- Create a test case function for handler validation
---@param test_name string Name of the test case
---@param event_factory_fn function Function that returns event data
---@param handler_name string Handler function name
---@param error_message string? Custom error message
---@return function test_case Test case function
function ValidationHelpers.create_handler_test_case(test_name, event_factory_fn, handler_name, error_message)
  return function()
    local event = event_factory_fn()
    local message = error_message or (handler_name .. " should execute without errors")
    ValidationHelpers.validate_chart_tag_handler(handler_name, event, message)
  end
end

--- Validate module loading without errors
---@param module_path string Module path to require
---@param error_message string? Custom error message
function ValidationHelpers.validate_module_loading(module_path, error_message)
  local success, err = pcall(function()
    require(module_path)
  end)
  local message = error_message or ("Module " .. module_path .. " should load without errors")
  assert(success, message .. ": " .. tostring(err))
end

--- Validate that a module exports expected functions
---@param module table Loaded module
---@param expected_functions string[] Array of expected function names
---@param module_name string? Module name for error messages
function ValidationHelpers.validate_module_exports(module, expected_functions, module_name)
  local name = module_name or "Module"
  assert(type(module) == "table", name .. " should be a table")
  
  for _, func_name in ipairs(expected_functions) do
    assert(type(module[func_name]) == "function", 
      name .. " should export function " .. func_name)
  end
end

--- Create a simple smoke test for module loading
---@param module_path string Module path to require
---@param expected_functions string[]? Expected function exports
---@param module_name string? Module name for error messages
---@return function test_case Test case function
function ValidationHelpers.create_module_smoke_test(module_path, expected_functions, module_name)
  return function()
    local module = require(module_path)
    ValidationHelpers.validate_module_loading(module_path)
    
    if expected_functions then
      ValidationHelpers.validate_module_exports(module, expected_functions, module_name)
    end
  end
end

return ValidationHelpers
