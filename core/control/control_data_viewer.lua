---@diagnostic disable: undefined-global

-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local helpers = require("core.utils.helpers_suite")
local safe_destroy_frame = helpers.safe_destroy_frame
local Lookups = require("core.cache.lookups")

local M = {}

--- Load data for the specified tab - centralized to eliminate duplication
---@param player LuaPlayer
---@param active_tab string
---@param font_size number?
---@return table state object with data, top_key, and active_tab
local function load_tab_data(player, active_tab, font_size)
  local state = { active_tab = active_tab, font_size = font_size or 12 }
  
  if active_tab == "player_data" then
    state.data = Cache.get_player_data(player)
    state.top_key = "player_data"
  elseif active_tab == "surface_data" then
    state.data = Cache.get_surface_data(player.surface.index)
    state.top_key = "surface_data"
  elseif active_tab == "lookup" then
    state.data = Lookups.get and Lookups.get("chart_tag_cache") or {}
    state.top_key = "lookups"
  elseif active_tab == "all_data" then
    state.data = storage
    state.top_key = "all_data"
  end
  
  return state
end

--- Rebuild the data viewer with fresh data - centralized to eliminate duplication
---@param player LuaPlayer
---@param main_flow LuaGuiElement
---@param active_tab string
---@param font_size number?
---@param show_flying_text boolean?
local function rebuild_data_viewer(player, main_flow, active_tab, font_size, show_flying_text)
  local state = load_tab_data(player, active_tab, font_size)
  helpers.safe_destroy_frame(main_flow, "data_viewer_frame")
  data_viewer.build(player, main_flow, state)
  
  if show_flying_text then
    data_viewer.show_refresh_flying_text(player)
  end
end

--- Update font size and rebuild viewer - centralized to eliminate duplication
---@param player LuaPlayer
---@param main_flow LuaGuiElement
---@param delta number Font size change (-2 or +2)
local function update_font_size(player, main_flow, delta)
  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
    local cur_size = tonumber(pdata.data_viewer_settings.font_size) or 12
  local new_size = math.max(6, math.min(24, cur_size + delta))
  pdata.data_viewer_settings.font_size = new_size
  
  local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
  rebuild_data_viewer(player, main_flow, active_tab, new_size)
end

--- Find currently active tab from GUI elements
---@param main_flow LuaGuiElement
---@return string active_tab
local function find_active_tab_from_gui(main_flow)
  local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
  if not (frame and frame.valid) then return "player_data" end
  
  local tabs_flow = frame.data_viewer_inner_flow and frame.data_viewer_inner_flow.data_viewer_tabs_flow
  if not tabs_flow then return "player_data" end
  
  for _, child in pairs(tabs_flow.children) do
    if child.style and child.style.name == "tf_slot_button_dragged" then
      if child.name:find("player_data") then return "player_data" end
      if child.name:find("surface_data") then return "surface_data" end
      if child.name:find("lookup") then return "lookup" end
      if child.name:find("all_data") then return "all_data" end
    end
  end
  
  return "player_data" -- default fallback
end

local function get_or_create_gui_flow_from_gui_top(player)
  local top = player.gui.top
  local flow = top and top.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = top.add {
      type = "flow",
      name = "tf_main_gui_flow",
      direction = "vertical",
      style = "vertical_flow" -- vanilla style, stretches to fit children, not scrollable
    }
    -- Do NOT set .style fields at runtime for flows; use style at creation only
  end
  return flow
end
M.get_or_create_gui_flow_from_gui_top = get_or_create_gui_flow_from_gui_top

function M.on_toggle_data_viewer(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  local main_flow = get_or_create_gui_flow_from_gui_top(player)
  local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
  local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
  local font_size = pdata.data_viewer_settings.font_size or 12
  
  if frame and frame.valid ~= false then
    helpers.safe_destroy_frame(main_flow, "data_viewer_frame")
  else
    rebuild_data_viewer(player, main_flow, active_tab, font_size)
  end
end

function M.on_data_viewer_tab_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  local main_flow = get_or_create_gui_flow_from_gui_top(player)
  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
  local tab_key = element.tags and element.tags.tab_key
  if not tab_key then return end
  
  pdata.data_viewer_settings.active_tab = tab_key
  local font_size = pdata.data_viewer_settings.font_size or 12
  
  -- Debug logging with centralized data loading
  local state = load_tab_data(player, tab_key, font_size)
  local dtype = type(state.data)
  local dkeys = ""
  if dtype == "table" then
    local function extract_key(_, key)
      return tostring(key)
    end
    local keys = helpers.map(state.data, extract_key)
    dkeys = table.concat(keys, ", ")
  else
    dkeys = tostring(state.data)
  end
  log("[TF DataViewer] Data type for tab '" .. tab_key .. "': " .. dtype .. ", keys: " .. dkeys)
  log("[TF DataViewer] State passed to data_viewer.build: active_tab=" ..
    tostring(state.active_tab) .. ", font_size=" .. tostring(font_size))
  
  rebuild_data_viewer(player, main_flow, tab_key, font_size)
end

function M.on_data_viewer_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  local main_flow = get_or_create_gui_flow_from_gui_top(player)

  -- Close button
  if element.name == "data_viewer_close_btn" then
    helpers.safe_destroy_frame(main_flow, "data_viewer_frame")
    return
  end

  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
  -- Robust tab switching (explicit name match)
  if element.name == "data_viewer_player_data_tab" then
    pdata.data_viewer_settings.active_tab = "player_data"
  elseif element.name == "data_viewer_surface_data_tab" then
    pdata.data_viewer_settings.active_tab = "surface_data"
  elseif element.name == "data_viewer_lookup_tab" then
    pdata.data_viewer_settings.active_tab = "lookup"
  elseif element.name == "data_viewer_all_data_tab" then
    pdata.data_viewer_settings.active_tab = "all_data"
  end  -- Robust tab switching: always persist and use font_size from pdata.data_viewer_settings
  if element.name:find("data_viewer_.*_tab") then
    local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    rebuild_data_viewer(player, main_flow, active_tab, font_size)
    return
  end
  -- Unified font size up/down handler
  if element.name == "data_viewer_actions_font_up_btn" or element.name == "data_viewer_actions_font_down_btn" then
    local delta = (element.name == "data_viewer_actions_font_up_btn") and 2 or -2
    update_font_size(player, main_flow, delta)
    return
  end
  -- Refresh button
  if element.name == "data_viewer_tab_actions_refresh_data_btn" then
    local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    rebuild_data_viewer(player, main_flow, active_tab, font_size, true)
    return
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
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local main_flow = get_or_create_gui_flow_from_gui_top(player)
    local pdata = Cache.get_player_data(player)
    pdata.data_viewer_settings = pdata.data_viewer_settings or {}
    
    -- Font size up/down buttons for Data Viewer
    if element.name == "data_viewer_actions_font_up_btn" or element.name == "data_viewer_actions_font_down_btn" then
      local delta = (element.name == "data_viewer_actions_font_up_btn") and 2 or -2
      update_font_size(player, main_flow, delta)
      return
    end
    
    -- Handle close button click in data viewer
    if element.name == "titlebar_close_btn" then
      safe_destroy_frame(main_flow, "data_viewer_frame")
      return
    end
      -- Handle refresh button click in data viewer
    if element.name == "data_viewer_tab_actions_refresh_data_btn" then
      local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
      if not (frame and frame.valid) then return end
      
      local active_tab = find_active_tab_from_gui(main_flow)
      rebuild_data_viewer(player, main_flow, active_tab, nil, true)
      return
    end
    
    -- Handle tab button clicks (robust: always use element.tags.tab_key if present)
    -- Handle opacity up/down
    if element.name == "data_viewer_actions_opacity_up_btn" or element.name == "data_viewer_actions_opacity_down_btn" then
      local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
      if not (frame and frame.valid) then return end
      local pdata = Cache.get_player_data(player)
      local cur_opacity = tonumber(pdata.data_viewer_opacity) or 1.0
      local delta = (element.name == "data_viewer_actions_opacity_up_btn") and 0.1 or -0.1
      local new_opacity = math.max(0.3, math.min(1.0, cur_opacity + delta))
      pdata.data_viewer_opacity = new_opacity
      frame.style.opacity = new_opacity
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
    local main_flow = get_or_create_gui_flow_from_gui_top(player)
    local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
    local tabs_flow = frame and frame.data_viewer_inner_flow and frame.data_viewer_inner_flow.data_viewer_tabs_flow
    if not tabs_flow then return end
    local children = tabs_flow.children
    local focused_idx = 1
    for i, child in ipairs(children) do
      if child.focused then
        focused_idx = i
        break
      end
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
    local main_flow = get_or_create_gui_flow_from_gui_top(player)
    local frame = helpers.find_child_by_name(main_flow, "data_viewer_frame")
    local tabs_flow = frame and frame.data_viewer_inner_flow and frame.data_viewer_inner_flow.data_viewer_tabs_flow
    if not tabs_flow then return end
    local children = tabs_flow.children
    local focused_idx = 1
    for i, child in ipairs(children) do
      if child.focused then
        focused_idx = i
        break
      end
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
  local valid_tabs = { "player_data", "surface_data", "lookup", "all_data" }
  for _, tab in ipairs(valid_tabs) do
    if state and state.active_tab == tab then return tab end
  end
  return valid_tabs[1] -- default to first tab
end

return M
