-- tests/gui_base_spec.lua

require("tests.test_bootstrap")

-- Clear any mock and force load the real gui_base module for coverage testing
package.loaded["gui.gui_base"] = nil
local GuiBase = require("gui.gui_base")

-- Add a simple check to see if we're loading real vs mock
if not GuiBase.create_element then
    error("gui_base_spec: loaded mock instead of real GuiBase module!")
end

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
            assert.is_table(GuiBase)
        end)

        it("should have all expected functions", function()
            assert.is_function(GuiBase.create_element)
            assert.is_function(GuiBase.create_frame)
            assert.is_function(GuiBase.create_icon_button)
            assert.is_function(GuiBase.create_sprite_button)
            assert.is_function(GuiBase.create_label)
            assert.is_function(GuiBase.create_button)
            assert.is_function(GuiBase.create_hflow)
            assert.is_function(GuiBase.create_vflow)
            assert.is_function(GuiBase.create_flow)
            assert.is_function(GuiBase.create_draggable)
            assert.is_function(GuiBase.create_titlebar)
            assert.is_function(GuiBase.create_textbox)
            assert.is_function(GuiBase.create_named_element)
        end)
    end)

    describe("create_element", function()
        it("should create an element with basic properties", function()
            local element = GuiBase.create_element("label", mock_parent, { name = "test" })
            assert.is_table(element)
            assert.equals("label", element.type)
            assert.equals("test", element.name)
        end)

        it("should handle missing name by generating one", function()
            local element = GuiBase.create_element("button", mock_parent, {})
            assert.is_table(element)
            assert.equals("button", element.type)
            assert.is_string(element.name)
            assert.is_true(element.name:find("button_unnamed_") == 1)
        end)

        it("should throw error for invalid parent", function()
            assert.has_error(function()
                GuiBase.create_element("label", nil, { name = "test" })
            end)
        end)
    end)

    describe("create_frame", function()
        it("should create a frame with default settings", function()
            local frame = GuiBase.create_frame(mock_parent, "test_frame")
            assert.is_table(frame)
            assert.equals("frame", frame.type)
            assert.equals("test_frame", frame.name)
        end)
    end)

    describe("create_icon_button", function()
        it("should create an icon button", function()
            local button = GuiBase.create_icon_button(mock_parent, "test_btn", "test_sprite")
            assert.is_table(button)
            assert.equals("sprite-button", button.type)
            assert.equals("test_btn", button.name)
            assert.equals("test_sprite", button.sprite)
        end)
    end)

    describe("create_label", function()
        it("should create a label", function()
            local label = GuiBase.create_label(mock_parent, "test_label", "Test Caption")
            assert.is_table(label)
            assert.equals("label", label.type)
            assert.equals("test_label", label.name)
            assert.equals("Test Caption", label.caption)
        end)
    end)

    describe("create_button", function()
        it("should create a button", function()
            local button = GuiBase.create_button(mock_parent, "test_button", "Click Me")
            assert.is_table(button)
            assert.equals("button", button.type)
            assert.equals("test_button", button.name)
            assert.equals("Click Me", button.caption)
        end)
    end)

    describe("create_hflow", function()
        it("should create a horizontal flow", function()
            local flow = GuiBase.create_hflow(mock_parent, "test_hflow")
            assert.is_table(flow)
            assert.equals("flow", flow.type)
            assert.equals("test_hflow", flow.name)
            assert.equals("horizontal", flow.direction)
        end)
    end)

    describe("create_vflow", function()
        it("should create a vertical flow", function()
            local flow = GuiBase.create_vflow(mock_parent, "test_vflow")
            assert.is_table(flow)
            assert.equals("flow", flow.type)
            assert.equals("test_vflow", flow.name)
            assert.equals("vertical", flow.direction)
        end)
    end)

    describe("create_flow", function()
        it("should create a flow with default horizontal direction", function()
            local flow = GuiBase.create_flow(mock_parent, "test_flow")
            assert.is_table(flow)
            assert.equals("flow", flow.type)
            assert.equals("test_flow", flow.name)
            assert.equals("horizontal", flow.direction)
        end)
    end)

    describe("create_textbox", function()
        it("should create a textbox", function()
            local textbox = GuiBase.create_textbox(mock_parent, "test_textbox")
            assert.is_table(textbox)
            assert.equals("text-box", textbox.type)
            assert.equals("test_textbox", textbox.name)
        end)
    end)

    describe("create_named_element", function()
        it("should create a named element", function()
            local element = GuiBase.create_named_element("label", mock_parent, { name = "test_element" })
            assert.is_table(element)
        end)

        it("should return nil for invalid parent", function()
            local element = GuiBase.create_named_element("label", nil, { name = "test_element" })
            assert.is_nil(element)
        end)
    end)
end)
