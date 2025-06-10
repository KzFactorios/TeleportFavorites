# Source of Truth for Factorio Modding

The following resources are considered the absolute source of truth for all Factorio modding, development, and API usage in this codebase. All design decisions, code implementations, and documentation should reference these sources for canonical answers to Factorio's runtime, data, and GUI APIs.

## 1. Factorio Lua API Documentation

- **URL:** https://lua-api.factorio.com/latest
- **Purpose:** The official, always up-to-date API reference for the Factorio modding environment. Includes all classes, prototypes, events, and scripting interfaces.  
- **Usage:** Consult for every question regarding accessible objects, methods, events, persistent data, GUI construction, mod lifecycle, and serialization rules.

## 2. Factorio Data Definitions

- **URL:** https://github.com/wube/factorio-data
- **Purpose:** The canonical repository for all vanilla game data, including prototypes, GUI style definitions, item/entity specs, and core mod files.  
- **Usage:** Reference for vanilla style definitions, entity/item IDs, default values, GUI layouts, and any mod that intends to match or extend the vanilla Factorio experience.

---

## Policy

- All technical disputes or ambiguities in modding conventions, runtime object fields, GUI element options, or vanilla styles should be resolved by consulting these sources.
- When documenting or implementing features, always cite the relevant section of these sources when applicable.
- Keep these URLs in project documentation and as a quick reference in onboarding guides.

_Last updated: 2025-06-04_