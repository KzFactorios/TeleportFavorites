#!/usr/bin/env lua
-- Convenient test runner from tests root directory
-- Simply forwards to the infrastructure directory

package.path = "./infrastructure/?.lua;./?.lua;" .. package.path

-- Change to infrastructure directory and run tests
local current_dir = io.popen("cd"):read("*l")
os.execute("cd infrastructure && lua run_all_tests.lua")
