# Test Runner Usage Guide

The TeleportFavorites project provides multiple test runners that now support running specific test files.

## Test Runners Available

### 1. Root-level PowerShell Runner (Recommended)
```powershell
# From project root directory
.\.test.ps1                              # Run all tests
.\.test.ps1 drag_drop_utils_spec         # Run specific test
.\.test.ps1 cache_spec gui_base_spec     # Run multiple specific tests
```

### 2. Tests Directory PowerShell Runner
```powershell
# From tests directory
.\run_tests.ps1                          # Run all tests
.\run_tests.ps1 drag_drop_utils_spec     # Run specific test
.\run_tests.ps1 cache_spec gui_base_spec # Run multiple specific tests
```

### 3. Universal Lua Runner
```bash
# From any directory
lua tests/run_tests.lua                              # Run all tests
lua tests/run_tests.lua drag_drop_utils_spec         # Run specific test
lua tests/run_tests.lua cache_spec gui_base_spec     # Run multiple specific tests
```

### 4. Direct Infrastructure Runner
```bash
# From tests directory
lua infrastructure/run_all_tests.lua                              # Run all tests
lua infrastructure/run_all_tests.lua drag_drop_utils_spec         # Run specific test
lua infrastructure/run_all_tests.lua cache_spec gui_base_spec     # Run multiple specific tests
```

## Test File Naming

- Test files should be in the `tests/specs/` directory
- Test files should end with `_spec.lua`
- When specifying test files, you can use either:
  - Just the base name: `drag_drop_utils_spec`
  - With extension: `drag_drop_utils_spec.lua` 
  - With full path: `specs/drag_drop_utils_spec.lua`

## Examples

### Run All Tests
```powershell
.\.test.ps1
```

### Run Single Test
```powershell
.\.test.ps1 drag_drop_utils_spec
```

### Run Multiple Tests
```powershell
.\.test.ps1 drag_drop_utils_spec cache_spec gui_base_spec
```

### Run Tests with Coverage
All test runners automatically generate coverage reports when LuaCov is available.

## Output

- **All Tests Mode**: Shows summary of all test files processed
- **Specific Tests Mode**: Shows "Running Specified Tests" and lists the files
- Test results show individual test outcomes (PASS/FAIL)
- Final summary shows total counts of files, tests passed/failed
- Coverage report is generated automatically

## Error Handling

- Invalid test file names will be silently ignored
- If no valid test files are found, the runner will show 0 tests processed
- Test failures will be clearly marked and exit with appropriate error codes
