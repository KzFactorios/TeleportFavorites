-- favorites_bar/fave_bar.lua
-- Favorites Bar GUI for TeleportFavorites
-- Uses shared gui helpers from gui.lua

local gui = require("gui.gui")
local Constants = require("constants")
local Favorite = require("core.favorite.favorite")

local fave_bar = {}

function fave_bar.build(player, parent)
    local PlayerFavorites = require("core.favorite.player_favorites")
    local GPS = require("core.gps.gps")
    local Style = require("gui.styles")
    local frame = gui.create_frame(parent, "fave_bar_frame", "horizontal", "inside_shallow_frame_with_padding")
    frame.style.top_padding = 2
    frame.style.bottom_padding = 2
    frame.style.left_padding = 4
    frame.style.right_padding = 4

    -- Toggle button container
    local toggle_container = gui.create_hflow(frame, "fave_toggle_container")
    local toggle_btn = gui.create_icon_button(toggle_container, "fave_toggle", "item/red_tf_slot_button_20", {"tf-gui.toggle_fave_bar"}, "tf_slot_button")

    -- Favorite buttons container
    local fav_btns = gui.create_hflow(frame, "favorite_buttons")
    local pfaves = PlayerFavorites.new(player):get_all()
    local drag_index = _G.storage and _G.storage.players and _G.storage.players[player.index] and _G.storage.players[player.index].drag_favorite_index
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
        local fav = pfaves[i]
        if type(fav) ~= "table" then fav = Favorite.get_blank_favorite() end
        local is_blank = Favorite.is_blank_favorite(fav)
        local is_locked = (fav and fav.locked) or false
        local icon = (fav and fav.tag and fav.tag.icon and fav.tag.icon ~= "") and fav.tag.icon or "default-map-tag"
        local btn = gui.create_icon_button(fav_btns, "favorite_slot_"..i, icon, nil, "tf_slot_button")
        btn.style.width = 36
        btn.style.height = 36
        btn.style.font = "default-small"
        -- Tooltip
        if is_blank then
            btn.tooltip = {"tf-gui.fave_slot_empty"}
        else
            local gps_str = (fav and fav.gps) and (GPS.coords_string_from_gps(fav.gps) or fav.gps) or "?"
            local tag_text = (fav and fav.tag and fav.tag.text and fav.tag.text ~= "") and fav.tag.text or nil
            if type(tag_text) == "string" and #tag_text > 50 then tag_text = tag_text:sub(1, 50) .. "..." end
            -- Accessibility: tooltips for all states
            if is_locked and not is_blank then
                btn.tooltip = {"tf-gui.fave_slot_locked_tooltip", gps_str, tag_text or ""}
            elseif not is_locked and not is_blank then
                btn.tooltip = tag_text and {"tf-gui.fave_slot_tooltip", gps_str, tag_text} or {"tf-gui.fave_slot_tooltip_one", gps_str}
            else
                btn.tooltip = {"tf-gui.fave_slot_empty"}
            end
        end
        -- Slot number caption (small, bottom right)
        local slot_caption = gui.create_label(btn, "slot_caption", tostring(i % 10), nil)
        slot_caption.style.font = "default-tiny"
        slot_caption.style.right_padding = 0
        slot_caption.style.bottom_padding = 0
        slot_caption.style.top_padding = 18
        slot_caption.style.left_padding = 18
        slot_caption.ignored_by_interaction = true
        -- Drag-and-drop visual feedback
        if drag_index == i then
            btn.style.border_color = {r=0.2, g=0.7, b=1, a=1} -- blue highlight for dragged slot
            btn.style.shadow = true
            btn.style.transition_duration = 0.2
        elseif drag_index and drag_index ~= i then
            btn.style.border_color = {r=1, g=1, b=0.2, a=1} -- yellow highlight for drop target
            btn.style.transition_duration = 0.2
        elseif is_locked and not is_blank then
            btn.style.border_color = {r=1, g=0.5, b=0, a=1} -- orange border for locked
            btn.style.transition_duration = 0.2
        else
            btn.style.border_color = nil
            btn.style.transition_duration = 0.1
        end
        -- Locked visuals
        if is_locked and not is_blank then
            -- Lock overlay icon (if possible)
            local lock_icon = btn.add{type="sprite", sprite="utility/lock", name="lock_overlay"}
            lock_icon.style.width = 16
            lock_icon.style.height = 16
            lock_icon.style.left_margin = 0
            lock_icon.style.top_margin = 0
            lock_icon.ignored_by_interaction = true
        else
            if btn.lock_overlay then btn.lock_overlay.destroy() end
        end
        -- Drag-and-drop stubs (Factorio 2.0+)
        btn.drag_target = fav_btns
        btn.tags = { slot = i }
        -- Disabled state for blank slots
        btn.enabled = not is_blank
        -- Overflow feedback: beep/message if max slots
        if not is_blank and pfaves and #pfaves >= Constants.settings.MAX_FAVORITE_SLOTS then
            btn.tooltip = {"tf-gui.fave_slot_overflow"}
        end
    end
    -- NOTE: favorites_on mod setting guard is handled in control.lua, not here, to avoid impossible ifs
    return frame
end

-- Event wiring for favorite bar is handled in control.lua (on_gui_click, etc.)

return fave_bar
