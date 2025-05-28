# Pattern Class Notes

This document describes the base pattern classes and key domain classes created for the TeleportFavorites mod as of May 2025.

---

## Pattern Base Classes (core/pattern, core/patterns)

### Builder
- **Purpose:** Stepwise construction of complex objects (e.g., GUIs).
- **Key Methods:**
  - `new()`: Constructor.
  - `reset()`: Reset builder state (override in subclass).
  - `add_part(part)`: Add a part to the product (override in subclass).
  - `get_result()`: Retrieve the final product (override in subclass).
- **Example:** See end of `builder.lua` for a string concatenation builder.

### Command
- **Purpose:** Encapsulate a request as an object, allowing parameterization and queuing of requests.
- **Key Methods:**
  - `new()`: Constructor.
  - `execute(...)`: Perform the command (override in subclass).
- **Example:** See end of `command.lua` for a print command.

### Composite
- **Purpose:** Treat individual objects and compositions of objects uniformly (e.g., GUI hierarchies).
- **Key Methods:**
  - `new()`: Constructor.
  - `add(child)`, `remove(child)`: Manage children.
  - `operation(...)`: Perform an operation on self and children (override in subclass).
- **Example:** See end of `composite.lua` for a tree of leaves.

### Facade
- **Purpose:** Provide a simplified interface to a complex subsystem.
- **Key Methods:**
  - `new()`: Constructor.
  - `operation(...)`: High-level operation (override in subclass).
- **Example:** See end of `facade.lua` for subsystem coordination.

### Observer
- **Purpose:** Event subscription and notification (decoupled event-driven logic).
- **Key Methods:**
  - `register(event_type, listener)`, `unregister(event_type, listener)`: Manage listeners.
  - `notify_all(event)`: Notify listeners of an event.
- **Example:** See end of `observer.lua` for event handling.

### Proxy
- **Purpose:** Control access to another object (e.g., for caching, logging, or access control).
- **Key Methods:**
  - `new(real_subject)`: Constructor.
  - `request(...)`: Forwarded request (override in subclass).
- **Example:** See end of `proxy.lua` for pre/post-processing.

### Singleton
- **Purpose:** Ensure only one instance of a class exists.
- **Key Methods:**
  - `getInstance()`: Get or create the singleton instance.
  - `init()`: Optional initialization logic.
- **Example:** See end of `singleton.lua` for singleton usage.

### Strategy
- **Purpose:** Define a family of algorithms, encapsulate each, and make them interchangeable.
- **Key Methods:**
  - `new()`: Constructor.
  - `execute(...)`: Execute the strategy (override in subclass).
- **Example:** See end of `strategy.lua` for add/multiply strategies.

### Adapter (core/patterns/adapter.lua)
- **Purpose:** Adapt one interface to another.
- **Key Methods:**
  - `new(adaptee)`: Constructor.
  - `request(...)`: Adapted call (override in subclass).
- **Example:** See end of `adapter.lua` for adapting an old API.

---

## Domain Classes

### Favorite (core/favorite/favorite.lua)
- **Purpose:** Represents a favorite location with a GPS string and a locked state.
- **Fields:**
  - `gps` (string): The GPS string identifying the location.
  - `locked` (boolean): Whether the favorite is locked (default: false).
- **Key Methods:**
  - `new(gps, locked)`: Constructor.
  - `update_gps(new_gps)`: Update the GPS string.
  - `toggle_locked()`: Toggle the locked state.
  - `get_blank_favorite()`: Static method to create a blank favorite.

### PlayerFavorites (core/favorite/player_favorites.lua)
- **Purpose:** Wrapper for a collection of favorites for a specific player, with slot management and persistence.
- **Key Methods:**
  - `new(player)`: Constructor, initializes persistent slots.
  - `add_favorite(gps)`, `remove_favorite(gps)`: Add/remove favorites.
  - `swap_slots(idx1, idx2)`, `move_favorite(from_idx, to_idx)`: Slot manipulation.
  - `cascade_up(from_idx)`, `cascade_down(from_idx)`: Shift slots up/down, respecting locked slots.

### Lookups (core/cache/lookups.lua)
- **Purpose:** Handles the non-persistent in-game data cache for runtime lookups (e.g., chart_tag_cache).
- **Key Methods:**
  - `get(key)`, `set(key, value)`, `remove(key)`, `clear()`: Generic cache operations.
  - `get_chart_tag_cache(surface_index)`, `clear_chart_tag_cache(surface_index)`: Chart tag cache management.
  - `set_tag_editor_position(player, map_position)`, `get_tag_editor_position(player)`, `clear_tag_editor_position(player)`: Tag editor position management.

---

This document will be updated as new pattern and domain classes are added or refactored.
