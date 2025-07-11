-- tests/gui_base_spec.lua

-- Load ONLY the test framework - no bootstrap
require("tests.test_framework")

-- Store the original require function
local original_require = require

-- Temporarily override require to get the real GuiBase module
local function get_real_module(name)
    -- Bypass any mocking for this specific module load
    return original_require(name)
end

-- Directly load the real GuiBase module
local GuiBase = get_real_module("gui.gui_base")

-- Simple verification that we have the real module
print("[DEBUG] GuiBase type:", type(GuiBase))
print("[DEBUG] GuiBase.create_element:", type(GuiBase.create_element))

-- The module should be available now

describe("GuiBase", function()
    local mock_parent

    before_each(function()
        -- Create a simple mock parent GUI element
        mock_parent = {
            add = function(params)
                -- Ensure params is never nil
                params = params or {}
                return {
                    type = params.type,
                    name = params.name,
                    caption = params.caption,
                    sprite = params.sprite,
                    tooltip = params.tooltip,
                    style = params.style,
                    direction = params.direction,
                    text = params.text or "",
                    icon_selector = params.icon_selector or false,
                    enabled = true,
                    valid = true,
                    parent = mock_parent
                }
            end,
            valid = true,
            name = "test_parent"
        }
    end)

    describe("module structure", function()
        it("should be a table", function()
            is_true(type(GuiBase) == "table", "GuiBase should be a table")
        end)

        it("should have all expected functions", function()
            is_true(type(GuiBase.create_element) == "function", "create_element should be a function")
            is_true(type(GuiBase.create_frame) == "function", "create_frame should be a function")
            is_true(type(GuiBase.create_icon_button) == "function", "create_icon_button should be a function")
            is_true(type(GuiBase.create_sprite_button) == "function", "create_sprite_button should be a function")
            is_true(type(GuiBase.create_label) == "function", "create_label should be a function")
            is_true(type(GuiBase.create_button) == "function", "create_button should be a function")
            is_true(type(GuiBase.create_hflow) == "function", "create_hflow should be a function")
            is_true(type(GuiBase.create_vflow) == "function", "create_vflow should be a function")
            is_true(type(GuiBase.create_flow) == "function", "create_flow should be a function")
            is_true(type(GuiBase.create_draggable) == "function", "create_draggable should be a function")
            is_true(type(GuiBase.create_titlebar) == "function", "create_titlebar should be a function")
            is_true(type(GuiBase.create_textbox) == "function", "create_textbox should be a function")
            is_true(type(GuiBase.create_named_element) == "function", "create_named_element should be a function")
        end)
    end)

    describe("create_element", function()
        it("should create an element with basic properties", function()
            local element = GuiBase.create_element("label", mock_parent, { name = "test" })
            is_true(type(element) == "table", "element should be a table")
            are_same("label", element.type)
            are_same("test", element.name)
        end)

        it("should handle missing name by generating one", function()
            local element = GuiBase.create_element("button", mock_parent, {})
            is_true(type(element) == "table", "element should be a table")
            are_same("button", element.type)
            is_true(type(element.name) == "string", "name should be a string")
            is_true(element.name:find("button_unnamed_") == 1, "name should start with button_unnamed_")
        end)

        it("should handle missing parent by creating basic mock", function()
            local element = GuiBase.create_element("label", nil, { name = "test" })
            is_true(type(element) == "table", "should create element even with nil parent")
            are_same("test", element.name)
        end)
    end)

    describe("create_frame", function()
        it("should create a frame with default settings", function()
            local frame = GuiBase.create_frame(mock_parent, "test_frame", "horizontal")
            is_true(type(frame) == "table", "frame should be a table")
            are_same("frame", frame.type)
            are_same("test_frame", frame.name)
        end)
    end)

    describe("create_icon_button", function()
        it("should create an icon button", function()
            local button = GuiBase.create_icon_button(mock_parent, "test_btn", "test_sprite", "tooltip", "style")
            is_true(type(button) == "table", "button should be a table")
            are_same("sprite-button", button.type)
            are_same("test_btn", button.name)
            are_same("test_sprite", button.sprite)
        end)
    end)

    describe("create_label", function()
        it("should create a label", function()
            local label = GuiBase.create_label(mock_parent, "test_label", "Test Caption")
            is_true(type(label) == "table", "label should be a table")
            are_same("label", label.type)
            are_same("test_label", label.name)
            are_same("Test Caption", label.caption)
        end)
    end)

    describe("create_button", function()
        it("should create a button", function()
            local button = GuiBase.create_button(mock_parent, "test_button", "Click Me")
            is_true(type(button) == "table", "button should be a table")
            are_same("button", button.type)
            are_same("test_button", button.name)
            are_same("Click Me", button.caption)
        end)
    end)

    describe("create_hflow", function()
        it("should create a horizontal flow", function()
            local flow = GuiBase.create_hflow(mock_parent, "test_hflow")
            is_true(type(flow) == "table", "flow should be a table")
            are_same("flow", flow.type)
            are_same("test_hflow", flow.name)
            are_same("horizontal", flow.direction)
        end)
    end)

    describe("create_vflow", function()
        it("should create a vertical flow", function()
            local flow = GuiBase.create_vflow(mock_parent, "test_vflow")
            is_true(type(flow) == "table", "flow should be a table")
            are_same("flow", flow.type)
            are_same("test_vflow", flow.name)
            are_same("vertical", flow.direction)
        end)
    end)

    describe("create_flow", function()
        it("should create a flow with default horizontal direction", function()
            local flow = GuiBase.create_flow(mock_parent, "test_flow", "horizontal")
            is_true(type(flow) == "table", "flow should be a table")
            are_same("flow", flow.type)
            are_same("test_flow", flow.name)
            are_same("horizontal", flow.direction)
        end)
    end)

    describe("create_textbox", function()
        it("should create a textbox", function()
            local textbox = GuiBase.create_textbox(mock_parent, "test_textbox")
            is_true(type(textbox) == "table", "textbox should be a table")
            are_same("text-box", textbox.type)
            are_same("test_textbox", textbox.name)
        end)
    end)

    describe("create_named_element", function()
        it("should create a named element", function()
            -- Create mock parent for this test
            local mock_parent = {
                add = function(params)
                    params = params or {}
                    return {
                        type = params.type,
                        name = params.name,
                        caption = params.caption,
                        sprite = params.sprite,
                        tooltip = params.tooltip,
                        style = params.style,
                        direction = params.direction,
                        text = params.text or "",
                        icon_selector = params.icon_selector or false,
                        enabled = true,
                        valid = true,
                        parent = mock_parent
                    }
                end,
                valid = true,
                name = "test_parent"
            }
            
            local element = GuiBase.create_named_element("label", mock_parent, { name = "test_element" })
            is_true(element ~= nil, "element should not be nil")
            is_true(type(element) == "table", "element should be a table")
        end)

        it("should return nil for invalid parent", function()
            local element = GuiBase.create_named_element("label", nil, { name = "test_element" })
            is_nil(element)
        end)
    end)
end)
