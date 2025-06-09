
-- Centralized enum/table for valid vanilla Factorio utility sprite names.
-- Only add sprite names that are verified to exist in vanilla Factorio.
-- Use is_valid_sprite_path to check validity before adding new entries.

--- **VERY HELPFUL ** https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua

-- Sprite path formatter (moved from helpers_suite)
local function format_sprite_path(type_or_icon, name, is_signal)
  local icon = name and tostring(name) or tostring(type_or_icon)
  if icon:find("/") then
    return icon
  elseif icon:match("^utility%.") then
    return icon:gsub("^utility%.", "utility/")
  elseif icon:match("^item%.") then
    local item_name = icon:match("^item%.(.+)$")
    return item_name or icon
  elseif icon:match("^virtual%-signal%.") then
    return icon:gsub("^virtual%-signal%.", "virtual-signal/")
  else
    return icon
  end
end

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
  SLOT_RED = "slot_red",
  SLOT_WHITE = "slot_white",
  STAR = "virtual-signal/signal-star", -- not working nor was star, there is a star - it might require a search
  TRASH = "utility/trash",
  WARNING = "utility/warning_icon"
}

local is_valid_sprite = rawget(_G, "is_valid_sprite_path") or function() return true end

local SpriteEnum = {}
for k, v in pairs(SPRITE_ENUM) do
  if is_valid_sprite(v) then
    SpriteEnum[k] = v
  end
end

SpriteEnum.format_sprite_path = format_sprite_path

return SpriteEnum
