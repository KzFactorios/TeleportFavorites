-- core/teleport/teleport_history.lua

local GameHelpers = require("core.utils.game_helpers")
local PlayerHelpers = require("core.utils.player_helpers")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local BasicHelpers = require("core.utils.basic_helpers")

local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local TeleportHistory = {}



-- Add a GPS to history (if not duplicate at top)
function TeleportHistory.add_gps(player, gps)
    if not BasicHelpers.is_valid_player(player) or not gps or not gps.x or not gps.y or not gps.surface then return end
    
    local surface_index = gps.surface
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    -- Convert to GPS string format immediately for storage
    local gps_string = GPSUtils.gps_from_map_position({ x = gps.x, y = gps.y }, gps.surface)
    if not gps_string then return end
    
    -- Only add if not duplicate at top
    local top = stack[#stack]
    if not (top == gps_string) then
        if #stack >= HISTORY_STACK_SIZE then
            table.remove(stack, 1)
        end
        -- Store as GPS string directly
        table.insert(stack, gps_string)
    end
    hist.pointer = #stack
end

-- Move pointer up/down, teleport if possible
function TeleportHistory.move_pointer(player, direction, shift)
    if not BasicHelpers.is_valid_player(player) then return end
    
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
    if not BasicHelpers.is_valid_player(player) then return end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    -- Reset both stack and pointer
    -- The reference to hist is maintained in the cache, so these changes
    -- will be persisted to global automatically
    hist.stack = {}
    hist.pointer = 0
end

-- Set pointer to specific index (for teleport history modal navigation)
function TeleportHistory.set_pointer(player, surface_index, index)
    if not BasicHelpers.is_valid_player(player) then return end
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    if #stack == 0 then
        hist.pointer = 0
        return
    end
    
    -- Clamp index to valid range
    if index < 1 then
        hist.pointer = 1
    elseif index > #stack then
        hist.pointer = #stack
    else
        hist.pointer = index
    end
end

-- Teleport to pointer location (with water/space checks)
function TeleportHistory.teleport_to_pointer(player)
    if not BasicHelpers.is_valid_player(player) then return end
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
function TeleportHistory.get_gps_string(gps_or_string)
    -- If it's already a GPS string, return it directly
    if type(gps_or_string) == "string" then
        return gps_or_string
    end
    
    -- Legacy support: if it's still in old {x, y, surface} format, convert it
    if type(gps_or_string) == "table" and gps_or_string.x and gps_or_string.y and gps_or_string.surface then
        return GPSUtils.gps_from_map_position({ x = gps_or_string.x, y = gps_or_string.y }, gps_or_string.surface)
    end
    
    return nil
end

-- Debug function to print history stack
function TeleportHistory.print_history(player)
    if not BasicHelpers.is_valid_player(player) then return end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack
    
    PlayerHelpers.safe_player_print(player, "==== Teleport History Debug ====")
    PlayerHelpers.safe_player_print(player, "Surface: " .. surface_index .. " | Stack size: " .. #stack .. " | Pointer: " .. hist.pointer)
    
    if #stack == 0 then
        PlayerHelpers.safe_player_print(player, "History is empty")
        return
    end
    
    for i, gps_string in ipairs(stack) do
        local prefix = (i == hist.pointer) and "→ " or "  "
        -- Stack entries are now GPS strings, so display them directly
        local gps_display = gps_string or "invalid"
        PlayerHelpers.safe_player_print(player, prefix .. i .. ": " .. gps_display)
    end
    PlayerHelpers.safe_player_print(player, "================================")
end

-- Register the remote interface for teleport history tracking
function TeleportHistory.register_remote_interface()
    if not remote.interfaces["TeleportFavorites_History"] then
        remote.add_interface("TeleportFavorites_History", {
            add_to_history = function(player_index)
                local player = game.players[player_index]
                if not player or not player.valid then return end
                
                local gps = {
                    x = math.floor(player.position.x),
                    y = math.floor(player.position.y),
                    surface = player.surface.index
                }
                TeleportHistory.add_gps(player, gps)
            end
        })
    end
end

return TeleportHistory
