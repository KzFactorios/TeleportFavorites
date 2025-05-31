# Data Viewer GUI – Design & Best Practices

The Data Viewer is a developer utility for inspecting mod storage in real time. It should be robust, performant, and idiomatic for Factorio 2.0, using the builder and command patterns for GUI and event handling. The viewer is intended for debugging and development, not for end users.

## Core Features
- **Location:** Lives in the top GUI, below the favorites bar.
- **Tabs:** Four tab buttons at the top: `player_data`, `surface_data`, `lookups`, `all_data`.
- **Panel:** Data panel below tabs, width 1000px, always shows scrollbars. Each line shows one key and its value, with child tables indented by `Constants.settings.DATA_VIEWER_INDENT` (default: 4 spaces). Wrapped lines begin with `...\t`.
- **Controls:**
  - Font size buttons (+/-) adjust data panel font size per player (default: 12, step 2, stored in `storage.players[player_index].data_viewer_settings.font_size`).
  - Refresh button reloads the current tab's data snapshot.
  - Close button hides the data panel.
  - Title bar: "Data Viewer", drag handle, close button.
- **Tab Content:**
  - `player_data`: Shows `storage.players[player_index]`, with toggle for all players.
  - `surface_data`: Shows `storage.surfaces[surface_index]`, with toggle for all surfaces.
  - `lookups`: Shows lookups storage.
  - `all_data`: Shows all mod storage.
- **Live Updates:** Data panel tracks changes in real time; refresh button can force reload.
- **Simplicity:** Keep code maintainable and easy to extend for future improvements.

## Per-Player Data Viewer Settings Structure

All per-player Data Viewer settings (such as font size, etc.) are now stored under a single table in player storage:

```
storage.players[player_index].data_viewer_settings = {
    font_size = 12,      -- integer, default 12, range 6-24 (step 2)
    -- future settings...
}
```

- **Font size** is now accessed as `storage.players[player_index].data_viewer_settings.font_size`.
- Add new settings to this table as needed for future features.

## Best Practices
- Use vanilla Factorio styles and idioms for all controls and layout.
- All controls should be accessible via keyboard and mouse.
- All user-facing strings should be localizable.
- Avoid excessive polling or performance impact in multiplayer.
- Use scrollbars and fixed width for predictable layout.
- Store per-player settings (font size) in persistent storage.
- Use the builder pattern for GUI construction and command pattern for event handling.

## Open Questions / Suggestions for Improvement

1. **Data Export:** Should there be a button to export the current data view to a file or clipboard?
Not at this time
2. **Search/Filter:** Should the data panel support searching or filtering keys/values?
Not at this time
3. **Data Editing:** Should the viewer allow editing of data (with confirmation), or remain strictly read-only?
Absolutely not
4. **Performance:** Are there concerns with very large tables (e.g., all_data in large multiplayer games)? Should there be paging or lazy loading?
Not at this time
5. **Tab Customization:** Should users be able to add custom tabs for other data sources?
NO. but make it easy for the developer to expand
6. **Panel Resizing:** Should the data panel width/height be resizable by the user?
Yes
7. **Error Handling:** How should the viewer handle errors or nil data (e.g., missing player/surface)?
There should rarely be errors as we are only displaying a snapshot of the current data without any manipulation
8. **Access Control:** Should the data viewer be restricted to admins or certain players?
Not at this time
9. **Hotkey Support:** Should there be a hotkey to open/close the data viewer or switch tabs?
There should a hotkey for openeing/closing the viewer ctrl+F12. Use tab and shift-tab to navigate tabs
10. **Data Diffing:** Should the viewer support diffing between snapshots (e.g., before/after an event)?
Not at this time

---

# Data Viewer GUI Hierarchy

```
data_viewer_frame (frame)
  └─ data_viewer_titlebar_flow (flow, horizontal)
    ├─ data_viewer_title_label (label)
    ├─ data_viewer_titlebar_filler (empty-widget)
    └─ data_viewer_close_btn (sprite-button)
  └─data_viewer_inner_flow (frame, vertical, invisible_frame)
    └─ data_viewer_tabs_flow (flow, horizontal)
      ├─ data_viewer_player_data_tab (button/sprite-button)
      ├─ data_viewer_surface_data_tab (button/sprite-button)
      ├─ data_viewer_lookup_tab (button/sprite-button)
      ├─ data_viewer_all_data_tab (button/sprite-button)
      └─ data_viewer_tab_actions_flow (flow, horizontal)
          ├─ data_viewer_actions_font_size_flow (flow, horizontal)
          |   ├─ data_viewer_actions_font_down_btn (button)
          |   └─ data_viewer_actions_font_up_btn (button)
          └─ data_viewer_tab_actions_refresh_data_btn
    └─ data_viewer_content_flow (flow, vertical)
      └─ data_viewer_table (table)
          ├─ data_viewer_row_1_label (label)
          ├─ data_viewer_row_1_value (label)
          ├─ ...
          └─ data_viewer_row_N_value (label)
```
- The author is unsure of how scrollbars will be structured, but they will control the viewing of data within the data_viewer_content_flow or the data_viewer_table
- All element names use (for the most part) the `{gui_context}_{purpose}_{type}` convention.
- The number of tab buttons and table rows may vary depending on the data being viewed.
```

---

<!--
The Data_Viewer:

This is a component to aid in debugging only. 
It's purpose is to provide the ability to view the state of the stored data at anytime.
The data viewer's gui should live in the top gui underneath the fave bar. it should have 4 buttons, acting as tabs at the top labeled "player_data", "surface_data", "lookups", "all_data"
Include another pair of buttons to increase the font size used for the data panel and update the data panel immediately upon any changes in this value. use a plus button minus button functionality for this. minus decrease the font size by one and the plus button increase the font-size by 1 for each click. use appropriate icons for these buttons. The default size sohuld be 12. This should be stored per player at storage.players[player_index].data_viewer_settings.font_size
There should be another button to "Refresh Data" the data on the top row off to the right. and another button to close the data panel. Use an appropriate icon to display this button and make "Refresh Data" to be the tooltip
Above all this should be a standard factorio title bar. The title is "Data Viewer" then a drag handle and finally a close button "X" to close the dialog

The data panel will be toggled by the data_panel_close button
the purpose of the data panel is to show the relevant data to what tab is selected in the top row
player_data will show the data from the current player -> storage.players[player_index] and there should be a way to toggle between the current player and all player data in the tab content display
surface_data will show the data from the current player -> storage.surfaces[surface_index] and there should be a way to toggle between the current player and all surface data in the tab content display
lookups will show the data for the lookups storage

when a tab is clicked, the viewer should load the snapshot of the current data appropriate to the selected tab, and should track it in the panel in realtime. Additionally, any data in the panel can be refreshed at any time by clicking on the refresh data button

display strategies will change as the mod develops and testing continues. Make the code super-maintainable and easy to navigate for future improvements

## Display Strategy
each line of data should only show one key and it value, which may be further broken down in to the child tables, etc. Once again each line should only show one key and it's value. show nil if nil. successive children should be indented by Constants.settings.DATA_VIEWER_INDENT or 4 (default) spaces 

Any wrapped lines should begin with "..." \t

implore scrollbars at all times to pan through the data. although the width should be a max amount of say 1000

the data panel should be 1000 wide.

the tabs and buttons specified should arrange horizontally in the top row of the gui.
the data panel sohuld be the same width and show below the tabs. Create a button handle the opening and closing of the data panel in the top row as well

keep things very simple as this only a dev utility
-->
## Working Vanilla Factorio Utility Sprites (for Data Viewer and General GUI)

- utility/list_view         (generic tab icon)
- utility/close             (close button)
- utility/refresh           (refresh button)
- utility/arrow-up          (increase, up)
- utility/arrow-down        (decrease, down)
- utility/arrow-left        (left)
- utility/arrow-right       (right)

> Note: Do NOT use utility/minus, utility/plus, utility/remove, utility/add, utility/tab_icon, utility/up_arrow, or utility/down_arrow. These do NOT exist in vanilla Factorio and will cause exceptions.

If you need more icons, check the [Factorio Wiki: Prototype/Sprite](https://wiki.factorio.com/Prototype/Sprite#Sprites) or inspect the game's utility-sprites.png for available names.

---
