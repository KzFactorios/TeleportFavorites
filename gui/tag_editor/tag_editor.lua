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

- tag_editor.build_confirmation_dialog(player, opts):
    Shows a modal confirmation dialog for destructive actions (e.g., tag deletion).

- setup_tag_editor_ui(refs, tag_data, player):
    Sets state, tooltips, and styles for all controls after construction.
--]]
local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Helpers = require("core.utils.helpers_suite")
local SpriteEnum = require("gui.sprite_enum")

local tag_editor = {}

-- Sets up the tag editor UI, including all controls and their state
-- This function now only sets state, tooltips, and styles. It does NOT create any elements.
local function setup_tag_editor_ui(refs, tag_data, player)
    local tag_editor_icon_elem_btn = refs.icon_btn or refs.tag_editor_icon_elem_btn
    local tag_editor_move_btn = refs.move_btn or refs.tag_editor_move_btn
    local tag_editor_delete_btn = refs.delete_btn or refs.tag_editor_delete_btn
    local tag_editor_teleport_btn = refs.teleport_btn or refs.tag_editor_teleport_btn
    local tag_editor_favorite_btn = refs.favorite_btn or refs.tag_editor_favorite_btn
    local tag_editor_textfield = refs.text_input or refs.tag_editor_textfield
    local tag_editor_confirm_btn = refs.confirm_btn or refs.tag_editor_confirm_btn
    local tag_editor_cancel_btn = refs.cancel_btn or refs.tag_editor_cancel_btn
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
    Helpers.set_button_state(tag_editor_favorite_btn,
        tag_data.is_favorite or ((tag_data.non_blank_faves or 0) < max_faves))
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
            frame.tooltip = { "tf-gui.move_mode_active" }
        else
            frame.tooltip = nil
        end
    end
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
--- @param tag_data table|nil
function tag_editor.build(player, tag_data)
    if not player then error("tag_editor.build: player is required") end
    if not tag_data then tag_data = {} end
    local last_user = tag_data.last_user or ""
    local line_height = 44
    local label_width = 100

    local parent = player.gui.screen
    local tag_editor_outer_frame = GuiBase.create_frame(parent, "tag_editor_outer_frame", "vertical", "slot_window_frame")
    tag_editor_outer_frame.auto_center = true
    tag_editor_outer_frame.style.padding = { 4, 8, 8, 8 }


    -- titlle bar
    GuiBase.create_titlebar(tag_editor_outer_frame, { "tf-gui.tag_editor_title" }, "titlebar_close_button")
    -- Make the dialog draggable by setting the draggable target to the titlebar's draggable space
    local tag_editor_titlebar = tag_editor_outer_frame["tag_editor_titlebar"]
    if tag_editor_titlebar then
        local draggable = tag_editor_titlebar["titlebar_draggable"]
        if draggable then
            --draggable.style.height = 24
            tag_editor_outer_frame.force_auto_center() -- Ensure dialog is centered after drag
            tag_editor_outer_frame.drag_target = draggable
        end
    end

    -- inner frame
    local tag_editor_inner_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_inner_frame", "vertical",
        "invisible_frame")
    tag_editor_inner_frame.style.padding = { 0, 0, 0, 0 }
    tag_editor_inner_frame.style.margin = { 0, 0, 0, 0 }


    -- Content background
    local tag_editor_content_frame = GuiBase.create_frame(tag_editor_inner_frame, "tag_editor_content_frame", "vertical")
    tag_editor_content_frame.style.padding = 0
    tag_editor_content_frame.style.margin = 0


    -- Last user row (frame, horizontal)
    local tag_editor_last_user_row = GuiBase.create_frame(tag_editor_content_frame, "tag_editor_last_user_row",
        "horizontal", "tf_last_user_label_row")
    tag_editor_last_user_row.style.horizontally_stretchable = true
    tag_editor_last_user_row.style.vertically_stretchable = false
    tag_editor_last_user_row.style.height = line_height - 8
    tag_editor_last_user_row.style.vertical_align = "center"
    tag_editor_last_user_row.style.horizontal_align = "left"
    tag_editor_last_user_row.style.width = nil
    tag_editor_last_user_row.style.maximal_width = 10000
    tag_editor_last_user_row.style.padding = { 8, 8, 4, 12 } -- Uniform padding (top, right, bottom, left)
    tag_editor_last_user_row.style.margin = { 0, 0, 0, 0 }   -- Uniform padding (top, right, bottom, left)
    tag_editor_last_user_row.style.minimal_width = 100
    tag_editor_last_user_row.style.maximal_width = 10000     -- Allow to stretch fully

    local tag_editor_last_user_label = GuiBase.create_label(tag_editor_last_user_row, "tag_editor_last_user_label",
        { "tf-gui.last_user_label", last_user })
    tag_editor_last_user_label.style.font = "default-bold"



    -- Content inner frame (vertical)
    local tag_editor_content_inner_frame = GuiBase.create_frame(tag_editor_content_frame,
        "tag_editor_content_inner_frame", "vertical")
    tag_editor_content_inner_frame.style.padding = { 8, 8, 8, 12 } -- Uniform padding (top, right, bottom, left)



    -- Teleport row
    local tag_editor_teleport_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_teleport_row")
    tag_editor_teleport_row.style.height = line_height
    tag_editor_teleport_row.style.vertical_align = "center"
    local tag_editor_teleport_label = GuiBase.create_label(tag_editor_teleport_row, "tag_editor_teleport_label",
        { "tf-gui.teleport_to" })
    tag_editor_teleport_label.style.width = label_width
    local tag_editor_teleport_button = GuiBase.create_icon_button(tag_editor_teleport_row, "tag_editor_teleport_button",
        nil, { "tf-gui.teleport_tooltip" }, "tf_teleport_button")
    tag_editor_teleport_button.style.horizontally_stretchable = true
    tag_editor_teleport_button.style.vertically_stretchable = false
    -- TOD assign correct location
    tag_editor_teleport_button.caption = "location"


    -- Favorite row
    local tag_editor_favorite_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_favorite_row")
    tag_editor_favorite_row.style.height = line_height
    tag_editor_favorite_row.style.vertical_align = "center"
    local tag_editor_is_favorite_label = GuiBase.create_label(tag_editor_favorite_row, "tag_editor_is_favorite_label",
        { "tf-gui.favorite_row_label" })
    tag_editor_is_favorite_label.style.width = label_width
    tag_editor_is_favorite_label.style.vertical_align = "center"
    local tag_editor_is_favorite_button = GuiBase.create_icon_button(tag_editor_favorite_row,
        "tag_editor_is_favorite_button", "utility/check_mark", { "tf-gui.favorite_tooltip" }, "tf_slot_button")




    -- Icon row
    local tag_editor_icon_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_icon_row")
    tag_editor_icon_row.style.height = line_height
    tag_editor_icon_row.style.vertical_align = "center"
    local tag_editor_icon_label = GuiBase.create_label(tag_editor_icon_row, "tag_editor_icon_label",
        { "tf-gui.icon_row_label" })
    tag_editor_icon_label.style.width = label_width
    tag_editor_icon_label.style.vertical_align = "center"
    local tag_editor_icon_button = GuiBase.create_icon_button(tag_editor_icon_row, "tag_editor_icon_button",
        tag_data.icon or "", { "tf-gui.icon_tooltip" }, "tf_slot_button")


    -- Text row
    local tag_editor_text_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_text_row")
    tag_editor_text_row.style.height = line_height
    tag_editor_text_row.style.vertical_align = "center"
    local tag_editor_text_label = GuiBase.create_label(tag_editor_text_row, "tag_editor_text_label",
        { "tf-gui.text_label" })
    tag_editor_text_label.style.width = label_width
    tag_editor_text_label.style.vertical_align = "center"


    
    local tag_editor_text_input = GuiBase.create_textfield(tag_editor_text_row, "tag_editor_text_input",
        tag_data.text or "")




    -- Rich text input row (for icons, like vanilla tag editor)
    local tag_editor_rich_text_row = GuiBase.create_hflow(tag_editor_content_inner_frame, "tag_editor_rich_text_row")
    tag_editor_rich_text_row.style.height = line_height
    tag_editor_rich_text_row.style.vertical_align = "center"



    -- Use a textfield for now, but Factorio does not support true rich text editing in GUIs
    local tag_editor_rich_text_input = GuiBase.create_textfield(tag_editor_rich_text_row, "tag_editor_rich_text_input",
        tag_data.rich_text or "")
    tag_editor_rich_text_input.style.horizontally_stretchable = true
    tag_editor_rich_text_input.style.vertically_stretchable = false
    tag_editor_rich_text_input.style.font = "default"
    tag_editor_rich_text_input.tooltip = { "tf-gui.rich_text_tooltip" }
    -- Optionally, you could add a button to insert icons or show a list of allowed icons
    -- Use a valid vanilla utility icon, e.g. utility/list_view
    local tag_editor_rich_text_icon_button = GuiBase.create_icon_button(tag_editor_rich_text_row,
        "tag_editor_rich_text_icon_button",
        SpriteEnum.INSERT_RICH_TEXT_ICON, { "tf-gui.insert_icon_tooltip" }, "tf_insert_rich_text_button")
    tag_editor_rich_text_icon_button.style.maximal_width = 20
    tag_editor_rich_text_icon_button.style.maximal_height = 20
    tag_editor_rich_text_icon_button.style.left_margin = -28 -- a little trickery to get the button to sit at the end of the text input



    -- Error row
    local tag_editor_error_row_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_error_row_frame",
        "vertical")
    local error_row_inner_frame = GuiBase.create_frame(tag_editor_error_row_frame, "error_row_inner_frame", "vertical",
        "invisible_frame")
    local error_row_error_message = GuiBase.create_label(error_row_inner_frame, "error_row_error_message",
        tag_data.error_message or "")





    -- Last row (confirm/cancel) - move to outer frame (after inner frame)
    local tag_editor_last_row = GuiBase.create_hflow(tag_editor_outer_frame, "tag_editor_last_row")
    tag_editor_last_row.style.vertical_align = "center"
    tag_editor_last_row.style.height = line_height + 4

    local last_row_cancel_button = GuiBase.create_icon_button(tag_editor_last_row, "last_row_cancel_button",
        "utility/close", { "tf-gui.cancel_tooltip" }, "tf_slot_button")

    local last_row_confirm_button = GuiBase.create_icon_button(tag_editor_last_row, "last_row_confirm_button",
        nil, { "tf-gui.confirm_tooltip" }, "tf_confirm_button")
    last_row_confirm_button.caption = { "tf-gui.confirm" }








    local refs = {
        outer = tag_editor_outer_frame,
        inner = tag_editor_inner_frame,
        content_frame = tag_editor_content_frame,
        content_inner = tag_editor_content_inner_frame,
        last_user_row = tag_editor_last_user_row,
        teleport_row = tag_editor_teleport_row,
        teleport_btn = tag_editor_teleport_button,
        favorite_row = tag_editor_favorite_row,
        favorite_btn = tag_editor_is_favorite_button,
        icon_row = tag_editor_icon_row,
        icon_btn = tag_editor_icon_button,
        text_row = tag_editor_text_row,
        text_input = tag_editor_text_input,
        error_row_frame = tag_editor_error_row_frame,
        error_label = error_row_error_message,
        last_row = tag_editor_last_row,
        cancel_btn = last_row_cancel_button,
        confirm_btn = last_row_confirm_button
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
