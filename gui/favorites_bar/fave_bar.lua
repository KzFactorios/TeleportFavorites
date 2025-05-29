---@diagnostic disable: undefined-global
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

local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local PlayerFavorites = require("core.favorite.player_favorites")
local GPS = require("core.gps.gps")
local Helpers = require("core.utils.helpers_suite")
local Settings = require("settings")
local Cache = require("core.cache.cache")
local SpriteEnum = require("gui.sprite_enum")

local fave_bar = {}

local function get_or_create_main_flow(parent)
    local flow = parent.tf_main_gui_flow
    if not (flow and flow.valid) then
        flow = parent.add{type="flow", name="tf_main_gui_flow", direction="vertical"}
    end
    return flow
end

local function create_fave_bar_frame(parent)
    local fave_bar_frame = GuiBase.create_frame(parent, "fave_bar_frame", "horizontal", "inside_shallow_frame_with_padding")
    local s = fave_bar_frame.style
    s.top_padding, s.bottom_padding, s.left_padding, s.right_padding = 2, 2, 4, 4
    return fave_bar_frame
end

local function add_toggle_button(toggle_flow, player)
    -- Place the toggle button inside the toggle_flow
    local btn = Helpers.create_slot_button(toggle_flow, "fave_bar_visible_btns_toggle", SpriteEnum.SLOT_ORANGE, {"tf-gui.toggle_fave_bar"})
    btn.style.size = 36
    btn.style.width = 36
    btn.style.height = 36
    btn.style.padding = 0
    btn.style.margin = 0
    btn.style.top_margin = 0
    btn.style.bottom_margin = 0
    btn.style.left_margin = 0
    btn.style.right_margin = 0
    btn.style.horizontally_stretchable = false
    btn.style.vertically_stretchable = false
    -- Store player index for event handler if needed
    btn.tags = btn.tags or {}
    btn.tags.player_index = player and player.index or nil
    return btn
end

local function build_favorite_buttons_row(slots_flow, player, pfaves, drag_index)
    -- slots_flow is now passed in, not created here
    for i = 1, #pfaves do
        local fav = type(pfaves[i]) == "table" and pfaves[i] or Constants.get_blank_favorite()
        local is_blank = Favorite.is_blank_favorite(fav)
        local is_locked = fav.locked or false
        -- Always create the slot button, even if blank or just toggled
        local icon = (not is_blank and fav.tag and fav.tag.icon ~= "") and fav.tag.icon or nil
        local tooltip = not is_blank and Helpers.build_favorite_tooltip(fav) or nil
        -- Use normalized slot button naming: "fave_bar_slot_" .. i
        local style = "tf_slot_button"
        if drag_index == i then
            style = "tf_slot_button_dragged"
        elseif drag_index and drag_index > 0 then
            style = "tf_slot_button_drag_target"
        elseif is_locked and not is_blank then
            style = "tf_slot_button_locked"
        end
        local btn = Helpers.create_slot_button(slots_flow, "fave_bar_slot_"..i, icon, tooltip, {
            locked = is_locked and not is_blank,
            enabled = not is_blank,
            style = style
        })
        -- Slot number caption
        local slot_caption = GuiBase.create_label(btn, "fave_bar_slot_caption", tostring(i % 10), nil)
        slot_caption.style.font = "default-small"
        slot_caption.style.right_padding, slot_caption.style.bottom_padding = 0, 0
        slot_caption.style.top_padding, slot_caption.style.left_padding = 18, 18
        slot_caption.ignored_by_interaction = true
    end
    return slots_flow
end

local function handle_overflow_error(frame, fav_btns, pfaves)
    if pfaves and #pfaves > Constants.settings.MAX_FAVORITE_SLOTS then
        Helpers.show_error_label(frame, { "tf-gui.fave_bar_overflow_error" })
    else
        Helpers.clear_error_label(frame)
    end
end

local _fave_bar_building_guard = _G._fave_bar_building_guard or {}
_G._fave_bar_building_guard = _fave_bar_building_guard

function fave_bar.build(player, parent)
    local pid = player.index
    if _fave_bar_building_guard[pid] then
        return
    end
    _fave_bar_building_guard[pid] = true
    local success, result = pcall(function()
        local player_settings = Settings:getPlayerSettings(player)
        if not player_settings.favorites_on then return end

        local mode = player and player.render_mode
        if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
            return  
        end
        -- Use shared vertical flow
        local main_flow = get_or_create_main_flow(parent)
        if main_flow.fave_bar_frame then
            main_flow.fave_bar_frame.destroy()
        end
        local fave_bar_frame = create_fave_bar_frame(main_flow)
        local bar_flow = GuiBase.create_hflow(fave_bar_frame, "fave_bar_flow")
        -- Add toggle flow and button
        local toggle_flow = GuiBase.create_hflow(bar_flow, "fave_bar_toggle_flow")
        local toggle_btn = add_toggle_button(toggle_flow, player)
        -- Add slots flow and favorite buttons
        local slots_flow = GuiBase.create_hflow(bar_flow, "fave_bar_slots_flow")
        local pfaves = PlayerFavorites.new(player):get_favorites()

        local pdata = Cache.get_player_data(player)
        local fav_btns = build_favorite_buttons_row(slots_flow, player, pfaves, pdata.drag_favorite_index)
        local show = pdata.toggle_fav_bar_buttons
        fav_btns.visible = show

        handle_overflow_error(fave_bar_frame, fav_btns, pfaves)

        return fave_bar_frame
    end)
    _fave_bar_building_guard[pid] = nil
    if not success then error(result) end
    return result
end

--- Efficiently update only the slot row (fave_bar_slots_flow) for the given player
-- parent: the bar_flow container (parent of fave_bar_slots_flow)
function fave_bar.update_slot_row(player, bar_flow)
    if not (bar_flow and bar_flow.valid and bar_flow.children) then return end
    -- Destroy all children named fave_bar_slots_flow (robust to any state)
    for _, child in pairs(bar_flow.children) do
        if child.name == "fave_bar_slots_flow" then
            child.destroy()
            _G.print("[TF DEBUG] Destroyed fave_bar_slots_flow row.")
        end
    end
    local slots_flow = GuiBase.create_hflow(bar_flow, "fave_bar_slots_flow")
    local pdata = Cache.get_player_data(player)
    slots_flow.visible = pdata.toggle_fav_bar_buttons
    local pfaves = PlayerFavorites.new(player):get_favorites()
    local drag_index = pdata.drag_favorite_index or -1
    local fav_btns = build_favorite_buttons_row(slots_flow, player, pfaves, drag_index)
    _G.print("[TF DEBUG] Built new fave_bar_slots_flow row.")
    return fav_btns
end

fave_bar.update_slot_row = update_slot_row
fave_bar.get_or_create_main_flow = get_or_create_main_flow
return fave_bar
