#!/usr/bin/env lua
-- Simple test runner for TeleportFavorites
-- Can be run from anywhere in the project

local function get_script_dir()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@(.+)")
    if not script_path then
        -- Fallback: use current directory
        return io.popen("cd"):read("*l")
    end
    local dir = script_path:match("(.+)[\\/][^\\/]*$")
    return dir or io.popen("cd"):read("*l")
end

local function run_tests()
    local project_root = get_script_dir()
    local tests_dir = project_root .. "\\tests"
    
    print("TeleportFavorites Test Runner")
    print("Project root: " .. project_root)
    print("Running tests from: " .. tests_dir)
    print("=" .. string.rep("=", 50))
    
    -- Run the tests from the correct directory
    local cmd = 'cd /d "' .. tests_dir .. '" && lua infrastructure\\run_all_tests.lua'
    local result = os.execute(cmd)
    
    if result == 0 then
        print("=" .. string.rep("=", 50))
        print("✅ Test execution completed successfully!")
    else
        print("=" .. string.rep("=", 50))
        print("❌ Test execution failed with exit code: " .. tostring(result))
        os.exit(1)
    end
end

-- Run the tests
run_tests()
