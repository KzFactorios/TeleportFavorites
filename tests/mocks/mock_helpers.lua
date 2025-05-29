-- tests/mocks/mock_helpers.lua
-- Provides a mock for Helpers.create_slot_button and related GUI helpers for test environments

local M = {}

function M.mock_create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local style = opts.style
  if type(style) == "string" then
    style = { style_name = style }
  elseif type(style) ~= "table" or style == nil then
    style = {}
  end
  local btn = {
    name = name,
    sprite = icon,
    tooltip = tooltip,
    style = style,
    enabled = opts.enabled ~= false,
    is_blank = opts.enabled == false,
    type = "sprite-button",
    children = {},
    parent = parent,
    add = function(self, child_opts)
      local child = child_opts or {}
      child.parent = self
      table.insert(self.children, child)
      return child
    end,
    destroy = function(self)
      if self.parent and type(self.parent.children) == "table" then
        for i = #self.parent.children, 1, -1 do
          if self.parent.children[i] == self then
            table.remove(self.parent.children, i)
            break
          end
        end
      end
      self.children = {}
    end,
    on_click = function() end,
    tags = {},
  }
  if opts.locked then btn.locked = true end
  -- Add to parent's children array if possible
  if type(parent) == "table" and type(parent.children) == "table" then
    local already = false
    for _, c in ipairs(parent.children) do
      if c == btn then already = true break end
    end
    if not already then table.insert(parent.children, btn) end
  end
  return btn
end

return M
