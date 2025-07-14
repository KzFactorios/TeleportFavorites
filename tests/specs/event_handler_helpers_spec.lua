require("test_bootstrap")
require("mocks.factorio_test_env")
require("test_framework")

-- Use centralized factories
local GameSetupFactory = require("mocks.game_setup_factory")

describe("EventHandlerHelpers", function()
  local EventHandlerHelpers

  before_each(function()
    -- Setup test environment with mock player
    GameSetupFactory.setup_test_globals({
      { index = 1, name = "player1", surface_index = 1 }
    })
    
    EventHandlerHelpers = require("core.utils.event_handler_helpers")
  end)

  it("should load event handler helpers without errors", function()
    local success, err = pcall(function()
      assert(type(EventHandlerHelpers) == "table", "EventHandlerHelpers should be a table")
      assert(type(EventHandlerHelpers.with_valid_player) == "function", "with_valid_player should be a function")
      assert(type(EventHandlerHelpers.create_safe_handler) == "function", "create_safe_handler should be a function")
    end)
    assert(success, "EventHandlerHelpers should load without errors: " .. tostring(err))
  end)

  it("should validate player and run handler logic", function()
    local called = false
    local player_result = nil
    
    local success, err = pcall(function()
      EventHandlerHelpers.with_valid_player(1, function(player)
        called = true
        player_result = player
      end)
    end)
    
    assert(success, "with_valid_player should execute without errors: " .. tostring(err))
    assert(called, "Handler should be called for valid player")
    assert(player_result ~= nil, "Player should be passed to handler")
  end)

  it("should handle invalid player gracefully", function()
    local called = false
    
    local success, err = pcall(function()
      EventHandlerHelpers.with_valid_player(999, function(player) -- Invalid player index
        called = true
      end)
    end)
    
    assert(success, "with_valid_player should handle invalid player gracefully: " .. tostring(err))
    assert(not called, "Handler should not be called for invalid player")
  end)

  it("should create safe handler wrapper", function()
    local test_handler = function(event)
      if event.should_error then
        error("Test error")
      end
      return "success"
    end
    
    local success, err = pcall(function()
      local safe_handler = EventHandlerHelpers.create_safe_handler(test_handler, "test_handler", "test")
      
      -- Test successful execution
      safe_handler({ should_error = false })
      
      -- Test error handling (should not throw)
      safe_handler({ should_error = true })
    end)
    
    assert(success, "create_safe_handler should work without errors: " .. tostring(err))
  end)

  it("should log event errors with context", function()
    local success, err = pcall(function()
      EventHandlerHelpers.log_event_error("test_handler", "test error", { player_index = 1 }, "test")
    end)
    
    assert(success, "log_event_error should execute without errors: " .. tostring(err))
  end)

  it("should validate event fields", function()
    local success, err = pcall(function()
      local valid_event = { field1 = "value1", field2 = "value2" }
      local invalid_event = { field1 = "value1" } -- missing field2
      
      local result1 = EventHandlerHelpers.validate_event_fields(valid_event, {"field1", "field2"})
      local result2 = EventHandlerHelpers.validate_event_fields(invalid_event, {"field1", "field2"})
      
      assert(result1 == true, "Valid event should pass validation")
      assert(result2 == false, "Invalid event should fail validation")
    end)
    
    assert(success, "validate_event_fields should execute without errors: " .. tostring(err))
  end)

  it("should create event logger with context", function()
    local success, err = pcall(function()
      local logger = EventHandlerHelpers.create_event_logger("test_handler")
      logger("test message", { player_index = 1 }, { extra = "data" })
    end)
    
    assert(success, "create_event_logger should execute without errors: " .. tostring(err))
  end)
end)
