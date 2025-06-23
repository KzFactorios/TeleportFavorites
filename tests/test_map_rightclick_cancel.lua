-- Test script for canceling drag operations with right-click on map

-- This test documents the behavior of right-clicking on the map during drag operations.

-- TEST CASES
-- 1. Right-click on GUI elements during drag:
--    - Should cancel drag via gui_event_dispatcher.lua
--    - Uses shared_on_gui_click handler

-- 2. Right-click on map during drag:
--    - Should cancel drag via handlers.on_open_tag_editor_custom_input
--    - The tag editor should not open

-- HOW TO TEST
-- 1. Create some favorites by placing map tags and setting them as favorites
-- 2. Start drag operation by Shift + Left-clicking a favorite slot
-- 3. Try right-clicking on different parts of the screen:
--    a. Right-click on another GUI element
--    b. Right-click on the map view
--    c. Right-click on another favorite slot
-- 4. In all cases, the drag should be canceled and no tag editor should open

-- Implementation check:
-- The right-click on map is handled in handlers.on_open_tag_editor_custom_input
-- It should check for active drag operations and cancel them before opening tag editor
-- Both the GUI right-click handler and map right-click handler should prevent tag editor from opening

-- Additional considerations:
-- - Make sure to test both GUI right-clicks and map right-clicks
-- - After drag cancel, right-clicks should work normally again
-- - Test on multiple map surfaces if applicable

print("Map right-click cancel test loaded")
