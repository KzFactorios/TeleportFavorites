---@diagnostic disable: undefined-global

-- core/events/tag_editor_event_helpers.lua
-- TeleportFavorites Factorio Mod
-- Helper functions for tag editor event handling, extracted from handlers.lua.
-- Specialized functions: tag data creation/lookup, chart tag normalization/replacement, position/GPS validation, tag editor opening validation.

local Cache = require("core.cache.cache")
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local GPSUtils = require("core.utils.gps_utils")
local PositionUtils = require("core.utils.position_utils")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")

---@class TagEditorEventHelpers
local TagEditorEventHelpers = {}

--- Validate if tag editor can be opened for the given player and context
---@param player LuaPlayer Player attempting to open tag editor
---@return boolean can_open Whether tag editor can be opened
---@return string? reason Reason if cannot open (for debugging)
function TagEditorEventHelpers.validate_tag_editor_opening(player)
  if not BasicHelpers.is_valid_player(player) then
    return false, "Invalid player"
  end

  if player.render_mode ~= defines.render_mode.chart then
    return false, "Wrong render mode"
  end

  -- UNIVERSAL GUI CONFLICT DETECTION: Check if ANY GUI is open (from any mod)
  -- player.opened is set by Factorio when a GUI/modal/entity is opened
  if player.opened ~= nil then
    -- Determine what type of GUI is open for better error messaging
    local opened_type = "unknown"
    if type(player.opened) == "table" then
      if player.opened.object_name == "LuaGuiElement" then
        opened_type = "GUI: " .. (player.opened.name or "unnamed")
      elseif player.opened.object_name then
        opened_type = player.opened.object_name
      end
    end
    return false, "Another GUI is open: " .. opened_type
  end

  -- Prevent tag editor from opening if any modal dialog is active (our mod's modals)
  if Cache.is_modal_dialog_active and Cache.is_modal_dialog_active(player) then
    local modal_type = Cache.get_modal_dialog_type and Cache.get_modal_dialog_type(player)
    return false, "Modal dialog active: " .. (modal_type or "unknown")
  end

  -- Prevent tag editor from opening if player is in drag mode
  local player_data = Cache.get_player_data(player)
  if player_data and player_data.drag_favorite and player_data.drag_favorite.active then
    return false, "Drag mode active"
  end

  local tag_editor_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if tag_editor_frame and tag_editor_frame.valid then
    return false, "Tag editor already open"
  end

  return true, nil
end

--- Find nearby chart tag within click radius
---@param normalized_pos table Normalized position to search around
---@param surface_index number Surface to search on  
---@param click_radius number Search radius
---@return LuaCustomChartTag? Found chart tag within radius
function TagEditorEventHelpers.find_nearby_chart_tag(normalized_pos, surface_index, click_radius)
  local force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
  local min_distance = click_radius
  local closest_chart_tag = nil

  for _, tag in pairs(force_tags) do
    if tag and tag.valid then
      local tag_pos = PositionUtils.normalize_position(tag.position)

      local dx = math.abs(tag_pos.x - normalized_pos.x)
      local dy = math.abs(tag_pos.y - normalized_pos.y)
      
      if dx <= click_radius and dy <= click_radius then
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < min_distance then
          min_distance = distance
          closest_chart_tag = tag
        end
      end
    end
  end

  return closest_chart_tag
end

--- Create temporary chart tag for position if no existing tag found
---@param normalized_pos table Position for temporary tag
---@param player LuaPlayer Player creating the tag
---@param surface_index number Surface index
---@return string gps GPS string for the position
function TagEditorEventHelpers.create_temp_tag_gps(normalized_pos, player, surface_index)
  local temp_spec = ChartTagSpecBuilder.build(normalized_pos, nil, player, nil)
  local tmp_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, player.surface, temp_spec, player)
  
  if tmp_chart_tag and tmp_chart_tag.valid then
    local tag_gps = GPSUtils.gps_from_map_position(tmp_chart_tag.position, surface_index)
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, tmp_chart_tag)
    return tag_gps
  end
  
  return GPSUtils.gps_from_map_position(normalized_pos, surface_index)
end

--- Normalize chart tag coordinates and replace if needed
---@param chart_tag LuaCustomChartTag Chart tag to normalize
---@param player LuaPlayer? Player performing the operation (nullable for type safety)
---@return LuaCustomChartTag? new_chart_tag New chart tag if replacement occurred
---@return table? position_pair Old and new position pair if replacement occurred
function TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
  if not BasicHelpers.is_valid_player(player) then return nil, nil end
  
  local position = chart_tag.position
  if not position then return nil, nil end
  
  if not BasicHelpers.is_whole_number(position.x) or not BasicHelpers.is_whole_number(position.y) then
    local position_pair = PositionUtils.create_position_pair(position)
    local chart_tag_spec = ChartTagSpecBuilder.build(
      position_pair.new,
      chart_tag,
      player,
      nil
    )
    
    local surface_index = chart_tag.surface and chart_tag.surface.index or 1
    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(
      player and player.force or chart_tag.force,
      chart_tag.surface,
      chart_tag_spec,
      player
    )
    
    if new_chart_tag and new_chart_tag.valid then
      chart_tag.destroy()
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      return new_chart_tag, position_pair
    end
  end
  
  return nil, nil
end

return TagEditorEventHelpers
