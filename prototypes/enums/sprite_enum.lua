---@diagnostic disable: undefined-global

-- Centralized enum/table for valid vanilla Factorio utility sprite names.
-- Only add sprite names that are verified to exist in vanilla Factorio.
-- Use is_valid_sprite_path to check validity before adding new entries.

--- **VERY HELPFUL ** https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua

---@class SpriteEnum: table<string, string>
local SpriteEnum = {}

--- @class SPRITE_ENUM
local SPRITE_ENUM = {
  ARROW_DOWN = "utility/hint_arrow_down",
  ARROW_LEFT = "utility/hint_arrow_left",
  ARROW_RIGHT = "utility/hint_arrow_right",
  ARROW_UP = "utility/hint_arrow_up",
  CHECK_MARK = "utility/check_mark",
  CLOSE = "utility/close",
  CONFIRM = "utility/confirm_slot",
  COPY = "utility/copy",
  DANGER = "utility/danger_icon",
  EDIT = "utility/edit",
  ENTER = "utility/enter",
  EXPORT = "utility/export_slot",
  HEART = "virtual-signal/signal-heart",
  IMPORT = "utility/import_slot",
  INFO = "utility/info",
  LIST_VIEW = "utility/list_view",
  LOCK = "utility/lock",
  MOVE = "move_tag_icon",
  PIN = "utility/pin",
  PLAY = "utility/play",
  REFRESH = "utility/refresh",
  SEARCH = "utility/search_icon",
  SETTINGS = "utility/settings",
  SLOT_BLACK = "slot_black",
  SLOT_BLUE = "slot_blue",
  SLOT_GREEN = "slot_green",
  SLOT_GREY = "slot_grey",
  SLOT_ORANGE = "slot_orange",
  SLOT_ORANGE_20 = "slot_orange_20",
  SLOT_ORANGE_24 = "slot_orange_24",
  SLOT_RED = "slot_red",
  SLOT_WHITE = "slot_white",
  STAR = "virtual-signal/signal-star", -- not working nor was star, there is a star - it might require a search
  STAR_DISABLED = "tf_star_disabled",
  TRASH = "utility/trash",
  WARNING = "utility/warning_icon"
}

-- Only add valid sprites to SpriteEnum
for k, v in pairs(SPRITE_ENUM) do
  SpriteEnum[k] = v
end

return SpriteEnum
