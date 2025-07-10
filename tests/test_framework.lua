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
    before_each = nil
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

-- Define assertion functions
_G.are_same = function(a, b, msg)
  if a ~= b then
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
