# Drag and Drop Algorithm - Current Implementation

## Overview
The TeleportFavorites mod uses a **blank-seeking cascade algorithm** implemented in `DragDropUtils.reorder_slots()`. This algorithm provides intuitive slot reordering by finding and utilizing blank slots between source and destination.

## Algorithm Description

### Function Signature
```lua
function DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)
-- Returns: (modified_slots, success, error_message)
```

### Core Logic Flow

#### 1. Validation Phase
- Validates source is not blank or locked
- Validates destination is not locked  
- Validates indices are within bounds
- Returns early with error if any validation fails

#### 2. Simple Cases (Fast Path)
```lua
-- Case A: Moving to blank destination
if is_blank(dest) then
    return simple_swap(source, dest)
end

-- Case B: Adjacent slots (distance = 1)
if math.abs(source_idx - dest_idx) == 1 then
    return simple_swap(source, dest)  
end
```

#### 3. Complex Case: Blank-Seeking Cascade

**Step 1: Source Evacuation**
```lua
-- Source immediately becomes blank, creating cascade target
local source_favorite = slots[source_idx]
slots[source_idx] = { gps = BLANK_GPS, locked = false }
```

**Step 2: Blank Detection Between Source and Destination**
```lua
local blank_idx = source_idx  -- Default: cascade to source position

if source_idx < dest_idx then
    -- Moving rightward: scan left from dest-1 to source+1
    for i = dest_idx - 1, source_idx + 1, -1 do
        if is_blank(slots[i]) and not slots[i].locked then
            blank_idx = i
            break
        end
    end
else
    -- Moving leftward: scan right from dest+1 to source-1  
    for i = dest_idx + 1, source_idx - 1 do
        if is_blank(slots[i]) and not slots[i].locked then
            blank_idx = i
            break
        end
    end
end
```

**Step 3: Cascade Items Toward Blank**
```lua
if source_idx < dest_idx then
    -- Rightward move: cascade items leftward to fill blank
    for i = blank_idx, dest_idx - 1 do
        if slots[i + 1] and not slots[i + 1].locked then
            slots[i] = slots[i + 1]  -- Shift left
        end
    end
else
    -- Leftward move: cascade items rightward to fill blank
    for i = blank_idx, dest_idx + 1, -1 do
        if slots[i - 1] and not slots[i - 1].locked then
            slots[i] = slots[i - 1]  -- Shift right
        end
    end
end
```

**Step 4: Place Source at Destination**
```lua
slots[dest_idx] = source_favorite
```

## Behavior Examples

### Example 1: Rightward Move with No Intermediate Blanks
**Initial**: `[A][B][C][D][E][F][G][H][I][J]`  
**Action**: Drag slot 1 (A) → slot 4 (D)

1. Source evacuation: `[_][B][C][D][E][F][G][H][I][J]`
2. No blanks found between positions 2-3, cascade target = position 1  
3. Cascade leftward: `[B][C][D][_][E][F][G][H][I][J]`
4. Place A at destination: `[B][C][A][D][E][F][G][H][I][J]`

**Result**: A inserted at position 3, displaced items shift left toward blank

### Example 2: Leftward Move with Intermediate Blank
**Initial**: `[A][B][_][D][E][F][G][H][I][J]`  
**Action**: Drag slot 6 (F) → slot 2 (B)

1. Source evacuation: `[A][B][_][D][E][_][G][H][I][J]`  
2. Blank found at position 3 between source(6) and dest(2)
3. Cascade rightward toward blank: `[A][B][D][E][_][_][G][H][I][J]`
4. Place F at destination: `[A][F][D][E][_][_][G][H][I][J]`

**Result**: F inserted at position 2, B displaced into available blank space

## Key Characteristics

### Intuitive Behavior
- **Natural flow**: Items shift in the direction that makes space for the moved item
- **Blank utilization**: Algorithm finds and uses available blank slots efficiently
- **Minimal disruption**: Only items between source and destination are affected

### Edge Case Handling
- **Locked slots**: Completely skipped during cascade operations
- **Boundary respect**: All operations stay within slot array bounds
- **State preservation**: Deep copy prevents original data mutation
- **Error reporting**: Comprehensive validation with descriptive error messages

### Performance Characteristics  
- **O(n) time complexity**: Single pass for blank detection, single pass for cascade
- **Memory efficient**: In-place operations on copied data structure
- **Early termination**: Simple cases bypass complex cascade logic

## Implementation Location
- **File**: `core/utils/drag_drop_utils.lua`
- **Function**: `DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)`
- **Dependencies**: `BasicHelpers.deep_copy()`, `BasicHelpers.is_blank_favorite()`, `Constants.settings.BLANK_GPS`
