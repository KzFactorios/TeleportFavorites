-- control_tag_editor.lua
-- Handles tag editor GUI events for TeleportFavorites

local tag_editor = require("gui.tag_editor.tag_editor")
local Cache = require("core.cache.cache")
local safe_destroy_frame = require("core.utils.helpers").safe_destroy_frame
local player_print = require("core.utils.helpers").player_print

local M = {}

--- Register tag editor event handlers
--- @param script table The Factorio script object
function M.register(script)
  script.on_event("tf-open-tag-editor", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local parent = player.gui.screen
    safe_destroy_frame(parent, "tag_editor_frame")
    tag_editor.build(player, parent, {})
  end)
  -- Add more tag editor event handlers here as needed
end

return M
