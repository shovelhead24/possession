# Possession — Claude Instructions

## Workflow

**Always commit after making code changes.** The dev pipeline is: Codespaces edit → git push → PowerShell watcher on the laptop auto-pulls and relaunches Godot. Changes are not testable until they are committed and pushed.

Commit message style: short imperative summary, no body needed.

## Getting Godot Logs

The PowerShell watcher on the laptop has a key binding: pressing **L** in the watcher/run script window pushes the current Godot log to git. After asking the user to test something, they can press L to share the log — check `git log` and `git show` on the latest commit to read it.
