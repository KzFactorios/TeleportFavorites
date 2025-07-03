-- tests/error_handler_full_spec.lua
-- 100% coverage for core.utils.error_handler

local ErrorHandler = require("core.utils.error_handler")

describe("ErrorHandler", function()
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
    -- Should not error
    ErrorHandler.debug_log("msg", {foo=1})
    ErrorHandler.warn_log("warn", {bar=2})
  end)
end)
