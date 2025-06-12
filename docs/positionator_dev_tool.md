# Positionator Developer Tool

## Overview

The Positionator is a developer utility that provides real-time fine-tuning of positions and bounding boxes during the position normalization workflow. It allows developers to adjust positions and search radius values before continuing with the normalization process, making it easier to test different values and visualize the effects.

## Features

- Real-time position adjustment of X and Y coordinates
- Teleport radius (search radius) adjustment
- Visualization of bounding box dimensions as the radius changes
- Reset button to restore original clicked position
- Toggle between development and production mode
- Integration with the existing position normalization workflow

## Environment Detection

The Positionator is only available in development mode, which is automatically detected by the presence of a `.dev_mode` file in the mod's root directory. This ensures that the tool is not active in production environments.

## Usage

1. **Enable Development Mode**:
   - Ensure the `.dev_mode` file exists in the mod's root directory.
   - The mod will automatically detect this file and enable development features.

2. **Using the Positionator**:
   - Right-click on the map to place a tag (normal workflow).
   - The Positionator dialog will appear before the tag editor, showing:
     - Original clicked position
     - Normalized position values
     - Sliders for adjusting X, Y coordinates
     - Slider for adjusting the search radius
     - Visual representation of the bounding box dimensions

3. **Adjusting Values**:
   - Use the sliders to adjust position or radius.
   - The bounding box visualization updates in real-time.
   - Click "Reset" to return to the original values.
   - Click "Confirm" to use the adjusted values and continue with the workflow.
   - Click the X button to cancel and close the dialog.

4. **Toggle in Settings**:
   - The Positionator can be enabled/disabled via mod settings when in dev mode.
   - Look for "teleport-favorites-dev-positionator-enabled" in mod settings.

## Integration with Existing Code

The Positionator is designed to be loosely coupled with the existing code:

1. It's only loaded when in development mode.
2. It can be disabled via settings without affecting the normal workflow.
3. It integrates at a specific point in the position normalization process without modifying the core functionality.

## Testing the Positionator

A test module is included to verify the functionality of the Positionator. Use the command `/test_positionator` in-game to:

1. Verify that development mode is correctly detected.
2. Test opening the Positionator dialog.
3. Validate the callback functionality.

## File Structure

- `core/utils/dev_environment.lua`: Handles detection of development mode and feature toggles.
- `core/utils/positionator.lua`: Implements the position adjustment dialog and visualization.
- `core/utils/dev_init.lua`: Initializes development features on mod startup.
- `tests/positionator_test.lua`: Contains test functions for the Positionator.
- `settings-dev.lua`: Defines development-only mod settings.
- `.dev_mode`: Marker file that indicates development mode.

## Development vs. Production

In development mode (`.dev_mode` file present):
- Positionator is available for position adjustments.
- Additional debug information is logged.
- Test commands are registered.

In production mode (`.dev_mode` file absent):
- Positionator is completely disabled.
- No debug logging or test commands are registered.
- No performance impact from development tools.

## Future Improvements

Potential enhancements to the Positionator system:
1. Add visualization of nearby tags within the search radius.
2. Provide an option to visualize grid alignment.
3. Add a debug log panel showing normalization steps.
4. Include controls for toggling specific validation rules.
