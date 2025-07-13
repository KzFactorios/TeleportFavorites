local test_framework = require("tests.test_framework")

-- Mock chart tag spec builder (no dependencies to avoid circular imports)
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")

describe("ChartTagSpecBuilder", function()
  it("should execute build without errors", function()
    local mock_position = {x = 100, y = 200}
    local mock_chart_tag = {
      text = "test tag",
      last_user = {name = "player1"}
    }
    local mock_player = {valid = true, name = "player1"}
    
    local success, err = pcall(function()
      ChartTagSpecBuilder.build(mock_position, mock_chart_tag, mock_player, "custom text", true)
    end)
    assert(success, "build should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil source_chart_tag gracefully", function()
    local mock_position = {x = 100, y = 200}
    local mock_player = {valid = true, name = "player1"}
    
    local success, err = pcall(function()
      ChartTagSpecBuilder.build(mock_position, nil, mock_player, "custom text", true)
    end)
    assert(success, "build should handle nil source_chart_tag: " .. tostring(err))
  end)
  
  it("should handle nil player gracefully", function()
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagSpecBuilder.build(mock_position, nil, nil, "custom text", false)
    end)
    assert(success, "build should handle nil player: " .. tostring(err))
  end)
  
  it("should handle minimal parameters gracefully", function()
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagSpecBuilder.build(mock_position)
    end)
    assert(success, "build should handle minimal parameters: " .. tostring(err))
  end)
  
  it("should handle invalid chart_tag data gracefully", function()
    local mock_position = {x = 100, y = 200}
    local invalid_chart_tag = "invalid"
    
    local success, err = pcall(function()
      ChartTagSpecBuilder.build(mock_position, invalid_chart_tag, nil, nil, false)
    end)
    assert(success, "build should handle invalid chart_tag: " .. tostring(err))
  end)
end)
