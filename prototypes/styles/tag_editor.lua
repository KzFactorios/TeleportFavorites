-- local Enum = require("prototypes.enums.enum")

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default
local line_height = 44


--- put all new content below this line ---


-- Tag Editor outer frame style (padding: 2,8,8,8)
gui_style.tf_tag_editor_outer_frame = {
  type = "frame_style",
  parent = "slot_window_frame",
  top_padding = 4,    -- Base vanilla: 4 (8 ÷ 2)
  right_padding = 8,  -- Base vanilla: 8 (16 ÷ 2)
  bottom_padding = 8, -- Base vanilla: 8 (16 ÷ 2)
  left_padding = 8,   -- Base vanilla: 8 (16 ÷ 2)
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  minimal_width = 342, -- Reduced by 16px from 358
  -- Base vanilla: 1080 (2160 ÷ 2)
  maximal_height = 1080
  -- Remove maximal_width constraint to allow stretching
}

-- Tag Editor content frame style (padding: 0, margin: 0)
gui_style.tf_tag_editor_content_frame = {
  type = "frame_style",
  parent = "inside_shallow_frame",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  padding = 0,
  margin = 0,
  bottom_margin = 4
}

-- Frame style for owner row background
gui_style.tf_owner_row_frame = {
  type = "frame_style",
  parent = "frame",
  horizontally_stretchable = "on",
  --horizontal_spacing = 12,  -- Increase spacing between elements
  height = 36,
  padding = 0,
  margin = 0,
  graphical_set = {
    base = {
      -- This creates a solid color background
      center = { position = { 0, 0 }, size = 1, tint = { r = 0.3, g = 0.3, b = 0.3, a = .85 } }
    }
  }
}

-- Tag Editor label style - ensure it takes up available space and is visible
gui_style.tf_tag_editor_owner_label = {
  type = "label_style",
  parent = "label",
  top_padding = 7,
  right_padding = 8,
  bottom_padding = 6,
  left_padding = 8,
  font = "default-bold",
  font_color = { r = 1, g = 1, b = 1, a = 1 }, -- Changed to pure white for better visibility
  horizontally_stretchable = "on",
  width = 292, -- Reduced proportionally for 342px dialog
  single_line = true,
  horizontal_align = "left",
  vertical_align = "center"
}

gui_style.tf_delete_button = {
  type = "button_style",
  parent = "red_button",
  height = 28,
  width = 28,
  padding = 2,
  top_margin = 4,
  right_margin = 4,
  bottom_margin = 0,
  left_margin = 0,
  horizontally_stretchable = "off", -- Explicitly prevent stretching
}

-- Tag Editor content inner frame style (margin: 8,0,0,0; padding: 0,12,0,12)
gui_style.tf_tag_editor_content_inner_frame = {
  type = "frame_style",
  parent = "invisible_frame",
  top_margin = 0,
  right_margin = 0,
  bottom_margin = 0,
  left_margin = 0,
  top_padding = 8,
  right_padding = 8,
  bottom_padding = 8,
  left_padding = 8,
  horizontally_stretchable = "on"
  -- Note: vertical_spacing removed as it's not valid for frame_style
}

-- Tag Editor teleport+favorite row style (vertical_align: center, horizontally_stretchable: on)
gui_style.tf_tag_editor_teleport_favorite_row = {
  type = "frame_style",
  parent = "invisible_frame",
  vertical_align = "center",
  horizontally_stretchable = "on",
  bottom_margin = 8
}

gui_style.tf_teleport_button = {
  type = "button_style",
  parent = "tf_orange_button",
  height = 36, -- exact height
  horizontally_stretchable = "on",
  vertically_stretchable = "off",
  top_margin = 3,
  right_margin = 3,
  left_margin = 9,
  font = "default-large-bold"
}

gui_style.tf_tag_editor_text_input = {
  type = "textbox_style",
  horizontally_stretchable = "on",
  width = 0,
  height = 30,
  top_margin = 5,
  right_margin = 4,
  left_margin = 4,
}

gui_style.tf_tag_editor_last_row = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  top_margin = 4,
  -- Allow vertical stretching for child elements
  top_padding = 0,
  -- Remove padding to let draggable fill completely
  bottom_padding = 0,       -- Remove padding to let draggable fill completely
  left_padding = 0,         -- Keep horizontal padding for button spacing
  right_padding = 0,        -- Keep horizontal padding for button spacing
  horizontal_spacing = 4,   -- Base scale spacing (displays as 8px at 200%)
  --height = 40,  -- Fixed height to match vanilla
  vertical_align = "center" -- Back to center
}

gui_style.tf_tag_editor_last_row_draggable = {
  type = "empty_widget_style",
  parent = "draggable_space", -- Use exact vanilla parent
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  --height = 40, -- Explicitly match the parent row height
  --min_height = 20, -- Ensure it fills the vertical space
  -- No custom width, margins, or padding
  top_margin = 8,
  right_margin = 8,
  left_margin = 0,
  left_padding = 0,
  --right_padding = 8,
}

-- Error row frame style - constrain width, allow vertical stretching
gui_style.tf_tag_editor_error_row_frame = {
  type = "frame_style",
  parent = "inside_deep_frame",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",

  top_padding = 12,
  right_padding = 12,
  bottom_padding = 12,
  left_padding = 12,

  top_margin = 8,
  right_margin = 0,
  bottom_margin = 0,
  left_margin = 0,

  minimal_height = 60, -- Increased minimum height for wrapped text
  minimal_width = 304,
  maximal_width = 314,
  background_graphical_set = {
    base = {
      center = { position = { 0, 0 }, size = 1, tint = { r = 1.0, g = 0.1, b = 0.1, a = 0.8 } }
    }
  }
}

-- Error message label style - wrap text and stretch vertically
-- Used for all error labels in the mod (favorites bar, tag editor, etc.)
gui_style.tf_error_label = {
  type = "label_style",
  parent = "label",
  font = "default-bold",
  font_color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  single_line = false,
  minimal_width = 264,
  minimal_height = 54
}

-- Existing tag editor error label style (for backward compatibility)
gui_style.tf_tag_editor_error_label = {
  type = "label_style",
  parent = "label",
  font = "default-bold",
  font_color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  single_line = false,
  minimal_width = 264,
  minimal_height = 54
}

-- Confirm dialog frame style (for modal confirm/cancel)
gui_style.tf_confirm_dialog_frame = {
  type = "frame_style",
  parent = "inside_shallow_frame_with_padding",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  horizontal_align = "center",
  minimal_width = 360,
  maximal_width = 360,
  top_padding = 16,
  right_padding = 32,
  bottom_padding = 16,
  left_padding = 32,
}

gui_style.tf_dlg_confirm_title = {
  type = "label_style",
  parent = "frame_title",
  font = "heading-1", -- Use idiomatic Factorio dialog title font
  horizontally_stretchable = "on",
  horizontal_align = "center",
  single_line = false,
  width = 0
}

gui_style.tf_confirm_dialog_btn_row = {
  type = "horizontal_flow_style",
  horizontally_stretchable = "on",
  horizontal_spacing = 0,
  top_margin = 32,
  left_margin = 16,
  right_margin = 16,
}

-- Confirm button style (large, green, right-aligned)
gui_style.tf_dlg_confirm_button = {
  type = "button_style",
  parent = "confirm_button",
}

return true
