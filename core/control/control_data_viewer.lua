---@diagnostic disable: undefined-global

-- control_data_viewer.lua
-- Handles data viewer GUI events for TeleportFavorites

local data_viewer = require("gui.data_viewer.data_viewer")
local Cache = require("core.cache.cache")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local ErrorHandler = require("core.utils.error_handler")
local PositionUtils = require("core.utils.position_utils")
local SharedUtils = require("core.control.control_shared_utils")


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
    ErrorHandler.debug_log("Data viewer loading player data", {
      player_name = player.name,
      data_nil = state.data == nil,
      data_type = type(state.data),
      data_count = state.data and (type(state.data) == "table" and SharedUtils.table_size(state.data) or "not table") or "nil"
    })
  elseif active_tab == "surface_data" then
    state.data = Cache.get_surface_data(player.surface.index)
    state.top_key = "surface_data"
    ErrorHandler.debug_log("Data viewer loading surface data", {
      surface_index = player.surface.index,
      data_nil = state.data == nil,
      data_type = type(state.data),
      data_count = state.data and (type(state.data) == "table" and SharedUtils.table_size(state.data) or "not table") or "nil"
    })
  elseif active_tab == "lookup" then
    -- Initialize Cache first to ensure Lookups is available
    Cache.init()
    -- Create a safe view of GPS mapping data for display
    local gps_mapping_data = {}
    for _, surface in pairs(game.surfaces) do
      if surface and surface.valid then
        local surface_index = surface.index
        -- Build GPS mapping data
        local gps_mapping = Cache.Lookups.get_gps_mapping_for_surface(surface_index)
        if gps_mapping and next(gps_mapping) then
          gps_mapping_data["surface_" .. surface_index] = {}
          for gps, chart_tag in pairs(gps_mapping) do
            if chart_tag and chart_tag.valid then
              -- Create a safe serializable representation
              local safe_chart_tag = {
                position = chart_tag.position and PositionUtils.normalize_if_needed(chart_tag.position) or {},
                text = tostring(chart_tag.text or ""),
                icon = chart_tag.icon and {
                  name = tostring(chart_tag.icon.name or ""),
                  type = tostring(chart_tag.icon.type or "")
                } or {},
                last_user = chart_tag.last_user and chart_tag.last_user.name or "",
                surface_name = chart_tag.surface and tostring(chart_tag.surface.name) or "unknown",
                valid = chart_tag.valid
              }
              gps_mapping_data["surface_" .. surface_index][gps] = safe_chart_tag
            end
          end
        end
      end
    end
    state.data = {
      chart_tags_mapped_by_gps = gps_mapping_data,
      cache_status = next(gps_mapping_data) and "populated" or "empty"
    }
    state.top_key = "lookups"
    ErrorHandler.debug_log("Data viewer loading lookup data", {
      gps_mapping_count = SharedUtils.table_size(gps_mapping_data),
      cache_status = state.data.cache_status
    })
  elseif active_tab == "all_data" then
    state.data = storage
    state.top_key = "all_data"
    local storage_count = storage and (type(storage) == "table" and SharedUtils.table_size(storage) or "not table") or "nil"
    ErrorHandler.debug_log("Data viewer loading all data", {
      storage_type = type(storage),
      storage_count = storage_count
    })
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
  SharedUtils.refresh_gui_with_cache(
    function() end, -- No cache setter needed for data viewer
    function(_, mf) GuiValidation.safe_destroy_frame(mf, "data_viewer_frame") end,
    function(p, mf, st) data_viewer.build(p, mf, st) end,
    player, main_flow, load_tab_data(player, active_tab, font_size)
  )
  if show_flying_text then
    data_viewer.show_refresh_notification(player)
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
  
  -- Use partial update instead of full rebuild for font size changes
  data_viewer.update_font_size(player, new_size)
end

function M.on_toggle_data_viewer(event)
  ErrorHandler.debug_log("Data viewer toggle called", {
    player_index = event.player_index,
    event_name = event.input_name or "unknown"
  })
  
  local player = game.get_player(event.player_index)
  if not player or not player.valid then 
    ErrorHandler.debug_log("Data viewer toggle failed: invalid player", {
      player_index = event.player_index
    })
    return 
  end
  
  ErrorHandler.debug_log("Data viewer toggle getting main flow", {
    player_name = player.name
  })
  
  local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow then
    ErrorHandler.debug_log("Data viewer toggle failed: no main flow")
    return
  end
  
  ErrorHandler.debug_log("Data viewer toggle checking existing frame", {
    main_flow_valid = main_flow.valid
  })
  
  local frame = GuiValidation.find_child_by_name(main_flow, "data_viewer_frame")
  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
  local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
  local font_size = pdata.data_viewer_settings.font_size or 12
  
  ErrorHandler.debug_log("Data viewer toggle frame check", {
    frame_exists = frame ~= nil,
    frame_valid = frame and frame.valid or false,
    active_tab = active_tab,
    font_size = font_size
  })
  
  if frame and frame.valid ~= false then
    ErrorHandler.debug_log("Data viewer toggle closing existing frame")
    GuiValidation.safe_destroy_frame(main_flow, "data_viewer_frame")
  else
    ErrorHandler.debug_log("Data viewer toggle building new frame")
    rebuild_data_viewer(player, main_flow, active_tab, font_size)
  end
  
  ErrorHandler.debug_log("Data viewer toggle completed")
end

--- Handle GUI click events for data viewer elements
--- Called by gui_event_dispatcher when parent GUI is DATA_VIEWER
---@param event table GUI click event data
function M.on_data_viewer_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
  local pdata = Cache.get_player_data(player)
  pdata.data_viewer_settings = pdata.data_viewer_settings or {}
  
  -- Font size up/down buttons for Data Viewer
  if element.name == "data_viewer_actions_font_up_btn" or element.name == "data_viewer_actions_font_down_btn" then
    local delta = (element.name == "data_viewer_actions_font_up_btn") and 2 or -2
    update_font_size(player, main_flow, delta)
    return
  end
  -- Handle close button click in data viewer
  if element.name == "data_viewer_close_btn" then      
    GuiValidation.safe_destroy_frame(main_flow, "data_viewer_frame")
    return
  end
  
  -- Handle tab button clicks to switch data views
  if element.name == "data_viewer_player_data_tab" then
    pdata.data_viewer_settings.active_tab = "player_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    data_viewer.update_tab_selection(player, "player_data")
    local state = load_tab_data(player, "player_data", font_size)
    data_viewer.update_content_panel(player, state.data, font_size, state.top_key)
    return
  elseif element.name == "data_viewer_surface_data_tab" then
    pdata.data_viewer_settings.active_tab = "surface_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    data_viewer.update_tab_selection(player, "surface_data")
    local state = load_tab_data(player, "surface_data", font_size)
    data_viewer.update_content_panel(player, state.data, font_size, state.top_key)
    return
  elseif element.name == "data_viewer_lookup_tab" then
    pdata.data_viewer_settings.active_tab = "lookup"
    local font_size = pdata.data_viewer_settings.font_size or 12
    data_viewer.update_tab_selection(player, "lookup")
    local state = load_tab_data(player, "lookup", font_size)
    data_viewer.update_content_panel(player, state.data, font_size, state.top_key)
    return
  elseif element.name == "data_viewer_all_data_tab" then
    pdata.data_viewer_settings.active_tab = "all_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    data_viewer.update_tab_selection(player, "all_data")
    local state = load_tab_data(player, "all_data", font_size)
    data_viewer.update_content_panel(player, state.data, font_size, state.top_key)
    return
  end
    -- Handle refresh button click in data viewer
  if element.name == "data_viewer_tab_actions_refresh_data_btn" then
    local frame = GuiValidation.find_child_by_name(main_flow, "data_viewer_frame")
    if not (frame and frame.valid) then return end
    
    -- Use the stored active tab instead of trying to detect from GUI
    local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    
    -- Use partial update instead of full rebuild for refresh
    local state = load_tab_data(player, active_tab, font_size)
    data_viewer.update_content_panel(player, state.data, font_size, state.top_key)
    data_viewer.show_refresh_notification(player)
    -- Notify observers of data refresh
    SharedUtils.notify_observer("data_refreshed", {
      player = player,
      type = "data_refreshed",
      tab = active_tab
    })
    return
  end
end

--- Register data viewer event handlers
--- @param script table The Factorio script object
function M.register(script)
  -- NOTE: GUI click events are now handled by gui_event_dispatcher via M.on_data_viewer_gui_click
  -- NOTE: dv-toggle-data-viewer custom input is handled by custom_input_dispatcher
  -- Only specialized keyboard navigation events are registered here
  
  -- Keyboard navigation for tabs (tab/shift-tab) using custom inputs
  script.on_event("tf-data-viewer-tab-next", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
    local frame = GuiValidation.find_child_by_name(main_flow, "data_viewer_frame")
    if not frame then return end
    
    -- Access the correct GUI structure: frame.data_viewer_inner_flow.data_viewer_tabs_flow
    ---@diagnostic disable-next-line: undefined-field
    local inner_flow = frame.data_viewer_inner_flow
    if not inner_flow then return end
    
    local tabs_flow = inner_flow.data_viewer_tabs_flow
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
    local main_flow = GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
    local frame = GuiValidation.find_child_by_name(main_flow, "data_viewer_frame")
    if not frame then return end
    
    -- Access the correct GUI structure: frame.data_viewer_inner_flow.data_viewer_tabs_flow
    ---@diagnostic disable-next-line: undefined-field
    local inner_flow = frame.data_viewer_inner_flow
    if not inner_flow then return end
    
    local tabs_flow = inner_flow.data_viewer_tabs_flow
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

-- Export functions for testing
M.load_tab_data = load_tab_data
M.rebuild_data_viewer = rebuild_data_viewer

return M
