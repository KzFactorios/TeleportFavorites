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
│ Favorite [★]   │ Always or when slots available      │
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
