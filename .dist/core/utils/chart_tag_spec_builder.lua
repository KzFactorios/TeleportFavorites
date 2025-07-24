---@diagnostic disable: undefined-global

local ChartTagSpecBuilder = {}

---@param text string? Custom text override
---@param set_ownership boolean? Whether to set last_user (only for final tags, not temporary)
---@return table chart_tag_spec Chart tag specification ready for Factorio API
function ChartTagSpecBuilder.build(position, source_chart_tag, player, text, set_ownership)
  local spec = { position = position }

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

  if set_ownership then
    local last_user_name = nil
    if source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
      local ok, last_user = pcall(function() return source_chart_tag.last_user end)
      if ok and last_user then
        if type(last_user) == "table" then
          local ok2, name = pcall(function() return last_user.name end)
          if ok2 and name and type(name) == "string" and name ~= "" then
            last_user_name = name
          end
        elseif type(last_user) == "string" and last_user ~= "" then
          last_user_name = last_user
        end
      end
    end
    if last_user_name ~= nil then
      spec.last_user = last_user_name
    elseif player and player.valid and player.name then
      spec.last_user = player.name
    else
      spec.last_user = "System"
    end
  end

  if source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
    local ok, icon = pcall(function() return source_chart_tag.icon end)
    if ok and icon and type(icon) == "table" and icon.name and not getmetatable(icon) then
      spec.icon = icon
    end
  end

  return spec
end

return ChartTagSpecBuilder
