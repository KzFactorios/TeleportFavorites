# Move Button Ownership Logic - VERIFIED ✅

## Current Implementation

The move button is properly configured to be **disabled unless the player is the owner** with the following logic:

```lua
if refs.move_btn then 
    -- Move button only enabled if player is owner AND in chart mode
    -- Disabled if: not owner, or not in chart mode
    local in_chart_mode = (player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in)
    local can_move = is_owner and in_chart_mode
    Helpers.set_button_state(refs.move_btn, can_move) 
end
```

## Ownership Determination

The `is_owner` variable is determined as follows:

```lua
if tag and tag.chart_tag then
    is_owner = (not tag.chart_tag.last_user or tag.chart_tag.last_user == "" or tag.chart_tag.last_user == player.name)
else
    -- New tag (no chart_tag yet) - player can edit and delete
    is_owner = true
end
```

## Move Button States

| Scenario | Owner? | Chart Mode? | Button State |
|----------|--------|-------------|--------------|
| Player owns tag, in chart mode | ✅ Yes | ✅ Yes | **ENABLED** |
| Player owns tag, not in chart mode | ✅ Yes | ❌ No | **DISABLED** |
| Player doesn't own tag, in chart mode | ❌ No | ✅ Yes | **DISABLED** |
| Player doesn't own tag, not in chart mode | ❌ No | ❌ No | **DISABLED** |
| New tag (no owner yet) | ✅ Yes | ✅ Yes | **ENABLED** |
| New tag (no owner yet) | ✅ Yes | ❌ No | **DISABLED** |

## Key Rules

1. **✅ OWNERSHIP REQUIRED**: Move button is disabled if player is not the owner
2. **✅ CHART MODE REQUIRED**: Move button is disabled if not in chart mode  
3. **✅ BOTH CONDITIONS**: Both ownership AND chart mode must be true to enable

This ensures that only the tag owner can move their tags, and only when they're in the appropriate view mode (chart view) where tag movement makes sense.
