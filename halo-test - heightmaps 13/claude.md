# Claude Code Instructions

## Project Context

This is a Godot 4.5 scifi FPS game targeting low-spec/potato hardware.
Main project folder: `halo-test - heightmaps 13/`
Large 3D asset packs are NOT in git — they live locally only (see .gitignore).

---

## Troubleshooting From the Laptop

When something goes wrong on the laptop, run this PowerShell one-liner and
paste the full output into the chat:

```powershell
powershell -ExecutionPolicy Bypass -Command "
Write-Host '=== SYSTEM ===';
(Get-WmiObject Win32_ComputerSystem).Model;
(Get-WmiObject Win32_OperatingSystem).Caption;
(Get-WmiObject Win32_Processor).Name;
(Get-WmiObject Win32_VideoController).Caption;
(Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB;
Write-Host '=== GODOT ===';
\$g = (Get-Command godot* -ErrorAction SilentlyContinue | Select-Object -First 1).Source;
if (\$g) { & \$g --version } else { 'godot not on PATH - specify full path' };
Write-Host '=== GIT ===';
git -C 'C:\Games\possession' log --oneline -3;
git -C 'C:\Games\possession' status --short;
Write-Host '=== ASSET PACKS ===';
@('custom_halo_classic_ring','enemy','fp_arms','fps_arms','halo_-_carbine','halo_railgun_redesigned','halo_warthog','realistic_fir_trees_pack_lods_gameready','realistic_trees_collection','skybox','grass_pack_of_9_vars_lowpoly_game_ready','tall_coniferous_fir_variant_low_poly','low_poly_red_spruce_tree_custom_textures') | ForEach-Object { if (Test-Path \"C:\Games\possession\halo-test - heightmaps 13\\\$_\") { \"[OK] \$_\" } else { \"[MISSING] \$_\" } };
Write-Host '=== LAST LOG (50 lines) ===';
if (Test-Path 'C:\Games\possession\logs\godot_latest.log') { Get-Content 'C:\Games\possession\logs\godot_latest.log' -Tail 50 } else { 'No log found — run watch-and-run.ps1 first' }
"
```

**If you cloned to a different path**, replace `C:\Games\possession` with your actual path before running.

---

## Running the Game Manually (Without the Watcher)

```powershell
# Replace paths to match your machine
& "C:\Godot\Godot_v4.x.exe" --path "C:\Games\possession\halo-test - heightmaps 13" --verbose 2>&1 | Tee-Object -FilePath "$env:USERPROFILE\godot_log.txt"
```

Log saved to: `%USERPROFILE%\godot_log.txt`

---

## Running the Auto-Watcher

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Games\possession\scripts\watch-and-run.ps1"
```

Logs written to: `C:\Games\possession\logs\godot_latest.log`

---

## After Each Code Change

The watcher handles this automatically. For manual testing, just close and
relaunch Godot — GDScript is interpreted, no compile step needed.
