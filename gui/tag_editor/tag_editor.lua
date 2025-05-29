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
- tag_editor.build(player, tag_data):
    Constructs and returns the tag editor modal frame for the given player and tag data.
    Handles all UI element creation, state logic, tooltips, error display, and move mode visuals.
    The tag_editor is always presented in the player.gui.screen.

Internal Helpers:
- build_outer_frame(parent): Creates the modal dialog frame 
- build_inner_frame(outer): Creates the inner content frame.
- build_titlebar(inner): Creates a vanilla-style title bar (frame with 'frame_titlebar' style, label, draggable grip, and close button).
- build_content_frames, build_last_user_row, build_teleport_row, build_favorite_row, build_icon_row, build_text_row, build_error_row, build_last_row: Modular UI element builders for each row/section.
- setup_tag_editor_ui: Sets state, tooltips, and styles for all controls.
--]]
local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Helpers = require("core.utils.helpers_suite")
local SpriteEnum = require("gui.sprite_enum")

local tag_editor = {}

-- Creates the icon selector button for the tag editor
local function build_icon_selector(frame, tag_data)
    return GuiBase.create_icon_button(frame, "tag_editor_icon_elem_btn", tag_data.icon or nil, { "tf-gui.icon_tooltip" },
        "tf_slot_button")
end

-- Creates the text section (label and textfield) for the tag editor
local function build_text_section(frame, tag_data)
    GuiBase.create_label(frame, "tag_editor_text_label", { "tf-gui.text_label" })
    return GuiBase.create_textfield(frame, "tag_editor_textfield", "")
end

-- Creates the row of action buttons for the tag editor
local function build_button_row(frame, tag_data)
    local tag_editor_button_row = GuiBase.create_hflow(frame, "tag_editor_button_row")
    local style = "tf_slot_button"
    if tag_data and tag_data.move_mode then
        style = "tf_slot_button_dragged"
    elseif tag_data and tag_data.locked then
        style = "tf_slot_button_locked"
    end
    local tag_editor_move_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_move_btn", SpriteEnum.ENTER, { "tf-gui.move_tooltip" }, {style=style})
    local tag_editor_delete_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_delete_btn", SpriteEnum.TRASH, { "tf-gui.delete_tooltip" }, {style=style})
    local tag_editor_teleport_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_teleport_btn", SpriteEnum.ENTER, { "tf-gui.teleport_tooltip" }, {style=style})
    local tag_editor_favorite_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_favorite_btn", SpriteEnum.CHECK_MARK, { "tf-gui.favorite_tooltip" }, {style=style})
    local tag_editor_confirm_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_confirm_btn", {},
        { "tf-gui.confirm_tooltip" }, {style=style})
    local tag_editor_cancel_btn = Helpers.create_slot_button(tag_editor_button_row, "tag_editor_cancel_btn", SpriteEnum.CLOSE, { "tf-gui.cancel_tooltip" }, {style=style})
    return tag_editor_button_row, tag_editor_move_btn, tag_editor_delete_btn, tag_editor_teleport_btn, tag_editor_favorite_btn, tag_editor_confirm_btn, tag_editor_cancel_btn
end

-- Creates the error label for the tag editor
local function build_error_label(frame, message)
    return Helpers.show_error_label(frame, message or "")
end

-- Sets up the tag editor UI, including all controls and their state
-- This function now only sets state, tooltips, and styles. It does NOT create any elements.
local function setup_tag_editor_ui(refs, tag_data, player)
    local tag_editor_icon_elem_btn = refs.tag_editor_icon_elem_btn
    local tag_editor_move_btn = refs.tag_editor_move_btn
    local tag_editor_delete_btn = refs.tag_editor_delete_btn
    local tag_editor_teleport_btn = refs.tag_editor_teleport_btn
    local tag_editor_favorite_btn = refs.tag_editor_favorite_btn
    local tag_editor_textfield = refs.tag_editor_textfield
    local tag_editor_confirm_btn = refs.tag_editor_confirm_btn
    local tag_editor_cancel_btn = refs.tag_editor_cancel_btn
    local error_label = refs.error_label
    local frame = refs.inner or refs.outer
    local trimmed = (tag_data.text or ""):gsub("%s+$", "")
    local is_owner = not tag_data.last_user or tag_data.last_user == "" or (player and tag_data.last_user == player.name)
    local faved = tag_data.faved_by_players or {}
    local is_favorited_by_others = #faved > 1 or (#faved == 1 and player and faved[1] ~= player.index)

    Helpers.set_button_state(tag_editor_move_btn, is_owner)
    Helpers.set_button_state(tag_editor_delete_btn, is_owner and not is_favorited_by_others)
    Helpers.set_button_state(tag_editor_icon_elem_btn, is_owner)
    Helpers.set_button_state(tag_editor_textfield, is_owner)
    local max_faves = Constants.settings.MAX_FAVORITE_SLOTS or 10
    Helpers.set_button_state(tag_editor_favorite_btn, tag_data.is_favorite or ((tag_data.non_blank_faves or 0) < max_faves))
    Helpers.set_button_state(tag_editor_teleport_btn, true)
    Helpers.set_button_state(tag_editor_cancel_btn, true)
    Helpers.set_button_state(tag_editor_confirm_btn, not ((not tag_data.icon or tag_data.icon == "") and trimmed == ""))
    -- Button style/tooltips
    if tag_editor_icon_elem_btn then tag_editor_icon_elem_btn.tooltip = { "tf-gui.icon_tooltip" } end
    if tag_editor_textfield then tag_editor_textfield.tooltip = { "tf-gui.text_tooltip" } end
    if tag_editor_move_btn then tag_editor_move_btn.tooltip = { "tf-gui.move_tooltip" } end
    if tag_editor_delete_btn then tag_editor_delete_btn.tooltip = { "tf-gui.delete_tooltip" } end
    if tag_editor_teleport_btn then tag_editor_teleport_btn.tooltip = { "tf-gui.teleport_tooltip" } end
    if tag_editor_favorite_btn then tag_editor_favorite_btn.tooltip = { "tf-gui.favorite_tooltip" } end
    if tag_editor_confirm_btn then tag_editor_confirm_btn.tooltip = { "tf-gui.confirm_tooltip" } end
    if tag_editor_cancel_btn then tag_editor_cancel_btn.tooltip = { "tf-gui.cancel_tooltip" } end
    -- Move mode visual
    if frame then
        if tag_data.move_mode then
            -- border_color is not a valid LuaStyle property; use a vanilla style or highlight another way if needed
            frame.tooltip = { "tf-gui.move_mode_active" }
        else
            frame.tooltip = nil
        end
    end
    if error_label then
        error_label.caption = tag_data.error_message or ""
        error_label.visible = (tag_data.error_message and tag_data.error_message ~= "")
    end
end

-- Modular row builders for tag editor
local function build_outer_frame(parent)
    local tag_editor_outer_frame = GuiBase.create_frame(parent, "tag_editor_outer_frame", "vertical", "inside_shallow_frame")
    tag_editor_outer_frame.auto_center = true
    return tag_editor_outer_frame
end

local function build_inner_frame(tag_editor_outer_frame)
    return GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_inner_frame", "vertical")
end

-- Titlebar builder: creates a vanilla-style draggable title bar as a flow with 'frame_titlebar_flow' style.
local function build_titlebar(inner)
    -- The titlebar is a flow styled as 'frame_titlebar_flow', matching vanilla dialogs.
    local tag_editor_titlebar = GuiBase.create_hflow(inner, "tag_editor_titlebar")
    tag_editor_titlebar.style = "frame_titlebar_flow"
    GuiBase.create_label(tag_editor_titlebar, "tag_editor_titlebar_label", {"tf-gui.tag_editor_title"}, "frame_title")
    local draggable = tag_editor_titlebar.add{type="empty-widget", name="titlebar_draggable", style="draggable_space_header"}
    draggable.style.horizontally_stretchable = true
    draggable.drag_target = inner.parent -- set drag target to the outer frame
    local close_btn = Helpers.create_slot_button(tag_editor_titlebar, "titlebar_close_button", SpriteEnum.CLOSE, {"tf-gui.cancel_tooltip"})
    return tag_editor_titlebar, close_btn
end

local function build_content_frames(inner)
    local tag_editor_content_frame = GuiBase.create_frame(inner, "tag_editor_content_frame", "vertical")
    local tag_editor_content_inner_frame = GuiBase.create_frame(tag_editor_content_frame, "tag_editor_content_inner_frame", "vertical")
    return tag_editor_content_frame, tag_editor_content_inner_frame
end

local function build_last_user_row(content_inner, tag_data, player)
    local tag_editor_last_user_row = GuiBase.create_hflow(content_inner, "tag_editor_last_user_row")
    local tag_editor_last_user_container = GuiBase.create_hflow(tag_editor_last_user_row, "tag_editor_last_user_container")
    GuiBase.create_label(tag_editor_last_user_container, "tag_editor_last_user_row_last_user_title", {"tf-gui.last_user_label"})
    GuiBase.create_label(tag_editor_last_user_container, "tag_editor_last_user_row_last_user_name", tag_data.last_user or player.name)
    local tag_editor_last_user_btn_container = GuiBase.create_hflow(tag_editor_last_user_row, "tag_editor_last_user_btn_container")
    local move_btn = Helpers.create_slot_button(tag_editor_last_user_btn_container, "last_user_row_move_button", SpriteEnum.ENTER, {"tf-gui.move_tooltip"})
    local delete_btn = Helpers.create_slot_button(tag_editor_last_user_btn_container, "last_user_row_delete_button", SpriteEnum.TRASH, {"tf-gui.delete_tooltip"})
    return tag_editor_last_user_row, tag_editor_last_user_btn_container, move_btn, delete_btn
end

local function build_teleport_row(content_inner)
    local tag_editor_teleport_row = GuiBase.create_hflow(content_inner, "tag_editor_teleport_row")
    GuiBase.create_label(tag_editor_teleport_row, "tag_editor_teleport_row_label", {"tf-gui.teleport_to"})
    local teleport_btn = Helpers.create_slot_button(tag_editor_teleport_row, "tag_editor_teleport_button", SpriteEnum.ENTER, {"tf-gui.teleport_tooltip"})
    return tag_editor_teleport_row, teleport_btn
end

local function build_favorite_row(content_inner)
    local tag_editor_favorite_row = GuiBase.create_hflow(content_inner, "tag_editor_favorite_row")
    GuiBase.create_label(tag_editor_favorite_row, "tag_editor_favorite_row_label", {"tf-gui.favorite_row_label"})
    local tag_editor_favorite_btn = Helpers.create_slot_button(tag_editor_favorite_row, "tag_editor_favorite_btn", SpriteEnum.CHECK_MARK, {"tf-gui.favorite_tooltip"})
    return tag_editor_favorite_row, tag_editor_favorite_btn
end

local function build_icon_row(content_inner, tag_data)
    local tag_editor_icon_row = GuiBase.create_hflow(content_inner, "tag_editor_icon_row")
    GuiBase.create_label(tag_editor_icon_row, "tag_editor_icon_row_label", {"tf-gui.icon_row_label"})
    local icon_btn = Helpers.create_slot_button(tag_editor_icon_row, "icon_row_icon_button", tag_data.icon or "", {"tf-gui.icon_tooltip"})
    return tag_editor_icon_row, icon_btn
end

local function build_text_row(content_inner, tag_data)
    local tag_editor_text_row = GuiBase.create_hflow(content_inner, "tag_editor_text_row")
    GuiBase.create_label(tag_editor_text_row, "tag_editor_text_row_label", {"tf-gui.text_label"})
    local tag_editor_textfield = GuiBase.create_textfield(tag_editor_text_row, "tag_editor_textfield", tag_data.text or "")
    return tag_editor_text_row, tag_editor_textfield
end

local function build_error_row(inner, tag_data)
    local error_row_frame = GuiBase.create_frame(inner, "tag_editor_error_row_frame", "vertical")
    error_row_frame.visible = tag_data and tag_data ~= {} and tag_data.error_message ~= nil and tag_data.error_message ~= ""
    local error_row_inner = GuiBase.create_frame(error_row_frame, "error_row_inner_frame", "vertical")
    local error_label = Helpers.show_error_label(error_row_inner, tag_data.error_message)
    return error_row_frame, error_label
end

local function build_last_row(inner)
    local tag_editor_last_row = GuiBase.create_hflow(inner, "tag_editor_last_row")
    local cancel_btn = Helpers.create_slot_button(tag_editor_last_row, "last_row_cancel_button", SpriteEnum.CLOSE, {"tf-gui.cancel_tooltip"})
    local confirm_btn = Helpers.create_slot_button(tag_editor_last_row, "last_row_confirm_button", SpriteEnum.CHECK_MARK, {"tf-gui.confirm_tooltip"})
    return tag_editor_last_row, cancel_btn, confirm_btn
end

-- Confirmation dialog for destructive actions (e.g., tag deletion)
function tag_editor.build_confirmation_dialog(player, opts)
    -- opts: { message, on_confirm, on_cancel, parent_frame_name }
    local parent = player.gui.screen
    local frame = GuiBase.create_frame(parent, "tf_confirm_dialog_frame", "vertical", "inside_shallow_frame_with_padding")
    frame.auto_center = true
    GuiBase.create_label(frame, "tag_editor_tf_confirm_dialog_label", opts.message or {"tf-gui.confirm_delete_message"}, "bold_label")
    local tag_editor_tf_confirm_dialog_btn_row = GuiBase.create_hflow(frame, "tag_editor_tf_confirm_dialog_btn_row")
    local confirm_btn = Helpers.create_slot_button(tag_editor_tf_confirm_dialog_btn_row, "tf_confirm_dialog_confirm_btn", SpriteEnum.CHECK_MARK, {"tf-gui.confirm_delete_confirm"})
    local cancel_btn = Helpers.create_slot_button(tag_editor_tf_confirm_dialog_btn_row, "tf_confirm_dialog_cancel_btn", SpriteEnum.CLOSE, {"tf-gui.confirm_delete_cancel"})
    -- Set modal/ESC behavior
    player.opened = frame
    return frame, confirm_btn, cancel_btn
end

-- Main builder for the tag editor, matching the full semantic/nested structure from notes/tag_editor.md
---
--- @param player LuaPlayer
--- @param tag_data table|nil
function tag_editor.build(player, tag_data)
    if not player then error("tag_editor.build: player is required") end
    if not tag_data then tag_data = {} end
    local parent = player.gui.screen
    local tag_editor_outer_frame = build_outer_frame(parent)
    local tag_editor_inner_frame = build_inner_frame(tag_editor_outer_frame)
    local titlebar, close_btn = build_titlebar(tag_editor_inner_frame)
    local tag_editor_content_frame, tag_editor_content_inner_frame = build_content_frames(tag_editor_inner_frame)
    local last_user_row, last_user_btn_container, move_btn, delete_btn = build_last_user_row(tag_editor_content_inner_frame, tag_data, player)
    local teleport_row, teleport_btn = build_teleport_row(tag_editor_content_inner_frame)
    local favorite_row, tag_editor_favorite_btn = build_favorite_row(tag_editor_content_inner_frame)
    local icon_row, icon_btn = build_icon_row(tag_editor_content_inner_frame, tag_data)
    local text_row, tag_editor_textfield = build_text_row(tag_editor_content_inner_frame, tag_data)
    local error_row_frame, error_label = build_error_row(tag_editor_inner_frame, tag_data)
    local last_row, cancel_btn, confirm_btn = build_last_row(tag_editor_inner_frame)
    local refs = {
        outer = tag_editor_outer_frame,
        inner = tag_editor_inner_frame,
        titlebar = titlebar,
        close_btn = close_btn,
        content_frame = tag_editor_content_frame,
        content_inner = tag_editor_content_inner_frame,
        last_user_row = last_user_row,
        last_user_btn_container = last_user_btn_container,
        move_btn = move_btn,
        delete_btn = delete_btn,
        teleport_row = teleport_row,
        teleport_btn = teleport_btn,
        favorite_row = favorite_row,
        tag_editor_favorite_btn = tag_editor_favorite_btn,
        icon_row = icon_row,
        icon_btn = icon_btn,
        text_row = text_row,
        tag_editor_textfield = tag_editor_textfield,
        error_row_frame = error_row_frame,
        error_label = error_label,
        last_row = last_row,
        cancel_btn = cancel_btn,
        confirm_btn = confirm_btn
    }
    setup_tag_editor_ui(refs, tag_data, player)
    if tag_editor_outer_frame and player and player.valid then
        player.opened = tag_editor_outer_frame
    end
    return refs
end

return tag_editor
