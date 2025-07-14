-- tests/locale_utils_combined_spec.lua
-- Combined and deduplicated tests for core.utils.locale_utils

if not _G.storage then _G.storage = {} end
if not _G.game then
  _G.game = {
    print = function() end,
    players = {}
  }
end

local LocaleUtils = require("core.utils.locale_utils")
local MockFactories = require("mocks.mock_factories")
local original_print = game.print
local print_calls = {}

describe("LocaleUtils Combined", function()
  before_each(function()
    print_calls = {}
    game.print = function(msg) table.insert(print_calls, msg) end
  end)
  after_each(function()
    game.print = original_print
  end)

  it("should exist as a module and have all expected functions", function()
    assert(LocaleUtils, "LocaleUtils module should exist")
    assert(type(LocaleUtils) == "table", "LocaleUtils should be a table")
    assert.is_function(LocaleUtils.get_gui_string)
    assert.is_function(LocaleUtils.get_error_string)
    assert.is_function(LocaleUtils.get_handler_string)
    assert.is_function(LocaleUtils.get_string)
    assert.is_function(LocaleUtils.get_fallback_string)
    assert.is_function(LocaleUtils.substitute_parameters)
    assert.is_function(LocaleUtils.set_debug_mode)
  end)

  it("should provide gui, error, and handler strings with correct prefix", function()
    local mock_player = MockFactories.create_player()
    assert.same({"tf-gui.test_key"}, LocaleUtils.get_gui_string(mock_player, "test_key"))
    assert.same({"tf-error.test_key"}, LocaleUtils.get_error_string(mock_player, "test_key"))
    assert.same({"tf-handler.test_key"}, LocaleUtils.get_handler_string(mock_player, "test_key"))
  end)

  it("should handle all category prefixes", function()
    local mock_player = MockFactories.create_player()
    assert.same({"tf-command.test_key"}, LocaleUtils.get_string(mock_player, "command", "test_key"))
    assert.same({"mod-setting-name.test_key"}, LocaleUtils.get_string(mock_player, "setting_name", "test_key"))
    assert.same({"mod-setting-description.test_key"}, LocaleUtils.get_string(mock_player, "setting_desc", "test_key"))
  end)

  it("should handle parameters in locale strings", function()
    local mock_player = MockFactories.create_player()
    assert.same({"tf-gui.test_key", "param1", "param2"}, LocaleUtils.get_gui_string(mock_player, "test_key", {"param1", "param2"}))
    local complex_params = {"first", {"nested1", "nested2"}, {key = "value"}}
    local result = LocaleUtils.get_gui_string(mock_player, "test_key", complex_params)
    assert.same("tf-gui.test_key", result[1])
    assert.same("first", result[2])
    assert.same({"nested1", "nested2"}, result[3])
  end)

  it("should use fallback for invalid or nil player", function()
    local result = LocaleUtils.get_string(nil, "gui", "confirm")
    assert.equals("Confirm", result)
    assert.equals(1, #print_calls)
    print_calls = {}
    local invalid_player = { valid = false }
    result = LocaleUtils.get_string(invalid_player, "gui", "confirm")
    assert.equals("Confirm", result)
    assert.equals(1, #print_calls)
  end)

  it("should handle unknown category", function()
    local mock_player = { valid = true }
    local result = LocaleUtils.get_string(mock_player, "unknown_category", "test_key")
    assert.equals("test_key", result)
  end)

  it("should provide all fallback strings", function()
    assert(LocaleUtils.get_fallback_string("gui", "confirm") == "Confirm")
    assert(LocaleUtils.get_fallback_string("gui", "cancel") == "Cancel")
    assert(LocaleUtils.get_fallback_string("gui", "close") == "Close")
    assert(LocaleUtils.get_fallback_string("gui", "delete_tag") == "Delete Tag")
    assert(LocaleUtils.get_fallback_string("gui", "teleport_success") == "Teleported successfully!")
    assert(LocaleUtils.get_fallback_string("gui", "teleport_failed") == "Teleportation failed")
    assert(LocaleUtils.get_fallback_string("error", "driving_teleport_blocked") == "Are you crazy? Trying to teleport while driving is strictly prohibited.")
    assert(LocaleUtils.get_fallback_string("error", "player_missing") == "Unable to teleport. Player is missing")
    assert(LocaleUtils.get_fallback_string("error", "unknown_error") == "Unknown error")
    assert(LocaleUtils.get_fallback_string("error", "move_mode_failed") == "Move failed")
    assert(LocaleUtils.get_fallback_string("error", "invalid_location_chosen") == "invalid location chosen")
    assert(LocaleUtils.get_fallback_string("command", "nothing_to_undo") == "No actions to undo")
  end)

  it("should handle parameter edge cases and substitution", function()
    assert(LocaleUtils.substitute_parameters(nil, {"param"}) == "")
    assert(LocaleUtils.substitute_parameters("Some text", nil) == "Some text")
    assert(LocaleUtils.substitute_parameters("Some __1__ text", {}) == "Some __1__ text")
    local params = {"first", "second", name = "John", age = "30"}
    local result = LocaleUtils.substitute_parameters("__1__ __2__ __name__ __age__", params)
    assert(result == "first second John 30")
    result = LocaleUtils.substitute_parameters("Player __name__ (level __level__)", {name = "Steve", level = "42"})
    assert(result == "Player Steve (level 42)")
    result = LocaleUtils.substitute_parameters("__1__ __name__ __2__ __level__", {"Hello", "World", name = "Steve", level = "42"})
    assert(result == "Hello Steve World 42")
  end)
end)
