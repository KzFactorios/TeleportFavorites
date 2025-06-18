# Chart Tag Position Collision Prevention System - Complete Implementation

## Overview

The TeleportFavorites mod now includes a comprehensive chart tag position collision detection and prevention system to ensure that only one chart tag can exist per GPS position, maintaining cache consistency and preventing conflicts in tag management.

## Problem Addressed

Previously, the mod had **no enforcement preventing multiple chart tags from occupying the same GPS position**, which could lead to:

1. **Cache inconsistencies** - the GPS-based lookup cache assumes one chart tag per GPS
2. **Tag management conflicts** - multiple chart tags at same position could confuse the system  
3. **Duplicate chart tag creation** - the system might create multiple chart tags at identical positions
4. **Data corruption** - overlapping chart tags could break the one-to-one GPS-to-chart-tag mapping

## Implementation

### Core Components

#### 1. Chart Tag Collision Detector (`core/utils/chart_tag_collision_detector.lua`)

**Key Features:**
- Position collision detection before chart tag creation
- Automatic cleanup of duplicate chart tags at same position
- Integration with cache invalidation system
- Comprehensive logging for debugging

**Main Functions:**
```lua
-- Check if a chart tag already exists at GPS position
ChartTagCollisionDetector.check_position_collision(gps, exclude_chart_tag)

-- Find all chart tags at the same position
ChartTagCollisionDetector.find_colliding_chart_tags(chart_tag)

-- Resolve collisions by removing duplicates
ChartTagCollisionDetector.resolve_position_collision(chart_tag, player)

-- Clean up all duplicate chart tags on a surface
ChartTagCollisionDetector.cleanup_surface_collisions(surface_index, player)

-- Safe creation with collision prevention
ChartTagCollisionDetector.safe_create_chart_tag_with_collision_check(force, surface, spec, player)
```

#### 2. Enhanced Chart Tag Creation (`core/utils/chart_tag_utils.lua`)

**Updated `safe_add_chart_tag` Function:**
- Added collision detection before creation
- Player notification for collision prevention
- Automatic collision resolution after creation (belt and suspenders)
- Updated function signature to include optional `player` parameter

**Before:**
```lua
function ChartTagUtils.safe_add_chart_tag(force, surface, spec)
```

**After:**
```lua
function ChartTagUtils.safe_add_chart_tag(force, surface, spec, player)
  -- Position collision check before creation
  local existing_chart_tag, has_collision = ChartTagCollisionDetector.check_position_collision(gps)
  
  if has_collision and existing_chart_tag then
    -- Notify player and prevent creation
    return nil
  end
  
  -- Proceed with creation and resolve any remaining collisions
end
```

#### 3. Diagnostic Commands (`core/control/control_collision_diagnostics.lua`)

**Available Commands:**
- `/tf-check-collisions` - Scan for chart tag position collisions on current surface
- `/tf-fix-collisions` - Automatically resolve detected collisions on current surface  
- `/tf-collision-report` - Generate detailed collision report for current surface
- `/tf-global-collision-check` - Check all surfaces for collisions (admin command)

**Features:**
- Player-friendly output with clear messaging
- Detailed collision reports showing affected positions
- Automatic resolution with confirmation messages
- Admin tools for server-wide collision management

#### 4. Comprehensive Test Suite (`tests/test_chart_tag_collision_detection.lua`)

**Test Cases:**
1. **Collision Prevention Test** - Verifies collision detection prevents duplicate creation
2. **Collision Resolution Test** - Tests cleanup of manually created duplicates  
3. **Surface Cleanup Test** - Validates surface-wide collision removal
4. **Tag Editor Integration Test** - Ensures collision prevention works in tag editor workflow

### Integration Points

#### Updated Function Calls

All calls to `ChartTagUtils.safe_add_chart_tag` have been updated to include the `player` parameter:

**Files Updated:**
- `core/control/control_tag_editor.lua` - Tag editor chart tag creation
- `core/tag/tag.lua` - Tag rehoming operations
- `core/events/handlers.lua` - Event-driven chart tag operations (3 locations)
- `core/tag/tag_sync.lua` - Tag synchronization operations
- `core/tag/tag_terrain_manager.lua` - Terrain-based relocations
- `core/tag/tag_terrain_watcher.lua` - Terrain monitoring (no player context)

#### Command Registration

Collision diagnostic commands are automatically registered in `control.lua` during mod initialization:

```lua
local function custom_on_init()
  handlers.on_init()
  -- Register collision diagnostic commands
  control_collision_diagnostics.register_commands()
end
```

## Benefits

### 1. **Data Integrity**
- Ensures one-to-one mapping between GPS positions and chart tags
- Prevents cache corruption from overlapping positions
- Maintains consistent lookup behavior

### 2. **User Experience**
- Clear notifications when collision prevention occurs
- Automatic resolution of existing collisions
- Diagnostic tools for troubleshooting

### 3. **System Reliability** 
- Prevents edge cases that could break tag management
- Robust error handling and recovery
- Comprehensive logging for debugging

### 4. **Maintainability**
- Centralized collision detection logic
- Clear separation of concerns
- Extensive test coverage

## Usage Examples

### For Players

**Check for collisions:**
```
/tf-check-collisions
```

**Fix any detected collisions:**
```
/tf-fix-collisions
```

**Get detailed report:**
```
/tf-collision-report
```

### For Developers

**Safe chart tag creation:**
```lua
local chart_tag = ChartTagUtils.safe_add_chart_tag(
  player.force, 
  player.surface, 
  chart_tag_spec, 
  player  -- Player context for collision notifications
)

if not chart_tag then
  -- Creation failed, possibly due to collision
end
```

**Manual collision check:**
```lua
local existing_chart_tag, has_collision = ChartTagCollisionDetector.check_position_collision(gps)
if has_collision then
  -- Handle collision case
end
```

## Testing

### Automated Tests
Run the complete test suite:
```lua
/c require("tests.test_chart_tag_collision_detection").run_all_tests()
```

### Manual Testing
1. Create a chart tag manually in map view
2. Try to create another chart tag at same position through tag editor
3. Verify collision prevention and user notification
4. Use diagnostic commands to check/fix any issues

## Performance Considerations

- **Minimal overhead** - collision checks only occur during chart tag creation
- **Efficient lookups** - leverages existing GPS-based cache system
- **Lazy cleanup** - collisions are resolved on-demand rather than continuously
- **Batched operations** - surface-wide cleanup processes multiple collisions efficiently

## Backward Compatibility

- **Non-breaking changes** - all existing functionality preserved
- **Optional player parameter** - existing calls work without modification
- **Graceful degradation** - system works even without player context
- **Automatic migration** - existing collisions can be detected and resolved

## Future Enhancements

1. **Automatic collision detection on mod load** - scan and fix collisions during initialization
2. **Prevention in vanilla chart tag creation** - intercept native Factorio chart tag creation events
3. **Advanced collision resolution strategies** - merge chart tag properties instead of deletion
4. **Performance optimizations** - cache collision detection results for frequently accessed positions

---

**Status**: ✅ **Complete and Tested**  
**Priority**: 🔥 **Critical** - Prevents data corruption  
**Testing**: ✅ **Comprehensive test suite included**  
**Documentation**: ✅ **Complete with examples**

This implementation ensures that the TeleportFavorites mod maintains data integrity by enforcing the fundamental constraint that only one chart tag can exist per GPS position, while providing comprehensive tools for detection, prevention, and resolution of any collisions that may occur.
