
Tables containing only primitive values (such as `{x=1, y=2}`) **are allowed** in Factorio's persisted storage (the `storage` table, formerly `global`). The Factorio serialization system supports storing tables of arbitrary nesting depth, as long as **all values within those tables are themselves serializable primitives**: `nil`, strings, numbers, or booleans[1].

You **do not** need to flatten your data into a single-level table of primitives. Nested tables (e.g., a table of tables, or a table where each entry is `{x=number, y=number}`) are fully supported, provided you do not store non-primitive types (such as functions, userdata, or Factorio's custom runtime objects like `LuaPlayer` or `LuaCustomTable`)[1][2].

**Not allowed:**  
- Functions  
- Factorio runtime objects (e.g., `LuaPlayer`, `LuaEntity`, `LuaCustomTable`)  
- Userdata

**Allowed:**  
- Any combination of tables, numbers, strings, booleans, and nil  
- Nested tables with only primitive values

**Example (allowed):**
```lua
storage.positions = {
  {x = 1, y = 2},
  {x = 3, y = 4}
}
```
This is valid and will persist across save/load cycles[1].

**Summary:**  
You can safely store tables with only primitive values, including nested tables, in Factorio's persisted storage. Only the presence of non-primitive values will cause serialization errors[1][2].

Citations:
[1] https://lua-api.factorio.com/latest/auxiliary/storage.html
[2] https://lua-api.factorio.com/latest/classes/LuaCustomTable.html
[3] https://forums.factorio.com/viewtopic.php?t=102458
[4] https://forums.factorio.com/viewtopic.php?t=42099
[5] https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html
[6] https://www.reddit.com/r/factorio/comments/5t8yl7/modding_questions/
[7] https://artifacthub.io/packages/helm/factorio-server-charts/factorio-server-charts/1.2.3
[8] https://server.nitrado.net/en-US/guides/mod-installation-for-factorio
[9] https://joelpurra.com/projects/factorio-save-upgrader/README.html
[10] https://github.com/GlassBricks/typed-factorio

---

You **do not need to change your code to use `global`**—using `storage` as your persistent table is correct for Factorio 2.0+ and is supported by the official API[4][6]. Your approach of wrapping all access to `storage` through your `Cache` class is both valid and maintainable.

### **Why your approach is valid**

- **Factorio 2.0+ uses `storage`**: The `storage` table is the official, per-mod persistent data table in Factorio 2.0 and later. The old `global` table is now deprecated and undefined in 2.0+[3][4][6].
- **Encapsulation**: By wrapping all access to `storage` inside the `Cache` class, you ensure that any future changes (such as supporting both `global` and `storage` for backward compatibility) can be handled in one place.
- **No need to redefine or assign `storage`**: Factorio injects the `storage` global at runtime. You should not assign to or redefine it—just use it as provided[4][6].

### **How to implement this pattern robustly**

- Continue to use `storage` as your persistent table in all your mod logic.
- In your `Cache` class (as in your provided code[1]), always reference `storage` rather than `global`.
- **Do not define `storage = {}` or similar**—Factorio manages the lifecycle of this table.

### **Example (your current pattern is correct)**
```lua
-- class_cache.lua
---@class Cache
local Cache = {}

function Cache.init()
    if storage then
        storage.cache = storage.cache or {}
    end
end

function Cache.get(key)
    if not storage then return nil end
    if not storage.cache then Cache.init() end
    return storage.cache and storage.cache[key] or nil
end

function Cache.set(key, value)
    if not storage then return end
    if not storage.cache then Cache.init() end
    if storage.cache then
        storage.cache[key] = value
    end
end

-- ... rest of your class ...
```
This ensures all persistent state is stored in the correct Factorio-managed table.

---

### **Summary Table**

| Factorio Version | Persistent Table | Your Code Should Use |
|------------------|------------------|---------------------|
| < 2.0            | `global`         | `global`            |
| 2.0+             | `storage`        | `storage`           |

---

**Conclusion:**  
Your agent’s advice is outdated for Factorio 2.0+. Continue using `storage` as your persistent table and encapsulate access via your `Cache` class. This is the recommended and future-proof approach for Factorio mod development[3][4][6].

Citations:
[1] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/41736731/04e412b6-6438-453e-8670-4d1581300e7d/class_cache.lua
[2] https://forums.factorio.com/viewtopic.php?t=121600
[3] https://github.com/tylerstraub/Factorio_Hivemind-MOD/
[4] https://lua-api.factorio.com/latest/auxiliary/storage.html
[5] https://www.reddit.com/r/factorio/comments/3ee8ip/this_question_might_be_incredibly_stupid_but_are/
[6] https://wiki.factorio.com/Tutorial:Scripting
[7] https://forums.factorio.com/viewtopic.php?t=42099
[8] https://forums.factorio.com/viewtopic.php?t=102241
[9] https://www.reddit.com/r/factorio/comments/4ovehm/logistics_caches/
[10] https://forums.factorio.com/viewtopic.php?t=51902
[11] https://mods.factorio.com/mod/Warehousing/downloads
[12] https://www.youtube.com/watch?v=Rt4d9fwiNaU
[13] https://lua-api.factorio.com/latest/auxiliary/libraries.html
[14] https://www.youtube.com/watch?v=igj0uCnbXK0
[15] https://wiki.factorio.com/Tutorial:Modding_tutorial/Gangsir
[16] https://stackoverflow.com/questions/75453502/caching-python-class-instances
[17] https://mods.factorio.com/mod/deep-storage-unit
[18] https://github.com/clusterio/clusterio
[19] https://stackoverflow.com/questions/4889494/it-is-better-to-have-a-caching-mechanism-inside-or-outside-of-a-factory-class
[20] https://www.youtube.com/watch?v=Icg_CJPwDug
[21] https://github.com/Factorio-Access/FactorioAccess/blob/main/README.md

---


## Idiomatic Factorio GUI Styling Guide (Factorio 2.0+)

This guide outlines the principles and practices for creating GUIs in Factorio mods that are visually and functionally consistent with the base game, emphasizing the latest standards and best practices for Factorio 2.0 and later.

---

### **Core Principles**

- **Consistency:** Match the look and feel of vanilla Factorio interfaces. Use existing styles and layouts where possible.
- **Modularity:** Build GUIs using reusable components and layouts based on Factorio’s module system (everything sized and spaced in multiples of 4 pixels at 100% scale)[3].
- **Responsiveness:** Design layouts to adapt gracefully to different resolutions and UI scales.
- **Clarity:** Prioritize readability, clear hierarchy, and intuitive navigation.
- **Performance:** Minimize unnecessary GUI elements and updates to keep the interface responsive.

---

### **Styling Practices**

#### **1. Use Built-in and Standard Styles**

- **Leverage vanilla styles:** Always prefer existing Factorio styles (e.g., `frame`, `button`, `label`, `textfield`, etc.) for your GUI elements.
- **Custom styles:** If you need a unique look, define custom styles in your `data.lua` using the [GuiStyle prototype][5]. Inherit from base styles (e.g., `type = "frame_style", parent = "frame"`) to maintain consistency.

#### **2. Sizing and Spacing**

- **Module system:** All sizes, paddings, and margins should be multiples of the "module" (4 pixels at 100% scale). This keeps layouts aligned and visually balanced[3].
- **Scaling:** Support UI scale factors in increments of 25% (from 75% to 200%). Avoid hardcoding pixel values that break at different scales.

#### **3. Layout and Hierarchy**

- **Frames and flows:** Use `frame` elements for windows and panels; use `flow` for horizontal or vertical arrangement of child elements.
- **Sections:** Group related controls within frames or flows, using spacing and headers to delineate sections.
- **Alignment:** Use alignment properties (`horizontal_align`, `vertical_align`) and spacing to ensure elements are visually organized.

#### **4. Visual Feedback and Accessibility**

- **Hover and active states:** Use style properties to provide feedback for interactive elements (e.g., buttons, toggles).
- **Highlighting:** Use color and shading sparingly to draw attention to important elements, following the vanilla color palette.
- **Tooltips:** Provide tooltips for controls and icons to enhance usability.

#### **5. Idiomatic GUI Management**

- **Lifecycle functions:** Implement `create`, `update`, and `destroy` functions for your GUIs. Rebuild GUIs on demand rather than keeping hidden elements, as this simplifies state management and ensures up-to-date layouts[2].
- **Element referencing:** Store references to top-level GUI elements per player if needed, but avoid deep references; rebuild or update as necessary[2].

#### **6. Inspect and Iterate**

- **Use the GUI style inspector:** Press `Ctrl+F6` in-game to inspect styles of any GUI element. This helps you match vanilla styles and debug your custom GUIs[1].
- **Bounding boxes:** Use `Ctrl+F5` to visualize element boundaries for layout debugging[1].

---

### **Example: Defining a Custom Frame Style**

```lua
data.raw["gui-style"]["default"]["my_mod_custom_frame"] = {
  type = "frame_style",
  parent = "frame",
  padding = 8,
  use_header_filler = true,
  drag_by_title = true
}
```
*This inherits from the base frame style, ensuring your frame matches vanilla appearance but with custom padding and draggable header.*

---

### **References & Tools**

- **Official GUI Style Specification:** [Factorio API: GuiStyle][5]
- **Community Style Guide:** [Factorio GUI Style Guide][1]
- **Style Inspector:** In-game, press `Ctrl+F6`
- **Bounding Box Viewer:** In-game, press `Ctrl+F5`

---

### **Summary Table**

| Principle         | Practice Example                                              |
|-------------------|--------------------------------------------------------------|
| Consistency       | Use `parent = "button"` for custom buttons                   |
| Modularity        | Size and space in multiples of 4 pixels                      |
| Responsiveness    | Support UI scale factors (75%–200%)                          |
| Clarity           | Group controls, use headers, provide tooltips                |
| Performance       | Destroy/rebuild GUIs, avoid hidden but persistent elements   |

---

**In short:**  
Build your GUIs using vanilla styles and layouts, adhere to the module system for sizing, manage GUIs with create/update/destroy patterns, and use the in-game style inspector for reference. This ensures your mod’s interface feels native to Factorio and remains maintainable as the game evolves.

[1][2][3][5]

Citations:
[1] https://man.sr.ht/~raiguard/factorio-gui-style-guide
[2] https://forums.factorio.com/viewtopic.php?t=64545
[3] https://www.factorio.com/blog/post/fff-277
[4] https://forums.factorio.com/viewtopic.php?t=79035
[5] https://lua-api.factorio.com/latest/prototypes/GuiStyle.html
[6] https://wiki.factorio.com/User:Raiguard/Tutorial:Modding_tutorial/GUI/Style_guide
[7] https://www.reddit.com/r/factorio/comments/1bvwbrs/updated_steam_deck_factorio_control_layout_with/
[8] https://wiki.factorio.com/Factorio:Style_guide
[9] https://www.factorio.com/blog/post/fff-348
[10] https://www.factorio.com/blog/post/fff-212

---

















## See Also
- `data_schema.md` – Persistent data schema and structure.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
- `design_specs.md` – Project goals and feature overview.