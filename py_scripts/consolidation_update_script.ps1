# PowerShell script to systematically replace imports and function calls
# This script performs the REAL consolidation by updating all references to use consolidated modules

# Define the replacement mappings
$ImportReplacements = @{
    'require\("core\.utils\.gps_core"\)' = 'require("core.utils.gps_utils")'
    'require\("core\.utils\.table_helpers"\)' = 'require("core.utils.collection_utils")'
    'require\("core\.utils\.position_helpers"\)' = 'require("core.utils.position_utils")'
    'require\("core\.utils\.position_normalizer"\)' = 'require("core.utils.position_utils")'
    'require\("core\.utils\.position_validator"\)' = 'require("core.utils.position_utils")'
    'require\("core\.utils\.validation_helpers"\)' = 'require("core.utils.validation_utils")'
    'require\("core\.utils\.chart_tag_spec_builder"\)' = 'require("core.utils.chart_tag_utils")'
    'require\("core\.utils\.chart_tag_click_detector"\)' = 'require("core.utils.chart_tag_utils")'
    'require\("core\.utils\.functional_helpers"\)' = 'require("core.utils.collection_utils")'
    'require\("core\.utils\.math_helpers"\)' = 'require("core.utils.collection_utils")'
    'require\("core\.utils\.style_helpers"\)' = 'require("core.utils.gui_utils")'
    'require\("core\.utils\.rich_text_formatter"\)' = 'require("core.utils.gui_utils")'
}

$VariableReplacements = @{
    'local gps_core' = 'local GPSUtils'
    'local GPSCore' = 'local GPSUtils'
    'local TableHelpers' = 'local CollectionUtils'
    'local position_helpers' = 'local PositionUtils'
    'local position_normalizer' = 'local PositionUtils'
    'local PositionValidator' = 'local PositionUtils'
    'local ValidationHelpers' = 'local ValidationUtils'
    'local ChartTagSpecBuilder' = 'local ChartTagUtils'
    'local FunctionalHelpers' = 'local CollectionUtils'
    'local MathHelpers' = 'local CollectionUtils'
    'local StyleHelpers' = 'local GuiUtils'
    'local RichTextFormatter' = 'local GuiUtils'
}

$FunctionCallReplacements = @{
    'gps_core\.' = 'GPSUtils.'
    'GPSCore\.' = 'GPSUtils.'
    'TableHelpers\.' = 'CollectionUtils.'
    'position_helpers\.' = 'PositionUtils.'
    'position_normalizer\.' = 'PositionUtils.'
    'PositionValidator\.' = 'PositionUtils.'
    'ValidationHelpers\.' = 'ValidationUtils.'
    'ChartTagSpecBuilder\.' = 'ChartTagUtils.'
    'FunctionalHelpers\.' = 'CollectionUtils.'
    'MathHelpers\.' = 'CollectionUtils.'
    'StyleHelpers\.' = 'GuiUtils.'
    'RichTextFormatter\.' = 'GuiUtils.'
}

function Update-FileImports {
    param([string]$FilePath)
    
    Write-Host "Processing: $FilePath"
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    
    # Update require statements
    foreach ($pattern in $ImportReplacements.Keys) {
        $replacement = $ImportReplacements[$pattern]
        $content = $content -replace $pattern, $replacement
    }
    
    # Update variable declarations
    foreach ($pattern in $VariableReplacements.Keys) {
        $replacement = $VariableReplacements[$pattern]
        $content = $content -replace [regex]::Escape($pattern), $replacement
    }
    
    # Update function calls
    foreach ($pattern in $FunctionCallReplacements.Keys) {
        $replacement = $FunctionCallReplacements[$pattern]
        $content = $content -replace $pattern, $replacement
    }
    
    # Only write if content changed
    if ($content -ne $originalContent) {
        Set-Content $FilePath $content -NoNewline
        Write-Host "  ✓ Updated $FilePath"
        return $true
    } else {
        Write-Host "  - No changes needed for $FilePath"
        return $false
    }
}

# Get all Lua files except the ones we're consolidating into
$luaFiles = Get-ChildItem -Path "v:\Fac2orios\2_Gemini\mods\TeleportFavorites" -Recurse -Include "*.lua" |
    Where-Object { 
        $_.Name -notmatch "^(position|gps|collection|chart_tag|validation|gui)_utils\.lua$" -and
        $_.Name -notmatch "^utils\.lua$" -and
        $_.Name -notmatch "^test_.*\.lua$"
    }

$updatedCount = 0
$totalCount = $luaFiles.Count

Write-Host "Starting consolidation import updates..."
Write-Host "Processing $totalCount files..."
Write-Host ""

foreach ($file in $luaFiles) {
    if (Update-FileImports $file.FullName) {
        $updatedCount++
    }
}

Write-Host ""
Write-Host "Consolidation import update complete!"
Write-Host "Updated: $updatedCount files"
Write-Host "Total processed: $totalCount files"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Test the mod to ensure it loads correctly"
Write-Host "2. Run a quick functionality test"
Write-Host "3. If all works, delete the original scattered files"
