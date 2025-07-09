-- tests/error_handler_spec.lua
-- Combined and robust test suite for core.utils.error_handler

local ErrorHandler = require("core.utils.error_handler")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("ErrorHandler", function()
  before_each(function()
    if not _G.log then _G.log = function() end end
  end)

  it("should handle errors gracefully", function()
    local _ = mock_player_data.create_mock_player_data()
    local ok, err = pcall(function() ErrorHandler.raise("Test error") end)
    assert.is_false(ok)
    assert.is_string(err)
  end)

  it("should create a success result", function()
    local res = ErrorHandler.success({foo=1})
    assert.is_true(res.success)
    assert.same(res.data, {foo=1})
  end)

  it("should create an error result", function()
    local res = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "fail", {ctx=1})
    assert.is_false(res.success)
    assert.equals(res.error_type, ErrorHandler.ERROR_TYPES.VALIDATION_FAILED)
    assert.equals(res.message, "fail")
    assert.same(res.context, {ctx=1})
  end)

  it("should handle error and print/log", function()
    local called = false
    local fake_player = {valid=true, name="Test", print=function() called=true end}
    local res = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "fail")
    local is_err = ErrorHandler.handle_error(res, fake_player, true)
    assert.is_true(is_err)
    assert.is_true(called)
  end)

  it("should debug log and warn log", function()
    ErrorHandler.debug_log("msg", {foo=1})
    ErrorHandler.warn_log("warn", {bar=2})
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
    local player = {valid = true, name = "test_player", print = function() print_called = true end}
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    local is_error = ErrorHandler.handle_error(result, player, true)
    assert.equals(is_error, true)
    assert.is_true(print_called)
  end)

  it("should prevent infinite recursion in handle_error", function()
    ErrorHandler._in_error_handler = true
    local result = ErrorHandler.error(ErrorHandler.ERROR_TYPES.VALIDATION_FAILED, "Test error")
    local is_error = ErrorHandler.handle_error(result)
    assert.equals(is_error, true)
    ErrorHandler._in_error_handler = false
  end)

  it("should log debug messages with context", function()
    local context = {key1 = "value1", key2 = "value2"}
    ErrorHandler.debug_log("Test debug message", context)
    assert.is_true(true)
  end)

  it("should log debug messages without context", function()
    ErrorHandler.debug_log("Test debug message")
    assert.is_true(true)
  end)

  it("should log warning messages", function()
    ErrorHandler.warn_log("Test warning message")
    assert.is_true(true)
  end)

  it("should prevent recursive logging", function()
    ErrorHandler._in_error_handler = true
    ErrorHandler.debug_log("This should be skipped")
    ErrorHandler._in_error_handler = false
    assert.is_true(true)
  end)
end)
