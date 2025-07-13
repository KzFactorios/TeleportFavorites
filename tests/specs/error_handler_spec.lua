-- tests/error_handler_spec.lua
-- Minimal test for ErrorHandler module

describe("ErrorHandler Module", function()
  it("should load without errors", function()
    -- Try to require the module
    local ok, module_or_error = pcall(require, "core.utils.error_handler")
    is_true(ok)
    is_true(type(module_or_error) == "table")
  end)

  it("should have some basic functions", function()
    local ok, ErrorHandler = pcall(require, "core.utils.error_handler")
    if ok and type(ErrorHandler) == "table" then
      -- Check if it has some expected functions (even if they might be mocked)
      is_true(type(ErrorHandler.debug_log) == "function")
      is_true(type(ErrorHandler.warn_log) == "function")
    else
      -- If it's completely broken, at least record that
      is_true(false, "ErrorHandler module failed to load properly")
    end
  end)
end)
