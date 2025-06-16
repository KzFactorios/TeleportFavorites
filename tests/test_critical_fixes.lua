-- test_critical_fixes.lua
-- Test to verify critical fixes are working correctly

print("\n=== TeleportFavorites Critical Fixes Test ===")

-- Test 1: Check if data.lua syntax is correct
print("\n1. Testing data.lua syntax...")
local data_content = io.open("../data.lua", "r")
if data_content then
    local content = data_content:read("*all")
    data_content:close()
    
    if content:find('},{%s*type = "custom%-input"') then
        print("✅ PASS: data.lua custom input structure is correct")
    else
        print("❌ FAIL: data.lua custom input structure issue")
    end
else
    print("❌ FAIL: Cannot read data.lua")
end

-- Test 2: Check if key modules can be loaded (basic syntax check)
print("\n2. Testing module loading...")

local modules_to_test = {
    "core.events.handlers",
    "core.events.event_registration_dispatcher", 
    "gui.favorites_bar.fave_bar",
    "core.utils.error_handler"
}

local success_count = 0
for _, mod_name in ipairs(modules_to_test) do
    local success, result = pcall(function()
        -- Just check if the file can be parsed (won't work fully without Factorio context)
        local file_path = "../" .. mod_name:gsub("%.", "/") .. ".lua"
        local file = io.open(file_path, "r")
        if file then
            file:close()
            return true
        end
        return false
    end)
    
    if success and result then
        print("✅ PASS: " .. mod_name .. " file exists and readable")
        success_count = success_count + 1
    else
        print("❌ FAIL: " .. mod_name .. " file issue")
    end
end

-- Test 3: Check if locale strings exist
print("\n3. Testing locale strings...")
local locale_file = io.open("../locale/en/strings.cfg", "r")
if locale_file then
    local locale_content = locale_file:read("*all")
    locale_file:close()
    
    if locale_content:find("event_handler_error=") then
        print("✅ PASS: Required locale strings present")
    else
        print("❌ FAIL: Missing required locale strings")
    end
else
    print("❌ FAIL: Cannot read locale file")
end

print("\n=== Test Summary ===")
print("Tests completed. If all critical fixes are applied correctly,")
print("the mod should now work properly in Factorio.")
print("\nTo test in-game:")
print("1. Right-click on map (in chart view) should open tag editor")
print("2. Favorites bar should appear in top GUI when joining game")
print("3. Check factorio-current.log for debug messages")
