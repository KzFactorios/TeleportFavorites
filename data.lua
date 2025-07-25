---@diagnostic disable: undefined-global

-- data.lua
-- TeleportFavorites Factorio Mod
-- Data stage definitions for custom fonts, sprites, and input events.
-- Registers all mod assets and custom inputs for use in runtime scripts and GUIs.
-- Integrates with prototypes/styles, item, input, and enums modules for centralized asset management.
--
-- API:
--   Defines custom fonts, sprites, and input events for use in GUIs and mod logic.
--   Uses Enum.EventEnum for custom input event names.

require("prototypes.styles.init")
require("prototypes.item.selection_tool")
require("prototypes.input.teleport_history_inputs")
local Enum = require("prototypes.enums.enum")

---@diagnostic disable-next-line: undefined-global, param-type-mismatch, missing-parameter, duplicate-set-field
data:extend({
  {
    type = "font",
    name = "custom-tiny-font",
    from = "default",
    size = 8,
    border = false
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
    name = "move_tag_icon",
    filename = "__core__/graphics/icons/mip/move-tag.png",
    width = 32,
    height = 32,
    x = 0,
    y = 0,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_star_disabled",
    filename = "__TeleportFavorites__/graphics/dark-star.png",
    width = 64,
    height = 64,
    x = 0,
    y = 0,
    scale = .5,
    tint = { r = 1, g = .64, b = 0, a = 1.0 },
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_hint_arrow_right",
    filename = "__core__/graphics/gui-new.png",
    priority = "extra-high-no-scale",
    x = 458,
    y = 441,
    width = 24,
    height = 32,
    scale = 0.5,
    flags = { "icon" }
  },
  {
    type = "sprite",
    name = "tf_hint_arrow_left",
    filename = "__core__/graphics/gui-new.png",
    priority = "extra-high-no-scale",
    x = 433,
    y = 441,
    width = 24,
    height = 32,
    scale = 0.5,
    flags = { "icon" }
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "1",
    key_sequence = "CONTROL + 1",
    consuming = "game-only",
    order = "ca"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "2",
    key_sequence = "CONTROL + 2",
    consuming = "game-only",
    order = "cb"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "3",
    key_sequence = "CONTROL + 3",
    consuming = "game-only",
    order = "cc"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "4",
    key_sequence = "CONTROL + 4",
    consuming = "game-only",
    order = "cd"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "5",
    key_sequence = "CONTROL + 5",
    consuming = "game-only",
    order = "ce"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "6",
    key_sequence = "CONTROL + 6",
    consuming = "game-only",
    order = "cf"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "7",
    key_sequence = "CONTROL + 7",
    consuming = "game-only",
    order = "cg"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "8",
    key_sequence = "CONTROL + 8",
    consuming = "game-only",
    order = "ch"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "9",
    key_sequence = "CONTROL + 9",
    consuming = "game-only",
    order = "ci"
  },
  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "10",
    key_sequence = "CONTROL + 0",
    consuming = "game-only",
    order = "cj"
  },
  {
    type = "custom-input",
    name = "tf-open-tag-editor",
    key_sequence = "mouse-button-2",
    consuming = "none",
    order = "ba[tag-editor-1]"
  },
  {
    type = "sprite",
    name = "logo_36",
    filename = "__TeleportFavorites__/graphics/logo_36.png",
    width = 36,
    height = 36,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "logo_144",
    filename = "__TeleportFavorites__/graphics/logo_144.png",
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
    name = "tf_font_7",
    from = "default",
    size = 7
  },
  {
    type = "font",
    name = "tf_font_8",
    from = "default",
    size = 8
  },
  {
    type = "font",
    name = "tf_font_9",
    from = "default",
    size = 9
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
    type = "sprite",
    name = "tf_tag_in_map_view",
    filename = "__TeleportFavorites__/graphics/square-custom-tag-in-map-view.png",
    width = 32,
    height = 32,
    scale = 0.25,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_tag_in_map_view_small",
    filename = "__TeleportFavorites__/graphics/square-custom-tag-in-map-view-small.png",
    width = 16,
    height = 16,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_slot_lock",
    filename = "__TeleportFavorites__/graphics/icons8-lock-a50.png",
    width = 24,
    height = 24,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_eye",
    filename = "__TeleportFavorites__/graphics/icons8-eye-50.png",
    width = 75,
    height = 75,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_eyelash",
    filename = "__TeleportFavorites__/graphics/icons8-eyelash-50.png",
    width = 75,
    height = 75,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_scroll_history",
    filename = "__TeleportFavorites__/graphics/icons8-history-50.png",
    width = 50,
    height = 50,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_pin_tilt_white",
    filename = "__TeleportFavorites__/graphics/tf_pin_tilt_white.png",
    width = 32,
    height = 32,
    flags = { "gui-icon" }
  },
  {
    type = "sprite",
    name = "tf_pin_tilt_black",
    filename = "__TeleportFavorites__/graphics/tf_pin_tilt_black.png",
    width = 32,
    height = 32,
    flags = { "gui-icon" }
  },
})