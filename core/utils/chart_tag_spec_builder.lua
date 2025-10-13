---@diagnostic disable: undefined-global

-- core/utils/chart_tag_spec_builder.lua
-- TeleportFavorites Factorio Mod
-- Chart tag specification builder for Factorio API.
-- Safely constructs chart tag spec tables for creation, update, and migration.
-- Handles text and icon fields with robust validation and fallback logic.
-- NOTE: Ownership is tracked via Tag.owner_name, not chart_tag.last_user
--
-- API:
--   ChartTagSpecBuilder.build(position, source_chart_tag, player, text):
--     Returns a chart tag spec table for use with force.add_chart_tag or tag mutation.

local ChartTagSpecBuilder = {}

---@param text string? Custom text override
---@return table chart_tag_spec Chart tag specification ready for Factorio API
function ChartTagSpecBuilder.build(position, source_chart_tag, player, text)
  local spec = { position = position }

  -- Text
  if text then
    spec.text = text
  elseif source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
    local ok, value = pcall(function() return source_chart_tag.text end)
    if ok and type(value) == "string" then
      spec.text = value
    else
      spec.text = ""
    end
  else
    spec.text = ""
  end

  -- icon
  if source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
    local ok, icon = pcall(function() return source_chart_tag.icon end)
    if ok and icon and type(icon) == "table" and icon.name and not getmetatable(icon) then
      spec.icon = icon
    end
  end

  return spec
end

return ChartTagSpecBuilder
