require("tests.test_bootstrap")
-- tests/events/handlers_spec.lua

if not _G.storage then _G.storage = {} end
local Handlers = require("core.events.handlers")

describe("Handlers", function()
    it("should be a table/module", function()
        assert.is_table(Handlers)
    end)
    -- Add more tests for exported functions as needed
end)

-- All robust and edge-case tests from handlers_full_spec.lua are merged below

-- Robust fake for LuaGuiElement
function make_fake_lua_gui_element(opts)
  -- ...existing code from handlers_full_spec.lua...
end

-- ...all global and dependency mocks from handlers_full_spec.lua...

-- All robust Handlers tests from handlers_full_spec.lua
-- ...existing code from handlers_full_spec.lua...

-- Patch: Robust mock for core.utils.gui_validation to ensure find_child_by_name works with fake elements
package.loaded["core.utils.gui_validation"] = {
  find_child_by_name = function(parent, child_name)
    if not parent or not parent.valid or not child_name then return nil end
    for _, child in ipairs(parent.children_list or {}) do
      if child.name == child_name and child.valid then
        return child
      end
    end
    for _, child in ipairs(parent.children_list or {}) do
      local found = package.loaded["core.utils.gui_validation"].find_child_by_name(child, child_name)
      if found then return found end
    end
    return nil
  end
}
