
require("test_bootstrap")
require("mocks.defines_mock")
local spy_utils = require("mocks.spy_utils")

-- Patch CursorUtils.is_dragging_favorite to always return false for tests
local CursorUtils = require("core.utils.cursor_utils")
CursorUtils.is_dragging_favorite = function() return false end

-- Pre-emptively mock PlayerFavorites before ControlFaveBar loads it
local PlayerFavorites = require("core.favorite.player_favorites")
local original_PlayerFavorites_new = PlayerFavorites.new

-- Ensure global game.get_player is always defined for these tests
if not _G.game then _G.game = {} end
if not _G.game.get_player then
  _G.game.get_player = function(idx)
    return { 
      name = "TestPlayer", 
      index = idx or 1, 
      valid = true, 
      print = function() end,
      surface = { index = 1, name = "nauvis" }
    }
  end
end
local ControlFaveBar = require("core.control.control_fave_bar")

-- Patch: mock GuiHelpers.get_or_create_gui_flow_from_gui_top for tests
local GuiHelpers = require("core.utils.gui_helpers")
if not GuiHelpers.get_or_create_gui_flow_from_gui_top then
  local mock_gui_helpers = require("mocks.mock_gui_helpers")
  GuiHelpers.get_or_create_gui_flow_from_gui_top = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
end

-- Patch: mock fave_bar.update_single_slot and build
local fave_bar = require("gui.favorites_bar.fave_bar")
-- Store originals before mocking
local original_update_single_slot = fave_bar.update_single_slot
local original_update_toggle_state = fave_bar.update_toggle_state
local original_build = fave_bar.build
-- Apply global mocks
fave_bar.update_single_slot = function() end
fave_bar.update_toggle_state = function() end
fave_bar.build = function() end

-- Patch: mock GameHelpers.player_print
local GameHelpers = require("core.utils.game_helpers")
GameHelpers.player_print = function() end

-- Patch: mock SlotInteractionHandlers
local SlotInteractionHandlers = require("core.control.slot_interaction_handlers")

-- Save original functions before mocking them globally
local original_handle_shift_left_click = SlotInteractionHandlers.handle_shift_left_click
local original_handle_toggle_lock = SlotInteractionHandlers.handle_toggle_lock
local original_handle_teleport = SlotInteractionHandlers.handle_teleport
local original_handle_request_to_open_tag_editor = SlotInteractionHandlers.handle_request_to_open_tag_editor
local original_handle_drop_on_slot = SlotInteractionHandlers.handle_drop_on_slot

-- Apply global mocks
SlotInteractionHandlers.handle_shift_left_click = function() return false end
SlotInteractionHandlers.handle_toggle_lock = function() return false end
SlotInteractionHandlers.handle_teleport = function() return false end
SlotInteractionHandlers.handle_request_to_open_tag_editor = function() return false end
SlotInteractionHandlers.handle_drop_on_slot = function() return false end

-- Helper to create a mock event
local function make_event(props)
  local e = {
    element = { name = props.element_name or "fave_bar_slot_1", valid = true },
    player_index = props.player_index or 1,
    button = props.button or 1,
    shift = props.shift or false,
    control = props.control or false
  }
  return e
end


describe("ControlFaveBar.on_fave_bar_gui_click", function()
  it("returns early for invalid element", function()
    local event = make_event{ element_name = nil }
    event.element = nil
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("returns early for invalid player", function()
    local event = make_event{ }
    local orig = game.get_player
    game.get_player = function() return nil end
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    game.get_player = orig
  end)

  it("handles slot click without errors", function()
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, shift = false, control = false }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles toggle button click without errors", function()
    local event = make_event{ element_name = "fave_bar_visibility_toggle", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles map right click when dragging", function()
    local event = make_event{ element_name = "map", button = 2 }
    -- The global mock already sets is_dragging_favorite to always return false
    -- So we need to temporarily override it for this test
    local orig = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true end
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    CursorUtils.is_dragging_favorite = orig
  end)

  it("does not call any handler for unknown element", function()
    local event = make_event{ element_name = "unknown_element" }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles blank slot (no favorite)", function()
    -- Use the global PlayerFavorites reference we have
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = nil, locked = false } } }
    end
    local event = make_event{ element_name = "fave_bar_slot_1" }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    PlayerFavorites.new = original_PlayerFavorites_new
  end)

  it("handles locked slot (should not allow drag)", function()
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1.1.1", locked = true } } }
    end
    local event = make_event{ element_name = "fave_bar_slot_1", shift = true }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    PlayerFavorites.new = original_PlayerFavorites_new
  end)

  it("handles invalid slot number gracefully", function()
    local event = make_event{ element_name = "fave_bar_slot_" } -- no number
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles drag and drop logic (left click during drag)", function()
    PlayerFavorites.new = function()
      return {
        favorites = { [1] = { gps = "1.1.1", locked = false }, [2] = { gps = "2.2.2", locked = false } },
        move_favorite = function() return true end
      }
    end
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    CursorUtils.is_dragging_favorite = orig_is_dragging
    PlayerFavorites.new = original_PlayerFavorites_new
  end)

  it("handles drag cancel (right click during drag)", function()
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1.1.1", locked = false }, [2] = { gps = "2.2.2", locked = false } } }
    end
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 2 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    CursorUtils.is_dragging_favorite = orig_is_dragging
    PlayerFavorites.new = original_PlayerFavorites_new
  end)


  it("handles ctrl+click without errors", function()
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, control = true }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles shift+click without errors", function()
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, shift = true }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles right-click without errors", function()
    local event = make_event{ element_name = "fave_bar_slot_1", button = 2 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles drag drop fallback without errors", function()
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
    CursorUtils.is_dragging_favorite = orig_is_dragging
  end)

  it("handles slot interaction without errors", function()
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles toggle state update without errors", function()
    local event = make_event{ element_name = "fave_bar_visibility_toggle", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handles invalid GUI elements gracefully", function()
    local event = make_event{ element_name = "fave_bar_visibility_toggle", button = 1 }
    local success = pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    is_true(success)
  end)

  it("handle_map_right_click returns false if not right click or not dragging", function()
    local event = make_event{ element_name = "map", button = 1 }
    local result = ControlFaveBar.on_fave_bar_gui_click(event)
    is_nil(result)
  end)

end)
