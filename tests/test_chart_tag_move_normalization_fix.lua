--[[
tests/test_chart_tag_move_normalization_fix.lua
TeleportFavorites Factorio Mod
-----------------------------
Test to verify that chart tag moves only normalize when necessary and
preserve chart tag references for favorites bar updates.

This test addresses the critical bug where all chart tag moves were
unnecessarily triggering normalization, destroying the original chart tag
and breaking favorites bar updates.

Testing scenario:
1. Create a chart tag at whole number coordinates
2. Move it to another whole number position (should NOT normalize)
3. Verify the original chart tag is preserved and favorites still work
4. Move a tag to fractional coordinates (should normalize)
5. Verify normalization happens and new chart tag is created
]]

-- Test: Chart tag move without normalization
/c
local test_surface = game.player.surface
local player = game.player

-- Create a chart tag at whole number coordinates
local chart_tag = player.force.add_chart_tag(test_surface, {
  position = {x = 100, y = 200},
  text = "Test Move Without Normalization",
  icon = {type = "item", name = "iron-plate"}
})

game.print("Created chart tag at (100, 200)")
game.print("Chart tag ID: " .. tostring(chart_tag.tag_number))

-- Simulate moving it to another whole number position
-- This should NOT trigger normalization since both positions are whole numbers
local mock_event = {
  tag = chart_tag,
  old_position = {x = 100, y = 200},
  player_index = player.index
}

-- Move the chart tag to new position manually (simulating player drag)
chart_tag.position = {x = 150, y = 250}

game.print("Moved chart tag to (150, 250)")
game.print("Chart tag still valid: " .. tostring(chart_tag.valid))
game.print("Chart tag ID after move: " .. tostring(chart_tag.tag_number))

-- Now test the handler
local handlers = require("core.events.handlers")
handlers.on_chart_tag_modified(mock_event)

game.print("Handler completed")
game.print("Chart tag still valid after handler: " .. tostring(chart_tag.valid))
game.print("Chart tag ID after handler: " .. tostring(chart_tag.tag_number))

-- Verify the chart tag wasn't destroyed and recreated
if chart_tag.valid then
  game.print("✅ SUCCESS: Chart tag preserved during normal move")
else
  game.print("❌ FAILURE: Chart tag was destroyed during normal move")
end

-- Test: Chart tag move WITH normalization (fractional coordinates)
/c
local test_surface = game.player.surface
local player = game.player

-- Create a chart tag at fractional coordinates (this will need normalization)
local chart_tag_fractional = player.force.add_chart_tag(test_surface, {
  position = {x = 300.7, y = 400.3},
  text = "Test Move With Normalization",
  icon = {type = "item", name = "copper-plate"}
})

local original_tag_id = chart_tag_fractional.tag_number
game.print("Created chart tag at fractional coordinates (300.7, 400.3)")
game.print("Original chart tag ID: " .. tostring(original_tag_id))

-- Simulate the modification event
local mock_event_fractional = {
  tag = chart_tag_fractional,
  old_position = {x = 300.7, y = 400.3},
  player_index = player.index
}

-- Test the handler with fractional coordinates
local handlers = require("core.events.handlers")
handlers.on_chart_tag_modified(mock_event_fractional)

game.print("Handler completed for fractional coordinates")

-- Check if normalization occurred
local chart_tags = test_surface.find_chart_tags(player.force, {{300, 400}, {302, 402}})
local found_normalized = false
for _, tag in pairs(chart_tags) do
  if tag.text == "Test Move With Normalization" then
    game.print("Found normalized chart tag at: (" .. tag.position.x .. ", " .. tag.position.y .. ")")
    game.print("New chart tag ID: " .. tostring(tag.tag_number))
    if tag.tag_number ~= original_tag_id then
      found_normalized = true
      game.print("✅ SUCCESS: Chart tag was normalized (ID changed)")
    end
    break
  end
end

if not found_normalized then
  game.print("❌ FAILURE: Chart tag normalization did not occur")
end

game.print("=== Test completed ===")
