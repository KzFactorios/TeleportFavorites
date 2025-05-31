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

-- Shared helpers for data rendering and retrieval
local function set_label_font(lbl, font_size)
  local font_name = "tf_font_"..tostring(font_size)
  pcall(function() lbl.style.font = font_name end)
  -- Do NOT set lbl.style.height or any other style property here
end
local function render_table_tree(parent, data, indent, visited, font_size, row_index)
  indent = indent or 0
  visited = visited or {}
  font_size = font_size or 12
  row_index = row_index or 1
  local prefix = string.rep("\t", indent)
  local function add_row(parent, caption, font_size, row_index)
    local style = (row_index % 2 == 1) and "data_viewer_row_odd_label" or "data_viewer_row_even_label"
    local lbl = parent.add{type="label", caption=caption, style=style}
    set_label_font(lbl, font_size)
    lbl.style.top_margin = 2
    lbl.style.font_color = {r=1, g=1, b=1} -- White for all data rows
    -- Do NOT set lbl.style.height or any other style property here
    return lbl
  end
  if type(data) ~= "table" then
    add_row(parent, prefix..tostring(data).." ["..type(data).."]", font_size, row_index)
    return row_index + 1
  end
  if visited[data] then
    add_row(parent, prefix.."<recursion>", font_size, row_index)
    return row_index + 1
  end
  visited[data] = true
  for k, v in pairs(data) do
    local is_table = type(v) == "table"
    if is_table then
      add_row(parent, prefix..tostring(k)..": {", font_size, row_index)
      row_index = row_index + 1
      row_index = render_table_tree(parent, v, indent + 2, visited, font_size, row_index)
      add_row(parent, string.rep("\t", indent).."}", font_size, row_index)
      row_index = row_index + 1
    else
      local valstr = tostring(v)
      if type(v) ~= "string" and type(v) ~= "number" then valstr = valstr.." ["..type(v).."]" end
      add_row(parent, prefix..tostring(k).." = "..valstr, font_size, row_index)
      row_index = row_index + 1
    end
  end
  visited[data] = nil
  return row_index
end
local function get_player_data(player)
  return (player and Cache.get_player_data(player)) or {}
end
local function get_surface_data(player)
  local sidx = (player and player.surface and player.surface.index) or nil
  if sidx then
    return Cache.get_surface_data(sidx)
  end
  return {}
end
local function get_lookup_data()
  local ldata = Lookups.get and Lookups.get("chart_tag_cache")
  if not ldata or next(ldata) == nil then
    ldata = { no_objects = true }
  end
  -- Always return as { chart_tag_cache = ... } for clarity in Data Viewer
  return { chart_tag_cache = ldata }
end

local function build_titlebar(parent)
  local flow = GuiBase.create_hflow(parent, "data_viewer_titlebar_flow")
  GuiBase.create_label(flow, "data_viewer_title_label", {"tf-gui.data_viewer_title"}, "frame_title")
  local filler = flow.add{type="empty-widget", name="data_viewer_titlebar_filler", style="draggable_space_header"}
  filler.style.horizontally_stretchable = true
  local close_btn = Helpers.create_slot_button(flow, "data_viewer_close_btn", SpriteEnum.CLOSE, {"tf-gui.close_tooltip"})
  return flow, close_btn
end

-- Helper to build the tab row and tab actions as per new hierarchy
local function build_tabs_row(parent, active_tab)
  local tabs_flow = GuiBase.create_hflow(parent, "data_viewer_tabs_flow")
  local tab_defs = {
    {"data_viewer_player_data_tab", "tf-gui.tab_player_data", "player_data"},
    {"data_viewer_surface_data_tab", "tf-gui.tab_surface_data", "surface_data"},
    {"data_viewer_lookup_tab", "tf-gui.tab_lookups", "lookup"},
    {"data_viewer_all_data_tab", "tf-gui.tab_all_data", "all_data"}
  }
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
    btn.style.horizontally_stretchable = false
    btn.style.vertically_stretchable = false
    btn.style.width = 140
    btn.style.height = 32
    btn.style.top_padding = 0
    btn.style.bottom_padding = 0
    btn.style.left_padding = 8
    btn.style.right_padding = 8
    btn.style.margin = 0
    if i > 1 then btn.style.left_margin = 4 end
  end
  -- Tab actions flow (right-aligned)
  local filler = tabs_flow.add{type="empty-widget", name="data_viewer_tabs_filler"}
  filler.style.horizontally_stretchable = true
  local actions_flow = GuiBase.create_hflow(tabs_flow, "data_viewer_tab_actions_flow")
  actions_flow.style.vertical_align = "center"
  actions_flow.style.horizontal_spacing = 12
  -- Font size controls
  local font_size_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_font_size_flow")
  font_size_flow.style.vertical_align = "center"
  font_size_flow.style.horizontal_spacing = 2
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_down_btn", SpriteEnum.ARROW_DOWN, {"tf-gui.font_minus_tooltip"}).style.margin = 0
  Helpers.create_slot_button(font_size_flow, "data_viewer_actions_font_up_btn", SpriteEnum.ARROW_UP, {"tf-gui.font_plus_tooltip"}).style.margin = 0
  -- Refresh button
  Helpers.create_slot_button(actions_flow, "data_viewer_tab_actions_refresh_data_btn", SpriteEnum.REFRESH, {"tf-gui.refresh_tooltip"}).style.margin = 0
  return  tabs_flow    
end

local function get_lookup_data()
  local ldata = Lookups.get and Lookups.get("chart_tag_cache")
  if not ldata or next(ldata) == nil then
    ldata = { no_objects = true }
  end
  -- Always return as { chart_tag_cache = ... } for clarity in Data Viewer
  return { chart_tag_cache = ldata }
end

-- Helper to parse a table row into a compact string, combining simple tables onto one line
local function rowline_parser(key, value, indent, max_line_len)
  local INDENT_STR = "  "
  indent = indent or 0
  max_line_len = max_line_len or 80
  local prefix = string.rep(INDENT_STR, indent)
  if type(value) ~= "table" then
    local valstr = tostring(value)
    if type(value) ~= "string" and type(value) ~= "number" then valstr = valstr.." ["..type(value).."]" end
    local line = prefix..tostring(key).." = "..valstr
    return line, false
  end
  -- If table is empty
  local n = 0; for _ in pairs(value) do n = n + 1 end
  if n == 0 then
    return prefix..tostring(key).." = {}", true
  end
  -- If table is shallow and all scalars, combine onto one line
  local parts = {}
  local all_scalar = true
  for k, v in pairs(value) do
    if type(v) == "table" or type(v) == "function" then all_scalar = false; break end
    local valstr = tostring(v)
    if type(v) ~= "string" and type(v) ~= "number" then valstr = valstr.." ["..type(v).."]" end
    table.insert(parts, tostring(k).." = "..valstr)
  end
  if all_scalar and #parts > 0 then
    local line = prefix..tostring(key).." = { "..table.concat(parts, ", ").." }"
    if #line <= max_line_len then
      return line, true
    end
  end
  -- Otherwise, not compactable
  return prefix..tostring(key).." = {", false
end

-- Render the data as a compact, hierarchical, property-only table with alternating row colors, indentation, and line wrapping
local function render_compact_data_rows(parent, data, indent, font_size, row_index, visited, force_white)
  indent = indent or 0
  font_size = font_size or 12
  row_index = row_index or 1
  visited = visited or {}
  local INDENT_STR = "  "
  local MAX_LINE_LEN = 80
  local function is_method(val)
    return type(val) == "function"
  end
  local function add_row(parent, text, font_size, row_index)
    local style = (row_index % 2 == 1) and "data_viewer_row_odd_label" or "data_viewer_row_even_label"
    local lbl = parent.add{type="label", caption=text, style=style}
    set_label_font(lbl, font_size)
    lbl.style.top_margin = 2
    lbl.style.font_color = {r=1, g=1, b=1} -- White for all data rows
    return lbl
  end
  if type(data) ~= "table" then
    local valstr = tostring(data) .. " ["..type(data).."]"
    if #valstr > MAX_LINE_LEN then
      local first = valstr:sub(1, MAX_LINE_LEN)
      local rest = valstr:sub(MAX_LINE_LEN+1)
      add_row(parent, string.rep(INDENT_STR, indent)..first, font_size, row_index)
      row_index = row_index + 1
      add_row(parent, string.rep(INDENT_STR, indent+1)..rest, font_size, row_index)
      row_index = row_index + 1
    else
      add_row(parent, string.rep(INDENT_STR, indent)..valstr, font_size, row_index)
      row_index = row_index + 1
    end
    return row_index
  end
  if visited[data] then
    add_row(parent, string.rep(INDENT_STR, indent).."<recursion>", font_size, row_index)
    return row_index + 1
  end
  visited[data] = true
  for k, v in pairs(data) do
    if not is_method(v) then
      local line, compact = rowline_parser(k, v, indent, MAX_LINE_LEN)
      if compact == true then
        add_row(parent, line, font_size, row_index)
        row_index = row_index + 1
      elseif type(v) == "table" then
        add_row(parent, line, font_size, row_index)
        row_index = row_index + 1
        row_index = render_compact_data_rows(parent, v, indent+1, font_size, row_index, visited)
        add_row(parent, string.rep(INDENT_STR, indent).."}", font_size, row_index)
        row_index = row_index + 1
      else
        add_row(parent, line, font_size, row_index)
        row_index = row_index + 1
      end
    end
  end
  visited[data] = nil
  return row_index
end

-- Show flying text when data is refreshed
function data_viewer.show_refresh_flying_text(player)
  if not (player and player.valid) then return end
  local pos = player.position or {0,0}
  -- Offset flying text upward so it appears above the Data Viewer panel
  pos = {x = pos.x, y = pos.y - 4}
  player.create_local_flying_text{
    text = {"tf-gui.data_refreshed_flying_text"},
    position = pos,
    color = {r=0.8, g=0.95, b=1, a=1}
  }
end

function data_viewer.build(player, parent, state)
  if not (state and state.data and type(state.data) == "table") then
    return
  end
  local n = 0
  for _ in pairs(state.data) do n = n + 1 end
  -- Ensure data and top_key are defined from state
  local data = state and state.data
  local top_key = state and state.top_key

  local font_size = (state and state.font_size) or 10
  -- Main dialog frame (resizable)
  local frame = parent.add{type="frame", name="data_viewer_frame", style="data_viewer_frame", direction="vertical"}
  frame.caption = ""
  frame.style.minimal_width = 480
  frame.style.minimal_height = 320
  -- Remove debug label at the very top
  -- frame.add{type="label", caption="[TF DEBUG] Data Viewer GUI visible for player: "..(player and player.name or "nil"), style="data_viewer_row_odd_label"}
  -- Titlebar
  local titlebar = GuiBase.create_hflow(frame, "data_viewer_titlebar_flow")
  GuiBase.create_label(titlebar, "data_viewer_title_label", {"tf-gui.data_viewer_title"}, "frame_title")
  local filler = titlebar.add{type="empty-widget", name="data_viewer_titlebar_filler", style="draggable_space_header"}
  filler.style.horizontally_stretchable = true
  Helpers.create_slot_button(titlebar, "data_viewer_close_btn", SpriteEnum.CLOSE, {"tf-gui.close_tooltip"})
  -- Inner flow (vertical, invisible_frame)
  local inner_flow = frame.add{type="frame", name="data_viewer_inner_flow", style="invisible_frame", direction="vertical"}
  -- Tabs row (with tab actions)
  build_tabs_row(inner_flow, state.active_tab)
  -- Content area: vertical flow, then table
  local content_flow = inner_flow.add{type="flow", name="data_viewer_content_flow", direction="vertical"}
  content_flow.style.horizontally_stretchable = true
  content_flow.style.vertically_stretchable = true

  -- Table for data rows (single column for compactness)
  local data_table = content_flow.add{type="table", name="data_viewer_table", column_count=1, style="data_viewer_table"}
  data_table.style.horizontally_stretchable = true
  data_table.style.vertically_stretchable = true -- Fix: allow table to stretch vertically
  data_table.style.minimal_width = 400
  data_table.style.minimal_height = 400
  data_table.style.top_padding = 8
  data_table.style.bottom_padding = 16
  data_table.style.left_padding = 8
  data_table.style.right_padding = 12
  data_table.style.width = 1000 -- Fix: force table width to match viewer
  data_table.style.maximal_width = 1000

  -- REMOVE DEBUG LABEL: Remove debug_data_str label
  -- data_table.add{type="label", caption=debug_data_str, style="data_viewer_row_even_label"}
  -- Patch: If data is nil or empty, always show top_key = { } and closing brace, never [NO DATA TO DISPLAY]
  if data == nil or (type(data) == "table" and next(data) == nil) then
    if not top_key then top_key = "player_data" end
    local style = "data_viewer_row_odd_label"
    local lbl = data_table.add{type="label", caption=top_key.." = {", style=style}
    set_label_font(lbl, font_size)
    lbl.style.font_color = {r=1, g=1, b=1}
    lbl.style.top_margin = 2
    local lbl2 = data_table.add{type="label", caption="}", style="data_viewer_row_even_label"}
    set_label_font(lbl2, font_size)
    lbl2.style.font_color = {r=1, g=1, b=1}
    lbl2.style.top_margin = 2
    return frame
  end
  
  -- Defensive: ensure top_key is always set
  if not top_key then top_key = "player_data" end

  -- Show the top-level key and render the data as a tree under it
  local style = "data_viewer_row_odd_label"
  local lbl = data_table.add{type="label", caption=top_key.." = {", style=style}
  set_label_font(lbl, font_size)
  lbl.style.font_color = {r=1, g=1, b=1} -- White for top key
  lbl.style.top_margin = 2
  
  local row_start = 1
  local row_end = 1
  if type(data) == "table" then
    row_end = render_compact_data_rows(data_table, data, 0, font_size, row_start, nil, true)
    if row_end == row_start then
      local no_data_lbl2 = data_table.add{type="label", caption="[NO DATA TO DISPLAY]", style="data_viewer_row_even_label"}
      no_data_lbl2.style.font_color = {r=1, g=0, b=0} -- Bright red for debug
    end
  else
    local no_data_lbl3 = data_table.add{type="label", caption="[NO DATA TO DISPLAY]", style="data_viewer_row_even_label"}
    no_data_lbl3.style.font_color = {r=1, g=0, b=0} -- Bright red for debug
  end
  
  local lbl2 = data_table.add{type="label", caption="}", style="data_viewer_row_even_label"}
  set_label_font(lbl2, font_size)
  lbl2.style.font_color = {r=1, g=1, b=1} -- White for closing brace
  lbl2.style.top_margin = 2
  -- REMOVE TEST LABEL: Remove visible test label for Data Viewer GUI
  -- caption = "[TEST] Data Viewer GUI is visible!",
  -- Always return the frame so the GUI is built
  return frame
end

return data_viewer
