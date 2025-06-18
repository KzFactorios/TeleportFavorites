# TeleportFavorites - Natural Position System Testing Guide

## Overview
This guide provides step-by-step instructions for testing the natural position uniqueness system that is built into TeleportFavorites. The system leverages existing architecture to ensure chart tag reuse and position consistency without requiring separate collision detection modules.

## How the System Works

The TeleportFavorites mod naturally prevents position conflicts through its existing architecture:

### 1. **Chart Tag Reuse via Cache System**
- When you right-click near an existing chart tag, the system finds and opens that existing tag for editing
- `ChartTagUtils.find_chart_tag_at_position()` searches within the configured radius
- This promotes chart tag reuse instead of creating duplicates

### 2. **GPS-Keyed Tag Storage**
- Tag objects are stored using GPS coordinates as keys: `tags[gps] = tag`
- This inherently prevents multiple Tag objects at the same GPS coordinate
- If a tag already exists at a GPS location, it gets replaced (not duplicated)

### 3. **Position Normalization**
- All positions are automatically normalized to whole numbers via `PositionUtils.normalize_position()`
- This ensures consistent coordinate handling and prevents floating-point position conflicts
- Positions like `{x=100.1, y=200.9}` become `{x=100, y=201}`

## Test Environment Setup

1. **Load Factorio** with the TeleportFavorites mod enabled
2. **Create or load a world** with sufficient space for testing
3. **Open the console** (~ key) to run test commands

---

## Manual Testing Procedures

### Test 1: Chart Tag Reuse Detection

**Objective**: Verify that clicking on or near an existing chart tag opens the tag editor for that existing tag

**Steps**:
1. Right-click on the map to open tag editor
2. Add text "Test Tag 1" and confirm to create the chart tag
3. Right-click the same position, or within the chart_tag_click_radius, again
4. Observe that the tag editor opens with "Test Tag 1" already populated
5. Modify text to "Test Tag 1 Modified" and confirm

**Expected Results**:
- ✅ First chart tag created successfully
- ✅ Second right-click opens tag editor with existing tag data
- ✅ Tag editor shows "Test Tag 1" in text field
- ✅ Modifications update the existing chart tag (no duplicate created)
- ✅ Only one chart tag visible at the chart_tag's position 

### Test 2: Tag Storage Natural Collision Prevention

**Objective**: Verify that the GPS-keyed storage naturally prevents duplicate Tag objects

**Steps**:
1. Create a tag at position (100, 100) by right-clicking and editing through tag editor
2. Add text "First Tag" and confirm to create both chart tag and Tag object
3. Right-click the same position (100, 100) again
4. Verify that the tag editor opens with "First Tag" already populated (tag reuse)
5. Change text to "Updated Tag" and confirm

**Expected Results**:
- ✅ First Tag object stored successfully at GPS coordinate
- ✅ Second right-click opens existing tag for editing (natural reuse)
- ✅ Only one Tag object exists at GPS coordinate (natural uniqueness)
- ✅ Tag text is updated to "Updated Tag" (existing tag modified, not duplicated)

### Test 3: Chart Tag Reuse Integration

**Objective**: Verify chart tag reuse when clicking near existing tags

**Steps**:
1. Create a chart tag at position (200, 200) with text "Original Tag"
2. Right-click at position (201, 201) - within the chart tag click radius
3. Verify that the tag editor opens showing "Original Tag"
4. Modify the text to "Modified Tag" and confirm

**Expected Results**:
- ✅ Original chart tag created successfully
- ✅ Right-click near existing tag opens tag editor with existing data
- ✅ Changes are applied to the existing chart tag (no duplicate created)
- ✅ Chart tag reuse system works correctly

### Test 4: System Integration Test

**Objective**: Verify chart tag and Tag systems work together naturally

**Steps**:
1. Create a chart tag using the map interface
2. Try to create a TeleportFavorites tag at the same position through tag editor
3. Attempt to confirm the tag creation

**Expected Results**:
- ✅ Chart tag reuse system finds existing chart tag
- ✅ Tag editor opens with existing chart tag data
- ✅ No duplicate objects created (natural system behavior)

---

## Automated Testing

### Run Natural System Test
```lua
/c require("tests.test_natural_position_system")
```

**Expected Output**:
```
🧪 Testing Natural Position System...
📍 Test 1: Chart Tag Reuse Detection
✅ First chart tag created successfully
✅ Right-click opens tag editor with existing tag data

🏷️ Test 2: Tag Storage Natural Uniqueness  
✅ First Tag object stored successfully
✅ Second attempt reuses existing tag naturally

🔗 Test 3: System Integration
✅ Different position: Both chart tag and Tag created successfully

🛡️ Natural position uniqueness is working perfectly!
```

### Diagnostic Commands

**Check for any issues**:
```lua
/c local Cache = require("core.cache.cache")
/c Cache.Lookups.invalidate_surface_chart_tags(1)
/c game.print("Chart tag cache refreshed")
```

**Verify position normalization**:
```lua
/c local GPSUtils = require("core.utils.gps_utils")
/c local pos = {x = 100.5, y = 100.7}
/c local gps = GPSUtils.gps_from_map_position(pos, 1)
/c game.print("GPS: " .. gps)  -- Should show whole numbers
```

---

## Troubleshooting

### If Natural System Is Not Working

1. **Check cache state**:
   ```lua
   /c local Cache = require("core.cache.cache")
   /c Cache.Lookups.invalidate_surface_chart_tags(1)
   /c game.print("Chart tag cache refreshed")
   ```

2. **Check position normalization**:
   ```lua
   /c local GPSUtils = require("core.utils.gps_utils")
   /c local pos = {x = 100.5, y = 100.7}
   /c local gps = GPSUtils.gps_from_map_position(pos, 1)
   /c game.print("GPS: " .. gps)  -- Should show whole numbers
   ```

### Common Issues

- **Floating point positions**: The system normalizes to whole numbers automatically
- **Cache inconsistency**: Use cache refresh commands to resolve
- **Multi-surface conflicts**: Each surface has independent tag storage

---

## Success Criteria

✅ **Chart Tag Reuse**: Existing tags reused when clicking within radius  
✅ **Tag GPS Uniqueness**: Only one Tag object per GPS coordinate (natural)  
✅ **Position Normalization**: Coordinates automatically aligned to tile grid  
✅ **Cache Consistency**: Automatic invalidation after operations  
✅ **Multi-surface Support**: Independent tag storage per surface  

---

## Performance Notes

- **Position Normalization**: Coordinates automatically aligned to tile grid
- **Cache Efficiency**: Tag reuse uses existing cache systems
- **Minimal Overhead**: No additional collision checks needed
- **Memory Safe**: GPS-keyed storage prevents duplicates naturally

The natural position uniqueness system leverages the existing position normalization and caching infrastructure, ensuring both data integrity and performance efficiency.
