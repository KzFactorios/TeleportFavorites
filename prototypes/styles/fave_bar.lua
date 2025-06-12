---@diagnostic disable: undefined-global
--[[
Custom styles for the Favorites Bar GUI (fave_bar)
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default


-- Favorites bar frame (padding: 4, margin: {4, 0, 0, 4})
if not gui_style.tf_fave_bar_frame then
    gui_style.tf_fave_bar_frame = {
        type = "frame_style",
        parent = "slot_window_frame",
        padding = 4,
        top_margin = 0,
        right_margin = 0,
        bottom_margin = 0,
        left_margin = 0,
        vertically_stretchable = "on",
        horizontally_stretchable = "off",
    }
end

if not gui_style.tf_fave_bar_draggable then
    gui_style.tf_fave_bar_draggable = {
        type = "empty_widget_style",
        parent = "draggable_space_header",
        horizontally_stretchable = "on",
        width = 16,
        height = 0,
        maximal_height = 100
    }
end

if not gui_style.tf_fave_toggle_container then
    gui_style.tf_fave_toggle_container = {
        type = "frame_style",
        parent = "inside_deep_frame", -- match the slots row background
        graphical_set = nil,    -- use parent's background
        padding = 2,
        margin = 0,
        horizontally_stretchable = "off",
        vertically_stretchable = "off"
    }
end

if not gui_style.tf_fave_toggle_button then
    gui_style.tf_fave_toggle_button = {
        type = "button_style",
        parent = "tf_slot_button",
        margin = 2,
        width = 40,
        height = 40,
        default_graphical_set = {
            base = { position = { 34, 17 }, corner_size = 8 } --tint = { r = 0.98, g = 0.66, b = 0.22, a = 1 } } -- orange tint
        }
    }
end

if not gui_style.tf_fave_slots_row then
    gui_style.tf_fave_slots_row = {
        type = "frame_style",
        parent = "inside_deep_frame",
        vertically_stretchable = "off",
        horizontally_stretchable = "on",
        left_margin = 0,
        padding = 4,
        margin = 0
    }
end

-- Functional programming approach for button style creation
local function extend_style(base_style, overrides)
  local result = {}
  for k, v in pairs(base_style) do result[k] = v end
  for k, v in pairs(overrides) do result[k] = v end
  return result
end

local function create_tinted_graphical_sets(tint)
  return {
    default_graphical_set = {
      base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
    },
    hovered_graphical_set = {
      base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
    },
    clicked_graphical_set = {
      base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
    },
    disabled_graphical_set = {
      base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", 
             tint = { r = tint.r, g = tint.g, b = tint.b, a = tint.a * 0.5 } }
    }
  }
end

-- Small font button style
if not gui_style.tf_slot_button_smallfont then
    gui_style.tf_slot_button_smallfont = extend_style(gui_style.slot_button, {
        type = "button_style",
        font = "default-small",
        horizontal_align = "center",
        vertical_align = "bottom",
        selected_font_color = nil,
        hovered_font_color = nil,
        clicked_font_color = nil,
        disabled_font_color = nil,
        font_color = { r = 1, g = 0.647, b = 0, a = 1 }, -- Factorio orange #ffa500
        top_padding = 0,
        bottom_padding = 2,
        size = { 40, 40 }
    })
end

-- Create tinted button variants using functional approach
local tinted_button_configs = {
  {
    name = "tf_slot_button_dragged",
    tint = { r = 0.2, g = 0.7, b = 1, a = 1 } -- blue
  },
  {
    name = "tf_slot_button_locked", 
    tint = { r = 1, g = 0.5, b = 0, a = 1 } -- orange
  },
  {
    name = "tf_slot_button_drag_target",
    tint = { r = 1, g = 1, b = 0.2, a = 1 } -- yellow
  }
}

for _, config in ipairs(tinted_button_configs) do
  if not gui_style[config.name] then
    gui_style[config.name] = extend_style(gui_style.slot_button, create_tinted_graphical_sets(config.tint))
  end
end

return true
