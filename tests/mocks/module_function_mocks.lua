-- tests/mocks/module_function_mocks.lua
-- Provides stubs for missing module function fields required by tests

-- PositionNormalizer mock
package.loaded["core.utils.position_normalizer"] = {
    needs_normalization = function(...) return false end
}

-- ChartTagModificationHelpers mock (add all required stub functions, and patch as global)
local ctmh = {
    is_valid_tag_modification = function(...) return true end,
    extract_gps = function(...) return {x=0, y=0, surface_index=1} end,
    update_tag_and_cleanup = function(...) return true end,
    update_favorites_gps = function(...) return true end
}
package.loaded["core.events.chart_tag_modification_helpers"] = ctmh
_G.ChartTagModificationHelpers = ctmh

-- TagEditor mock (patch as global and in package.loaded)
local tag_editor = {
    validate_tag_editor_opening = function(...) return true end
}
package.loaded["core.tag.tag_editor"] = tag_editor
_G.TagEditor = tag_editor

-- PlayerEvents mock
package.loaded["core.events.player_events"] = {
    reset_transient_player_states = function(...) end
}

-- SurfaceEvents mock
package.loaded["core.events.surface_events"] = {
    ensure_surface_cache = function(...) end
}

-- Patch core.events.handlers as a stub for test runner
package.loaded["core.events.handlers"] = {
    on_init = function() end,
    on_load = function() end,
    on_player_created = function() end,
    on_player_changed_surface = function() end,
    on_open_tag_editor_custom_input = function() end,
    on_chart_tag_added = function() end,
    on_chart_tag_modified = function() end,
    on_chart_tag_removed = function() end
}

return true
