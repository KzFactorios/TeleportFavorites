#!/usr/bin/env lua
-- Universal test runner that works from any directory
-- Automatically finds the project root and runs tests from the correct location

local function find_project_root()
    -- Try to find the project root by looking for key files
    local function file_exists(path)
        local file = io.open(path, "r")
        if file then
            file:close()
            return true
        end
        return false
    end
    
    -- Get current working directory
    local current_dir = io.popen("cd"):read("*l")
    local test_paths = {
        current_dir,                                    -- Current directory
        current_dir .. "\\tests",                       -- tests subdirectory
        current_dir .. "\\..\\tests",                   -- parent/tests
        current_dir .. "\\..\\..",                      -- two levels up
        current_dir .. "\\..\\..\\tests",               -- two levels up/tests
    }
    
    for _, path in ipairs(test_paths) do
        local info_json = path .. "\\info.json"
        local control_lua = path .. "\\control.lua"
        if file_exists(info_json) and file_exists(control_lua) then
            return path .. "\\tests"
        end
    end
    
    -- Fallback: assume we're in the right place
    return current_dir
end

local function run_tests()
    local tests_dir = find_project_root()
    print("Running tests from: " .. tests_dir)
    
    -- Build command with any specified test files
    local cmd = 'cd /d "' .. tests_dir .. '" && lua infrastructure\\run_all_tests.lua'
    
    -- Add any command line arguments (test files) to the command
    if arg and #arg > 0 then
        for i = 1, #arg do
            cmd = cmd .. ' "' .. arg[i] .. '"'
        end
    end
    
    local result = os.execute(cmd)
    
    if result ~= 0 then
        print("Test execution failed with exit code: " .. tostring(result))
        os.exit(1)
    end
end

run_tests()
