# TeleportFavorites – Game Rules and Permissions

This document defines the core game rules for the TeleportFavorites mod, including ownership, permissions, admin functionality, and tag editing rules. These rules ensure fair gameplay, prevent griefing, and maintain mod integrity in multiplayer environments.

---

## Core Ownership Principles

### Chart Tag Ownership
- **Initial Ownership**: Only the player who **CREATES** a chart tag becomes the owner
- **Ownership Persistence**: Ownership does NOT change when other players edit the tag
- **Ownership Reset**: Ownership only resets when the owner leaves/is removed from the game
- **Owner Identification**: `chart_tag.last_user` property stores the owner's player name (string)
- **Legacy Tags**: Tags with empty or nil `last_user` can be claimed by any player who edits them

### Tag Creation Rules
```lua
-- When a new chart tag is created:
chart_tag.last_user = creating_player.name

-- When a legacy tag (last_user empty) is edited:
if not chart_tag.last_user or chart_tag.last_user == "" then
    chart_tag.last_user = editing_player.name
end
```

---

## Permission System

### Regular Player Permissions

#### Tag Editing Permissions
Players can edit a chart tag if:
- They are the owner (`chart_tag.last_user == player.name`), OR
- The tag has no owner (`last_user` is empty/nil)

#### Tag Deletion Permissions  
Players can delete a chart tag if:
- They are the owner, AND
- No other players have favorited the tag

If other players have favorited the tag, deletion is blocked to prevent grief.

### Admin Override System

#### Admin Identification
- Uses Factorio's built-in admin system: `player.admin == true`
- No separate permission system - relies on server admin assignment

#### Admin Edit Privileges
Admins can:
- **Edit any chart tag** regardless of ownership
- **Delete any chart tag** regardless of ownership or favorites
- **Bypass all ownership restrictions**

#### Admin Ownership Transfer
When an admin edits a tag with no specified owner:
- Ownership automatically transfers to the admin
- `chart_tag.last_user` is set to the admin's name
- This prevents orphaned tags and ensures accountability

```lua
-- Automatic ownership transfer for admins
if AdminUtils.is_admin(player) and (not chart_tag.last_user or chart_tag.last_user == "") then
    chart_tag.last_user = admin_player.name
end
```

---

## Tag Editor Permissions

### Button Enablement Logic

#### Move Button
- **Enabled when**: Player is owner AND in chart mode
- **Disabled when**: Not owner OR not in chart mode
- **Admin Override**: Admins can move any tag

#### Delete Button  
- **Enabled when**: Player is owner AND no other favorites exist
- **Disabled when**: Not owner OR other players have favorited the tag
- **Admin Override**: Admins can delete any tag regardless of favorites

#### Edit Controls (Text/Icon)
- **Enabled when**: Player is owner OR tag has no owner
- **Disabled when**: Player is not owner and tag has owner
- **Admin Override**: Admins can edit any tag

#### Teleport Button
- **Always enabled** - teleportation is unrestricted

#### Favorite Button
- **Always enabled** - players can favorite any tag (subject to slot limits)

---

## Admin Audit and Logging

### Admin Action Logging
All admin actions are logged with comprehensive details:

```lua
AdminUtils.log_admin_action(admin_player, "edit_chart_tag", chart_tag, {
    old_text = "Previous text",
    new_text = "New text", 
    override_reason = "admin_privileges"
})
```

### Logged Admin Actions
- **Chart tag editing** (text/icon changes)
- **Chart tag deletion** (including forced deletion with favorites)
- **Chart tag movement** (position changes)
- **Ownership transfers** (when editing unowned tags)

### Log Data Includes
- Admin player name and timestamp
- Chart tag position and content
- Previous and new values
- Override reason and context
- Whether other players had favorites

---

## Multiplayer Safety Rules

### Race Condition Prevention
- **First-come-first-served**: First player to successfully save wins
- **Ownership validation**: All operations validate ownership before execution
- **Transaction safety**: Operations are atomic where possible

### Player Disconnect Handling
When a player leaves the game:
1. **Ownership reset**: All chart tags owned by the player have ownership reset to empty
2. **Favorite cleanup**: Player is removed from all tag favorite lists
3. **Orphan cleanup**: Tags with no remaining favorites are deleted
4. **Cache invalidation**: Lookup caches are refreshed for affected surfaces

### Admin Disconnect Handling
- Same rules apply to admins - no special treatment
- Admin status is session-based, not persistent
- Ownership transfers by admins persist after they leave

---

## Permission Check Functions

### Core Permission Validators

#### Edit Permissions
```lua
local can_edit, is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, chart_tag)
-- Returns: ability to edit, ownership status, admin override flag
```

#### Delete Permissions  
```lua
local can_delete, is_owner, is_admin_override, reason = AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
-- Returns: ability to delete, ownership status, admin override flag, denial reason
```

#### Admin Status
```lua
local is_admin = AdminUtils.is_admin(player)
-- Returns: true if player has admin privileges
```

---

## Error Handling and User Feedback

### Permission Denied Messages
- **Edit denied**: "You are not the owner of this tag and do not have admin privileges"  
- **Delete denied**: "Cannot delete tag: other players have favorited this tag"
- **Move denied**: Handled via button disabling rather than error messages

### Admin Action Feedback
- Admin actions are logged but not announced to other players
- Admins receive standard success/failure feedback
- No special admin-only UI elements or notifications

---

## Edge Cases and Special Scenarios

### Legacy Tags (No Owner)
- Any player can claim ownership by editing
- Admins automatically claim ownership when editing
- First editor wins in race conditions

### Chart Tags vs Vanilla Tags
- Rules apply only to chart tags created through this mod
- Vanilla chart tags (created through base game) are not affected
- Mod chart tags are distinguished by association with mod tag objects

### External Modifications
- If chart tags are modified through vanilla interface, admin rules still apply
- External modifications trigger permission checks
- Unauthorized external changes are rejected

### Cross-Surface Scenarios
- Ownership rules apply per-surface
- Same player can own tags on different surfaces
- Admin privileges apply across all surfaces

---

## Implementation Notes

### Security Considerations
- All permission checks use server-side validation
- Admin status verified through Factorio's native system
- No client-side trust or privilege escalation possible

### Performance Implications
- Permission checks are lightweight (O(1) lookups)
- Admin logs use standard error handling system
- No significant performance impact in normal gameplay

### Mod Compatibility
- Uses only Factorio's built-in admin system
- No conflicts with other permission mods
- Graceful handling of missing admin status

---

## Future Considerations

### Potential Enhancements
- **Delegation system**: Allow owners to grant edit permissions to specific players
- **Role-based permissions**: Support for different admin/moderator levels  
- **Time-based ownership**: Automatic ownership expiry for inactive players
- **Permission groups**: Team-based ownership and editing rights

### Current Limitations
- Binary ownership model (owner vs non-owner)
- No granular permission controls
- Admin actions are not reversible through UI
- No owner transfer mechanism (except through admin intervention)

---

*This document reflects the current implementation as of 2025-06-17. For technical implementation details, see `core/utils/admin_utils.lua` and related modules.*
