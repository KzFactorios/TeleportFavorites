# Utils Consolidation Migration Strategy

## Overview
This document outlines the systematic approach to migrating the entire TeleportFavorites codebase from scattered utility files to consolidated domain-focused modules.

## Migration Status

### ✅ **Phase 1: Consolidation Complete**
- [x] `position_utils.lua` - All position-related functions consolidated
- [x] `gps_utils.lua` - Complete GPS system unified  
- [x] `collection_utils.lua` - Data manipulation functions consolidated
- [x] `chart_tag_utils.lua` - Chart tag operations consolidated
- [x] `validation_utils.lua` - Validation patterns consolidated
- [x] `gui_utils.lua` - GUI utilities consolidated
- [x] `utils.lua` - Unified facade created
- [x] Test suite created for validation

### 🔄 **Phase 2: Migration in Progress**

## Migration Mapping

### Files to Replace:

#### **Position & Geography → `position_utils.lua`**
```
position_helpers.lua         → PositionUtils
position_normalizer.lua      → PositionUtils  
position_validator.lua       → PositionUtils
terrain_validator.lua        → PositionUtils
```

#### **GPS System → `gps_utils.lua`**
```
gps_core.lua                 → GPSUtils
gps_parser.lua               → GPSUtils
gps_helpers.lua              → GPSUtils (facade)
gps_chart_helpers.lua        → GPSUtils
gps_position_normalizer.lua  → GPSUtils
```

#### **Chart Tag Operations → `chart_tag_utils.lua`**
```
chart_tag_spec_builder.lua   → ChartTagUtils
chart_tag_click_detector.lua → ChartTagUtils
chart_tag_terrain_handler.lua → ChartTagUtils
```

#### **Validation System → `validation_utils.lua`**
```
validation_helpers.lua       → ValidationUtils
icon_validator.lua           → ValidationUtils
```

#### **GUI & Display → `gui_utils.lua`**
```
style_helpers.lua            → GuiUtils
rich_text_formatter.lua      → GuiUtils
sprite_debugger.lua          → GuiUtils
```

#### **Collection Operations → `collection_utils.lua`**
```
table_helpers.lua            → CollectionUtils
functional_helpers.lua       → CollectionUtils
math_helpers.lua             → CollectionUtils
```

## Systematic Migration Process

### Step 1: Identify All Import Statements

**Command to find all require statements:**
```powershell
# Find all require statements for files being consolidated
Get-ChildItem -Path "v:\Fac2orios\2_Gemini\mods\TeleportFavorites" -Recurse -Include "*.lua" | 
    Select-String 'require.*\(".*position_helpers.*"\)' | 
    Select-Object -Property Filename, LineNumber, Line
```

### Step 2: Update Import Statements

**Before:**
```lua
local position_helpers = require("core.utils.position_helpers")  
local position_normalizer = require("core.utils.position_normalizer")
local gps_core = require("core.utils.gps_core")
```

**After Option 1 (Individual modules):**
```lua
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils") 
```

**After Option 2 (Unified facade):**
```lua
local Utils = require("core.utils.utils")
-- Access via Utils.PositionUtils, Utils.GPSUtils, etc.
```

### Step 3: Update Function Calls

**Before:**
```lua
local normalized = position_normalizer.normalize_position(pos)
local gps = gps_core.create_gps_string(x, y, surface)
local valid = position_helpers.is_valid_position(pos)
```

**After:**
```lua
local normalized = PositionUtils.normalize_position(pos)
local gps = GPSUtils.gps_from_map_position({x = x, y = y}, surface)
local valid = PositionUtils.is_valid_position(pos)
```

## Migration Priority Order

### **High Priority (Core Dependencies)**
1. **Basic utilities used everywhere**
   - `basic_helpers.lua` (keep as is - foundational)
   - `error_handler.lua` (keep as is - foundational)
   - `settings_access.lua` (keep as is - foundational)

2. **Core cache and event system**
   - Files in `core/cache/`
   - Files in `core/events/`
   - Files in `core/control/`

### **Medium Priority (Feature Modules)**
3. **GUI subsystems**
   - `gui/gui_base.lua`
   - `gui/favorites_bar/`
   - `gui/tag_editor/`
   - `gui/data_viewer/`

4. **Business logic modules**
   - `core/favorite/`
   - `core/tag/` 
   - `core/pattern/`

### **Low Priority (Entry Points)**
5. **Main entry points** (update last)
   - `control.lua`
   - `data.lua`
   - `settings.lua`

## Automated Migration Tools

### PowerShell Script for Import Replacement
```powershell
# Replace old imports with new consolidated imports
function Update-ImportStatements {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    
    # Replace position-related imports
    $content = $content -replace 'require\("core\.utils\.position_helpers"\)', 'require("core.utils.position_utils")'
    $content = $content -replace 'require\("core\.utils\.position_normalizer"\)', 'require("core.utils.position_utils")'
    
    # Replace GPS-related imports  
    $content = $content -replace 'require\("core\.utils\.gps_core"\)', 'require("core.utils.gps_utils")'
    $content = $content -replace 'require\("core\.utils\.gps_parser"\)', 'require("core.utils.gps_utils")'
    
    # Continue for other modules...
    
    Set-Content $FilePath $content
}
```

### Function Call Update Script
```powershell
function Update-FunctionCalls {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    
    # Update position function calls
    $content = $content -replace 'position_helpers\.', 'PositionUtils.'
    $content = $content -replace 'position_normalizer\.', 'PositionUtils.'
    
    # Update GPS function calls
    $content = $content -replace 'gps_core\.', 'GPSUtils.'
    $content = $content -replace 'gps_parser\.', 'GPSUtils.'
    
    Set-Content $FilePath $content
}
```

## Quality Assurance

### Testing Strategy
1. **Run consolidation test suite** after each migration batch
2. **Load mod in Factorio** to verify no runtime errors
3. **Test core functionality** (teleporting, favorites, etc.)
4. **Performance regression testing** if needed

### Rollback Plan
1. **Keep backup of original files** until migration is complete
2. **Git branching strategy** - separate branch for migration
3. **Incremental commits** - one logical change per commit

## Completion Criteria

### Definition of Done
- [ ] All old utility files removed
- [ ] All imports updated to use consolidated modules
- [ ] All function calls updated to use new APIs
- [ ] All tests passing
- [ ] No compilation errors
- [ ] No runtime errors during basic mod operations
- [ ] Performance equivalent or better than before

### Final File Structure
```
core/utils/
├── basic_helpers.lua           # Foundational utilities
├── error_handler.lua           # Error handling
├── settings_access.lua         # Settings access
├── version.lua                 # Auto-generated version
├── position_utils.lua          # All position operations
├── gps_utils.lua              # Complete GPS system
├── chart_tag_utils.lua        # Chart tag operations
├── validation_utils.lua       # Validation patterns
├── gui_utils.lua              # GUI utilities
├── collection_utils.lua       # Data manipulation
└── utils.lua                  # Unified facade
```

**From 31 files → 11 files (65% reduction)**

## Next Steps

1. **Execute migration scripts** on high-priority files
2. **Test after each batch** of changes
3. **Update documentation** to reflect new structure
4. **Create developer guide** for using consolidated modules
5. **Performance benchmarking** before final cleanup

## Benefits Realized

### **Immediate Benefits**
- ✅ Consolidated modules created and tested
- ✅ Clear domain separation established
- ✅ Reduced file count from 31 to 11

### **Expected Benefits After Migration**
- 🎯 Improved developer experience - know exactly where to find functions
- 🔧 Reduced complexity - fewer cross-references between files
- 📈 Better maintainability - related functions grouped together
- ⚡ Performance improvements - fewer module loads during startup
- 🛡️ Reduced circular dependency risk

---

**Status:** Phase 1 Complete, Phase 2 Ready to Begin
**Next Action:** Execute migration scripts on core cache and event systems
