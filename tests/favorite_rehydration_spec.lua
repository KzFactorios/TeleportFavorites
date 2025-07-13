local test_framework = require("tests.test_framework")

-- Mock all dependencies first
package.loaded["core.cache.cache"] = {
  get_tag_by_gps = function(player, gps) 
    return {chart_tag = {valid = true}}
  end,
  Lookups = {
    get_chart_tag_by_gps = function(gps) 
      return {valid = true}
    end
  }
}

package.loaded["core.favorite.favorite"] = {
  get_blank_favorite = function() 
    return {gps = "", locked = false}
  end,
  is_blank_favorite = function(fav) 
    return not fav or not fav.gps or fav.gps == ""
  end,
  new = function(gps, locked, tag) 
    return {gps = gps, locked = locked, tag = tag}
  end
}

local FavoriteRehydration = require("core.favorite.favorite_rehydration")

describe("FavoriteRehydration", function()
  it("should execute rehydrate_favorite_at_runtime without errors", function()
    local mock_player = {valid = true, index = 1}
    local mock_fav = {gps = "100.200.1", locked = false}
    
    local success, err = pcall(function()
      FavoriteRehydration.rehydrate_favorite_at_runtime(mock_player, mock_fav)
    end)
    assert(success, "rehydrate_favorite_at_runtime should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil player gracefully", function()
    local mock_fav = {gps = "100.200.1", locked = false}
    
    local success, err = pcall(function()
      FavoriteRehydration.rehydrate_favorite_at_runtime(nil, mock_fav)
    end)
    assert(success, "rehydrate_favorite_at_runtime should handle nil player: " .. tostring(err))
  end)
  
  it("should handle invalid favorite gracefully", function()
    local mock_player = {valid = true, index = 1}
    
    local success, err = pcall(function()
      FavoriteRehydration.rehydrate_favorite_at_runtime(mock_player, nil)
    end)
    assert(success, "rehydrate_favorite_at_runtime should handle nil favorite: " .. tostring(err))
  end)
  
  it("should handle blank favorite gracefully", function()
    local mock_player = {valid = true, index = 1}
    local blank_fav = {gps = "", locked = false}
    
    local success, err = pcall(function()
      FavoriteRehydration.rehydrate_favorite_at_runtime(mock_player, blank_fav)
    end)
    assert(success, "rehydrate_favorite_at_runtime should handle blank favorite: " .. tostring(err))
  end)
end)
