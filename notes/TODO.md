-- This is a work in progress

# TODOs for TeleportFavorites


- [ ] Review and finalize all custom button styles for the tag editor GUI, ensuring vanilla-like appearance and consistent sizing/alignment. 
- [ ] Change the color of the teleport button in the tag_editor
- [ ] Test the ft_teleport_button with parent = "confirm_button" and minimal overrides for best vanilla look.
- [ ] Confirm that all label widths and alignments are consistent across the tag editor dialog.
- [ ] Add more unit tests for helpers and GUI logic as the project matures.
- [ ] Implement GUI desync detection and recovery (see notes/specs_after_agent_discussion.md).
- [ ] Add localization for any new user-facing strings.
- [ ] Document any further style or layout tweaks in this file for future reference.
- [ ] Test for the display of unforeseen large strings - player names, 
- [ ] Check limits on size for chart tag text
- [ ] Check for map editor functionality
- [ ] When a chart_tag is destroyed, it should destroy any linked tags
- [ ] When a tag is destroyed, it should destroy any linked chart_tags
- [ ] Multiplayer: play around with ownership of tags
- [ ] Match vanilaa styling for delete and move button in the TE
- [ ] If it possible that the tag_editor can be available when the game starts then we may need to persist the tag_editor_positions 
- [ ] Player favorites mimic a first-in last-out (FILO) pattern. If for some reason we need to trim the list, the last in items go first. This will preserve the longest lasting members
- [ ] In control.lua.events.on_player_changed_surface, event.surface_index is not guaranteed. Ensure that player.surface.index indicates the new surface
- [ ] Handle events from the vanilla tag editor