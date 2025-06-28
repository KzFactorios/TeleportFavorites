---@diagnostic disable: undefined-global
--[[
gui/data_viewer/data_parsing_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Helper functions for data parsing and formatting in the data viewer, extracted from data_viewer.lua.

This module contains specialized functions for:
- Table serialization and parsing
- Chart tag userdata conversion
- Row line formatting and display
- Compact representation logic

These functions were extracted from large data viewer functions to improve
maintainability and testability.
]]

---@class DataParsingHelpers
local DataParsingHelpers = {}

--- Serialize LuaCustomChartTag userdata into a readable table format
---@param chart_tag any Potential chart tag userdata
---@return any Serialized representation or original value
function DataParsingHelpers.serialize_chart_tag(chart_tag)
  if not chart_tag or type(chart_tag) ~= "userdata" then
    return chart_tag
  end
  
  -- Check if this is a LuaCustomChartTag by checking for known methods
  local success, result = pcall(function()
    if chart_tag.valid then
      -- Convert all properties to basic types to avoid nested userdata
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
        valid = true
      }
      return serialized
    else
      return { valid = false, type = "LuaCustomChartTag" }
    end
  end)
  
  if success then
    return result
  else
    return chart_tag
  end
end

--- Process a single table entry for compact representation
---@param value any Value to process
---@param key any Key for the value
---@param parts table Parts list to append to
---@return boolean continue_processing Whether to continue processing more entries
function DataParsingHelpers.process_table_entry(value, key, parts)
  -- Check for userdata in table entries
  if type(value) == "userdata" then
    local serialized = DataParsingHelpers.serialize_chart_tag(value)
    if serialized ~= value then
      value = serialized
    end
  end
  
  if type(value) == "table" or type(value) == "function" then
    return false -- Stop processing, not all scalar
  end
  
  local valstr = tostring(value)
  if type(value) ~= "string" and type(value) ~= "number" then
    valstr = valstr .. " [" .. type(value) .. "]"
  end
  table.insert(parts, tostring(key) .. " = " .. valstr)
  
  return true -- Continue processing
end

--- Parse a key-value pair into a formatted row line for display
---@param key any Key to display
---@param value any Value to display
---@param indent number? Indentation level (default: 0)
---@param max_line_len number? Maximum line length for compact format (default: 80)
---@return string line Formatted line for display
---@return boolean compact Whether the line was compacted
function DataParsingHelpers.parse_row_line(key, value, indent, max_line_len)
  local INDENT_STR = "    " -- 4 spaces for indentation
  indent = indent or 0
  max_line_len = max_line_len or 80
  local prefix = string.rep(INDENT_STR, math.floor(indent))
  
  -- Check if this is userdata that we can serialize
  if type(value) == "userdata" then
    local serialized = DataParsingHelpers.serialize_chart_tag(value)
    if serialized ~= value then
      value = serialized -- Successfully serialized, treat as table
    end
  end
  
  -- Handle non-table values
  if type(value) ~= "table" then
    local valstr = tostring(value)
    if type(value) ~= "string" and type(value) ~= "number" then 
      valstr = valstr .. " [" .. type(value) .. "]" 
    end
    local line = prefix .. tostring(key) .. " = " .. valstr
    return line, false
  end
  
  -- Handle empty tables
  local entry_count = 0
  for _ in pairs(value) do entry_count = entry_count + 1 end
  if entry_count == 0 then
    return prefix .. tostring(key) .. " = {}", true
  end

  -- Try to create compact representation for tables with all scalar values
  local parts = {}
  local all_scalar = true
  
  -- Process each table entry to build compact representation
  for k, v in pairs(value) do
    if not DataParsingHelpers.process_table_entry(v, k, parts) then
      all_scalar = false
      break
    end
  end
  
  -- Return compact format if possible and within length limit
  if all_scalar and #parts > 0 then
    local line = prefix .. tostring(key) .. " = { " .. table.concat(parts, ", ") .. " }"
    if #line <= max_line_len then
      return line, true
    end
  end
  
  -- Return non-compact format for complex tables
  return prefix .. tostring(key) .. " = {", false
end

--- Check if a value represents displayable chart tag data
---@param value any Value to check
---@return boolean is_chart_tag Whether value appears to be chart tag data
function DataParsingHelpers.is_chart_tag_data(value)
  if type(value) ~= "table" then return false end
  
  -- Check for chart tag-like properties
  return value.position ~= nil or 
         value.text ~= nil or 
         value.icon ~= nil or 
         value.last_user ~= nil or
         value.surface_name ~= nil
end

return DataParsingHelpers
