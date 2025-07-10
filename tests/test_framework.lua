-- Simple test framework to mimic Busted-like API
-- Designed to run TeleportFavorites tests

-- Define testing environment
local tests = {}
local current_describe = nil
local before_each_fn = nil

-- Define global functions that mimic Busted
_G.describe = function(desc, fn)
  current_describe = {
    description = desc,
    tests = {},
    before_each = nil,
    after_each = nil
  }
  table.insert(tests, current_describe)
  fn()
  current_describe = nil
end

_G.it = function(desc, fn)
  if not current_describe then
    print("Error: 'it' called outside of 'describe' block")
    return
  end
  table.insert(current_describe.tests, {
    description = desc,
    fn = fn
  })
end

_G.before_each = function(fn)
  if not current_describe then
    -- Global before_each
    before_each_fn = fn
  else
    -- Local before_each for current describe block
    current_describe.before_each = fn
  end
end

_G.after_each = function(fn)
  if not current_describe then
    -- Global after_each - not implemented
    print("Warning: global after_each not implemented")
  else
    -- Local after_each for current describe block
    current_describe.after_each = fn
  end
end

-- Deep equality check for tables
local function deep_equals(a, b)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return false end
  
  -- Check if both tables have the same keys and values
  for k, v in pairs(a) do
    if not deep_equals(v, b[k]) then return false end
  end
  for k, v in pairs(b) do
    if not deep_equals(v, a[k]) then return false end
  end
  return true
end

-- Define assertion functions
_G.are_same = function(a, b, msg)
  if not deep_equals(a, b) then
    error((msg or "Assertion failed: values not equal") .. "\nExpected: " .. tostring(a) .. "\nActual:   " .. tostring(b), 2)
  end
  return true
end

_G.is_true = function(v, msg)
  if not v then
    error((msg or "Assertion failed: value is not true") .. "\nActual: " .. tostring(v), 2)
  end
  return true
end

_G.is_nil = function(v, msg)
  if v ~= nil then
    error((msg or "Assertion failed: value is not nil") .. "\nActual: " .. tostring(v), 2)
  end
  return true
end

_G.has_error = function(fn, msg)
  local ok = pcall(fn)
  if ok then
    error((msg or "Assertion failed: function did not error as expected"), 2)
  end
  return true
end

-- Add compatibility for Busted-style assert syntax
_G.assert = setmetatable({}, {
  __index = function(t, k)
    if k == "has_no" then
      return {
        errors = function(fn, msg)
          local ok, err = pcall(fn)
          if not ok then
            error((msg or "Assertion failed: function errored unexpectedly") .. "\nError: " .. tostring(err), 2)
          end
          return true
        end
      }
    elseif k == "is_true" then
      return is_true
    elseif k == "is_false" then
      return function(v, msg)
        if v then
          error((msg or "Assertion failed: value is not false") .. "\nActual: " .. tostring(v), 2)
        end
        return true
      end
    elseif k == "is_table" then
      return function(v, msg)
        if type(v) ~= "table" then
          error((msg or "Assertion failed: value is not a table") .. "\nActual type: " .. type(v), 2)
        end
        return true
      end
    elseif k == "is_function" then
      return function(v, msg)
        if type(v) ~= "function" then
          error((msg or "Assertion failed: value is not a function") .. "\nActual type: " .. type(v), 2)
        end
        return true
      end
    elseif k == "is_string" then
      return function(v, msg)
        if type(v) ~= "string" then
          error((msg or "Assertion failed: value is not a string") .. "\nActual type: " .. type(v), 2)
        end
        return true
      end
    elseif k == "is_nil" then
      return is_nil
    elseif k == "is_not_nil" then
      return function(v, msg)
        if v == nil then
          error((msg or "Assertion failed: value is nil"), 2)
        end
        return true
      end
    elseif k == "equals" then
      return are_same
    elseif k == "same" then
      return are_same
    elseif k == "are" then
      return {
        same = are_same
      }
    elseif k == "spy" then
      return function(spy_obj)
        return {
          was_called = function()
            if not spy_obj or not spy_obj.was_called then
              error("Expected to be called >0 time(s), but was called 0 time(s)", 2)
            end
            return true
          end,
          was_not_called = function()
            if spy_obj and spy_obj.was_called then
              error("Expected to not be called, but was called", 2)
            end
            return true
          end
        }
      end
    else
      -- Fallback for any other assert methods
      return function(...)
        error("Unsupported assertion: assert." .. k, 2)
      end
    end
  end,
  __call = function(t, condition, msg)
    -- Handle basic assert(condition, message)
    if not condition then
      error(msg or "Assertion failed", 2)
    end
    return true
  end
})

-- Add spy functionality
_G.spy = {
  new = function(fn)
    local spy_data = {
      calls = {},
      was_called = false
    }
    
    local function wrapper(...)
      spy_data.was_called = true
      table.insert(spy_data.calls, {args = {...}})
      if fn then
        return fn(...)
      end
    end
    
    -- Add spy methods directly to the wrapper function
    wrapper.calls = spy_data.calls
    wrapper.was_called = spy_data.was_called
    wrapper.was_called_with = function(...)
      local args = {...}
      for _, call in ipairs(spy_data.calls) do
        local match = true
        for i, arg in ipairs(args) do
          if call.args[i] ~= arg then
            match = false
            break
          end
        end
        if match then return true end
      end
      return false
    end
    
    -- Update wrapper's was_called status
    local original_wrapper = wrapper
    wrapper = function(...)
      spy_data.was_called = true
      original_wrapper.was_called = true
      table.insert(spy_data.calls, {args = {...}})
      if fn then
        return fn(...)
      end
    end
    
    -- Copy methods to new wrapper
    wrapper.calls = spy_data.calls
    wrapper.was_called_with = original_wrapper.was_called_with
    
    return wrapper
  end,
  on = function(target, method_name)
    if not target or not target[method_name] then
      error("spy.on: method '" .. method_name .. "' does not exist on target")
    end
    
    local original = target[method_name]
    local spy_fn = _G.spy.new(original)
    target[method_name] = spy_fn
    
    return spy_fn
  end
}

-- Add basic assertion support for spies by extending the assert metatable
local original_assert_index = getmetatable(_G.assert).__index
getmetatable(_G.assert).__index = function(t, k)
  if k == "spy" then
    return function(spy_obj)
      return {
        was_called = function()
          if not spy_obj or not spy_obj.was_called then
            error("Expected to be called >0 time(s), but was called 0 time(s)", 2)
          end
          return true
        end
      }
    end
  else
    return original_assert_index and original_assert_index(t, k)
  end
end

-- Function to run all tests
local function run_tests()
  print("\n==== Running Tests ====")
  
  local passed = 0
  local failed = 0
  local failures = {}
  
  for _, describe in ipairs(tests) do
    print("\n" .. describe.description)
    
    for _, test in ipairs(describe.tests) do
      io.write("  - " .. test.description .. " ... ")
      io.flush()
      
      -- Run before_each if defined
      local global_before_each_fn = before_each_fn  -- Save local reference
      if global_before_each_fn then
        pcall(global_before_each_fn)
      end
      
      local local_before_each = describe.before_each  -- Save local reference
      if local_before_each then
        pcall(local_before_each)
      end
      
      local success, err = pcall(test.fn)
      
      if success then
        print("PASS")
        passed = passed + 1
      else
        print("FAIL")
        failed = failed + 1
        table.insert(failures, {
          describe = describe.description,
          test = test.description,
          error = err
        })
      end
      
      -- Run after_each if defined
      local local_after_each = describe.after_each  -- Save local reference
      if local_after_each then
        pcall(local_after_each)
      end
    end
  end
  
  -- Print summary
  print("\n==== Test Summary ====")
  print("Total tests: " .. (passed + failed))
  print("Passed: " .. passed)
  print("Failed: " .. failed)
  
  if #failures > 0 then
    print("\nFailures:")
    for i, failure in ipairs(failures) do
      print(string.format("%d) %s: %s\n   %s", 
                         i, 
                         failure.describe, 
                         failure.test, 
                         failure.error))
    end
  end
  
  return failed == 0
end

-- Return API
return {
  run = run_tests
}
