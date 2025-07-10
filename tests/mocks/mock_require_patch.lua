-- tests/mocks/mock_require_patch.lua
-- Patch global require to redirect to mocks for test dependencies

local real_require = require
local mock_map = {
    ["core.utils.gui_helpers"] = "tests.mocks.mock_gui_helpers",
    ["core.utils.gui_validation"] = "tests.mocks.mock_gui_validation",
    ["core.utils.gps_utils"] = "tests.mocks.mock_gps_utils",
    ["core.utils.debug_config"] = "tests.mocks.mock_debug_config",
    ["core.utils.enhanced_error_handler"] = "tests.mocks.mock_enhanced_error_handler",
    ["core.utils.error_handler"] = "tests.mocks.mock_error_handler",
    ["core.utils.game_helpers"] = "tests.mocks.mock_game_helpers",
    ["gui.favorites_bar.fave_bar"] = "tests.mocks.mock_fave_bar",
    ["gui.gui_base"] = "tests.mocks.mock_gui_base",
    ["settings"] = "tests.mocks.mock_settings"
}

function require(name)
    -- Never mock the SUT file, always load the real one for coverage
    if name == "core.commands.debug_commands" then
        return real_require(name)
    end
    if mock_map[name] then
        return real_require(mock_map[name])
    end
    return real_require(name)
end
