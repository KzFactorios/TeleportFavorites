# PowerShell Best Practices for TeleportFavorites Development

## Overview
This document captures PowerShell anti-patterns and best practices discovered during TeleportFavorites mod development. The project uses PowerShell as the primary shell on Windows, and many common command patterns can fail due to PowerShell's object-oriented nature.

## Common Anti-Patterns and Fixes

### 1. Select-String Parameter Binding Failures

**❌ BROKEN PATTERN:**
```powershell
.\.test.ps1 | Select-String -Pattern "Total tests.*:" -A 2
```
**ERROR:** `The input object cannot be bound to any parameters for the command`

**ROOT CAUSE:** PowerShell scripts often output objects, not strings. Select-String expects string input but receives custom objects from the script output.

**✅ CORRECT SOLUTIONS:**
```powershell
# Option 1: Force string conversion with parentheses
(.\.test.ps1) | Select-String -Pattern "pattern"

# Option 2: Use Out-String to convert objects to strings
.\.test.ps1 | Out-String | Select-String -Pattern "pattern"

# Option 3: Use Out-String with -Stream for line-by-line processing
.\.test.ps1 | Out-String -Stream | Select-String -Pattern "pattern"
```

### 2. Complex Pattern Matching Issues

**❌ BROKEN PATTERN:**
```powershell
.\.test.ps1 | Select-String -Pattern "Failed|Total tests passed|Total tests failed" -Context 1
```
**ERROR:** Multiple parameter binding exceptions

**ROOT CAUSE:** Complex regex patterns combined with object pipeline issues cause cascading failures.

**✅ CORRECT SOLUTIONS:**
```powershell
# Simplify and use Out-String
.\.test.ps1 | Out-String | Select-String -Pattern "Failed"
.\.test.ps1 | Out-String | Select-String -Pattern "Total tests"

# Or capture output first, then process
$output = .\.test.ps1
$output | Out-String | Select-String -Pattern "Failed|Total tests"
```

### 3. File Content Processing Anti-Patterns

**❌ BROKEN UNIX-STYLE:**
```bash
grep -n "pattern" file.txt
head -10 file.txt  
tail -f log.txt
sed 's/old/new/g' file.txt
```

**✅ CORRECT POWERSHELL:**
```powershell
# Search with line numbers
Select-String -Pattern "pattern" -Path "file.txt" -AllMatches

# Get first/last lines
Get-Content "file.txt" | Select-Object -First 10
Get-Content "file.txt" | Select-Object -Last 10

# Watch file changes
Get-Content "file.txt" -Wait -Tail 10

# Replace content
(Get-Content "file.txt") -replace "old", "new" | Set-Content "file.txt"
```

### 4. Test Output Processing Best Practices

**SITUATION:** Processing test runner output to extract pass/fail statistics

**❌ AVOID:**
```powershell
# Complex patterns with context switches
.\.test.ps1 | Select-String -Pattern "complex.*pattern" -A 5 -B 3
```

**✅ RECOMMENDED:**
```powershell
# Capture, convert, then process
$testOutput = .\.test.ps1 | Out-String
$testOutput | Select-String -Pattern "Total tests passed: (\d+)"
$testOutput | Select-String -Pattern "Total tests failed: (\d+)"

# Or use simple patterns
.\.test.ps1 | Out-String | Select-String -Pattern "Failed|Passed"
```

## PowerShell vs Bash Mental Model

### Key Differences:
- **Bash:** Text streams, everything is a string
- **PowerShell:** Object streams, structured data with properties and methods

### Pipeline Behavior:
```powershell
# Bash: Always text
ls | grep pattern  # Text → Text

# PowerShell: Objects unless converted
Get-ChildItem | Where-Object { $_.Name -match "pattern" }  # Objects → Objects
Get-ChildItem | Out-String | Select-String "pattern"      # Objects → Text → Text
```

## Debugging Failed Commands

### Step-by-Step Approach:
1. **Identify the error type:** Parameter binding? Invalid operation? 
2. **Check pipeline types:** Are you passing objects where strings are expected?
3. **Test with simpler patterns:** Remove complex regex, context switches, etc.
4. **Add Out-String strategically:** Convert objects to strings at the right points
5. **Use parentheses for grouping:** Force evaluation order and type conversion

### Common Error Messages and Solutions:

**"The input object cannot be bound to any parameters"**
- **Solution:** Add `| Out-String` before the failing cmdlet

**"Cannot bind parameter... does not match any of the parameters"**  
- **Solution:** Check parameter names and values, ensure correct types

**"Object reference not set to an instance of an object"**
- **Solution:** Check for null values, add validation

## Best Practices Summary

1. **Always prefer PowerShell native cmdlets** over Unix-style commands
2. **Use Out-String when piping script output** to text-processing cmdlets
3. **Test complex commands incrementally** - start simple, add complexity
4. **Capture output in variables** for repeated processing
5. **Use parentheses** to control evaluation order and type conversion
6. **Prefer explicit parameter names** over positional parameters for clarity
7. **Handle errors gracefully** with try/catch or -ErrorAction parameters

## Project-Specific Patterns

### Test Execution:
```powershell
# Preferred pattern for test result analysis
$testResults = .\.test.ps1 | Out-String
$passCount = ($testResults | Select-String "Total tests passed: (\d+)").Matches[0].Groups[1].Value
$failCount = ($testResults | Select-String "Total tests failed: (\d+)").Matches[0].Groups[1].Value
```

### File Processing:
```powershell
# Safe file modification pattern
$content = Get-Content "file.lua"
$modified = $content -replace "old_pattern", "new_pattern"
$modified | Set-Content "file.lua"
```

### Line Counting:
```powershell
# Count lines in Lua files
(Get-ChildItem -Path "." -Filter "*.lua" -Recurse | Get-Content | Measure-Object -Line).Lines
```

---

*This document should be updated whenever new PowerShell anti-patterns are discovered during development.*
