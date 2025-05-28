-- tests/mocks/mock_helpers.lua
-- Provides a mock for Helpers.create_slot_button and related GUI helpers for test environments

local M = {}

function M.mock_create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local btn = {
    name = name,
    sprite = icon,
    tooltip = tooltip,
    style = opts.style or "tf_slot_button",
    enabled = opts.enabled ~= false,
    is_blank = opts.enabled == false,
    type = "sprite-button",
    children = {},
    add = function(self, child_opts)
      local child = child_opts or {}
      table.insert(self.children, child)
      return child
    end,
    on_click = function() end,
    tags = {},
  }
  if opts.locked then btn.locked = true end
  if parent and parent.children then table.insert(parent.children, btn) end
  return btn
end

return M
