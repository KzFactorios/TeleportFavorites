---@diagnostic disable: undefined-global
--[[
gui/data_viewer/data_viewer_gui_builders.lua
TeleportFavorites Factorio Mod
-----------------------------
Helper functions for data viewer GUI construction, extracted from data_viewer.lua.

This module contains functions for:
- Building the main data viewer frame
- Creating titlebar and tabs
- Building data tables and content areas
- Handling empty data display

These functions were extracted from large GUI builder methods to improve
maintainability and reduce function complexity.
]]

local GuiBase = require("gui.gui_base")
local GuiUtils = require("core.utils.gui_utils")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")

---@class DataViewerGuiBuilders
local DataViewerGuiBuilders = {}

--- Build the main data viewer frame structure
---@param parent LuaGuiElement Parent element to attach frame to
---@param state table Data viewer state containing configuration
---@param player LuaPlayer Player who owns the GUI
---@return LuaGuiElement? frame Main frame element
function DataViewerGuiBuilders.build_main_frame(parent, state, player)
  if not (state and parent and player) then
    ErrorHandler.debug_log("Data viewer frame build failed: missing requirements", {
      has_state = state ~= nil,
      has_parent = parent ~= nil,
      has_player = player ~= nil
    })
    return nil
  end

  -- Main dialog frame (resizable)
  local frame = GuiBase.create_frame(parent, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER, "vertical", "tf_data_viewer_frame")
  -- Leave caption empty for now
  
  ErrorHandler.debug_log("Data viewer main frame created", {
    player_name = player.name,
    frame_name = frame.name
  })
  
  return frame
end

--- Build the titlebar for the data viewer
---@param parent LuaGuiElement Frame to add titlebar to
---@return LuaGuiElement titlebar Titlebar element
function DataViewerGuiBuilders.build_titlebar(parent)
  local titlebar = GuiBase.create_hflow(parent, "data_viewer_titlebar", "tf_data_viewer_titlebar_flow")
  
  -- Title label
  GuiBase.create_label(titlebar, "data_viewer_title", "TeleportFavorites Data Viewer", "tf_data_viewer_title_label")
  
  -- Spacer
  GuiBase.create_element("empty-widget", titlebar, {
    name = "data_viewer_titlebar_spacer",
    style = "tf_data_viewer_titlebar_spacer"
  })
  
  -- Close button
  GuiBase.create_element("sprite-button", titlebar, {
    name = "data_viewer_close_btn",
    sprite = Enum.SpriteEnum.CLOSE,
    style = "tf_data_viewer_close_button",
    tooltip = "Close Data Viewer"
  })
  
  return titlebar
end

--- Build the tabs row for data viewer sections
---@param parent LuaGuiElement Element to add tabs to
---@param active_tab string Currently active tab name
---@return LuaGuiElement tabs_flow Tabs container element
function DataViewerGuiBuilders.build_tabs_row(parent, active_tab)
  local tabs_flow = GuiBase.create_hflow(parent, "data_viewer_tabs_flow")
  
  -- Define available tabs
  local tabs = {
    {name = "player_data", caption = "Player Data", tooltip = "View player-specific data"},
    {name = "surface_data", caption = "Surface Data", tooltip = "View surface-specific data"},
    {name = "lookup", caption = "Lookup Data", tooltip = "View GPS mapping and lookup data"},
    {name = "all_data", caption = "All Data", tooltip = "View complete storage data"}
  }
  
  -- Create tab buttons
  for _, tab in ipairs(tabs) do
    local style = (tab.name == active_tab) 
      and "tf_data_viewer_tab_button_selected" 
      or "tf_data_viewer_tab_button"
    
    GuiBase.create_element("button", tabs_flow, {
      name = "data_viewer_" .. tab.name .. "_tab",
      caption = tab.caption,
      tooltip = tab.tooltip,
      style = style
    })
  end
  
  -- Font size controls
  local font_controls = GuiBase.create_hflow(tabs_flow, "font_size_controls")
  
  GuiBase.create_label(font_controls, "font_size_label", "Font Size:")
  
  GuiBase.create_element("button", font_controls, {
    name = "data_viewer_actions_font_down_btn",
    caption = "-",
    style = "tf_data_viewer_font_size_button_minus",
    tooltip = "Decrease font size"
  })
  
  GuiBase.create_element("button", font_controls, {
    name = "data_viewer_actions_font_up_btn",
    caption = "+",
    style = "tf_data_viewer_font_size_button_plus",
    tooltip = "Increase font size"
  })
  
  -- Refresh button
  GuiBase.create_element("sprite-button", tabs_flow, {
    name = "data_viewer_tab_actions_refresh_data_btn",
    sprite = Enum.SpriteEnum.REFRESH,
    style = "tf_data_viewer_refresh_button",
    tooltip = "Refresh data display"
  })
  
  return tabs_flow
end

--- Create content area with data table
---@param parent LuaGuiElement Element to add content area to
---@return LuaGuiElement content_flow Content container
---@return LuaGuiElement data_table Data table element  
function DataViewerGuiBuilders.build_content_area(parent)
  -- Content area: vertical flow, then table
  local content_flow = GuiBase.create_vflow(parent, "data_viewer_content_flow")

  -- Table for data rows (single column for compactness)
  local data_table = GuiBase.create_element("table", content_flow, {
    name = "data_viewer_table",
    column_count = 1,
    style = "tf_data_viewer_table"
  })
  
  return content_flow, data_table
end

--- Display empty data structure with proper formatting
---@param data_table LuaGuiElement Table to add empty data display to
---@param top_key string Key name to display
---@param font_size number Font size to use
function DataViewerGuiBuilders.display_empty_data(data_table, top_key, font_size)
  if not top_key then top_key = "player_data" end
  
  ErrorHandler.debug_log("Data viewer showing empty data structure", {
    top_key = top_key,
    font_size = font_size
  })

  local style = "data_viewer_row_odd_label"
  local lbl = GuiBase.create_label(data_table, "data_top_key_empty", top_key .. " = {", style)
  -- Simple font setting without circular dependency
  if font_size and font_size > 0 then
    local font_name = "tf_font_" .. tostring(font_size)
    pcall(function() lbl.style.font = font_name end)
  end
  
  local lbl2 = GuiBase.create_label(data_table, "data_closing_brace_empty", "}", "data_viewer_row_even_label")
  if font_size and font_size > 0 then
    local font_name = "tf_font_" .. tostring(font_size)
    pcall(function() lbl2.style.font = font_name end)
  end
end

return DataViewerGuiBuilders
