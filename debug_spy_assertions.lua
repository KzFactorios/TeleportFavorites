-- Minimal test to debug spy assertion issue

package.path = './?.lua;' .. package.path

-- Load test framework
require('tests.test_framework')

-- Create a simple test object and spy
local test_obj = {
    test_method = function()
        return "test result"
    end
}

-- Create spy
local spy_utils = require("tests.mocks.spy_utils")
local spy_obj = spy_utils.make_spy(test_obj, "test_method")

print("=== Testing Spy Assertions ===")
print("spy_obj type:", type(spy_obj))
print("spy_obj.was_called type:", type(spy_obj.was_called))

-- Test direct call to was_called
print("Testing direct call to spy_obj:was_called()...")
local success1, result1 = pcall(function() return spy_obj:was_called() end)
if success1 then
    print("  Direct call succeeded:", result1)
else
    print("  Direct call failed:", result1)
end

-- Test assert.spy
print("Testing assert.spy(spy_obj).was_not_called()...")
local success2, result2 = pcall(function() 
    return assert.spy(spy_obj).was_not_called()
end)
if success2 then
    print("  assert.spy call succeeded:", result2)
else
    print("  assert.spy call failed:", result2)
end

-- Call the spied method and test again
print("Calling spied method...")
test_obj.test_method()

print("Testing assert.spy(spy_obj).was_called()...")
local success3, result3 = pcall(function() 
    return assert.spy(spy_obj).was_called()
end)
if success3 then
    print("  assert.spy call succeeded:", result3)
else
    print("  assert.spy call failed:", result3)
end

print("=== End Test ===")
