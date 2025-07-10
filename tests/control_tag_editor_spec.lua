-- tests/control/control_tag_editor_spec.lua

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end

-- Clear any existing mocks and force reload of the module
package.loaded["core.control.control_tag_editor"] = nil

describe("TagEditor", function()
    local TagEditor, mock_player, mock_event, mock_element, mock_surface
    local Cache, GuiValidation, SmallHelpers, ErrorHandler
    
    before_each(function()
        -- Load required modules for mocking
        Cache = require("core.cache.cache")
        GuiValidation = require("core.utils.gui_validation")
        SmallHelpers = require("core.utils.small_helpers")
        ErrorHandler = require("core.utils.error_handler")
        
        -- Mock defines.events
        _G.defines = {
            events = {
                on_player_selected_area = 1,
                on_player_alt_selected_area = 2
            }
        }
        
        -- Mock GUI validation functions
        spy.on(GuiValidation, "safe_destroy_frame")
        
        -- Mock error handler functions
        spy.on(ErrorHandler, "warn_log")
        
        -- Mock small helpers functions  
        spy.on(SmallHelpers, "update_error_message")
        spy.on(SmallHelpers, "update_state")
        
        -- Create mock surface
        mock_surface = {
            index = 1,
            name = "nauvis",
            valid = true
        }
        
        -- Create mock GUI element
        mock_element = {
            valid = true,
            name = "tag_editor_confirm_button",
            text = "Test text",
            elem_value = "test-icon"
        }
        
        -- Create mock player with GUI
        mock_player = {
            index = 1,
            name = "test_player",
            valid = true,
            surface = mock_surface,
            clear_cursor = spy.new(function() end),
            teleport = spy.new(function() return true end),
            admin = false,
            gui = {
                screen = {
                    tag_editor_frame = mock_element
                }
            }
        }
        
        -- Create mock event
        mock_event = {
            element = mock_element,
            player_index = 1,
            text = "Test text"
        }
        
        -- Mock global game object
        _G.game = {
            get_player = function(index) return mock_player end,
            tick = 1000
        }
        
        -- Mock tag_editor module functions
        local tag_editor_mock = {
            update_error_message = spy.new(function() end),
            update_confirm_button_state = spy.new(function() end),
            close = spy.new(function() end)
        }
        package.loaded["gui.tag_editor.tag_editor"] = tag_editor_mock
        
        -- Now load the TagEditor module after mocks are set up
        TagEditor = require("core.control.control_tag_editor")
        
        -- Set up default tag_editor_data in cache
        local default_tag_data = {
            gps = "001.002.nauvis",
            text = "Test Tag",
            icon = "test-icon",
            is_favorite = false,
            move_mode = false,
            delete_mode = false,
            error_message = ""
        }
        Cache.set_tag_editor_data(mock_player, default_tag_data)
    end)
    
    after_each(function()
        -- Revert spies
        GuiValidation.safe_destroy_frame:revert()
        ErrorHandler.warn_log:revert()
        SmallHelpers.update_error_message:revert()
        SmallHelpers.update_state:revert()
        
        -- Clear cache
        _G.storage = {}
    end)

    describe("module structure", function()
        it("should be a table/module", function()
            assert.is_table(TagEditor)
        end)
        
        it("should export the required functions", function()
            assert.is_function(TagEditor.close_tag_editor)
            assert.is_function(TagEditor.on_tag_editor_gui_click)
            assert.is_function(TagEditor.on_tag_editor_gui_text_changed)
            assert.is_function(TagEditor.on_tag_editor_gui_elem_changed)
        end)
    end)

    describe("close_tag_editor", function()
        it("should close the tag editor for a valid player", function()
            TagEditor.close_tag_editor(mock_player)
            
            assert.spy(GuiValidation.safe_destroy_frame).was_called()
        end)
        
        it("should handle move mode cleanup", function()
            -- Set up move mode
            local tag_data = Cache.get_tag_editor_data(mock_player)
            tag_data.move_mode = true
            Cache.set_tag_editor_data(mock_player, tag_data)
            
            TagEditor.close_tag_editor(mock_player)
            
            assert.spy(mock_player.clear_cursor).was_called()
        end)
        
        it("should handle invalid player gracefully", function()
            local invalid_player = { valid = false, gui = { screen = {} }, opened = nil }
            
            -- Should not throw error
            TagEditor.close_tag_editor(invalid_player)
        end)
    end)

    describe("on_tag_editor_gui_click", function()
        it("should handle close button click", function()
            mock_element.name = "tag_editor_title_row_close"
            
            TagEditor.on_tag_editor_gui_click(mock_event, nil)
            
            assert.spy(GuiValidation.safe_destroy_frame).was_called()
        end)
        
        it("should handle confirm button click", function()
            mock_element.name = "tag_editor_confirm_button"
            
            TagEditor.on_tag_editor_gui_click(mock_event, nil)
            
            -- Should not throw error (might close editor internally)
        end)
        
        it("should return early for invalid element", function()
            mock_event.element = nil
            
            TagEditor.on_tag_editor_gui_click(mock_event, nil)
            
            -- Should handle gracefully without calling GUI functions
        end)
        
        it("should return early for invalid player", function()
            _G.game.get_player = function() return nil end
            
            TagEditor.on_tag_editor_gui_click(mock_event, nil)
            
            -- Should handle gracefully
        end)
        
        it("should handle non-tag-editor elements", function()
            mock_element.name = "some_other_button"
            
            TagEditor.on_tag_editor_gui_click(mock_event, nil)
            
            -- Should not perform tag editor specific actions
        end)
    end)

    describe("on_tag_editor_gui_text_changed", function()
        it("should handle text input changes", function()
            mock_element.name = "tag_editor_rich_text_input"
            mock_element.text = "New tag text"
            
            TagEditor.on_tag_editor_gui_text_changed(mock_event)
            
            -- Should process the text change
        end)
        
        it("should return early for non-tag-editor elements", function()
            mock_element.name = "some_other_element"
            
            TagEditor.on_tag_editor_gui_text_changed(mock_event)
            
            -- Should not process non-tag-editor elements
        end)
        
        it("should handle invalid element gracefully", function()
            mock_event.element = nil
            
            TagEditor.on_tag_editor_gui_text_changed(mock_event)
            
            -- Should handle gracefully
        end)
        
        it("should handle invalid player gracefully", function()
            mock_element.name = "tag_editor_rich_text_input"
            _G.game.get_player = function() return nil end
            
            TagEditor.on_tag_editor_gui_text_changed(mock_event)
            
            -- Should handle gracefully
        end)
    end)

    describe("on_tag_editor_gui_elem_changed", function()
        it("should handle icon button changes", function()
            mock_element.name = "tag_editor_icon_button"
            mock_element.elem_value = "new-test-icon"
            
            TagEditor.on_tag_editor_gui_elem_changed(mock_event)
            
            -- Should process the element change
        end)
        
        it("should return early for non-tag-editor elements", function()
            mock_element.name = "some_other_element"
            
            TagEditor.on_tag_editor_gui_elem_changed(mock_event)
            
            -- Should not process non-tag-editor elements
        end)
        
        it("should handle invalid element gracefully", function()
            mock_event.element = nil
            
            TagEditor.on_tag_editor_gui_elem_changed(mock_event)
            
            -- Should handle gracefully
        end)
        
        it("should handle invalid player gracefully", function()
            mock_element.name = "tag_editor_icon_button"
            _G.game.get_player = function() return nil end
            
            TagEditor.on_tag_editor_gui_elem_changed(mock_event)
            
            -- Should handle gracefully
        end)
    end)
end)
