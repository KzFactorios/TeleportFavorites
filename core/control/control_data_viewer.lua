---@diagnostic disable: undefined-global

-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local helpers = require("core.utils.helpers_suite")
local safe_destroy_frame = helpers.safe_destroy_frame

local M = {}

--- Register data viewer event handlers
--- @param script table The Factorio script object
function M.register(script)
  script.on_event("tf-toggle-data-viewer", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local parent = player.gui.top
    local frame = parent.data_viewer_frame
    if frame and frame.valid then
      safe_destroy_frame(parent, "data_viewer_frame")
    else
      safe_destroy_frame(parent, "data_viewer_frame")
      data_viewer.build(player, parent, {})
    end
  end)

  -- Handle close button click in data viewer
  script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if element.name == "close_btn" then
      local parent = element.parent
      while parent do
        if parent.name == "data_viewer_frame" then
          local player = game.get_player(event.player_index)
          if player then
            safe_destroy_frame(player.gui.top, "data_viewer_frame")
          end
          break
        end
        parent = parent.parent
      end
    end
  end)
  -- Add more data viewer event handlers here as needed
end

return M
