---@diagnostic disable: undefined-global
--[[
TeleportFavorites Factorio Mod - Data Viewer GUI
------------------------------------------------
Module: gui/data_viewer/data_viewer.lua

Provides the Data Viewer GUI for inspecting player, surface, lookup, and global data.
- Displays structured data in a scrollable, tabbed interface for debugging and inspection.
- Supports dynamic font size controls and tab switching for different data scopes.
- Uses shared GUI helpers from gui_base.lua for consistent UI construction.
- Handles robust error feedback if player data is missing.

NOTE: Factorio's Lua GUI API does NOT support per-element opacity. Attempts to set frame.style.opacity or similar will fail or error. Do not implement opacity controls in GUIs—this is a common pitfall for modders.

Functions:
- data_viewer.build(player, parent, state):
    Constructs the Data Viewer GUI for the given player, parent element, and state.
    Handles tab selection, control buttons, and data rendering for each tab.
    Returns the created frame element.

--]]

local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Cache = require("core.cache.cache")
local Lookups = require("core.cache.lookups")
local Helpers = require("core.utils.helpers_suite")
local SpriteEnum = require("gui.sprite_enum")

local data_viewer = {}

local function build_titlebar(parent)
  local flow = GuiBase.create_hflow(parent, "data_viewer_titlebar_flow")
  GuiBase.create_label(flow, "data_viewer_title_label", {"tf-gui.data_viewer_title"}, "frame_title")
  local filler = flow.add{type="empty-widget", name="data_viewer_titlebar_filler", style="draggable_space_header"}
  filler.style.horizontally_stretchable = true
  local close_btn = Helpers.create_slot_button(flow, "data_viewer_close_btn", SpriteEnum.CLOSE, {"tf-gui.close_tooltip"})
  return flow, close_btn
end

local function build_tabs_row(parent, active_tab)
  local tabs_flow = GuiBase.create_hflow(parent, "data_viewer_tabs_flow")
  local tab_defs = {
    {"data_viewer_player_data_tab", "tf-gui.tab_player_data", "player_data"},
    {"data_viewer_surface_data_tab", "tf-gui.tab_surface_data", "surface_data"},
    {"data_viewer_lookup_tab", "tf-gui.tab_lookups", "lookup"},
    {"data_viewer_all_data_tab", "tf-gui.tab_all_data", "all_data"}
  }
  local tab_width = 140
  local tab_height = 32
  for i, def in ipairs(tab_defs) do
    local is_active = (active_tab == def[3])
    local btn = tabs_flow.add{
      type = "sprite-button",
      name = def[1],
      sprite = nil,
      caption = {def[2]},
      style = is_active and "frame_action_button" or "button",
      tags = { tab_key = def[3] },
      selected = is_active
    }
    -- Only set supported properties. All visual indicator is via 'selected' and style.
    btn.style.horizontally_stretchable = false
    btn.style.vertically_stretchable = false
    btn.style.width = tab_width
    btn.style.height = tab_height
    btn.style.top_padding = 0
    btn.style.bottom_padding = 0
    btn.style.left_padding = 8
    btn.style.right_padding = 8
    btn.style.margin = 0
    if i > 1 then btn.style.left_margin = 4 end -- small gap between tabs
  end
  -- Add a filler to push actions to the right
  local filler = tabs_flow.add{type="empty-widget", name="data_viewer_tabs_filler"}
  filler.style.horizontally_stretchable = true
  -- Inline action buttons (font size, refresh)
  local actions_flow = GuiBase.create_hflow(tabs_flow, "data_viewer_tab_actions_inline_flow")
  actions_flow.style.vertical_align = "center"
  actions_flow.style.horizontal_spacing = 12
  -- Font size controls
  local font_size_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_font_size_flow")
  font_size_flow.style.vertical_align = "center"
  font_size_flow.style.horizontal_spacing = 2
  GuiBase.create_label(font_size_flow, "data_viewer_font_label", {"tf-gui.font_label"}).style.right_margin = 2
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_down_btn", SpriteEnum.ARROW_DOWN, {"tf-gui.font_minus_tooltip"}).style.margin = 0
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_up_btn", SpriteEnum.ARROW_UP, {"tf-gui.font_plus_tooltip"}).style.margin = 0
  -- Refresh controls
  local refresh_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_refresh_flow")
  refresh_flow.style.vertical_align = "center"
  refresh_flow.style.horizontal_spacing = 2
  GuiBase.create_label(refresh_flow, "data_viewer_refresh_label", {"tf-gui.refresh_label"}).style.right_margin = 2
  Helpers.create_slot_button(refresh_flow, "data_viewer_tab_actions_refresh_data_btn", SpriteEnum.REFRESH, {"tf-gui.refresh_tooltip"}).style.margin = 0
  return tabs_flow
end

local function build_content_flow(parent)
  -- Use a vertical flow for tree view, wrapped in a frame for styling
  local frame = parent.add{type="frame", name="data_viewer_content_frame", style="inside_deep_frame"}
  local content_flow = GuiBase.create_vflow(frame, "data_viewer_content_flow")
  content_flow.style.left_margin = 8
  content_flow.style.right_margin = 8
  content_flow.style.horizontally_stretchable = true
  return content_flow, frame
end

function data_viewer.build(player, parent, state)
  -- Ensure a valid tab is selected
  local valid_tabs = { player_data = true, surface_data = true, lookup = true, all_data = true }
  if not state.active_tab or not valid_tabs[state.active_tab] then
    state.active_tab = "player_data"
  end
  -- Main dialog frame (resizable)
  local frame = parent.add{type="frame", name="data_viewer_frame", style="data_viewer_frame", direction="vertical"}
  frame.caption = ""
  --frame.force_auto_center() -- optional: keep centered on open

  -- Main vertical frame for dialog content (per hierarchy spec)
  local inner_flow = frame.add{type="frame", name="data_viewer_inner_flow", style="invisible_frame", direction="vertical"}

  -- Title bar (top row)
  local title_flow, close_btn = build_titlebar(inner_flow)

  -- Tabs row (second row, now includes actions)
  local tabs_flow = build_tabs_row(inner_flow, state.active_tab)

  -- Content area (tree view, vertical flow)
  -- Use a frame for inside_deep_frame, then a scroll-pane for content
  local content_frame = inner_flow.add{type="frame", name="data_viewer_content_frame", style="inside_deep_frame"}
  local content_scroll = content_frame.add{type="scroll-pane", name="data_viewer_content_scroll", style="data_viewer_content_scroll", direction="vertical"}
  content_scroll.style.left_margin = 8
  content_scroll.style.right_margin = 8
  content_scroll.style.horizontally_stretchable = true
  content_scroll.style.vertically_stretchable = true
  -- Remove explicit width/height assignments; use style for resizing
  -- content_scroll.style.width = 1000
  -- content_scroll.style.maximal_width = 1000
  -- content_scroll.style.minimal_width = 600
  -- content_scroll.style.height = 600
  -- content_scroll.style.maximal_height = 600
  -- content_scroll.style.minimal_height = 200
  content_scroll.vertical_scroll_policy = "auto"
  content_scroll.horizontal_scroll_policy = "auto"

  local content_flow = content_scroll.add{type="flow", name="data_viewer_content_flow", direction="vertical"}
  content_flow.style.horizontally_stretchable = true
  content_flow.style.vertically_stretchable = false

  -- Keyboard navigation for tabs (tab/shift-tab)
  -- (No .focusable or .focus() in Factorio API; navigation is handled by custom input events)

  -- Helper to get or set player data_viewer_settings
  local function get_settings()
    local pdata = Cache.get_player_data(player)
    pdata.data_viewer_settings = pdata.data_viewer_settings or { font_size = 12 }
    return pdata.data_viewer_settings
  end

  -- In render_table_tree, set font using .style.font if available
  local function set_label_font(lbl, font_size)
    local font_name = "tf_font_"..tostring(font_size)
    pcall(function() lbl.style.font = font_name end)
  end
  local function render_table_tree(parent, data, indent, visited, font_size, row_index)
    indent = indent or 0
    visited = visited or {}
    font_size = font_size or 12
    row_index = row_index or 1
    local prefix = string.rep("\t", indent)
    if type(data) ~= "table" then
      local row = parent.add{type="flow", direction="horizontal"}
      if row_index % 2 == 1 then row.style = "data_viewer_row_odd" end
      local lbl = row.add{type="label", caption=prefix..tostring(data).." ["..type(data).."]"}
      set_label_font(lbl, font_size)
      if lbl.style then lbl.style.single_line = false end
      return row_index + 1
    end
    if visited[data] then
      local row = parent.add{type="flow", direction="horizontal"}
      if row_index % 2 == 1 then row.style = "data_viewer_row_odd" end
      local lbl = row.add{type="label", caption=prefix.."<recursion>"}
      set_label_font(lbl, font_size)
      if lbl.style then lbl.style.single_line = false end
      return row_index + 1
    end
    visited[data] = true
    for k, v in pairs(data) do
      local is_table = type(v) == "table"
      if is_table then
        local row = parent.add{type="flow", direction="horizontal"}
        if row_index % 2 == 1 then row.style = "data_viewer_row_odd" end
        local lbl = row.add{type="label", caption=prefix..tostring(k)..": {"}
        set_label_font(lbl, font_size)
        if lbl.style then lbl.style.single_line = false end
        row_index = row_index + 1
        row_index = render_table_tree(parent, v, indent + 2, visited, font_size, row_index)
        local close_row = parent.add{type="flow", direction="horizontal"}
        if row_index % 2 == 1 then close_row.style = "data_viewer_row_odd" end
        local close_lbl = close_row.add{type="label", caption=string.rep("\t", indent).."}"}
        set_label_font(close_lbl, font_size)
        if close_lbl.style then close_lbl.style.single_line = false end
        row_index = row_index + 1
      else
        local row = parent.add{type="flow", direction="horizontal"}
        if row_index % 2 == 1 then row.style = "data_viewer_row_odd" end
        local valstr = tostring(v)
        if type(v) ~= "string" and type(v) ~= "number" then valstr = valstr.." ["..type(v).."]" end
        local lbl = row.add{type="label", caption=prefix..tostring(k).." = "..valstr}
        set_label_font(lbl, font_size)
        if lbl.style then lbl.style.single_line = false end
        row_index = row_index + 1
      end
    end
    visited[data] = nil
    return row_index
  end

  -- Helper functions to get data for each tab
  local function get_player_data()
    return (player and Cache.get_player_data(player)) or {}
  end
  local function get_surface_data()
    local sidx = (player and player.surface and player.surface.index) or nil
    if sidx then
      return Cache.get_surface_data(sidx)
    end
    return {}
  end
  local function get_lookup_data()
    local ldata = Lookups.get and Lookups.get("chart_tag_cache")
    if not ldata then
      ldata = Lookups.ensure_cache and Lookups.ensure_cache() or { ["error"] = "No lookup data available" }
    end
    return ldata
  end
  local function get_all_data()
    local pdata = get_player_data()
    local sdata = get_surface_data()
    local gdata = global and global.teleport_favorites or {}
    return {
      player_data = pdata,
      surface_data = sdata,
      global_data = gdata
    }
  end

  -- Initial population of content area with player data
  local function update_content()
    content_flow.clear()
    local settings = get_settings()
    local font_size = settings.font_size or 12
    local active_tab = state.active_tab
    if active_tab == "player_data" then
      render_table_tree(content_flow, get_player_data(), 0, nil, font_size)
    elseif active_tab == "surface_data" then
      render_table_tree(content_flow, get_surface_data(), 0, nil, font_size)
    elseif active_tab == "lookup" then
      render_table_tree(content_flow, get_lookup_data(), 0, nil, font_size)
    elseif active_tab == "all_data" then
      render_table_tree(content_flow, get_all_data(), 0, nil, font_size)
    end
  end

  -- Initial content update
  update_content()

  -- Event handlers
  local function on_close_btn_click()
    frame.destroy()
  end
  local function on_tab_btn_click(event)
    local new_tab = event.element.tags.tab_key
    if new_tab and new_tab ~= state.active_tab then
      state.active_tab = new_tab
      -- Update tab button styles
      for _, btn in ipairs(tabs_flow.children) do
        if btn.type == "sprite-button" then
          btn.selected = (btn.tags.tab_key == new_tab)
          btn.style = (btn.tags.tab_key == new_tab) and "frame_action_button" or "button"
        end
      end
      -- Update content for new tab
      update_content()
    end
  end
  local function on_font_size_btn_click(event)
    local btn = event.element
    local settings = get_settings()
    local font_size = settings.font_size or 12
    if btn.name == "data_viewer_actions_font_down_btn" and font_size > 8 then
      font_size = font_size - 1
    elseif btn.name == "data_viewer_actions_font_up_btn" and font_size < 24 then
      font_size = font_size + 1
    end
    settings.font_size = font_size
    update_content()
  end
  local function on_refresh_btn_click()
    update_content()
  end

  -- Event subscriptions
  -- Remove all direct .on_click assignments; handled by event dispatcher

  return frame
end

return data_viewer
