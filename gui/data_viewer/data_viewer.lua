--[[
TeleportFavorites Factorio Mod - Data Viewer GUI
------------------------------------------------
Module: gui/data_viewer/data_viewer.lua

Provides the Data Viewer GUI for inspecting player, surface, lookup, and global data.
- Displays structured data in a scrollable, tabbed interface for debugging and inspection.
- Supports dynamic font size and opacity controls, and tab switching for different data scopes.
- Uses shared GUI helpers from gui.lua for consistent UI construction.
- Handles robust error feedback if player data is missing.

Functions:
- data_viewer.build(player, parent, state):
    Constructs the Data Viewer GUI for the given player, parent element, and state.
    Handles tab selection, control buttons, and data rendering for each tab.
    Returns the created frame element.

--]]

local gui = require("gui.gui")
local Constants = require("constants")
local Cache = require("core.cache.cache")
local Lookups = require("core.cache.lookups")

local data_viewer = {}

function data_viewer.build(player, parent, state)
  local player_data = Cache.get_player_data(player)
  local font_size = (player_data and player_data.data_viewer_font_size) or 12
  local opacity = (player_data and player_data.data_viewer_opacity) or 1
  local data_viewer_state = (player_data and player_data.data_viewer_state) or {}
  local active_tab = data_viewer_state.active_tab or "player_data"

  local frame = gui.create_frame(parent, "data_viewer_frame", "vertical", "inside_shallow_frame_with_padding")
  frame.style.width, frame.style.vertically_stretchable, frame.style.opacity = 1000, true, opacity
  gui.create_titlebar(frame, {"tf-gui.data_viewer_title"}, function() frame.destroy() end)

  local tabs = gui.create_hflow(frame, "data_viewer_tabs")
  for _, tab in ipairs({"player_data", "surface_data", "lookups", "all_data"}) do
    local btn = gui.create_icon_button(tabs, "tab_"..tab, "utility/tab_icon", {"tf-gui.tab_"..tab}, "tf_slot_button")
    if tab == active_tab then btn.style.font_color = {r=1,g=0.8,b=0.2} end
  end

  local controls = gui.create_hflow(frame, "controls_row")
  for _, def in ipairs{{"opacity_btn","utility/brush","opacity_tooltip"},{"font_plus_btn","utility/add","font_plus_tooltip"},{"font_minus_btn","utility/remove","font_minus_tooltip"},{"refresh_btn","utility/refresh","refresh_tooltip"},{"close_btn","utility/close_white","close_tooltip"}} do
    gui.create_icon_button(controls, def[1], def[2], {"tf-gui."..def[3]}, "tf_slot_button")
  end

  local scroll = frame.add{ type = "scroll-pane", name = "data_panel" }
  scroll.style.width, scroll.style.height, scroll.style.vertically_stretchable, scroll.style.font, scroll.style.font_size, scroll.style.opacity = 980, 400, true, "default", font_size, opacity

  local function pretty_table(tbl, indent)
    indent = indent or ""
    if type(tbl) ~= "table" then return tostring(tbl) end
    local lines = {}
    for k, v in pairs(tbl) do table.insert(lines, indent..tostring(k)..": "..(type(v)=="table" and "{...}" or tostring(v))) end
    return table.concat(lines, "\n")
  end
  local function safe_pretty_table(tbl, indent) return tbl and pretty_table(tbl, indent) or "<nil>" end

  if active_tab == "player_data" then
    scroll.add{type="label", caption={"tf-gui.data_viewer_section_player"}, style="heading_2_label"}
    scroll.add{type="label", caption=safe_pretty_table(player_data)}
  elseif active_tab == "surface_data" then
    local surface = player.surface
    scroll.add{type="label", caption={"tf-gui.data_viewer_section_surface", surface.name}, style="heading_2_label"}
    scroll.add{type="label", caption=safe_pretty_table(Cache.get_surface_data(surface.index))}
  elseif active_tab == "lookups" then
    scroll.add{type="label", caption={"tf-gui.data_viewer_section_lookups"}, style="heading_2_label"}
    scroll.add{type="label", caption=safe_pretty_table(Lookups.ensure_cache())}
  elseif active_tab == "all_data" then
    scroll.add{type="label", caption={"tf-gui.data_viewer_section_all"}, style="heading_2_label"}
    scroll.add{type="label", caption=safe_pretty_table(_G.storage)}
  else
    scroll.add{type="label", caption={"tf-gui.data_viewer_section_unknown"}}
  end

  if not player_data then
    scroll.add{type="label", caption={"tf-gui.data_viewer_error_player_data"}, style="bold_label"}.style.font_color = {r=1, g=0.2, b=0.2}
  end
  for _, btn in pairs(controls.children) do btn.tooltip = btn.tooltip or {"tf-gui.data_viewer_control_tooltip"} end
  return frame
end

return data_viewer
