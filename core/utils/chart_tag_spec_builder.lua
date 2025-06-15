---@diagnostic disable
--[[
core/utils/chart_tag_spec_builder.lua
TeleportFavorites Factorio Mod
-----------------------------
Simple chart tag specification builder.
]]

---@class ChartTagSpecBuilder
local ChartTagSpecBuilder = {}

--- Build a chart tag specification
---@param position MapPosition
---@param source_chart_tag LuaCustomChartTag?
---@param player LuaPlayer?
---@param text string?
---@return table chart_tag_spec
function ChartTagSpecBuilder.build(position, source_chart_tag, player, text)
  local spec = {
    position = position,
    text = text or (source_chart_tag and source_chart_tag.text) or "Tag",
    last_user = (source_chart_tag and source_chart_tag.last_user) or 
                (player and player.valid and player.name) or 
                "System"
  }

  -- Add icon if valid
  local icon = source_chart_tag and source_chart_tag.icon
  if icon and type(icon) == "table" and icon.name then
    spec.icon = icon
  end

  return spec
end

return ChartTagSpecBuilder
