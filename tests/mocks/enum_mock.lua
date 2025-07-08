-- tests/mocks/enum_mock.lua
-- Minimal Enum mock for test bootstrap
local Enum = {}
Enum.EventEnum = {
  TELEPORT_TO_FAVORITE = "teleport_to_favorite-",
  ADD_TAG_INPUT = "add-tag-input",
  ON_OPEN_TAG_EDITOR = "on_open_tag_editor",
  CACHE_DUMP = "cache_dump"
}
return Enum
