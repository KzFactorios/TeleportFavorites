---@diagnostic disable
--[[
gui_rendering_strategy.lua
TeleportFavorites Factorio Mod
-----------------------------
Strategy pattern implementation for GUI rendering strategies.

This demonstrates how different GUI rendering approaches can be encapsulated
as strategies and swapped at runtime based on context (player preferences,
screen resolution, mod compatibility, etc.).

PATTERN BENEFITS:
- Different rendering strategies for different screen sizes
- Accessibility-focused rendering strategies
- Performance-optimized strategies for large player counts
- Easy to add new rendering modes without changing existing code

USAGE SCENARIOS:
- Compact vs. full GUI rendering modes
- High-contrast mode for accessibility
- Performance mode for multiplayer servers
- Mobile-friendly rendering (future-proofing)
]]

local Strategy = require("core.pattern.strategy")
local GuiBase = require("gui.base_gui")
local ErrorHandler = require("core.utils.error_handler")

---@class GuiRenderingStrategy: Strategy
-- Context class for GUI rendering strategies
local GuiRenderingStrategy = {}
GuiRenderingStrategy.__index = GuiRenderingStrategy

--- Create a new GUI rendering strategy context
---@param strategy Strategy The rendering strategy to use
---@return GuiRenderingStrategy
function GuiRenderingStrategy:new(strategy)
    local obj = setmetatable({}, self)
    obj.strategy = strategy
    return obj
end

--- Set a new rendering strategy
---@param strategy Strategy
function GuiRenderingStrategy:set_strategy(strategy)
    self.strategy = strategy
end

--- Render GUI using the current strategy
---@param parent LuaGuiElement
---@param data table GUI data to render
---@param context table? Optional rendering context
---@return LuaGuiElement? rendered_gui
function GuiRenderingStrategy:render(parent, data, context)
    if not self.strategy then
        ErrorHandler.debug_log("No GUI rendering strategy set")
        return nil
    end
    
    return self.strategy:execute(parent, data, context)
end

-- =====================================
-- CONCRETE GUI RENDERING STRATEGIES  
-- =====================================

---@class StandardGuiStrategy: Strategy
-- Standard GUI rendering - full-featured, normal spacing
local StandardGuiStrategy = setmetatable({}, { __index = Strategy })

---@param parent LuaGuiElement
---@param data table
---@param context table?
---@return LuaGuiElement?
function StandardGuiStrategy:execute(parent, data, context)
    ErrorHandler.debug_log("StandardGuiStrategy: Rendering standard GUI", {
        data_type = type(data),
        has_context = context ~= nil
    })
    
    -- Create standard outer frame
    local frame = GuiBase.create_frame(parent, data.name or "standard_frame", "vertical", "inside_shallow_frame_with_padding")
    if not frame then return nil end
    
    -- Add title with standard styling
    if data.title then
        local title = GuiBase.create_label(frame, (data.name or "frame") .. "_title", data.title, "frame_title")
        if title then
            title.style.font = "default-large-bold"
            title.style.bottom_margin = 8
        end
    end
    
    -- Create content area with standard spacing
    local content = GuiBase.create_frame(frame, (data.name or "frame") .. "_content", "vertical", "inside_shallow_frame")
    if content then
        content.style.padding = 12
        content.style.vertical_spacing = 8
    end
    
    -- Add standard buttons if provided
    if data.buttons and type(data.buttons) == "table" then
        local button_flow = GuiBase.create_flow(content, (data.name or "frame") .. "_buttons", "horizontal")
        if button_flow then
            button_flow.style.top_margin = 8
            button_flow.style.horizontal_spacing = 8
            
            for _, button_data in ipairs(data.buttons) do
                if button_data.name and button_data.caption then
                    GuiBase.create_button(button_flow, button_data.name, button_data.caption, button_data.style or "default")
                end
            end
        end
    end
    
    ErrorHandler.debug_log("StandardGuiStrategy: Standard GUI rendered successfully")
    return frame
end

---@class CompactGuiStrategy: Strategy
-- Compact GUI rendering - reduced spacing, smaller fonts
local CompactGuiStrategy = setmetatable({}, { __index = Strategy })

---@param parent LuaGuiElement
---@param data table
---@param context table?
---@return LuaGuiElement?
function CompactGuiStrategy:execute(parent, data, context)
    ErrorHandler.debug_log("CompactGuiStrategy: Rendering compact GUI", {
        data_type = type(data),
        has_context = context ~= nil
    })
    
    -- Create compact outer frame
    local frame = GuiBase.create_frame(parent, data.name or "compact_frame", "vertical", "inside_shallow_frame")
    if not frame then return nil end
    
    -- Compact styling
    frame.style.padding = 4
    frame.style.vertical_spacing = 4
    
    -- Add title with compact styling
    if data.title then
        local title = GuiBase.create_label(frame, (data.name or "frame") .. "_title", data.title, "label")
        if title then
            title.style.font = "default-bold"
            title.style.bottom_margin = 4
        end
    end
    
    -- Create content area with compact spacing
    local content = GuiBase.create_frame(frame, (data.name or "frame") .. "_content", "vertical", "inside_shallow_frame")
    if content then
        content.style.padding = 6
        content.style.vertical_spacing = 4
    end
    
    -- Add compact buttons if provided
    if data.buttons and type(data.buttons) == "table" then
        local button_flow = GuiBase.create_flow(content, (data.name or "frame") .. "_buttons", "horizontal")
        if button_flow then
            button_flow.style.top_margin = 4
            button_flow.style.horizontal_spacing = 4
            
            for _, button_data in ipairs(data.buttons) do
                if button_data.name and button_data.caption then
                    local button = GuiBase.create_button(button_flow, button_data.name, button_data.caption, "compact_button")
                    if button then
                        button.style.height = 24
                        button.style.font = "default-small"
                    end
                end
            end
        end
    end
    
    ErrorHandler.debug_log("CompactGuiStrategy: Compact GUI rendered successfully")
    return frame
end

---@class AccessibilityGuiStrategy: Strategy
-- Accessibility GUI rendering - high contrast, larger fonts, clear focus
local AccessibilityGuiStrategy = setmetatable({}, { __index = Strategy })

---@param parent LuaGuiElement
---@param data table
---@param context table?
---@return LuaGuiElement?
function AccessibilityGuiStrategy:execute(parent, data, context)
    ErrorHandler.debug_log("AccessibilityGuiStrategy: Rendering accessibility GUI", {
        data_type = type(data),
        has_context = context ~= nil
    })
    
    -- Create accessible outer frame
    local frame = GuiBase.create_frame(parent, data.name or "accessible_frame", "vertical", "inside_shallow_frame_with_padding")
    if not frame then return nil end
    
    -- High-contrast styling
    frame.style.padding = 16
    frame.style.vertical_spacing = 12
    
    -- Add title with accessibility styling
    if data.title then
        local title = GuiBase.create_label(frame, (data.name or "frame") .. "_title", data.title, "frame_title")
        if title then
            title.style.font = "default-large-bold"
            title.style.bottom_margin = 12
            -- Add tooltip for screen readers
            title.tooltip = "Dialog title: " .. (data.title or "")
        end
    end
    
    -- Create content area with accessible spacing
    local content = GuiBase.create_frame(frame, (data.name or "frame") .. "_content", "vertical", "inside_shallow_frame")
    if content then
        content.style.padding = 16
        content.style.vertical_spacing = 12
    end
    
    -- Add accessible buttons if provided
    if data.buttons and type(data.buttons) == "table" then
        local button_flow = GuiBase.create_flow(content, (data.name or "frame") .. "_buttons", "horizontal")
        if button_flow then
            button_flow.style.top_margin = 12
            button_flow.style.horizontal_spacing = 12
            
            for _, button_data in ipairs(data.buttons) do
                if button_data.name and button_data.caption then
                    local button = GuiBase.create_button(button_flow, button_data.name, button_data.caption, "default")
                    if button then
                        button.style.height = 36
                        button.style.font = "default-large"
                        button.style.minimal_width = 120
                        -- Add descriptive tooltips
                        button.tooltip = button_data.tooltip or ("Button: " .. button_data.caption)
                    end
                end
            end
        end
    end
    
    ErrorHandler.debug_log("AccessibilityGuiStrategy: Accessibility GUI rendered successfully")
    return frame
end

---@class MinimalGuiStrategy: Strategy
-- Minimal GUI rendering - bare minimum elements, performance optimized
local MinimalGuiStrategy = setmetatable({}, { __index = Strategy })

---@param parent LuaGuiElement
---@param data table
---@param context table?
---@return LuaGuiElement?
function MinimalGuiStrategy:execute(parent, data, context)
    ErrorHandler.debug_log("MinimalGuiStrategy: Rendering minimal GUI", {
        data_type = type(data),
        has_context = context ~= nil
    })
    
    -- Create minimal frame - just the essentials
    local frame = GuiBase.create_frame(parent, data.name or "minimal_frame", "vertical", "naked_frame")
    if not frame then return nil end
    
    -- Minimal styling
    frame.style.padding = 2
    frame.style.vertical_spacing = 2
    
    -- Only add title if absolutely necessary
    if data.title and data.show_title ~= false then
        local title = GuiBase.create_label(frame, (data.name or "frame") .. "_title", data.title, "label")
        if title then
            title.style.font = "default"
            title.style.bottom_margin = 2
        end
    end
    
    -- Minimal buttons - only essential ones
    if data.buttons and type(data.buttons) == "table" then
        local button_flow = GuiBase.create_flow(frame, (data.name or "frame") .. "_buttons", "horizontal")
        if button_flow then
            button_flow.style.horizontal_spacing = 2
            
            -- Only render buttons marked as essential
            for _, button_data in ipairs(data.buttons) do
                if button_data.essential and button_data.name and button_data.caption then
                    local button = GuiBase.create_button(button_flow, button_data.name, button_data.caption, "mini_button")
                    if button then
                        button.style.height = 20
                        button.style.font = "default-small"
                        button.style.minimal_width = 60
                    end
                end
            end
        end
    end
    
    ErrorHandler.debug_log("MinimalGuiStrategy: Minimal GUI rendered successfully")
    return frame
end

-- Factory function to create appropriate strategy based on context
---@param context table? Context information for strategy selection
---@return Strategy
local function create_strategy_for_context(context)
    if not context then
        return StandardGuiStrategy
    end
    
    -- Select strategy based on player preferences or context
    if context.mode == "compact" or context.screen_size == "small" then
        return CompactGuiStrategy
    elseif context.mode == "accessibility" or context.high_contrast then
        return AccessibilityGuiStrategy
    elseif context.mode == "minimal" or context.performance_mode then
        return MinimalGuiStrategy
    else
        return StandardGuiStrategy
    end
end

-- Export strategy classes and factory
return {
    GuiRenderingStrategy = GuiRenderingStrategy,
    StandardGuiStrategy = StandardGuiStrategy,
    CompactGuiStrategy = CompactGuiStrategy,
    AccessibilityGuiStrategy = AccessibilityGuiStrategy,
    MinimalGuiStrategy = MinimalGuiStrategy,
    create_strategy_for_context = create_strategy_for_context
}
