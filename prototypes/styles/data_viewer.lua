--[[
Custom styles for the Data Viewer GUI
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

--- Place all styles below this line---


-- Frame style for data_viewer_frame (make resizable)
gui_style.tf_data_viewer_frame = {
  type = "frame_style",
  parent = "frame",
  width = 1000,
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  --minimal_width = 600,
  --maximal_width = 2000,
  minimal_height = 200,
  maximal_height = 1200,
  padding = 0,
  top_margin = 16,
  left_margin = 4,
  left_padding = 12,
  right_padding = 12
}

-- Data Viewer active tab button style (matches size of inactive tabs, uses frame_action_button color)
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

-- Data Viewer tab button style (width: 140, height: 32, padding: 0/8, margin: 0, left_margin: 4 for i>1)
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
  -- left_margin for i>1 must be set by using a separate style or handled in code
}

-- Data Viewer table style
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

-- Data Viewer tab button style with left margin (for i > 1)
gui_style.tf_data_viewer_tab_button_margin = {
  type = "button_style",
  parent = "tf_data_viewer_tab_button",
  left_margin = 4
}

-- Data Viewer actions flow style (vertical_align = center, horizontal_spacing = 12)
gui_style.tf_data_viewer_actions_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontal_spacing = 12
}

-- Data Viewer font size flow style (vertical_align = center, horizontal_spacing = 2)
gui_style.tf_data_viewer_font_size_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontal_spacing = 2
}

gui_style.tf_data_viewer_font_size_button_minus = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 6,
  scale = 0.7
}

gui_style.tf_data_viewer_font_size_button_plus = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 6,
  scale = 0.7
}

gui_style.tf_data_viewer_font_size_button_refresh = {
  type = "button_style",
  parent = "tf_slot_button",
  width = 32,
  height = 32,
  padding = 4
}

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
