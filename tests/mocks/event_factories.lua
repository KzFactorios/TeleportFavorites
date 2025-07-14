-- tests/mocks/event_factories.lua
-- Centralized event creation factory to reduce test code duplication

local EventFactories = {}

--- Create a standard chart tag event with common structure
---@param player_index number Player index for the event
---@param position table Position table {x, y}
---@param surface table Surface object
---@param additional_fields table? Additional fields to merge
---@return table event Chart tag event structure
function EventFactories.create_chart_tag_event(player_index, position, surface, additional_fields)
  local event = {
    player_index = player_index or 1,
    tag = {
      valid = true,
      position = position or { x = 100, y = 200 },
      surface = surface or { index = 1, name = "nauvis", valid = true }
    }
  }
  
  if additional_fields then
    for k, v in pairs(additional_fields) do
      event[k] = v
    end
  end
  
  return event
end

--- Create a chart tag modification event
---@param player_index number Player index for the event
---@param position table New position {x, y}
---@param old_position table Old position {x, y}
---@param surface table Surface object
---@param additional_fields table? Additional fields to merge
---@return table event Chart tag modification event
function EventFactories.create_chart_tag_modification_event(player_index, position, old_position, surface, additional_fields)
  local event = EventFactories.create_chart_tag_event(player_index, position, surface, additional_fields)
  event.old_position = old_position or { x = 90, y = 180 }
  return event
end

--- Create fractional position for normalization testing
---@param x_frac number? X coordinate with fractional part (default 100.5)
---@param y_frac number? Y coordinate with fractional part (default 200.5)
---@return table position Fractional position
function EventFactories.create_fractional_position(x_frac, y_frac)
  return { x = x_frac or 100.5, y = y_frac or 200.5 }
end

--- Create integer position for non-normalization testing
---@param x_int number? X coordinate as integer (default 100)
---@param y_int number? Y coordinate as integer (default 200)
---@return table position Integer position
function EventFactories.create_integer_position(x_int, y_int)
  return { x = x_int or 100, y = y_int or 200 }
end

--- Create invalid event with missing required fields
---@param missing_field string Field to omit ('tag', 'old_position', 'position')
---@param player_index number? Player index (default 1)
---@return table event Invalid event structure
function EventFactories.create_invalid_event(missing_field, player_index)
  local event = { player_index = player_index or 1 }
  
  if missing_field ~= "tag" then
    event.tag = { valid = true, position = { x = 100, y = 200 } }
  end
  
  if missing_field ~= "old_position" and missing_field ~= "tag" then
    event.old_position = { x = 90, y = 180 }
  end
  
  if missing_field == "position" and event.tag then
    event.tag.position = nil
  end
  
  if missing_field == "invalid_tag" and event.tag then
    event.tag.valid = false
  end
  
  return event
end

--- Create player event structure
---@param player_index number Player index
---@param event_type string Type of player event
---@param additional_fields table? Additional event fields
---@return table event Player event structure
function EventFactories.create_player_event(player_index, event_type, additional_fields)
  local event = {
    player_index = player_index or 1,
    type = event_type
  }
  
  if additional_fields then
    for k, v in pairs(additional_fields) do
      event[k] = v
    end
  end
  
  return event
end

--- Create surface change event
---@param player_index number Player index
---@param surface_index number New surface index
---@return table event Surface change event
function EventFactories.create_surface_change_event(player_index, surface_index)
  return EventFactories.create_player_event(player_index, "surface_change", {
    surface_index = surface_index or 2
  })
end

return EventFactories
