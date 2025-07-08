-- tests/mocks/factorio_test_env.lua
-- Shared Factorio test environment bootstrap for all test files

-- Only define globals if not already present (idempotent)
if not _G.global then _G.global = {} end
if not _G.global.cache then _G.global.cache = {} end
if not _G.storage then _G.storage = {} end
if not _G.storage.players then _G.storage.players = {} end
if not _G.settings then _G.settings = {} end
if not _G.settings.get_player_settings then
    _G.settings.get_player_settings = function()
        return { ["show-player-coords"] = { value = true } }
    end
end
if not _G.game then _G.game = {players = {}, tick = 1} end
if not _G.defines then
    _G.defines = {
        render_mode = { chart = "chart", chart_zoomed_in = "chart-zoomed-in", game = "game" },
        direction = {}, gui_type = {}, inventory = {}, print_sound = {}, print_skip = {},
        chunk_generated_status = {}, controllers = {}, riding = { acceleration = {}, direction = {} },
        alert_type = {}, wire_type = {}, circuit_connector_id = {}, rail_direction = {}, rail_connection_direction = {}
    }
end

-- Export as a module (no-op, just for require semantics)
return true
