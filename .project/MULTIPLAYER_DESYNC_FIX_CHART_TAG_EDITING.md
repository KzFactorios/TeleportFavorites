# Multiplayer Desync Fix - Chart Tag Editing

**Date:** 2025-10-12  
**Issue:** CRC mismatch causing multiplayer desyncs when confirming tag editor changes  
**Root Cause:** Direct modification of `LuaChartTag` properties in multiplayer environment  
**Solution:** Destroy and recreate chart tags instead of direct modification

---

## Problem Analysis

### Symptoms
From Factorio log (v2.0.69):
```
26.549 Error GameActionHandler.cpp:2808: Multiplayer desynchronisation: 
      crc test (heuristic) failed for crcTick(2130) 
      serverCRC(1469756831) localCRC(1211826104)
```

The desync occurred immediately after tag editor confirmation at tick 2130, cascading across multiple ticks (2130-2134).

### Timeline from Log
```
22.698  [TeleFaves] tf-open-tag-editor event (player opens tag editor)
24.449  [TeleFaves] on_gui_click tag_editor_icon_button
26.532  [TeleFaves] on_gui_click tag_editor_confirm_button
26.533  [TeleFaves] handle_confirm_btn: entry
26.549  ERROR: Multiplayer desynchronisation (CRC mismatch)
```

### Root Cause
**Direct property assignment on `LuaChartTag` objects causes desyncs in multiplayer.**

The problematic patterns in the codebase (before fix):

**1. Direct Chart Tag Modification:**
```lua
// ❌ BROKEN in multiplayer - causes desync
if chart_tag and chart_tag.valid then
  chart_tag.last_user = player.name      // Direct assignment
  chart_tag.text = text or ""            // Direct assignment
  chart_tag.icon = icon                  // Direct assignment
end
```

**2. Storing LuaObject Userdata in Persistent Storage:**
```lua
// ❌ BROKEN in multiplayer - causes desync
local sanitized_tag = Cache.sanitize_for_storage(refreshed_tag)
tags[tag.gps] = sanitized_tag
// This line re-adds the userdata after sanitization!
tags[tag.gps].chart_tag = tag_data.chart_tag  // ← DESYNC SOURCE!
```

**3. Non-Deterministic Iteration Order:**
```lua
// ❌ BROKEN in multiplayer - causes desync
function Cache.sanitize_for_storage(obj, exclude_fields)
  local sanitized = {}
  for k, v in pairs(obj) do  // ← pairs() has random iteration order!
    if not exclude_fields[k] and type(v) ~= "userdata" then
      sanitized[k] = v
    end
  end
  return sanitized
end
```

This works in **single-player** because there's only one game state, but in **multiplayer**:
- Direct property assignments don't propagate as game actions
- Storing LuaObject references (userdata) in `storage` is forbidden
- `pairs()` iteration order is **non-deterministic** - random on each client
- Each client has independent local state
- Clients diverge in state, causing CRC mismatches
- Server and clients compute different checksums → desynchronization

**Factorio Multiplayer Rule:** 
> Never store `LuaObject` references (userdata) in `storage`. These are client-specific and cause immediate desyncs.  
> Never use `pairs()` for iteration when writing to `storage`. Use sorted keys with `ipairs()` for deterministic order.

---

## Solution: Destroy and Recreate Pattern

### Correct Multiplayer-Safe Pattern
```lua
-- ✅ CORRECT in multiplayer - synchronized game actions
if chart_tag and chart_tag.valid then
  -- Store old chart tag data before destroying
  local surface_index = chart_tag.surface.index
  local force = chart_tag.force
  local surface = chart_tag.surface
  local position = chart_tag.position
  
  -- 1. Destroy old chart tag (game action - syncs to all clients)
  chart_tag.destroy()
  
  -- 2. Invalidate runtime cache
  Cache.Lookups.invalidate_surface_chart_tags(surface_index)
  
  -- 3. Create new chart tag with updated properties (game action - syncs to all clients)
  local chart_tag_spec = ChartTagSpecBuilder.build(position, nil, player, text, true)
  if ValidationUtils.has_valid_icon(icon) then
    chart_tag_spec.icon = icon
  else
    chart_tag_spec.icon = nil
  end
  
  local new_chart_tag = ChartTagUtils.safe_add_chart_tag(force, surface, chart_tag_spec, player)
  
  -- 4. Update references
  tag.chart_tag = new_chart_tag
  tag_data.chart_tag = new_chart_tag
end
```

### Why This Works
1. **`destroy()` is a game action** - propagates to all clients via Factorio's multiplayer protocol
2. **`force.add_chart_tag()` is a game action** - synchronized across all clients automatically
3. **All clients receive identical game events** - maintains CRC consistency
4. **No direct state mutation** - eliminates race conditions and desync vectors

### Factorio Multiplayer Architecture
Factorio uses **deterministic lockstep multiplayer**:
- Game actions (create entity, destroy entity, etc.) are synchronized
- Direct property changes on game objects are NOT synchronized
- All clients must execute identical logic to maintain determinism

---

## Implementation Details

### Modified Functions
**Files Changed:**
1. `core/control/control_tag_editor.lua::update_chart_tag_fields()` - Tag editing
2. `core/utils/chart_tag_utils.lua::safe_add_chart_tag()` - Tag creation/update
3. `core/utils/admin_utils.lua` - Admin operations (warning added, TODO marked)
4. `core/control/chart_tag_ownership_manager.lua` - Ownership management (warning added, TODO marked)

### Key Changes
1. **Replaced direct modification in tag editing** (`control_tag_editor.lua`) with destroy-and-recreate pattern
2. **Replaced direct modification in tag creation** (`chart_tag_utils.lua`) with destroy-and-recreate pattern
3. **Removed LuaObject storage** - eliminated code that stored `chart_tag` userdata in persistent `storage`
4. **Fixed non-deterministic iteration** - replaced `pairs()` with sorted keys in `sanitize_for_storage()`
5. **Preserved permission checks** - admin override and ownership validation still enforced
6. **Maintained cache synchronization** - invalidate before/after chart tag operations
7. **Added error handling** - gracefully handle recreation failures
8. **Enhanced logging** - debug messages for multiplayer troubleshooting
9. **Added TODOs** for remaining direct modifications in admin utilities (lower priority)
10. **Updated data schema documentation** - clarified that `chart_tag` is never stored in `storage`

### Flow Diagram
```
Permission Check 
    ↓
Destroy Old Tag (game action)
    ↓
Invalidate Cache (local state)
    ↓
Create New Tag (game action)
    ↓
Update References (local state)
    ↓
Refresh Cache (local state)
```

### Code Documentation Added
Added critical comment block at top of `control_tag_editor.lua`:
```lua
-- CRITICAL MULTIPLAYER SAFETY PATTERN:
-- LuaChartTag objects CANNOT be directly modified in multiplayer without causing desynchronization.
-- Direct property assignment (chart_tag.text = "foo", chart_tag.icon = {...}) works in single-player
-- but causes CRC mismatches and desyncs in multiplayer because each client has independent state.
--
-- CORRECT PATTERN: Destroy and recreate chart tags instead of modifying them.
-- This ensures all clients receive the same game actions and maintain synchronized state.
-- See update_chart_tag_fields() for the implementation of this pattern.
```

---

## Related Patterns

### Multiplayer-Safe Operations (Game Actions)
These operations are **already safe** because they use game actions:
- ✅ `force.add_chart_tag()` - creates tags
- ✅ `chart_tag.destroy()` - removes tags
- ✅ `force.find_chart_tags()` - reads tags (read-only, no state mutation)
- ✅ `player.teleport()` - moves player
- ✅ `entity.destroy()` - removes entity

### Unsafe Operations (Direct State Mutation)
These cause desyncs and must **never** be used in multiplayer:
- ❌ Direct property assignment: `chart_tag.text = "foo"`
- ❌ Direct property assignment: `chart_tag.icon = {...}`
- ❌ Direct property assignment: `chart_tag.last_user = player`
- ❌ Using client-specific state: `player.render_mode` (see MULTIPLAYER_DESYNC_FIX.md)

---

## Testing Checklist

### Critical Test Cases
- [ ] **Single-player tag editing** - ensure no regression in SP functionality
- [ ] **Multiplayer tag editing** - verify no desyncs when editing existing tags
- [ ] **Tag creation** - confirm new tags work correctly (already used this pattern)
- [ ] **Permission enforcement** - non-owners cannot edit, admins can override
- [ ] **Icon/text updates** - all property changes propagate correctly
- [ ] **Cache consistency** - runtime lookups stay synchronized with game state

### Manual Multiplayer Test Procedure
```
1. Start multiplayer server
2. Join as client from different machine/account
3. Create tag via tag editor (should work - already used safe pattern)
4. Edit existing tag via tag editor (THIS is the fixed case):
   a. Open tag editor on existing tag
   b. Change text and/or icon
   c. Click Confirm
5. Check factorio-current.log for desync errors (should be NONE)
6. Confirm tag updates visible to all clients
7. Verify server and client see identical tag state
```

---

## Performance Considerations

### Overhead
- **Destroy + Recreate** is marginally slower than direct modification
- Impact is **negligible** - tag editor operations are user-triggered, not in hot path
- Trade-off is **mandatory** for multiplayer safety

### Comparison
| Operation | Time Complexity | Multiplayer Safe? |
|-----------|----------------|-------------------|
| Direct modification | O(1) | ❌ No (causes desync) |
| Destroy + Recreate | O(1) + overhead | ✅ Yes (game actions) |

### Cache Management
- Cache invalidation triggers lazy reload on next access
- `ensure_surface_cache()` rebuilds GPS mapping from fresh `find_chart_tags()` call
- No performance regression - same cache refresh pattern used throughout codebase

---

## Related Previous Fixes

This is the **third** multiplayer desync fix for this mod:

1. **MULTIPLAYER_DESYNC_FIX.md** - Fixed `player.render_mode` non-determinism in chart tag creation
2. **MULTIPLAYER_DESYNC_FIX_PAIRS_ITERATION.md** - Fixed non-deterministic `pairs()` iteration order
3. **MULTIPLAYER_DESYNC_FIX_ADDITIONAL_FIXES.md** - Fixed table serialization and storage patterns
4. **THIS FIX** - Fixed direct chart tag property modification

### Common Thread
All desyncs stem from **non-deterministic operations** or **client-specific state**:
- Using `player.render_mode` (client-specific view state)
- Using `pairs()` on arrays (non-deterministic iteration order)
- Direct property assignment on game objects (not synchronized as game actions)

### Lessons Learned Pattern
**In Factorio multiplayer, ALWAYS:**
1. Use game actions (`destroy()`, `add_chart_tag()`) instead of direct property changes
2. Avoid client-specific state (`player.render_mode`, `player.opened`)
3. Use deterministic iteration (`ipairs()` instead of `pairs()` for arrays)
4. Test in real multiplayer scenarios, not just single-player

---

## References

- **Factorio Multiplayer Architecture:** [FFF #276 - Multiplayer](https://factorio.com/blog/post/fff-276)
- **LuaChartTag API:** [Factorio Lua API - LuaChartTag](https://lua-api.factorio.com/latest/classes/LuaChartTag.html)
- **Desynchronization Wiki:** [Factorio Wiki - Desynchronization](https://wiki.factorio.com/Desynchronization)
- **Coding Standards:** `.project/coding_standards.md` - Multiplayer safety requirements
- **Architecture:** `.project/architecture.md` - Event-driven patterns for multiplayer

---

## Status

**Fixed:** 2025-10-12  
**Tested:** Awaiting multiplayer testing  
**Documented:** ✅  
**Committed:** Pending  

## Contributors
- **Identified by:** User log analysis (desync on tag editor confirm)
- **Root cause analysis:** GitHub Copilot
- **Fix implemented:** GitHub Copilot
- **Code review:** Pending
