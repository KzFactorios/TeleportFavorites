---@diagnostic disable: undefined-global

-- core/teleport/teleport_history.lua
-- TeleportFavorites Factorio Mod
-- Manages player teleport history stack, pointer navigation, and GPS string conversion for history modal.

local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local ValidationUtils = require("core.utils.validation_utils")
local HistoryItem = require("core.teleport.history_item")


local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local TeleportHistory = {}

-- Observer pattern for history changes
TeleportHistory._observers = {}

--- Register an observer callback for history changes
---@param callback fun(player: LuaPlayer)
function TeleportHistory.register_observer(callback)
    table.insert(TeleportHistory._observers, callback)
end

--- Notify all observers of a history change for a player
---@param player LuaPlayer
function TeleportHistory.notify_observers(player)
    for _, cb in ipairs(TeleportHistory._observers) do
        pcall(cb, player)
    end
end

function TeleportHistory.add_gps(player, gps)
    local valid = ValidationUtils.validate_player(player)
    if not valid or not gps then return end

    local hist = Cache.get_player_teleport_history(player, tonumber(GPSUtils.get_surface_index_from_gps(gps)))
    local stack = hist.stack

    local timestamp = math.floor(game.tick) -- Use game.tick as timestamp (Factorio standard)
    local top = stack[#stack]
    local top_gps = top and top.gps or nil
    if not (top_gps == gps) then
        if #stack >= HISTORY_STACK_SIZE then
            table.remove(stack, 1)
        end
        local item = HistoryItem.new(gps, timestamp)
        table.insert(stack, item)
    end
    hist.pointer = #stack
    TeleportHistory.notify_observers(player)
end

-- Set pointer to specific index (for teleport history modal navigation)
function TeleportHistory.set_pointer(player, surface_index, index)
    if not ValidationUtils.validate_player(player) then return end
    local hist = Cache.get_player_teleport_history(player, surface_index)
    local stack = hist.stack

    if #stack == 0 then
        hist.pointer = 0
        TeleportHistory.notify_observers(player)
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
    TeleportHistory.notify_observers(player)
end

-- Register the remote interface for teleport history tracking
function TeleportHistory.register_remote_interface()
    if not remote.interfaces["TeleportFavorites_History"] then
        remote.add_interface("TeleportFavorites_History", {
            add_to_history = function(player_index, gps)
                local player = game.players[player_index]
                if not player or not player.valid then return end
                TeleportHistory.add_gps(player, gps)
            end
        })
    end
end

return TeleportHistory
