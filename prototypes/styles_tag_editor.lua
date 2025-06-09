---@diagnostic disable: undefined-global

--- Leaving this here to demonstrate that it will not work here due to lifecycle
-- local Enum = require("prototypes.enum")

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
    width = 359
  }
end

-- Custom style for last user label with blue background
if not gui_style.tf_owner_row then
  gui_style.tf_owner_row = {
    type = "frame_style",
    parent = "frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    graphical_set = {
      base = {
        -- This creates a solid color background
        center = { position = { 0, 0 }, size = 1, tint = { r = 0.3, g = 0.3, b = 0.3, a = .85 } }
      }
    },
    -- Removed height to allow full stretching
    -- Removed margin and padding for testing
    height = nil,
    margin = nil,
    top_padding = nil,
    bottom_padding = nil,
    left_padding = nil,
    right_padding = nil,
  }
end

if not gui_style.tf_owner_left_flow then
  gui_style.tf_owner_left_flow = {
    type = "horizontal_flow_style",
    horizontally_stretchable = "on",
  }
end

if not gui_style.tf_owner_right_flow then
  gui_style.tf_owner_right_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontal_align = "right",
    vertical_align = "center",
  }
end

-- Tag Editor label style (padding: 8,12,4,16; bold font)
if not gui_style.tf_tag_editor_owner_label then
  gui_style.tf_tag_editor_owner_label = {
    type = "label_style",
    parent = "label",
    top_padding = 8,
    right_padding = 8,
    bottom_padding = 4,
    left_padding = 8,
    font = "default-bold",
    font_color = { r = 1, g = .9, b = .75, a = 1 },
    horizontally_stretchable = "on",
    right_margin = 4,
    left_margin = 6
  }
end


if not gui_style.tf_move_button then
  gui_style.tf_move_button = {
    type = "button_style",
    parent = "button",
    height = 28,
    width = 28,
    padding = 3,
    top_margin = 3,
    right_margin = 4
  }
end

if not gui_style.tf_delete_button then
  gui_style.tf_delete_button = {
    type = "button_style",
    parent = "red_button",
    height = 28,
    width = 28,
    padding = 0,
    top_margin = 3,
    right_margin = 8
  }
end


-- Tag Editor content frame style (padding: 0, margin: 0)
if not gui_style.tf_tag_editor_content_frame then
  gui_style.tf_tag_editor_content_frame = {
    type = "frame_style",
    parent = "inside_shallow_frame",
    padding = 0,
    margin = 0
  }
end

-- Tag Editor content inner frame style (margin: 8,0,0,0; padding: 0,12,0,12)
if not gui_style.tf_tag_editor_content_inner_frame then
  gui_style.tf_tag_editor_content_inner_frame = {
    type = "frame_style",
    parent = "invisible_frame",
    top_margin = 8,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    top_padding = 0,
    right_padding = 8,
    bottom_padding = 0,
    left_padding = 8,
    horizontally_stretchable = "on",
  }
end

if not gui_style.tf_tag_editor_rich_text_row then
  gui_style.tf_tag_editor_rich_text_row = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertical_align = "center",
    horizontally_stretchable = "on",
    height = line_height
  }
end

if not gui_style.tf_tag_editor_last_row then
  gui_style.tf_tag_editor_last_row = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertical_align = "center",
    horizontal_align = "right",
    horizontally_stretchable = "on",
    width = 400,
    maximal_width = 400,
    minimal_width = 200,
    --height = line_height
  }
end

-- Confirm button style (large, green, right-aligned)
if not gui_style.tf_confirm_button then
  gui_style.tf_confirm_button = {
    type = "button_style",
    parent = "confirm_button",
    horizontal_align = "right",
    top_margin = 0,
    right_margin = 4,
  }
end

-- Tag Editor teleport+favorite row style (vertical_align: center, horizontally_stretchable: on)
if not gui_style.tf_tag_editor_teleport_favorite_row then
  gui_style.tf_tag_editor_teleport_favorite_row = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertical_align = "center",
    horizontally_stretchable = "on",
    height = 78, -- Match the button's scaled height
    minimal_width = 200
  }
end

if not gui_style.tf_teleport_button then
  gui_style.tf_teleport_button = {
    type = "button_style",
    parent = "tf_orange_button",
    minimal_width = 100,             -- exact width
    maximal_width = 400,             -- prevent stretching
    --width = 38,                      -- force width
    height = 35,                     -- exact height
    minimal_height = 32,             -- prevent stretching
    maximal_height = 32,             -- prevent stretching
    horizontally_stretchable = "on", -- do not stretch
    vertically_stretchable = "off",  -- do not stretch
    top_margin = 3,
    bottom_margin = 0,
    left_margin = 0,
    right_margin = 0
  }
end



return true
