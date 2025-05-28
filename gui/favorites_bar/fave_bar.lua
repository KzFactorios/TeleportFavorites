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

local fave_bar = {}

local function create_fave_bar_frame(parent)
    local fave_bar_frame = GuiBase.create_frame(parent, "fave_bar_frame", "horizontal", "inside_shallow_frame_with_padding")
    local s = fave_bar_frame.style
    s.top_padding, s.bottom_padding, s.left_padding, s.right_padding = 2, 2, 4, 4
    return fave_bar_frame
end

local function add_toggle_button(toggle_flow, player)
    -- Place the toggle button inside the toggle_flow
    local btn = Helpers.create_slot_button(toggle_flow, "fave_bar_visible_btns_toggle", "red_tf_slot_button_20", {"tf-gui.toggle_fave_bar"})
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
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
        local fav = type(pfaves[i]) == "table" and pfaves[i] or Favorite.get_blank_favorite()
        local is_blank = Favorite.is_blank_favorite(fav)
        local is_locked = fav.locked or false
        local icon = (not is_blank and fav.tag and fav.tag.icon ~= "") and fav.tag.icon or nil
        local tooltip = not is_blank and Helpers.build_favorite_tooltip(fav) or nil
        -- Use normalized slot button naming: "fave_bar_slot_" .. i
        local btn = Helpers.create_slot_button(slots_flow, "fave_bar_slot_"..i, icon, tooltip, {
            locked = is_locked and not is_blank,
            enabled = not is_blank,
            border_color = drag_index == i and {r=0.2,g=0.7,b=1,a=1} or (drag_index and {r=1,g=1,b=0.2,a=1}) or (is_locked and not is_blank and {r=1,g=0.5,b=0,a=1}) or nil
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
        _G.print("[TF DEBUG] fave_bar.build: re-entrant call for player " .. tostring(pid) .. ", skipping.")
        return
    end
    _fave_bar_building_guard[pid] = true
    _G.print("[TF DEBUG] fave_bar.build: ENTER for player " .. tostring(pid))
    local success, result = pcall(function()
        local player_settings = Settings:getPlayerSettings(player)
        if not player_settings.favorites_on then return end
        local mode = player and player.render_mode
        if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
            return
        end
        if parent.fave_bar_frame then
            parent.fave_bar_frame.destroy()
        end
        local fave_bar_frame = create_fave_bar_frame(parent)
        local bar_flow = GuiBase.create_hflow(fave_bar_frame, "fave_bar_flow")
        -- Add toggle flow and button
        local toggle_flow = GuiBase.create_hflow(bar_flow, "fave_bar_toggle_flow")
        local toggle_btn = add_toggle_button(toggle_flow, player)
        -- Add slots flow and favorite buttons
        local slots_flow = GuiBase.create_hflow(bar_flow, "fave_bar_slots_flow")
        local pfaves = PlayerFavorites.new(player):get_all()
        local drag_index = _G.storage and _G.storage.players and _G.storage.players[player.index] and _G.storage.players[player.index].drag_favorite_index
        local fav_btns = build_favorite_buttons_row(slots_flow, player, pfaves, drag_index)
        handle_overflow_error(fave_bar_frame, fav_btns, pfaves)
        local function update_toggle_state()
            local pdata = Cache.get_player_data(player)
            local show = pdata.toggle_fav_bar_buttons ~= false
            fav_btns.visible = show
        end
        update_toggle_state()
        return fave_bar_frame
    end)
    _fave_bar_building_guard[pid] = nil
    _G.print("[TF DEBUG] fave_bar.build: EXIT for player " .. tostring(pid))
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
    local pfaves = PlayerFavorites.new(player):get_all()
    local drag_index = _G.storage and _G.storage.players and _G.storage.players[player.index] and _G.storage.players[player.index].drag_favorite_index
    local fav_btns = build_favorite_buttons_row(slots_flow, player, pfaves, drag_index)
    _G.print("[TF DEBUG] Built new fave_bar_slots_flow row.")
    return fav_btns
end

return fave_bar
