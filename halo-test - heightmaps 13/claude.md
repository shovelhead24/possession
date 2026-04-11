# Claude Code Instructions

## Game Testing Command

After finishing any request that changes code, run the game with verbose logging:

```bash
"/Users/declan_mcgibney/Downloads/Godot.app/Contents/MacOS/Godot" --path "/Users/declan_mcgibney/Library/CloudStorage/OneDrive-TrendMicro/Documents/godot/halo-test - heightmaps 13" --verbose 2>&1 | tee ~/game_log.txt
```

This command:
- Runs the game from the Godot app bundle
- Enables verbose output for debugging
- Saves all output to `~/game_log.txt` for crash analysis

## Log Location

Game log: `~/game_log.txt`
