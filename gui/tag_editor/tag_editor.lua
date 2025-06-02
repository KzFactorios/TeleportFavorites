--[[
Tag Editor GUI for TeleportFavorites
====================================
Module: gui/tag_editor/tag_editor.lua

Provides the modal Tag Editor interface for creating and editing map tags in the TeleportFavorites mod.

Features:
- Modal dialog for editing tag icon, text, and actions (move, delete, teleport, favorite, confirm, cancel).
- Ownership and favorite state logic for enabling/disabling controls.
- Error message display and move mode visual feedback.
- Modularized UI construction for maintainability and clarity.
- Vanilla dialog structure: uses a 'inside_shallow_frame' for the outer frame, a 'frame_titlebar' for the title bar (with draggable grip), and a close button handled by event logic.
- Sets player.opened for modal/ESC support; titlebar is draggable and visually matches vanilla Factorio dialogs.

Main Functions:
- tag_editor.build(player, tag_data, editor_target_position):
    Constructs and returns the tag editor modal frame for the given player and tag data.
    Handles all UI element creation, state logic, tooltips, error display, and move mode visuals.
    The tag_editor is always presented in the player.gui.screen.

- tag_editor.build_confirmation_dialog(player, opts):
    Shows a modal confirmation dialog for destructive actions (e.g., tag deletion).

- setup_tag_editor_ui(refs, tag_data, player):
    Sets state, tooltips, and styles for all controls after construction.
--]]
local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Helpers = require("core.utils.helpers_suite")
local SpriteEnum = require("gui.sprite_enum")
local GPS = require("core.gps.gps")

local tag_editor = {}

local factorio_label_color = { r = 1, b = 0.79, g = .93, a = 1 } -- rgb(244,222,186) rbg = { r = 0.96, b = 0.73, g = .87, a = 1 } - needs to be lighter

-- Sets up the tag editor UI, including all controls and their state
-- This function now only sets state, tooltips, and styles. It does NOT create any elements.
local function setup_tag_editor_ui(refs, tag_data, player)
    -- Only set button state for elements that exist in refs
    if refs.icon_btn then Helpers.set_button_state(refs.icon_btn, true) end
    if refs.teleport_btn then Helpers.set_button_state(refs.teleport_btn, true) end
    if refs.favorite_btn then Helpers.set_button_state(refs.favorite_btn, true) end
    if refs.rich_text_input then Helpers.set_button_state(refs.rich_text_input, true) end
    if refs.rich_text_icon_btn then Helpers.set_button_state(refs.rich_text_icon_btn, true) end
    -- Add more as needed for your current refs structure

    -- Button style/tooltips
    if refs.icon_btn then refs.icon_btn.tooltip = { "tf-gui.icon_tooltip" } end
    if refs.text_input then refs.text_input.tooltip = { "tf-gui.text_tooltip" } end
    if refs.move_btn then refs.move_btn.tooltip = { "tf-gui.move_tooltip" } end
    if refs.delete_btn then refs.delete_btn.tooltip = { "tf-gui.delete_tooltip" } end
    if refs.teleport_btn then refs.teleport_btn.tooltip = { "tf-gui.teleport_tooltip" } end
    if refs.favorite_btn then refs.favorite_btn.tooltip = { "tf-gui.favorite_tooltip" } end
    if refs.confirm_btn then refs.confirm_btn.tooltip = { "tf-gui.confirm_tooltip" } end
    if refs.cancel_btn then refs.cancel_btn.tooltip = { "tf-gui.cancel_tooltip" } end
    -- Move mode visual
    if refs.inner then
        if tag_data.move_mode then
            refs.inner.tooltip = { "tf-gui.move_mode_active" }
        else
            refs.inner.tooltip = nil
        end
    end
    local error_label = refs.error_label
    if error_label then
        error_label.caption = tag_data.error_message or ""
        error_label.visible = (tag_data.error_message ~= nil and tag_data.error_message ~= "") and true or false
    end
end

-- Confirmation dialog for destructive actions (e.g., tag deletion)
function tag_editor.build_confirmation_dialog(player, opts)
    -- opts: { message, on_confirm, on_cancel, parent_frame_name }
    local parent = player.gui.screen
    local frame = GuiBase.create_frame(parent, "tf_confirm_dialog_frame", "vertical", "inside_shallow_frame_with_padding")
    frame.auto_center = true
    GuiBase.create_label(frame, "tag_editor_tf_confirm_dialog_label", opts.message or { "tf-gui.confirm_delete_message" },
        "bold_label")
    local tag_editor_tf_confirm_dialog_btn_row = GuiBase.create_hflow(frame, "tag_editor_tf_confirm_dialog_btn_row")
    local confirm_btn = Helpers.create_slot_button(tag_editor_tf_confirm_dialog_btn_row, "tf_confirm_dialog_confirm_btn",
        SpriteEnum.CHECK_MARK, { "tf-gui.confirm_delete_confirm" })
    local cancel_btn = Helpers.create_slot_button(tag_editor_tf_confirm_dialog_btn_row, "tf_confirm_dialog_cancel_btn",
        SpriteEnum.CLOSE, { "tf-gui.confirm_delete_cancel" })
    -- Set modal/ESC behavior
    player.opened = frame
    return frame, confirm_btn, cancel_btn
end

-- Main builder for the tag editor, matching the full semantic/nested structure from notes/tag_editor.md
---
--- @param player LuaPlayer
--- @param tag_data Tag|nil
function tag_editor.build(player, tag_data)
    if not player then error("tag_editor.build: player is required") end
    if not tag_data then tag_data = {} end
    local last_user = tag_data.last_user or ""
    local line_height = 44
    -- Store the editor position for use in the editor (from map right-click or fave bar)
    local editor_gps = tag_data.gps
    local editor_target_position = GPS.map_position_from_gps(editor_gps)
    local editor_coords_string = GPS.coords_string_from_gps(editor_gps)


    local parent = player.gui.screen
    if parent["tag_editor_outer_frame"] then
        parent["tag_editor_outer_frame"].destroy()
    end
    local tag_editor_outer_frame = GuiBase.create_frame(parent, "tag_editor_outer_frame", "vertical", "tf_tag_editor_outer_frame")
    tag_editor_outer_frame.auto_center = true


    -- title bar
    local tag_editor_titlebar = GuiBase.create_titlebar(tag_editor_outer_frame, "tag_editor_titlebar",
        { "tf-gui.tag_editor_title_text" },
        "tag_editor_title_row_close")
    -- Make the dialog draggable by setting the draggable target to the titlebar's draggable space
    local draggable = tag_editor_titlebar["title_bar_draggable"]
    if draggable then
        draggable.drag_target = tag_editor_outer_frame
    end


    -- inner frame
    local tag_editor_inner_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_inner_frame", "vertical", "tf_tag_editor_inner_frame")


    -- Content background
    local tag_editor_content_frame = GuiBase.create_frame(tag_editor_inner_frame, "tag_editor_content_frame", "vertical", "tf_tag_editor_content_frame")


    -- Last user row (horizontal flow)
    local tag_editor_last_user_row
    do
        tag_editor_last_user_row = GuiBase.create_frame(tag_editor_content_frame, "tag_editor_last_user_row", "horizontal", "tf_last_user_row")
        local label_text = { "tf-gui.last_user_label", tag_data.last_user or "" }
        local label = GuiBase.create_label(tag_editor_last_user_row, "tag_editor_last_user_label", label_text, "tf_tag_editor_label")
        label.style.font_color = factorio_label_color
    end


    -- Content inner frame (vertical)
    local tag_editor_content_inner_frame = GuiBase.create_frame(tag_editor_content_frame,
        "tag_editor_content_inner_frame", "vertical", "tf_tag_editor_content_inner_frame")

    -- Teleport+Favorite row (favorite button at head, no labels)
    local tag_editor_teleport_favorite_row, tag_editor_is_favorite_button, tag_editor_teleport_button
    do
        local teleport_tooltip = { "tf-gui.teleport_tooltip" }
        local favorite_tooltip = { "tf-gui.favorite_tooltip" }
        tag_editor_teleport_favorite_row = GuiBase.create_hflow(tag_editor_content_inner_frame,
            "tag_editor_teleport_favorite_row", "tf_tag_editor_teleport_favorite_row")
        tag_editor_teleport_favorite_row.style.height = line_height
        tag_editor_teleport_button = GuiBase.create_icon_button(tag_editor_teleport_favorite_row,
            "tag_editor_teleport_button", "", { "tf-gui.teleport_tooltip" }, "tf_teleport_button")
        tag_editor_teleport_button.caption = editor_coords_string
        tag_editor_is_favorite_button = GuiBase.create_icon_button(tag_editor_teleport_favorite_row,
            "tag_editor_is_favorite_button", "utility/check_mark", { "tf-gui.favorite_tooltip" }, "tf_slot_button")
    end

    -- Rich Text row
    local tag_editor_rich_text_row, tag_editor_icon_button, tag_editor_rich_text_input, tag_editor_rich_text_icon_button
    do
        local icon_tooltip = { "tf-gui.icon_tooltip" }
        local insert_icon_tooltip = { "tf-gui.insert_icon_tooltip" }
        tag_editor_rich_text_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_rich_text_row")

        tag_editor_icon_button = GuiBase.create_icon_button(tag_editor_rich_text_row, "tag_editor_icon_button",
            tag_data.icon or "", icon_tooltip, "tf_slot_button")
        tag_editor_rich_text_input = GuiBase.create_textfield(tag_editor_rich_text_row, "tag_editor_rich_text_input",
            tag_data.rich_text or "", nil)
        tag_editor_rich_text_icon_button = GuiBase.create_icon_button(tag_editor_rich_text_row,
            "tag_editor_rich_text_icon_button", SpriteEnum.INSERT_RICH_TEXT_ICON, { "tf-gui.insert_icon_tooltip" },
            "tf_insert_rich_text_button")
    end


    -- Error row
    local tag_editor_error_row_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_error_row_frame",
        "vertical")
    local error_row_inner_frame = GuiBase.create_frame(tag_editor_error_row_frame, "error_row_inner_frame", "vertical",
        "invisible_frame")
    local error_row_error_message = GuiBase.create_label(error_row_inner_frame, "error_row_error_message",
        tag_data.error_message or "")




    -- Last row (confirm/cancel) - move to outer frame (after inner frame)
    local tag_editor_last_row = GuiBase.create_hflow(tag_editor_outer_frame, "tag_editor_last_row")
    local cancel_tooltip = { "tf-gui.cancel_tooltip" }
    local confirm_tooltip = { "tf-gui.confirm_tooltip" }
    local last_row_cancel_button = GuiBase.create_icon_button(tag_editor_last_row, "last_row_cancel_button",
        "utility/close", { "tf-gui.cancel_tooltip" }, "tf_slot_button")
    local last_row_confirm_button = GuiBase.create_icon_button(tag_editor_last_row, "last_row_confirm_button",
        "utility/check_mark", { "tf-gui.confirm_tooltip" }, "tf_confirm_button")


    -- Build refs table for event handlers and logic
    local refs = {
        last_user_row = tag_editor_last_user_row,
        teleport_favorite_row = tag_editor_teleport_favorite_row,
        teleport_btn = tag_editor_teleport_button,
        favorite_btn = tag_editor_is_favorite_button,
        rich_text_row = tag_editor_rich_text_row,
        icon_btn = tag_editor_icon_button,
        rich_text_input = tag_editor_rich_text_input,
        rich_text_icon_btn = tag_editor_rich_text_icon_button,
        editor_position = editor_target_position,
        editor_gps = editor_gps
        -- ...other refs as needed...
    }

    setup_tag_editor_ui(refs, tag_data, player)
    if tag_editor_outer_frame and player and player.valid then
        player.opened = tag_editor_outer_frame
    end
    return refs
end

local function find_child_by_name(element, name)
    return Helpers.find_child_by_name(element, name)
end

return tag_editor
