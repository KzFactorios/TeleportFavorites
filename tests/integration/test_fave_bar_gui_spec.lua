require("tests.test_bootstrap")

---@diagnostic disable: undefined-global
-- tests/integration/test_fave_bar_gui_spec.lua
-- Integration test for the Favorites Bar GUI (fave_bar)
-- Only one test: structure and slot count

local mock_gui = require("tests.mocks.mock_gui")
package.loaded["gui.gui_base"] = {
  create_frame = mock_gui.create_frame,
  create_hflow = mock_gui.create_hflow,
  create_label = mock_gui.create_label,
}
package.loaded["gui_base"] = package.loaded["gui.gui_base"]

local assert = require("luassert")
local Constants = require("constants")
local mock_helpers = require("tests.mocks.mock_helpers")
local Helpers = require("core.utils.helpers_suite")

local fave_bar = require("gui.favorites_bar.fave_bar")
local control_fave_bar = reload_module("core.control.control_fave_bar")
print("[TEST DEBUG] control_fave_bar.on_fave_bar_gui_click =", tostring(control_fave_bar.on_fave_bar_gui_click))

-- Patch Helpers in package.loaded if present
local ok, helpers = pcall(require, "core.utils.helpers_suite")
if ok and helpers then
  helpers.create_slot_button = mock_helpers.mock_create_slot_button
end
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

local function patched_mock_player()
  local player = mock_player()
  mock_gui.patch_add_method(player.gui.top)
  mock_gui.patch_add_method(player.gui.screen)
  -- Patch persistent storage for player and surface
  if not storage.players then storage.players = {} end
  if not storage.players[player.index] then storage.players[player.index] = {} end
  if not storage.players[player.index].surfaces then storage.players[player.index].surfaces = {} end
  if not storage.players[player.index].surfaces[player.surface.index] then
    storage.players[player.index].surfaces[player.surface.index] = { favorites = {} }
  end
  -- Patch player settings
  if not storage.players[player.index].settings then
    storage.players[player.index].settings = { favorites_on = true }
  end
  -- Ensure toggle_fav_bar_buttons is initialized as in production
  if storage.players[player.index].toggle_fav_bar_buttons == nil then
    storage.players[player.index].toggle_fav_bar_buttons = true
  end
  return player
end

local function get_slots_flow(player)
  local bar_frame = player.gui.top.fave_bar_frame
  if not bar_frame then return nil end
  local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
  if not bar_flow then return nil end
  return Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
end

describe("Favorites Bar GUI", function()
  it("builds with correct structure and slot count", function()
    local player = patched_mock_player()
    _G.__test_player = player
    local bar_frame = fave_bar.build(player, player.gui.top)
    assert(bar_frame ~= nil, "fave_bar.build returned nil")
    player.gui.top.fave_bar_frame = bar_frame
    print("bar_frame children names:")
    if type(bar_frame) == "table" and type(bar_frame.children) == "table" then
      for i, child in ipairs(bar_frame.children) do
        print(i, child.name)
      end
    end
    local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
    assert(bar_flow ~= nil, "bar_frame.fave_bar_flow is nil")
    local toggle_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_toggle_flow")
    assert(toggle_flow ~= nil, "bar_flow.fave_bar_toggle_flow is nil")
    local visible_btns_toggle = Helpers.find_child_by_name(toggle_flow, "fave_bar_visible_btns_toggle")
    assert(visible_btns_toggle ~= nil, "toggle_flow.fave_bar_visible_btns_toggle is nil")
    local slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    assert(slots_flow ~= nil, "slots_flow is nil")
    assert(type(slots_flow.children) == "table", "slots_flow.children is not a table")
    local expected_slot_count = Constants.settings and Constants.settings.MAX_FAVORITE_SLOTS or 10
    assert(#slots_flow.children == expected_slot_count,
      "Expected " .. expected_slot_count .. " slots, got " .. tostring(#slots_flow.children))
  end)

  it("toggles slot button visibility on fave_bar_visible_btns_toggle click", function()
    local player = patched_mock_player()
    _G.__test_player = player
    local bar_frame = fave_bar.build(player, player.gui.top)
    player.gui.top.fave_bar_frame = bar_frame
    local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
    assert.is_not_nil(bar_flow)
    local toggle_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_toggle_flow")
    assert.is_not_nil(toggle_flow)
    local visible_btns_toggle = Helpers.find_child_by_name(toggle_flow, "fave_bar_visible_btns_toggle")
    assert.is_not_nil(visible_btns_toggle)
    local slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    assert.is_not_nil(slots_flow)
    -- Initial state: visible
    slots_flow.visible = true
    debug_state("before first toggle", player, bar_flow)
    -- First toggle: hide
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    local slots_flow_after_hide = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    debug_state("after first toggle", player, bar_flow)
    assert.is_not_nil(slots_flow_after_hide)
    if slots_flow_after_hide and slots_flow_after_hide.visible ~= nil then
      assert.is_false(slots_flow_after_hide.visible)
    end
    -- Second toggle: show again
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    local slots_flow_after_show = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    debug_state("after second toggle", player, bar_flow)
    assert.is_not_nil(slots_flow_after_show)
    if slots_flow_after_show and slots_flow_after_show.visible ~= nil then
      assert.is_true(slots_flow_after_show.visible)
    end
  end)

  it("shows slots_flow again after toggling fave_bar_visible_btns_toggle twice", function()
    local player = patched_mock_player()
    _G.__test_player = player
    local bar_frame = fave_bar.build(player, player.gui.top)
    player.gui.top.fave_bar_frame = bar_frame
    local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
    assert.is_not_nil(bar_flow)
    local toggle_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_toggle_flow")
    assert.is_not_nil(toggle_flow)
    local visible_btns_toggle = Helpers.find_child_by_name(toggle_flow, "fave_bar_visible_btns_toggle")
    assert.is_not_nil(visible_btns_toggle)
    local slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    assert.is_not_nil(slots_flow)
    -- Initial state: visible
    slots_flow.visible = true
    debug_state("before first toggle", player, bar_flow)
    -- First toggle: hide
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    local slots_flow_after_hide = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    debug_state("after first toggle", player, bar_flow)
    assert.is_not_nil(slots_flow_after_hide)
    assert.is_false(slots_flow_after_hide.visible)
    -- Second toggle: show again
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    local slots_flow_after_show = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    debug_state("after second toggle", player, bar_flow)
    assert.is_not_nil(slots_flow_after_show)
    assert.is_true(slots_flow_after_show.visible)
  end)

  it("shows slots_flow again after toggling fave_bar_visible_btns_toggle twice, even if slots_flow is destroyed", function()
    local player = patched_mock_player()
    _G.__test_player = player
    local bar_frame = fave_bar.build(player, player.gui.top)
    player.gui.top.fave_bar_frame = bar_frame
    local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
    assert.is_not_nil(bar_flow)
    local toggle_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_toggle_flow")
    assert.is_not_nil(toggle_flow)
    local visible_btns_toggle = Helpers.find_child_by_name(toggle_flow, "fave_bar_visible_btns_toggle")
    assert.is_not_nil(visible_btns_toggle)
    local slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    assert.is_not_nil(slots_flow)
    debug_state("before first toggle", player, bar_flow)
    -- First toggle: hide (simulate handler)
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    debug_state("after first toggle", player, bar_flow)
    -- Simulate in-game behavior: slots_flow is destroyed when hidden
    if bar_flow and type(bar_flow.children) == "table" then
      for i = #bar_flow.children, 1, -1 do
        local child = bar_flow.children[i]
        if child and child.name == "fave_bar_slots_flow" then
          table.remove(bar_flow.children, i)
          break
        end
      end
    end
    debug_state("after slots_flow destroyed", player, bar_flow)
    -- Second toggle: show again (should recreate slots_flow)
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    local new_slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    debug_state("after second toggle", player, bar_flow)
    assert.is_not_nil(new_slots_flow)
    if new_slots_flow then
      assert.is_true(new_slots_flow.visible)
    end
  end)

  it("persists toggle_fav_bar_buttons state in storage across toggles", function()
    local player = patched_mock_player()
    _G.__test_player = player
    local bar_frame = fave_bar.build(player, player.gui.top)
    player.gui.top.fave_bar_frame = bar_frame
    local bar_flow = Helpers.find_child_by_name(bar_frame, "fave_bar_flow")
    assert.is_not_nil(bar_flow)
    local toggle_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_toggle_flow")
    assert.is_not_nil(toggle_flow)
    local visible_btns_toggle = Helpers.find_child_by_name(toggle_flow, "fave_bar_visible_btns_toggle")
    assert.is_not_nil(visible_btns_toggle)
    local slots_flow = Helpers.find_child_by_name(bar_flow, "fave_bar_slots_flow")
    assert.is_not_nil(slots_flow)
    debug_state("before first toggle", player, bar_flow)
    -- Initial state: should be true in storage
    assert.is_true(storage.players[player.index].toggle_fav_bar_buttons)
    -- First toggle: should set to false
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    debug_state("after first toggle", player, bar_flow)
    assert.is_false(storage.players[player.index].toggle_fav_bar_buttons)
    -- Second toggle: should set to true
    control_fave_bar.on_fave_bar_gui_click({element=visible_btns_toggle, player_index=player.index})
    debug_state("after second toggle", player, bar_flow)
    assert.is_true(storage.players[player.index].toggle_fav_bar_buttons)
  end)
end)
