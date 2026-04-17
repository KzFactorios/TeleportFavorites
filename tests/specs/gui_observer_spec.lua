require("test_bootstrap")
require("mocks.factorio_test_env")

local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")
local BaseObserver = require("tests.mocks.base_observer")

local mock_player = PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)

--- Lightweight stand-in for GuiEventBus used in unit tests (no real gui_observer.lua load).
local function create_gui_event_bus()
  local bus = {
    _observers = {},
    _deferred_queue = {},
    _deferred_tick_active = false,
  }

  function bus:subscribe(event_name, observer)
    self._observers[event_name] = self._observers[event_name] or {}
    table.insert(self._observers[event_name], observer)
  end

  function bus:notify(event_name, data)
    self._deferred_queue[#self._deferred_queue + 1] = { event = event_name, data = data }
    self._deferred_tick_active = true
  end

  function bus:process_deferred_notifications()
    self._deferred_queue = {}
    self._deferred_tick_active = false
  end

  function bus:cleanup_old_observers()
    for event_name, observers in pairs(self._observers) do
      for i = #observers, 1, -1 do
        if not observers[i]:is_valid() then
          table.remove(observers, i)
        end
      end
      if #observers == 0 then
        self._observers[event_name] = nil
      end
    end
  end

  return bus
end

--- In-process mock module shape (same keys as core.events.gui_observer exports we care about here).
local MockGuiObserver = {
  BaseObserver = BaseObserver,
  GuiEventBus = create_gui_event_bus(),
  DataObserver = BaseObserver,
}

describe("GuiObserver (mock event bus)", function()
  before_each(function()
    _G.game = _G.game or {}
    game.tick = 1
    game.players = { [1] = mock_player }

    _G.storage = _G.storage or {}
    storage.players = {}
    _G.global = _G.global or {}
    _G.global.cache = { players = {} }

    local Constants = require("core.constants_impl")
    Constants.settings.DEFAULT_LOG_LEVEL = "debug"

    MockGuiObserver.GuiEventBus._observers = {}
    MockGuiObserver.GuiEventBus._deferred_queue = {}
    MockGuiObserver.GuiEventBus._deferred_tick_active = false

    local ErrorHandler = require("core.utils.error_handler")
    ErrorHandler.initialize("debug")
  end)

  it("exposes bus and observer tables for tests", function()
    assert(MockGuiObserver ~= nil)
    assert(type(MockGuiObserver.GuiEventBus) == "table")
    assert(type(MockGuiObserver.BaseObserver) == "table")
    assert(type(MockGuiObserver.DataObserver) == "table")
  end)

  it("manages observers and notifications correctly", function()
    local GuiEventBus = MockGuiObserver.GuiEventBus
    local DataObserver = MockGuiObserver.DataObserver

    local observer = DataObserver:new(mock_player)
    GuiEventBus:subscribe("test_event", observer)

    assert(type(GuiEventBus._observers["test_event"]) == "table")
    assert(#GuiEventBus._observers["test_event"] > 0)

    GuiEventBus:notify("test_event", { player = mock_player, type = "test" })
    assert(#GuiEventBus._deferred_queue > 0)
    assert(GuiEventBus._deferred_tick_active == true)

    GuiEventBus:notify("cache_updated", { player = mock_player, type = "cache" })
    assert(#GuiEventBus._deferred_queue == 2)

    GuiEventBus:process_deferred_notifications()
    assert(#GuiEventBus._deferred_queue == 0)
    assert(GuiEventBus._deferred_tick_active == false)
  end)

  it("cleans up invalid observers", function()
    local GuiEventBus = MockGuiObserver.GuiEventBus
    local BaseObs = MockGuiObserver.BaseObserver

    local invalid_player = {
      valid = false,
      index = 2,
      name = "InvalidPlayer",
      controller_type = (defines.controllers and defines.controllers.character) or 1,
    }

    local observer = BaseObs:new(invalid_player, "test")
    GuiEventBus:subscribe("test_cleanup", observer)

    game.tick = 1000
    GuiEventBus:cleanup_old_observers(0)

    local observers = GuiEventBus._observers["test_cleanup"]
    assert(not observers or #observers == 0)
  end)
end)
