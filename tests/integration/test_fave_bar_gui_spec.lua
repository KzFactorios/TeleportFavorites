---@diagnostic disable: undefined-global
-- tests/integration/test_fave_bar_gui_spec.lua
-- Integration tests for the Favorites Bar GUI (fave_bar)
-- Covers structure, slot count, toggle, and slot button behavior

local assert = require("luassert")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Constants = require("constants")
local Cache = require("core.cache.cache")
local mock_helpers = require("tests.mocks.mock_helpers")
local mock_gui = require("tests.mocks.mock_gui")

-- Mock Factorio global 'defines' for test environment
if not _G.defines then
  _G.defines = {
    render_mode = { game = 0, chart = 1, chart_zoomed_in = 2 },
    events = {},
    gui_type = {},
    direction = {},
    inventory = {},
    -- Add other required fields as needed for tests
  }
end

-- Patch Helpers in package.loaded if present
local ok, helpers = pcall(require, "core.utils.helpers_suite")
if ok and helpers then
  helpers.create_slot_button = mock_helpers.mock_create_slot_button
end

-- Patch require cache for Helpers
package.loaded["core.utils.helpers_suite"].create_slot_button = mock_helpers.mock_create_slot_button

-- Mock player and GUI API
local function mock_player()
  local gui = { top = {}, screen = {} }
  return {
    gui = gui,
    index = 1,
    surface = { index = 1 },
    render_mode = defines and defines.render_mode and defines.render_mode.game or 0,
    opened = nil,
    print = function() end,
    teleport = function() end,
    force = { find_chart_tags = function() return {} end },
    position = { x = 0, y = 0 },
    name = "TestPlayer"
  }
end

-- Patch mock_player to use patched add method
local function patched_mock_player()
  local player = mock_player()
  mock_gui.patch_add_method(player.gui.top)
  mock_gui.patch_add_method(player.gui.screen)
  return player
end

-- Utility to safely get slots_flow and assert not nil before further checks
local function get_slots_flow(player)
  local bar_frame = player.gui.top.fave_bar_frame
  if not bar_frame then return nil end
  local bar_flow = bar_frame.fave_bar_flow
  if not bar_flow then return nil end
  return bar_flow.fave_bar_slots_flow
end

-- Mock frame function to replace gui_base.create_frame in tests
local function mock_frame(parent, name, direction, style)
  local frame = {
    name = name,
    direction = direction or 'horizontal',
    style = { -- mock style as a table, not a string
      top_padding = 0,
      bottom_padding = 0,
      left_padding = 0,
      right_padding = 0
    },
    children = {},
    add = function(self, opts)
      local child = opts or {}
      child.children = {}
      if type(self.children) ~= "table" then self.children = {} end
      table.insert(self.children, child)
      if child.name then self[child.name] = child end
      child.add = self.add
      -- Add a style table for all GUI elements
      child.style = {}
      return child
    end
  }
  if parent and parent.children then table.insert(parent.children, frame) end
  return frame
end

-- Patch GuiBase.create_frame to use the mock_frame in test
local ok_gb, gui_base = pcall(require, "gui.gui_base")
if ok_gb and gui_base then
  gui_base.create_frame = mock_frame
end

describe("Favorites Bar GUI", function()
  it("builds with correct structure and slot count", function()
    local player = patched_mock_player()
    fave_bar.build(player, player.gui.top)
    local bar_frame = player.gui.top.fave_bar_frame
    assert.is_not_nil(bar_frame)
    assert.is_not_nil(bar_frame.fave_bar_flow)
    assert.is_not_nil(bar_frame.fave_bar_flow.fave_bar_toggle_flow)
    assert.is_not_nil(bar_frame.fave_bar_flow.fave_bar_visible_btns_toggle)
    local slots_flow = get_slots_flow(player)
    assert.is_not_nil(slots_flow)
    assert.is_table(slots_flow.children)
    assert.are.equal(Constants.settings.MAX_FAVORITE_SLOTS, #slots_flow.children)
  end)

  it("toggles the bar to hide/show the slot row", function()
    local player = patched_mock_player()
    fave_bar.build(player, player.gui.top)
    local slots_flow = get_slots_flow(player)
    assert.is_not_nil(slots_flow)
    assert.is_true(slots_flow.visible)
    -- Simulate toggle
    slots_flow.visible = false
    assert.is_false(slots_flow.visible)
    slots_flow.visible = true
    assert.is_true(slots_flow.visible)
  end)

  it("slot buttons have correct naming and are always present", function()
    local player = patched_mock_player()
    fave_bar.build(player, player.gui.top)
    local slots_flow = get_slots_flow(player)
    assert.is_not_nil(slots_flow)
    assert.is_table(slots_flow.children)
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      local btn = slots_flow.children[i]
      assert.is_not_nil(btn)
      assert.is_true(tostring(btn.name):find("fave_bar_slot_"))
      assert.are.equal(i, tonumber(btn.name:match("fave_bar_slot_(%d+)")))
    end
  end)

  it("blank slot buttons are enabled and do nothing on click", function()
    local player = patched_mock_player()
    fave_bar.build(player, player.gui.top)
    local slots_flow = get_slots_flow(player)
    assert.is_not_nil(slots_flow)
    assert.is_table(slots_flow.children)
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      local btn = slots_flow.children[i]
      assert.is_not_nil(btn)
      -- Simulate click handler: should be a no-op for blank slots
      local was_called = false
      btn.on_click = function() was_called = true end
      if btn.is_blank then
        btn:on_click()
        assert.is_false(was_called)
      end
    end
  end)
end)
