# Tag Editor GUI Behavior and Rules

The tag editor is a modal GUI for creating, editing, moving, and deleting map tags and their associated favorites. It is designed for multiplayer, surface-aware, and robust operation, and should closely mimic the vanilla "add tag" dialog in Factorio 2.0, with additional features for favorites and tag management. The GUI is built using the builder pattern for construction and the command pattern for user/event handling. It is auto-centered, screen-anchored, and only active in chart or chart_zoomed_in modes (except when opened from the favorites bar in game mode).

```
┌─────────────────────────────────────────────────────────┐
│  Tag Editor                                       [X]   │
├─────────────────────────────────────────────────────────┤
│  Owner: Engineer1                       [Move] [Delete] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [★] [Teleport]                                        │
│                                                         │
│  [Icon] [                Text Input                  ]  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Error message appears here when needed                 │
├─────────────────────────────────────────────────────────┤
│                                          [Confirm]      │
└─────────────────────────────────────────────────────────┘

Button States:
┌─────────────────┬─────────────────────────────────────┐
│     Button      │         Enabled When                │
├─────────────────┼─────────────────────────────────────┤
│ Close [X]       │ Always                              │
│ Move            │ Player is owner & in chart mode     │
│ Delete          │ Player is owner & no other favs     │
│ Favorite [★]    │ Always or when slots available      │
│ Teleport        │ Always                              │
│ Icon            │ Player is owner                     │
│ Text Input      │ Player is owner                     │
│ Confirm         │ Icon set OR text not blank          │
└─────────────────┴─────────────────────────────────────┘
```

## Storage as Source of Truth Pattern

**CRITICAL:** The tag editor follows the "storage as source of truth" pattern. All GUI state is stored in `tag_editor_data` and immediately persisted on any user input change.

### Core Rules:
1. **Never read from GUI elements** - always read from `tag_editor_data`
2. **Immediately save user input** to `tag_editor_data` via event handlers
3. **UI elements display storage values** - they are write-only from user perspective
4. **All business logic** operates on `tag_editor_data`, never GUI state

### Implementation:
- **Text changes**: `on_gui_text_changed` → immediate save to `tag_editor_data.text`
- **Icon selection**: `on_gui_elem_changed` → immediate save to `tag_editor_data.icon`
- **Favorite toggle**: Button click → toggle `tag_editor_data.is_favorite` → refresh UI
- **Confirm action**: Use values from `tag_editor_data` directly, never read from GUI

### Benefits:
- Eliminates GUI/data sync issues
- Prevents nil reference errors
- Provides immediate data persistence
- Simplifies multiplayer state management
- Enables reliable undo/redo functionality

## Core Features and Interactions
- **Builder/Command Patterns:** Use builder pattern for GUI construction and command pattern for all user/event interactions.
- **Styling:** Mimic vanilla "add tag" dialog, omitting the snap_position editor. Use vanilla styles, spacing, and iconography where possible.
- **Modal Behavior:** Mouse clicks outside the tag editor's outer frame are ignored. ESC closes the GUI. The "e" key, when no fields are focused, confirms and saves/closes the dialog.
- **Lifecycle:**
  - If the editor remains open after switching to game mode (not from the favorites bar), it self-closes after 30 ticks via on_tick. The on_tick event is unregistered on close.
  - On open, set `player.opened` to enable ESC to close the GUI.
- **Button Enablement:**
  - Only certain buttons are enabled depending on the player and tag state (see below).
  - The close button is always enabled and closes the dialog without saving.
  - The move button is only enabled in chart mode and when the current player is the last user (or last_user is nil/empty). Clicking it enters move_mode, allowing the user to pick a new location. Right-click cancels move_mode. Left-click attempts to move the tag and all linked favorites, validating the new location. If valid, updates all relevant objects and reopens the dialog at the new location.
  - The delete button is enabled only if the current player is the last user and no other players have favorited the tag. Clicking it asks for confirmation, then deletes the tag, chart tag, and resets all linked favorites.
  - The teleport button is always enabled (background orange). Clicking it teleports the player and closes the dialog, unless there is an error (which is shown in the error message label).
  - The favorite button is always available. Its state is tied to `is_player_favorite`. If true, shows a green checkmark; if false, no icon. Clicking toggles the state, but changes are only saved on confirm.
  - The icon button shows the current icon or blank. Clicking opens the signalID selector. Selecting a signal saves the icon and closes the selector. The value is saved to the tag/chart_tag on confirm or during move_mode.
  - The text box reflects `tag.chart_tag.text` and records input back to that field. Max length is 256 chars (see `constants.settings`). Validator trims right whitespace and checks length before saving. Shows an error if exceeded.
  - The cancel button is always enabled and closes the dialog without saving.
  - The confirm button is enabled if either the icon is set or the trimmed text box is not blank. Clicking validates and saves all fields, closes the dialog if valid, or shows an error if not.
- **last_user:** If `last_user` is empty, any changes record the current player as the new last_user.

## Button Enablement Logic
- If `player == tag.chart_tag.last_user` (by name) or `last_user` is nil/empty:
  - Enable: move, delete, icon, and text box buttons.
- The move button is only enabled in chart mode and when above conditions are met.
- The delete button is only enabled if the tag is not favorited by any other player.

## Move Mode
- Clicking the move button enters move_mode, changing the cursor to indicate selection. Right-click cancels move_mode. Left-click attempts to move the tag and all linked favorites, validating the new location. If valid, updates all relevant objects and reopens the dialog at the new location. If not valid, plays a beep and remains in move_mode.

## Teleport Button
- Always enabled. Clicking teleports the player to the tag location and closes the dialog. If teleport fails, shows an error and keeps the dialog open.

## Favorite Button
- The favorite button should always be enabled, except in the case when a player already has Constants.settings.MAX_FAVORITE_SLOTS non-blank favorites.  An easier way to manage the enablement is to ask if the current tag is_player_favorite, then the button should be enabled, otherwise it is only enabled if the player has favorit_slots_available == true (count of blank favorites in the collection > 0 == true ) 

10 If the players non-blank favorites are = to the constant specified, then the button should be di State is tied to `is_player_favorite`. Clicking toggles the state, but changes are only saved on confirm.

## Icon Button
- Shows current icon or blank. Clicking opens the signalID selector. Selecting a signal saves the icon and closes the selector. Value is saved on confirm or during move_mode.

## Text Box
- Reflects `tag.chart_tag.text`. Max length is 256 chars (see `constants.settings`). Validator trims right whitespace and checks length before saving. Shows an error if exceeded.

## Confirm/Cancel Buttons
- Cancel always enabled, closes dialog without saving.
- Confirm enabled if icon is set or trimmed text is not blank. Clicking validates and saves all fields, closes dialog if valid, or shows an error if not.

---
## Open Questions / Missing Functionality

1. **Undo/Redo Support:** Should the tag editor support undo/redo for text or icon changes before confirmation?
Absolutely!
2. **Keyboard Navigation:** Are there keyboard shortcuts for moving between fields, or for toggling favorite/move modes?
it would be great if the tab key facilitated moving through focusing the next field and shift-tab the opposite.
nothing for toggling favorite or move_mode
3. **Accessibility:** Should the GUI provide tooltips, ARIA labels, or other accessibility features for visually impaired users? Yes, for now, unless already mentioned, tootltips should be used to reflect the value of their controls or input is such
4. **Multiplayer Race Conditions:** How should the editor handle cases where another player modifies or deletes the tag while the dialog is open?
whoever is first to successfully save to storage wins. the loser should be shown an error that they lost. Howevere, because the player=last_user state should ward off virtually all race-conditions
5. **Concurrent Edits:** What happens if two players edit the same tag at the same time? Is there a locking or merge strategy?
-- se above
6. **Tag Color/Style:** Is there a way to customize the color or style of a tag beyond the icon and text?
no at this time
7. **Error Handling Granularity:** Should errors be shown per-field (inline) or only in the error row? Should errors be cleared automatically on input change?
only in the error row and should be cleared on input change
8. **Localization:** Are all user-facing strings (including error messages) localized and translatable?
we will handle localization at another time
9. **History/Audit Trail:** Should changes to tags (text, icon, location, last_user) be logged for audit/history purposes?
-- yes. it should be simple stuff and not each up much in the log file. is it acceptable to use factorio-current.log for this or should we create our own file? what does everyone else do :)?
10. **Favorite Limit Enforcement:** Is there a maximum number of favorites per player, and is this enforced/communicated in the UI?
I have rewritten the rules and explanation for this. Please let me know if the new explanation is adequate
11. **Tag Sharing:** Can tags be shared or transferred between players, or are they strictly per-user?
tags are strictly per-user in the sense that the icon be changed or the text updated only by the player == last_user of the associated chart_tag. If there is no last_user, assign the current player to last_user (and this should enable the fields forr editing). All other players can favorite an existing tag.
Disabled controls should reflect that  staus in the styling
12. **Chart Tag Sync:** How is the chart tag kept in sync with the tag editor and player favorites if changes are made outside the editor?
it is possible that a data error or sync issue could occur while the tag editor is open. In the past, we had tracked the tag_editor_positions per player. Looking at this question I think that wee could just expand on this concept and use the tag_editor_positions storage object to hold all of the current input field data for the editor and clear it out, for the playerss index, when  the tag editor is closed. So let's implement that strategy and at the same time rename the tag_editor_positions collection to tag_editor_data. the key/value should be located at storage.players[player_index].tag_editor_data
13. **GUI Scaling:** Does the tag editor scale properly with different screen resolutions and UI scales? the tag editor should scale properly with different screen resolutions an UI scales. Correct me if I use styling that goes against achieving this goal
14. **Input Validation:** Are there additional validation rules for text (e.g., forbidden characters, profanity filter)?
not yet. 
15. **Move Mode Feedback:** Is there visual feedback (cursor, highlight) when in move_mode, and is it clear when move_mode is active? This is something I neeed your help. Research to see if you can find out how others have done similar things. My thought was that at least the cursor or something held by the currsor stack should be displayed/animated/etc to visually display the fact that we are in move mode.
16. **Favorite State Persistence:** If the dialog is closed without confirming, is the favorite state reverted or left as-is? The state of the data is not persisted until the confirm button has been clicked and everything goes successfully
17. **Performance:** Are there any performance concerns with large numbers of tags or favorites in multiplayer?
I am pretty sure we have some mapping structures in place for the fastest possible access to surface chart_tags and tags
18. **Mod Compatibility:** Are there known compatibility issues with other mods that modify tags or the map GUI?
not at this time, however, I have heard of some conflicts with "Map Editor" or similar. We will address as progress occurs, but if you see a known conflict with another mod, or bad-practice, please let me know.
19. **Tag Expiry/Auto-Removal:** Should tags have an expiry or auto-removal mechanism (e.g., after X days or if unused)?
No. the tags cache should be refreshed after a player makes an edit or creates or deletes a tag. The chart_tag cache should be rest whenever a new chart_tag is added or update, etc
20. **Custom Signals:** Can custom signals (beyond vanilla) be used as icons, and how are they handled?
Yes, allow whatever signals are available in the current game. If a mod change removes a signal or some other game changes the availability or validty of a signal, then the signal should be set to nil or empty table

---
## Additional Open Questions / Considerations

21. **Tag Deletion Confirmation:** Should there be an option to undo a tag deletion immediately after confirming, or is deletion always final? No there shouldn't be a need to confirm as hitting the delete button, which brings up a confirmation dialog, should handle this. if the deletion is confirmed then, if valid for deletion, the tag will be immediately deleted and the confirmation dialog and the tag editor should be closed. If the dlete confirmation is negative, than the confirmation should be closed and the tag_editor, already open with it's current data should be remained open. The confirmation dialog should also set player.opened correctly
22. **Favorite Button Disabled State:** Should the favorite button show a tooltip or message when disabled due to reaching the favorite slot limit? tooltip
23. **Chart Tag/Tag Data Migration:** If the tag schema changes in a future version, how should migration of tag_editor_data and chart_tag data be handled? we are not concerning ourseleves with migrations just yet
24. **Signal Selector Usability:** Should the signal selector for the icon button support search/filtering for large modded signal lists? absolutely
25. **Tag Editor Re-entrancy:** Can the tag editor be opened for multiple tags at once (e.g., by different scripts or hotkeys), or is it strictly single-instance per player? strict single-instance for player. thee confirmation dialog should open in a layer over the tag editor
26. **Player Disconnect Handling:** If a player disconnects with the tag editor open, should their tag_editor_data be cleared immediately or on reconnect? The tag_editor should be closed, which should also clear any data. ensure the data is reset (or rather the player's entry in the tag_editor_data is set to nil)
27. **Tag Editor API Exposure:** Should there be a remote interface or API for other mods to open/close the tag editor or interact with its data? no
28. **Input Method Support:** Is the tag editor usable with gamepads or other non-mouse input devices? I am not sure and this will have to be tested separately at another time. Follow best practices and know fixes and idiomatic methods to resolve this. Let me know when I am creating conflicts to that goal
29. **Tag Editor Analytics:** Should usage of the tag editor (opens, edits, deletes) be tracked for analytics or debugging? Not at this time
30. **Error Recovery:** If a runtime error occurs while the tag editor is open, is there a recovery or auto-close strategy to prevent UI lockup? No, but we should emplore a way to handle

---

# Tag Editor GUI Hierarchy (Updated)

```
tag_editor_outer_frame (frame, vertical, tf_tag_editor_outer_frame)
├─ tag_editor_titlebar (flow, horizontal)
│  ├─ tag_editor_title_label (label)
│  └─ tag_editor_title_row_close (button)
├─ tag_editor_content_frame (frame, vertical, tf_tag_editor_content_frame)
│  ├─ tag_editor_owner_row_frame (frame, horizontal, tf_owner_row_frame)
│  │  ├─ tag_editor_label_flow (flow, horizontal)
│  │  │  └─ tag_editor_owner_label (label, tf_tag_editor_owner_label)
│  │  └─ tag_editor_button_flow (flow, horizontal)
│  │     ├─ tag_editor_move_button (icon-button, tf_move_button)
│  │     └─ tag_editor_delete_button (icon-button, tf_delete_button)
│  └─ tag_editor_content_inner_frame (frame, vertical, tf_tag_editor_content_inner_frame)
│     ├─ tag_editor_teleport_favorite_row (frame, horizontal, tf_tag_editor_teleport_favorite_row)
│     │  ├─ tag_editor_is_favorite_button (icon-button, tf_slot_button)
│     │  └─ tag_editor_teleport_button (icon-button, tf_teleport_button)
│     ├─ tag_editor_rich_text_row (flow, horizontal)
│     │  ├─ tag_editor_icon_button (choose-elem-button, tf_slot_button)
│     │  └─ tag_editor_rich_text_input (textbox, tf_tag_editor_text_input)
├─ tag_editor_error_row_frame (frame, vertical, tf_tag_editor_error_row_frame) [conditional]
│  └─ error_row_error_message (label, tf_tag_editor_error_label)
└─ tag_editor_last_row (frame, horizontal, tf_tag_editor_last_row)
   ├─ tag_editor_last_row_draggable (empty-widget, tf_tag_editor_last_row_draggable)
   └─ tag_editor_confirm_button (button, tf_confirm_button)
```

```
┌────────────────────────────────────────────────────────┐
│              Tag Editor Event/Data Flow                │
├───────────────┐                   ┌───────────────────┐
│  GUI Element  │                   │  tag_editor_data  │
│  Interactions │                   │  (Storage)        │
├───────────────┘                   └───────────────────┘
│                                                        │
│  ┌─────────────┐     ┌─────────────────┐    ┌────────┐ │
│  │ User Input  │────>│ Event Handler   │───>│ Save   │ │
│  │             │     │                 │    │ to     │ │
│  └─────────────┘     └─────────────────┘    │Storage │ │
│                                             └───┬────┘ │
│  ┌─────────────┐     ┌─────────────────┐        │      │
│  │ UI Updated  │<────│ Business Logic  │<───────┘      │
│  │             │     │                 │               │
│  └─────────────┘     └─────────────────┘               │
└────────────────────────────────────────────────────────┘
```

- The error row only appears when `tag_data.error_message` exists and is non-empty.
- The favorite button is at the head of the teleport row.
- All element names use the `{gui_context}_{purpose}_{type}` convention.

---

## Naming Convention and Enforcement

All tag editor GUI element names use the `{gui_context}_{purpose}_{type}` naming convention. This ensures clarity and robust event filtering. Example element names:
- `tag_editor_outer_frame` (frame)
- `tag_editor_move_button` (icon-button)
- `tag_editor_rich_text_input` (textbox)
- `tag_editor_error_label` (label)

This convention is strictly enforced in both code and documentation. All event handler logic checks for these names to ensure robust domain filtering.

---

## Event Filtering and Handling

```
┌─────────────────────────────────────────────────────────┐
│                   Event Handling Flow                   │
├─────────────────┬─────────────────────┬─────────────────┤
│ Event Received  │  Element Name Check │  Player Context │
│                 │   tag_editor_*      │     Check       │
└─────────┬───────┴──────────┬──────────┴────────┬────────┘
          │                  │                   │
          v                  v                   v
┌─────────────────────────────────────────────────────────┐
│                 Command Pattern Handler                 │
│                                                         │
│  Each user action = One command object                  │
│  Each command validates context/state                   │
│  Surface-aware execution                                │
│  Multiplayer-safe operations                            │
└─────────────────────────────────────────────────────────┘
```

The tag editor uses robust event filtering:
- All event handlers check the element name prefix (`tag_editor_`) to ensure only relevant events are processed.
- Only events for the current player's tag editor instance are handled.
- The command pattern is used for all user/event interactions, with each command handler responsible for validating context and state before acting.
- Event handlers are modular and surface-aware, preventing cross-GUI event leakage and multiplayer desyncs.

---

## Builder/Command Pattern and Modularity

- The tag editor GUI is constructed using the builder pattern, ensuring modular, maintainable, and testable code.
- All user interactions and events are handled via the command pattern, with each command encapsulating a single user action (e.g., move, delete, confirm, favorite toggle).
- GUI logic is separated into modular files under `gui/tag_editor/` and `core/control/control_tag_editor.lua`.
- Shared logic and helpers are placed in `core/utils/`.

---

## Best Practices & Design Rules (Updated)

- All user-facing strings and tooltips are localizable.
- Error messages are shown only in the error row and cleared on input change.
- Accessibility: All controls have tooltips reflecting their value or purpose.
- Keyboard navigation: Tab/Shift-Tab moves focus between fields; ESC closes the dialog; E confirms if no field is focused.
- Only the owner (or if last_user is nil/empty) can edit, move, or delete a tag.
- All persistent state is stored in `storage.players[player_index].tag_editor_data` and cleared on close.
- The error row is conditional and only appears when `tag_data.error_message` is non-empty.
- The GUI scales with UI scale and resolution.

---

## Archived/Resolved Open Questions

- Undo/redo, accessibility, multiplayer race conditions, and favorite slot enforcement are now fully documented and implemented as described above.
- For any new open questions, see the end of this file.

---