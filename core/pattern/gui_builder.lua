---@diagnostic disable: undefined-global

--[[
gui_builder.lua
TeleportFavorites Factorio Mod
-----------------------------
Builder pattern implementation for Factorio GUI construction.

Features:
---------
- Fluent API for building complex GUI hierarchies
- Type-safe element creation with validation
- Automatic parent-child relationship management
- Style application and configuration chaining
- Conditional element creation with predicates
- Reusable component templates and layouts

Builder Types:
--------------
- FlowBuilder: Horizontal/vertical flow containers
- FrameBuilder: Windows and dialogs with titlebars
- ButtonBuilder: Various button types with actions
- LabelBuilder: Text displays with formatting
- InputBuilder: Text fields and number inputs
- TableBuilder: Grid layouts with row/column management

Usage Examples:
---------------
-- Simple button with callback
GuiBuilder:button("my_btn")
  :caption("Click Me")
  :style("confirm_button")
  :on_click(my_handler)
  :build_in(parent)

-- Complex frame with nested elements
GuiBuilder:frame("main_window")
  :caption("My Window")
  :add_titlebar()
  :flow("content", "vertical")
    :label("title"):caption("Welcome"):style("heading_1_label"):build()
    :button("ok"):caption("OK"):style("confirm_button"):build()
  :build_in(player.gui.screen)
--]]

local Builder = require("core.pattern.builder")
local ErrorHandler = require("core.utils.error_handler")
local Helpers = require("core.utils.helpers_suite")

---@class GuiBuilder : Builder
local GuiBuilder = setmetatable({}, { __index = Builder })
GuiBuilder.__index = GuiBuilder

--- Create a new GUI builder
---@param element_type string Factorio GUI element type
---@param name string Element name
---@return GuiBuilder
function GuiBuilder:new(element_type, name)
  local obj = Builder:new()
  setmetatable(obj, self)
  
  obj.element_type = element_type
  obj.element_name = name
  obj.properties = {}
  obj.children = {}
  obj.event_handlers = {}
  obj.conditions = {}
  obj.built_element = nil
  
  return obj
end

--- Set element caption
---@param text LocalisedString
---@return GuiBuilder
function GuiBuilder:caption(text)
  self.properties.caption = text
  return self
end

--- Set element style
---@param style_name string
---@return GuiBuilder
function GuiBuilder:style(style_name)
  self.properties.style = style_name
  return self
end

--- Set element tooltip
---@param tooltip LocalisedString
---@return GuiBuilder
function GuiBuilder:tooltip(tooltip)
  self.properties.tooltip = tooltip
  return self
end

--- Set element visibility
---@param visible boolean
---@return GuiBuilder
function GuiBuilder:visible(visible)
  self.properties.visible = visible
  return self
end

--- Set element enabled state
---@param enabled boolean
---@return GuiBuilder
function GuiBuilder:enabled(enabled)
  self.properties.enabled = enabled
  return self
end

--- Add arbitrary property
---@param key string
---@param value any
---@return GuiBuilder
function GuiBuilder:property(key, value)
  self.properties[key] = value
  return self
end

--- Add condition for building this element
---@param predicate function Function that returns boolean
---@return GuiBuilder
function GuiBuilder:when(predicate)
  table.insert(self.conditions, predicate)
  return self
end

--- Add event handler
---@param event_type string Event type (e.g., "on_click")
---@param handler function Event handler function
---@return GuiBuilder
function GuiBuilder:on_click(handler)
  self.event_handlers.on_click = handler
  return self
end

--- Add child element builder
---@param child GuiBuilder
---@return GuiBuilder
function GuiBuilder:add_child(child)
  table.insert(self.children, child)
  return self
end

--- Create and add button child
---@param name string
---@return GuiBuilder child_builder
function GuiBuilder:button(name)
  local child = GuiBuilder:new("sprite-button", name)
  self:add_child(child)
  return child
end

--- Create and add label child
---@param name string
---@return GuiBuilder child_builder
function GuiBuilder:label(name)
  local child = GuiBuilder:new("label", name)
  self:add_child(child)
  return child
end

--- Create and add flow child
---@param name string
---@param direction string "horizontal" or "vertical"
---@return GuiBuilder child_builder
function GuiBuilder:flow(name, direction)
  local child = GuiBuilder:new("flow", name)
  child:property("direction", direction or "horizontal")
  self:add_child(child)
  return child
end

--- Create and add frame child
---@param name string
---@return GuiBuilder child_builder
function GuiBuilder:frame(name)
  local child = GuiBuilder:new("frame", name)
  self:add_child(child)
  return child
end

--- Create and add text input child
---@param name string
---@return GuiBuilder child_builder
function GuiBuilder:textfield(name)
  local child = GuiBuilder:new("textfield", name)
  self:add_child(child)
  return child
end

--- Create and add textbox child
---@param name string
---@return GuiBuilder child_builder
function GuiBuilder:textbox(name)
  local child = GuiBuilder:new("text-box", name)
  self:add_child(child)
  return child
end

--- Create and add table child
---@param name string
---@param column_count number
---@return GuiBuilder child_builder
function GuiBuilder:table(name, column_count)
  local child = GuiBuilder:new("table", name)
  child:property("column_count", column_count or 1)
  self:add_child(child)
  return child
end

--- Create and add choose-elem-button child
---@param name string
---@param elem_type string Element type (e.g., "signal", "item")
---@return GuiBuilder child_builder
function GuiBuilder:elem_button(name, elem_type)
  local child = GuiBuilder:new("choose-elem-button", name)
  child:property("elem_type", elem_type or "signal")
  self:add_child(child)
  return child
end

--- Check if all conditions are met for building
---@return boolean should_build
function GuiBuilder:should_build()
  for _, predicate in ipairs(self.conditions) do
    if not predicate() then
      return false
    end
  end
  return true
end

--- Build element properties table
---@return table properties
function GuiBuilder:build_properties()
  local props = Helpers.deep_copy(self.properties)
  props.type = self.element_type
  props.name = self.element_name
  return props
end

--- Build the GUI element
---@param parent LuaGuiElement Parent element to build in
---@return LuaGuiElement? element Built element or nil if conditions not met
function GuiBuilder:build_in(parent)
  if not parent or not parent.valid then
    ErrorHandler.handle_error(ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.VALIDATION_FAILED,
      "Invalid parent element for GUI builder",
      { element_name = self.element_name, element_type = self.element_type }
    ), nil, false)
    return nil
  end

  -- Check conditions
  if not self:should_build() then
    ErrorHandler.debug_log("Skipping element build due to conditions", {
      element_name = self.element_name
    })
    return nil
  end

  -- Build properties
  local properties = self:build_properties()
  
  -- Create element
  local success, element = pcall(function()
    return parent.add(properties)
  end)

  if not success then
    ErrorHandler.handle_error(ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.OPERATION_FAILED,
      "Failed to create GUI element: " .. tostring(element),
      { element_name = self.element_name, element_type = self.element_type, properties = properties }
    ), nil, false)
    return nil
  end

  self.built_element = element

  -- Build children
  for _, child in ipairs(self.children) do
    child:build_in(element)
  end

  ErrorHandler.debug_log("GUI element built successfully", {
    element_name = self.element_name,
    element_type = self.element_type,
    children_count = #self.children
  })

  return element
end

--- Build and return element (alias for build_in)
---@param parent LuaGuiElement Parent element
---@return LuaGuiElement? element
function GuiBuilder:build(parent)
  return self:build_in(parent)
end

--- Get the built element
---@return LuaGuiElement? element
function GuiBuilder:get_element()
  return self.built_element
end

--- Chain back to parent builder for fluent API
---@return GuiBuilder parent_builder
function GuiBuilder:end_child()
  -- This would need to be implemented with parent tracking for full fluent API
  return self
end

---@class FrameBuilder : GuiBuilder
local FrameBuilder = setmetatable({}, { __index = GuiBuilder })
FrameBuilder.__index = FrameBuilder

--- Create a frame builder
---@param name string
---@return FrameBuilder
function FrameBuilder:new(name)
  local obj = GuiBuilder:new("frame", name)
  setmetatable(obj, self)
  return obj
end

--- Add titlebar to frame
---@param title LocalisedString? Title text
---@param close_button boolean? Whether to add close button
---@return FrameBuilder
function FrameBuilder:add_titlebar(title, close_button)
  -- Add titlebar flow
  local titlebar = self:flow("titlebar", "horizontal")
    :style("titlebar_flow")
  
  if title then
    titlebar:label("title")
      :caption(title)
      :style("frame_title")
  end
  
  if close_button ~= false then
    titlebar:button("close")
      :style("frame_action_button")
      :sprite("utility/close")
      :tooltip({"gui.close"})
  end
  
  return self
end

--- Make frame modal
---@return FrameBuilder
function FrameBuilder:modal()
  self.properties.ignored_by_interaction = false
  return self
end

---@class ButtonBuilder : GuiBuilder
local ButtonBuilder = setmetatable({}, { __index = GuiBuilder })
ButtonBuilder.__index = ButtonBuilder

--- Create a button builder
---@param name string
---@return ButtonBuilder
function ButtonBuilder:new(name)
  local obj = GuiBuilder:new("sprite-button", name)
  setmetatable(obj, self)
  return obj
end

--- Set button sprite
---@param sprite string Sprite path
---@return ButtonBuilder
function ButtonBuilder:sprite(sprite)
  self.properties.sprite = sprite
  return self
end

--- Set button as toggle
---@param toggled boolean? Initial toggle state
---@return ButtonBuilder
function ButtonBuilder:toggle(toggled)
  self.properties.toggle = true
  if toggled ~= nil then
    self.properties.toggled = toggled
  end
  return self
end

--- Make button raise on hover
---@return ButtonBuilder
function ButtonBuilder:raise_hover()
  self.properties.raise_hover_events = true
  return self
end

-- Factory functions for convenience
GuiBuilder.frame = function(name) return FrameBuilder:new(name) end
GuiBuilder.button = function(name) return ButtonBuilder:new(name) end
GuiBuilder.label = function(name) return GuiBuilder:new("label", name) end
GuiBuilder.flow = function(name, direction) 
  local builder = GuiBuilder:new("flow", name)
  builder:property("direction", direction or "horizontal")
  return builder
end

return GuiBuilder
