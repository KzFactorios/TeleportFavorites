-- core/teleport/teleport_history.lua

local GameHelpers = require("core.utils.game_helpers")

local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local TeleportHistory = {}

-- Utility: Get or create player/surface history
local function _get_player_surface_history(player_index, surface_index)
    if not global.teleport_history then global.teleport_history = {} end
    if not global.teleport_history[player_index] then global.teleport_history[player_index] = {} end
    if not global.teleport_history[player_index][surface_index] then
        global.teleport_history[player_index][surface_index] = { stack = {}, pointer = 0 }
    end
    return global.teleport_history[player_index][surface_index]
end

-- Add a GPS to history (if not duplicate at top)
function TeleportHistory.add_gps(player, gps)
    if not player or not player.valid or not gps or not gps.x or not gps.y or not gps.surface then return end
    local surface_index = gps.surface
    local hist = _get_player_surface_history(player.index, surface_index)
    local stack = hist.stack
    -- Only add if not duplicate at top
    local top = stack[#stack]
    if not (top and top.x == gps.x and top.y == gps.y and top.surface == gps.surface) then
        if #stack >= HISTORY_STACK_SIZE then
            table.remove(stack, 1)
        end
        table.insert(stack, { x = gps.x, y = gps.y, surface = gps.surface })
    end
    hist.pointer = #stack
end

-- Move pointer up/down, teleport if possible
function TeleportHistory.move_pointer(player, direction, shift)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = _get_player_surface_history(player.index, surface_index)
    local stack = hist.stack
    if #stack == 0 then return end
    if shift then
        hist.pointer = (direction < 0) and 1 or #stack
    else
        local new_ptr = hist.pointer + direction
        if new_ptr < 1 or new_ptr > #stack then return end
        hist.pointer = new_ptr
    end
    TeleportHistory.teleport_to_pointer(player)
end

-- Clear stack
function TeleportHistory.clear(player)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = _get_player_surface_history(player.index, surface_index)
    hist.stack = {}
    hist.pointer = 0
end

-- Teleport to pointer location (with water/space checks)
function TeleportHistory.teleport_to_pointer(player)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = _get_player_surface_history(player.index, surface_index)
    local stack = hist.stack
    local ptr = hist.pointer
    if ptr < 1 or ptr > #stack then return end
    local gps = stack[ptr]
    if not gps then return end
    -- Use GameHelpers.safe_teleport_to_gps for all checks (water, space, etc)
    -- gps must be a string in 'x,y,surface' format for GameHelpers.safe_teleport_to_gps
    local gps_str = string.format("%d,%d,%d", gps.x, gps.y, gps.surface)
    local success = GameHelpers.safe_teleport_to_gps(player, gps_str)
    if not success then
        GameHelpers.safe_play_sound(player, { path = "utility/cannot_build" })
    end
end

return TeleportHistory
