-- core/utils/style_helpers.lua
-- Functional programming utilities for GUI style generation

local StyleHelpers = {}

--- Creates a style by extending a base style with custom properties
--- @param base_style table The base style to extend
--- @param overrides table Properties to override or add
--- @return table The new style table
function StyleHelpers.extend_style(base_style, overrides)
  if type(base_style) ~= "table" or type(overrides) ~= "table" then
    return base_style or {}
  end
  
  local result = {}
  -- Copy base style properties
  for k, v in pairs(base_style) do
    result[k] = v
  end
  
  -- Apply overrides
  for k, v in pairs(overrides) do
    result[k] = v
  end
  
  return result
end

--- Creates multiple button styles with the same base but different tints
--- @param base_style table The base style to use
--- @param style_configs table Array of {name, tint_color} configurations
--- @param gui_style table The gui_style table to register styles to
function StyleHelpers.create_tinted_button_styles(base_style, style_configs, gui_style)
  if type(base_style) ~= "table" or type(style_configs) ~= "table" or type(gui_style) ~= "table" then
    return
  end
  
  local function create_graphical_set_with_tint(tint)
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
  
  for _, config in ipairs(style_configs) do
    if config.name and config.tint and not gui_style[config.name] then
      local style_override = create_graphical_set_with_tint(config.tint)
      gui_style[config.name] = StyleHelpers.extend_style(base_style, style_override)
    end
  end
end

--- Creates a processor function for transforming table data
--- @param transform_func function Function that takes (value, key) and returns transformed result
--- @return function Processor function for use with data transformation
function StyleHelpers.create_data_processor(transform_func)
  return function(data)
    if type(data) ~= "table" or type(transform_func) ~= "function" then
      return {}
    end
    
    local result = {}
    for k, v in pairs(data) do
      local transformed = transform_func(v, k)
      if transformed ~= nil then
        table.insert(result, transformed)
      end
    end
    return result
  end
end

--- Applies functional style transformations to a set of styles
--- @param styles table Table of style definitions
--- @param transform_func function Function to apply to each style
--- @return table Transformed styles table
function StyleHelpers.transform_styles(styles, transform_func)
  if type(styles) ~= "table" or type(transform_func) ~= "function" then
    return styles or {}
  end
  
  local result = {}
  for name, style in pairs(styles) do
    result[name] = transform_func(style, name)
  end
  return result
end

return StyleHelpers
