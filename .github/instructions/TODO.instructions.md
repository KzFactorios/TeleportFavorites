---
name: "Project Roadmap & Tech Debt"
description: "Current tasks, migration history, and known conflicts"
applyTo: "**/*"
---
# TeleportFavorites: Project State

## 1. MIGRATION LOGIC (Reference: core/cache/cache.lua)
- **Legacy History**: Must convert raw GPS strings to `HistoryItem` objects.
- **Timestamps**: Increment by at least 1 second per entry to ensure unique, chronological ordering.

## 2. ACTIVE TODOs
- [ ] **Conflict Analysis**: Identify 3rd-party mods (e.g., other teleport or map-tag mods) that might conflict with our event logic or GUI.
- [ ] **Surface Validation**: Ensure all teleport logic handles "Space Platforms" correctly (current rule: No favorites on platforms).
- [ ] **Multiplayer Edge Cases**: Stress test tag ownership when a player is deleted while their tag is being edited by an admin.

## 3. TECHNICAL DEBT
- **GUI Refresh**: Some modules still trigger full redraws where partial updates (observers) would be more efficient.
- **Input Validation**: Centralize all GPS string parsing into `gps_utils.lua` to avoid redundant regex logic in GUI modules.