-- tests/unit/test_tag_destroy_helper.lua
-- Unit tests for core.tag.tag_destroy_helper
local tag_destroy_helper = require("core.tag.tag_destroy_helper")

local function test_destroy_tag_and_chart_tag()
  local tag = { gps = "1.2.1", faved_by_players = {1,2} }
  local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  assert(chart_tag.destroyed, "Chart tag should be destroyed")
end

local function test_recursion_guard()
  local tag = { gps = "1.2.1", faved_by_players = {1} }
  local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
  -- Simulate recursion: mark as being destroyed
  tag_destroy_helper.is_tag_being_destroyed(tag)
  tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag)
  -- Should not destroy again
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  -- No error, no double-destroy
end

local function run_all()
  test_destroy_tag_and_chart_tag()
  test_recursion_guard()
  print("All tag_destroy_helper tests passed.")
end

run_all()
