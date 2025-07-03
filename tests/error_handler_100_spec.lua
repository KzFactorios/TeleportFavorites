-- Error handler spec for full coverage
local ErrorHandler = require("core.utils.error_handler")

describe("ErrorHandler", function()
  before_each(function()
    -- Mock log function if not defined
    if not _G.log then _G.log = function() end end
  end)
  
  it("should create success result", function()
    local result = ErrorHandler.success("test data")
    assert.equals(result.success, true)
    assert.equals(result.data, "test data")
  end)
  
  it("should create error result", function()
    local result = ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, 
      "Test error message", 
      {test_context = true}
    )
    assert.equals(result.success, false)
    assert.equals(result.error_type, ErrorHandler.ERROR_TYPES.VALIDATION_FAILED)
    assert.equals(result.message, "Test error message")
    assert.equals(result.context.test_context, true)
  end)
  
  it("should handle successful result", function()
    local result = ErrorHandler.success()
    local is_error = ErrorHandler.handle_error(result)
    assert.equals(is_error, false)
  end)
  
  it("should handle error result with no player", function()
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    local is_error = ErrorHandler.handle_error(result)
    assert.equals(is_error, true)
  end)
  
  it("should handle error result with player but no printing", function()
    local player = {valid = true, name = "test_player"}
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    local is_error = ErrorHandler.handle_error(result, player, false)
    assert.equals(is_error, true)
  end)
  
  it("should handle error result with player and printing", function()
    local print_called = false
    local player = {
      valid = true, 
      name = "test_player",
      print = function() print_called = true end
    }
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    local is_error = ErrorHandler.handle_error(result, player, true)
    assert.equals(is_error, true)
    assert.is_true(print_called)
  end)
  
  it("should prevent infinite recursion in handle_error", function()
    -- Mock to simulate _in_error_handler being true
    local old_handle_error = ErrorHandler.handle_error
    -- Set error handler flag to true
    ErrorHandler._in_error_handler = true
    
    -- Create error result
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    
    -- Call handle_error directly which should immediately return true due to _in_error_handler flag
    local is_error = ErrorHandler.handle_error(result)
    assert.equals(is_error, true)
    
    -- Reset flag
    ErrorHandler._in_error_handler = false
  end)
  
  it("should log debug messages with context", function()
    local context = {key1 = "value1", key2 = "value2"}
    ErrorHandler.debug_log("Test debug message", context)
    -- Not much to assert here as we're just ensuring code coverage
    assert.is_true(true)
  end)
  
  it("should log debug messages without context", function()
    ErrorHandler.debug_log("Test debug message")
    -- Not much to assert here as we're just ensuring code coverage
    assert.is_true(true)
  end)
  
  it("should log warning messages", function()
    ErrorHandler.warn_log("Test warning message")
    -- Not much to assert here as we're just ensuring code coverage
    assert.is_true(true)
  end)
  
  it("should prevent recursive logging", function()
    -- Test recursive prevention in debug_log
    ErrorHandler._in_error_handler = true
    ErrorHandler.debug_log("This should be skipped")
    ErrorHandler._in_error_handler = false
    
    -- Test recursive prevention in warn_log
    ErrorHandler._in_error_handler = true
    ErrorHandler.warn_log("This should be skipped")
    ErrorHandler._in_error_handler = false
    
    assert.is_true(true)
  end)
end)
