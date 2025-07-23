# Migration Note (2025-07-19)
Legacy teleport history stack migration now ensures unique timestamps for each migrated entry. During migration, each raw GPS string is converted to a `HistoryItem` object with a timestamp incremented by at least 1 second from the previous, guaranteeing uniqueness and correct chronological ordering. This logic is implemented in `core/cache/cache.lua` and uses the updated `HistoryItem.new(gps, timestamp)` constructor.

# TODOs for TeleportFavorites

<!--
  This file tracks outstanding tasks, design notes, and technical debt for the TeleportFavorites mod.
  Please keep entries concise and actionable. Use checkboxes for task tracking.
  When adding new items, prefer actionable language and reference relevant modules/files if possible.
-->

- [ ] Check for conflicts with other potential 3rd-party mods. If you are able to figure out what mods may conflict with our mod, bring them to my attention.
