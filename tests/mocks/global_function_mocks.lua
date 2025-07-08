-- tests/mocks/global_function_mocks.lua
-- Provides stubs for missing global functions required by tests

_G.needs_normalization = function(...) return false end
_G.is_valid_tag_modification = function(...) return true end
_G.validate_tag_editor_opening = function(...) return true end
_G.reset_transient_player_states = function(...) end
_G.ensure_surface_cache = function(...) end
-- Patch for event handler fields (e.g., '?', 'on')
_G.on = function(...) end
_G["?"] = function(...) end

return true
