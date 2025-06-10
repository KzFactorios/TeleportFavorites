---@diagnostic disable: undefined-global

-- Centralized enum/table for valid vanilla Factorio utility sprite names.
-- Only add sprite names that are verified to exist in vanilla Factorio.
-- Use is_valid_sprite_path to check validity before adding new entries.

--- **VERY HELPFUL ** https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua

---@class SpriteEnum
---@field ARROW_DOWN string
---@field ARROW_LEFT string
---@field ARROW_RIGHT string
---@field ARROW_UP string
---@field CHECK_MARK string
---@field CLOSE string
---@field CONFIRM string
---@field COPY string
---@field DANGER string
---@field EDIT string
---@field ENTER string
---@field EXPORT string
---@field HEART string
---@field IMPORT string
---@field INFO string
---@field LIST_VIEW string
---@field LOCK string
---@field MOVE string
---@field PIN string
---@field PLAY string
---@field REFRESH string
---@field SEARCH string
---@field SETTINGS string
---@field STAR string
---@field STAR_DISABLED string
---@field TRASH string
---@field WARNING string
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
  STAR = "virtual-signal/signal-star",
  STAR_DISABLED = "tf_star_disabled", 
  TRASH = "utility/trash",
  WARNING = "utility/warning_icon"
}

-- Only add valid sprites to SpriteEnum
for k, v in pairs(SPRITE_ENUM) do
  SpriteEnum[k] = v
end

return SpriteEnum
