# Enabling Developer Mode in Factorio for TeleportFavorites

Developer mode in the TeleportFavorites mod provides access to additional tools and features designed to assist with mod development, including the Positionator tool for fine-tuning positions and bounding boxes.

## How to Enable Developer Mode

1. **Create the `.dev_mode` File**:
   - Navigate to your TeleportFavorites mod directory (typically in `%appdata%\Factorio\mods\TeleportFavorites_x.y.z\` on Windows)
   - Create an empty file named `.dev_mode` in the root of the mod directory
   - This file's presence signals to the mod that it should enable development features

2. **Restart Factorio**:
   - If Factorio was already running, restart it to ensure the mod detects the `.dev_mode` file

3. **Configure Developer Settings**:
   - In Factorio, go to Settings > Mod Settings
   - Look for the "TeleportFavorites - Developer Settings" section
   - Ensure "Enable Positionator" is checked (should be enabled by default in dev mode)

## Using the Positionator Tool

Once developer mode is enabled, you can use the enhanced Positionator features:

### Right-Click Preview

The improved Positionator now supports a real-time preview of collision indicators while using the map view:

1. Open the map view (press "M" by default)
2. Right-click and hold on any location
3. You'll see two collision indicators:
   - A green circle showing the collision detection area
   - A blue square showing the bounding box dimensions
4. These indicators follow your cursor in real-time, updating based on your zoom level
5. Release right-click to place a tag and open the regular tag editor

### Performance Optimizations

The updated Positionator includes several optimizations to reduce UPS impact:

- Rendering frequency adapts based on zoom level (less frequent updates when zoomed out)
- Visual elements are simplified when zoomed out
- Position updates are throttled to reduce rendering calls
- Rendering complexity scales based on zoom level

### Troubleshooting

If developer mode features aren't appearing:

1. Verify the `.dev_mode` file exists and is in the correct location
2. Check mod settings to ensure the Positionator feature is enabled
3. Look for any errors in the Factorio log (`factorio-current.log`)
4. Try creating the `.dev_mode` file again, making sure your file manager isn't hiding the extension

## Disabling Developer Mode

To disable developer mode:

1. Delete the `.dev_mode` file from the mod directory
2. Restart Factorio

This will return the mod to its standard production configuration.
