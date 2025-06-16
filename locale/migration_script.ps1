# TeleportFavorites Localization Migration Script
# This script helps identify and track hardcoded strings that need to be replaced with LocaleUtils calls

param(
    [switch]$Scan,           # Scan for hardcoded strings
    [switch]$Report,         # Generate migration report  
    [switch]$Replace,        # Perform automated replacements (use with caution)
    [string]$TargetFile,     # Target specific file for operations
    [switch]$DryRun          # Show what would be changed without making changes
)

# Configuration
$ModPath = "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"
$LogFile = Join-Path $ModPath "locale\migration_log.txt"

# Known hardcoded strings that need replacement
$KnownStrings = @{
    "Are you crazy? Trying to teleport while driving is strictly prohibited." = @{
        Category = "error"
        Key = "driving_teleport_blocked"
        Files = @("core\pattern\teleport_strategy.lua")
    }
    "Unable to teleport. Player is missing" = @{
        Category = "error" 
        Key = "player_missing"
        Files = @("core\pattern\teleport_strategy.lua")
    }
    "Unable to teleport. Player character is missing" = @{
        Category = "error"
        Key = "player_character_missing" 
        Files = @("core\pattern\teleport_strategy.lua")
    }
    "Confirm" = @{
        Category = "gui"
        Key = "confirm"
        Files = @("gui\tag_editor\tag_editor_gui.lua")
    }
    "Cancel" = @{
        Category = "gui"
        Key = "cancel"
        Files = @("gui\tag_editor\tag_editor_gui.lua")
    }
    "Delete Tag" = @{
        Category = "gui"
        Key = "delete_tag"
        Files = @("gui\tag_editor\tag_editor_gui.lua")
    }
    "Teleported successfully!" = @{
        Category = "gui"
        Key = "teleport_success"
        Files = @("core\pattern\teleport_strategy.lua")
    }
}

# Patterns to identify string literals
$StringPatterns = @(
    'GameHelpers\.player_print\([^,]+,\s*"([^"]+)"',
    'player\.print\s*\(\s*"([^"]+)"',
    'caption\s*=\s*"([^"]+)"',
    'tooltip\s*=\s*"([^"]+)"',
    'name\s*=\s*"([^"]+)"',
    'text\s*=\s*"([^"]+)"'
)

function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

function Scan-HardcodedStrings {
    param($FilePath)
    
    Write-Log "Scanning file: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath"
        return @()
    }
    
    $Content = Get-Content $FilePath -Raw
    $Found = @()
    
    foreach ($Pattern in $StringPatterns) {
        $Matches = [regex]::Matches($Content, $Pattern)
        foreach ($Match in $Matches) {
            if ($Match.Groups.Count -gt 1) {
                $StringValue = $Match.Groups[1].Value
                $Found += @{
                    File = $FilePath
                    Line = ($Content.Substring(0, $Match.Index) -split "`n").Count
                    Pattern = $Pattern
                    String = $StringValue
                    FullMatch = $Match.Value
                }
            }
        }
    }
    
    return $Found
}

function Generate-MigrationReport {
    Write-Log "Generating migration report..."
    
    $AllFindings = @()
    $LuaFiles = Get-ChildItem -Path $ModPath -Filter "*.lua" -Recurse
    
    foreach ($File in $LuaFiles) {
        $Findings = Scan-HardcodedStrings -FilePath $File.FullName
        $AllFindings += $Findings
    }
    
    # Generate report
    $ReportPath = Join-Path $ModPath "locale\migration_report.md"
    $Report = @"
# TeleportFavorites Localization Migration Report

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Summary
- Total files scanned: $($LuaFiles.Count)
- Total hardcoded strings found: $($AllFindings.Count)
- Files with hardcoded strings: $($AllFindings | Group-Object File | Measure-Object).Count

## Findings by File

"@

    # Group findings by file
    $GroupedFindings = $AllFindings | Group-Object File
    
    foreach ($FileGroup in $GroupedFindings) {
        $Report += "`n### $($FileGroup.Name)`n"
        $Report += "Found $($FileGroup.Count) hardcoded strings:`n`n"
        
        foreach ($Finding in $FileGroup.Group) {
            $Report += "- **Line $($Finding.Line)**: `"$($Finding.String)`"`n"
            
            # Check if we have a known replacement
            $KnownReplacement = $KnownStrings[$Finding.String]
            if ($KnownReplacement) {
                $Report += "  - **Replacement**: `LocaleUtils.get_$($KnownReplacement.Category)_string(player, `"$($KnownReplacement.Key)`")`n"
                $Report += "  - **Status**: ✅ Ready for migration`n"
            } else {
                $Report += "  - **Status**: ❌ Needs locale key assignment`n"
            }
            $Report += "`n"
        }
    }
    
    # Add priority recommendations
    $Report += @"

## Migration Priority

### High Priority (User-facing errors)
"@
    
    foreach ($Finding in $AllFindings) {
        if ($Finding.String -match "error|fail|unable|invalid|blocked") {
            $Report += "- `"$($Finding.String)`" in $($Finding.File):$($Finding.Line)`n"
        }
    }
    
    $Report += @"

### Medium Priority (GUI elements)
"@
    
    foreach ($Finding in $AllFindings) {
        if ($Finding.String -match "confirm|cancel|delete|close|save|open") {
            $Report += "- `"$($Finding.String)`" in $($Finding.File):$($Finding.Line)`n"
        }
    }
    
    $Report += @"

## Next Steps

1. **Review unknown strings** - Assign locale keys for strings not in known mappings
2. **Add to locale files** - Add new keys to all language files
3. **Update LocaleUtils** - Add fallback strings for critical messages
4. **Replace in code** - Use this script with -Replace flag for automated replacements
5. **Test thoroughly** - Validate all replacements work correctly

## Automated Replacement Commands

```powershell
# Replace known strings (dry run first)
.\locale\migration_script.ps1 -Replace -DryRun

# Replace known strings (actual changes)
.\locale\migration_script.ps1 -Replace
```
"@

    Set-Content -Path $ReportPath -Value $Report
    Write-Log "Migration report generated: $ReportPath"
}

function Perform-StringReplacement {
    param($FilePath, $DryRun = $false)
    
    Write-Log "Processing file for replacement: $FilePath"
    
    $Content = Get-Content $FilePath -Raw
    $Modified = $false
    $Changes = @()
    
    foreach ($StringEntry in $KnownStrings.GetEnumerator()) {
        $OriginalString = $StringEntry.Key
        $Config = $StringEntry.Value
        
        # Pattern to match GameHelpers.player_print calls with this string
        $Pattern = "GameHelpers\.player_print\(([^,]+),\s*`"$([regex]::Escape($OriginalString))`"\)"
        $Replacement = "GameHelpers.player_print(`$1, LocaleUtils.get_$($Config.Category)_string(`$1, `"$($Config.Key)`"))"
        
        if ($Content -match $Pattern) {
            if (-not $DryRun) {
                $Content = $Content -replace $Pattern, $Replacement
                $Modified = $true
            }
            $Changes += "Replaced: `"$OriginalString`" -> LocaleUtils.get_$($Config.Category)_string(player, `"$($Config.Key)`")"
        }
        
        # Pattern for GUI element captions
        $GuiPattern = "caption\s*=\s*`"$([regex]::Escape($OriginalString))`""
        $GuiReplacement = "caption = LocaleUtils.get_$($Config.Category)_string(player, `"$($Config.Key)`")"
        
        if ($Content -match $GuiPattern) {
            if (-not $DryRun) {
                $Content = $Content -replace $GuiPattern, $GuiReplacement
                $Modified = $true
            }
            $Changes += "Replaced GUI caption: `"$OriginalString`" -> LocaleUtils.get_$($Config.Category)_string(player, `"$($Config.Key)`")"
        }
    }
    
    if ($Changes.Count -gt 0) {
        Write-Log "Changes for $FilePath"
        foreach ($Change in $Changes) {
            Write-Log "  $Change"
        }
        
        if ($Modified -and -not $DryRun) {
            Set-Content -Path $FilePath -Value $Content
            Write-Log "File updated: $FilePath"
        } elseif ($DryRun) {
            Write-Log "DRY RUN - No changes made to: $FilePath"
        }
    }
}

# Main execution logic
Write-Log "TeleportFavorites Localization Migration Script Started"

# Ensure log directory exists
$LocaleDir = Join-Path $ModPath "locale"
if (-not (Test-Path $LocaleDir)) {
    New-Item -Path $LocaleDir -ItemType Directory -Force
}

if ($Scan -or $Report) {
    Generate-MigrationReport
}

if ($Replace) {
    Write-Log "Starting string replacement process (DryRun: $DryRun)"
    
    if ($TargetFile) {
        $FullPath = Join-Path $ModPath $TargetFile
        Perform-StringReplacement -FilePath $FullPath -DryRun $DryRun
    } else {
        # Process all known files
        $AllTargetFiles = @()
        foreach ($StringEntry in $KnownStrings.GetEnumerator()) {
            $AllTargetFiles += $StringEntry.Value.Files
        }
        
        $UniqueFiles = $AllTargetFiles | Sort-Object | Get-Unique
        
        foreach ($File in $UniqueFiles) {
            $FullPath = Join-Path $ModPath $File
            if (Test-Path $FullPath) {
                Perform-StringReplacement -FilePath $FullPath -DryRun $DryRun
            } else {
                Write-Log "File not found: $FullPath"
            }
        }
    }
}

Write-Log "Migration script completed"

# Usage examples
if (-not ($Scan -or $Report -or $Replace)) {
    Write-Host @"

TeleportFavorites Localization Migration Script

Usage Examples:
  .\migration_script.ps1 -Report          # Generate migration report
  .\migration_script.ps1 -Replace -DryRun # Preview changes without applying
  .\migration_script.ps1 -Replace         # Apply automated replacements
  .\migration_script.ps1 -TargetFile "core\pattern\teleport_strategy.lua" -Replace -DryRun

Options:
  -Scan         Scan for hardcoded strings
  -Report       Generate comprehensive migration report  
  -Replace      Perform automated string replacements
  -TargetFile   Target specific file for operations
  -DryRun       Show what would be changed without making changes

"@
}
