-- core/teleport/teleport_history.lua
-- TeleportFavorites Factorio Mod
-- Manages player teleport history stack, pointer navigation, and GPS string conversion for history modal.

local GameHelpers = require("core.utils.game_helpers")
local PlayerHelpers = require("core.utils.player_helpers")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local ValidationUtils = require("core.utils.validation_utils")

local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local TeleportHistory = {}


-- Add a GPS to history (if not duplicate at top)
function TeleportHistory.add_gps(player, gps)
    local valid = require("core.utils.validation_utils").validate_player(player)
    if not valid or not gps or not gps.x or not gps.y or not gps.surface then return end
    
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

-- Set pointer to specific index (for teleport history modal navigation)
function TeleportHistory.set_pointer(player, surface_index, index)
    if not ValidationUtils.validate_player(player) then return end
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
