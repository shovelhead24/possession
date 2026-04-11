# extract-assets.ps1
# Extracts asset packs from assets/ into game/ if not already present.
# Safe to run multiple times - skips packs that are already extracted.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File "C:\Games\possession\scripts\extract-assets.ps1"

$projectPath = "C:\Games\possession"
$assetsDir   = "$projectPath\assets"
$gameDir     = "$projectPath\game"

# Pack zip name (in assets/) -> destination folder name (in game/)
$packs = [ordered]@{
    "halo_warthog"                          = "halo_warthog"
    "halo_-_carbine"                        = "halo_-_carbine"
    "halo_railgun_redesigned"               = "halo_railgun_redesigned"
    "fp_arms"                               = "fp_arms"
    "fps_arms"                              = "fps_arms"
    "enemy"                                 = "enemy"
    "grass_pack_of_9_vars_lowpoly_game_ready"   = "grass_pack_of_9_vars_lowpoly_game_ready"
    "realistic_fir_trees_pack_lods_gameready"   = "realistic_fir_trees_pack_lods_gameready"
    "realistic_trees_collection"                = "realistic_trees_collection"
    "tall_coniferous_fir_variant_low_poly"      = "tall_coniferous_fir_variant_low_poly"
    "low_poly_red_spruce_tree_custom_textures"  = "low_poly_red_spruce_tree_custom_textures"
    "skybox"                                    = "skybox"
    "custom_halo_classic_ring"                  = "custom_halo_classic_ring"
}

Write-Host ""
Write-Host "=== ASSET EXTRACTION ===" -ForegroundColor Cyan

$anyWork = $false

foreach ($entry in $packs.GetEnumerator()) {
    $zipPath  = "$assetsDir\$($entry.Key).zip"
    $destPath = "$gameDir\$($entry.Value)"

    if (-not (Test-Path $zipPath)) {
        Write-Host "[SKIP]   $($entry.Key).zip - not in assets/ folder" -ForegroundColor Yellow
        continue
    }

    if (Test-Path $destPath) {
        Write-Host "[OK]     $($entry.Value)" -ForegroundColor Green
        continue
    }

    Write-Host "[EXTRACT] $($entry.Key).zip -> game\$($entry.Value)\" -ForegroundColor Cyan
    $anyWork = $true
    try {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $destPath -Force
        Write-Host "[DONE]    $($entry.Value)" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL]    $($entry.Key): $_" -ForegroundColor Red
    }
}

Write-Host "========================" -ForegroundColor Cyan
if ($anyWork) {
    Write-Host "Assets extracted. Godot will import them on next launch." -ForegroundColor Green
} else {
    Write-Host "All packs already in place." -ForegroundColor Green
}
Write-Host ""
