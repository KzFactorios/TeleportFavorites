---@diagnostic disable: undefined-global
local gui_style = data.raw["gui-style"].default

local default_glow_color = { 225, 177, 106, 255 }
local default_shadow_color = { 0, 0, 0, 0.35 }
local hard_shadow_color = { 0, 0, 0, 1 }

local default_dirt_color = { 15, 7, 3, 100 }

local line_height = 44
local gui_color =
{
  white = { 1, 1, 1 },
  white_with_alpha = { 1, 1, 1, 0.5 },
  grey = { 0.5, 0.5, 0.5 },
  green = { 0, 1, 0 },
  red = { 255, 142, 142 },
  orange = { 0.98, 0.66, 0.22 },
  light_orange = { 1, 0.74, 0.40 },
  caption = { 255, 230, 192 },
  achievement_green = { 210, 253, 145 },
  achievement_tan = { 255, 230, 192 },
  achievement_failed = { 176, 171, 171 },
  achievement_failed_body = { 255, 136, 136 },
  blue = { 128, 206, 240 }
}

local arrow_idle_index = 0
local arrow_disabled_index = 1
local arrow_hovered_index = 2
local arrow_clicked_index = 3

--- put all new content below this line



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
  left_padding = 12,
  horizontally_stretchable = "on",
}

gui_style.tf_tag_editor_rich_text_row = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontally_stretchable = "on",
  height = line_height
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
        position = { 136, 0 },
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


gui_style.tf_tag_editor_last_row = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontal_align = "right",
  horizontally_stretchable = "on",
  height = line_height
}

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


-- Confirm button style (large, green, right-aligned)
if not gui_style.tf_confirm_button then
  gui_style.tf_confirm_button = {
    type = "button_style",
    parent = "confirm_button",
    horizontal_align = "center",
    top_margin = 0,
    right_margin = 4,
    minimal_width = 150
  }
end

-- Tag Editor teleport+favorite row style (vertical_align: center, horizontally_stretchable: on)
gui_style.tf_tag_editor_teleport_favorite_row = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  vertical_align = "center",
  horizontally_stretchable = "on",
  height = 78, -- Match the button's scaled height
  minimal_width = 200
}

if not gui_style.tf_teleport_button then
  local base_graphical_set = {
    base = {
      filename = "__TeleportFavorites__/graphics/button_orange_right.png",
      position = {0, 0},
      size = {38, 32}, -- exact PNG size
      --corner_size = 0, -- no 9-slice, just use the full image
      draw_type = "outer",
    }
  }
  gui_style.tf_teleport_button = {
    type = "button_style",
    parent = "dialog_button",
    minimal_width = 38,   -- exact width
    maximal_width = 38,   -- prevent stretching
    width = 38,           -- force width
    height = 32,          -- exact height
    minimal_height = 32,  -- prevent stretching
    maximal_height = 32,  -- prevent stretching
    horizontally_stretchable = "off", -- do not stretch
    vertically_stretchable = "off",   -- do not stretch
    top_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    right_margin = 0,
    default_graphical_set = base_graphical_set,
    hovered_graphical_set = base_graphical_set,
    clicked_graphical_set = base_graphical_set,
    disabled_graphical_set = base_graphical_set
  }
end



return true
