-- core/teleport/teleport_history.lua

local GameHelpers = require("core.utils.game_helpers")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")

local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local TeleportHistory = {}



-- Add a GPS to history (if not duplicate at top)
function TeleportHistory.add_gps(player, gps)
    if not player or not player.valid or not gps or not gps.x or not gps.y or not gps.surface then return end
    
    local surface_index = gps.surface
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    -- Only add if not duplicate at top
    local top = stack[#stack]
    if not (top and top.x == gps.x and top.y == gps.y and top.surface == gps.surface) then
        if #stack >= HISTORY_STACK_SIZE then
            table.remove(stack, 1)
        end
        -- Just store the basic position info - our GPS conversion will handle the rest
        table.insert(stack, { 
            x = gps.x, 
            y = gps.y, 
            surface = gps.surface
        })
    end
    hist.pointer = #stack
end

-- Move pointer up/down, teleport if possible
function TeleportHistory.move_pointer(player, direction, shift)
    if not player or not player.valid then return end
    
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    if #stack == 0 then
        -- No history available
        return 
    end
    
    if shift then
        -- Jump to first or last entry based on direction
        hist.pointer = (direction < 0) and 1 or #stack
    else
        -- Step one position in the specified direction
        local new_ptr = hist.pointer + direction
        if new_ptr < 1 or new_ptr > #stack then 
            -- Pointer would be out of bounds - don't move it
            return 
        end
        hist.pointer = new_ptr
    end
    
    -- Attempt teleport to the location at the new pointer position
    TeleportHistory.teleport_to_pointer(player)
end

-- Clear stack
function TeleportHistory.clear(player)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    -- Reset both stack and pointer
    -- The reference to hist is maintained in the cache, so these changes
    -- will be persisted to global automatically
    hist.stack = {}
    hist.pointer = 0
end

-- Teleport to pointer location (with water/space checks)
function TeleportHistory.teleport_to_pointer(player)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    local ptr = hist.pointer
    
    if ptr < 1 or ptr > #stack then 
        return false
    end
    
    local gps = stack[ptr]
    if not gps then 
        return false
    end
    
    -- Use GameHelpers.safe_teleport_to_gps for all checks (water, space, etc)
    -- Convert GPS object to string using our helper
    local gps_str = TeleportHistory.get_gps_string(gps)
    if not gps_str then
        return false
    end
    
    -- Perform the teleport silently without any debugging output
    return GameHelpers.safe_teleport_to_gps(player, gps_str)
end

-- Convert our GPS object to proper Factorio GPS string format using the existing utility
function TeleportHistory.get_gps_string(gps)
    if not gps or not gps.x or not gps.y or not gps.surface then
        return nil
    end
    
    -- Use GPSUtils with map position format
    return GPSUtils.gps_from_map_position({ x = gps.x, y = gps.y }, gps.surface)
end

-- Debug function to print history stack
function TeleportHistory.print_history(player)
    if not player or not player.valid then return end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    player.print("==== Teleport History Debug ====")
    player.print("Surface: " .. surface_index .. " | Stack size: " .. #stack .. " | Pointer: " .. hist.pointer)
    
    if #stack == 0 then
        player.print("History is empty")
        return
    end
    
    for i, gps in ipairs(stack) do
        local prefix = (i == hist.pointer) and "→ " or "  "
        local gps_display = gps.x .. ", " .. gps.y .. ", surface " .. gps.surface
        local gps_string = TeleportHistory.get_gps_string(gps) or "invalid"
        player.print(prefix .. i .. ": [" .. gps_display .. "] (GPS: " .. gps_string .. ")")
    end
    player.print("================================")
end

return TeleportHistory
