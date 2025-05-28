--[[
TeleportFavorites Factorio Mod - Data Viewer GUI
------------------------------------------------
Module: gui/data_viewer/data_viewer.lua

Provides the Data Viewer GUI for inspecting player, surface, lookup, and global data.
- Displays structured data in a scrollable, tabbed interface for debugging and inspection.
- Supports dynamic font size and opacity controls, and tab switching for different data scopes.
- Uses shared GUI helpers from gui_base.lua for consistent UI construction.
- Handles robust error feedback if player data is missing.

Functions:
- data_viewer.build(player, parent, state):
    Constructs the Data Viewer GUI for the given player, parent element, and state.
    Handles tab selection, control buttons, and data rendering for each tab.
    Returns the created frame element.

--]]

local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Cache = require("core.cache.cache")
local Lookups = require("core.cache.lookups")
local Helpers = require("core.utils.helpers_suite")

local data_viewer = {}

local function build_titlebar(parent)
  local flow = GuiBase.create_hflow(parent, "data_viewer_titlebar_flow")
  GuiBase.create_label(flow, "data_viewer_title_label", {"tf-gui.data_viewer_title"}, "frame_title")
  local filler = flow.add{type="empty-widget", name="data_viewer_titlebar_filler", style="draggable_space_header"}
  filler.style.horizontally_stretchable = true
  local close_btn = Helpers.create_slot_button(flow, "data_viewer_close_btn", "utility/close_white", {"tf-gui.close_tooltip"})
  return flow, close_btn
end

local function build_tabs_row(parent, active_tab)
  local tabs_flow = GuiBase.create_hflow(parent, "data_viewer_tabs_flow")
  local tab_defs = {
    {"data_viewer_player_data_tab", "tf-gui.tab_player_data"},
    {"data_viewer_surface_data_tab", "tf-gui.tab_surface_data"},
    {"data_viewer_lookup_tab", "tf-gui.tab_lookups"},
    {"data_viewer_all_data_tab", "tf-gui.tab_all_data"}
  }
  for _, def in ipairs(tab_defs) do
    local btn = GuiBase.create_icon_button(tabs_flow, def[1], "utility/tab_icon", {def[2]}, "tf_slot_button")
    if active_tab and btn.name:find(active_tab) then btn.style.font_color = {r=1,g=0.8,b=0.2} end
  end
  return tabs_flow
end

local function build_tab_actions_row(parent)
  local actions_flow = GuiBase.create_hflow(parent, "data_viewer_tab_actions_flow")
  -- Font size controls
  local font_size_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_font_size_flow")
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_down_btn", "utility/remove", {"tf-gui.font_minus_tooltip"})
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_up_btn", "utility/add", {"tf-gui.font_plus_tooltip"})
  -- Opacity controls
  local opacity_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_opacity_flow")
  Helpers.create_slot_button(opacity_flow, "data_viewer_actions_opacity_down_btn", "utility/remove", {"tf-gui.opacity_down_tooltip"})
  Helpers.create_slot_button(opacity_flow, "data_viewer_actions_opacity_up_btn", "utility/add", {"tf-gui.opacity_up_tooltip"})
  -- Refresh button
  Helpers.create_slot_button(actions_flow, "data_viewer_tab_actions_refresh_data_btn", "utility/refresh", {"tf-gui.refresh_tooltip"})
  return actions_flow
end

local function build_content_flow(parent)
  local content_flow = GuiBase.create_vflow(parent, "data_viewer_content_flow")
  local table_elem = content_flow.add{type="table", name="data_viewer_table", column_count=2}
  return content_flow, table_elem
end

local function fill_data_table(table_elem, data)
  local row = 1
  for k, v in pairs(data) do
    table_elem.add{type="label", name="data_viewer_row_"..row.."_label", caption=tostring(k)}
    table_elem.add{type="label", name="data_viewer_row_"..row.."_value", caption=tostring(v)}
    row = row + 1
  end
end

function data_viewer.build(player, parent, state)
  local s = state or {}
  local frame = GuiBase.create_frame(parent, "data_viewer_frame", "vertical", "inside_shallow_frame_with_padding")
  frame.style.width = 1000
  frame.style.vertically_stretchable = true
  local inner_flow = GuiBase.create_vflow(frame, "data_viewer_inner_flow")
  local titlebar_flow, close_btn = build_titlebar(inner_flow)
  local tabs_flow = build_tabs_row(inner_flow, s.active_tab)
  local tab_actions_flow = build_tab_actions_row(tabs_flow)
  local content_flow, table_elem = build_content_flow(inner_flow)
  -- Example: fill table with dummy data (replace with real data logic)
  fill_data_table(table_elem, s.data or {foo="bar", baz=42})
  return frame
end

return data_viewer
