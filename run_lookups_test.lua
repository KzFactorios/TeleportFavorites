-- Run the lookups_spec.lua test directly
-- No dependencies on test frameworks

-- Add test assertions to global environment
_G.are_same = function(a, b, msg)
  if a ~= b then
    error((msg or "Assertion failed: values not equal") .. "\nExpected: " .. tostring(a) .. "\nActual:   " .. tostring(b), 2)
  end
end

_G.is_true = function(v, msg)
  if not v then
    error((msg or "Assertion failed: value is not true") .. "\nActual: " .. tostring(v), 2)
  end
end

_G.is_nil = function(v, msg)
  if v ~= nil then
    error((msg or "Assertion failed: value is not nil") .. "\nActual: " .. tostring(v), 2)
  end
end

_G.has_error = function(fn, msg)
  local ok = pcall(fn)
  if ok then
    error((msg or "Assertion failed: function did not error as expected"), 2)
  end
end

-- Add testing functions
local current_describe = nil
local describe_blocks = {}
local before_each_fn = nil

_G.describe = function(desc, fn)
  print("\nDESCRIBE: " .. desc)
  table.insert(describe_blocks, {
    description = desc,
    fn = fn,
    before_each = nil,
    tests = {}
  })
  current_describe = describe_blocks[#describe_blocks]
  fn() -- Execute the describe block immediately
  current_describe = nil
end

_G.before_each = function(fn)
  if current_describe then
    current_describe.before_each = fn
  else
    before_each_fn = fn
  end
end

_G.it = function(desc, fn)
  if not current_describe then
    error("'it' block must be inside a 'describe' block")
    return
  end
  
  print("  IT: " .. desc)
  
  -- Run the test immediately
  
  -- Run before_each hooks if any
  if before_each_fn then
    before_each_fn()
  end
  
  if current_describe.before_each then
    current_describe.before_each()
  end
  
  -- Run the test
  local success, err = pcall(fn)
  if success then
    print("    ✓ PASS")
  else
    print("    ✗ FAIL: " .. tostring(err))
  end
end

-- Setup game environment mocks
local function setup_game_mocks()
  _G.game = {
    surfaces = {},
    forces = {
      ["player"] = {
        find_chart_tags = function(surface)
          return {}
        end
      }
    }
  }
end

-- Load the test file
print("\n==== Running lookups_spec.lua Test ====")
setup_game_mocks()

-- Load required mocks/files
local success, err = pcall(function()
  dofile("tests/lookups_spec.lua")
end)

if not success then
  print("ERROR running test: " .. tostring(err))
  os.exit(1)
else
  print("\n==== Test Completed ====")
  os.exit(0)
end
