-- tag_editor/tag_editor.lua
-- Tag Editor GUI for TeleportFavorites
-- Uses shared gui helpers from gui.lua

local gui = require("gui.gui")
local Constants = require("constants")

local tag_editor = {}

function tag_editor.build(player, parent, tag_data)
    -- Modal frame
    local frame = gui.create_frame(parent, "tag_editor_frame", "vertical", "dialog_frame")
    frame.style.vertically_stretchable = false
    frame.style.horizontally_stretchable = false
    frame.style.maximal_width = 400

    -- Titlebar
    gui.create_titlebar(frame, {"tf-gui.tag_editor_title"}, function() frame.destroy() end)

    -- Icon selector (elem-button for signal selection)
    frame.add{
        type = "choose-elem-button",
        name = "icon_elem_btn",
        elem_type = "signal",
        signal = tag_data.icon or nil,
        tooltip = {"tf-gui.icon_tooltip"},
        style = "slot_button"
    }

    -- Text box
    gui.create_label(frame, "text_label", {"tf-gui.text_label"})
    gui.create_textfield(frame, "text_box", tag_data.text or "", "textfield")

    -- Button row
    local btn_row = gui.create_hflow(frame, "button_row")
    gui.create_icon_button(btn_row, "move_btn", "utility/enter", {"tf-gui.move_tooltip"}, "slot_button")
    gui.create_icon_button(btn_row, "delete_btn", "utility/trash", {"tf-gui.delete_tooltip"}, "slot_button")
    gui.create_icon_button(btn_row, "teleport_btn", "utility/enter", {"tf-gui.teleport_tooltip"}, "slot_button")
    gui.create_icon_button(btn_row, "favorite_btn", "utility/star_white", {"tf-gui.favorite_tooltip"}, "slot_button")
    local confirm_btn = gui.create_icon_button(btn_row, "confirm_btn", "utility/check_mark", {"tf-gui.confirm_tooltip"}, "slot_button")
    gui.create_icon_button(btn_row, "cancel_btn", "utility/close_white", {"tf-gui.cancel_tooltip"}, "slot_button")

    -- Error row for validation messages
    local error_row = frame.add{type="flow", name="error_row", direction="horizontal"}
    local error_label = error_row.add{type="label", name="error_row_error_message", caption="", style="bold_label"}
    error_label.style.font_color = {r=1, g=0.2, b=0.2} -- red for errors
    error_label.visible = false

    -- Enable/disable confirm button based on icon or trimmed text
    local trimmed_text = (tag_data.text or ""):gsub("%s+$", "")
    if (not tag_data.icon or tag_data.icon == "") and trimmed_text == "" then
        confirm_btn.enabled = false
    else
        confirm_btn.enabled = true
    end

    -- Ownership and favorite state logic
    local is_owner = tag_data.last_user == nil or tag_data.last_user == "" or tag_data.last_user == player.name
    local is_favorited_by_others = tag_data.faved_by_players and #tag_data.faved_by_players > 1 or (tag_data.faved_by_players and #tag_data.faved_by_players == 1 and tag_data.faved_by_players[1] ~= player.index)
    -- Move and delete only enabled for owner and not favorited by others
    btn_row.move_btn.enabled = is_owner
    btn_row.delete_btn.enabled = is_owner and not is_favorited_by_others
    -- Icon and text box only enabled for owner
    frame.icon_elem_btn.enabled = is_owner
    frame.text_box.enabled = is_owner
    -- Favorite button: always enabled unless at max slots and not already favorited
    local max_faves = Constants.settings.MAX_FAVORITE_SLOTS or 10
    local non_blank_faves = tag_data.non_blank_faves or 0
    local is_player_favorite = tag_data.is_favorite
    btn_row.favorite_btn.enabled = is_player_favorite or (non_blank_faves < max_faves)
    -- Confirm button enablement (already handled above)
    -- Teleport and cancel always enabled
    btn_row.teleport_btn.enabled = true
    btn_row.cancel_btn.enabled = true

    -- Teleport button: orange background
    btn_row.teleport_btn.style.font_color = {r=1, g=0.5, b=0}
    btn_row.teleport_btn.style.font = "default-bold"
    btn_row.teleport_btn.style.default_font_color = {r=1, g=0.5, b=0}
    btn_row.teleport_btn.style.hovered_font_color = {r=1, g=0.7, b=0.2}

    -- Accessibility: tooltips for all controls
    frame.icon_elem_btn.tooltip = {"tf-gui.icon_tooltip"}
    frame.text_box.tooltip = {"tf-gui.text_tooltip"}
    btn_row.move_btn.tooltip = {"tf-gui.move_tooltip"}
    btn_row.delete_btn.tooltip = {"tf-gui.delete_tooltip"}
    btn_row.teleport_btn.tooltip = {"tf-gui.teleport_tooltip"}
    btn_row.favorite_btn.tooltip = {"tf-gui.favorite_tooltip"}
    btn_row.confirm_btn.tooltip = {"tf-gui.confirm_tooltip"}
    btn_row.cancel_btn.tooltip = {"tf-gui.cancel_tooltip"}

    -- Move mode visual feedback (highlight frame border if in move_mode)
    if tag_data.move_mode then
        frame.style.border_color = {r=0.2, g=0.7, b=1, a=1}
        frame.style.shadow = true
        frame.tooltip = {"tf-gui.move_mode_active"}
    else
        frame.style.border_color = nil
        frame.style.shadow = false
        frame.tooltip = nil
    end

    return frame
end

return tag_editor
