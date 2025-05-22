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
