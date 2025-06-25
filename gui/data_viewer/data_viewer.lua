---@diagnostic disable: undefined-global, missing-fields, param-type-mismatch, assign-type-mismatch, need-check-nil
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
local Cache = require("core.cache.cache")
local GuiUtils = require("core.utils.gui_utils")
local GameHelpers = require("core.utils.game_helpers")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")


local data_viewer = {}

-- Shared helpers for data rendering and retrieval
local function set_label_font(lbl, font_size)
  local font_name = "tf_font_" .. tostring(font_size)
  local success, err = pcall(function()
    lbl.style.font = font_name
    -- Set line height proportional to font size for better readability
    -- For data viewer, we want tight line spacing but still readable
    local line_height = math.max(font_size + 1, math.floor(font_size * 1.25 + 1))
    lbl.style.minimal_height = line_height
  end)
  if not success then
    ErrorHandler.debug_log("Failed to set font and line height", {
      font_name = font_name,
      font_size = font_size,
      error = err
    })
  end
end

local function render_table_tree(parent, data, indent, visited, font_size, row_index)
  indent = indent or 0
  visited = visited or {}
  font_size = font_size or 12
  row_index = row_index or 1
  local prefix = string.rep("\t", indent)
  local function add_row(parent, caption, font_size, row_index)
    local style = (row_index % 2 == 1) and "data_viewer_row_odd_label" or "data_viewer_row_even_label"
    local lbl = GuiBase.create_label(parent, "data_row_" .. (row_index or 1), caption, style)
    set_label_font(lbl, font_size)
    -- Note: Some style properties like top_margin and font_color may not be settable on all label types
    return lbl
  end
  if type(data) ~= "table" then
    add_row(parent, prefix .. tostring(data) .. " [" .. type(data) .. "]", font_size, row_index)
    return row_index + 1
  end
  if visited[data] then
    add_row(parent, prefix .. "<recursion>", font_size, row_index)
    return row_index + 1
  end
  visited[data] = true
  for k, v in pairs(data) do
    local is_table = type(v) == "table"
    if is_table then
      add_row(parent, prefix .. tostring(k) .. ": {", font_size, row_index)
      row_index = row_index + 1
      row_index = render_table_tree(parent, v, indent + 2, visited, font_size, row_index)
      add_row(parent, string.rep("\t", indent) .. "}", font_size, row_index)
      row_index = row_index + 1
    else
      local valstr = tostring(v)
      if type(v) ~= "string" and type(v) ~= "number" then valstr = valstr .. " [" .. type(v) .. "]" end
      add_row(parent, prefix .. tostring(k) .. " = " .. valstr, font_size, row_index)
      row_index = row_index + 1
    end
  end
  visited[data] = nil
  return row_index
end

-- Builds the titlebar for the data viewer window
-- Builds the titlebar for the data viewer window using shared helpers
local function build_titlebar(parent) --(parent, name, title, close_button_name, drag_handle_target)
  local _tb, title_label, _cb = GuiBase.create_titlebar(parent, "data_viewer_titlebar", "data_viewer_close_btn")
  ---@diagnostic disable-next-line: assign-type-mismatch
  if title_label ~= nil then title_label.caption = { "tf-gui.data_viewer_title" } end
  return
end

-- Helper to build the tab row and tab actions as per new hierarchy
local function build_tabs_row(parent, active_tab)
  local tabs_flow = GuiBase.create_hflow(parent, "data_viewer_tabs_flow")
  local tab_defs = {
    { "data_viewer_player_data_tab",  "tf-gui.tab_player_data",  "player_data" },
    { "data_viewer_surface_data_tab", "tf-gui.tab_surface_data", "surface_data" },
    { "data_viewer_lookup_tab",       "tf-gui.tab_lookups",      "lookup" },
    { "data_viewer_all_data_tab",     "tf-gui.tab_all_data",     "all_data" }
  } -- Functional approach to tab creation
  
  local function create_tab_button(def, index)
    local element_name, caption_key, tab_key = def[1], def[2], def[3]
    local is_active = (tab_key == active_tab)
    local style = (index > 1) and "tf_data_viewer_tab_button_margin" or "tf_data_viewer_tab_button"
    if is_active then
      style = "tf_data_viewer_tab_button_active"
    end
    -- Pass the localization key as a LocalisedString table for correct localization
    ---@diagnostic disable-next-line: assign-type-mismatch
    local btn = GuiBase.create_button(tabs_flow, element_name, {caption = caption_key}, style)
    btn.enabled = not is_active
    return btn
  end
  
  -- Process each tab definition with the creation function
  for i, def in ipairs(tab_defs) do
    create_tab_button(def, i)
  end
  -- Create filler widget to push action buttons to the right
  GuiBase.create_empty_widget(tabs_flow, "data_viewer_tabs_filler", "tf_draggable_space_header")

  -- Create actions flow for font size and refresh buttons
  local actions_flow = GuiBase.create_hflow(tabs_flow, "data_viewer_tab_actions_flow", "tf_data_viewer_actions_flow")
  local font_size_flow = GuiBase.create_hflow(actions_flow, "data_viewer_actions_font_size_flow",
    "tf_data_viewer_font_size_flow")

  -- Create font size buttons
  local font_down_btn = GuiUtils.create_slot_button(font_size_flow, "data_viewer_actions_font_down_btn",
    Enum.SpriteEnum.ARROW_DOWN,
    { "tf-gui.font_minus_tooltip" }, { style = "tf_data_viewer_font_size_button_minus" })
  local font_up_btn = GuiUtils.create_slot_button(font_size_flow, "data_viewer_actions_font_up_btn",
    Enum.SpriteEnum.ARROW_UP,
    { "tf-gui.font_plus_tooltip" }, { style = "tf_data_viewer_font_size_button_plus" })

  -- Create refresh button
  local refresh_btn = GuiUtils.create_slot_button(actions_flow, "data_viewer_tab_actions_refresh_data_btn",
    Enum.SpriteEnum.REFRESH,
    { "tf-gui.refresh_tooltip" }, { style = "tf_data_viewer_font_size_button_refresh" })

  -- Debug: Verify buttons were created
  ErrorHandler.debug_log("Data viewer action buttons created", {
    font_down_valid = font_down_btn and font_down_btn.valid,
    font_up_valid = font_up_btn and font_up_btn.valid,
    refresh_valid = refresh_btn and refresh_btn.valid,
    font_down_sprite = font_down_btn and font_down_btn.sprite,
    font_up_sprite = font_up_btn and font_up_btn.sprite,
    refresh_sprite = refresh_btn and refresh_btn.sprite
  })
  return tabs_flow
end

-- Helper to parse a table row into a compact string, combining simple tables onto one line
local function rowline_parser(key, value, indent, max_line_len)
  local INDENT_STR = "    " -- Increased indent to 4 spaces
  indent = indent or 0
  max_line_len = max_line_len or 80
  local prefix = string.rep(INDENT_STR, indent)
  
  -- Check if this is userdata that we can serialize
  if type(value) == "userdata" then
    local serialized = serialize_chart_tag(value)
    if serialized ~= value then
      -- Successfully serialized, treat as table
      value = serialized
    end
  end
  
  if type(value) ~= "table" then
    local valstr = tostring(value)
    if type(value) ~= "string" and type(value) ~= "number" then valstr = valstr .. " [" .. type(value) .. "]" end
    local line = prefix .. tostring(key) .. " = " .. valstr
    return line, false
  end
  -- If table is empty
  local n = 0; for _ in pairs(value) do n = n + 1 end
  if n == 0 then
    return prefix .. tostring(key) .. " = {}", true
  end

  -- If table is shallow and all scalars, combine onto one line
  local parts = {}
  local all_scalar = true
  -- Process each table entry to build compact representation
  local function process_table_entry(v, k)
    -- Also check for userdata in table entries
    if type(v) == "userdata" then
      local serialized = serialize_chart_tag(v)
      if serialized ~= v then
        v = serialized
      end
    end
    
    if type(v) == "table" or type(v) == "function" then
      all_scalar = false
      -- Stop processing
      return false
    end
    local valstr = tostring(v)
    if type(v) ~= "string" and type(v) ~= "number" then
      valstr = valstr .. " [" .. type(v) .. "]"
    end
    table.insert(parts, tostring(k) .. " = " .. valstr)
    -- Continue processing
    return true
  end

  -- Process entries until we find a non-scalar or finish all
  for k, v in pairs(value) do
    if not process_table_entry(v, k) then break end
  end
  if all_scalar and #parts > 0 then
    local line = prefix .. tostring(key) .. " = { " .. table.concat(parts, ", ") .. " }"
    if #line <= max_line_len then
      return line, true
    end
  end
  -- Otherwise, not compactable
  return prefix .. tostring(key) .. " = {", false
end

-- Serialize LuaCustomChartTag userdata into a readable table format
local function serialize_chart_tag(chart_tag)
  if not chart_tag or type(chart_tag) ~= "userdata" then
    return chart_tag
  end
  
  -- Check if this is a LuaCustomChartTag by checking for known methods
  local success, result = pcall(function()
    if chart_tag.valid then      -- Convert all properties to basic types to avoid nested userdata
      local chart_tag_text = tostring(chart_tag.text or "")
      local serialized = {
        position = chart_tag.position and { x = chart_tag.position.x, y = chart_tag.position.y } or {},
        text = chart_tag_text == "" and "[No Text]" or chart_tag_text,
        icon = chart_tag.icon and {
          name = tostring(chart_tag.icon.name or ""),
          type = tostring(chart_tag.icon.type or "")
        } or {},
        last_user = chart_tag.last_user and chart_tag.last_user.name or "",
        surface_name = chart_tag.surface and tostring(chart_tag.surface.name) or "unknown",
        surface_index = chart_tag.surface and tonumber(chart_tag.surface.index) or 0,
        valid = chart_tag.valid,
        object_name = "LuaCustomChartTag"
      }
      return serialized
    else
      return {
        valid = false,
        object_name = "LuaCustomChartTag (invalid)"
      }
    end
  end)
  
  if success then
    return result
  else
    -- If not a chart tag, return original value
    return chart_tag
  end
end

-- Render the data as a compact, hierarchical, property-only table with alternating row colors, indentation, and line wrapping
local function render_compact_data_rows(parent, data, indent, font_size, row_index, visited, force_white)
  indent = indent or 0
  font_size = font_size or 12
  row_index = row_index or 1
  visited = visited or {}
  local INDENT_STR = "  "
  local MAX_LINE_LEN = 80
  local MAX_DEPTH = 8
  local MAX_KEYS = 1000
  local function is_method(val)
    return type(val) == "function"
  end

  local function add_row(parent, text, font_size, row_index)
    local style = (row_index % 2 == 1) and "data_viewer_row_odd_label" or "data_viewer_row_even_label"
    local lbl = GuiBase.create_label(parent, "data_row_" .. (row_index or 1), text, style)
    set_label_font(lbl, font_size)
    return lbl
  end

  -- Check for excessive depth
  if indent > MAX_DEPTH then
    add_row(parent, string.rep(INDENT_STR, indent) .. "<max depth reached>", font_size, row_index)
    return row_index + 1
  end

  -- Check if this is userdata that we can serialize
  if type(data) == "userdata" then
    local serialized = serialize_chart_tag(data)
    if serialized ~= data then
      data = serialized
    end
  end

  if type(data) ~= "table" then
    local valstr = tostring(data) .. " [" .. type(data) .. "]"
    if #valstr > MAX_LINE_LEN then
      local first = valstr:sub(1, MAX_LINE_LEN)
      local rest = valstr:sub(MAX_LINE_LEN + 1)
      add_row(parent, string.rep(INDENT_STR, indent) .. first, font_size, row_index)
      row_index = row_index + 1
      add_row(parent, string.rep(INDENT_STR, indent + 1) .. rest, font_size, row_index)
      row_index = row_index + 1
    else
      add_row(parent, string.rep(INDENT_STR, indent) .. valstr, font_size, row_index)
      row_index = row_index + 1
    end
    return row_index
  end
  if visited[data] then
    add_row(parent, string.rep(INDENT_STR, indent) .. "<circular reference>", font_size, row_index)
    return row_index + 1
  end
  visited[data] = true
  local key_count = 0
  for k, v in pairs(data) do
    key_count = key_count + 1
    if key_count > MAX_KEYS then
      add_row(parent, string.rep(INDENT_STR, indent) .. "<truncated: too many keys>", font_size, row_index)
      row_index = row_index + 1
      break
    end
    if not is_method(v) then
      if type(v) == "userdata" then
        local serialized = serialize_chart_tag(v)
        if serialized ~= v then
          v = serialized
        end
      end
      local line, compact = rowline_parser(k, v, indent, MAX_LINE_LEN)
      if compact == true then
        add_row(parent, line, font_size, row_index)
        row_index = row_index + 1
      elseif type(v) == "table" then
        add_row(parent, line, font_size, row_index)
        row_index = row_index + 1
        row_index = render_compact_data_rows(parent, v, indent + 1, font_size, row_index, visited)
        add_row(parent, string.rep(INDENT_STR, indent) .. "}", font_size, row_index)
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

function data_viewer.build(player, parent, state)
  if not (state and parent and player) then
    ErrorHandler.debug_log("Data viewer build failed: missing requirements", {
      has_state = state ~= nil,
      has_parent = parent ~= nil,
      has_player = player ~= nil
    })
    return
  end

  local n = 0
  if state.data and type(state.data) == "table" then
    for _ in pairs(state.data) do n = n + 1 end
  end

  ErrorHandler.debug_log("Data viewer build starting", {
    player_name = player.name,
    active_tab = state.active_tab,
    data_type = type(state.data),
    data_count = n,
    font_size = state.font_size,
    top_key = state.top_key
  })

  -- Ensure data and top_key are defined from state
  local data = state and state.data
  local top_key = state and state.top_key

  local font_size = (state and state.font_size) or 10
  -- Main dialog frame (resizable)
  local frame = GuiBase.create_frame(parent, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER, "vertical", "tf_data_viewer_frame")
  frame.caption = ""
  -- Remove debug label at the very top
  -- frame.add{type="label", caption="[TF DEBUG] Data Viewer GUI visible for player: "..(player and player.name or "nil"), style="data_viewer_row_odd_label"}
  -- Titlebar
  build_titlebar(frame)
  -- Inner flow (vertical, invisible_frame)
  -- Tabs row (with tab actions)
  local inner_flow = GuiBase.create_frame(frame, "data_viewer_inner_flow", "vertical", "invisible_frame")
  build_tabs_row(inner_flow, state.active_tab)

  -- Content area: vertical flow, then table
  local content_flow = GuiBase.create_vflow(inner_flow, "data_viewer_content_flow")

  -- Table for data rows (single column for compactness)
  local data_table = GuiBase.create_element("table", content_flow, {
    name = "data_viewer_table",
    column_count = 1,
    style = "tf_data_viewer_table"
  })

  -- REMOVE DEBUG LABEL: Remove debug_data_str label
  -- data_table.add{type="label", caption=debug_data_str, style="data_viewer_row_even_label"}  -- Patch: If data is nil or empty, always show top_key = { } and closing brace, never [NO DATA TO DISPLAY]
  -- Add debug logging to understand why data might appear empty
  ErrorHandler.debug_log("Data viewer data check", {
    data_is_nil = data == nil,
    data_type = type(data),
    data_has_next = data and next(data) ~= nil,
    top_key = top_key
  })
  
  if data == nil or (type(data) == "table" and next(data) == nil) then
    if not top_key then
      top_key = "player_data"
    end

    ErrorHandler.debug_log("Data viewer showing empty data structure", {
      top_key = top_key,
      reason = data == nil and "data_is_nil" or "table_is_empty"
    })

    local style = "data_viewer_row_odd_label"
    local lbl = GuiBase.create_label(data_table, "data_top_key_empty", top_key .. " = {", style)
    set_label_font(lbl, font_size)
    -- Note: font_color and top_margin are not settable on LuaStyle
    local lbl2 = GuiBase.create_label(data_table, "data_closing_brace_empty", "}", "data_viewer_row_even_label")
    set_label_font(lbl2, font_size)
    -- Note: font_color and top_margin are not settable on LuaStyle
    return frame
  end

  -- Defensive: ensure top_key is always set
  if not top_key then top_key = "player_data" end
  -- Show the top-level key and render the data as a tree under it
  local style = "data_viewer_row_odd_label"
  local lbl = GuiBase.create_label(data_table, "data_top_key", top_key .. " = {", style)
  set_label_font(lbl, font_size)
  -- Note: font_color and top_margin are not settable on LuaStyle

  local row_start = 1
  local row_end = 1
  if type(data) == "table" then
    row_end = render_compact_data_rows(data_table, data, 0, font_size, row_start, nil, true)
    if row_end == row_start then
      local no_data_lbl2 = GuiBase.create_label(data_table, "no_data_table", "[NO DATA TO DISPLAY]",
        "data_viewer_row_even_label")
      -- Note: font_color is not settable on LuaStyle
    end
  else
    -- For non-table data, just show the value as a single line
    local val_str = tostring(data) .. " [" .. type(data) .. "]"
    local lbl = GuiBase.create_label(data_table, "data_single_value", "  " .. val_str, "data_viewer_row_even_label")
    set_label_font(lbl, font_size)
  end

  -- Closing brace
  local lbl2 = GuiBase.create_label(data_table, "data_closing_brace", "}", "data_viewer_row_odd_label")
  set_label_font(lbl2, font_size)

  return frame
end

-- Partial update functions for data viewer

--- Update only the content panel without rebuilding tabs and controls
---@param player LuaPlayer
---@param data table Data to display
---@param font_size number Font size to use
---@param top_key string Top-level key name
function data_viewer.update_content_panel(player, data, font_size, top_key)
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local frame = GuiUtils.find_child_by_name(main_flow, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER)
  if not frame then return end

  local content_flow = GuiUtils.find_child_by_name(frame, "data_viewer_content_flow")
  if not content_flow then return end

  -- Remove existing data table
  local existing_table = GuiUtils.find_child_by_name(content_flow, "data_viewer_table")
  if existing_table then
    existing_table.destroy()
  end

  -- Create new data table
  local data_table = GuiBase.create_element("table", content_flow, {
    name = "data_viewer_table",
    column_count = 1,
    style = "tf_data_viewer_table"
  })

  -- Populate with data
  if data == nil or (type(data) == "table" and next(data) == nil) then
    if not top_key then top_key = "player_data" end
    
    local style = "data_viewer_row_odd_label"
    local lbl = GuiBase.create_label(data_table, "data_top_key_empty", top_key .. " = {", style)
    set_label_font(lbl, font_size)
    local lbl2 = GuiBase.create_label(data_table, "data_closing_brace_empty", "}", "data_viewer_row_even_label")
    set_label_font(lbl2, font_size)
  else
    -- Show the top-level key and render the data
    if not top_key then top_key = "player_data" end
    local style = "data_viewer_row_odd_label"
    local lbl = GuiBase.create_label(data_table, "data_top_key", top_key .. " = {", style)
    set_label_font(lbl, font_size)

    local row_start = 1
    local row_end = 1
    if type(data) == "table" then
      row_end = render_compact_data_rows(data_table, data, 0, font_size, row_start, nil, true)
      if row_end == row_start then
        local no_data_lbl2 = GuiBase.create_label(data_table, "no_data_table", "[NO DATA TO DISPLAY]",
          "data_viewer_row_even_label")
      end
    else
      -- For non-table data, just show the value as a single line
      local val_str = tostring(data) .. " [" .. type(data) .. "]"
      local lbl = GuiBase.create_label(data_table, "data_single_value", "  " .. val_str, "data_viewer_row_even_label")
      set_label_font(lbl, font_size)
    end

    -- Closing brace
    local lbl2 = GuiBase.create_label(data_table, "data_closing_brace", "}", "data_viewer_row_odd_label")
    set_label_font(lbl2, font_size)
  end
end

--- Update font size for existing content without full rebuild
---@param player LuaPlayer
---@param new_font_size number New font size to apply
function data_viewer.update_font_size(player, new_font_size)
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local frame = GuiUtils.find_child_by_name(main_flow, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER)
  if not frame then return end

  local data_table = GuiUtils.find_child_by_name(frame, "data_viewer_table")
  if not data_table then return end

  -- Update font size for all existing labels in the data table
  for _, child in pairs(data_table.children) do
    if child.type == "label" then
      set_label_font(child, new_font_size)
    end
  end
end

--- Update tab selection state without rebuilding content
---@param player LuaPlayer
---@param active_tab string Active tab name
function data_viewer.update_tab_selection(player, active_tab)
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local frame = GuiUtils.find_child_by_name(main_flow, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER)
  if not frame then return end

  local tabs_flow = GuiUtils.find_child_by_name(frame, "data_viewer_tabs_flow")
  if not tabs_flow then return end

  -- Tab button name to tab key mapping
  local tab_mapping = {
    ["data_viewer_player_data_tab"] = "player_data",
    ["data_viewer_surface_data_tab"] = "surface_data", 
    ["data_viewer_lookup_tab"] = "lookup",
    ["data_viewer_all_data_tab"] = "all_data"
  }

  -- Update each tab button's enabled state and style
  for button_name, tab_key in pairs(tab_mapping) do
    local tab_button = GuiUtils.find_child_by_name(tabs_flow, button_name)
    if tab_button then
      local is_active = (tab_key == active_tab)
      tab_button.enabled = not is_active
      
      -- Update style based on active state
      if is_active then
        ---@diagnostic disable-next-line: assign-type-mismatch
        tab_button.style = "tf_data_viewer_tab_button_active"
      else
        -- Determine if this is the first button for styling
        if button_name == "data_viewer_player_data_tab" then
          ---@diagnostic disable-next-line: assign-type-mismatch
          tab_button.style = "tf_data_viewer_tab_button"
        else
          ---@diagnostic disable-next-line: assign-type-mismatch
          tab_button.style = "tf_data_viewer_tab_button_margin"
        end
      end
    end
  end
end

--- Show notification when data is refreshed
---@param player LuaPlayer
function data_viewer.show_refresh_notification(player)
  if player and player.valid then
    GameHelpers.player_print(player, { "tf-gui.data_refreshed" })
  end
end

return data_viewer
