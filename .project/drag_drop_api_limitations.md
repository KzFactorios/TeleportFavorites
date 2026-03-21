# Drag & Drop API Limitations (Factorio v2.0+)

## Why Shift+Click Is Required for Favorites Bar Reordering

Factorio's GUI API **cannot detect a true drag gesture** (click-hold-move-release) on mod-created GUI elements.

### What the API provides

`on_gui_click` is the only input event for buttons, firing once per click with:
- `button` — `defines.mouse_button_type` (left, right, middle)
- `shift`, `control`, `alt` — boolean modifier keys

There is **no** `on_gui_mouse_down`, `on_gui_mouse_up`, `on_gui_mouse_move`, or hold/long-press detection.

### What about `draggable`?

The `draggable` property only exists for **frame** elements (window dragging via `drag_target`). It does not apply to `sprite-button` or any other element type used for favorites slots.

### What about hover events?

`on_gui_hover` / `on_gui_leave` exist (with `raise_hover_events = true`) but only detect cursor entering/leaving an element — not click-and-drag motion.

### How vanilla does it

Vanilla Factorio's quickbar/toolbar drag-and-drop is a **native C++ engine feature**. The quickbar, inventory grid, crafting queue, and other native UI panels share an internal drag system that is not exposed to the Lua modding API. Mods cannot create native quickbar-style slot grids.

### Alternatives considered

| Approach | Trigger | Pros | Cons |
|---|---|---|---|
| **Shift+click (current)** | Shift + left-click | Intuitive, well-understood | Requires modifier |
| **Middle-click** | Middle mouse button | No modifier needed | Not all mice have it |
| **Reorder mode toggle** | Dedicated bar button | Most accessible | Extra UI, two-step workflow |
| **Alt+click** | Alt + left-click | Unused modifier | Alt has meaning in Factorio |
| **Double-click** | Two rapid clicks | Feels natural | Adds latency to all teleports |

### Decision

**Keep Shift+click** as the primary drag trigger. This is the standard pattern used by Factorio mods that implement slot reordering, since the Lua API provides no alternative for detecting drag gestures on mod GUI elements.
