---@diagnostic disable: undefined-global
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

-- Dark background frame for sprites
gui_style.tf_sprite_dark_frame = {
  type = "frame_style",
  parent = "inside_deep_frame", -- Changed from "deep_frame" to "inside_deep_frame" which exists in Factorio
  background_graphical_set = {
    base = {
      position = {282, 17},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  padding = 0
}

-- Checkerboard background table
gui_style.tf_checkerboard_table = {
  type = "table_style",
  parent = "table",
  cell_padding = 0,
  horizontal_spacing = 0,
  vertical_spacing = 0
}

-- Checkerboard dark cell
gui_style.tf_checkerboard_dark = {
  type = "empty_widget_style",
  parent = "empty_widget",
  size = 20,
  graphical_set = {
    base = {
      position = {0, 0},
      size = 1,
      tint = {r = 0.2, g = 0.2, b = 0.2, a = 1}
    }
  }
}

-- Checkerboard light cell
gui_style.tf_checkerboard_light = {
  type = "empty_widget_style",
  parent = "empty_widget",
  size = 20,
  graphical_set = {
    base = {
      position = {0, 0},
      size = 1,
      tint = {r = 0.5, g = 0.5, b = 0.5, a = 1}
    }
  }
}

return true
