local Constants = require("constants")

---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

gui_style.te_tr_favorite_label = {
  type = "label_style",
  parent = "label",
  single_line = true,
  horizontally_stretchable = "off",
  vertically_stretchable = "off",
  font = "default-bold",
  minimal_width = 100,
  maximal_width = 100
}

-- Custom slot button style for all TeleportFavorites GUIs
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

-- Inherit from vanilla slot_button, but allow for future tweaks
if not gui_style.tf_slot_button then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.font = "default-bold"
  base.width = 36
  base.height = 36
  base.default_font_color = {r=1, g=1, b=1}
  base.hovered_font_color = {r=1, g=0.9, b=0.5}
  base.clicked_font_color = {r=1, g=0.8, b=0.2}
  base.padding = 0
  base.margin = 0
  gui_style.tf_slot_button = base
end
