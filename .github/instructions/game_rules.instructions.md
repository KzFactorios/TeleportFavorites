---
name: "TeleportFavorites Game Rules"
description: "Ownership, Admin overrides, and Permission logic"
applyTo: "core/utils/admin_utils.lua, gui/**/*.lua, **/*.lua"
---
# TeleportFavorites: Permissions & Game Rules

## 1. OWNERSHIP CORE
- **Initial Owner**: The player who CREATES the tag. Stored in `chart_tag.last_user`.
- **Persistence**: Ownership does NOT change when others edit.
- **Legacy Tags**: If `last_user` is empty, the first player to edit "claims" it.
- **Admin Claim**: If an Admin edits an unowned tag, they automatically become the owner.

## 2. PERMISSION LOGIC (Surgical Checks)
Always use `AdminUtils` for these checks:

| Action | Regular Player Requirement | Admin Requirement |
| :--- | :--- | :--- |
| **Edit Text/Icon** | Is Owner OR Tag is Unowned | Can edit ANY tag |
| **Move Tag** | Is Owner | Can move ANY tag |
| **Delete Tag** | Is Owner AND No other players favorited it | Can delete ANY tag |
| **Teleport** | Always Allowed | Always Allowed |

## 3. MULTIPLAYER SAFETY & DISCONNECTS
- **Atomic Saves**: First-to-save wins. Validate ownership *on the server* immediately before writing to `storage`.
- **Cleanup on Leave**: 
  1. Remove player from all "faved_by" lists.
  2. If a tag has 0 favorites and no owner, delete it (Orphan Cleanup).
  3. Reset ownership of tags owned by the departing player to `nil` (Claimable).

## 4. ADMIN AUDIT LOGGING
- **Rule**: All Admin overrides (Edit/Move/Delete of non-owned tags) MUST be logged.
- **Helper**: Use `AdminUtils.log_admin_action(admin, action, tag, details)`.

## 5. GUI STATE (Button Enablement)
- **Visuals**: Disable (don't just hide) buttons that violate permissions.
- **Tooltips**: Explain *why* a button is disabled (e.g., "Owned by [Name]" or "Other players have favorited this").