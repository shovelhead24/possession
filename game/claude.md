# Claude Code Instructions

## Project Context

This is a Godot 4.5 scifi FPS game targeting low-spec/potato hardware.
Main project folder: `game/`
Large 3D asset packs are NOT in git — they live locally only (see .gitignore).

---

## Troubleshooting From the Laptop

When something goes wrong, run the diagnose script and paste the output here:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Games\possession\scripts\diagnose.ps1"
```

---

## Running the Game Manually (Without the Watcher)

```powershell
# Replace paths to match your machine
& "C:\Godot\Godot_v4.x.exe" --path "C:\Games\possession\game" --verbose 2>&1 | Tee-Object -FilePath "$env:USERPROFILE\godot_log.txt"
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
