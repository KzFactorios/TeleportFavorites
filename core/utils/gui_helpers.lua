---@diagnostic disable: undefined-global

-- core/utils/gui_helpers.lua
-- TeleportFavorites Factorio Mod
-- Consolidated GUI utilities for accessibility, formatting, and styling.
-- Combines gui_accessibility, gui_formatting, and gui_styling for maintainability.

local Deps = require("core.deps_barrel")
local BasicHelpers, GPSUtils = Deps.BasicHelpers, Deps.GpsUtils
local GuiValidation = require("core.utils.gui_validation")
local GuiBase = require("gui.gui_base")

local GuiHelpers = {}

--- Count direct children of a GUI element. Do not use `#parent.children` or
--- `table_size(parent.children)` on `LuaGuiElement.children` — it is a LuaCustomTable;
--- use numeric indexing (same pattern as `slots_frame.children[i]` in progressive hydrate).
---@param parent LuaGuiElement|nil
---@return integer
function GuiHelpers.count_direct_children(parent)
  if not parent or not parent.valid then return 0 end
  local ch = parent.children
  if not ch then return 0 end
  local n = 0
  for i = 1, 512 do
    local el = ch[i]
    if el == nil then break end
    if type(el) == "userdata" and el.valid then
      n = n + 1
    else
      break
    end
  end
  return n
end

--- True when the favorites slots row has exactly `max_slots` children and each slot index
--- has the expected named elements with the slot number label caption matching the index.
---@param slots_frame LuaGuiElement|nil
---@param max_slots integer
---@param use_labels boolean
---@return boolean
function GuiHelpers.slot_row_matches_expected(slots_frame, max_slots, use_labels)
  if not slots_frame or not slots_frame.valid then return false end
  if type(max_slots) ~= "number" or max_slots < 1 then return false end
  if GuiHelpers.count_direct_children(slots_frame) ~= max_slots then return false end
  for i = 1, max_slots do
    local btn
    if use_labels then
      local wrapper = slots_frame["fave_bar_slot_wrapper_" .. i]
      if not wrapper or not wrapper.valid or wrapper.type ~= "flow" then return false end
      btn = wrapper["fave_bar_slot_" .. i]
    else
      btn = slots_frame["fave_bar_slot_" .. i]
    end
    if not btn or not btn.valid then return false end
    local n_el = btn["n"]
    if not n_el or not n_el.valid then return false end
    if tostring(n_el.caption) ~= tostring(i) then return false end
  end
  return true
end

--- Destroy every direct child by repeatedly removing `children[1]` (LuaCustomTable-safe).
---@param el LuaGuiElement|nil
function GuiHelpers.peel_destroy_all_children(el)
  if not el or not el.valid then return end
  local ch = el.children
  if not ch then return end
  for _ = 1, 512 do
    local c = ch[1]
    if c == nil or not c.valid then break end
    c.destroy()
  end
end

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
