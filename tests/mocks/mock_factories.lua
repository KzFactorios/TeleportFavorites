-- tests/mocks/mock_factories.lua
-- Centralized mock object factories to reduce duplication across test files

local mock_luaPlayer = require("mocks.mock_luaPlayer")

---@class MockFactories
local MockFactories = {}

--- Create a standard mock player with common defaults
---@param opts table? Options: index, name, surface_index, valid, admin, etc.
---@return table mock_player
function MockFactories.create_player(opts)
  opts = opts or {}
  return mock_luaPlayer(
    opts.index or 1,
    opts.name or ("Player" .. tostring(opts.index or 1)),
    opts.surface_index or 1
  )
end

--- Create a mock GUI element with common properties
---@param opts table? Options: name, valid, type, children, etc.
---@return table mock_element
function MockFactories.create_element(opts)
  opts = opts or {}
  return {
    valid = opts.valid ~= false, -- Default to true unless explicitly false
    name = opts.name or "test_element",
    type = opts.type or "button",
    children = opts.children or {},
    style = opts.style or {},
    parent = opts.parent,
    caption = opts.caption or "",
    enabled = opts.enabled ~= false, -- Default to true unless explicitly false
  }
end

--- Create a mock surface
---@param opts table? Options: index, name, valid
---@return table mock_surface
function MockFactories.create_surface(opts)
  opts = opts or {}
  return {
    index = opts.index or 1,
    name = opts.name or "nauvis",
    valid = opts.valid ~= false,
    get_tile = opts.get_tile or function() return { name = "grass-1", valid = true } end
  }
end

--- Create a mock chart tag
---@param opts table? Options: position, text, valid, surface
---@return table mock_chart_tag
function MockFactories.create_chart_tag(opts)
  opts = opts or {}
  return {
    valid = opts.valid ~= false,
    position = opts.position or { x = 100, y = 100 },
    text = opts.text or "Test Tag",
    surface = opts.surface or MockFactories.create_surface(),
    icon = opts.icon or "signal-1",
    destroy = opts.destroy or function() end
  }
end

return MockFactories
