-- core/events/teleport_history_handlers.lua
-- Event handlers for Teleport History feature
local TeleportHistory = require("core.teleport.teleport_history")

local TeleportHistoryHandlers = {}

-- Track if teleport was initiated by teleport history traversal
local teleport_history_in_progress = {}

local function mark_teleport_history(player_index)
    teleport_history_in_progress[player_index] = true
end

local function clear_teleport_history(player_index)
    teleport_history_in_progress[player_index] = nil
end

-- Shared function to get valid player or return nil
local function _get_valid_player(event)
    if not event.player_index then return nil end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return nil end
    return player
end

-- Handle history navigation with direction and endpoint parameters
local function _handle_history_navigation(event, direction, is_endpoint)
    local player = _get_valid_player(event)
    if not player then return end
    
    local player_index = event.player_index
    mark_teleport_history(player_index)
    TeleportHistory.move_pointer(player, direction, is_endpoint)
    -- clear will be called after script_raised_teleported
end

function TeleportHistoryHandlers.register(script)
    script.on_event("teleport_history-prev", function(event)
        _handle_history_navigation(event, -1, false)
    end)

    script.on_event("teleport_history-next", function(event)
        _handle_history_navigation(event, 1, false)
    end)

    script.on_event("teleport_history-first", function(event)
        _handle_history_navigation(event, -1, true)
    end)

    script.on_event("teleport_history-last", function(event)
        _handle_history_navigation(event, 1, true)
    end)

    script.on_event("teleport_history-clear", function(event)
        local player = _get_valid_player(event)
        if not player then return end
        
        TeleportHistory.clear(player)
    end)

    -- Create a remote interface for TeleportUtils to add to history
    -- This avoids circular dependencies
    if remote then
        remote.add_interface("TeleportFavorites_History", {
            add_to_history = function(player_index)
                local player = game.get_player(player_index)
                if not player or not player.valid then return end
                
                -- Skip if this teleport was initiated by history navigation
                if teleport_history_in_progress[player_index] then
                    clear_teleport_history(player_index)
                    return
                end
                
                -- Add current position to history
                local gps = {
                    x = math.floor(player.position.x),
                    y = math.floor(player.position.y),
                    surface = player.surface.index
                }
                TeleportHistory.add_gps(player, gps)
            end
        })
    end
    
    -- Add a remote interface for other mods to trigger teleport history
    if remote then
        remote.add_interface("TeleportFavorites_History", {
            add_to_history = function(player_index)
                local player = game.get_player(player_index)
                if not player or not player.valid then return end
                
                -- Skip if this teleport was initiated by history navigation
                if teleport_history_in_progress[player_index] then
                    clear_teleport_history(player_index)
                    return
                end
                
                -- Add current position to history
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

return TeleportHistoryHandlers
