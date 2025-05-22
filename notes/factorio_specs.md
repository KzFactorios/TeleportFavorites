
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
Answer from Perplexity: pplx.ai/share




















## See Also
- `data_schema.md` – Persistent data schema and structure.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
- `design_specs.md` – Project goals and feature overview.