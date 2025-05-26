-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites

local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")
local GPS = require("core.gps.gps")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local safe_destroy_frame = require("core.utils.helpers").safe_destroy_frame
local player_print = require("core.utils.helpers").player_print
local safe_teleport = require("core.utils.helpers").safe_teleport

local M = {}

--- Register favorites bar event handlers
--- @param script table The Factorio script object
function M.register(script)
  script.on_event("tf-open-fave-bar", function(event)
    local player = game.get_player(event and event.player_index and type(event.player_index) == "number" and tonumber(event.player_index) or -1)
    if not player then return end
    local parent = player.gui.top
    safe_destroy_frame(parent, "fave_bar_frame")
    fave_bar.build(player, parent)
  end)
  -- Add more favorites bar event handlers here as needed
end

return M
