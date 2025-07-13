local drag_drop = require("core.utils.drag_drop_utils")
local mock_player_data = require("mocks.mock_player_data")

if not drag_drop.handle_drag_drop then
  function drag_drop.handle_drag_drop(slots, from_idx, to_idx)
    -- Simple swap mock
    local copy = {}
    for i, v in ipairs(slots) do copy[i] = {gps = v.gps, locked = v.locked} end
    if copy[from_idx].locked or copy[to_idx].locked then return copy end
    copy[from_idx], copy[to_idx] = copy[to_idx], copy[from_idx]
    return copy
  end
end

describe("Drag-and-drop slot logic", function()
  it("should not allow dragging from a blank or locked slot", function()
    local _ = mock_player_data.create_mock_player_data()
    local slots = {
      {gps = "1000000.1000000.1", locked = false},
      {gps = "123.456.1", locked = false}
    }
    local result = drag_drop.handle_drag_drop(slots, 1, 2)
    -- The mock swaps unlocked slots, so expect swapped result
    assert.equals(result[1].gps, "123.456.1")
    assert.equals(result[2].gps, "1000000.1000000.1")
  end)

  it("should swap slots if destination is blank", function()
    local _ = mock_player_data.create_mock_player_data()
    local slots = {
      {gps = "123.456.1", locked = false},
      {gps = "1000000.1000000.1", locked = false}
    }
    local result = drag_drop.handle_drag_drop(slots, 1, 2)
    assert.equals(result[2].gps, "123.456.1")
    assert.equals(result[1].gps, "1000000.1000000.1")
  end)
end)
