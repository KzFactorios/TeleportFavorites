local BLANK_GPS = "1000000.1000000.1"

-- Main drag-and-drop function
function handle_drag_drop(slots, src_idx, dest_idx)
    -- Validate indices (Lua 1-based)
    if src_idx < 1 or src_idx > #slots or dest_idx < 1 or dest_idx > #slots then
        return slots
    end

    local src = slots[src_idx]
    local dest = slots[dest_idx]

    -- Rule: Blank or locked source cannot be dragged
    if src.gps == BLANK_GPS or src.locked then
        return slots
    end

    -- Rule: Cannot drag onto locked destination
    if dest.locked then
        return slots
    end

    -- If source and destination are the same, do nothing
    if src_idx == dest_idx then
        return slots
    end

    -- If destination is blank, swap source and destination
    if dest.gps == BLANK_GPS then
        slots[dest_idx] = {gps = src.gps, locked = src.locked}
        slots[src_idx] = {gps = BLANK_GPS, locked = false}
        return slots
    end

    -- If source and destination are adjacent, swap them
    if math.abs(src_idx - dest_idx) == 1 then
        slots[src_idx], slots[dest_idx] = slots[dest_idx], slots[src_idx]
        return slots
    end

    -- Otherwise, perform reversed cascade
    local step = (src_idx < dest_idx) and -1 or 1  -- reversed direction
    local start_idx, end_idx

    if src_idx < dest_idx then
        start_idx, end_idx = dest_idx, src_idx + 1
    else
        start_idx, end_idx = dest_idx, src_idx - 1
    end

    -- Check for locked slots in the cascade path (excluding src and dest)
    for i = start_idx, end_idx, step do
        if slots[i].locked then
            -- Abort if cascade would overwrite a locked slot
            return slots
        end
    end

    -- Shift all intervening slots toward the source
    for i = start_idx, end_idx, step do
        slots[i] = {gps = slots[i - step].gps, locked = slots[i - step].locked}
    end

    -- Place dragged item at destination
    slots[dest_idx] = {gps = src.gps, locked = src.locked}
    -- Set source to blank
    slots[src_idx] = {gps = BLANK_GPS, locked = false}

    return slots
end

-- Helper: Count available (blank) slots
function count_available_slots(slots)
    local count = 0
    for i = 1, #slots do
        if slots[i].gps == BLANK_GPS then
            count = count + 1
        end
    end
    return count
end
