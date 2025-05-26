-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local safe_destroy_frame = require("core.utils.helpers").safe_destroy_frame

local M = {}

--- Register data viewer event handlers
--- @param script table The Factorio script object
function M.register(script)
  script.on_event("tf-open-data-viewer", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local parent = player.gui.top
    safe_destroy_frame(parent, "data_viewer_frame")
    data_viewer.build(player, parent, {})
  end)
  -- Add more data viewer event handlers here as needed
end

return M
