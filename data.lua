---@diagnostic disable: undefined-global
require("prototypes.styles.init")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")

-- Check if we're in development mode
local dev_marker_path = "__TeleportFavorites__/.dev_mode"
local is_dev_mode = pcall(function() return io.open(dev_marker_path, "r") end)

-- Include developer settings if in dev mode
if is_dev_mode then
  pcall(function() require("settings-dev") end)
end


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
    name = "move_tag_icon",
    filename = "__core__/graphics/icons/mip/move-tag.png",
    width = 32,
    height = 32,
    x = 0,
    y = 0,
    flags = { "gui-icon" }
  },  {
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
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "1",
    key_sequence = "CONTROL + 1",
    consuming = "game-only",
    order = "ca",
    localised_name = {"shortcut-name.teleport-to-favorite", 1},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "2",
    key_sequence = "CONTROL + 2",
    consuming = "game-only",
    order = "cb",
    localised_name = {"shortcut-name.teleport-to-favorite", 2},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "3",
    key_sequence = "CONTROL + 3",
    consuming = "game-only",
    order = "cc",
    localised_name = {"shortcut-name.teleport-to-favorite", 3},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "4",
    key_sequence = "CONTROL + 4",
    consuming = "game-only",
    order = "cd",
    localised_name = {"shortcut-name.teleport-to-favorite", 4},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "5",
    key_sequence = "CONTROL + 5",
    consuming = "game-only",
    order = "ce",
    localised_name = {"shortcut-name.teleport-to-favorite", 5},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "6",
    key_sequence = "CONTROL + 6",
    consuming = "game-only",
    order = "cf",
    localised_name = {"shortcut-name.teleport-to-favorite", 6},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "7",
    key_sequence = "CONTROL + 7",
    consuming = "game-only",
    order = "cg",
    localised_name = {"shortcut-name.teleport-to-favorite", 7},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "8",
    key_sequence = "CONTROL + 8",
    consuming = "game-only",
    order = "ch",
    localised_name = {"shortcut-name.teleport-to-favorite", 8},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "9",
    key_sequence = "CONTROL + 9",
    consuming = "game-only",
    order = "ci",
    localised_name = {"shortcut-name.teleport-to-favorite", 9},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = Enum.EventEnum.TELEPORT_TO_FAVORITE .. "10",
    key_sequence = "CONTROL + 0",
    consuming = "game-only",
    order = "cj",
    localised_name = {"shortcut-name.teleport-to-favorite", 10},
    localised_description = {"shortcut-description.teleport-to-favorite"}
  },  {
    type = "custom-input",
    name = "dv-toggle-data-viewer",
    key_sequence = "CONTROL + F12",
    consuming = "game-only",
    order = "z[data-viewer]",
    localised_name = {"shortcut-name.toggle-data-viewer"},
    localised_description = {"shortcut-description.toggle-data-viewer"}
  },{
    type = "custom-input",
    name = "tf-open-tag-editor",
    key_sequence = "mouse-button-2",
    consuming = "none",
    order = "ba[tag-editor-1]",
    localised_name = {"shortcut-name.open-tag-editor"},
    localised_description = {"shortcut-description.open-tag-editor"}
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
  },  {
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
  
  -- Data viewer and utility shortcuts
  {
    type = "custom-input",
    name = "tf-data-viewer-tab-next",
    key_sequence = "TAB",
    consuming = "none",
    order = "da[data-viewer-1]",
    localised_name = {"shortcut-name.data-viewer-tab-next"},
    localised_description = {"shortcut-description.data-viewer-tab"}
  },
  {
    type = "custom-input",
    name = "tf-data-viewer-tab-prev",
    key_sequence = "SHIFT + TAB",
    consuming = "none",
    order = "da[data-viewer-2]",
    localised_description = {"shortcut-description.data-viewer-tab"},
    localised_name = {"shortcut-name.data-viewer-tab-prev"}
  },
  {
    type = "custom-input",
    name = "tf-undo-last-action",
    key_sequence = "CONTROL + Z",
    consuming = "game-only",
    order = "ea[undo-1]",
    localised_name = {"shortcut-name.undo-last-action"},
    localised_description = {"shortcut-description.undo-last-action"}
  },
}
