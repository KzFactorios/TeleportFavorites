-- tests/chart_tag_ownership_manager_spec.lua
-- Test coverage for core/control/chart_tag_ownership_manager.lua

local mock_cache = require("mocks.mock_cache")
local mock_error_handler = require("mocks.mock_error_handler")
local mock_collection_utils = require("mocks.mock_collection_utils")

local old_require = require
local function fake_require(name)
  if name == "core.cache.cache" then return mock_cache end
  if name == "core.utils.error_handler" then return mock_error_handler end
  if name == "core.utils.collection_utils" then return mock_collection_utils end
  return old_require(name)
end
_G.require = fake_require


-- Mock defines global for disconnect reasons
_G.defines = {
  disconnect_reason = {
    switching_servers = "switching_servers",
    kicked_and_deleted = "kicked_and_deleted",
    banned = "banned"
  }
}

local ChartTagOwnershipManager = old_require("core.control.chart_tag_ownership_manager")

-- Helper functions must be defined before use
local function make_surface(index, tags)
  return {
    index = index,
    valid = true,
    name = "surface" .. tostring(index),
    tags = tags or {},
  }
end

local function make_chart_tag(owner_name, valid)
  return {
    valid = valid ~= false,
    last_user = { name = owner_name },
    position = { x = 1, y = 2 },
    text = "tagtext"
  }
end

describe("ChartTagOwnershipManager", function()
  before_each(function()
    mock_error_handler.clear()
    mock_cache.clear()
  end)

  it("reset_ownership_for_player resets ownership and invalidates cache", function()
    local tag1 = make_chart_tag("Alice", true)
    local tag2 = make_chart_tag("Bob", true)
    local tag3 = make_chart_tag("Alice", true)
    local surface1 = make_surface(1, { tag1, tag2 })
    local surface2 = make_surface(2, { tag3 })
    _G.game = {
      surfaces = {
        [1] = surface1,
        [2] = surface2
      }
    }
    mock_cache.Lookups.get_chart_tag_cache = function(surface_index)
      if surface_index == 1 then return surface1.tags end
      if surface_index == 2 then return surface2.tags end
      return {}
    end
    local count = ChartTagOwnershipManager.reset_ownership_for_player("Alice")
    assert(count == 2, "Should reset 2 tags owned by Alice")
    assert(tag1.last_user == nil, "Tag1 owner reset")
    assert(tag3.last_user == nil, "Tag3 owner reset")
  end)

  it("reset_ownership_for_player returns 0 for invalid player and logs warning", function()
    mock_error_handler.clear()
    local count = ChartTagOwnershipManager.reset_ownership_for_player("")
    assert(count == 0)
    local calls = mock_error_handler.get_calls()
    assert(calls[#calls].type == "warn", "Should log warn for empty string")
  end)

  it("on_player_left_game resets ownership for switching_servers and covers reset_count > 0 branch", function()
    local tag = make_chart_tag("Alice", true)
    local surface = make_surface(1, { tag })
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Alice" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1, reason = defines.disconnect_reason.switching_servers }
    ChartTagOwnershipManager.on_player_left_game(event)
    assert(tag.last_user == nil, "Tag owner should be reset to nil for switching_servers")
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player leaving" then found = true end
    end
    assert(found, "Should log reset due to player leaving for switching_servers")
  end)

  it("on_player_left_game resets ownership for kicked_and_deleted and covers reset_count > 0 branch", function()
    local tag = make_chart_tag("Alice", true)
    local surface = make_surface(1, { tag })
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Alice" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1, reason = defines.disconnect_reason.kicked_and_deleted }
    ChartTagOwnershipManager.on_player_left_game(event)
    assert(tag.last_user == nil, "Tag owner should be reset to nil for kicked_and_deleted")
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player leaving" then found = true end
    end
    assert(found, "Should log reset due to player leaving for kicked_and_deleted")
  end)

  it("on_player_left_game resets ownership for banned and covers reset_count > 0 branch", function()
    local tag = make_chart_tag("Alice", true)
    local surface = make_surface(1, { tag })
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Alice" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1, reason = defines.disconnect_reason.banned }
    ChartTagOwnershipManager.on_player_left_game(event)
    assert(tag.last_user == nil, "Tag owner should be reset to nil for banned")
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player leaving" then found = true end
    end
    assert(found, "Should log reset due to player leaving for banned")
  end)

  it("on_player_removed always resets ownership and covers reset_count > 0 branch", function()
    local tag = make_chart_tag("Bob", true)
    local surface = make_surface(1, { tag })
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Bob" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1 }
    ChartTagOwnershipManager.on_player_removed(event)
    assert(tag.last_user == nil, "Tag owner should be reset to nil for player removal")
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player removal" then found = true end
    end
    assert(found, "Should log reset due to player removal")
  end)

  it("handles missing/invalid player in on_player_left_game and on_player_removed and logs warning", function()
    mock_error_handler.clear()
    _G.game = { get_player = function() return nil end }
    local event = { player_index = 1 }
    ChartTagOwnershipManager.on_player_left_game(event)
    ChartTagOwnershipManager.on_player_removed(event)
    local calls = mock_error_handler.get_calls()
    local warn_count = 0
    for _, call in ipairs(calls) do
      if call.type == "warn" then warn_count = warn_count + 1 end
    end
    assert(warn_count >= 2, "Should log warn for both left and removed invalid player")
  end)

  it("on_player_removed does not log reset when no tags owned (reset_count == 0)", function()
    local tag = make_chart_tag("Carol", true)
    local surface = make_surface(1, { tag })
    -- Bob owns no tags
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Bob" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1 }
    ChartTagOwnershipManager.on_player_removed(event)
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player removal" then found = true end
    end
    assert(not found, "Should not log reset due to player removal when reset_count == 0")
  end)

  it("on_player_left_game does not log reset when reason does not match and reset_count == 0", function()
    local tag = make_chart_tag("Carol", true)
    local surface = make_surface(1, { tag })
    -- Bob owns no tags
    _G.game = { surfaces = { [1] = surface }, get_player = function(idx) return { name = "Bob" } end }
    mock_cache.Lookups.get_chart_tag_cache = function() return { tag } end
    mock_error_handler.clear()
    local event = { player_index = 1, reason = defines.disconnect_reason.afk }
    ChartTagOwnershipManager.on_player_left_game(event)
    local calls = mock_error_handler.get_calls()
    local found = false
    for _, call in ipairs(calls) do
      if call.msg == "Reset chart tag ownership due to player leaving" then found = true end
    end
    assert(not found, "Should not log reset due to player leaving when reset_count == 0 and reason does not match")
  end)
end)
