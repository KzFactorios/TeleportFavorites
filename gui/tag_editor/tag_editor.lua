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
- tag_editor.build
    Constructs and returns the tag editor modal frame for the given player and tag data.
    Handles all UI element creation, state logic, tooltips, error display, and move mode visuals.
    The tag_editor is always presented in the player.gui.screen.

- tag_editor.build_confirmation_dialog
    Shows a modal confirmation dialog for destructive actions (e.g., tag deletion).

- setup_tag_editor_ui(refs, tag_data, player):
    Sets state, tooltips, and styles for all controls after construction.
--]]
local GuiBase = require("gui.gui_base")
local Helpers = require("core.utils.helpers_suite")
local BasicHelpers = require("core.utils.basic_helpers")
local Enum = require("prototypes.enums.enum")
local GPS = require("core.gps.gps")
local Cache = require("core.cache.cache")

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
        Enum.SpriteEnum.CHECK_MARK, { "tf-gui.confirm_delete_confirm" })
    local cancel_btn = Helpers.create_slot_button(tag_editor_tf_confirm_dialog_btn_row, "tf_confirm_dialog_cancel_btn",
        Enum.SpriteEnum.CLOSE, { "tf-gui.confirm_delete_cancel" })
    -- Set modal/ESC behavior
    player.opened = frame
    return frame, confirm_btn, cancel_btn
end

-- Modular builder functions for each section of the tag editor
local function build_titlebar(parent)
    local titlebar, title_label, _cb = GuiBase.create_titlebar(parent, "tag_editor_titlebar",
        "tag_editor_title_row_close")
    title_label.caption = { "tf-gui.tag_editor_title" } -- Set caption on the label, not the titlebar flow
    return titlebar, title_label
end

local function build_owner_row(parent, tag_data)
    -- Create a frame with a fixed height for the owner row
    local row_frame = GuiBase.create_frame(parent, "tag_editor_owner_row_frame", "horizontal", "tf_owner_row_frame") -- Create a horizontal flow for the label - this will take up all available space
    local label_flow = GuiBase.create_hflow(row_frame, "tag_editor_label_flow")

    -- Create the label within the flow - it will stretch with its container
    local label = GuiBase.create_label(label_flow, "tag_editor_owner_label",
        "", "tf_tag_editor_owner_label") -- Create a flow for the buttons
    label.caption = { "tf-gui.tag_editor_title" }

    local button_flow = GuiBase.create_hflow(row_frame, "tag_editor_button_flow") -- Add buttons to the button flow
    local move_button = GuiBase.create_icon_button(button_flow, "tag_editor_move_button", Enum.SpriteEnum.MOVE,
        nil, "tf_move_button")
    local delete_button = GuiBase.create_icon_button(button_flow, "tag_editor_delete_button", Enum.SpriteEnum.TRASH,
        nil, "tf_delete_button")

    return row_frame, label, move_button, delete_button
end




local function build_teleport_favorite_row(parent, tag_data)
    -- Style must be set at creation time for Factorio GUIs
    local row = GuiBase.create_frame(parent, "tag_editor_teleport_favorite_row", "horizontal",
        "tf_tag_editor_teleport_favorite_row")



    local star_state = (tag_data and tag_data.is_favorite and tag_data.is_favorite ~= nil and tag_data.is_favorite and Enum.SpriteEnum.STAR) or
        Enum.SpriteEnum.STAR_DISABLED

    local fave_style = tag_data.is_favorite and "slot_orange_favorite_on" or "slot_orange_favorite_off"


    local favorite_btn = GuiBase.create_icon_button(row, "tag_editor_is_favorite_button", star_state,
        nil, fave_style)







    local teleport_btn = GuiBase.create_icon_button(row, "tag_editor_teleport_button", "",
        nil,
        "tf_teleport_button")
    teleport_btn.caption = tag_data.gps or "no destination"
    return row, favorite_btn, teleport_btn
end










local function build_rich_text_row(parent, tag_data)
    local row = GuiBase.create_hflow(parent, "tag_editor_rich_text_row")
    local icon_btn = GuiBase.create_element("choose-elem-button", row,
        {
            name = "tag_editor_icon_button",
            tooltip = { "tf-gui.icon_tooltip" },
            style = "tf_slot_button",
            elem_type = "signal",
            signal = tag_data.icon or ""
        })
    -- Use the new textbox with icon_selector = true
    local text_input = GuiBase.create_textbox(row, "tag_editor_rich_text_input",
        tag_data.rich_text or "", "tf_tag_editor_text_input", true)
    return row, icon_btn, text_input
end

local function build_error_row(parent, tag_data)
    local error_row_frame, error_label = nil, nil
    if tag_data and tag_data.error_message and tag_data.error_message ~= nil and BasicHelpers.trim(tag_data.error_message) ~= "" then
        error_row_frame = GuiBase.create_frame(parent, "tag_editor_error_row_frame", "vertical",
            "tf_tag_editor_error_row_frame")
        error_label = GuiBase.create_label(error_row_frame, "error_row_error_message", tag_data.error_message or "",
            "tf_tag_editor_error_label")
    end
    return error_row_frame, error_label
end

local function build_last_row(parent)
    local row = GuiBase.create_hflow(parent, "tag_editor_last_row")
    row.style = "tf_tag_editor_last_row"

    -- Create draggable space directly with correct style instead of using GuiBase.create_draggable
    local draggable = row.add {
        type = "empty-widget",
        name = "tag_editor_last_row_draggable",
        style = "tf_tag_editor_last_row_draggable"
    }

    -- Set drag target for the draggable space
    local drag_target = Helpers.get_gui_frame_by_element(parent)
    if drag_target and drag_target.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
        draggable.drag_target = drag_target
    end

    local confirm_btn = GuiBase.create_element('button', row, {
        name = "last_row_confirm_button",
        caption = { "tf-gui.confirm" },
        tooltip = { "tf-gui.confirm_tooltip" },
        style = "tf_confirm_button",
        sprite = nil
    })
    return row, confirm_btn
end

-- Main builder for the tag editor, matching the full semantic/nested structure from notes/tag_editor.md
---
--- @param player LuaPlayer
--- @param tag_data table|nil
function tag_editor.build(player, tag_data)
    if not player then error("tag_editor.build: player is required") end
    -- if we were given data then fine, otherwise get from storage
    if not tag_data then tag_data = Cache.get_player_data(player).tag_editor_data end

    local editor_gps = tag_data.gps
    local editor_target_position = GPS.map_position_from_gps(editor_gps)
    local editor_coords_string = GPS.coords_string_from_gps(editor_gps)

    local parent = player.gui.screen
    local outer = nil
    for _, child in pairs(parent.children) do
        if child.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
            outer = child
            break
        end
    end
    if outer ~= nil then outer.destroy() end

    local tag_editor_outer_frame = GuiBase.create_frame(parent, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR, "vertical",
        "tf_tag_editor_outer_frame")
    tag_editor_outer_frame.auto_center = true
    local titlebar, title_label = build_titlebar(tag_editor_outer_frame)
    -- Caption is already set in build_titlebar function

    local tag_editor_content_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_content_frame", "vertical",
        "tf_tag_editor_content_frame")
    local tag_editor_owner_row, owner_label, _move_button, _delete_button = build_owner_row(tag_editor_content_frame,
        tag_data)
    owner_label.caption = { "tf-gui.owner_label", player.name }

    local tag_editor_content_inner_frame = GuiBase.create_frame(tag_editor_content_frame,
        "tag_editor_content_inner_frame", "vertical", "tf_tag_editor_content_inner_frame")
    local tag_editor_teleport_favorite_row, tag_editor_is_favorite_button, tag_editor_teleport_button =
        build_teleport_favorite_row(tag_editor_content_inner_frame, tag_data)
    local tag_editor_rich_text_row, tag_editor_icon_button, tag_editor_rich_text_input =
        build_rich_text_row(tag_editor_content_inner_frame, tag_data)

    local tag_editor_error_row_frame, error_row_error_message = build_error_row(tag_editor_outer_frame, tag_data)
    local tag_editor_last_row, last_row_confirm_button = build_last_row(tag_editor_outer_frame)

    local refs = {
        titlebar = titlebar,
        owner_row = tag_editor_owner_row,
        teleport_favorite_row = tag_editor_teleport_favorite_row,
        teleport_btn = tag_editor_teleport_button,
        favorite_btn = tag_editor_is_favorite_button,
        rich_text_row = tag_editor_rich_text_row,
        icon_btn = tag_editor_icon_button,
        rich_text_input = tag_editor_rich_text_input,
        error_label = error_row_error_message,
        confirm_btn = last_row_confirm_button,
        editor_position = editor_target_position,
        tag_editor_error_row_frame = tag_editor_error_row_frame,
        tag_editor_last_row = tag_editor_last_row,
        editor_gps = editor_gps
    }

    setup_tag_editor_ui(refs, tag_data, player)

    player.opened = tag_editor_outer_frame or nil

    return refs
end

local function find_child_by_name(element, name)
    return Helpers.find_child_by_name(element, name)
end

-- NOTE: The built-in Factorio signal/icon picker (used for icon selection) always requires the user to confirm their selection with a checkmark button. There is no property or style that allows auto-accepting the selection on click; this is a limitation of the Factorio engine as of 1.1.x.

return tag_editor
