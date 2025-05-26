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

Main Functions:
- tag_editor.build(player, parent, tag_data):
    Constructs and returns the tag editor modal frame for the given player, parent GUI element, and tag data.
    Handles all UI element creation, state logic, tooltips, error display, and move mode visuals.

Internal Helpers:
- create_tag_editor_frame(parent): Creates and styles the modal frame.
- build_icon_selector, build_text_section, build_button_row, build_error_label: Modular UI element builders.
- setup_tag_editor_ui: Assembles all UI elements and returns references.
- set_button_states, set_button_styles_and_tooltips, set_move_mode_visual, set_error_label: Handle state, style, and feedback logic.
--]]
local gui = require("gui.gui")
local Constants = require("constants")

local tag_editor = {}

local function build_icon_selector(frame, tag_data)
    return frame.add{
        type="choose-elem-button", name="icon_elem_btn", elem_type="signal",
        signal=tag_data.icon or nil, tooltip={"tf-gui.icon_tooltip"}, style="tf_slot_button"
    }
end

local function build_text_section(frame, tag_data)
    gui.create_label(frame, "text_label", {"tf-gui.text_label"})
    return gui.create_textfield(frame, "text_box", tag_data.text or "", "textfield")
end

local function build_button_row(frame)
    local btn_row = gui.create_hflow(frame, "button_row")
    local move_btn = gui.create_icon_button(btn_row, "move_btn", "utility/enter", {"tf-gui.move_tooltip"}, "tf_slot_button")
    local delete_btn = gui.create_icon_button(btn_row, "delete_btn", "utility/trash", {"tf-gui.delete_tooltip"}, "tf_slot_button")
    local teleport_btn = gui.create_icon_button(btn_row, "teleport_btn", "utility/enter", {"tf-gui.teleport_tooltip"}, "tf_slot_button")
    local favorite_btn = gui.create_icon_button(btn_row, "favorite_btn", "utility/star_white", {"tf-gui.favorite_tooltip"}, "tf_slot_button")
    local confirm_btn = gui.create_icon_button(btn_row, "confirm_btn", "utility/check_mark", {"tf-gui.confirm_tooltip"}, "tf_slot_button")
    local cancel_btn = gui.create_icon_button(btn_row, "cancel_btn", "utility/close_white", {"tf-gui.cancel_tooltip"}, "tf_slot_button")
    return btn_row, move_btn, delete_btn, teleport_btn, favorite_btn, confirm_btn, cancel_btn
end

local function build_error_label(frame)
    local error_label = frame.add{type="flow", name="error_row", direction="horizontal"}
        :add{type="label", name="error_row_error_message", caption="", style="bold_label"}
    error_label.style.font_color, error_label.visible = {r=1,g=0.2,b=0.2}, false
    return error_label
end

local function set_button_states(tag_data, player, move_btn, delete_btn, icon_elem_btn, text_box, favorite_btn, confirm_btn, teleport_btn, cancel_btn)
    local trimmed = (tag_data.text or ""):gsub("%s+$", "")
    confirm_btn.enabled = not ((not tag_data.icon or tag_data.icon == "") and trimmed == "")
    local is_owner = not tag_data.last_user or tag_data.last_user == "" or tag_data.last_user == player.name
    local faved = tag_data.faved_by_players or {}
    local is_favorited_by_others = #faved > 1 or (#faved == 1 and faved[1] ~= player.index)
    move_btn.enabled = is_owner
    delete_btn.enabled = is_owner and not is_favorited_by_others
    icon_elem_btn.enabled = is_owner
    text_box.enabled = is_owner
    local max_faves = Constants.settings.MAX_FAVORITE_SLOTS or 10
    favorite_btn.enabled = tag_data.is_favorite or ((tag_data.non_blank_faves or 0) < max_faves)
    teleport_btn.enabled, cancel_btn.enabled = true, true
end

local function set_button_styles_and_tooltips(icon_elem_btn, text_box, move_btn, delete_btn, teleport_btn, favorite_btn, confirm_btn, cancel_btn)
    local tps = teleport_btn.style
    tps.font_color, tps.font, tps.default_font_color, tps.hovered_font_color = {r=1,g=0.5,b=0}, "default-bold", {r=1,g=0.5,b=0}, {r=1,g=0.7,b=0.2}
    icon_elem_btn.tooltip = {"tf-gui.icon_tooltip"}
    text_box.tooltip = {"tf-gui.text_tooltip"}
    move_btn.tooltip = {"tf-gui.move_tooltip"}
    delete_btn.tooltip = {"tf-gui.delete_tooltip"}
    teleport_btn.tooltip = {"tf-gui.teleport_tooltip"}
    favorite_btn.tooltip = {"tf-gui.favorite_tooltip"}
    confirm_btn.tooltip = {"tf-gui.confirm_tooltip"}
    cancel_btn.tooltip = {"tf-gui.cancel_tooltip"}
end

local function set_move_mode_visual(frame, style, move_mode)
    if move_mode then
        style.border_color, style.shadow, frame.tooltip = {r=0.2,g=0.7,b=1,a=1}, true, {"tf-gui.move_mode_active"}
    else
        style.border_color, style.shadow, frame.tooltip = nil, false, nil
    end
end

local function set_error_label(error_label, tag_data, frame)
    if tag_data.error_message and tag_data.error_message ~= "" then
        error_label.caption, error_label.visible = tag_data.error_message, true
        frame.focus()
    else
        error_label.caption, error_label.visible = "", false
    end
end

local function setup_tag_editor_ui(frame, tag_data)
    local icon_elem_btn = build_icon_selector(frame, tag_data)
    local text_box = build_text_section(frame, tag_data)
    local btn_row, move_btn, delete_btn, teleport_btn, favorite_btn, confirm_btn, cancel_btn = build_button_row(frame)
    local error_label = build_error_label(frame)
    return {
        icon_elem_btn = icon_elem_btn,
        text_box = text_box,
        btn_row = btn_row,
        move_btn = move_btn,
        delete_btn = delete_btn,
        teleport_btn = teleport_btn,
        favorite_btn = favorite_btn,
        confirm_btn = confirm_btn,
        cancel_btn = cancel_btn,
        error_label = error_label
    }
end

local function create_tag_editor_frame(parent)
    local frame = gui.create_frame(parent, "tag_editor_frame", "vertical", "dialog_frame")
    local s = frame.style
    s.vertically_stretchable, s.horizontally_stretchable, s.maximal_width = false, false, 400
    return frame
end

function tag_editor.build(player, parent, tag_data)
    local frame = create_tag_editor_frame(parent)
    gui.create_titlebar(frame, {"tf-gui.tag_editor_title"}, function() frame.destroy() end)
    local ui = setup_tag_editor_ui(frame, tag_data)
    set_button_states(tag_data, player, ui.move_btn, ui.delete_btn, ui.icon_elem_btn, ui.text_box, ui.favorite_btn, ui.confirm_btn, ui.teleport_btn, ui.cancel_btn)
    set_button_styles_and_tooltips(ui.icon_elem_btn, ui.text_box, ui.move_btn, ui.delete_btn, ui.teleport_btn, ui.favorite_btn, ui.confirm_btn, ui.cancel_btn)
    set_move_mode_visual(frame, frame.style, tag_data.move_mode)
    set_error_label(ui.error_label, tag_data, frame)
    return frame
end

return tag_editor
