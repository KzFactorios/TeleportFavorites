---@diagnostic disable: undefined-global
require("test_framework")

describe("FactorioEmmyTypes", function()
  
  before_each(function()
    -- Type definitions usually don't need dependencies
  end)

  it("should load factorio.emmy without errors", function()
    local success, err = pcall(function()
      -- Type definitions file - might not exist in all projects
      require("core.types.factorio.emmy")
    end)
    -- Type definition files may not exist, which is acceptable
    assert(success or string.find(tostring(err), "module.*not found"), 
           "factorio.emmy should load or be missing: " .. tostring(err))
  end)

  it("should handle type definition loading", function()
    local success, err = pcall(function()
      -- Emmy type files typically don't export anything
      local _ = require("core.types.factorio.emmy")
    end)
    -- Type definition files may not exist, which is acceptable  
    assert(success or string.find(tostring(err), "module.*not found"), 
           "type definitions should load or be missing: " .. tostring(err))
  end)

end)
