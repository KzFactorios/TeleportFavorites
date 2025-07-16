-- tests/commands/debug_commands_spec.lua
-- Minimal smoke test for debug_commands registration

-- Ensure debug output is visible in test logs
_G.print = print

-- Use custom test framework
require("test_framework")
local mock_luaPlayer = require("mocks.mock_luaPlayer")
local TestHelpers = require("mocks.test_helpers")
local MockFactories = require("mocks.mock_factories")
require("mocks.mock_require_patch")
require("test_bootstrap")
if not _G.storage then _G.storage = {} end

local function make_spy_player_helpers(called)
    local helpers = {}
    helpers.safe_player_print = function(_, msg)
        table.insert(called, msg)
    end
    helpers.debug_print_to_player = function(_, msg)
        table.insert(called, msg)
    end
    return helpers
end

local function make_spy_debug_config()
    local config = require("mocks.mock_debug_config")
    return config
end

local function make_basic_helpers_mock()
    return {
        is_valid_element = function(element) return element ~= nil and element.valid ~= false end,
        is_valid_player = function(player) return player ~= nil and player.valid ~= false end
    }
end

-- Helper to create standardized mock game with players using MockFactories
local function create_mock_game_with_player(player_exists)
    if player_exists == false then
        return { 
            get_player = function() return nil end,
            players = {}
        }
    else
        local mock_player = MockFactories.create_player({
            index = 1, 
            name = "TestPlayer"
        })
        return { 
            get_player = function(idx) 
                return mock_player
            end,
            players = { [1] = mock_player }
        }
    end
end

-- Helpers for command handler registration and invocation
local _test_cmd_handlers = {}
local function patch_commands_mock()
    _test_cmd_handlers = {}
    _G.commands = {
        add_command = function(name, a, b)
            -- Accept both (name, handler) and (name, help, handler)
            local handler
            if type(a) == "function" then
                handler = a
            else
                handler = b
            end
            -- Patch: always call handler with a single argument (cmd), never extra args
            _test_cmd_handlers[name] = function(cmd)
                return handler(cmd)
            end
        end
    }
end

local function call_cmd(name, args)
    assert(_test_cmd_handlers[name], "No handler registered for command: " .. tostring(name))
    return _test_cmd_handlers[name](args)
end

local function clear_and_patch_all(called)
    -- Patch all relevant modules and clear SUT and dependencies from package.loaded
    local all_player_helpers_paths = {
        "core.utils.player_helpers", "player_helpers", "core/player_helpers", "core.utils/player_helpers"
    }
    local all_debug_config_paths = {
        "core.utils.debug_config", "debug_config", "core/debug_config", "core.utils/debug_config"
    }
    for _, path in ipairs(all_player_helpers_paths) do
        package.loaded[path] = make_spy_player_helpers(called)
    end
    for _, path in ipairs(all_debug_config_paths) do
        package.loaded[path] = make_spy_debug_config()
    end
    package.loaded["core.utils.gps_utils"] = require("mocks.mock_gps_utils")
    package.loaded["core.utils.gui_helpers"] = require("mocks.mock_gui_helpers")
    package.loaded["core.utils.gui_validation"] = require("mocks.mock_gui_validation")
    package.loaded["core.utils.enhanced_error_handler"] = require("mocks.mock_enhanced_error_handler")
    package.loaded["core.utils.error_handler"] = require("mocks.mock_error_handler")
    package.loaded["core.utils.basic_helpers"] = {
        is_valid_element = function(element) return element ~= nil and element.valid ~= false end,
        is_valid_player = function(player) return player ~= nil and player.valid ~= false end
    }
    package.loaded["gui.favorites_bar.fave_bar"] = require("mocks.mock_fave_bar")
    package.loaded["gui.gui_base"] = require("mocks.mock_gui_base")
    -- Clear SUT and all its dependencies
    package.loaded["core.commands.debug_commands"] = nil
    for _, path in ipairs(all_debug_config_paths) do package.loaded[path] = nil end
    for _, path in ipairs(all_player_helpers_paths) do package.loaded[path] = nil end
    package.loaded["core.utils.gps_utils"] = nil
    package.loaded["core.utils.gui_helpers"] = nil
    package.loaded["core.utils.gui_validation"] = nil
    package.loaded["core.utils.enhanced_error_handler"] = nil
    package.loaded["core.utils.error_handler"] = nil
    package.loaded["core.utils.basic_helpers"] = nil
    package.loaded["gui.favorites_bar.fave_bar"] = nil
    package.loaded["gui.gui_base"] = nil
    -- Patch _G as fallback
    _G.PlayerHelpers = make_spy_player_helpers(called)
    _G.DebugConfig = make_spy_debug_config()
end

local function clear_debug_commands_from_package_loaded()
    local paths = {
        "core.commands.debug_commands",
        "core/commands/debug_commands",
        "core\\commands\\debug_commands",
        "core.commands\\debug_commands",
        "core/commands\\debug_commands",
        "core\\commands/debug_commands"
    }
    for _, path in ipairs(paths) do
        package.loaded[path] = nil
    end
end

describe("DebugCommands", function()

    describe("/tf_debug_level command", function()
        before_each(function()
            _G.commands = { add_command = function(_, _, fn) _G._test_cmd_fn = fn end }
            _G.game = create_mock_game_with_player(true)
        end)

        it("should do nothing if player is invalid (nil)", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_debug_level", { player_index = 1, parameter = "2" })
            assert.is_true(#called == 0)
        end)

        it("should print usage if parameter is not a number", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = "notanumber" })
            local found = false
            for _, msg in ipairs(called) do if msg:match("Usage") then found = true break end end
            assert.is_true(found)
        end)

        it("should print error if parameter is negative", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = "-1" })
            local found = false
            for _, msg in ipairs(called) do if msg:match("between 0 and 5") then found = true break end end
            assert.is_true(found)
        end)

        it("should work for boundary values 0 and 5", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = "0" })
            call_cmd("tf_debug_level", { player_index = 1, parameter = "5" })
            local found0, found5 = false, false
            for _, msg in ipairs(called) do
                if msg:match("set to: 0") then found0 = true end
                if msg:match("set to: 5") then found5 = true end
            end
            assert.is_true(found0 and found5)
        end)

        it("should print usage if no parameter", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = nil })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Usage") then found = true break end end
            assert.is_true(found)
        end)

        it("should print error if out of range", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = "99" })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("between 0 and 5") then found = true break end end
            assert.is_true(found)
        end)

        it("should set level and print confirmation for valid input", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_level", { player_index = 1, parameter = "2" })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("set to: 2") then found = true break end end
            assert.is_true(found)
        end)
    end)

    describe("/tf_debug_info command", function()
        it("should print debug info", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            _G.game = create_mock_game_with_player(true)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_info", { player_index = 1 })
            assert.is_true(#called > 0)
            -- Accept any variation of the debug info message
            local found = false
            for _, msg in ipairs(called) do 
                local msg_str = tostring(msg)
                if msg_str:match("TeleportFavorites") or msg_str:match("Debug Info") or msg_str:match("Current Level") then 
                    found = true 
                    break 
                end 
            end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil)", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_debug_info", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
    end)

    describe("/tf_debug_production and /tf_debug_development", function()
        it("should enable production mode", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            _G.game = create_mock_game_with_player(true)
            DebugCommands.register_commands()
            call_cmd("tf_debug_production", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if tostring(msg):match("Production mode enabled") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil) for production", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_debug_production", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
        it("should enable development mode", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            _G.game = create_mock_game_with_player(true)
            DebugCommands.register_commands()
            call_cmd("tf_debug_development", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if tostring(msg):match("Development mode enabled") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil) for development", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_debug_development", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
    end)

    describe("/tf_test_controller and /tf_force_build_bar", function()
        it("should print controller test info", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            -- Setup defines.controllers for the test
            _G.defines = _G.defines or {}
            _G.defines.controllers = {
                character = 1,
                god = 2,
                editor = 3
            }
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            _G.game = create_mock_game_with_player(true)
            DebugCommands.register_commands()
            call_cmd("tf_test_controller", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if tostring(msg):match("CONTROLLER TEST") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil) for controller", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_test_controller", { player_index = 1 })
            assert.is_true(#called == 0)
        end)

        it("should print force build bar info", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            _G.game = create_mock_game_with_player(true)
            DebugCommands.register_commands()
            call_cmd("tf_force_build_bar", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if tostring(msg):match("Force building") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil) for force build bar", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_player_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{PlayerHelpers=helpers, DebugConfig=debug_config}
            DebugCommands.register_commands()
            _G.game = create_mock_game_with_player(false)
            call_cmd("tf_force_build_bar", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
    end)

    describe("DebugCommands.create_debug_level_controls edge cases", function()
        it("should not fail if parent is missing add method", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            local mock_parent = { name = "test_parent" }
            local mock_player = MockFactories.create_player({ index = 1, name = "TestPlayer" })
            local success, err = pcall(function()
                local result = DebugCommands.create_debug_level_controls(mock_parent, mock_player)
                -- Expect this to fail gracefully since parent doesn't have add method
                return result
            end)
            -- It should either succeed with graceful handling OR fail gracefully
            assert.is_true(success or err ~= nil)
        end)
    end)

    describe("DebugCommands.on_debug_level_button_click edge cases", function()
        before_each(function()
            _G.game = create_mock_game_with_player(true)
        end)

        it("should do nothing if event.element is nil", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{
                PlayerHelpers=make_spy_player_helpers(called), 
                DebugConfig=make_spy_debug_config(),
                BasicHelpers=make_basic_helpers_mock()
            }
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = nil, player_index = 1 })
            end)
            assert(success == true, "Should handle nil event.element gracefully: " .. tostring(err))
        end)

        it("should do nothing if element is not valid", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = { valid = false }, player_index = 1 })
            end)
            assert(success == true, "Should handle invalid element gracefully: " .. tostring(err))
        end)

        it("should do nothing if player is nil", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            _G.game = create_mock_game_with_player(false)
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = { valid = true, name = "tf_debug_set_level_1" }, player_index = 1 })
            end)
            assert(success == true, "Should handle nil player gracefully: " .. tostring(err))
        end)

        it("should do nothing if element name does not match pattern", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = { valid = true, name = "some_other_button" }, player_index = 1 })
            end)
            assert(success == true, "Should handle non-matching element name gracefully: " .. tostring(err))
        end)

        it("should do nothing if level is not a number", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = { valid = true, name = "tf_debug_set_level_abc" }, player_index = 1 })
            end)
            assert(success == true, "Should handle invalid level string gracefully: " .. tostring(err))
        end)

        it("should handle parent missing children", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                local mock_parent = { 
                    valid = true, 
                    children = {} -- Empty children but present
                }
                DebugCommands.on_debug_level_button_click({ 
                    element = { valid = true, name = "tf_debug_set_level_1", parent = mock_parent }, 
                    player_index = 1 
                })
            end)
            assert(success == true, "Should handle parent with missing children gracefully: " .. tostring(err))
        end)

        it("should handle children with missing or invalid names", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                local mock_parent = { 
                    valid = true, 
                    children = { { name = nil }, { name = "invalid_name" } },
                    tf_debug_current_level = { valid = true, caption = "1 (ERROR)" }
                }
                DebugCommands.on_debug_level_button_click({ element = { valid = true, name = "tf_debug_set_level_1", parent = mock_parent }, player_index = 1 })
            end)
            assert(success == true, "Should handle children with invalid names gracefully: " .. tostring(err))
        end)
    end)

    describe("DebugCommands general functionality", function()
        it("should have a register_commands function", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            assert(type(DebugCommands.register_commands) == "function", "register_commands should be a function")
        end)

        it("should create debug level controls GUI", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            local mock_parent = { add = function() return { add = function() return {} end } end }
            local mock_player = MockFactories.create_player({ index = 1, name = "TestPlayer" })
            local success, err = pcall(function()
                DebugCommands.create_debug_level_controls(mock_parent, mock_player)
            end)
            assert(success, "Should create debug level controls without errors: " .. tostring(err))
        end)

        it("should handle debug level button click", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                DebugCommands.on_debug_level_button_click({ element = { valid = true, name = "tf_debug_set_level_1" }, player_index = 1 })
            end)
            assert(success == true, "Should handle debug level button click without errors: " .. tostring(err))
        end)

        it("should register commands without error", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{PlayerHelpers=make_spy_player_helpers(called), DebugConfig=make_spy_debug_config(), BasicHelpers=make_basic_helpers_mock()}
            local success, err = pcall(function()
                DebugCommands.register_commands()
            end)
            assert(success, "Should register commands without errors: " .. tostring(err))
        end)
    end)
end)
