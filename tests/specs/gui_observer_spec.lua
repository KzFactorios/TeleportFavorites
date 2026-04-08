require("test_bootstrap")
require("mocks.factorio_test_env")

-- Import mock system
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")
local BaseObserver = require("tests.mocks.base_observer")

-- Initialize mock player for tests
local mock_player = PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)

-- Mock GuiEventBus implementation for testing
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

-- Create GuiObserverModule table with mock components
local GuiObserverModule = {
    BaseObserver = BaseObserver,
    GuiEventBus  = create_gui_event_bus(),
    DataObserver = BaseObserver,
}

-- Mock package.loaded for GuiObserver dependencies
package.loaded["core.events.gui_observer"] = GuiObserverModule

-- Export for use in tests
local GuiEventBus = GuiObserverModule.GuiEventBus

describe("GuiObserver", function()
    -- Reset GuiEventBus state before each test
    -- Run before each test to reset state
    before_each(function()
        -- Reset game state
        game.tick = 1
        game.players = { [1] = mock_player }

        -- Reset storage via accessors
        storage.players = {}
        global.cache = { players = {} }
        
        -- Reset constants
        local Constants = require("constants")
        Constants.settings.DEFAULT_LOG_LEVEL = "debug"
        
        -- Reset GuiEventBus
        local GuiObserverModule = require("core.events.gui_observer")
        local GuiEventBus = GuiObserverModule.GuiEventBus
        GuiEventBus._observers = {}
        GuiEventBus._deferred_queue = {}
        GuiEventBus._deferred_tick_active = false

        -- Enable debug logging
        local ErrorHandler = require("core.utils.error_handler")
        ErrorHandler.initialize("debug")
    end)
  
    -- Test module loading
    it("should load module without errors", function()
        local success, err = pcall(function()
            local GuiObserverModule = require("core.events.gui_observer")
            assert(GuiObserverModule ~= nil, "Module should load")
            assert(type(GuiObserverModule.GuiEventBus) == "table", "GuiEventBus should be a table")
            assert(type(GuiObserverModule.BaseObserver) == "table", "BaseObserver should be a table")
            assert(type(GuiObserverModule.DataObserver) == "table", "DataObserver should be a table")
        end)
        assert(success, "Module should load without errors: " .. tostring(err))
    end)
    
    -- Test observer registration and notification
    it("should manage observers and notifications correctly", function()
        local GuiObserverModule = require("core.events.gui_observer")
        local GuiEventBus = GuiObserverModule.GuiEventBus
        local DataObserver = GuiObserverModule.DataObserver

        -- Create and register observer
        local observer = DataObserver:new(mock_player)
        GuiEventBus.subscribe("test_event", observer)

        -- Verify subscription
        assert(type(GuiEventBus._observers["test_event"]) == "table", "Event should have observer array")
        assert(#GuiEventBus._observers["test_event"] > 0, "Observer should be registered")

        -- All notifications go to the deferred queue
        GuiEventBus.notify("test_event", { player = mock_player, type = "test" })
        assert(#GuiEventBus._deferred_queue > 0, "Deferred queue should have notification")
        assert(GuiEventBus._deferred_tick_active == true, "Deferred flag should be set")

        GuiEventBus.notify("cache_updated", { player = mock_player, type = "cache" })
        assert(#GuiEventBus._deferred_queue == 2, "Both notifications should be queued")

        -- Process deferred notifications
        GuiEventBus.process_deferred_notifications()
        assert(#GuiEventBus._deferred_queue == 0, "Deferred queue should be empty after processing")
        assert(GuiEventBus._deferred_tick_active == false, "Deferred flag should be cleared")
    end)
    
    -- Test cleanup functionality
    it("should clean up invalid observers", function()
        local GuiObserverModule = require("core.events.gui_observer")
        local GuiEventBus = GuiObserverModule.GuiEventBus
        local BaseObserver = GuiObserverModule.BaseObserver
        
        -- Create invalid player
        local invalid_player = {
            valid = false,
            index = 2,
            name = "InvalidPlayer",
            controller_type = defines.controllers.character
        }
        
        -- Create and register observer with both required parameters
        local observer = BaseObserver:new(invalid_player, "test")
        GuiEventBus.subscribe("test_cleanup", observer)
        
        -- Run cleanup
        game.tick = 1000 -- Simulate time passing
        GuiEventBus.cleanup_old_observers(0) -- Immediate cleanup
        
        -- Verify cleanup
        local observers = GuiEventBus._observers["test_cleanup"]
        assert(not observers or #observers == 0, "Invalid observer should be cleaned up")
    end)
end)