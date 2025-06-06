# Tapered Orange Button Fix

## Issue
The tapered orange buttons were not displaying the arrow/tapered shape on the right side correctly. They were rendering as flat rectangles with colored lines at the top and bottom.

## Solution
The main issue was using incorrect sprite regions for the "right" section of the button. In Factorio's GUI system, the tapered/arrow shape on colored buttons is created by using a special sprite region from the `__core__/graphics/gui.png` file.

### Key Fixes:

1. **Use the correct right section coordinates**: 
   - Changed from `{378, 345}` to `{393, 0}`
   - This is the region used by vanilla confirm buttons for their taper/arrow

2. **Use the proper structure**:
   - Changed from using `arrow` to using `right` in the graphical_set
   - Set width to 14px and height to 36px to match the vanilla buttons

3. **Use correct base states**:
   - Default: position {0, 60}
   - Hovered: position {0, 96}
   - Clicked: position {0, 132}

4. **Ensure correct shadow position**:
   - All shadow positions should be {240, 24}

## Tapered Button Structure
For a button to have the tapered/arrow shape, it needs this structure in its graphical_set:

```lua
default_graphical_set = {
  base = {
    filename = "__core__/graphics/gui.png",
    position = {0, 60}, -- Regular button base
    corner_size = 8,
    tint = {r = 0.98, g = 0.66, b = 0.22, a = 1.0} -- Desired tint
  },
  shadow = {
    filename = "__core__/graphics/gui.png",
    position = {240, 24}, -- Fixed shadow position
    corner_size = 8,
    draw_type = "outer"
  },
  right = {
    filename = "__core__/graphics/gui.png",
    position = {393, 0}, -- Colored button right section
    width = 14,
    height = 36,
    tint = {r = 0.98, g = 0.66, b = 0.22, a = 1.0} -- Same tint as base
  }
}
```

## Using Custom Sprites
When using a custom sprite for the right section:

1. Make sure the image has the correct dimensions (should be exactly 14×36 pixels)
2. Register the sprite in data.lua
3. Reference the sprite correctly in the style definition
4. Use `width` and `height` instead of `size` when defining the sprite region

## Testing
To check if the buttons are working as expected:

1. Open the game and click on "Test Colored Buttons" in the top bar
2. Compare all the orange button styles to see if they display the arrow/tapered shape correctly
3. Check if the button stretches correctly without distorting the taper/arrow

## Vanilla Button Reference
The vanilla colored confirm buttons use these graphical_set values:
- Base for green button: gui.png {0, 60} with green tint
- Right section: gui.png {393, 0} with matching tint
- Shadow: gui.png {240, 24}

Different tints create different colored buttons with the same tapered shape.
