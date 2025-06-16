# TeleportFavorites - Hardcoded String Detection Script
# This script searches for potential hardcoded strings that should be localized
#
# IMPORTANT: Not all detected strings need localization!
# - USER-FACING strings (GUI, errors, notifications) = LOCALIZE
# - DEVELOPER strings (debug logs, internal validation) = KEEP HARDCODED

param(
    [switch]$Detailed,  # Show detailed matches with context
    [switch]$Report,    # Generate a summary report
    [switch]$Verbose    # Show verbose output including excluded files
)

$ModPath = $PSScriptRoot + "\.."
$ExcludePatterns = @(
    "*.md", "*.txt", "*.cfg", "*.ps1", "*.log", 
    "*\.github*", "*\graphics\*", "*\notes\*", "*\docs\*",
    "*\locale\*", "*\tests\*", "*test_*.lua", "test_*.lua"
)

$HardcodedPatterns = @{
    "player_print_hardcoded" = 'player\.print\s*\(\s*"[^"]*"'
    "game_print_hardcoded" = 'game\.print\s*\(\s*"[^"]*"'
    "direct_string_messages" = 'GameHelpers\.player_print\s*\([^,]*,\s*"[^"]*"'
    "error_messages" = '"(\[ERROR\]|\[WARN\]|\[INFO\]|Error:|Warning:|Invalid|Failed|Cannot|Unable)[^"]*"'
    "gui_captions" = 'caption\s*=\s*"[^"]*"'
    "gui_tooltips" = 'tooltip\s*=\s*"[^"]*"'
    "teleport_messages" = '"[^"]*[Tt]eleport[^"]*"'
    "position_messages" = '"[^"]*[Pp]osition[^"]*"'
    "tag_messages" = '"[^"]*[Tt]ag[^"]*"'
    "fallback_strings" = '"\[invalid[^"]*\]"'
    "mod_name_strings" = '"\[TeleportFavorites\][^"]*"'
}

function Test-ShouldExclude {
    param($FilePath)
    
    # Convert to relative path for consistent checking
    $relativePath = $FilePath.Replace($ModPath, "").TrimStart("\").Replace("\", "/")
    $fileName = Split-Path $FilePath -Leaf
    
    # Exclude files that start with test_
    if ($fileName -like "test_*") {
        Write-Verbose "Excluding test file: $fileName"
        return $true
    }
    
    # Exclude files in tests directory (more robust checking)
    if ($relativePath -match "^tests/" -or $relativePath -match "/tests/") {
        Write-Verbose "Excluding file in tests directory: $relativePath"
        return $true
    }
    
    # Check other exclusion patterns
    foreach ($pattern in $ExcludePatterns) {
        if ($FilePath -like $pattern) {
            Write-Verbose "Excluding file matching pattern '$pattern': $relativePath"
            return $true
        }
    }
    
    return $false
}

function Search-HardcodedStrings {
    param(
        [string]$FilePath,
        [hashtable]$Patterns
    )
    
    if (Test-ShouldExclude $FilePath) {
        return @()
    }
    
    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $results = @()
        
        foreach ($patternName in $Patterns.Keys) {
            $pattern = $Patterns[$patternName]
            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            foreach ($match in $matches) {
                # Get line number
                $beforeMatch = $content.Substring(0, $match.Index)
                $lineNumber = ($beforeMatch -split "`n").Length
                
                # Get context (surrounding lines)
                $lines = $content -split "`n"
                $startLine = [Math]::Max(0, $lineNumber - 3)
                $endLine = [Math]::Min($lines.Length - 1, $lineNumber + 1)
                $context = $lines[$startLine..$endLine] -join "`n"
                
                $results += [PSCustomObject]@{
                    File = $FilePath
                    Pattern = $patternName
                    Match = $match.Value
                    LineNumber = $lineNumber
                    Context = $context
                }
            }
        }
        
        return $results
    }
    catch {
        Write-Warning "Could not read file: $FilePath - $($_.Exception.Message)"
        return @()
    }
}

function Get-LuaFiles {
    param([string]$Path)
    
    Get-ChildItem -Path $Path -Recurse -Filter "*.lua" | 
        Where-Object { -not (Test-ShouldExclude $_.FullName) } |
        ForEach-Object { $_.FullName }
}

# Main execution
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Write-Host "TeleportFavorites Hardcoded String Detection" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$luaFiles = Get-LuaFiles $ModPath
Write-Host "Scanning $($luaFiles.Count) Lua files..." -ForegroundColor Yellow

$allResults = @()
$fileCount = 0

foreach ($file in $luaFiles) {
    $fileCount++
    $relativePath = $file.Replace($ModPath, "").TrimStart("\")
    Write-Progress -Activity "Scanning for hardcoded strings" -Status $relativePath -PercentComplete (($fileCount / $luaFiles.Count) * 100)
    
    $results = Search-HardcodedStrings -FilePath $file -Patterns $HardcodedPatterns
    $allResults += $results
}

Write-Progress -Activity "Scanning for hardcoded strings" -Completed

# Group results by pattern
$groupedResults = $allResults | Group-Object Pattern

Write-Host ""
Write-Host "SUMMARY RESULTS" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Green

if ($allResults.Count -eq 0) {
    Write-Host "✅ No hardcoded strings detected!" -ForegroundColor Green
} else {
    Write-Host "Found $($allResults.Count) potential hardcoded strings in $($($allResults | Select-Object File -Unique).Count) files" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($group in $groupedResults) {
        $count = $group.Count
        $patternName = $group.Name
        Write-Host "  $patternName : $count matches" -ForegroundColor White
    }
}

if ($Detailed -and $allResults.Count -gt 0) {
    Write-Host ""
    Write-Host "DETAILED RESULTS" -ForegroundColor Green
    Write-Host "================" -ForegroundColor Green
    
    foreach ($group in $groupedResults) {
        Write-Host ""
        Write-Host "Pattern: $($group.Name)" -ForegroundColor Cyan
        Write-Host ("-" * 50) -ForegroundColor Cyan
        
        foreach ($result in $group.Group) {
            $relativePath = $result.File.Replace($ModPath, "").TrimStart("\")
            Write-Host ""
            Write-Host "File: $relativePath (Line $($result.LineNumber))" -ForegroundColor Yellow
            Write-Host "Match: $($result.Match)" -ForegroundColor Red
            
            if ($result.Context) {
                Write-Host "Context:" -ForegroundColor Gray
                Write-Host $result.Context -ForegroundColor DarkGray
            }
        }
    }
}

if ($Report) {
    $reportPath = Join-Path $PSScriptRoot "hardcoded_strings_scan_results.json"
    $allResults | ConvertTo-Json -Depth 3 | Out-File $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "RECOMMENDATIONS" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Green

if ($allResults.Count -gt 0) {
    Write-Host "1. Review each match to determine if it should be localized"
    Write-Host "2. Replace user-facing strings with LocaleUtils.get_*_string() calls"
    Write-Host "3. Add corresponding keys to locale/en/strings.cfg"
    Write-Host "4. Use locale sync tools to propagate to other languages"
    Write-Host "5. Test with different language settings"
    Write-Host ""
    Write-Host "Priority files to review:"
    
    $fileStats = $allResults | Group-Object File | Sort-Object Count -Descending | Select-Object -First 5
    foreach ($fileStat in $fileStats) {
        $relativePath = $fileStat.Name.Replace($ModPath, "").TrimStart("\")
        Write-Host "  - $relativePath ($($fileStat.Count) matches)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ No action needed - localization appears complete!"
}

Write-Host ""
Write-Host "Scan completed." -ForegroundColor Cyan
