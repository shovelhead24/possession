# possession
Open and deep system gameplay and procedural rendering for low spec hardware

## Running on the laptop (watch-and-run)

The watcher polls GitHub every 15 seconds, auto-pulls new commits, and relaunches Godot automatically.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\watch-and-run.ps1
```

Run this once from the repo root (`C:\Games\possession`) and leave the window open. Godot will relaunch whenever new code is pushed.

**First-time setup:**
1. Edit the top of `scripts\watch-and-run.ps1` and set `$projectPath` and `$godotExe` to match your machine
2. Copy asset packs into `game\` (see Missing Asset Packs warning on first run)
3. Run the command above

**Shortcuts while running:**
| Key | Action |
|-----|--------|
| `L` | Push the current Godot log to the repo immediately |
| Auto | Log is also pushed every ~5 minutes automatically |

**In-game shortcuts:**
| Key / Button | Action |
|---|---|
| D-pad Up / `R` | Git pull latest commits and reload the scene |
| `F` | Toggle fly mode |
| `Escape` | Release mouse cursor |
| `1`–`7` | Switch biome |
