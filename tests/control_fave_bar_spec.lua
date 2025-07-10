
require("tests.test_bootstrap")
require("tests.mocks.defines_mock")
local spy_utils = require("tests.mocks.spy_utils")

-- Patch CursorUtils.is_dragging_favorite to always return false for tests
local CursorUtils = require("core.utils.cursor_utils")
CursorUtils.is_dragging_favorite = function() return false end

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
  local mock_gui_helpers = require("tests.mocks.mock_gui_helpers")
  GuiHelpers.get_or_create_gui_flow_from_gui_top = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
end

-- Patch: mock fave_bar.update_single_slot and build
local fave_bar = require("gui.favorites_bar.fave_bar")
fave_bar.update_single_slot = function() end
fave_bar.update_toggle_state = function() end
fave_bar.build = function() end

-- Patch: mock GameHelpers.player_print
local GameHelpers = require("core.utils.game_helpers")
GameHelpers.player_print = function() end

-- Patch: mock SlotInteractionHandlers
local SlotInteractionHandlers = require("core.control.slot_interaction_handlers")
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
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
  end)

  it("returns early for invalid player", function()
    local event = make_event{ }
    local orig = game.get_player
    game.get_player = function() return nil end
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    game.get_player = orig
  end)

  it("calls SlotInteractionHandlers.handle_teleport for slot click", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false } } }
    end
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, shift = false, control = false }
    local called = false
    local orig = SlotInteractionHandlers.handle_teleport
    SlotInteractionHandlers.handle_teleport = function(...)
      called = true; return false
    end
    ControlFaveBar.on_fave_bar_gui_click(event)
    SlotInteractionHandlers.handle_teleport = orig
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("calls handle_toggle_button_click for toggle button", function()
    local event = make_event{ element_name = "fave_bar_visibility_toggle" }
    local called = false
    local orig = GuiHelpers.get_or_create_gui_flow_from_gui_top
    GuiHelpers.get_or_create_gui_flow_from_gui_top = function(...) called = true; return orig(...) end
    ControlFaveBar.on_fave_bar_gui_click(event)
    GuiHelpers.get_or_create_gui_flow_from_gui_top = orig
    assert.is_true(called)
  end)

  it("calls handle_map_right_click for map element and right click", function()
    local event = make_event{ element_name = "map", button = 2 }
    local called = false
    local orig = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() called = true; return true end
    ControlFaveBar.on_fave_bar_gui_click(event)
    CursorUtils.is_dragging_favorite = orig
    assert.is_true(called)
  end)

  it("does not call any handler for unknown element", function()
    local event = make_event{ element_name = "unknown_element" }
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
  end)

  it("handles blank slot (no favorite)", function()
    -- Patch PlayerFavorites to return blank favorite for slot 1
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = nil, locked = false } } }
    end
    local event = make_event{ element_name = "fave_bar_slot_1" }
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    PlayerFavorites.new = orig_new
  end)

  it("handles locked slot (should not allow drag)", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = true } } }
    end
    local event = make_event{ element_name = "fave_bar_slot_1", shift = true }
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    PlayerFavorites.new = orig_new
  end)

  it("handles invalid slot number gracefully", function()
    local event = make_event{ element_name = "fave_bar_slot_" } -- no number
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
  end)

  it("handles drag and drop logic (left click during drag)", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return {
        favorites = { [1] = { gps = "1,1,1", locked = false }, [2] = { gps = "2,2,2", locked = false } },
        move_favorite = function() return true end
      }
    end
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 1 }
    assert(pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end))
    CursorUtils.is_dragging_favorite = orig_is_dragging
    PlayerFavorites.new = orig_new
  end)

  it("handles drag cancel (right click during drag)", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false }, [2] = { gps = "2,2,2", locked = false } } }
    end
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 2 }
    assert.has_no.errors(function() ControlFaveBar.on_fave_bar_gui_click(event) end)
    CursorUtils.is_dragging_favorite = orig_is_dragging
    PlayerFavorites.new = orig_new
  end)


  it("calls handle_toggle_lock for ctrl+click", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false } } }
    end
    local called = false
    local orig = SlotInteractionHandlers.handle_toggle_lock
    SlotInteractionHandlers.handle_toggle_lock = function(...) called = true; return true end
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, control = true }
    ControlFaveBar.on_fave_bar_gui_click(event)
    SlotInteractionHandlers.handle_toggle_lock = orig
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("calls handle_shift_left_click for shift+click", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false } } }
    end
    local called = false
    local orig = SlotInteractionHandlers.handle_shift_left_click
    SlotInteractionHandlers.handle_shift_left_click = function(...) called = true; return true end
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1, shift = true }
    ControlFaveBar.on_fave_bar_gui_click(event)
    SlotInteractionHandlers.handle_shift_left_click = orig
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("calls handle_request_to_open_tag_editor for right-click", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false } } }
    end
    local called = false
    local orig = SlotInteractionHandlers.handle_request_to_open_tag_editor
    SlotInteractionHandlers.handle_request_to_open_tag_editor = function(...) called = true; return true end
    local event = make_event{ element_name = "fave_bar_slot_1", button = 2 }
    ControlFaveBar.on_fave_bar_gui_click(event)
    SlotInteractionHandlers.handle_request_to_open_tag_editor = orig
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("falls back to handle_drop_on_slot if direct reorder fails", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return {
        favorites = { [1] = { gps = "1,1,1", locked = false }, [2] = { gps = "2,2,2", locked = false } },
        move_favorite = function() return false end
      }
    end
    local orig_is_dragging = CursorUtils.is_dragging_favorite
    CursorUtils.is_dragging_favorite = function() return true, 1 end
    local orig_reorder = require("core.control.control_fave_bar").reorder_favorites or function() return false end
    require("core.control.control_fave_bar").reorder_favorites = function() return false end
    local called = false
    local orig_drop = SlotInteractionHandlers.handle_drop_on_slot
    SlotInteractionHandlers.handle_drop_on_slot = function(...) called = true; return true end
    local event = make_event{ element_name = "fave_bar_slot_2", button = 1 }
    ControlFaveBar.on_fave_bar_gui_click(event)
    SlotInteractionHandlers.handle_drop_on_slot = orig_drop
    require("core.control.control_fave_bar").reorder_favorites = orig_reorder
    CursorUtils.is_dragging_favorite = orig_is_dragging
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("calls fave_bar.update_single_slot after slot interaction", function()
    local PlayerFavorites = require("core.favorite.player_favorites")
    local orig_new = PlayerFavorites.new
    PlayerFavorites.new = function()
      return { favorites = { [1] = { gps = "1,1,1", locked = false } } }
    end
    local called = false
    local orig = fave_bar.update_single_slot
    fave_bar.update_single_slot = function() called = true end
    local event = make_event{ element_name = "fave_bar_slot_1", button = 1 }
    ControlFaveBar.on_fave_bar_gui_click(event)
    fave_bar.update_single_slot = orig
    PlayerFavorites.new = orig_new
    assert(called == true)
  end)

  it("calls fave_bar.update_toggle_state in handle_toggle_button_click", function()
    local called = false
    local orig_update = fave_bar.update_toggle_state
    fave_bar.update_toggle_state = function() called = true end
    local event = make_event{ element_name = "fave_bar_visibility_toggle", button = 1 }

    -- Patch the GUI hierarchy so all elements are valid
    local orig_get_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top
    local orig_find_child = require("core.utils.gui_validation").find_child_by_name
    local slots_flow = { valid = true, visible = true }
    local bar_flow = { valid = true }
    local bar_frame = { valid = true }
    local main_flow = { valid = true }
    GuiHelpers.get_or_create_gui_flow_from_gui_top = function() return main_flow end
    require("core.utils.gui_validation").find_child_by_name = function(parent, name)
      if parent == main_flow and name == "fave_bar_frame" then return bar_frame end
      if parent == bar_frame and name == "fave_bar_flow" then return bar_flow end
      if parent == bar_flow and name == "fave_bar_slots_flow" then return slots_flow end
      return nil
    end

    ControlFaveBar.on_fave_bar_gui_click(event)

    -- Restore
    fave_bar.update_toggle_state = orig_update
    GuiHelpers.get_or_create_gui_flow_from_gui_top = orig_get_flow
    require("core.utils.gui_validation").find_child_by_name = orig_find_child
    assert(called == true)
  end)

  it("returns early in handle_toggle_button_click for invalid GUI elements", function()
    local event = make_event{ element_name = "fave_bar_visibility_toggle", button = 1 }
    local orig_helpers = GuiHelpers.get_or_create_gui_flow_from_gui_top
    GuiHelpers.get_or_create_gui_flow_from_gui_top = function() return { valid = false } end
    assert(pcall(function() ControlFaveBar.on_fave_bar_gui_click(event) end))
    GuiHelpers.get_or_create_gui_flow_from_gui_top = orig_helpers
  end)

  it("handle_map_right_click returns false if not right click or not dragging", function()
    local event = make_event{ element_name = "map", button = 1 }
    local result = ControlFaveBar.on_fave_bar_gui_click(event)
    assert(result == nil)
  end)

end)
