--[[
Custom styles for the Tag Editor GUI
]]

---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default


-- Tag Editor outer frame style (padding: 2,8,8,8)
gui_style.tf_tag_editor_outer_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    top_padding = 2,
    right_padding = 8,
    bottom_padding = 8,
    left_padding = 8
}

-- Tag Editor inner frame style (padding: 0,0,0,0; margin: 0,0,0,0)
gui_style.tf_tag_editor_inner_frame = {
    type = "frame_style",
    parent = "invisible_frame",
    padding = 0,
    margin = 0
}

-- Tag Editor content frame style (padding: 0, margin: 0)
gui_style.tf_tag_editor_content_frame = {
    type = "frame_style",
    parent = "frame",
    padding = 0,
    margin = 0
}

-- Tag Editor label style (padding: 8,12,4,16; bold font)
gui_style.tf_tag_editor_label = {
    type = "label_style",
    parent = "label",
    top_padding = 8,
    right_padding = 12,
    bottom_padding = 4,
    left_padding = 16,
    font = "default-bold"
}

-- Tag Editor content inner frame style (margin: 8,0,0,0; padding: 0,12,0,12)
gui_style.tf_tag_editor_content_inner_frame = {
    type = "frame_style",
    parent = "invisible_frame",
    top_margin = 8,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    top_padding = 0,
    right_padding = 12,
    bottom_padding = 0,
    left_padding = 12
}

-- Tag Editor teleport+favorite row style (vertical_align: center, horizontally_stretchable: on)
gui_style.tf_tag_editor_teleport_favorite_row = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertical_align = "center",
    horizontally_stretchable = "on"
}

-- Custom style for last user label with blue background
if not gui_style.tf_last_user_row then
  gui_style.tf_last_user_row = {
    type = "frame_style",
    parent = "frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    --height = 28,
    graphical_set = {
      base = {
        position = {136, 0},
        corner_size = 8,
        draw_type = "outer",
        tint = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
      }
    },
    top_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    right_padding = 0,
  }
end


-- Confirm button style (large, green, right-aligned)
if not gui_style.tf_confirm_button then
  gui_style.tf_confirm_button = {
    type = "button_style",
    parent = "confirm_button",
    horizontally_stretchable = "on",
    font = "default-bold",
    height = 36,
    width = 120,
    top_margin = 8,
    right_margin = 8
  }
end

-- Teleport button style (vanilla icon, orange background)
if not gui_style.tf_teleport_button then
  gui_style.tf_teleport_button = {
    type = "button_style",
    parent = "confirm_button",
    horizontal_align = "center",
    height = 32,
    top_margin = 0,
    right_margin = 4
  }
end

-- Custom style for the insert rich text icon button (no background)
if not gui_style.tf_insert_rich_text_button then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.default_graphical_set = { base = { type = "none" } }
  base.hovered_graphical_set = { base = { type = "none" } }
  base.clicked_graphical_set = { base = { type = "none" } }
  base.disabled_graphical_set = { base = { type = "none" } }
  base.width = 16
  base.height = 16
  base.padding = 2
  base.margin = 0
  gui_style.tf_insert_rich_text_button = base
end

return true
