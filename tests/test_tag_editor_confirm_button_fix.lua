-- test_tag_editor_confirm_button_fix.lua
-- Test to verify that the tag editor confirm button is properly handled

local test_name = "tag_editor_confirm_button_fix"

local Cache = require("core.cache.cache")
local tag_editor = require("gui.tag_editor.tag_editor")
local control_tag_editor = require("core.control.control_tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local Enum = require("prototypes.enums.enum")

local function run_test()
  game.print("🧪 [" .. test_name .. "] Starting test...")
  
  local player = game.get_player(1)
  if not player or not player.valid then
    game.print("❌ [" .. test_name .. "] Player 1 not found")
    return
  end
  
  -- Create test tag data
  local test_gps = "[gps=0,0,nauvis]"
  local tag_data = Cache.create_tag_editor_data({
    gps = test_gps,
    text = "Test Tag",
    icon = nil,
    is_favorite = false
  })
  
  -- Set the tag editor data
  Cache.set_tag_editor_data(player, tag_data)
  
  -- Build the tag editor
  tag_editor.build(player)
  
  -- Check if the tag editor frame exists
  local tag_editor_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if not tag_editor_frame then
    game.print("❌ [" .. test_name .. "] Tag editor frame not found")
    return
  end
  
  -- Check if the confirm button exists with the correct name
  local confirm_btn = GuiValidation.find_child_by_name(tag_editor_frame, "tag_editor_confirm_button")
  if not confirm_btn then
    game.print("❌ [" .. test_name .. "] Confirm button with correct name 'tag_editor_confirm_button' not found")
    return
  end
  
  -- Check if the confirm button is enabled (should be since we have text)
  if not confirm_btn.enabled then
    game.print("❌ [" .. test_name .. "] Confirm button should be enabled with text content")
    return
  end
  
  game.print("✅ [" .. test_name .. "] Confirm button found with correct name and enabled state")
  
  -- Clean up
  control_tag_editor.close_tag_editor(player)
  
  game.print("✅ [" .. test_name .. "] Test completed successfully!")
end

-- Register the test command
commands.add_command("test_confirm_fix", "Test tag editor confirm button fix", function(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then
    run_test()
  end
end)

game.print("📋 Test loaded: " .. test_name .. " - Use /test_confirm_fix to run")
