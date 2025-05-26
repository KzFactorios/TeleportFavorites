-- data_viewer/data_viewer.lua
-- Data Viewer GUI for TeleportFavorites
-- Uses shared gui helpers from gui.lua

local gui = require("gui.gui")
local Constants = require("constants")

local data_viewer = {}

function data_viewer.build(player, parent, state)
    local Cache = require("core.cache.cache")
    local player_data = Cache.get_player_data(player)
    local font_size = player_data.data_viewer_font_size or 12
    local opacity = player_data.data_viewer_opacity or 1
    local data_viewer_state = player_data.data_viewer_state or {}
    local active_tab = data_viewer_state.active_tab or "player_data"

    -- Main frame
    local frame = gui.create_frame(parent, "data_viewer_frame", "vertical", "inside_shallow_frame_with_padding")
    frame.style.width = 1000
    frame.style.vertically_stretchable = true
    frame.style.opacity = opacity

    -- Titlebar
    gui.create_titlebar(frame, {"tf-gui.data_viewer_title"}, function() frame.destroy() end)

    -- Tabs
    local tabs = gui.create_hflow(frame, "data_viewer_tabs")
    local tab_names = {"player_data", "surface_data", "lookups", "all_data"}
    for _, tab in ipairs(tab_names) do
        local btn = gui.create_icon_button(tabs, "tab_"..tab, "utility/tab_icon", {"tf-gui.tab_"..tab}, "tf_slot_button")
        if tab == active_tab then btn.style.font_color = {r=1,g=0.8,b=0.2} end
    end

    -- Controls row
    local controls = gui.create_hflow(frame, "controls_row")
    gui.create_icon_button(controls, "opacity_btn", "utility/brush", {"tf-gui.opacity_tooltip"}, "tf_slot_button")
    gui.create_icon_button(controls, "font_plus_btn", "utility/add", {"tf-gui.font_plus_tooltip"}, "tf_slot_button")
    gui.create_icon_button(controls, "font_minus_btn", "utility/remove", {"tf-gui.font_minus_tooltip"}, "tf_slot_button")
    gui.create_icon_button(controls, "refresh_btn", "utility/refresh", {"tf-gui.refresh_tooltip"}, "tf_slot_button")
    gui.create_icon_button(controls, "close_btn", "utility/close_white", {"tf-gui.close_tooltip"}, "tf_slot_button")

    -- Data panel (scrollable)
    local scroll = frame.add{ type = "scroll-pane", name = "data_panel" }
    scroll.style.width = 980
    scroll.style.height = 400
    scroll.style.vertically_stretchable = true
    scroll.style.font = "default"
    scroll.style.font_size = font_size
    scroll.style.opacity = opacity

    -- Helper: pretty-print a table (1 level deep)
    local function pretty_table(tbl, indent)
        indent = indent or ""
        if type(tbl) ~= "table" then return tostring(tbl) end
        local lines = {}
        for k, v in pairs(tbl) do
            local vstr = (type(v)=="table") and "{...}" or tostring(v)
            table.insert(lines, indent..tostring(k)..": "..vstr)
        end
        return table.concat(lines, "\n")
    end

    -- Error handling for nil/missing data
    local function safe_pretty_table(tbl, indent)
        if not tbl then return "<nil>" end
        return pretty_table(tbl, indent)
    end

    -- Populate data panel based on active tab
    if active_tab == "player_data" then
        scroll.add{type="label", caption={"tf-gui.data_viewer_section_player"}, style="heading_2_label"}
        scroll.add{type="label", caption=safe_pretty_table(player_data)}
    elseif active_tab == "surface_data" then
        local surface = player.surface
        local surface_data = Cache.get_surface_data(surface.index)
        scroll.add{type="label", caption={"tf-gui.data_viewer_section_surface", surface.name}, style="heading_2_label"}
        scroll.add{type="label", caption=safe_pretty_table(surface_data)}
    elseif active_tab == "lookups" then
        local Lookups = require("core.cache.lookups")
        local lookups = Lookups.ensure_cache()
        scroll.add{type="label", caption={"tf-gui.data_viewer_section_lookups"}, style="heading_2_label"}
        scroll.add{type="label", caption=safe_pretty_table(lookups)}
    elseif active_tab == "all_data" then
        scroll.add{type="label", caption={"tf-gui.data_viewer_section_all"}, style="heading_2_label"}
        scroll.add{type="label", caption=safe_pretty_table(_G.storage)}
    else
        scroll.add{type="label", caption={"tf-gui.data_viewer_section_unknown"}}
    end

    -- Accessibility: tooltips for all controls
    for _, btn in pairs(controls.children) do
        btn.tooltip = btn.tooltip or {"tf-gui.data_viewer_control_tooltip"}
    end

    return frame
end

return data_viewer
