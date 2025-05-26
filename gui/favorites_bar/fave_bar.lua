--[[
Favorites Bar GUI for TeleportFavorites
======================================
Module: gui/favorites_bar/fave_bar.lua

Builds the favorites bar UI for the TeleportFavorites mod, providing quick-access favorite teleport slots.

Features:
- Renders a horizontal bar of favorite slots, each as an icon button with tooltip and slot number.
- Handles locked, blank, and overflow slot states with distinct visuals and tooltips.
- Supports drag-and-drop visuals for slot reordering (Factorio 2.0+).
- Integrates with PlayerFavorites and Favorite modules for data, and uses shared gui helpers.
- Displays error feedback if the number of favorites exceeds the allowed maximum.

Main Function:
- fave_bar.build(player, parent):
    Constructs and returns the favorites bar frame for the given player and parent GUI element.
    Handles all slot rendering, tooltips, drag/locked visuals, and overflow error display.

Event handling for slot clicks and drag is managed externally (see control.lua).
--]]
local gui = require("gui.gui")
local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local PlayerFavorites = require("core.favorite.player_favorites")
local GPS = require("core.gps.gps")

local fave_bar = {}

function fave_bar.build(player, parent)
    local frame = gui.create_frame(parent, "fave_bar_frame", "horizontal", "inside_shallow_frame_with_padding")
    local s = frame.style
    s.top_padding, s.bottom_padding, s.left_padding, s.right_padding = 2, 2, 4, 4
    local toggle_btn = gui.create_icon_button(gui.create_hflow(frame, "fave_toggle_container"), "fave_toggle", "item/red_tf_slot_button_20", {"tf-gui.toggle_fave_bar"}, "tf_slot_button")
    local fav_btns = gui.create_hflow(frame, "favorite_buttons")
    local pfaves = PlayerFavorites.new(player):get_all()
    local drag_index = _G.storage and _G.storage.players and _G.storage.players[player.index] and _G.storage.players[player.index].drag_favorite_index
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
        local fav = type(pfaves[i]) == "table" and pfaves[i] or Favorite.get_blank_favorite()
        local is_blank = Favorite.is_blank_favorite(fav)
        local is_locked = fav.locked or false
        local icon = (fav.tag and fav.tag.icon ~= "") and fav.tag.icon or "default-map-tag"
        local btn = gui.create_icon_button(fav_btns, "favorite_slot_"..i, icon, nil, "tf_slot_button")
        btn.style.width, btn.style.height, btn.style.font = 36, 36, "default-small"
        -- Tooltip
        if is_blank then
            btn.tooltip = {"tf-gui.fave_slot_empty"}
        else
            local gps_str = fav.gps and (GPS.coords_string_from_gps(fav.gps) or fav.gps) or "?"
            local tag_text = fav.tag and fav.tag.text ~= "" and fav.tag.text or nil
            if type(tag_text) == "string" and #tag_text > 50 then tag_text = tag_text:sub(1, 50).."..." end
            btn.tooltip = is_locked and {"tf-gui.fave_slot_locked_tooltip", gps_str, tag_text or ""}
                or (tag_text and {"tf-gui.fave_slot_tooltip", gps_str, tag_text} or {"tf-gui.fave_slot_tooltip_one", gps_str})
        end
        -- Slot number caption
        local slot_caption = gui.create_label(btn, "slot_caption", tostring(i % 10), nil)
        slot_caption.style.font = "default-tiny"
        slot_caption.style.right_padding, slot_caption.style.bottom_padding = 0, 0
        slot_caption.style.top_padding, slot_caption.style.left_padding = 18, 18
        slot_caption.ignored_by_interaction = true
        -- Border/drag/locked visuals
        local bstyle = btn.style
        if drag_index == i then
            bstyle.border_color, bstyle.shadow, bstyle.transition_duration = {r=0.2,g=0.7,b=1,a=1}, true, 0.2
        elseif drag_index then
            bstyle.border_color, bstyle.transition_duration = {r=1,g=1,b=0.2,a=1}, 0.2
        elseif is_locked and not is_blank then
            bstyle.border_color, bstyle.transition_duration = {r=1,g=0.5,b=0,a=1}, 0.2
        else
            bstyle.border_color, bstyle.transition_duration = nil, 0.1
        end
        if is_locked and not is_blank then
            local lock_icon = btn.add{type="sprite", sprite="utility/lock", name="lock_overlay"}
            lock_icon.style.width, lock_icon.style.height = 16, 16
            lock_icon.style.left_margin, lock_icon.style.top_margin = 0, 0
            lock_icon.ignored_by_interaction = true
        elseif btn.lock_overlay then btn.lock_overlay.destroy() end
        btn.drag_target, btn.tags, btn.enabled = fav_btns, {slot=i}, not is_blank
    end
    -- Overflow error
    if pfaves and #pfaves >= Constants.settings.MAX_FAVORITE_SLOTS then
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            local btn = fav_btns["favorite_slot_"..i]
            if btn then btn.tooltip = {"tf-gui.fave_slot_overflow"} end
        end
        frame.add{type="label", caption={"tf-gui.fave_bar_overflow_error"}, style="bold_label"}.style.font_color = {r=1,g=0.2,b=0.2}
    end
    return frame
end

return fave_bar
