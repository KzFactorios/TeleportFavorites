---@diagnostic disable: undefined-global

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

-- Styles for the sprite debugger component

-- Scroll pane for sprite viewer
gui_style.tf_sprite_viewer_scroll_pane = {
  type = "scroll_pane_style",
  parent = "scroll_pane",
  padding = 4,
  maximal_height = 600
}

-- Section title style
gui_style.tf_sprite_viewer_section_title = {
  type = "label_style",
  parent = "caption_label", -- Changed from "heading_2_label" to standard Factorio style
  top_margin = 8,
  bottom_margin = 4
}

-- Sprite info style
gui_style.tf_sprite_info_label = {
  type = "label_style",
  parent = "label",
  font = "default-small",
  single_line = false
}

-- Sprite sample cell style 
gui_style.tf_sprite_sample_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontal_spacing = 8,
  vertical_align = "center",
  margin = 4
}

-- Sprite sample label 
gui_style.tf_sprite_sample_label = {
  type = "label_style",
  parent = "label",
  width = 240,
  font = "default-small",
  single_line = true
}

-- Sprite position info
gui_style.tf_sprite_position_label = {
  type = "label_style",
  parent = "label",
  width = 120,
  font = "default-small",
  single_line = true
}

-- Coordinates label
gui_style.tf_sprite_coords_label = {
  type = "label_style",
  parent = "label",
  width = 80,
  font = "default-small",
  single_line = true
}

-- Container for sprite test display
gui_style.tf_sprite_test_container = {
  type = "frame_style",
  parent = "deep_frame_in_shallow_frame",
  horizontal_align = "center",
  horizontally_stretchable = "on",
  padding = 8,
  width = 420
}

return true
