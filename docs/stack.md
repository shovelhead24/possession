# Possession — Stack & Pipeline

High-level, mostly-static facts about the project's tech and workflow. Tuned technical decisions (chunk sizes, LOD tables, shader thresholds) belong in `.decisions/`, not here.

## Stack

| Layer | Choice |
|---|---|
| Engine | Godot 4.5 |
| Renderer | GL Compatibility (OpenGL 3.3 — Intel UHD safe) |
| Language | GDScript |
| Version control | GitHub — `shovelhead24/possession`, branch `main` |
| Primary hardware target | Intel UHD / integrated GPU ("potato hardware") |

## Dev Pipeline

Claude Code now runs natively on the Windows laptop with direct file access — no Codespaces push/pull/watcher loop needed for edits. Godot project root is `game/` inside the repo.

The PowerShell watcher script still exists for manual test runs and log capture — see `game/CLAUDE.md` for the diagnose/run/watch commands, and the root `CLAUDE.md` "Getting Godot Logs" section for the **L**-key log push.

## Doc & Process Layout

- `docs/` — this folder. High-level, mostly-static vision/stack/world docs.
- `.decisions/` — per-system technical decision log (flat files, one per system, `INDEX.md` maps them). See "Decision Log" in root `CLAUDE.md`.
- GitHub Issues + Projects — day-to-day task tracking (replaces the abandoned GSD `.planning/` framework).
- GitHub PRs — code review flow.

---
*Last reviewed: 2026-07-18.*
