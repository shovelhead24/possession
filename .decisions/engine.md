# Engine / Godot

### reload-via-quit — Reload is full quit + relaunch, never reload_current_scene()
**Date:** 2026-04-12 (recorded 2026-07-18)
**Status:** active
**Decision:** To reload the game after a change, call `get_tree().quit()` and let the external watcher/launcher restart Godot. Never use `reload_current_scene()`.
**Why:** `reload_current_scene()` leaves stale GDScript static variables alive across the reload — state bleeds into the "fresh" run and produces unreproducible behavior.
