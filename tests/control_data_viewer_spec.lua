-- Patch package.path to include mod root for core/ and other folders
local sep = package.config:sub(1,1)
local mod_root = (".." .. sep)
package.path = mod_root .. "?.lua;" .. mod_root .. "?" .. sep .. "init.lua;" .. package.path
-- Inject mock for gui_base via global for dependency injection
_G.__TF_GUIBASE__ = {
  create_named_element = function(type, parent, opts)
    if not parent or not parent.valid then return nil end
    if not opts or not opts.name then return nil end
    return parent:add{ type = type, name = opts.name, style = opts.style, caption = opts.caption, sprite = opts.sprite, tooltip = opts.tooltip }
  end,
  create_vflow = function(parent, name) return parent:add{ type = "flow", name = name, direction = "vertical" } end,
  create_element = function(type, parent, opts) return parent:add{ type = type, name = opts and opts.name or "", style = opts and opts.style, caption = opts and opts.caption, sprite = opts and opts.sprite, tooltip = opts and opts.tooltip } end,
  create_label = function(parent, name, caption, style) return parent:add{ type = "label", name = name, caption = caption, style = style } end,
  create_frame = function(parent, name, direction, style)
    return parent:add{ type = "frame", name = name, direction = direction or 'horizontal', style = style or 'inside_shallow_frame_with_padding' }
  end
}

-- Now patch all other mocks
local mock_cache = require("mocks.mock_cache")
package.loaded["core.cache.cache"] = mock_cache
package.loaded["core.cache.lookups"] = mock_cache.Lookups
_G.Lookups = mock_cache.Lookups

local mock_gui_helpers = require("mocks.mock_gui_helpers")
if not mock_gui_helpers.create_named_element then mock_gui_helpers.create_named_element = function(parent, def) return parent:add(def) end end
package.loaded["core.utils.gui_helpers"] = mock_gui_helpers
package.loaded["gui.data_viewer.gui_helpers"] = mock_gui_helpers
package.loaded["gui.gui_helpers"] = mock_gui_helpers

require("mocks.mock_require_patch")

-- Patch global settings to use the mock for all tests (simulate Factorio env)
_G.settings = require("mocks.mock_settings")

-- Patch global storage to use the mock for all tests (simulate Factorio env)
rawset(_G, "storage", require("mocks.mock_storage"))
local mock_luaPlayer = require("mocks.mock_luaPlayer")
local mock_error_handler = require("mocks.mock_error_handler")
package.loaded["core.utils.error_handler"] = mock_error_handler
local mock_gui_helpers = require("mocks.mock_gui_helpers")
local mock_gui_validation = require("mocks.mock_gui_validation")
package.loaded["core.utils.gui_validation"] = mock_gui_validation
-- Add diagnostic print to the mock
local orig_find_child_by_name = mock_gui_validation.find_child_by_name
mock_gui_validation.find_child_by_name = function(parent, name)
  print("[MOCK GUI VALIDATION] find_child_by_name called with:", parent and parent.name, name)
  if parent and name then
    print("[MOCK GUI VALIDATION] parent[name]:", parent[name])
    if parent[name] then print("[MOCK GUI VALIDATION] parent[name].valid:", parent[name].valid) end
  end
  return orig_find_child_by_name(parent, name)
end
local DataViewerControl = require("core.control.control_data_viewer")

-- Patch global game object
_G.game = {
  get_player = function(idx)
    if idx == 99 then return nil end
    return mock_luaPlayer(idx, "Player"..tostring(idx))
  end,
  surfaces = {
    [1] = { index = 1, valid = true, name = "nauvis" },
    [2] = { index = 2, valid = true, name = "orbit" }
  },
  forces = {
    player = { name = "player" },
    enemy = { name = "enemy" }
  }
}

-- Patch global storage for all_data tab
_G.storage = _G.storage or { foo = "bar" }


-- Helper to create a mock GUI element with recursive add method
local function make_mock_gui_element(props)
  local elem = props or {}
  elem.valid = elem.valid ~= false -- default to true
  if type(elem.children) ~= "table" then elem.children = {} end
  elem.add = function(self, def)
    local child = make_mock_gui_element(def)
    if type(self.children) ~= "table" then self.children = {} end
    table.insert(self.children, child)
    if def and def.name then self[def.name] = child end
    return child
  end
  return elem
end

-- Always stub safe_destroy_frame, get_surface_data, and get_or_create_gui_flow_from_gui_top before each test
local function reset_mocks()
  mock_error_handler.clear()
  mock_cache.clear()
  -- Always stub safe_destroy_frame to a no-op and patch SUT
  mock_gui_validation.safe_destroy_frame = function() end
  require("core.utils.gui_validation").safe_destroy_frame = mock_gui_validation.safe_destroy_frame
  -- Always stub get_surface_data to return dummy data and patch SUT and all plausible Lookups
  local get_surface_data_mock = function(...)
    print("[MOCK] get_surface_data called", ...)
    return {} 
  end
  mock_cache.Lookups.get_surface_data = get_surface_data_mock
  require("core.cache.cache").Lookups.get_surface_data = get_surface_data_mock
  local lookups_mod = require("core.cache.lookups")
  lookups_mod.get_surface_data = get_surface_data_mock
  _G.Lookups.get_surface_data = get_surface_data_mock
  -- Always stub get_or_create_gui_flow_from_gui_top to return a valid flow and patch SUT
  mock_gui_helpers.get_or_create_gui_flow_from_gui_top = function()
    return make_mock_gui_element{ name = "main_flow" }
  end
  require("core.utils.gui_helpers").get_or_create_gui_flow_from_gui_top = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
end

-- Minimal busted assert helpers for compatibility
local function assert_is_true(val, msg) assert(val == true, msg or ('expected true, got ' .. tostring(val))) end
local function assert_is_function(val, msg) assert(type(val) == 'function', msg or ('expected function, got ' .. tostring(val))) end
local function assert_is_table(val, msg) assert(type(val) == 'table', msg or ('expected table, got ' .. tostring(val))) end

describe("control_data_viewer.on_toggle_data_viewer", function()
  before_each(reset_mocks)

  it("logs and returns for invalid player", function()
    DataViewerControl.on_toggle_data_viewer{ player_index = 99 }
    local calls = mock_error_handler.get_calls()
    print("[TEST DEBUG] #calls after invalid player:", #calls)
    if #calls > 0 then print("[TEST DEBUG] last call msg:", calls[#calls].msg) end
    assert_is_table(calls)
    assert_is_true(#calls > 0)
    assert_is_true(calls[#calls].msg:find("invalid player") ~= nil)
  end)

  it("logs and returns for missing main flow", function()
    local player = mock_luaPlayer(1)
    local orig = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = function() return nil end
    DataViewerControl.on_toggle_data_viewer{ player_index = 1 }
    local calls = mock_error_handler.get_calls()
    assert(#calls > 0)
    assert(calls[#calls].msg:find("no main flow"))
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = orig
  end)

  it("destroys frame if exists and valid", function()
    local player = mock_luaPlayer(1)
    local main_flow = mock_gui_helpers.get_or_create_gui_flow_from_gui_top(player)
    local frame = { name = "data_viewer_frame", valid = true }
    main_flow.children = { frame }
    main_flow["data_viewer_frame"] = frame
    -- Patch get_or_create_gui_flow_from_gui_top to always return this main_flow for this test
    local orig_get_flow = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = function() return main_flow end
    local called = false
    mock_gui_validation.safe_destroy_frame = function(flow, name)
      called = (flow == main_flow and name == "data_viewer_frame")
    end
    -- Patch DataViewerControl.rebuild_data_viewer to prevent further GUI calls
    local orig_rebuild = DataViewerControl.rebuild_data_viewer
    DataViewerControl.rebuild_data_viewer = function() end
    DataViewerControl.on_toggle_data_viewer{ player_index = 1 }
    DataViewerControl.rebuild_data_viewer = orig_rebuild
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = orig_get_flow
    assert_is_true(called)
  end)

  it("builds new frame if frame missing or invalid", function()
    local player = mock_luaPlayer(1)
    local main_flow = mock_gui_helpers.get_or_create_gui_flow_from_gui_top(player)
    main_flow.children = {}
    main_flow["data_viewer_frame"] = nil
    local called = false
    DataViewerControl.rebuild_data_viewer = function(p, mf, tab, size)
      called = (p == player and mf == main_flow)
    end
    -- Patch mock_gui_validation.safe_destroy_frame to prevent errors
    local orig_destroy = mock_gui_validation.safe_destroy_frame
    mock_gui_validation.safe_destroy_frame = function() end
    DataViewerControl.on_toggle_data_viewer{ player_index = 1 }
    mock_gui_validation.safe_destroy_frame = orig_destroy
    assert_is_true(called)
  end)
end)

describe("control_data_viewer.on_data_viewer_gui_click", function()
  before_each(reset_mocks)

  it("returns for invalid element", function()
    local called = false
    DataViewerControl.on_data_viewer_gui_click{ element = nil, player_index = 1 }
    -- no error, no call
    assert(true)
  end)

  it("returns for invalid player", function()
    local element = { name = "foo", valid = true }
    DataViewerControl.on_data_viewer_gui_click{ element = element, player_index = 99 }
    assert(true)
  end)

  it("handles font up/down", function()
    local element = { name = "data_viewer_actions_font_up_btn", valid = true }
    local called = false
    DataViewerControl.update_font_size = function(p, mf, delta)
      called = (delta == 2)
    end
    -- Patch DataViewerControl.rebuild_data_viewer to prevent further GUI calls
    local orig_rebuild = DataViewerControl.rebuild_data_viewer
    DataViewerControl.rebuild_data_viewer = function() end
    -- Patch get_or_create_gui_flow_from_gui_top to always return a valid flow
    local orig_get_flow = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = function() return { children = {}, valid = true } end
    DataViewerControl.on_data_viewer_gui_click{ element = element, player_index = 1 }
    DataViewerControl.rebuild_data_viewer = orig_rebuild
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = orig_get_flow
    assert_is_true(called)
  end)

  it("handles close button", function()
    local element = { name = "data_viewer_close_btn", valid = true }
    local called = false
    mock_gui_validation.safe_destroy_frame = function(flow, name)
      called = (name == "data_viewer_frame")
    end
    -- Patch DataViewerControl.rebuild_data_viewer to prevent further GUI calls
    local orig_rebuild = DataViewerControl.rebuild_data_viewer
    DataViewerControl.rebuild_data_viewer = function() end
    DataViewerControl.on_data_viewer_gui_click{ element = element, player_index = 1 }
    DataViewerControl.rebuild_data_viewer = orig_rebuild
    assert_is_true(called)
  end)

  it("handles tab switches and updates content", function()
    -- Patch get_surface_data on all plausible Lookups and reload SUT just before test
    local get_surface_data_mock = function(...)
      print("[TEST PATCH] get_surface_data called", ...)
      return {} 
    end
    mock_cache.Lookups.get_surface_data = get_surface_data_mock
    require("core.cache.cache").Lookups.get_surface_data = get_surface_data_mock
    local lookups_mod = require("core.cache.lookups")
    lookups_mod.get_surface_data = get_surface_data_mock
    _G.Lookups.get_surface_data = get_surface_data_mock
    -- Patch DataViewerControl's Lookups if possible
    if DataViewerControl and DataViewerControl.Lookups then
      DataViewerControl.Lookups.get_surface_data = get_surface_data_mock
    end
    package.loaded["core.control.control_data_viewer"] = nil
    local DataViewerControlReloaded = require("core.control.control_data_viewer")
    if DataViewerControlReloaded and DataViewerControlReloaded.Lookups then
      DataViewerControlReloaded.Lookups.get_surface_data = get_surface_data_mock
    end
    local tabs = {
      { name = "data_viewer_player_data_tab", tab = "player_data" },
      { name = "data_viewer_surface_data_tab", tab = "surface_data" },
      { name = "data_viewer_lookup_tab", tab = "lookup" },
      { name = "data_viewer_all_data_tab", tab = "all_data" }
    }
    for _, t in ipairs(tabs) do
      local element = { name = t.name, valid = true }
      local called = false
      DataViewerControlReloaded.load_tab_data = function(p, tab, size) return { data = {}, top_key = tab } end
      local orig_update_tab = require("gui.data_viewer.data_viewer").update_tab_selection
      require("gui.data_viewer.data_viewer").update_tab_selection = function(p, tab)
        called = (tab == t.tab)
      end
      DataViewerControlReloaded.on_data_viewer_gui_click{ element = element, player_index = 1 }
      assert(called)
      require("gui.data_viewer.data_viewer").update_tab_selection = orig_update_tab
    end
  end)

  it("handles refresh button", function()
    local element = { name = "data_viewer_tab_actions_refresh_data_btn", valid = true }
    local called = false
    require("gui.data_viewer.data_viewer").update_content_panel = function() called = true end
    require("gui.data_viewer.data_viewer").show_refresh_notification = function() called = true end
    local orig_notify = require("core.control.control_shared_utils").notify_observer
    require("core.control.control_shared_utils").notify_observer = function(ev, data)
      called = (ev == "data_refreshed")
    end
    -- Patch DataViewerControl.rebuild_data_viewer to prevent further GUI calls
    local orig_rebuild = DataViewerControl.rebuild_data_viewer
    DataViewerControl.rebuild_data_viewer = function() end
    -- Patch get_or_create_gui_flow_from_gui_top to always return a valid flow
    local orig_get_flow = mock_gui_helpers.get_or_create_gui_flow_from_gui_top
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = function() return { children = {}, valid = true } end
    DataViewerControl.on_data_viewer_gui_click{ element = element, player_index = 1 }
    DataViewerControl.rebuild_data_viewer = orig_rebuild
    mock_gui_helpers.get_or_create_gui_flow_from_gui_top = orig_get_flow
    require("core.control.control_shared_utils").notify_observer = orig_notify
    assert_is_true(called)
  end)
end)

describe("control_data_viewer.register", function()
  it("registers tab navigation events", function()
    -- Patch global script for SUT
    _G.script = {
      events = {},
      on_event = function(name, handler)
        _G.script.events = _G.script.events or {}
        _G.script.events[name] = handler
      end
    }
    DataViewerControl.register(_G.script)
    assert_is_function(_G.script.events["tf-data-viewer-tab-next"])
    assert_is_function(_G.script.events["tf-data-viewer-tab-prev"])
    _G.script = nil
  end)
end)

-- Patch Cache.Lookups after SUT is loaded to ensure runtime uses the mock
require("core.cache.cache").Lookups = mock_cache.Lookups
