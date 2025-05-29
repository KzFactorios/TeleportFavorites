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
        flow = parent.add { type = "flow", name = "tf_main_gui_flow", direction = "vertical", margin = { 8, 0, 0, 8 } }
    end
    return flow
end

-- Build the favorites bar to visually match the quickbar top row
function fave_bar.build_quickbar_style(player, parent)
    local main_flow = parent
    -- Remove old bar if present
    if main_flow.fave_bar_frame then main_flow.fave_bar_frame.destroy() end

    -- Outer frame for the bar (matches quickbar background)
    local bar_frame = main_flow.add {
        type = "frame",
        name = "fave_bar_frame",
        style = "slot_window_frame",
        direction = "horizontal"
    }
    bar_frame.style.padding = 4
    bar_frame.style.margin = 0
    bar_frame.style.vertically_stretchable = false

    -- Toggle button in its own padded subframe (like the quickbar's number button)
    local toggle_frame = bar_frame.add {
        type = "frame",
        name = "fave_bar_toggle_frame",
        style = "tf_fave_slots_row",
        direction = "horizontal",
        padding = 0,
        margin = 0
    }
    toggle_frame.style.vertically_stretchable = false
    toggle_frame.style.horizontally_stretchable = false

    local toggle_btn = toggle_frame.add {
        type = "sprite-button",
        name = "fave_bar_visible_btns_toggle",
        style = "tf_fave_toggle_button",
        sprite = SpriteEnum.HEART
    }
    toggle_btn.style.width = 36
    toggle_btn.style.height = 36
    toggle_btn.style.vertically_stretchable = false
    toggle_btn.style.horizontally_stretchable = false

    return bar_frame
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
        -- Use the new quickbar-style builder for the favorites bar
        local fave_bar_frame = fave_bar.build_quickbar_style(player, main_flow)
        -- Only one toggle button: the one created in build_quickbar_style
        -- Add slots frame and favorite buttons
        local slots_frame = fave_bar_frame.add {
            type = "frame",
            name = "fave_bar_slots_frame",
            style = "tf_fave_slots_row",
            direction = "horizontal",
        }
        local pfaves = PlayerFavorites.new(player):get_favorites()
        local pdata = Cache.get_player_data(player)

        local fav_btns = fave_bar.build_favorite_buttons_row(slots_frame, player, pfaves, pdata.drag_favorite_index)
        local show = pdata.toggle_fav_bar_buttons
        fav_btns.visible = show

        handle_overflow_error(fave_bar_frame, fav_btns, pfaves)

        return fave_bar_frame
    end)
    _fave_bar_building_guard[pid] = nil
    if not success then error(result) end
    return result
end

-- Build a row of favorite slot buttons for the favorites bar
function fave_bar.build_favorite_buttons_row(parent, player, pfaves, drag_index)
    drag_index = drag_index or -1
    local max_slots = Constants.settings.MAX_FAVORITE_SLOTS or 10
    for i = 1, max_slots do
        local fav = pfaves[i]
        local icon = pfaves[i].icon or nil
        local tooltip = { "tf-gui.fave_slot_tooltip", i }
        local style = "tf_slot_button_smallfont"
        if fav and not Favorite.is_blank_favorite(fav) then
            if fav.icon and fav.icon ~= "" then
                icon = fav.icon
            elseif SpriteEnum.DEFAULT_MAP_TAG then
                icon = SpriteEnum.DEFAULT_MAP_TAG
            end
            tooltip = Helpers.build_favorite_tooltip(fav, { slot = i }) or { "tf-gui.fave_slot_tooltip", i }
            if fav.locked then style = "tf_slot_button_locked" end
            if drag_index == i then style = "tf_slot_button_dragged" end
        end
        local btn = Helpers.create_slot_button(parent, "fave_bar_slot_" .. i, icon, tooltip, { style = style })
        btn.style = style
        btn.caption = tostring(i)
        btn.style.horizontal_align = "center"
        btn.style.vertical_align = "bottom"
        btn.style.font = "default-small"
        btn.style.top_padding = 0
        btn.style.bottom_padding = 2 -- move text closer to bottom
    end
    return parent
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
    local slots_frame = bar_flow.add {
        type = "frame",
        name = "fave_bar_slots_flow",
        style = "tf_fave_slots_row",
        direction = "horizontal"
    }
    local pdata = Cache.get_player_data(player)
    slots_frame.visible = pdata.toggle_fav_bar_buttons
    local pfaves = PlayerFavorites.new(player):get_favorites()
    local drag_index = pdata.drag_favorite_index or -1
    local fav_btns = build_favorite_buttons_row(slots_frame, player, pfaves, drag_index)
    _G.print("[TF DEBUG] Built new fave_bar_slots_flow row.")
    return fav_btns
end

fave_bar.update_slot_row = update_slot_row
fave_bar.get_or_create_main_flow = get_or_create_main_flow
return fave_bar
