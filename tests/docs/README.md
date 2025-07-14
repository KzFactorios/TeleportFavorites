# TeleportFavorites Test Suite

This README provides comprehensive instructions for running and managing the TeleportFavorites mod test suite using PowerShell and Lua.

## � SIMPLE: Easy Test Running

**The test suite now works from ANY directory! Use these simple commands:**

### ✅ EASIEST METHODS (Pick Your Favorite):

**PowerShell Script (RECOMMENDED):**
```powershell
# From ANYWHERE in the project:
.\test.ps1
```

**Batch File:**
```cmd
# From ANYWHERE in the project:
test.bat
```

**Lua Script:**
```powershell
# From ANYWHERE in the project:
lua test.lua
```

**From Tests Directory (Classic Method):**
```powershell
# Navigate to tests directory first
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua
```

**✅ All methods automatically:**
- Find the project root
- Change to the correct directory  
- Run tests with proper paths
- Show clear success/failure status

## ⚠️ CRITICAL PowerShell Pipeline Warning

**NEVER pipe lua test output directly to Select-String!** This causes binding errors:

```powershell
# ❌ CAUSES ERROR: "The input object cannot be bound to any parameters"
lua infrastructure/run_all_tests.lua | Select-String "Test files processed"
```

**✅ ALWAYS use file redirection instead:**
```powershell
lua infrastructure/run_all_tests.lua > results.txt 2>&1
Select-String "Test files processed" results.txt
```

### 🛑 Real Example of the Error

When you try this command:
```powershell
lua infrastructure/run_all_tests.lua | Select-String "Test files processed"
```

You'll get this exact error:
```
Select-String : The input object cannot be bound to any parameters for the command either because the command does not take pipeline input or the input and its properties do not match any of the parameters that take pipeline input.
At line:1 char:40
+ ... tests.lua | Select-String "Test files processed|Total tests|Overall T ...
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (Coverage report...acov.report.out:PSObject) [Select-String], ParameterBindingException
    + FullyQualifiedErrorId : InputObjectNotBound,Microsoft.PowerShell.Commands.SelectStringCommand
```

**Fix**: Always capture to file first, then search the file.

## 📁 Test Suite Organization

```
tests/
├── specs/              # All test specification files (*_spec.lua)
├── infrastructure/     # Test runners and framework components
│   ├── run_all_tests.lua    # Main test runner
│   ├── test_framework.lua   # Custom test framework
│   └── test_bootstrap.lua   # Test environment setup
├── mocks/              # Mock objects for testing
├── fakes/              # Test doubles and fake implementations
├── output/             # Test outputs and generated reports
├── docs/               # Documentation (this file)
├── run_tests.lua       # Convenience runner (forwards to infrastructure/)
└── run_tests.ps1       # PowerShell test runner script

**PROJECT ROOT RUNNERS (NEW!):**
- `test.ps1`           # Universal PowerShell test runner
- `test.bat`           # Universal batch test runner  
- `test.lua`           # Universal Lua test runner
```

## 🚀 Running Tests

### ✅ EASIEST METHODS (Work from Anywhere!)

**PowerShell Script (RECOMMENDED)**
```powershell
# Run from ANY directory in the project:
.\test.ps1
```

**Batch File**
```cmd
# Run from ANY directory in the project:
test.bat
```

**Lua Script**
```powershell
# Run from ANY directory in the project:
lua test.lua
```

**Direct Method (Classic)**
```powershell
# Navigate to tests directory first
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"

# Run using the infrastructure runner
lua infrastructure/run_all_tests.lua
```

**Convenience Wrapper**
```powershell
# Navigate to tests directory first
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"

# Use the convenience wrapper
lua run_tests.lua
```

### ✅ Benefits of New Universal Runners

- **Work from ANY directory** - no more path confusion!
- **Automatic project detection** - finds the right location automatically
- **Clear success/failure reporting** - immediate feedback with colored output
- **Consistent behavior** - same experience regardless of where you run from

### ❌ Legacy Warnings (These Still Apply)

```powershell
# DON'T pipe lua output directly to Select-String - causes binding errors
# lua infrastructure/run_all_tests.lua | Select-String "Test files processed"  # ← BINDING ERROR

# DO use file redirection instead:
lua infrastructure/run_all_tests.lua > results.txt 2>&1
Select-String "Test files processed" results.txt  # ← WORKS
```

**The new universal runners handle all path issues automatically, but if using the classic method, be sure to run from the tests directory.**

# DON'T run from infrastructure directory - can't find specs
# Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests\infrastructure"
# lua run_all_tests.lua  # ← PATH ERROR
```

## 📊 Test Output and Results

### Test Execution Summary
- **Test Files**: 74 total specification files
- **Total Tests**: 415 individual tests
- **Success Rate**: 415/415 tests passing (100%)
- **Framework**: Custom test framework with `describe()` and `it()` blocks

### Output Formats
- **Console**: Real-time test execution with pass/fail status
- **Coverage**: LuaCov integration generates `luacov.report.out`
- **Summaries**: Automatic coverage analysis in `coverage_summary.txt`

### Example Test Output
```
==== Running specs/cache_spec.lua ====
==== Running Tests ====
Cache module
  - should load cache module without errors ... PASS
  - should expose expected cache API methods ... PASS
==== Test Summary ====
Total tests: 2
Passed: 2
Failed: 0
```

## 🔍 Working with Test Directories

### Exploring Test Structure

```powershell
# List all test specification files
Get-ChildItem tests/specs/*.lua | Select-Object Name

# Count total test files
(Get-ChildItem tests/specs/*.lua).Count

# Search for specific test patterns
Get-ChildItem tests/specs/*favorite*.lua

# Find tests by content
Select-String "describe.*Debug" tests/specs/*.lua
```

### Infrastructure Components

```powershell
# View test framework components
Get-ChildItem tests/infrastructure/

# Check test runner content
Get-Content tests/infrastructure/run_all_tests.lua | Select-Object -First 20

# View test framework functions
Select-String "function" tests/infrastructure/test_framework.lua
```

## 🛠️ Managing Test Infrastructure

### Test Runner Scripts

1. **`tests/infrastructure/run_all_tests.lua`** - Main test runner
   - Automatically discovers all `*_spec.lua` files in `tests/specs/`
   - Loads test framework for each test file
   - Generates coverage reports when LuaCov is available
   - Provides detailed execution summaries

2. **`tests/run_tests.lua`** - Convenience wrapper
   - Forwards execution to infrastructure directory
   - Simpler entry point from tests directory

3. **`tests/run_tests.ps1`** - PowerShell script
   - Windows-native test execution
   - Handles path resolution and error reporting

### Test Framework Features

- **Custom Framework**: `tests/infrastructure/test_framework.lua`
- **Test Structure**: `describe()` blocks with nested `it()` tests
- **Assertions**: `assert()`, `is_true()`, `are_same()`, `is_nil()`
- **Isolation**: Each test file runs in clean environment
- **Mocking**: Comprehensive mock system via `package.loaded`

## 📝 PowerShell Commands for Common Tasks

### ✅ Running Tests - CORRECT Commands Only

```powershell
# STEP 1: Always navigate to tests directory first
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"

# STEP 2: Choose one of these working commands
lua infrastructure/run_all_tests.lua
# OR
lua run_tests.lua

# STEP 3: For output capture (optional)
lua infrastructure/run_all_tests.lua | Tee-Object -FilePath "test_results.txt"
```

### ❌ Commands That Cause Errors - DO NOT USE

```powershell
# WRONG: Running from project root
# Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites"
# lua tests/infrastructure/run_all_tests.lua  # ← Causes "module 'test_framework' not found"

# WRONG: Running from infrastructure directory  
# Set-Location "tests/infrastructure"
# lua run_all_tests.lua  # ← Can't find test specs

# WRONG: Using Select-String with pipes - CAUSES BINDING ERRORS
# lua infrastructure/run_all_tests.lua | Select-String "Summary"  # ← PowerShell binding error
# lua infrastructure/run_all_tests.lua 2>&1 | Select-String "Test files"  # ← PowerShell binding error
```

**⚠️ CRITICAL**: The Select-String pipeline error is the most common mistake! Always use file redirection instead.

### Analyzing Test Results

```powershell
# ✅ CORRECT: Count test files and results
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
$testFiles = Get-ChildItem specs/*.lua
Write-Host "Total test files: $($testFiles.Count)"

# ✅ CORRECT: Capture output to file first, then search
lua infrastructure/run_all_tests.lua > test_results.txt 2>&1
Select-String "FAIL|Failed:" test_results.txt

# ✅ CORRECT: Alternative using Out-String
lua infrastructure/run_all_tests.lua 2>&1 | Out-String | Select-String "Overall Test Summary"

# ✅ CORRECT: View coverage summary (if exists)
if (Test-Path "coverage_summary.txt") { Get-Content coverage_summary.txt | Select-Object -First 20 }
```

### Directory Navigation

```powershell
# ✅ CORRECT: Quick navigation to test directory
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"

# ✅ CORRECT: Navigate to specific subdirectories
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests\specs"     # View test files
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests\infrastructure"  # View framework

# ✅ CORRECT: PowerShell aliases for convenience
function Go-Tests { Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests" }
function Go-Specs { Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests\specs" }

# Usage: 
Go-Tests; lua infrastructure/run_all_tests.lua
Go-Specs; Get-ChildItem *favorite*.lua
```

### File Management

```powershell
# ✅ CORRECT: Create new test file in proper location
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"

$testTemplate = @"
describe("NewModule", function()
  it("should load without errors", function()
    local success, err = pcall(function()
      require("path.to.new_module")
    end)
    assert(success, "Module should load: " .. tostring(err))
  end)
end)
"@

$testTemplate | Out-File -FilePath "specs/new_module_spec.lua" -Encoding UTF8
```

### 🚨 IMPORTANT: Test File Placement

**Always place test-related files in the tests directory structure:**

```powershell
# ✅ CORRECT: Test files go in tests directory
tests/
├── specs/new_test_spec.lua           # New test files
├── output/debug_results.txt          # Test output files  
├── temp_debugging.lua                # Temporary debug files
└── coverage_analysis.md              # Analysis files

# ❌ WRONG: Never place in project root
../debug_test.lua                     # DON'T DO THIS
../temp_analysis.md                   # DON'T DO THIS
../test_output.txt                    # DON'T DO THIS
```

**Cleanup project root if needed:**
```powershell
# Remove any test files accidentally placed in project root
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites"
Get-ChildItem -Name "debug_*", "test_*", "*analysis*" | Remove-Item -Force
```

## 🔧 Troubleshooting

### Common Issues

**Issue**: `module 'test_framework' not found`
```powershell
# ❌ WRONG: Running from project root causes this error
# Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites"
# lua tests/infrastructure/run_all_tests.lua

# ✅ SOLUTION: Always run from tests directory
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua
```

**Issue**: `Select-String : The input object cannot be bound to any parameters`
```powershell
# ❌ WRONG: Direct piping causes binding errors
# lua infrastructure/run_all_tests.lua 2>&1 | Select-String "pattern"

# ✅ SOLUTION: Capture to file first, then search
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua > output.txt 2>&1
Select-String -Pattern "Summary" -Path "output.txt"
```

**Issue**: No test files found (0 files processed)
```powershell
# ❌ WRONG: Running from wrong directory
# Set-Location "infrastructure" 
# lua run_all_tests.lua

# ✅ SOLUTION: Run from tests directory
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua
```

**Issue**: PowerShell execution policy
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Issue**: Lua path not found
```powershell
# Verify Lua installation
lua -v

# Check if lua.exe is in PATH
Get-Command lua
```

### Test Framework Warnings

- **Warning**: `global after_each not implemented` - This is expected, framework doesn't implement this feature
- **Warning**: `it() calls outside describe blocks` - Tests should be wrapped in `describe()` blocks

### Path Resolution

**CRITICAL: Always use the tests directory as your working directory**

```powershell
# ✅ CORRECT: The ONLY working directory for test commands
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua

# ❌ WRONG: Running from project root - PATH ERRORS
# Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites"
# lua tests/infrastructure/run_all_tests.lua  # ← Fails to find test_framework

# ❌ WRONG: Running from infrastructure directory - SPEC ERRORS  
# Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests\infrastructure"
# lua run_all_tests.lua  # ← Can't find test specs
```

## 🚨 PowerShell Pipeline Issues

### ⚠️ CRITICAL: Select-String Binding Error

**This is the most common error users encounter:**

```
Select-String : The input object cannot be bound to any parameters for the command either because the command does not take pipeline input or the input and its properties do not match any of the parameters that take pipeline input.
```

**Root Cause**: PowerShell's `Select-String` expects string input, but lua output contains mixed object types (text and error objects) that can't be processed directly through pipes.

### Common Select-String Errors

**Problem**: `Select-String : The input object cannot be bound to any parameters`

This error occurs when trying to pipe mixed output streams (stdout/stderr) directly to `Select-String`.

```powershell
# ❌ INCORRECT - Causes binding errors
lua infrastructure/run_all_tests.lua | Select-String "Test files processed"
lua infrastructure/run_all_tests.lua 2>&1 | Select-String -Pattern "Summary" -A 10

# ❌ INCORRECT - Mixed streams confuse Select-String
lua infrastructure/run_all_tests.lua | Select-String -Pattern "cache|debug"
```

### ✅ CORRECT Solutions

**Method 1: Redirect to file first**
```powershell
# Capture all output to file, then search
lua tests/infrastructure/run_all_tests.lua > test_output.txt 2>&1
Select-String -Pattern "Overall Test Summary" -Path "test_output.txt" -Context 0,10

# Search for specific patterns
Select-String -Pattern "FAIL|Failed:" -Path "test_output.txt"
```

**Method 2: Use Out-String for pipeline conversion**
```powershell
# Convert object stream to string stream
lua tests/infrastructure/run_all_tests.lua 2>&1 | Out-String | Select-String "Summary"

# Filter specific content
lua tests/infrastructure/run_all_tests.lua 2>&1 | Out-String | Select-String "cache.*PASS"
```

**Method 3: Use Tee-Object for dual output**
```powershell
# Display output AND save to file
lua tests/infrastructure/run_all_tests.lua | Tee-Object -FilePath "test_results.txt"

# Then search the saved file
Select-String -Pattern "Total tests:" -Path "test_results.txt"
```

### Why This Happens

PowerShell's `Select-String` expects string input, but when you redirect stderr (`2>&1`), it creates a mix of different object types that can't be processed directly. The lua output contains both text and error objects that need to be converted to strings first.

## 📈 Test Coverage and Quality

### Coverage Philosophy
- **Smoke Testing Approach**: Tests verify code executes without errors
- **Comprehensive Mocking**: All dependencies mocked for isolation
- **Regression Protection**: Primary goal is catching breaking changes
- **Simple Assertions**: Focus on execution success rather than behavior verification

### Expected Results
- **Test Count**: ~415 tests across 74 specification files
- **Pass Rate**: Should maintain >99% pass rate
- **Coverage**: LuaCov reports available but mocking affects traditional coverage metrics
- **Performance**: Full test suite runs in under 30 seconds

### Quality Metrics
- Zero syntax/compilation errors in test files
- All tests properly organized in `describe()` blocks
- Comprehensive mock coverage for Factorio APIs
- Clear, descriptive test names and failure messages

## 🎯 Best Practices

### Writing Tests
- Place new test files in `tests/specs/` with `_spec.lua` suffix
- Use `describe()` blocks to group related tests
- Mock all external dependencies via `package.loaded`
- Focus on execution validation rather than complex behavior testing

### Running Tests
- Always run from tests directory: `Set-Location "...\tests"`
- Use the main test runner for comprehensive results: `lua infrastructure/run_all_tests.lua`
- Capture output for analysis when debugging failures using file redirection
- Monitor test count and pass rates for regressions

### Maintenance
- Keep test specs separate from infrastructure code
- Update mocks when production APIs change
- Review failing tests promptly - they catch real issues
- Don't modify production code just to satisfy tests

### 🚨 CRITICAL: Temporary Test Files

**NEVER place temporary test files in the project root directory!**

```
❌ WRONG LOCATIONS FOR TEST FILES:
project_root/
├── debug_test_file.lua        # ← DELETE THESE
├── temp_analysis.md           # ← DELETE THESE  
├── test_output.txt            # ← DELETE THESE
└── debug_*.lua                # ← DELETE THESE

✅ CORRECT LOCATIONS FOR TEST FILES:
tests/
├── output/                    # ← Temporary test outputs
├── specs/                     # ← Test specification files  
└── temp_debug_files.lua       # ← Temporary debugging (clean up after use)
```

**Why this matters:**
- Keeps project root clean and professional
- Prevents accidental commits of debug files  
- Avoids confusion between production and test code
- Maintains clear separation of concerns

**Cleanup Command:**
```powershell
# Remove debug files from project root (run from project root)
Get-ChildItem -Name "debug_*", "test_*", "*analysis*" | Remove-Item -Force
```

## 📂 Legacy Information

### Mocks vs Fakes

- **Mocks**: Used to simulate dependencies that the code under test relies on. Located in the `mocks/` directory.
- **Fakes**: Used to create test data, particularly for simulating single-player and multiplayer scenarios. Located in the `fakes/` directory.

### Consolidated Mocks

Instead of duplicating mock implementations across test files, we use consolidated mock files:

- `mocks/tag_editor_mocks.lua`: Contains all mocks needed for testing tag editor functionality
- `mocks/mock_cache.lua`: Mock implementation of the Cache module
- `mocks/mock_modules.lua`: General mock implementations for various modules
- `mocks/mock_player_data.lua`: Mock implementations for player-related data
- `mocks/mock_storage.lua`: Mock implementation of storage functionality

### Testing Strategy

1. **Unit Tests**: Test each function in isolation, mocking all dependencies.
2. **Integration Tests**: Test how components work together, with minimal mocking.
3. **Single Player vs Multiplayer**: Use the appropriate fake data factories to test both scenarios.

---

**Note**: This test suite uses a custom testing framework optimized for Factorio mod development. The simplified smoke testing approach provides reliable regression detection while remaining maintainable and compatible with the mod's complex dependency structure.

## 📋 Quick Reference Card

### ✅ THE ONLY CORRECT WAY TO RUN TESTS

```powershell
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests"
lua infrastructure/run_all_tests.lua
```

### ✅ Alternative Using Convenience Script  

```powershell
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites\tests" 
lua run_tests.lua
```

### ❌ NEVER USE THESE - THEY CAUSE ERRORS

```powershell
# WRONG - Path errors
lua tests/infrastructure/run_all_tests.lua

# WRONG - PowerShell binding errors  
lua infrastructure/run_all_tests.lua 2>&1 | Select-String "pattern"
lua infrastructure/run_all_tests.lua | Select-String "Test files processed"

# WRONG - Can't find specs
cd infrastructure; lua run_all_tests.lua

# WRONG - Test files in project root
../debug_test.lua              # ← Keep test files in tests/ directory only!
../temp_analysis.md            # ← Keep test files in tests/ directory only!
```

### 📊 Expected Results
- **74 test files processed**
- **415 total tests run**  
- **All tests should pass**
- **Coverage report generated**

### 🧹 Project Root Cleanup
```powershell
# Clean up any test files accidentally placed in project root
Set-Location "V:\Fac2orios\2_Gemini\mods\TeleportFavorites"
Get-ChildItem -Name "debug_*", "test_*", "*analysis*" | Remove-Item -Force
```
