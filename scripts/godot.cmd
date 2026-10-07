@echo off
REM Thin forwarder to the Godot binary. Exists ONLY so the unattended queue tick has a command it
REM can actually be granted permission to run.
REM
REM The tick is launched with --permission-mode acceptEdits, which overrides the repo's own
REM bypassPermissions, so it gets exactly the commands named in --allowedTools and nothing else.
REM Those entries match a command PREFIX. Godot was granted as:
REM
REM     Bash(C:\Godot\Godot_v4.5.1-stable_win64.exe:*)
REM
REM but nothing the agent actually types begins with that string. In PowerShell a path with spaces
REM must be launched with the call operator, so it writes `& "C:\Godot\..."`; in Bash it writes the
REM path with forward slashes, `C:/Godot/...`. Neither matches. The grant was real and the intent was
REM clear, and it had never once worked -- four consecutive items shipped with "NOT runtime-verified"
REM on them, including the damage, bake and assembler selftests, one of which was failing the whole
REM time because the project did not compile.
REM
REM Same shape as the git bug fixed in 228afb2: allowlists match how the command is WRITTEN, not what
REM it means. The durable fix is a command whose written form is fixed and short, so the prefix in
REM the allowlist and the text the agent types are the same thing by construction.
REM
REM Called as `scripts/godot.cmd <args>` from the repo root. %* forwards everything verbatim,
REM including the `--` separator that divides engine flags from the harness's own user args.
"C:\Godot\Godot_v4.5.1-stable_win64.exe" %*
