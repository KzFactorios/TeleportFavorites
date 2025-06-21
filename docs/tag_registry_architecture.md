-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\docs\tag_registry_architecture.md
# Tag Registry Architecture

## Problem Statement

The TeleportFavorites mod was experiencing a "too many C levels" error due to circular dependencies between several key modules:

1. `Tag:get_chart_tag()` in `tag.lua` needed to access chart tags but would indirectly call `Cache.get_tag_by_gps()`
2. `Cache.get_tag_by_gps()` would set the Tag metatable on objects which might trigger `Tag:get_chart_tag()`
3. `tag_destroy_helper.lua` would call `Cache.remove_stored_tag()`
4. `Cache.remove_stored_tag()` would call `Lookups.remove_chart_tag_from_cache_by_gps()`
5. Which could then restart the cycle

This circular dependency caused stack overflow errors in certain edge cases, particularly during tag destruction operations.

## Solution: TagRegistry Architecture

The solution was to break the circular dependencies by introducing a new `TagRegistry` module that serves as a centralized access point for tag data, without requiring dependencies on either the `Tag` class or the `Cache` module.

### Architectural Changes

1. **Introduced `TagRegistry` Module**:
   - Acts as a standalone, dependency-free module for chart tag access
   - Provides `get_chart_tag_by_gps()` without depending on `Cache` or `Tag`
   - Handles `remove_chart_tag_by_gps()` operations directly

2. **Modified `Tag:get_chart_tag()`**:
   - Now uses `TagRegistry` directly
   - Removed all circular dependencies and recursion guards

3. **Updated `Cache.remove_stored_tag()`**:
   - Simplified to only handle persistent storage
   - Uses `TagRegistry` for chart tag operations

4. **Simplified `Lookups.remove_chart_tag_from_cache_by_gps()`**:
   - Removed recursion protection that was needed due to circular dependencies
   - Focuses only on cache management

5. **Updated `tag_destroy_helper.lua`**:
   - Now uses both `Cache` and `TagRegistry` directly
   - Maintains proper separation of concerns

## Benefits

1. **Eliminated Stack Overflow Errors**:
   - No more recursive calls between modules
   - No need for global recursion guards

2. **Improved Code Architecture**:
   - Proper separation of concerns
   - Cleaner dependency graph
   - Better modularity

3. **Enhanced Maintainability**:
   - Each module has clear responsibilities
   - Easier to understand and debug
   - Less fragile when making changes

## Testing

A dedicated test script (`tests/test_tag_registry.lua`) was created to validate the new architecture and ensure that:

1. Tag operations work correctly without circular dependencies
2. No global recursion guards are needed
3. Tag creation, fetching, and removal all work as expected

## Future Considerations

This pattern could be extended to other areas of the codebase where circular dependencies might exist. The `Registry` pattern provides a clean way to break dependency cycles while maintaining proper encapsulation and separation of concerns.
