# Admin Functionality - TeleportFavorites Mod

## Overview

The TeleportFavorites mod now includes comprehensive admin functionality that allows server administrators to manage chart tags regardless of ownership restrictions.

## Admin Privileges

### Chart Tag Editing
- **Regular Players**: Can only edit chart tags they own (where `chart_tag.last_user` matches their name)
- **Admins**: Can edit ANY chart tag regardless of ownership
- **Ownership Transfer**: When an admin edits a chart tag with no specified owner (`last_user` is empty), ownership automatically transfers to the admin

### Chart Tag Deletion
- **Regular Players**: Can only delete chart tags they own AND no other players have favorited
- **Admins**: Can delete ANY chart tag, even if other players have favorited it
- **Override Protection**: Admin privileges override all ownership and favorite-based deletion restrictions

## Implementation Details

### Admin Detection
Admin status is determined using Factorio's built-in `LuaPlayer.admin` property:
```lua
local is_admin = AdminUtils.is_admin(player)
```

### Permission Checking
```lua
-- Check if player can edit a chart tag
local can_edit, is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, chart_tag)

-- Check if player can delete a chart tag
local can_delete, is_owner, is_admin_override, reason = AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
```

### Ownership Transfer
```lua
-- Transfer ownership to admin if last_user is unspecified
local transferred = AdminUtils.transfer_ownership_to_admin(chart_tag, admin_player)
```

### Admin Action Logging
All admin actions are automatically logged for audit purposes:
```lua
AdminUtils.log_admin_action(admin_player, "edit_chart_tag", chart_tag, additional_data)
```

## Usage Examples

### In Tag Editor GUI
- Admins will see all edit controls enabled regardless of tag ownership
- When an admin edits a tag with no owner, they automatically become the owner
- Admins can delete tags even if other players have favorited them

### Console Commands
Test admin functionality in-game:
```
/test-admin
```

### Event Handling
- Chart tag modification events now respect admin privileges
- External chart tag deletions are prevented unless the player is admin or owner with no other favorites

## Security Considerations

1. **Admin-Only**: Only players with `player.admin = true` can use admin overrides
2. **Audit Trail**: All admin actions are logged with detailed information
3. **Ownership Preservation**: Regular ownership rules still apply to non-admin players
4. **Automatic Transfer**: Ownership only transfers when `last_user` is empty or nil

## Integration

The admin functionality is integrated into:
- Tag Editor GUI (`gui/tag_editor/tag_editor.lua`)
- Tag Editor Control Logic (`core/control/control_tag_editor.lua`) 
- Chart Tag Event Handlers (`core/events/handlers.lua`)
- Chart Tag Utilities (`core/utils/chart_tag_utils.lua`)

## Testing

Run the admin functionality tests:
1. Load the mod in a Factorio game
2. Ensure you have admin privileges (`/promote <username>`)
3. Run `/test-admin` to verify functionality
4. Check the log for detailed admin action logging

## Configuration

No additional configuration is required. Admin functionality is automatically available to any player with admin privileges as determined by Factorio's built-in admin system.
