# Tag Editor Workflow: Right-Click to Tag Editor Opening

This document outlines the complete workflow from the moment a player right-clicks on the Factorio map to the moment the tag editor is opened. This helps in understanding the event flow and processes involved in the TeleportFavorites mod.

## Visual Workflow Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│                 │       │                 │       │                 │
│  Player Right   │       │   Custom Input  │       │ Event Handler   │
│  Click on Map   ├──────►│   Event Fired   ├──────►│ Validation      │
│                 │       │                 │       │                 │
└─────────────────┘       └─────────────────┘       └────────┬────────┘
                                                             │
                                                             ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│                 │       │                 │       │                 │
│  Modal Dialog   │       │  GUI Elements   │       │  Tag Data       │
│  Presentation   │◄──────┤  Construction   │◄──────┤  Preparation    │
│                 │       │                 │       │                 │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

## 1. Custom Input Registration

### 1.1 Input Definition
- The mod first defines a custom input for right-clicking in `data.lua`:
```lua
{
  type = "custom-input",
  name = "tf-open-tag-editor",
  key_sequence = "mouse-button-2",  -- Right mouse click
  consuming = "none",               -- Doesn't consume event (allows vanilla handlers to also process it)
  order = "ba[tag-editor-1]",
  localised_name = {"shortcut-name.open-tag-editor"},
  localised_description = {"shortcut-description.open-tag-editor"}
}
```
- The `consuming = "none"` parameter is particularly important as it allows both this mod and vanilla Factorio to respond to the right-click event

### 1.2 Event Registration
- In `control.lua`, the mod registers a handler for this custom input:
```lua
script.on_event("tf-open-tag-editor", handlers.on_open_tag_editor_custom_input)
```

## 2. Right-Click Event Handling

### 2.1 Initial Validation
When a player right-clicks on the map, Factorio triggers the custom input event, which is handled in `core/events/handlers.lua`:

1. The handler first retrieves the player object from the event data
2. Validates that the player object is valid
3. Checks if the player is in chart mode (map view) - returns if not in chart or zoomed chart mode
4. Verifies that the tag editor isn't already open - exits if it is
5. Gets the surface and cursor position information

### 2.2 Position Processing & Normalization
After validation, the handler processes the position data through a complex normalization pipeline:

1. Retrieves the cursor's position from the event data (`event.cursor_position`)
2. Converts the raw position to a canonical GPS string format using:
   ```lua
   local normalized_gps = gps_parser.gps_from_map_position(cursor_position, player.surface.index)
   ```
   - This creates a GPS string in the format `xxx.yyy.s` where x/y are padded and s is the surface index 

#### Position Normalization Flow Diagram

```
                   ┌───────────────────┐
                   │   Right Click     │
                   │ cursor_position   │
                   └─────────┬─────────┘
                             │
                             ▼
                   ┌───────────────────┐
                   │    Convert to     │
                   │     GPS string    │
                   └─────────┬─────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────┐
│          normalize_landing_position_with_cache    │
│                                                   │
│  ┌─────────────────────┐                          │
│  │ Context Validation  │                          │
│  └──────────┬──────────┘                          │
│             │                                     │
│             ▼                          YES        │
│  ┌─────────────────────┐      ┌──────────────┐   │
│  │   Exact Match?      ├─────►│ Use existing │   │
│  └──────────┬──────────┘      │ tag/chart tag│   │
│             │ NO              └──────────────┘   │
│             ▼                                    │
│  ┌─────────────────────┐      ┌──────────────┐   │
│  │ Check Nearby Tags?  ├─────►│ Use nearby   │   │
│  └──────────┬──────────┘ YES  │ tag/chart tag│   │
│             │ NO              └──────────────┘   │
│             ▼                                    │
│  ┌─────────────────────┐                         │
│  │   Grid Snap Check   │                         │
│  │                     │                         │
│  │ Create/align chart  │                         │
│  │ tag to ensure whole │                         │
│  │ number coordinates  │                         │
│  └──────────┬──────────┘                         │
│             │                                    │
│             ▼                                    │
│  ┌─────────────────────┐                         │
│  │ Favorite Check      │                         │
│  └──────────┬──────────┘                         │
│             │                                    │
└─────────────┼────────────────────────────────────┘
              │
              ▼
  ┌───────────────────────────┐
  │  Return normalized data:  │
  │  - Position (nrm_pos)     │
  │  - Tag object (nrm_tag)   │
  │  - Chart tag (nrm_chart)  │
  │  - Favorite (nrm_favorite)│
  └───────────────────────────┘
```

3. Performs deep normalization via `gps_helpers.normalize_landing_position_with_cache()`, which:
   
   a. **Context Validation**: Validates player and GPS string
      - Checks if player reference is valid
      - Ensures GPS string is valid and not empty
      - Retrieves player's teleport radius setting (used for nearby searches)
   
   b. **Exact Match Search**: Looks for exact matches at the clicked position
      - Checks if there's an existing tag object at this exact GPS coordinate
      - If found, retrieves associated chart tag and uses its position
      - If not, checks if there's a standalone chart tag at this position
     c. **Nearby Match Search**: If no exact match, searches for nearby tags/chart tags
      - Uses player's teleport radius setting to define the search area
      - Calls `Helpers.get_nearest_tag_to_click_position()` to find the closest chart tag
      - If found, gets associated tag object or uses the standalone chart tag
   
   d. **Grid Snap Processing**: Ensures positions align to the grid
      - If tag exists but chart tag doesn't, creates a new chart tag
      - If chart tag exists, ensures its coordinates are whole numbers via `align_chart_tag_position()`
      - If neither exists, creates a temporary chart tag to validate the position
        - Checks if position can be tagged (charted, not water or space)
        - Gets the adjusted position from the temporary tag
        - Destroys the temporary tag as it will be properly created later

   e. **Favorites Association**: Checks if position is a player favorite
      - Associates any matching player favorites with the position

4. Returns the following normalized data or exits if normalization failed:
   - `nrm_pos`: Normalized position coordinates (whole-number aligned)
   - `nrm_tag`: Associated Tag object (if any)
   - `nrm_chart_tag`: Associated ChartTag object (if any)
   - `nrm_favorite`: Associated player favorite (if any)

### 2.3 Tag Data Preparation
The handler then uses the normalized data to prepare the tag editor data structure:

1. Creates a final GPS string from the normalized position using:
   ```lua
   local gps = gps_helpers.gps_from_map_position(nrm_pos, surface_id)
   ```

2. Creates tag editor data structure with `Cache.create_tag_editor_data()` containing:
   - `gps`: Canonical GPS coordinate string (e.g., `123.456.1`)
   - `locked`: Whether the favorite is locked (`nrm_favorite.locked` or `false`)
   - `is_favorite`: Whether this is a favorite for the player (`nrm_favorite ~= nil`)
   - `icon`: Chart tag icon or empty string (`nrm_chart_tag.icon or ""`)
   - `text`: Chart tag text or empty string (`nrm_chart_tag.text or ""`)
   - `tag`: Reference to existing Tag object (`nrm_tag or nil`)
   - `chart_tag`: Reference to existing ChartTag object (`nrm_chart_tag or nil`)

3. Stores this tag data in the player's cache using:
   ```lua
   Cache.set_tag_editor_data(player, tag_data)
   ```

The data structure follows this pattern:
```lua
{
  gps = "123.456.1",            -- Canonical GPS string (x.y.surface)
  locked = false,               -- Is the favorite locked?
  is_favorite = true,           -- Is this a favorite for the player?
  icon = "signal-A",            -- Icon name or object
  text = "My location",         -- Text for the tag
  tag = {...},                  -- Reference to existing Tag object
  chart_tag = {...},            -- Reference to existing LuaCustomChartTag
  move_mode = false,            -- Indicator if tag is in move mode
  error_message = nil,          -- Error message to display (if any)
  move_gps = ""                 -- Temporary GPS during move operations
}
```

#### Tag Editor Data Storage

The tag editor data is stored in the player's cache using the "storage as source of truth" pattern:

1. Initial creation:
   ```lua
   local tag_data = Cache.create_tag_editor_data({
     gps = gps,
     locked = nrm_favorite and nrm_favorite.locked or false,
     is_favorite = nrm_favorite ~= nil,
     icon = nrm_chart_tag and nrm_chart_tag.icon or "",
     text = nrm_chart_tag and nrm_chart_tag.text or "",
     tag = nrm_tag or nil,
     chart_tag = nrm_chart_tag or nil
   })
   Cache.set_tag_editor_data(player, tag_data)
   ```

2. Retrieval during GUI construction:
   ```lua
   local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
   ```

3. Updates during user interaction:
   ```lua
   local tag_data = Cache.get_tag_editor_data(player) or {}
   tag_data.text = (element.text or ""):gsub("%s+$", "") -- Trim trailing whitespace
   Cache.set_tag_editor_data(player, tag_data)
   ```

4. Cleanup on close:
   ```lua
   Cache.set_tag_editor_data(player, {})
   ```

#### Position Validation Rules

The normalization process ensures only valid positions can be tagged. A position is considered valid if:

1. **Player Permission Checks**
   - Player must have a valid force and surface 
   - `player.force.is_chunk_charted` must be callable

2. **Chunk Charting Requirement**
   ```lua
   local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
   if not player.force.is_chunk_charted(player.surface, chunk) then
     -- Error: Cannot tag uncharted territory
     return false
   end
   ```

3. **Terrain Restrictions**
   ```lua
   -- Cannot tag water or space tiles
   if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
     -- Error: Cannot tag water or space
     return false
   end
   ```

4. **Chart Tag Validation**
   - Creates a temporary chart tag to test if Factorio's API allows tagging
   - Destroys this tag if validation fails

This complex normalization process ensures that:
1. Tags align properly to the game's grid system (whole numbers only)
2. Existing tags and chart tags are properly associated
3. Nearby tags are found if the player didn't click exactly on a tag
4. Only valid positions that can be tagged are processed
5. All related objects (tags, chart tags, favorites) are properly linked

## 3. Tag Editor GUI Construction

### 3.1 Initialization
The `tag_editor.build(player)` function then:

1. Retrieves the tag data from the player's cache
2. Destroys any existing tag editor frame for the player
3. Creates a new outer frame for the tag editor with auto-centering

### 3.2 GUI Component Building
The tag editor GUI is built using modular components:

1. `build_titlebar`: Creates the title bar with the "Tag Editor" label and close button
2. `build_owner_row`: Creates the owner label, move button, and delete button
3. `build_teleport_favorite_row`: Creates teleport and favorite toggle buttons
4. `build_rich_text_row`: Creates text input field and icon selection button
5. `build_error_row`: Creates container for error messages
6. `build_last_row`: Creates confirm and cancel buttons

The complete GUI hierarchy follows this structure:

```
tag_editor_outer_frame (frame, vertical, tf_tag_editor_outer_frame)
├─ tag_editor_titlebar (flow, horizontal)
│  ├─ (title label)
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
└─ tag_editor_last_row (flow, horizontal)
   ├─ tag_editor_last_row_draggable (empty-widget, tf_tag_editor_last_row_draggable)
   └─ last_row_confirm_button (button, tf_confirm_button)
```

Each element follows a consistent naming pattern of `tag_editor_{purpose}_{type}` for clarity and robust event handling.

### 3.3 UI State Setup
After building all UI components:

1. The `setup_tag_editor_ui` function configures the state of all UI elements:
   - Determines ownership status and edit permissions
   - Sets button states based on ownership and current tag status:
     - Move button: enabled only if player is owner AND in chart mode
     - Delete button: enabled only if player is owner AND no other players have favorited the tag
     - Confirm button: enabled only if text input has content OR icon is selected
     - Favorite button: state reflects current favorite status
     - Teleport button: always enabled
   - Configures tooltips for all interactive elements
   - Applies visual indication for move mode (if active)
   - Sets up error message display (if applicable)

### 3.4 Modal Dialog Configuration
Finally, the tag editor is configured as a modal dialog:

1. Sets `player.opened` to the tag editor frame, making it modal
2. This enables ESC to close the dialog and focuses user interaction on it
3. Makes the frame auto-centered on the screen with `tag_editor_outer_frame.auto_center = true`
4. Configures the titlebar to be draggable, allowing users to reposition the dialog

## 4. Event Handlers for Tag Editor

After the tag editor is open, these event handlers are ready to process user interactions:

### 4.1 Button Event Handlers
The tag editor implements several command handlers for button interactions:

- `handle_confirm_btn`: Saves changes to tag text, icon, and favorite status
  1. Validates input (text length, non-empty requirement)
  2. Updates tag and chart tag fields
  3. Updates favorite state if changed
  4. Notifies observers of tag creation or modification
  5. Closes the tag editor and cleans up

- `handle_move_btn`: Activates move mode for tag repositioning
  1. Sets `tag_data.move_mode = true`
  2. Shows guidance message in error area
  3. Registers area selection event handlers
  4. Visually indicates move mode is active
  5. When location selected: updates position, refreshes UI or closes dialog

- `handle_delete_btn`: Opens confirmation dialog for tag deletion
  1. Creates a modal confirmation dialog
  2. Registers confirm/cancel handlers
  3. On confirm: deletes tag, chart tag, resets favorites, closes dialog
  4. On cancel: returns to tag editor without changes

- `handle_favorite_btn`: Toggles favorite status of the tag
  1. Toggles `tag_data.is_favorite` value
  2. Updates cache with `Cache.set_tag_editor_data(player, tag_data)`
  3. Refreshes UI to reflect new state
  4. Notifies observers of change (not persisted until confirm)

- `handle_teleport_btn`: Teleports player to tag location
  1. Uses `Helpers.safe_teleport(player, tag_data.pos)`
  2. Closes tag editor on success
  3. Shows error message on failure

### 4.2 Input Handlers
- `on_tag_editor_gui_text_changed`: Handles text input changes:
  ```lua
  function on_tag_editor_gui_text_changed(event)
    local element = event.element
    if element.name == "tag_editor_rich_text_input" then
      local tag_data = Cache.get_tag_editor_data(player) or {}
      tag_data.text = (element.text or ""):gsub("%s+$", "") -- Trim trailing whitespace
      Cache.set_tag_editor_data(player, tag_data)
      -- Update confirm button state based on new text content
      tag_editor.update_confirm_button_state(player, tag_data)
    end
  end
  ```
- `on_gui_elem_changed`: Handles icon selection:
  ```lua
  -- When icon selection changed - immediately save to storage
  local new_icon = element.elem_value or element.signal or ""
  tag_data.icon = new_icon
  Cache.set_tag_editor_data(player, tag_data)
  -- Update confirm button state based on new icon selection
  tag_editor.update_confirm_button_state(player, tag_data)
  ```

### 4.3 Close Handlers
- Handles ESC key through the `on_gui_closed` event
- Properly cleans up data and UI elements when closing
- The `close_tag_editor(player)` function performs these steps:
  1. Clears tag editor data from cache with `Cache.set_tag_editor_data(player, {})`
  2. Finds the tag editor frame using `Helpers.find_child_by_name()`
  3. Destroys the frame if found
  4. Sets `player.opened = nil` to restore normal input handling

## 5. Command Pattern Implementation

The mod uses the command pattern for all user interactions:

1. Each button click creates a specific command object
2. Commands encapsulate actions, validation, and state changes
3. A command manager executes commands and maintains history for undo functionality
4. Event dispatchers route events to appropriate command handlers

### 5.1 Event Dispatcher System

The event handling system follows a hierarchical approach:

```
Factorio Input Event
      │
      ▼
Event Dispatcher
      │
      ├─────► Element Name Filter (tag_editor_*)
      │
      ├─────► Player Index Check
      │
      └─────► Command Handler Routing
                     │
                     ▼
           ┌─────────────────┐
           │                 │
           │ Command Handler │
           │                 │
           └─────────────────┘
                     │
                     ▼
          Update Tag Editor Data
                     │
                     ▼
           Refresh UI (if needed)
```

This dispatcher system ensures that:
1. Only relevant events for the tag editor are processed
2. Each player's commands are isolated from others (multiplayer safety)
3. Command execution follows a consistent pattern
4. UI updates reflect the current state of the tag editor data

## Workflow Summary

1. **User Action**: Player right-clicks on Factorio map
2. **Event Triggering**: Custom input event "tf-open-tag-editor" fires
3. **Validation**: Ensure proper rendering mode and conditions are met
4. **Data Preparation**: Collect and organize tag data from the clicked position
5. **UI Construction**: Build modular tag editor UI components
6. **State Setup**: Configure UI elements based on tag state and permissions
7. **Modal Presentation**: Present the tag editor as a modal dialog to the player
8. **Interactive Mode**: User can now interact with the tag editor

This workflow ensures proper validation, state management, and user experience throughout the tag creation and editing process.

## Key Implementation Patterns

### Storage as Source of Truth Pattern
The tag editor follows the "storage as source of truth" pattern where all GUI state is stored in `tag_editor_data` and immediately persisted on any user input change:

1. **Read from storage, not GUI**: All data is read from `tag_editor_data`, never from GUI elements
2. **Immediate persistence**: User input is immediately saved to storage via event handlers
3. **One-way data flow**: UI elements display storage values but never read from them
4. **Business logic isolation**: All logic operates exclusively on `tag_editor_data`

### Builder Pattern
The tag editor's UI is constructed using the builder pattern with modular components:

1. Each UI section has a dedicated builder function (e.g., `build_titlebar`, `build_owner_row`)
2. The main `tag_editor.build(player)` function orchestrates construction
3. The `setup_tag_editor_ui()` function configures the state of UI elements
4. All UI elements are consistently named according to the pattern `tag_editor_{purpose}_{type}`

### Command Pattern
User interactions are handled via the command pattern:

1. Each button click creates a specific command handler (e.g., `handle_move_btn`, `handle_confirm_btn`)
2. Commands encapsulate actions, validation, and state changes
3. A command manager maintains history for undo functionality
4. Event dispatchers route events to appropriate command handlers

This implementation ensures clean separation of concerns, testability, and robust state management in a multiplayer environment.
