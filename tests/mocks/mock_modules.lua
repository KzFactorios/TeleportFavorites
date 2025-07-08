-- Mock implementations for various modules used in testing

local MockModules = {}

-- Mock ChartTagSpecBuilder
MockModules.ChartTagSpecBuilder = {
  build = function(position, chart_tag, player, text, preserve_owner)
    return {
      position = position,
      text = text or "Test Tag",
      player = player
    }
  end
}

-- Mock ChartTagUtils
MockModules.ChartTagUtils = {
  find_closest_chart_tag_to_position = function(force, surface, position, radius)
    return nil -- Default to no chart tag found
  end,
  
  safe_add_chart_tag = function(force, surface, spec, player)
    return {
      valid = true,
      position = spec.position,
      text = spec.text or "Test Tag",
      last_user = player,
      surface = surface,
      destroy = function() end
    }
  end
}

-- Mock GPSUtils
MockModules.GPSUtils = {
  gps_from_map_position = function(position, surface_index)
    local surface_name = "nauvis"
    if type(surface_index) == "table" and surface_index.name then
      surface_name = surface_index.name
    elseif type(surface_index) == "number" and _G.game and _G.game.surfaces and _G.game.surfaces[surface_index] then
      surface_name = _G.game.surfaces[surface_index].name
    end
    
    return string.format("gps:%d,%d,%s", position.x, position.y, surface_name)
  end,
  
  coords_string_from_gps = function(gps)
    return "100, 100" -- Default for testing
  end,
  
  map_position_from_gps = function(gps)
    return {x = 100, y = 100} -- Default position for testing
  end
}

-- Mock PositionUtils
MockModules.PositionUtils = {
  normalize_if_needed = function(position)
    return position -- Default returns unchanged position
  end,
  
  create_position_pair = function(position)
    return {
      old = position,
      new = {x = math.floor(position.x), y = math.floor(position.y)}
    }
  end,
  
  needs_normalization = function(position)
    return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
  end
}

-- Mock Settings
MockModules.Settings = {
  get_chart_tag_click_radius = function()
    return 5 -- Default value for testing
  end
}

-- Mock tag_destroy_helper
MockModules.tag_destroy_helper = {
  destroy_tag_and_chart_tag = function(tag, chart_tag)
    -- No-op for tests
  end
}

-- Mock basic_helpers
MockModules.basic_helpers = {
  is_whole_number = function(num)
    return num == math.floor(num)
  end
}

-- Mock Enum
MockModules.Enum = {
  GuiEnum = {
    GUI_FRAME = {
      TAG_EDITOR = "tf_tag_editor_frame"
    }
  }
}

return MockModules
