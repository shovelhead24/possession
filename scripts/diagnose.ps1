# diagnose.ps1
# Run this and paste the output into the chat for troubleshooting.
# Usage: powershell -ExecutionPolicy Bypass -File "C:\Games\possession\scripts\diagnose.ps1"

$projectPath = "C:\Games\possession"
$gameDir     = "$projectPath\halo-test - heightmaps 13"

Write-Host ""
Write-Host "=== SYSTEM ===" -ForegroundColor Cyan
try {
    $cs  = Get-WmiObject Win32_ComputerSystem
    $os  = Get-WmiObject Win32_OperatingSystem
    $cpu = Get-WmiObject Win32_Processor
    $gpu = Get-WmiObject Win32_VideoController
    $ram = (Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
    Write-Host "Model : $($cs.Model)"
    Write-Host "OS    : $($os.Caption)"
    Write-Host "CPU   : $($cpu.Name)"
    Write-Host "GPU   : $($gpu.Caption)"
    Write-Host "RAM   : $([math]::Round($ram, 1)) GB"
} catch {
    Write-Host "Could not read system info: $_"
}

Write-Host ""
Write-Host "=== GODOT ===" -ForegroundColor Cyan
$godotCmd = Get-Command godot* -ErrorAction SilentlyContinue | Select-Object -First 1
if ($godotCmd) {
    $version = & $godotCmd.Source --version 2>&1 | Select-Object -First 1
    Write-Host "Path   : $($godotCmd.Source)"
    Write-Host "Version: $version"
    if ($version -notmatch "^4\.5") {
        Write-Host "WARNING: Project requires Godot 4.5" -ForegroundColor Yellow
    }
} else {
    Write-Host "NOT FOUND on PATH" -ForegroundColor Red
    Write-Host "Common locations to check:" -ForegroundColor Yellow
    $candidates = @(
        "$env:USERPROFILE\Downloads\Godot*.exe",
        "$env:USERPROFILE\Desktop\Godot*.exe",
        "C:\Godot\Godot*.exe",
        "C:\Program Files\Godot\Godot*.exe"
    )
    foreach ($c in $candidates) {
        $found = Get-Item $c -ErrorAction SilentlyContinue
        if ($found) { Write-Host "  Found: $($found.FullName)" -ForegroundColor Green }
    }
}

Write-Host ""
Write-Host "=== GIT ===" -ForegroundColor Cyan
$gitOk = git -C $projectPath rev-parse HEAD 2>$null
if ($gitOk) {
    Write-Host "Repo  : OK (commit $($gitOk.Substring(0,8)))"
    git -C $projectPath log --oneline -3
    $status = git -C $projectPath status --short
    if ($status) { Write-Host "Dirty : $status" } else { Write-Host "Clean : no uncommitted changes" }
} else {
    Write-Host "NOT a git repo at: $projectPath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ASSET PACKS ===" -ForegroundColor Cyan
$packs = @(
    "custom_halo_classic_ring",
    "enemy",
    "fp_arms",
    "fps_arms",
    "halo_-_carbine",
    "halo_railgun_redesigned",
    "halo_warthog",
    "realistic_fir_trees_pack_lods_gameready",
    "realistic_trees_collection",
    "skybox",
    "grass_pack_of_9_vars_lowpoly_game_ready",
    "tall_coniferous_fir_variant_low_poly",
    "low_poly_red_spruce_tree_custom_textures"
)
foreach ($pack in $packs) {
    if (Test-Path "$gameDir\$pack") {
        Write-Host "[OK]      $pack" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $pack" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== LAST LOG (50 lines) ===" -ForegroundColor Cyan
$logFile = "$projectPath\logs\godot_latest.log"
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 50
} else {
    Write-Host "No log yet - run watch-and-run.ps1 first to generate one"
}

Write-Host ""
Write-Host "=== DONE - paste everything above into the chat ===" -ForegroundColor Cyan
