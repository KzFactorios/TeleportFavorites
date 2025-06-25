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
  local titlebar = parent.add{
    type = "flow",
    name = "data_viewer_titlebar",
    direction = "horizontal",
    style = "tf_data_viewer_titlebar_flow"
  }
  
  -- Title label
  titlebar.add{
    type = "label",
    caption = "TeleportFavorites Data Viewer",
    style = "tf_data_viewer_title_label"
  }
  
  -- Spacer
  local spacer = titlebar.add{
    type = "empty-widget",
    style = "tf_data_viewer_titlebar_spacer"
  }
  -- Note: horizontally_stretchable cannot be set directly on style
  
  -- Close button
  titlebar.add{
    type = "sprite-button",
    name = "data_viewer_close_button",
    sprite = "utility/close_white",
    style = "tf_data_viewer_close_button",
    tooltip = "Close Data Viewer"
  }
  
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
    {name = "cache_data", caption = "Cache Data", tooltip = "View global cache data"},
    {name = "global_data", caption = "Global Data", tooltip = "View global game data"}
  }
  
  -- Create tab buttons
  for _, tab in ipairs(tabs) do
    local style = (tab.name == active_tab) 
      and "tf_data_viewer_tab_button_selected" 
      or "tf_data_viewer_tab_button"
    
    tabs_flow.add{
      type = "button",
      name = "data_viewer_tab_" .. tab.name,
      caption = tab.caption,
      tooltip = tab.tooltip,
      style = style
    }
  end
  
  -- Font size controls
  local font_controls = tabs_flow.add{
    type = "flow",
    name = "font_size_controls",
    direction = "horizontal"
  }
  -- Note: left_margin cannot be set directly on style
  
  font_controls.add{type = "label", caption = "Font Size:"}
  
  font_controls.add{
    type = "button",
    name = "data_viewer_font_smaller",
    caption = "-",
    style = "tf_small_button",
    tooltip = "Decrease font size"
  }
  
  font_controls.add{
    type = "button", 
    name = "data_viewer_font_larger",
    caption = "+",
    style = "tf_small_button",
    tooltip = "Increase font size"
  }
  
  -- Refresh button
  tabs_flow.add{
    type = "button",
    name = "data_viewer_refresh",
    caption = "Refresh",
    style = "tf_data_viewer_refresh_button",
    tooltip = "Refresh data display"
  }
  
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
  
  local set_label_font = require("gui.data_viewer.data_viewer").set_label_font
  
  ErrorHandler.debug_log("Data viewer showing empty data structure", {
    top_key = top_key,
    font_size = font_size
  })

  local style = "data_viewer_row_odd_label"
  local lbl = GuiBase.create_label(data_table, "data_top_key_empty", top_key .. " = {", style)
  set_label_font(lbl, font_size)
  
  local lbl2 = GuiBase.create_label(data_table, "data_closing_brace_empty", "}", "data_viewer_row_even_label")
  set_label_font(lbl2, font_size)
end

return DataViewerGuiBuilders
