# PowerShell script to move unused PNG files to sprite_shop folder

$filesToMove = @(
    "button_tapered_right_orange_new.png",
    "factorio-gui-new.png",
    "icons8-lock-a75.png",
    "icons8-lock.png",
    "orange_button_base.png",
    "orange_button_taper.png",
    "slot_orange_24.png", 
    "slot_orange_b.png",
    "teleport_button.png",
    "the_button_shape.png",
    "the_shape.png"
)

$sourceFolder = "v:\Fac2orios\2_Gemini\mods\TeleportFavorites\graphics\"
$targetFolder = "v:\Fac2orios\2_Gemini\mods\TeleportFavorites\graphics\sprite_shop\"

# Create target folder if it doesn't exist
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force
}

# Move each file if it exists
foreach ($file in $filesToMove) {
    $sourcePath = Join-Path -Path $sourceFolder -ChildPath $file
    $targetPath = Join-Path -Path $targetFolder -ChildPath $file
    
    if (Test-Path $sourcePath) {
        Write-Host "Moving $file to sprite_shop folder..."
        Move-Item -Path $sourcePath -Destination $targetPath -Force
    } else {
        Write-Host "File $file not found in source directory."
    }
}

Write-Host "Done!"
