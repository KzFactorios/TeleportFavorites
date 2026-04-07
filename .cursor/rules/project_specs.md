# TeleportFavorites: Project Specifications (Factorio 2.0)

## 1. Core Intent
High-speed teleportation system utilizing a dedicated favorites bar and map-based chart tags. Designed specifically for Factorio 2.0 (Space Age) with full surface-awareness (Planets, Platforms, Nauvis).

## 2. Technical Standards
- **Runtime**: Factorio-flavored Lua 5.2.
- **Persistence**: All state must live in the `storage` table (never `global`).
- **Safety**: Every object access must be preceded by a `.valid` check.
- **Determinism**: Use `ipairs` for arrays and `pairs` for dictionaries. No `next()` on userdata.
- **Performance**: Strict `on_nth_tick(N, ...)` for periodic logic (N >= 2).

## 3. Data Schema (Canonical)
### GPS Serialization
TeleportFavorites uses a deterministic, padded string format for all GPS lookups:
- **Format**: `"xxx.yyy.s"` (e.g., `-005.010.1`)
- **Padded Magnitude**: X and Y are zero-padded based on `Constants.settings.GPS_PAD_NUMBER`.
- **Surface**: `s` is the unpadded surface index.
- **Null Value**: `Constants.settings.BLANK_GPS`.

### Storage Hierarchy
- **Player Data**: `storage.players[p_idx].surfaces[s_idx].favorites[slot]`
- **Tag Registry**: `storage.surfaces[s_idx].tags[gps_string]`

## 4. Architecture & Module Responsibilities
- **GUI (gui/gui_base.lua)**: Use `GuiBase` helpers for all construction. GUI is a passive observer of `storage`.
- **Cache (core/cache/)**: The exclusive interface for reading/writing to `storage`. Includes `Cache.sanitize_for_storage` to purge userdata.
- **Events (core/events/)**: Permanent registration only. Uses a "Dirty-Player" deferred notification pattern via `on_nth_tick(2)`.
- **Permissions (core/utils/admin_utils.lua)**: Creator-based ownership. Admins override all; regular players only manage their own tags.

## 5. Development Workflow
- **Require Policy**: All `require()` calls must be at the absolute top of the file.
- **Linting**: Run `lua .scripts/require_lint.lua --check .` after changes.
- **Testing**: Run smoke tests via `.\.test.ps1`. Specs reside in `tests/specs/`.
- **Changelog**: Strict Factorio format: `Version: 0.0.0`, `Date: YYYY-MM-DD`, 2-space indentation.
