-- tests/mocks/defines_mock.lua
-- Provides a mock for the Factorio defines table for test environments

_G.defines = _G.defines or {}
_G.defines.mouse_button_type = _G.defines.mouse_button_type or {
  left = 1,
  right = 2,
  middle = 3
}
