# Sprite Registration and Usage – Best Practices (TeleportFavorites)

## Overview
This note summarizes best practices for registering and using custom sprites in the TeleportFavorites mod, in accordance with project standards and Factorio modding conventions.

---

## Sprite Registration
- Register all custom sprites in the data stage (e.g., in `data.lua` or `data-final-fixes.lua`) using `data:extend{ ... }`.
- Do not use the `scale` property in the sprite prototype unless you have a specific need to scale the image at runtime. If your PNG is already the correct size (e.g., 16x16), omit `scale`.
- Always specify the correct `width` and `height` matching the actual pixel size of your PNG.
- Use the `flags = { "gui-icon" }` property for GUI icons.
- Example:
  ```lua
  data:extend{
    {
      type = "sprite",
      name = "tf_insert_rich_text_icon",
      filename = "__TeleportFavorites__/graphics/insert_rich_text_icon.png",
      width = 16,
      height = 16,
      flags = { "gui-icon" }
    }
  }
  ```

## Sprite Usage in GUI
- Assign the sprite to GUI elements (e.g., `sprite-button`) at runtime, not in the style definition.
- Use enums (e.g., `SpriteEnum`) to reference sprite names for maintainability.
- Example:
  ```lua
  parent.add{
    type = "sprite-button",
    style = "tf_insert_rich_text_button",
    sprite = SpriteEnum.INSERT_RICH_TEXT_ICON
  }
  ```

## Button Style Best Practices
- Set `width` and `height` in the style to match the sprite size.
- Avoid setting `icon_scale` unless you need to scale the icon independently of the button size.
- Do not override all graphical sets to `type = "none"` unless you want a fully transparent button.

## Troubleshooting
- If the icon does not appear, verify:
  - The PNG exists at the specified path and is the correct size.
  - The sprite is registered in the data stage.
  - The sprite name matches in both registration and usage.
  - The button style does not hide the icon (e.g., by setting all graphical sets to `none`).
  - Test with a vanilla sprite (e.g., `"utility/add"`) to isolate the issue.

---

For more, see: `notes/coding_standards.md`, `notes/GUI-general.md`, and the official [Factorio modding documentation](https://lua-api.factorio.com/latest/prototypes/Sprite.html).
