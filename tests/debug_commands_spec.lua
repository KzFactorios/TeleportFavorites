-- tests/commands/debug_commands_spec.lua
-- Minimal smoke test for debug_commands registration

-- Patch require to redirect to mocks for test dependencies
require("tests.mocks.mock_require_patch")
require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local mock_luaPlayer = require("tests.mocks.mock_luaPlayer")

local function make_spy_helpers(called)
    local helpers = {}
    helpers.player_print = function(_, msg) table.insert(called, msg) end
    return helpers
end

local function make_spy_debug_config()
    local config = require("tests.mocks.mock_debug_config")
    return config
end

describe("DebugCommands", function()
    describe("/tf_debug_level command", function()
        before_each(function()
            _G.commands = { add_command = function(_, _, fn) _G._test_cmd_fn = fn end }
            _G.game = { get_player = function(idx) return mock_luaPlayer(idx or 1, "TestPlayer") end }
        end)

        local function clear_and_patch_all(called)
            -- Patch all relevant modules and clear SUT and dependencies from package.loaded
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.utils.gps_utils"] = require("tests.mocks.mock_gps_utils")
            package.loaded["core.utils.gui_helpers"] = require("tests.mocks.mock_gui_helpers")
            package.loaded["core.utils.gui_validation"] = require("tests.mocks.mock_gui_validation")
            package.loaded["core.utils.enhanced_error_handler"] = require("tests.mocks.mock_enhanced_error_handler")
            package.loaded["core.utils.error_handler"] = require("tests.mocks.mock_error_handler")
            package.loaded["gui.favorites_bar.fave_bar"] = require("tests.mocks.mock_fave_bar")
            package.loaded["gui.gui_base"] = require("tests.mocks.mock_gui_base")
            -- Clear SUT and all its dependencies
            package.loaded["core.commands.debug_commands"] = nil
            package.loaded["core.utils.debug_config"] = nil
            package.loaded["core.utils.game_helpers"] = nil
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

        it("should print usage if no parameter", function()
            local called = {}
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1, parameter = nil })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Usage") then found = true break end end
            assert.is_true(found)
        end)

        it("should print error if out of range", function()
            local called = {}
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1, parameter = "99" })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("between 0 and 5") then found = true break end end
            assert.is_true(found)
        end)

        it("should set level and print confirmation for valid input", function()
            local called = {}
            clear_and_patch_all(called)
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1, parameter = "2" })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("set to: 2") then found = true break end end
            assert.is_true(found)
        end)
    end)

    describe("/tf_debug_info command", function()
        it("should print debug info", function()
            local called = {}
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Debug Info") then found = true break end end
            assert.is_true(found)
        end)
    end)

    describe("/tf_debug_production and /tf_debug_development", function()
        it("should enable production mode", function()
            local called = {}
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Production mode enabled") then found = true break end end
            assert.is_true(found)
        end)
        it("should enable development mode", function()
            local called = {}
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Development mode enabled") then found = true break end end
            assert.is_true(found)
        end)
    end)

    describe("/tf_test_controller and /tf_force_build_bar", function()
        it("should print controller test info", function()
            local called = {}
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("CONTROLLER TEST") then found = true break end end
            assert.is_true(found)
        end)
        it("should print force build bar info", function()
            local called = {}
            package.loaded["core.utils.game_helpers"] = make_spy_helpers(called)
            package.loaded["core.utils.debug_config"] = make_spy_debug_config()
            package.loaded["core.commands.debug_commands"] = nil
            local DebugCommands = require("core.commands.debug_commands")
            DebugCommands.register_commands()
            _G._test_cmd_fn({ player_index = 1 })
            assert.is_true(#called > 0)
            local found = false
            for _, msg in ipairs(called) do if msg:match("Force building favorites bar") then found = true break end end
            assert.is_true(found)
        end)
    end)

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
        assert.are.equal(parent["tf_debug_current_level"].caption:match("2"), "2")
        assert.is_false(parent.children[3].enabled)
    end)

    it("should register commands without error", function()
        package.loaded["core.commands.debug_commands"] = nil
        local DebugCommands = require("core.commands.debug_commands")
        _G.commands = { add_command = function() end }
        _G.game = { get_player = function() return mock_luaPlayer(1, "TestPlayer") end }
        assert.has_no.errors(function() DebugCommands.register_commands() end)
    end)
end)
