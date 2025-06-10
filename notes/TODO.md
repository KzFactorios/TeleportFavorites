-- This is a work in progress

# TODOs for TeleportFavorites
- [TeleportFavorites GUI Experiments (Copilot Space)](https://github.com/copilot/spaces/kurtzilla/1)  

<!--
  This file tracks outstanding tasks, design notes, and technical debt for the TeleportFavorites mod.
  Please keep entries concise and actionable. Use checkboxes for task tracking.
  When adding new items, prefer actionable language and reference relevant modules/files if possible.
-->

- [ ] Review and finalize all custom button styles for the tag editor GUI, ensuring vanilla-like appearance and consistent sizing/alignment. 
- [ ] Change the color of the teleport button in the tag_editor
- [ ] Test the ft_teleport_button with parent = "confirm_button" and minimal overrides for best vanilla look.
- [ ] Confirm that all label widths and alignments are consistent across the tag editor dialog.
- [ ] Add more unit tests for helpers and GUI logic as the project matures.
- [ ] Implement GUI desync detection and recovery (see notes/specs_after_agent_discussion.md).
- [ ] Add localization for any new user-facing strings.
- [ ] Document any further style or layout tweaks in this file for future reference.
- [ ] Test for the display of unforeseen large strings (e.g., player names, chart tag text). Limit string length in GUI where appropriate.
- [ ] Check limits on size for chart tag text and enforce in GUI logic/helpers. Set the limit to 1024 chars, but make this a constant variable
- [ ] Check for map editor functionality and ensure compatibility.
- [ ] When a chart_tag is destroyed, ensure it destroys any linked tags (and vice versa). Refactor tag<->chart_tag destruction logic to a shared helper if possible.
- [ ] Multiplayer: test and document tag ownership edge cases.
- [ ] Match vanilla styling for delete and move button in the tag editor.
- [ ] Player favorites should mimic a first-in last-out (FILO) pattern. If trimming is needed, remove last-in items first to preserve oldest entries.
- [ ] In control.lua.events.on_player_changed_surface, event.surface_index is not guaranteed. Use player.surface.index for the new surface.
- [ ] Handle events from the vanilla tag editor and ensure mod GUI stays in sync.
- [ ] allow a creator of a tag to be able to allow(or not) the favoriting of the tag by other players
- [x] Clarify and document that GPS must always be a string in the format 'xxx.yyy.s', never a table. Update README, gps_helpers.lua, and favorite.lua with explicit rules and examples.
- [ ] Ensure that the tag editor's close button doesn't close the data viewer and vice versa. The titlebar close buttons are named the same. 
- [ ] Check for conflicts with other mods. Especially with all those buttons in the top gui. Find alternative display locations?
- [ ] Destination messages setting in game? switch to fly aways?
- [ ] 