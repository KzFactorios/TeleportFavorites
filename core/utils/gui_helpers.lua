--[[
Consolidated GUI Utilities for TeleportFavorites
===============================================
Module: core/utils/gui_helpers.lua

Consolidated GUI utilities for accessibility, formatting, and styling.
Combines functionality from gui_accessibility.lua, gui_formatting.lua, 
and gui_styling.lua to reduce file fragmentation.

Functions:
- get_or_create_gui_flow_from_gui_top() - Get or create main GUI flow
- build_favorite_tooltip() - Build tooltip for favorites  
- create_slot_button() - Create styled slot button with icon and tooltip
]]

local GuiValidation = require("core.utils.gui_validation")
local GuiBase = require("gui.gui_base")
local GPSUtils = require("core.utils.gps_utils")
local BasicHelpers = require("core.utils.basic_helpers")

local GuiHelpers = {}

-- ===========================
-- ACCESSIBILITY FUNCTIONS
-- ===========================

function GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local top = player.gui.top
  local flow = top and top.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = top.add {
      type = "flow",
      name = "tf_main_gui_flow",
      direction = "vertical", 
      style = "vertical_flow"
    }
  end
  return flow
end

-- ===========================
-- FORMATTING FUNCTIONS
-- ===========================

function GuiHelpers.build_favorite_tooltip(fav, opts)
  opts = opts or {}
  local gps_str = fav and fav.gps or opts.gps or "?"
  local tag_text = fav and fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.text or opts.text or nil
  
  -- Truncate long tag text
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end

  if not tag_text or tag_text == "" then
    return { "tf-gui.fave_slot_tooltip_one", GPSUtils.coords_string_from_gps(gps_str) }
  else
    return { "tf-gui.fave_slot_tooltip_both", tag_text or "", gps_str }
  end
end

function GuiHelpers.format_gps_display(gps)
  if not BasicHelpers.is_valid_gps(gps) then return "N/A" end
  return GPSUtils.coords_string_from_gps(gps)
end

-- ===========================
-- STYLING FUNCTIONS
-- ===========================

function GuiHelpers.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local style = opts.style or "tf_fave_slot_button"
  local sprite = icon or ""
  local button = GuiBase.create_sprite_button(parent, name, sprite, tooltip, style)
  
  -- Apply any style overrides
  if opts.style_overrides then
    GuiValidation.apply_style_properties(button, opts.style_overrides)
  end
  
  return button
end

function GuiHelpers.create_label_with_style(parent, name, caption, style_name)
  if not parent or not name then return nil end
  
  return parent.add({
    type = "label",
    name = name,
    caption = caption or "",
    style = style_name or "label"
  })
end

return GuiHelpers
