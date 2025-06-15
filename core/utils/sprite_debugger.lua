---@class SpriteDebugger
-- Tool for displaying sprites from sprite sheets for debugging and visual inspection
local SpriteDebugger = {}

-- Import GUI base functionality
local GuiBase = require("gui.gui_base")
local ErrorHandler = require("core.utils.error_handler")

--- Create a sprite viewer frame with labeled sections
---@param parent LuaGuiElement The parent GUI element to add the sprite viewer to
---@param name string Base name for the sprite viewer elements
---@return LuaGuiElement The created sprite viewer frame
function SpriteDebugger.create_sprite_viewer(parent, name)
    local frame = GuiBase.create_element("frame", parent, {
        name = name .. "_sprite_viewer_frame",
        direction = "vertical",
        caption = "Sprite Sections Used"
    })
    
    -- Create a scroll pane inside the frame to hold all sprite sections
    local scroll_pane = GuiBase.create_element("scroll-pane", frame, {
        name = name .. "_sprite_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
        style = "tf_sprite_viewer_scroll_pane"
    })
    
    -- Create a main flow inside the scroll pane to hold all sprite sections
    local main_flow = GuiBase.create_element("flow", scroll_pane, {
        name = name .. "_sprite_main_flow",
        direction = "vertical"
    })
    
    return main_flow
end

--- Add a labeled section for displaying sprite sections for a button style
---@param viewer_flow LuaGuiElement The main flow in the sprite viewer
---@param section_name string Name for this section
---@param description string Description of what this section displays
---@return LuaGuiElement The section flow for adding sprites
function SpriteDebugger.add_section(viewer_flow, section_name, description)
    -- Create section header with a visible separator
    local separator = GuiBase.create_element("line", viewer_flow, {
        name = section_name .. "_separator",
        direction = "horizontal"
    })
    
    -- Add section title/label
    local title = GuiBase.create_element("label", viewer_flow, {
        name = section_name .. "_title",
        caption = description,
        style = "tf_sprite_viewer_section_title"
    })
    
    -- Create flow for sprite images
    local section_flow = GuiBase.create_element("flow", viewer_flow, {
        name = section_name .. "_flow",
        direction = "vertical"
    })
    
    return section_flow
end

--- Add a sprite from a sprite sheet to a section
---@param section_flow LuaGuiElement The section flow to add the sprite to
---@param sprite_name string Name for this sprite element
---@param label_text string Label text to display above the sprite
---@param sprite_data table Sprite data with filename, position, size, etc.
function SpriteDebugger.add_sprite(section_flow, sprite_name, label_text, sprite_data)
    -- Container for label and sprite
    local container = GuiBase.create_element("flow", section_flow, {
        name = sprite_name .. "_container",
        direction = "vertical"
    })
    
    -- Add label above sprite
    local label = GuiBase.create_element("label", container, {
        name = sprite_name .. "_label",
        caption = label_text,
        tooltip = "Filename: " .. (sprite_data.filename or "none") .. 
                  "\nPosition: " .. table.concat(sprite_data.position or {0, 0}, ", ") ..
                  "\nSize: " .. (sprite_data.width or "?") .. "×" .. (sprite_data.height or "?") ..
                  (sprite_data.tint and ("\nTint: " .. sprite_data.tint.r .. "," .. sprite_data.tint.g .. "," .. sprite_data.tint.b) or "")
    })
    
    -- Add frame to hold sprite with a dark background
    local sprite_frame = GuiBase.create_element("frame", container, {
        name = sprite_name .. "_frame",
        style = "tf_sprite_dark_frame"
    })
    
    -- Create a high-contrast background so we can see transparent parts of sprites
    local bg = GuiBase.create_element("table", sprite_frame, {
        name = sprite_name .. "_bg",
        column_count = 2,
        style = "tf_checkerboard_table"
    })
    
    -- Need to create 4 cells (2x2) of alternating colors to create a checkerboard
    for i=1,4 do
        local cell = GuiBase.create_element("empty-widget", bg, {
            style = (i % 2 == 1) and "tf_checkerboard_dark" or "tf_checkerboard_light"
        })
    end
    
    -- Add the actual sprite on top of the checkerboard
    local sprite = GuiBase.create_element("sprite", sprite_frame, {
        name = sprite_name .. "_sprite",
        sprite = SpriteDebugger.prepare_sprite_for_display(sprite_data),
        resize_to_sprite = true
    })
    
    -- For sprites with tint, add a copy without tint for comparison
    if sprite_data.tint then        local untinted_data = {}
        for k, v in pairs(sprite_data) do
            untinted_data[k] = v
        end
        untinted_data.tint = nil
        
        local untinted_label = GuiBase.create_element("label", container, {
            name = sprite_name .. "_untinted_label",
            caption = label_text .. " (without tint)",
            tooltip = "Filename: " .. (sprite_data.filename or "none") .. 
                      "\nPosition: " .. table.concat(sprite_data.position or {0, 0}, ", ") ..
                      "\nSize: " .. (sprite_data.width or "?") .. "×" .. (sprite_data.height or "?")
        })
        
        local untinted_frame = GuiBase.create_element("frame", container, {
            name = sprite_name .. "_untinted_frame",
            style = "tf_sprite_dark_frame"
        })
        
        local untinted_bg = GuiBase.create_element("table", untinted_frame, {
            name = sprite_name .. "_untinted_bg",
            column_count = 2,
            style = "tf_checkerboard_table"
        })
        
        for i=1,4 do
            local cell = GuiBase.create_element("empty-widget", untinted_bg, {
                style = (i % 2 == 1) and "tf_checkerboard_dark" or "tf_checkerboard_light"
            })
        end
        
        local untinted_sprite = GuiBase.create_element("sprite", untinted_frame, {
            name = sprite_name .. "_untinted_sprite",
            sprite = SpriteDebugger.prepare_sprite_for_display(untinted_data),
            resize_to_sprite = true
        })
    end
end

--- Create a sprite definition from the data used in button style definitions
---@param sprite_data table The sprite data from a button style
---@return string The sprite name for use in a sprite element
function SpriteDebugger.prepare_sprite_for_display(sprite_data)
    -- Convert the sprite data used in button styles to a format usable by the sprite element
    local sprite_def = {
        type = "sprite",
        name = "temp_sprite_" .. math.random(1000000),  -- Generate random name
        filename = sprite_data.filename,
        priority = "extra-high-no-scale",
        x = sprite_data.position[1],
        y = sprite_data.position[2],
        width = sprite_data.width or sprite_data.size and sprite_data.size[1] or 36,
        height = sprite_data.height or sprite_data.size and sprite_data.size[2] or 36
    }
    
    -- Apply tint if present
    if sprite_data.tint then
        sprite_def.tint = sprite_data.tint
    end
    
    return sprite_def.name
end

-- Function to extract style data from the actual game style prototypes
-- This will be called at runtime to get the actual sprite sections being used
-- @param style_name string The name of the style to extract information from
-- @param game LuaGameScript Game object reference
-- @return table Information about the style's graphical_set sections
function SpriteDebugger.extract_style_data(style_name, game)
    local style_data = {}
    -- The game parameter must be passed in from the calling context
    if not game or not game.styles then
        return { error = "Game object missing or invalid" }
    end
    
    local style = game.styles[style_name]
    
    if not style then
        return { error = "Style not found: " .. style_name }
    end
    
    -- Note: We need to use pcall here as accessing these properties can throw errors
    -- if the style doesn't have the expected structure
    local success, result = pcall(function()
        local data = {
            default_graphical_set = {},
            hovered_graphical_set = {},
            clicked_graphical_set = {}
        }
        
        -- Extract sprite info from button states
        -- We have to be careful here as the style might not have all these properties
        if style.default_graphical_set then
            data.default_graphical_set = SpriteDebugger.extract_graphical_set(style.default_graphical_set)
        end
        
        if style.hovered_graphical_set then
            data.hovered_graphical_set = SpriteDebugger.extract_graphical_set(style.hovered_graphical_set)
        end
        
        if style.clicked_graphical_set then
            data.clicked_graphical_set = SpriteDebugger.extract_graphical_set(style.clicked_graphical_set)
        end
        
        return data
    end)
      if success then
        return result
    else
        ErrorHandler.debug_log("Error extracting button style data", {
            style_name = tostring(style and style.name),
            error = result
        })
        return { error = "Error extracting style data: " .. tostring(result) }
    end
end

-- Extract details from a graphical set
-- @param graphical_set table The graphical_set to extract information from
-- @return table Information about the base, shadow, and right sections
function SpriteDebugger.extract_graphical_set(graphical_set)
    local result = {}
    
    -- Extract base section
    if graphical_set.base then
        result.base = SpriteDebugger.extract_sprite_info(graphical_set.base)
    end
    
    -- Extract shadow section
    if graphical_set.shadow then
        result.shadow = SpriteDebugger.extract_sprite_info(graphical_set.shadow)
    end
    
    -- Extract right section
    if graphical_set.right then
        result.right = SpriteDebugger.extract_sprite_info(graphical_set.right)
    end
    
    return result
end

-- Extract information from a sprite definition
-- @param sprite table The sprite definition to extract information from
-- @return table Information about the sprite
function SpriteDebugger.extract_sprite_info(sprite)
    local info = {}
    
    -- Copy all fields that may be present
    info.filename = sprite.filename
    info.position = sprite.position
    info.size = sprite.size or {sprite.width, sprite.height}
    info.tint = sprite.tint
    
    return info
end

-- This function will create the debugging sprites in the runtime
function SpriteDebugger.show_button_sprite_sections(parent, style_data)
    -- Create a sprite viewer for the button style
    local viewer = SpriteDebugger.create_sprite_viewer(parent, "button_style")
    
    -- Add sections for each button state
    local default_section = SpriteDebugger.add_section(viewer, "default", "Default Button State")
    local hover_section = SpriteDebugger.add_section(viewer, "hover", "Hovered Button State")
    local clicked_section = SpriteDebugger.add_section(viewer, "clicked", "Clicked Button State")
    
    -- If we have style data, add all the sprite sections
    if style_data then
        if style_data.default_graphical_set then
            local set = style_data.default_graphical_set
            
            -- Add base section if present
            if set.base then
                SpriteDebugger.add_sprite(default_section, "default_base", "Base", set.base)
            end
            
            -- Add right/arrow section if present
            if set.right then
                SpriteDebugger.add_sprite(default_section, "default_right", "Right Taper", set.right)
            end
            
            -- Add shadow section if present
            if set.shadow then
                SpriteDebugger.add_sprite(default_section, "default_shadow", "Shadow", set.shadow)
            end
        end
        
        if style_data.hovered_graphical_set then
            local set = style_data.hovered_graphical_set
            
            -- Add base section if present
            if set.base then
                SpriteDebugger.add_sprite(hover_section, "hover_base", "Base", set.base)
            end
            
            -- Add right/arrow section if present
            if set.right then
                SpriteDebugger.add_sprite(hover_section, "hover_right", "Right Taper", set.right)
            end
            
            -- Add shadow section if present
            if set.shadow then
                SpriteDebugger.add_sprite(hover_section, "hover_shadow", "Shadow", set.shadow)
            end
        end
        
        if style_data.clicked_graphical_set then
            local set = style_data.clicked_graphical_set
            
            -- Add base section if present
            if set.base then
                SpriteDebugger.add_sprite(clicked_section, "clicked_base", "Base", set.base)
            end
            
            -- Add right/arrow section if present
            if set.right then
                SpriteDebugger.add_sprite(clicked_section, "clicked_right", "Right Taper", set.right)
            end
            
            -- Add shadow section if present
            if set.shadow then
                SpriteDebugger.add_sprite(clicked_section, "clicked_shadow", "Shadow", set.shadow)
            end
        end
    end
end

return SpriteDebugger
