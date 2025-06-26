--[[
Custom styles for the Data Viewer GUI
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

--- Place all styles below this line---

-- =======================
-- 1. MAIN FRAME
-- =======================

-- Frame style for data_viewer_frame (main container)
gui_style.tf_data_viewer_frame = {
  type = "frame_style",
  parent = "frame",
  width = 1000,
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  minimal_height = 200,
  maximal_height = 1200,
  padding = 0,
  top_margin = 16,
  left_margin = 4,
  left_padding = 12,
  right_padding = 12
}

-- =======================
-- 2. TITLEBAR ELEMENTS
-- =======================

-- Titlebar flow container
gui_style.tf_data_viewer_titlebar_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontal_align = "center",
  vertical_align = "center",
  padding = 4
}

-- Main title label
gui_style.tf_data_viewer_title_label = {
  type = "label_style",
  parent = "frame_title",
  horizontal_align = "center",
  font = "default-bold"
}

-- Spacer between title and close button
gui_style.tf_data_viewer_titlebar_spacer = {
  type = "empty_widget_style",
  parent = "empty_widget",
  horizontally_stretchable = "on"
}

-- Close button (X)
gui_style.tf_data_viewer_close_button = {
  type = "button_style",
  parent = "frame_action_button",
  width = 24,
  height = 24
}

-- =======================
-- 3. TAB ELEMENTS
-- =======================

-- Active tab button style
gui_style.tf_data_viewer_tab_button_active = {
  type = "button_style",
  parent = "green_slot",
  width = 140,
  height = 32,
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 8,
  right_padding = 8,
  margin = 0
}

-- Regular tab button style
gui_style.tf_data_viewer_tab_button = {
  type = "button_style",
  parent = "button",
  width = 140,
  height = 32,
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 8,
  right_padding = 8,
  margin = 0
}

-- Tab button with left margin (for tabs after the first)
gui_style.tf_data_viewer_tab_button_margin = {
  type = "button_style",
  parent = "tf_data_viewer_tab_button",
  left_margin = 4
}

-- Selected tab button (alternative style)
gui_style.tf_data_viewer_tab_button_selected = {
  type = "button_style",
  parent = "tf_data_viewer_tab_button_active",
  default_font_color = { 1, 1, 1 },
  selected_font_color = { 1, 1, 1 },
  minimal_width = 120,
  maximal_width = 200
}

-- =======================
-- 4. ACTIONS/CONTROLS
-- =======================

-- Actions flow (horizontal container for controls)
gui_style.tf_data_viewer_actions_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontal_spacing = 12
}

-- Refresh data button
gui_style.tf_data_viewer_refresh_button = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 4
}

-- Font size controls flow
gui_style.tf_data_viewer_font_size_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontal_spacing = 2
}

-- Font size decrease button (-)
gui_style.tf_data_viewer_font_size_button_minus = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 6,
}

-- Font size increase button (+)
gui_style.tf_data_viewer_font_size_button_plus = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 6,
}

-- Font size refresh button
gui_style.tf_data_viewer_font_size_button_refresh = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 4
}

-- =======================
-- 5. CONTENT AREA
-- =======================

-- Main data table
gui_style.tf_data_viewer_table = {
  type = "table_style",
  parent = "table",
  minimal_width = 400,
  minimal_height = 400,
  top_padding = 8,
  bottom_padding = 16,
  left_padding = 8,
  right_padding = 12
}

-- Odd row labels (white text)
gui_style.data_viewer_row_odd_label = {
  type = "label_style",
  parent = "label",
  font = "default",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  padding = 0,
  margin = 0,
  font_color = { r = 1, g = 1, b = 1 }, -- white text for odd rows
  single_line = false,
  minimal_height = 14                   -- Reduced line height for tighter rows
}

-- Even row labels (dimmer text)
gui_style.data_viewer_row_even_label = {
  type = "label_style",
  parent = "label",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  padding = 0,
  margin = 0,
  font = "default",
  font_color = { r = 0.98, g = 0.66, b = 0.22, a = .5 }, -- slightly dimmer text for even rows
  single_line = false,
  minimal_height = 14                   -- Reduced line height for tighter rows
}

return true
