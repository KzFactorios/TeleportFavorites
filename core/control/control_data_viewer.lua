---@diagnostic disable: undefined-global

-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local helpers = require("core.utils.helpers_suite")
local safe_destroy_frame = helpers.safe_destroy_frame
local Lookups = require("core.cache.lookups")

local M = {}

local function get_or_create_main_flow(player)
  local top = player.gui.top
  local flow = top and top.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = top.add{type="flow", name="tf_main_gui_flow", direction="vertical"}
  end
  return flow
end
M.get_or_create_main_flow = get_or_create_main_flow

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

function M.on_data_viewer_tab_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local main_flow = get_or_create_main_flow(player)
  local tab_key = element.tags and element.tags.tab_key
  if not tab_key then return end
  -- Load correct data for each tab
  local global_storage = _G.storage or global.storage or {} -- fallback for test/dev
  local state = { active_tab = tab_key }
  if tab_key == "player_data" then
    state.data = global_storage.players and global_storage.players[player.index] or {}
  elseif tab_key == "surface_data" then
    state.data = global_storage.surfaces or {}
  elseif tab_key == "lookup" then
    state.data = (global and global["Lookups"]) or Lookups or {}
  elseif tab_key == "all_data" then
    state.data = global_storage
  end
  safe_destroy_frame(main_flow, "data_viewer_frame")
  data_viewer.build(player, main_flow, state)
end

--- Register data viewer event handlers
--- @param script table The Factorio script object
function M.register(script)
  -- Only register GUI click handlers here. Do NOT register script.on_event for dv-toggle-data-viewer (handled by dispatcher).

  -- Handle close button click in data viewer
  script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local main_flow = get_or_create_main_flow(player)
    -- Handle close button click in data viewer
    if element.name == "data_viewer_close_btn" then
      safe_destroy_frame(main_flow, "data_viewer_frame")
      return
    end
    -- Handle refresh button click in data viewer
    if element.name == "data_viewer_tab_actions_refresh_data_btn" then
      print("[DataViewer DEBUG] Refresh button clicked by player:", player.name)
      local frame = main_flow.data_viewer_frame
      if not (frame and frame.valid) then return end
      -- Find the currently active tab
      local tabs_flow = frame.data_viewer_inner_flow and frame.data_viewer_inner_flow.data_viewer_tabs_flow
      local active_tab = "player_data" -- default fallback
      if tabs_flow then
        for _, child in pairs(tabs_flow.children) do
          if child.style and child.style.name == "tf_slot_button_dragged" then
            if child.name:find("player_data") then active_tab = "player_data" end
            if child.name:find("surface_data") then active_tab = "surface_data" end
            if child.name:find("lookup") then active_tab = "lookup" end
            if child.name:find("all_data") then active_tab = "all_data" end
          end
        end
      end
      -- Build the correct data snapshot for the tab
      local state = { active_tab = active_tab }
      if active_tab == "player_data" then
        state.data = Cache.get_player_data(player)
      elseif active_tab == "surface_data" then
        state.data = Cache.get_surface_data(player.surface.index)
      elseif active_tab == "lookup" then
        state.data = Lookups.get and Lookups.get("chart_tag_cache") or {}
      elseif active_tab == "all_data" then
        -- Fallback: merge player and surface data for demo
        state.data = {
          player = Cache.get_player_data(player),
          surface = Cache.get_surface_data(player.surface.index)
        }
      end
      -- Rebuild the data viewer with the new snapshot
      safe_destroy_frame(main_flow, "data_viewer_frame")
      data_viewer.build(player, main_flow, state)
      return
    end
    -- Handle tab button clicks
    if element.name:find("^data_viewer_.*_tab$") then
      local tab_context = nil
      if element.name:find("player_data") then tab_context = "player_data" end
      if element.name:find("surface_data") then tab_context = "surface_data" end
      if element.name:find("lookup") then tab_context = "lookup" end
      if element.name:find("all_data") then tab_context = "all_data" end
      if not tab_context then return end
      local state = { active_tab = tab_context }
      if tab_context == "player_data" then
        state.data = Cache.get_player_data(player)
      elseif tab_context == "surface_data" then
        state.data = Cache.get_surface_data(player.surface.index)
      elseif tab_context == "lookup" then
        state.data = Lookups.get and Lookups.get("chart_tag_cache") or {}
      elseif tab_context == "all_data" then
        state.data = {
          player = Cache.get_player_data(player),
          surface = Cache.get_surface_data(player.surface.index)
        }
      end
      safe_destroy_frame(main_flow, "data_viewer_frame")
      data_viewer.build(player, main_flow, state)
      return
    end
    -- Handle opacity up/down
    if element.name == "data_viewer_actions_opacity_up_btn" or element.name == "data_viewer_actions_opacity_down_btn" then
      local frame = main_flow.data_viewer_frame
      if not (frame and frame.valid) then return end
      local pdata = Cache.get_player_data(player)
      local cur_opacity = tonumber(pdata.data_viewer_opacity) or 1.0
      local delta = (element.name == "data_viewer_actions_opacity_up_btn") and 0.1 or -0.1
      local new_opacity = math.max(0.3, math.min(1.0, cur_opacity + delta))
      pdata.data_viewer_opacity = new_opacity
      frame.style.opacity = new_opacity
      return
    end
    -- Handle font size up/down
    if element.name == "data_viewer_actions_font_up_btn" or element.name == "data_viewer_actions_font_down_btn" then
      local frame = main_flow.data_viewer_frame
      if not (frame and frame.valid) then return end
      -- Find the scroll-pane and content flow robustly
      local content_scroll = frame.data_viewer_inner_flow
        and frame.data_viewer_inner_flow.data_viewer_content_frame
        and frame.data_viewer_inner_flow.data_viewer_content_frame.data_viewer_content_scroll
      local content_flow = content_scroll and content_scroll.data_viewer_content_flow
      if not content_flow then return end
      local pdata = Cache.get_player_data(player)
      pdata.data_viewer_settings = pdata.data_viewer_settings or {}
      local dv_settings = pdata.data_viewer_settings
      local cur_size = tonumber(dv_settings.font_size) or 14
      -- Step by 2, clamp to [6,24]
      local delta = (element.name == "data_viewer_actions_font_up_btn") and 2 or -2
      local new_size = math.max(6, math.min(24, cur_size + delta))
      dv_settings.font_size = new_size
      -- Store the font style name as well
      local font_name = "tf_font_" .. tostring(new_size)
      dv_settings.font_style_name = font_name
      -- Redraw the Data Viewer to apply font size everywhere
      -- Find the currently active tab and data
      local tabs_flow = frame.data_viewer_inner_flow and frame.data_viewer_inner_flow.data_viewer_tabs_flow
      local active_tab = "player_data"
      if tabs_flow then
        for _, child in pairs(tabs_flow.children) do
          if child.selected then
            active_tab = child.name:match("data_viewer_(.*)_tab") or active_tab
          end
        end
      end
      local state = { active_tab = active_tab }
      if active_tab == "player_data" then
        state.data = Cache.get_player_data(player)
      elseif active_tab == "surface_data" then
        state.data = Cache.get_surface_data(player.surface.index)
      elseif active_tab == "lookup" then
        state.data = Lookups.get and Lookups.get("chart_tag_cache") or {}
      elseif active_tab == "all_data" then
        state.data = {
          player = Cache.get_player_data(player),
          surface = Cache.get_surface_data(player.surface.index)
        }
      end
      safe_destroy_frame(main_flow, "data_viewer_frame")
      data_viewer.build(player, main_flow, state)
      return
    end
  end)

  -- Register custom input for ctrl+F12 (open/close Data Viewer)
  script.on_event("dv-toggle-data-viewer", function(event)
    M.on_toggle_data_viewer(event)
  end)

  -- Keyboard navigation for tabs (tab/shift-tab) using custom inputs
  script.on_event("tf-data-viewer-tab-next", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local main_flow = get_or_create_main_flow(player)
    local tabs_flow = main_flow.data_viewer_frame and main_flow.data_viewer_frame.data_viewer_inner_flow and main_flow.data_viewer_frame.data_viewer_inner_flow.data_viewer_tabs_flow
    if not tabs_flow then return end
    local children = tabs_flow.children
    local focused_idx = 1
    for i, child in ipairs(children) do
      if child.focused then focused_idx = i break end
    end
    local next_idx = focused_idx + 1
    if next_idx > #children then next_idx = 1 end
    if children[next_idx] and children[next_idx].type == "sprite-button" then
      children[next_idx].focus()
    end
  end)
  script.on_event("tf-data-viewer-tab-prev", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local main_flow = get_or_create_main_flow(player)
    local tabs_flow = main_flow.data_viewer_frame and main_flow.data_viewer_frame.data_viewer_inner_flow and main_flow.data_viewer_frame.data_viewer_inner_flow.data_viewer_tabs_flow
    if not tabs_flow then return end
    local children = tabs_flow.children
    local focused_idx = 1
    for i, child in ipairs(children) do
      if child.focused then focused_idx = i break end
    end
    local prev_idx = focused_idx - 1
    if prev_idx < 1 then prev_idx = #children end
    if children[prev_idx] and children[prev_idx].type == "sprite-button" then
      children[prev_idx].focus()
    end
  end)
end

-- Helper to ensure a valid active tab
function M.get_valid_active_tab(state)
  local valid_tabs = {"player_data", "surface_data", "lookup", "all_data"}
  for _, tab in ipairs(valid_tabs) do
    if state and state.active_tab == tab then return tab end
  end
  return valid_tabs[1] -- default to first tab
end

return M
