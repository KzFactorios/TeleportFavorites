-- tests/mocks/spy_utils.lua
-- Table-based spy utility for robust function call tracking in tests

local function make_spy(target_table, method_name)
  if type(target_table) ~= "table" then
    error("make_spy: target_table must be a table, got " .. tostring(target_table))
  end
  local orig = target_table[method_name]
  if type(orig) ~= "function" then
    error("make_spy: method '" .. tostring(method_name) .. "' must exist and be a function on the target table")
  end
  local spy_tbl = {
    calls = {},
    call_count = function(self)
      return #self.calls
    end,
    was_called = function(self)
      return #self.calls > 0
    end,
    reset = function(self)
      self.calls = {}
    end,
    revert = function(self)
      if self._original then
        target_table[method_name] = self._original
      end
    end
  }
  spy_tbl._original = orig
  target_table[method_name] = function(...)
    table.insert(spy_tbl.calls, {...})
    return spy_tbl._original(...)
  end
  target_table[method_name .. "_spy"] = spy_tbl
  return spy_tbl
end

return {
  make_spy = make_spy
}
