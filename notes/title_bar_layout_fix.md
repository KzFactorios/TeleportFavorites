# Title Bar Layout Fix

## Summary
Modified the `tf_frame_title` and `tf_titlebar_draggable` styles to improve horizontal space usage in title bars throughout the TeleportFavorites mod.

## Problem
The previous title bar layout had both the title label and draggable space set to stretch horizontally, which could lead to poor space utilization where the title didn't use available space effectively and the draggable area was either too large or too small.

## Solution
Updated the styles in `prototypes/styles.lua`:

### tf_frame_title Style Changes
- Added `width = 0` to allow natural expansion to text width
- Added `maximal_width = 9999` to let it take all available space for long titles  
- Added `single_line = true` to ensure titles don't wrap
- Added `horizontal_align = "left"` for proper text alignment

### tf_titlebar_draggable Style Changes
- Added `minimal_width = 24` to ensure there's always some draggable space
- Added `width = 0` to make it fill only remaining space after title

## Expected Behavior
1. Title labels now use as much horizontal space as needed to display their text fully
2. Draggable space fills the remaining gap between title and close button
3. There's always at least 24px of draggable space available
4. Long titles can expand to use most of the available width

## Files Modified
- `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\prototypes\styles.lua`

## Testing
The changes affect all GUIs that use the shared titlebar creation function in `gui/gui_base.lua`, including:
- Tag Editor
- Data Viewer
- Any future dialogs using `GuiBase.create_titlebar()`

## Date
June 10, 2025
