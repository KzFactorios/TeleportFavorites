# TeleportFavorites Styles Directory

This directory contains all GUI styling definitions for the TeleportFavorites mod.

## Structure

- `init.lua`: Central entry point for all styles. Contains shared/global styles and imports component-specific styles.
- `fave_bar.lua`: Styles specific to the favorites bar GUI.
- `tag_editor.lua`: Styles specific to the tag editor GUI.
- `data_viewer.lua`: Styles specific to the data viewer GUI.
- `debugger.lua`: Styles specific to the debugging tools.

## Usage

All styles are registered with `data.raw["gui-style"].default` and can be referenced by name in runtime GUI code.

## Naming Conventions

Most styles use the prefix `tf_` to avoid conflicts with vanilla styles. Example: `tf_slot_button`, `tf_frame_title`.

## Dependencies

These files are loaded during the data stage of Factorio mod loading and should not depend on files that are only available during runtime.
