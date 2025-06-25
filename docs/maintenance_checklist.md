# Code Maintenance Checklist

## Daily/Weekly Maintenance

### 1. Code Quality Checks
- [ ] Run syntax validation: `lua tests/validate_syntax.lua`
- [ ] Check for unused requires: Use IDE or grep to find unused imports
- [ ] Verify error handling patterns are consistent
- [ ] Ensure all new functions have EmmyLua annotations

### 2. Documentation Updates
- [ ] Update function docstrings for any modified functions
- [ ] Keep module headers current with functionality changes
- [ ] Update architectural documentation when patterns change
- [ ] Verify locale strings are properly referenced

### 3. Pattern Consistency
- [ ] Use `ErrorHandler.debug_log()` for debugging
- [ ] Use `GameHelpers.player_print()` for user messages
- [ ] Follow established error handling patterns
- [ ] Maintain consistent naming conventions

## Monthly Reviews

### 1. Dependency Audit
- [ ] Review all `require` statements for necessity
- [ ] Check for circular dependencies
- [ ] Verify module loading order is optimal
- [ ] Update dependency documentation

### 2. Performance Review
- [ ] Check for performance hotspots in complex operations
- [ ] Review logging verbosity and impact
- [ ] Verify efficient data structure usage
- [ ] Monitor memory usage patterns

### 3. Architecture Review
- [ ] Assess module boundaries and responsibilities
- [ ] Identify opportunities for further modularization
- [ ] Review and update coding standards
- [ ] Plan architectural improvements

## Code Standards Enforcement

### 1. Function Design
- [ ] Functions should have single responsibility
- [ ] Keep functions under 50 lines when possible
- [ ] Use descriptive parameter and variable names
- [ ] Include proper error handling

### 2. Module Organization
- [ ] Group related functionality together
- [ ] Maintain clear module boundaries
- [ ] Use consistent export patterns
- [ ] Document inter-module dependencies

### 3. Error Handling
- [ ] Use centralized error logging (ErrorHandler)
- [ ] Provide user-friendly error messages
- [ ] Include sufficient debug information
- [ ] Handle edge cases gracefully

## Quick Quality Checks

### PowerShell Commands (Windows)
```powershell
# Find unused requires (basic check)
Get-ChildItem -Recurse -Filter "*.lua" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $requires = [regex]::Matches($content, 'local\s+(\w+)\s+=\s+require\("([^"]+)"\)')
    foreach ($req in $requires) {
        $varName = $req.Groups[1].Value
        if ($content -notmatch "$varName\.") {
            Write-Host "Potentially unused require: $varName in $($_.Name)"
        }
    }
}

# Check for hardcoded strings (should use locale)
Get-ChildItem -Recurse -Filter "*.lua" | Select-String -Pattern 'player\.print\("' | ForEach-Object {
    Write-Host "Hardcoded string found: $($_.Filename):$($_.LineNumber)"
}

# Find long functions (>50 lines)
Get-ChildItem -Recurse -Filter "*.lua" | ForEach-Object {
    $lines = Get-Content $_.FullName
    $inFunction = $false
    $functionStart = 0
    $functionName = ""
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "local function (\w+)" -or $lines[$i] -match "function (\w+)") {
            $inFunction = $true
            $functionStart = $i + 1
            $functionName = $matches[1]
        }
        elseif ($inFunction -and $lines[$i] -match "^end\s*$") {
            $length = $i - $functionStart
            if ($length -gt 50) {
                Write-Host "Long function ($length lines): $functionName in $($_.Name)"
            }
            $inFunction = $false
        }
    }
}
```

### Key Files to Monitor
- `core/control/*.lua` - Main control logic
- `core/utils/*.lua` - Utility modules  
- `gui/*/*.lua` - GUI modules
- `core/events/*.lua` - Event handling

### Red Flags to Watch For
- Functions over 50 lines
- Duplicate code patterns
- Hardcoded strings
- Missing error handling
- Complex nested logic
- Unused imports/variables
- Missing documentation

## Tools Integration
- **VS Code**: Use EmmyLua extension for type checking
- **Git Hooks**: Consider pre-commit hooks for basic quality checks
- **Documentation**: Keep README and architectural docs current
- **Testing**: Maintain test coverage for critical functions
