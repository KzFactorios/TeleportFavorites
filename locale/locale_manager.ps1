# Comprehensive locale management script for TeleportFavorites mod
# Handles validation, reporting, and future synchronization features

param(
    [switch]$Validate,          # Validate all locale files
    [switch]$Report,            # Generate detailed comparison report
    [switch]$Sync,              # Synchronize all locales with English source (future)
    [switch]$Backup,            # Create backup before making changes
    [switch]$DryRun,            # Show what would be changed without making changes
    [switch]$PruneUnused,       # Find and optionally remove unused locale keys
    [string]$Language,          # Target specific language (de, fr, es)
    [switch]$Help               # Show help information
)

# Configuration
$ModPath = "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"
$LocalePath = Join-Path $ModPath "locale"
$LogFile = Join-Path $LocalePath "locale_manager_log.txt"
$BackupPath = Join-Path $LocalePath "backups"

# Supported languages and file types
$SupportedLanguages = @("de", "fr", "es")
$SourceLanguage = "en"
$LocaleFileTypes = @("strings.cfg", "settings.cfg", "controls.cfg")

function Write-Log {
    param($Message, $Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Type] $Message"
    
    $Color = switch ($Type) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Log to file
    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    } catch {
        # Ignore logging errors
    }
}

function Get-LocaleStats {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return @{
            Exists = $false
            Keys = 0
            Sections = 0
            Lines = 0
            Size = 0
        }
    }
      try {
        $Content = Get-Content $FilePath -Encoding UTF8
        $Lines = $Content
        $LineCount = $Lines.Count
        $Sections = ($Lines | Where-Object { $_ -match "^\[.*\]$" }).Count
        $Keys = ($Lines | Where-Object { $_ -match "^[^#/\[\s].*=" }).Count
        $Size = (Get-Item $FilePath).Length
          return @{
            Exists = $true
            Keys = $Keys
            Sections = $Sections
            Lines = $LineCount
            Size = $Size
        }
    }
    catch {
        return @{
            Exists = $false
            Keys = 0
            Sections = 0
            Lines = 0
            Size = 0
        }
    }
}

function Parse-LocaleFile {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return @{}
    }
    
    try {
        $Content = Get-Content $FilePath -Encoding UTF8
        $ParsedData = @{}
        $CurrentSection = ""
        
        foreach ($Line in $Content) {
            $Line = $Line.Trim()
            
            # Skip empty lines and comments
            if ($Line -eq "" -or $Line.StartsWith("#") -or $Line.StartsWith("//")) {
                continue
            }
            
            # Section header
            if ($Line -match "^\[(.+)\]$") {
                $CurrentSection = $Matches[1]
                if (-not $ParsedData.ContainsKey($CurrentSection)) {
                    $ParsedData[$CurrentSection] = @{}
                }
                continue
            }
            
            # Key-value pair
            if ($Line -match "^([^=]+)=(.*)$" -and $CurrentSection -ne "") {
                $Key = $Matches[1].Trim()
                $Value = $Matches[2].Trim()
                $ParsedData[$CurrentSection][$Key] = $Value
            }
        }
        
        return $ParsedData
    }
    catch {
        Write-Log "Error parsing locale file $FilePath`: $($_.Exception.Message)" "ERROR"
        return @{}
    }
}

function Find-UnusedKeys {
    Write-Log "=== UNUSED KEY ANALYSIS ===" "INFO"
    
    $UnusedKeys = @{}
    
    foreach ($FileType in $LocaleFileTypes) {
        Write-Log ""
        Write-Log "Analyzing $FileType files..." "INFO"
        
        # Parse English file as source of truth
        $EnglishFile = Join-Path $LocalePath "$SourceLanguage\$FileType"
        $EnglishData = Parse-LocaleFile $EnglishFile
        
        if ($EnglishData.Count -eq 0) {
            Write-Log "  No English source file or empty: $FileType" "WARN"
            continue
        }
        
        $EnglishKeyCount = 0
        foreach ($Section in $EnglishData.Keys) {
            $EnglishKeyCount += $EnglishData[$Section].Count
        }
        Write-Log "  English source has $EnglishKeyCount keys across $($EnglishData.Count) sections" "INFO"
        
        # Check each target language
        foreach ($Lang in $SupportedLanguages) {
            if ($Language -and $Lang -ne $Language) {
                continue
            }
            
            $LangFile = Join-Path $LocalePath "$Lang\$FileType"
            $LangData = Parse-LocaleFile $LangFile
            
            if ($LangData.Count -eq 0) {
                Write-Log "  $($Lang.ToUpper()): No file or empty" "WARN"
                continue
            }
            
            $UnusedInThisFile = @()
            
            # Find keys in target language that don't exist in English
            foreach ($Section in $LangData.Keys) {
                if (-not $EnglishData.ContainsKey($Section)) {
                    # Entire section doesn't exist in English
                    foreach ($Key in $LangData[$Section].Keys) {
                        $UnusedInThisFile += "[$Section]$Key"
                    }
                    continue
                }
                
                foreach ($Key in $LangData[$Section].Keys) {
                    if (-not $EnglishData[$Section].ContainsKey($Key)) {
                        # Key doesn't exist in English section
                        $UnusedInThisFile += "[$Section]$Key"
                    }
                }
            }
            
            if ($UnusedInThisFile.Count -gt 0) {
                Write-Log "  $($Lang.ToUpper()): Found $($UnusedInThisFile.Count) unused keys:" "WARN"
                foreach ($UnusedKey in $UnusedInThisFile) {
                    Write-Log "    - $UnusedKey" "WARN"
                }
                
                # Store for potential removal
                if (-not $UnusedKeys.ContainsKey($Lang)) {
                    $UnusedKeys[$Lang] = @{}
                }
                $UnusedKeys[$Lang][$FileType] = $UnusedInThisFile
            } else {
                Write-Log "  $($Lang.ToUpper()): All keys match English source" "SUCCESS"
            }
        }
    }
    
    return $UnusedKeys
}

function Remove-UnusedKeys {
    param($UnusedKeys)
    
    if ($UnusedKeys.Count -eq 0) {
        Write-Log "No unused keys found to remove." "SUCCESS"
        return
    }
    
    Write-Log "=== REMOVING UNUSED KEYS ===" "INFO"
    
    foreach ($Lang in $UnusedKeys.Keys) {
        foreach ($FileType in $UnusedKeys[$Lang].Keys) {
            $FilePath = Join-Path $LocalePath "$Lang\$FileType"
            $UnusedKeysInFile = $UnusedKeys[$Lang][$FileType]
            
            if ($UnusedKeysInFile.Count -eq 0) {
                continue
            }
            
            Write-Log "Processing $Lang\$FileType..." "INFO"
            
            if ($Backup) {
                Create-Backup $FilePath
            }
            
            if ($DryRun) {
                Write-Log "  DRY RUN: Would remove $($UnusedKeysInFile.Count) unused keys" "INFO"
                foreach ($Key in $UnusedKeysInFile) {
                    Write-Log "    Would remove: $Key" "INFO"
                }
                continue
            }
            
            # Read the file content
            $Content = Get-Content $FilePath -Encoding UTF8
            $NewContent = @()
            $CurrentSection = ""
            $RemovedCount = 0
            
            foreach ($Line in $Content) {
                $OriginalLine = $Line
                $Line = $Line.Trim()
                
                # Track current section
                if ($Line -match "^\[(.+)\]$") {
                    $CurrentSection = $Matches[1]
                    $NewContent += $OriginalLine
                    continue
                }
                
                # Check if this is a key-value pair to potentially remove
                if ($Line -match "^([^=]+)=(.*)$" -and $CurrentSection -ne "") {
                    $Key = $Matches[1].Trim()
                    $KeyToCheck = "[$CurrentSection]$Key"
                    
                    if ($KeyToCheck -in $UnusedKeysInFile) {
                        Write-Log "    Removed unused key: $KeyToCheck" "SUCCESS"
                        $RemovedCount++
                        continue  # Skip this line (remove it)
                    }
                }
                
                # Keep all other lines (comments, empty lines, used keys)
                $NewContent += $OriginalLine
            }
            
            # Write the cleaned content back
            try {
                $NewContent | Set-Content $FilePath -Encoding UTF8
                Write-Log "  Removed $RemovedCount unused keys from $Lang\$FileType" "SUCCESS"
            }
            catch {
                Write-Log "  ERROR: Failed to write cleaned file: $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

function Create-Backup {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return
    }
    
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    }
    
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $FileName = [System.IO.Path]::GetFileName($FilePath)
    $BackupFile = Join-Path $BackupPath "${FileName}_$Timestamp.backup"
    
    try {
        Copy-Item $FilePath $BackupFile
        Write-Log "Created backup: $BackupFile" "SUCCESS"
    }
    catch {
        Write-Log "Failed to create backup: $($_.Exception.Message)" "ERROR"
    }
}

function Show-ValidationReport {
    Write-Log "=== LOCALE VALIDATION REPORT ===" "INFO"
    
    foreach ($FileType in $LocaleFileTypes) {
        Write-Log "" 
        Write-Log "File Type: $FileType" "INFO"
        Write-Log "------------------------" "INFO"
        
        # Get English baseline
        $EnglishFile = Join-Path $LocalePath "$SourceLanguage\$FileType"
        $EnglishStats = Get-LocaleStats $EnglishFile
        
        if ($EnglishStats.Exists) {
            Write-Log "  EN (source): $($EnglishStats.Keys) keys, $($EnglishStats.Sections) sections, $($EnglishStats.Size) bytes" "SUCCESS"
        } else {
            Write-Log "  EN (source): MISSING" "ERROR"
            continue
        }
        
        # Check other languages
        foreach ($Lang in $SupportedLanguages) {
            if ($Language -and $Lang -ne $Language) {
                continue
            }
            
            $LangFile = Join-Path $LocalePath "$Lang\$FileType"
            $LangStats = Get-LocaleStats $LangFile
            
            if ($LangStats.Exists) {
                $Completeness = if ($EnglishStats.Keys -gt 0) { 
                    [math]::Round(($LangStats.Keys / $EnglishStats.Keys) * 100, 1) 
                } else { 
                    100
                }
                Write-Log "  $($Lang.ToUpper()): $($LangStats.Keys) keys, $($LangStats.Sections) sections, $($LangStats.Size) bytes ($Completeness%)" "SUCCESS"
            } else {
                Write-Log "  $($Lang.ToUpper()): MISSING" "ERROR"
            }
        }
    }
}

function Show-Help {
    Write-Host @"
=== TeleportFavorites Locale Manager ===

USAGE:
  .\locale_manager.ps1 [OPTIONS]

OPTIONS:
  -Validate              Validate all locale files for consistency
  -Report                Generate detailed comparison report  
  -PruneUnused           Find and remove keys not present in English source files
  -Sync                  Synchronize all locales with English source (NOT IMPLEMENTED YET)
  -Backup                Create backup before making changes
  -DryRun                Show what would be changed without making changes
  -Language <lang>       Target specific language (de, fr, es, en)
  -Help                  Show this help information

EXAMPLES:
  .\locale_manager.ps1 -Validate                    # Validate all files
  .\locale_manager.ps1 -Report                      # Generate comparison report
  .\locale_manager.ps1 -PruneUnused -DryRun         # Show unused keys (dry run)
  .\locale_manager.ps1 -PruneUnused -Backup         # Remove unused keys with backup
  .\locale_manager.ps1 -Report -Language de         # Report for German only
  .\locale_manager.ps1 -Validate -Language fr       # Validate French files only

SUPPORTED:
  Languages: English (en), German (de), French (fr), Spanish (es)
  File Types: strings.cfg, settings.cfg, controls.cfg
  
NOTE: PruneUnused compares other language files against English as source of truth.
Synchronization features are planned for future implementation.

"@ -ForegroundColor Cyan
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

# Check prerequisites
if (-not (Test-Path $LocalePath)) {
    Write-Log "Locale directory not found: $LocalePath" "ERROR"
    exit 1
}

# Clear/initialize log file
if (Test-Path $LogFile) {
    Remove-Item $LogFile -ErrorAction SilentlyContinue
}

Write-Log "=== TeleportFavorites Locale Manager ===" "INFO"
Write-Log "Locale Path: $LocalePath" "INFO"
Write-Log "Supported Languages: $($SupportedLanguages -join ', ')" "INFO"
Write-Log "File Types: $($LocaleFileTypes -join ', ')" "INFO"

if ($Language) {
    if ($Language -notin (@($SourceLanguage) + $SupportedLanguages)) {
        Write-Log "Invalid language: $Language. Supported: $($SourceLanguage), $($SupportedLanguages -join ', ')" "ERROR"
        exit 1
    }
    Write-Log "Target Language: $Language" "INFO"
}

# Execute requested operations
if ($Validate) {
    Write-Log "Starting validation..." "INFO"
    
    $ErrorCount = 0
    foreach ($Lang in (@($SourceLanguage) + $SupportedLanguages)) {
        if ($Language -and $Lang -ne $Language) {
            continue
        }
        
        $LangPath = Join-Path $LocalePath $Lang
        if (-not (Test-Path $LangPath)) {
            Write-Log "Language directory missing: $LangPath" "ERROR"
            $ErrorCount++
            continue
        }
        
        foreach ($FileType in $LocaleFileTypes) {
            $FilePath = Join-Path $LangPath $FileType
            $Stats = Get-LocaleStats $FilePath
            
            if ($Stats.Exists) {
                Write-Log "OK: $Lang\$FileType ($($Stats.Keys) keys)" "SUCCESS"
            } else {
                Write-Log "MISSING: $Lang\$FileType" "ERROR"
                $ErrorCount++
            }
        }
    }
    
    if ($ErrorCount -eq 0) {
        Write-Log "Validation completed successfully!" "SUCCESS"
    } else {
        Write-Log "Validation completed with $ErrorCount errors" "ERROR"
    }
}

if ($Report) {
    Show-ValidationReport
}

if ($PruneUnused) {
    Write-Log "Starting unused key analysis..." "INFO"
    $UnusedKeys = Find-UnusedKeys
    
    if ($UnusedKeys.Count -gt 0) {
        if ($DryRun) {
            Write-Log "DRY RUN: Found unused keys but not removing them" "INFO"
        } else {
            Remove-UnusedKeys $UnusedKeys
        }
    } else {
        Write-Log "No unused keys found - all locale files are clean!" "SUCCESS"
    }
}

if ($Sync) {
    Write-Log "Synchronization feature is not yet implemented." "WARN"
    Write-Log "This feature will be added in a future version." "WARN"
    Write-Log "For now, use -Validate and -Report to analyze locale files." "WARN"
}

Write-Log "=== LOCALE MANAGER COMPLETE ===" "INFO"
