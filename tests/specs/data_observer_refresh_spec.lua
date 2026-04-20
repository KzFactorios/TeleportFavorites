require("test_bootstrap")

local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")
local bootstrap = require("test_bootstrap")
local fave_bar = bootstrap.fave_bar

package.loaded["core.events.gui_observer"] = nil
local GuiObserver = require("core.events.gui_observer")

local function planet_player(index, name)
  local p = PlayerFavoritesMocks.mock_player(index, name, 1)
  p.surface.planet = {}
  p.surface.platform = nil
  return p
end

describe("DataObserver refresh routing", function()
  before_each(function()
    fave_bar.refresh_slots_spy:reset()
    fave_bar.mark_slot_dirty_spy:reset()
  end)

  it("calls refresh_slots when slots table is empty (no partial no-op)", function()
    local obs = GuiObserver.DataObserver:new(planet_player(1, "TestPlayer"))
    obs:update({ player_index = 1, slots = {} })
    assert.are.equal(1, fave_bar.refresh_slots_spy:call_count())
    assert.are.equal(0, fave_bar.mark_slot_dirty_spy:call_count())
  end)

  it("calls refresh_slots when full_refresh is set", function()
    local obs = GuiObserver.DataObserver:new(planet_player(1, "TestPlayer"))
    obs:update({ player_index = 1, full_refresh = true })
    assert.are.equal(1, fave_bar.refresh_slots_spy:call_count())
  end)

  it("marks dirty slots when slots map has entries", function()
    local obs = GuiObserver.DataObserver:new(planet_player(1, "TestPlayer"))
    obs:update({ player_index = 1, slots = { [2] = true, [5] = true } })
    assert.are.equal(2, fave_bar.mark_slot_dirty_spy:call_count())
    assert.are.equal(0, fave_bar.refresh_slots_spy:call_count())
  end)
end)

describe("GuiEventBus coalesce refresh merge", function()
  before_each(function()
    package.loaded["core.events.gui_observer"] = nil
    GuiObserver = require("core.events.gui_observer")
    fave_bar.refresh_slots_spy:reset()
    fave_bar.mark_slot_dirty_spy:reset()
  end)

  it("coarse + slot-specific coalesces to full_refresh and refresh_slots", function()
    local mock_player = planet_player(7, "P7")
    local obs = GuiObserver.DataObserver:new(mock_player)
    GuiObserver.GuiEventBus._observers = {}
    GuiObserver.GuiEventBus._deferred_queue = {}
    GuiObserver.GuiEventBus.subscribe("cache_updated", obs)

    GuiObserver.GuiEventBus.notify("cache_updated", { player_index = 7, type = "tag_move" })
    GuiObserver.GuiEventBus.notify("favorite_updated", { player_index = 7, slot = 3 })
    GuiObserver.GuiEventBus.process_deferred_notifications()

    assert.are.equal(1, fave_bar.refresh_slots_spy:call_count())
    assert.are.equal(0, fave_bar.mark_slot_dirty_spy:call_count())
  end)

  it("two slot-specific merges stay partial (mark_slot_dirty)", function()
    local mock_player = planet_player(8, "P8")
    local obs = GuiObserver.DataObserver:new(mock_player)
    GuiObserver.GuiEventBus._observers = {}
    GuiObserver.GuiEventBus._deferred_queue = {}
    GuiObserver.GuiEventBus.subscribe("cache_updated", obs)

    GuiObserver.GuiEventBus.notify("favorite_updated", { player_index = 8, slot = 1 })
    GuiObserver.GuiEventBus.notify("favorite_updated", { player_index = 8, slot = 2 })
    GuiObserver.GuiEventBus.process_deferred_notifications()

    assert.are.equal(0, fave_bar.refresh_slots_spy:call_count())
    assert.are.equal(2, fave_bar.mark_slot_dirty_spy:call_count())
  end)
end)
