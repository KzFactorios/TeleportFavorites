-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\docs\protection_area_customization.md

# Protection Area Customization Guide

## How Easy is it to Adjust the Protection Area?

**VERY EASY!** The protection area size is controlled by a single function with just one calculation. Here's how to customize it:

## Current Implementation (3x3)
```lua
function ChartTagUtils.calculate_protected_area(position)
  if not position then return nil end
  
  -- 3x3 area centered on the position (1 tile in each direction)
  return {
    left_top = { x = math.floor(position.x) - 1, y = math.floor(position.y) - 1 },
    right_bottom = { x = math.floor(position.x) + 1, y = math.floor(position.y) + 1 }
  }
end
```

## Other Common Sizes

### 1x1 (Chart tag tile only)
```lua
-- 1x1 area - just the chart tag tile itself
return {
  left_top = { x = math.floor(position.x), y = math.floor(position.y) },
  right_bottom = { x = math.floor(position.x), y = math.floor(position.y) }
}
```

### 5x5 (Larger protection)
```lua
-- 5x5 area centered on the position (2 tiles in each direction)
return {
  left_top = { x = math.floor(position.x) - 2, y = math.floor(position.y) - 2 },
  right_bottom = { x = math.floor(position.x) + 2, y = math.floor(position.y) + 2 }
}
```

### 7x7 (Very large protection)
```lua
-- 7x7 area centered on the position (3 tiles in each direction)
return {
  left_top = { x = math.floor(position.x) - 3, y = math.floor(position.y) - 3 },
  right_bottom = { x = math.floor(position.x) + 3, y = math.floor(position.y) + 3 }
}
```

## Visual Representation

### 3x3 Protection (Current)
```
[ ][ ][ ]
[ ][T][ ]  T = Chart Tag
[ ][ ][ ]
```

### 5x5 Protection
```
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
[ ][ ][T][ ][ ]  T = Chart Tag
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
```

## Making it Configurable

For advanced users, you could make this configurable by adding a setting:

```lua
-- Get protection radius from mod settings (default: 1 for 3x3)
local protection_radius = settings.global["tf-protection-radius"].value or 1

function ChartTagUtils.calculate_protected_area(position)
  if not position then return nil end
  
  return {
    left_top = { x = math.floor(position.x) - protection_radius, y = math.floor(position.y) - protection_radius },
    right_bottom = { x = math.floor(position.x) + protection_radius, y = math.floor(position.y) + protection_radius }
  }
end
```

## Notes

- **Performance**: Larger protection areas will check more tiles, but the performance impact is minimal
- **Balance**: Smaller areas (1x1, 3x3) are less intrusive to players but offer minimal protection
- **Usability**: Larger areas (5x5, 7x7) provide stronger protection but may interfere with normal construction
- **Recommendation**: 3x3 strikes the best balance between protection and usability
