---@diagnostic disable: undefined-global

-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local helpers = require("core.utils.helpers_suite")
local safe_destroy_frame = helpers.safe_destroy_frame

local M = {}

local function get_or_create_main_flow(player)
  local top = player.gui.top
  local flow = top and top.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = top.add{type="flow", name="tf_main_gui_flow", direction="vertical"}
  end
  return flow
end

function M.on_toggle_data_viewer(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local main_flow = get_or_create_main_flow(player)
  local frame = main_flow.data_viewer_frame
  if frame and frame.valid then
    safe_destroy_frame(main_flow, "data_viewer_frame")
  else
    safe_destroy_frame(main_flow, "data_viewer_frame")
    data_viewer.build(player, main_flow, {})
  end
end

--- Register data viewer event handlers
--- @param script table The Factorio script object
function M.register(script)
  -- Only register GUI click handlers here. Do NOT register script.on_event for dv-toggle-data-viewer (handled by dispatcher).

  -- Handle close button click in data viewer
  script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if element.name == "data_viewer_close_btn" then
      local player = game.get_player(event.player_index)
      if player then
        local main_flow = get_or_create_main_flow(player)
        safe_destroy_frame(main_flow, "data_viewer_frame")
      end
    end
  end)
  -- Add more data viewer event handlers here as needed
end

return M
