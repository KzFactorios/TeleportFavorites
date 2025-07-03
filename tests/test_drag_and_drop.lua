local drag_drop = require("core.utils.drag_drop_utils") -- adjust path as needed

describe("Drag-and-drop slot logic", function()
  it("should not allow dragging from a blank or locked slot", function()
    local slots = {
      {gps = "1000000.1000000.1", locked = false},
      {gps = "123.456.1", locked = false}
    }
    local result = drag_drop.handle_drag_drop(slots, 1, 2)
    assert.same(result, slots)
  end)

  it("should swap slots if destination is blank", function()
    local slots = {
      {gps = "123.456.1", locked = false},
      {gps = "1000000.1000000.1", locked = false}
    }
    local result = drag_drop.handle_drag_drop(slots, 1, 2)
    assert.equals(result[2].gps, "123.456.1")
    assert.equals(result[1].gps, "1000000.1000000.1")
  end)
end)
