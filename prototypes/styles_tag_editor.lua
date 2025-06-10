---@diagnostic disable: undefined-global

--- Leaving this here to demonstrate that it will not work here due to lifecycle
-- local Enum = require("prototypes.enums.enum")

local gui_style = data.raw["gui-style"].default
local line_height = 44


--- put all new content below this line ---


-- Tag Editor outer frame style (padding: 2,8,8,8)
if not gui_style.tf_tag_editor_outer_frame then
  gui_style.tf_tag_editor_outer_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    top_padding = 4,
    right_padding = 8,
    bottom_padding = 8,
    left_padding = 8,
    horizontally_stretchable = "on",
    minimal_width = 358
    -- Remove maximal_width constraint to allow stretching
  }
end

-- Tag Editor content frame style (padding: 0, margin: 0)
if not gui_style.tf_tag_editor_content_frame then
  gui_style.tf_tag_editor_content_frame = {
    type = "frame_style",
    parent = "inside_shallow_frame",
    horizontally_stretchable = "on",
    padding = 0,
    margin = 0,
    bottom_margin = 4
  }
end

-- Frame style for owner row background
if not gui_style.tf_owner_row_frame then
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
end

-- Tag Editor label style - ensure it takes up available space and is visible
if not gui_style.tf_tag_editor_owner_label then
  gui_style.tf_tag_editor_owner_label = {
    type = "label_style",
    parent = "label",
    top_padding = 7,
    right_padding = 8,
    bottom_padding = 6,
    left_padding = 8,
    font = "default-bold",
    font_color = { r = 1, g = .9, b = .75, a = 1 },
    horizontally_stretchable = "on",
    minimal_width = 200,
    natural_width = 280, -- Slightly reduced to ensure buttons have space
    width = 280,         -- Set explicit width to force it to take space
    single_line = true,
    horizontal_align = "left",
    vertical_align = "center"
  }
end

-- We no longer need the tf_owner_right_flow style as we're using a simpler layout

if not gui_style.tf_move_button then
  gui_style.tf_move_button = {
    type = "button_style",
    parent = "button",
    height = 28,
    width = 28,
    padding = 1,
    top_margin = 4,
    right_margin = 4,                 -- Tighter margin
    horizontally_stretchable = "off", -- Explicitly prevent stretching
  }
end

if not gui_style.tf_delete_button then
  gui_style.tf_delete_button = {
    type = "button_style",
    parent = "red_button",
    height = 28,
    width = 28,
    padding = 2,
    top_margin = 4,
    right_margin = 4,
    horizontally_stretchable = "off", -- Explicitly prevent stretching
  }
end

-- Tag Editor content inner frame style (margin: 8,0,0,0; padding: 0,12,0,12)
if not gui_style.tf_tag_editor_content_inner_frame then
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
    horizontally_stretchable = "on",
    vertical_spacing = 8
  }
end

-- Tag Editor teleport+favorite row style (vertical_align: center, horizontally_stretchable: on)
if not gui_style.tf_tag_editor_teleport_favorite_row then
  gui_style.tf_tag_editor_teleport_favorite_row = {
    type = "frame_style",
    parent = "invisible_frame",
    vertical_align = "center",
    horizontally_stretchable = "on",
    bottom_margin = 8
  }
end

if not gui_style.tf_teleport_button then
  gui_style.tf_teleport_button = {
    type = "button_style",
    parent = "tf_orange_button",
    width = 0,
    maximal_width = 400,
    height = 28,                     -- exact height
    horizontally_stretchable = "on", -- do not stretch
    vertically_stretchable = "off",  -- do not stretch
    top_margin = 7,
    right_margin = 3,
    left_margin = 9,
  }
end

if not gui_style.tf_tag_editor_rich_text_row then
  gui_style.tf_tag_editor_rich_text_row = {
    type = "frame_style",
    parent = "invisible_frame",
    vertical_align = "center",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    width = 0,
    maximal_width = 400
  }
end

if not gui_style.tf_tag_editor_text_input then
  gui_style.tf_tag_editor_text_input = {
    type = "textbox_style",
    horizontally_stretchable = "on",
    width = 0,
    top_margin = 6,
    right_margin = 4,
    left_margin = 4,
    --right_padding = 2
  }
end

if not gui_style.tf_tag_editor_last_row then
  gui_style.tf_tag_editor_last_row = {
    type = "frame_style",
    parent = "invisible_frame",
    vertical_align = "center",
    horizontally_stretchable = "on",
    width = 0,
    --maximal_width = 400,
    top_margin = 4
  }
end

if not gui_style.tf_tag_editor_last_row_draggable then
  gui_style.tf_tag_editor_last_row_draggable = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on",
    left_margin = 0,
    right_margin = 12,
    minimal_width = 8,
    height = 40
  }
end

-- Confirm button style (large, green, right-aligned)
if not gui_style.tf_confirm_button then
  gui_style.tf_confirm_button = {
    type = "button_style",
    parent = "confirm_button",
    top_margin = 4,
  }
end

return true
