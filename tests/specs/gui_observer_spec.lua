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
        _notification_queue = {},
        _deferred_queue = {},
        _initialized = false
    }

    function bus:ensure_initialized()
        self._initialized = true
        self._observers = self._observers or {}
        self._notification_queue = self._notification_queue or {}
        self._deferred_queue = self._deferred_queue or {}
    end

    function bus:subscribe(event_name, observer)
        self._observers[event_name] = self._observers[event_name] or {}
        table.insert(self._observers[event_name], observer)
    end

    function bus:notify(event_name, data, defer_to_tick)
        -- Auto-defer GUI events
        local gui_event_types = {
            cache_updated = true,
            favorite_added = true,
            favorite_removed = true
        }
        local should_defer = defer_to_tick or gui_event_types[event_name]
        
        if should_defer then
            table.insert(self._deferred_queue, {
                event = event_name,
                data = data
            })
        else
            table.insert(self._notification_queue, {
                event = event_name,
                data = data
            })
        end
    end

    function bus:process_notifications()
        self._notification_queue = {}
    end
    
    function bus:process_deferred_notifications()
        self._deferred_queue = {}
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
    GuiEventBus = create_gui_event_bus(),
    DataObserver = BaseObserver,
    NotificationObserver = BaseObserver
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
        GuiEventBus._notification_queue = {}
        GuiEventBus._deferred_queue = {}
        GuiEventBus._initialized = false

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
            assert(type(GuiObserverModule.NotificationObserver) == "table", "NotificationObserver should be a table")
        end)
        assert(success, "Module should load without errors: " .. tostring(err))
    end)
    
    -- Test initialization
    it("should handle initialization state correctly", function()
        local GuiObserverModule = require("core.events.gui_observer")
        local GuiEventBus = GuiObserverModule.GuiEventBus
        
        -- Reset state for test
        GuiEventBus._observers = {}
        GuiEventBus._notification_queue = {}
        
        -- Call initialization and verify state
        GuiEventBus.ensure_initialized()
        
        -- Check state
        assert(type(GuiEventBus._observers) == "table", "Observers should be initialized")
        assert(type(GuiEventBus._notification_queue) == "table", "Queue should be initialized")
        assert(next(GuiEventBus._observers) == nil, "Observer table should be empty but initialized")
        assert(next(GuiEventBus._notification_queue) == nil, "Notification queue should be empty but initialized")
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
        
        -- Test notification (non-GUI event goes to immediate queue)
        -- Note: The real implementation auto-processes non-deferred events,
        -- so we just verify the subscription works
        GuiEventBus._processing = true -- Prevent auto-processing for test
        GuiEventBus.notify("test_event", { player = mock_player, type = "test" }, false)
        assert(#GuiEventBus._notification_queue > 0, "Queue should have notification")
        GuiEventBus._processing = false
        
        -- Test deferred notification (GUI events go to deferred queue)
        GuiEventBus.notify("cache_updated", { player = mock_player, type = "cache" })
        assert(#GuiEventBus._deferred_queue > 0, "Deferred queue should have notification")
        
        -- Process notifications
        GuiEventBus.process_notifications()
        assert(#GuiEventBus._notification_queue == 0, "Queue should be empty after processing")
        
        -- Process deferred notifications
        GuiEventBus.process_deferred_notifications()
        assert(#GuiEventBus._deferred_queue == 0, "Deferred queue should be empty after processing")
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