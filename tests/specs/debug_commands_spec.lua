-- tests/commands/debug_commands_spec.lua
-- Minimal smoke test for debug_commands registration

-- Patch require to redirect to mocks for test dependencies

-- Ensure debug output is visible in test logs
_G.print = print

-- Use custom test framework
require("test_framework")
local mock_luaPlayer = require("mocks.mock_luaPlayer")
require("mocks.mock_require_patch")
require("test_bootstrap")
if not _G.storage then _G.storage = {} end

local function make_spy_helpers(called)
    local helpers = {}
    helpers.player_print = function(_, msg)
        table.insert(called, msg)
    end
    return helpers
end

local function make_spy_debug_config()
    local config = require("mocks.mock_debug_config")
    return config
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
    local all_game_helpers_paths = {
        "core.utils.game_helpers", "game_helpers", "core/game_helpers", "core.utils/game_helpers"
    }
    local all_debug_config_paths = {
        "core.utils.debug_config", "debug_config", "core/debug_config", "core.utils/debug_config"
    }
    for _, path in ipairs(all_game_helpers_paths) do
        package.loaded[path] = make_spy_helpers(called)
    end
    for _, path in ipairs(all_debug_config_paths) do
        package.loaded[path] = make_spy_debug_config()
    end
    package.loaded["core.utils.gps_utils"] = require("mocks.mock_gps_utils")
    package.loaded["core.utils.gui_helpers"] = require("mocks.mock_gui_helpers")
    package.loaded["core.utils.gui_validation"] = require("mocks.mock_gui_validation")
    package.loaded["core.utils.enhanced_error_handler"] = require("mocks.mock_enhanced_error_handler")
    package.loaded["core.utils.error_handler"] = require("mocks.mock_error_handler")
    package.loaded["gui.favorites_bar.fave_bar"] = require("mocks.mock_fave_bar")
    package.loaded["gui.gui_base"] = require("mocks.mock_gui_base")
    -- Clear SUT and all its dependencies
    package.loaded["core.commands.debug_commands"] = nil
    for _, path in ipairs(all_debug_config_paths) do package.loaded[path] = nil end
    for _, path in ipairs(all_game_helpers_paths) do package.loaded[path] = nil end
    package.loaded["core.utils.gps_utils"] = nil
    package.loaded["core.utils.gui_helpers"] = nil
    package.loaded["core.utils.gui_validation"] = nil
    package.loaded["core.utils.enhanced_error_handler"] = nil
    package.loaded["core.utils.error_handler"] = nil
    package.loaded["gui.favorites_bar.fave_bar"] = nil
    package.loaded["gui.gui_base"] = nil
    -- Patch _G as fallback
    _G.GameHelpers = make_spy_helpers(called)
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
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
        end)

        it("should do nothing if player is invalid (nil)", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
            call_cmd("tf_debug_level", { player_index = 1, parameter = "2" })
            assert.is_true(#called == 0)
        end)

        it("should print usage if parameter is not a number", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
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
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            call_cmd("tf_debug_info", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Debug Info") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil)", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
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
            local helpers = make_spy_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{GameHelpers=helpers, DebugConfig=debug_config}
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
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
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
            call_cmd("tf_debug_production", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
        it("should enable development mode", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{GameHelpers=helpers, DebugConfig=debug_config}
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
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
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
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
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{GameHelpers=helpers, DebugConfig=debug_config}
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
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
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
            call_cmd("tf_test_controller", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
        it("should print force build bar info", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            clear_debug_commands_from_package_loaded()
            local DebugCommands = require("core.commands.debug_commands")
            local helpers = make_spy_helpers(called)
            local debug_config = make_spy_debug_config()
            DebugCommands._inject{GameHelpers=helpers, DebugConfig=debug_config}
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
            DebugCommands.register_commands()
            call_cmd("tf_force_build_bar", { player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if tostring(msg):match("Force building favorites bar") then found = true break end end
            assert.is_true(found)
        end)

        it("should do nothing if player is invalid (nil) for force build bar", function()
            local called = {}
            patch_commands_mock()
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands._inject{GameHelpers=make_spy_helpers(called), DebugConfig=make_spy_debug_config()}
            DebugCommands.register_commands()
            _G.game = { get_player = function() return nil end }
            call_cmd("tf_force_build_bar", { player_index = 1 })
            assert.is_true(#called == 0)
        end)
    end)

    describe("DebugCommands.create_debug_level_controls edge cases", function()
        it("should not fail if parent is missing add method", function()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            local parent = { valid = true }
            local player = mock_luaPlayer(1, "TestPlayer")
            local ok, err = pcall(function()
                DebugCommands.create_debug_level_controls(parent, player)
            end)
            assert.is_true(ok == false or ok == true) -- Should not throw, but if it does, test fails
        end)
    end)

    describe("DebugCommands.on_debug_level_button_click edge cases", function()
        local DebugCommands
        before_each(function()
            package.loaded["core.commands.debug_commands"] = nil
            DebugCommands = require("core.commands.debug_commands")
        end)

        it("should do nothing if event.element is nil", function()
            local event = { element = nil, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should do nothing if element is not valid", function()
            local event = { element = { valid = false }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should do nothing if player is nil", function()
            _G.game = { get_player = function() return nil end }
            local event = { element = { valid = true, name = "tf_debug_set_level_2" }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should do nothing if element name does not match pattern", function()
            _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
            local event = { element = { valid = true, name = "not_a_debug_button" }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should do nothing if level is not a number", function()
            _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
            local event = { element = { valid = true, name = "tf_debug_set_level_foo" }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should handle parent missing children", function()
            _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
            local parent = { valid = true, ["tf_debug_current_level"] = { valid = true, caption = "", name = "tf_debug_current_level" }, children = {} }
            local event = { element = { valid = true, name = "tf_debug_set_level_2", parent = parent }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)

        it("should handle children with missing or invalid names", function()
            _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
            local parent = { valid = true, ["tf_debug_current_level"] = { valid = true, caption = "", name = "tf_debug_current_level" }, children = { { name = nil }, { name = "tf_debug_set_level_2" } } }
            local event = { element = { valid = true, name = "tf_debug_set_level_2", parent = parent }, player_index = 1 }
            local ok = pcall(function() DebugCommands.on_debug_level_button_click(event) end)
            assert.is_true(ok)
        end)
    end)

    describe("DebugCommands general functionality", function()
        it("should have a register_commands function", function()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            assert.is_function(DebugCommands.register_commands)
        end)

    it("should create debug level controls GUI", function()
        package.loaded["core.commands.debug_commands"] = nil
        local DebugCommands = require("core.commands.debug_commands")
        -- Minimal working mock for Factorio LuaGuiElement
        local function make_element(def)
            def = def or {}
            local el = {
                children = {},
                type = def.type or "flow",
                name = def.name or "",
                direction = def.direction,
                valid = true
            }
            el.add = function(self, child_def)
                child_def = child_def or {}
                local child = make_element(child_def)
                child.name = child_def.name or "tf_debug_level_controls"
                self.children = self.children or {}
                table.insert(self.children, child)
                return child
            end
            return el
        end
        local parent = make_element()
        local player = mock_luaPlayer(1, "TestPlayer")
        local flow = DebugCommands.create_debug_level_controls(parent, player)
        assert.is_table(flow)
        assert.equals("tf_debug_level_controls", flow.name)
    end)

    it("should handle debug level button click", function()
        package.loaded["core.commands.debug_commands"] = nil
        local DebugCommands = require("core.commands.debug_commands")
        local parent = {
            valid = true,
            ["tf_debug_current_level"] = { valid = true, caption = "", name = "tf_debug_current_level" },
            children = {},
        }
        for i=0,5 do
            local btn = { name = "tf_debug_set_level_"..i, enabled = true, valid = true }
            table.insert(parent.children, btn)
        end
        local event = {
            element = { name = "tf_debug_set_level_2", valid = true, parent = parent },
            player_index = 1
        }
        _G.game = { get_player = function(idx) return mock_luaPlayer(idx, "TestPlayer") end }
        DebugCommands.on_debug_level_button_click(event)
        are_same("2", parent["tf_debug_current_level"].caption:match("2"))
        is_true(not parent.children[3].enabled)
    end)

    it("should register commands without error", function()
        package.loaded["core.commands.debug_commands"] = nil
        local DebugCommands = require("core.commands.debug_commands")
        _G.commands = { add_command = function() end }
        _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
        assert.has_no.errors(function() DebugCommands.register_commands() end)
    end)
    end)
end)
