---@diagnostic disable: undefined-global
require("test_framework")

-- Clear any cached modules to avoid interference
package.loaded["core.utils.basic_helpers"] = nil

describe("CommandHelpers", function()
    it("should load command_helpers without errors", function()
        local success, err = pcall(function()
            require("core.utils.basic_helpers")
        end)
        assert(success, "BasicHelpers should load without errors: " .. tostring(err))
    end)

    it("should handle basic command registration without errors", function()
        local success, err = pcall(function()
            -- Mock commands global
            local called_commands = {}
            _G.commands = {
                add_command = function(name, desc, handler)
                    table.insert(called_commands, {name, desc, handler})
                end
            }
            
            local BasicHelpers = require("core.utils.basic_helpers")
            
            BasicHelpers.register_commands({
                {"test_cmd", "Test command", function() end}
            })
            
            assert(#called_commands == 1, "Expected 1 command to be registered")
            assert(called_commands[1][1] == "test_cmd", "Expected first command name to be test_cmd") 
            assert(called_commands[1][2] == "Test command", "Expected first command description to be Test command")
        end)
        assert(success, "BasicHelpers should handle basic registration: " .. tostring(err))
    end)

    it("should handle module command registration without errors", function()
        local success, err = pcall(function()
            -- Mock commands global
            local called_commands = {}
            _G.commands = {
                add_command = function(name, desc, handler)
                    table.insert(called_commands, {name, desc, handler})
                end
            }
            
            local BasicHelpers = require("core.utils.basic_helpers")
            
            local test_module = {
                test_handler = function(cmd) return "test result" end
            }
            
            BasicHelpers.register_module_commands(test_module, {
                {"mod_cmd", "Module command", "test_handler"}
            })
            
            assert(#called_commands == 1, "Expected 1 command to be registered") 
            assert(called_commands[1][1] == "mod_cmd", "Expected command name to be mod_cmd")
            assert(called_commands[1][2] == "Module command", "Expected command description to be Module command")
        end)
        assert(success, "BasicHelpers should handle module registration: " .. tostring(err))
    end)
end)
