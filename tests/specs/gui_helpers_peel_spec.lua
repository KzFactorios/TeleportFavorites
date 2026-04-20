-- Real GuiHelpers peel (bootstrap mocks gui_helpers; load fresh for this spec only).
package.loaded["core.utils.gui_helpers"] = nil
local GuiHelpers = require("core.utils.gui_helpers")

describe("GuiHelpers.peel_destroy_all_children", function()
  it("removes direct children by repeatedly destroying index 1", function()
    local destroyed = {}
    local ch = {}
    local parent = { valid = true, children = ch }
    local b = {
      valid = true,
      destroy = function()
        destroyed[#destroyed + 1] = "b"
        ch[1] = nil
      end,
    }
    local a = {
      valid = true,
      destroy = function()
        destroyed[#destroyed + 1] = "a"
        ch[1] = b
        ch[2] = nil
      end,
    }
    ch[1] = a
    ch[2] = b

    GuiHelpers.peel_destroy_all_children(parent)
    assert.are.same({ "a", "b" }, destroyed)
  end)
end)
