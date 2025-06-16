# Simple and reliable locale file validator for TeleportFavorites mod
# Validates that all required locale files exist and are properly formatted

param(
    [switch]$Verbose,           # Show detailed information
    [switch]$Summary            # Show only summary information
)

# Configuration
$ModPath = "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"
$LocalePath = Join-Path $ModPath "locale"

# Define expected languages and files
$Languages = @("en", "de", "fr", "es")
$RequiredFiles = @("strings.cfg", "settings.cfg", "controls.cfg")

function Write-Status {
    param($Message, $Type = "INFO")
    $Color = switch ($Type) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host $Message -ForegroundColor $Color
}

function Test-LocaleFileContent {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return @{ Valid = $false; Error = "File not found" }
    }
      try {
        $Content = Get-Content $FilePath -Encoding UTF8 -ErrorAction Stop
        $Lines = $Content
        $LineCount = $Lines.Count
        
        # Count sections [section_name] 
        $SectionCount = ($Lines | Where-Object { $_ -match "^\[.*\]$" }).Count
        
        # Count key-value pairs (not comments, not sections, not empty lines)
        $KeyCount = ($Lines | Where-Object { $_ -match "^[^#/\[\s].*=" }).Count
        
        return @{
            Valid = $true
            Lines = $LineCount
            Sections = $SectionCount
            Keys = $KeyCount
            Size = (Get-Item $FilePath).Length
        }
    }
    catch {
        return @{ Valid = $false; Error = $_.Exception.Message }
    }
}

# Main validation
Write-Status "=== TeleportFavorites Locale Validator ===" "INFO"
Write-Status ""

# Check if locale directory exists
if (-not (Test-Path $LocalePath)) {
    Write-Status "ERROR: Locale directory not found: $LocalePath" "ERROR"
    exit 1
}

$ValidationResults = @()
$TotalErrors = 0

# Check each language directory
foreach ($Lang in $Languages) {
    $LangPath = Join-Path $LocalePath $Lang
    Write-Status "Validating language: $Lang" "INFO"
    
    if (-not (Test-Path $LangPath)) {
        Write-Status "  ERROR: Language directory missing: $LangPath" "ERROR"
        $TotalErrors++
        continue
    }
    
    # Check each required file
    foreach ($File in $RequiredFiles) {
        $FilePath = Join-Path $LangPath $File
        $Result = Test-LocaleFileContent $FilePath
        
        if ($Result.Valid) {
            $Message = "  OK: $File"
            if ($Verbose) {
                $Message += " ($($Result.Keys) keys, $($Result.Sections) sections, $($Result.Lines) lines, $($Result.Size) bytes)"
            }
            Write-Status $Message "SUCCESS"
            
            $ValidationResults += [PSCustomObject]@{
                Language = $Lang
                File = $File
                Status = "Valid"
                Keys = $Result.Keys
                Sections = $Result.Sections
                Lines = $Result.Lines
                Size = $Result.Size
            }
        } else {
            Write-Status "  ERROR: $File - $($Result.Error)" "ERROR"
            $TotalErrors++
            
            $ValidationResults += [PSCustomObject]@{
                Language = $Lang
                File = $File
                Status = "Error"
                Keys = 0
                Sections = 0
                Lines = 0
                Size = 0
            }
        }
    }
    Write-Status ""
}

# Summary
Write-Status "=== VALIDATION SUMMARY ===" "INFO"
if ($TotalErrors -eq 0) {
    Write-Status "SUCCESS: All locale files are valid!" "SUCCESS"
} else {
    Write-Status "ERRORS FOUND: $TotalErrors validation failures" "ERROR"
}

if ($Summary -or $Verbose) {
    Write-Status ""
    Write-Status "File Statistics:" "INFO"
    
    foreach ($File in $RequiredFiles) {
        Write-Status "  $File Files:" "INFO"
        $FileResults = $ValidationResults | Where-Object { $_.File -eq $File }
        
        foreach ($Result in $FileResults) {
            if ($Result.Status -eq "Valid") {
                Write-Status "    $($Result.Language): $($Result.Keys) keys, $($Result.Size) bytes" "SUCCESS"
            } else {
                Write-Status "    $($Result.Language): $($Result.Status)" "ERROR"
            }
        }
    }
}

Write-Status ""
Write-Status "Expected structure verified:" "INFO"
foreach ($Lang in $Languages) {
    Write-Status "  locale/$Lang/" "INFO"
    foreach ($File in $RequiredFiles) {
        Write-Status "    $File" "INFO"
    }
}

exit $TotalErrors
