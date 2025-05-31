---@diagnostic disable: undefined-global
local Constants = require("constants")
require("prototypes.styles")
local Style = require("gui.styles")


if data then
  -- Ensure the custom virtual signal subgroup exists
  if not data.raw["item-subgroup"]["virtual-signal-special"] then
    data:extend({
      {
        type = "item-subgroup",
        name = "virtual-signal-special",
        group = "signals",
        order = "z"
      }
    })
  end
end

---@diagnostic disable-next-line: undefined-global
data:extend {
  {
    type = "font",
    name = "custom-tiny-font",
    from = "default",
    size = 8,      -- Adjust this size to be smaller than default-tiny
    border = false -- Set to true if you want better readability with a border
  },
  {
    type = "font",
    name = "super_large_font",
    from = "default-bold",
    size = 64,
    border = true
  },
  {
    type = "sprite",
    name = "default-map-tag",
    filename = "__TeleportFavorites__/graphics/map_tag_default.png",
    priority = "extra-high",
    size = { 24, 36 },
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "move_tag_icon",
    filename = "__core__/graphics/icons/mip/move-tag.png",
    width = 24,
    height = 24,
    x = 0,
    y = 0,
    flags = { "icon" }
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "1",
    key_sequence = "CONTROL + 1",
    consuming = "game-only",
    order = "ca"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "2",
    key_sequence = "CONTROL + 2",
    consuming = "game-only",
    order = "cb"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "3",
    key_sequence = "CONTROL + 3",
    consuming = "game-only",
    order = "cc"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "4",
    key_sequence = "CONTROL + 4",
    consuming = "game-only",
    order = "cd"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "5",
    key_sequence = "CONTROL + 5",
    consuming = "game-only",
    order = "ce"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "6",
    key_sequence = "CONTROL + 6",
    consuming = "game-only",
    order = "cf"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "7",
    key_sequence = "CONTROL + 7",
    consuming = "game-only",
    order = "cg"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "8",
    key_sequence = "CONTROL + 8",
    consuming = "game-only",
    order = "ch"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "9",
    key_sequence = "CONTROL + 9",
    consuming = "game-only",
    order = "ci"
  },
  {
    type = "custom-input",
    name = Constants.enums.events.TELEPORT_TO_FAVORITE .. "10",
    key_sequence = "CONTROL + 0",
    consuming = "game-only",
    order = "cj"
  },
  {
    type = "custom-input",
    name = "dv-toggle-data-viewer",
    key_sequence = "CONTROL + F12",
    consuming = "game-only",
    order = "z[data-viewer]"
  },
  {
    type = "custom-input",
    name = "tf-open-tag-editor",
    key_sequence = "mouse-button-2",
    consuming = "none"
  },
  {
    type = "sprite",
    name = "slot_black",
    filename = "__TeleportFavorites__/graphics/slot_black.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_blue",
    filename = "__TeleportFavorites__/graphics/slot_blue.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_green",
    filename = "__TeleportFavorites__/graphics/slot_green.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_grey",
    filename = "__TeleportFavorites__/graphics/slot_grey.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_orange",
    filename = "__TeleportFavorites__/graphics/slot_orange.png",
    priority = "extra-high-no-scale",
    width = 36,
    height = 36,
    scale = 1,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_red",
    filename = "__TeleportFavorites__/graphics/slot_red.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "slot_white",
    filename = "__TeleportFavorites__/graphics/slot_white.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "logo_36",
    filename = "__TeleportFavorites__/graphics/prelim_logo_36.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "logo_144",
    filename = "__TeleportFavorites__/graphics/prelim_logo_144.png",
    width = 144,
    height = 144,
    flags = { "gui-icon" }
  },
  {
    type = "font",
    name = "tf_font_6",
    from = "default",
    size = 6
  },
  {
    type = "font",
    name = "tf_font_8",
    from = "default",
    size = 8
  },
  {
    type = "font",
    name = "tf_font_10",
    from = "default",
    size = 10
  },
  {
    type = "font",
    name = "tf_font_12",
    from = "default",
    size = 12
  },
  {
    type = "font",
    name = "tf_font_14",
    from = "default",
    size = 14
  },
  {
    type = "font",
    name = "tf_font_16",
    from = "default",
    size = 16
  },
  {
    type = "font",
    name = "tf_font_18",
    from = "default",
    size = 18
  },
  {
    type = "font",
    name = "tf_font_20",
    from = "default",
    size = 20
  },
  {
    type = "font",
    name = "tf_font_22",
    from = "default",
    size = 22
  },
  {
    type = "font",
    name = "tf_font_24",
    from = "default",
    size = 24
  },
  {
    type = "custom-input",
    name = "tf-data-viewer-tab-next",
    key_sequence = "TAB",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "tf-data-viewer-tab-prev",
    key_sequence = "SHIFT + TAB",
    consuming = "none"
  }
}
