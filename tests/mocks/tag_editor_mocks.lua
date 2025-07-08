-- Consolidated mocks for tag editor event helpers

-- NOTE: For any LuaPlayer mock, use PlayerFavoritesMocks.mock_player from player_favorites_mocks.lua
-- (require as needed in your test setup)
--
-- Create a mock module container
local TagEditorMocks = {}

-- Mock Cache module
TagEditorMocks.Cache = {
  get_player_data = function(player)
    return {
      tag_editor_data = {
        gps = "[gps=100,100,1]",
        position = {x = 100, y = 100},
        text = "Test Tag",
        icon = {type = "item", name = "iron-plate"},
        is_favorite = false,
        surface = 1,
        chart_tag = nil
      },
      drag_favorite = {
        active = false
      }
    }
  end,
  create_tag_editor_data = function()
    return {
      gps = "[gps=100,100,1]",
      position = {x = 100, y = 100},
      text = "New Test Tag",
      icon = nil,
      is_favorite = false,
      surface = 1,
      chart_tag = nil
    }
  end,
  get_player_settings = function() 
    return { tag_editor_auto_close = true }
  end,
  Lookups = {
    get_chart_tag_cache = function(surface_index) 
      return {}
    end,
    invalidate_surface_chart_tags = function(surface_index) end,
    get_surface_chart_tags = function(force, surface_index) 
      return {
        ["tag-1"] = {
          position = {x = 100, y = 100},
          surface_index = 1,
          text = "Tag 1"
        },
        ["tag-2"] = {
          position = {x = 200, y = 200},
          surface_index = 1,
          text = "Tag 2"
        }
      }
    end
  }
}

-- Mock ChartTagSpecBuilder
TagEditorMocks.ChartTagSpecBuilder = {
  build = function(position, chart_tag, player, text, preserve_owner)
    return {
      position = position or {x = 100, y = 100},
      text = text or "Test Tag",
      player = player,
      icon = {type = "item", name = "iron-plate"}
    }
  end
}

-- Mock Settings
TagEditorMocks.Settings = {
  get_player_mod_setting = function(player, setting_name)
    if setting_name == "tf-tag-editor-auto-close" then
      return true
    end
    return false
  end
}

-- Mock tag_destroy_helper
TagEditorMocks.tag_destroy_helper = {
  destroy_tag_and_chart_tag = function(tag, chart_tag)
    -- Just pretend we destroyed it
    return true
  end
}

-- Mock Enum
TagEditorMocks.Enum = {
  GuiEnum = {
    GUI_FRAME = {
      TAG_EDITOR = "tag_editor_frame"
    }
  }
}

-- Mock basic_helpers
TagEditorMocks.basic_helpers = {
  is_whole_number = function(value)
    if not value then return false end
    return value % 1 == 0
  end,
  trim = function(s)
    return s:match("^%s*(.-)%s*$")
  end
}

-- Mock ChartTagUtils
TagEditorMocks.ChartTagUtils = {
  find_closest_chart_tag_to_position = function(force, surface, position, radius)
    -- Default implementation returns nil
    -- Test cases can override this as needed
    return nil
  end,
  replace_chart_tag = function(chart_tag, spec, player)
    -- Return a mock replaced chart tag
    return {
      position = spec.position,
      text = spec.text,
      icon = spec.icon,
      last_user = player,
      surface = {
        index = 1,
        name = "nauvis",
        valid = true
      },
      valid = true,
      destroy = function() end
    }
  end,
  create_chart_tag = function(force, surface, position, text, icon, player)
    -- Return a mock chart tag
    return {
      position = position,
      text = text,
      icon = icon,
      last_user = player,
      surface = surface,
      valid = true,
      destroy = function() end
    }
  end,
  safe_add_chart_tag = function(force, surface, spec, player)
    -- Return a mock chart tag
    return {
      position = spec.position,
      text = spec.text,
      icon = spec.icon,
      last_user = player,
      surface = surface,
      force = force,
      valid = true,
      destroy = function() end
    }
  end
}

-- Mock GPSUtils
TagEditorMocks.GPSUtils = {
  is_valid_gps_string = function(gps_string)
    -- Simple validation - check if it looks like a GPS string
    return gps_string and gps_string:match("%[gps=%-?%d+%.?%d*,%-?%d+%.?%d*,?%d*%]") ~= nil
  end,
  parse_gps_string = function(gps_string)
    -- Simple mock parser for GPS strings
    local x, y, surface_index = gps_string:match("%[gps=(%-?%d+%.?%d*),(%-?%d+%.?%d*),?(%d*)%]")
    if x and y then
      return {
        position = {x = tonumber(x), y = tonumber(y)},
        surface_index = tonumber(surface_index) or 1
      }
    end
    return nil
  end,
  create_gps_string = function(position, surface_index)
    -- Create a mock GPS string
    return "[gps=" .. position.x .. "," .. position.y .. "," .. (surface_index or 1) .. "]"
  end,
  coords_string_from_gps = function(gps_string)
    -- Extract coordinates from GPS string
    if not gps_string then return "" end
    local x, y = gps_string:match("%[gps=(%-?%d+%.?%d*),(%-?%d+%.?%d*)")
    if x and y then
      return x .. ", " .. y
    end
    return ""
  end,
  gps_from_map_position = function(position, surface_index)
    -- Create a mock GPS string
    return "[gps=" .. position.x .. "," .. position.y .. "," .. (surface_index or 1) .. "]"
  end
}

-- Mock PositionUtils
TagEditorMocks.PositionUtils = {
  equals = function(pos1, pos2)
    if not pos1 or not pos2 then return false end
    return pos1.x == pos2.x and pos1.y == pos2.y
  end,
  calculate_distance = function(pos1, pos2)
    if not pos1 or not pos2 then return 999 end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
  end,
  normalize = function(position)
    if not position then return {x = 0, y = 0} end
    return {
      x = math.floor(position.x),
      y = math.floor(position.y)
    }
  end,
  create_position_pair = function(position)
    if not position then return nil end
    return {
      old = {x = position.x, y = position.y},
      new = {
        x = math.floor(position.x),
        y = math.floor(position.y)
      }
    }
  end,
  normalize_if_needed = function(position)
    if not position then return {x = 0, y = 0} end
    if math.floor(position.x) ~= position.x or math.floor(position.y) ~= position.y then
      return {
        x = math.floor(position.x),
        y = math.floor(position.y)
      }
    end
    return position
  end
}

-- Mock ErrorHandler
TagEditorMocks.ErrorHandler = {
  capture = function(err, context)
    -- Just return the error for testing purposes
    return err
  end
}

-- Mock ValidationUtils
TagEditorMocks.ValidationUtils = {
  has_valid_icon = function(icon)
    return icon ~= nil
  end
}

-- Mock GameHelpers
TagEditorMocks.GameHelpers = {
  player_print = function(player, message) 
    -- No-op for tests
  end,
  get_player_by_index = function(index)
    if _G.game and _G.game.players and _G.game.players[index] then
      return _G.game.players[index]
    end
    return nil
  end
}

-- NOTE: The following functions are intentionally NOT defined here:
--   TagEditorMocks.find_nearby_chart_tag
--   TagEditorMocks.validate_tag_editor_opening
-- These should be patched or defined in individual tests as needed to avoid duplicate field errors.

return TagEditorMocks
