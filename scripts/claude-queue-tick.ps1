# One pass at the work queue, unattended.
#
# Runs Claude Code in print mode against TASKS.md: it takes the top unchecked item, does it, ticks
# it, commits. One item per run. Output is appended to logs/queue_tick.log so you can read what
# happened while you were away.
#
# TWO THINGS TO KNOW BEFORE SCHEDULING THIS:
#   1. It spends your usage quota with nobody watching.
#   2. Unattended means it cannot ask permission, so whatever tools it is allowed, it uses without
#      confirmation. Keep the allow-list to what the queue actually needs. It is scoped to this
#      repo, but it can still commit, delete files and run scripts inside it.
# If either of those is not what you want, don't schedule it -- run it by hand when you're around.
#
# Register (needs an ELEVATED PowerShell -- that is why Claude could not do it):
#   $a = New-ScheduledTaskAction -Execute "powershell.exe" `
#        -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Games\possession\scripts\claude-queue-tick.ps1"'
#   $t = New-ScheduledTaskTrigger -Daily -At 3am
#   $s = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries `
#        -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
#   Register-ScheduledTask -TaskName "possession-queue-tick" -Action $a -Trigger $t -Settings $s -RunLevel Limited
#
# -StartWhenAvailable matters: this laptop sleeps, and without it a missed 3am run is simply skipped.
#
# Remove:  Unregister-ScheduledTask -TaskName "possession-queue-tick" -Confirm:$false
# Test:    Start-ScheduledTask -TaskName "possession-queue-tick"   (or just run this file)

$ErrorActionPreference = "Continue"
$repo = "C:\Games\possession"
$log  = "$repo\logs\queue_tick.log"
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
Set-Location $repo

$prompt = @'
Take the top unchecked item from TASKS.md, do it, tick it, and commit. One item only.
Follow the rules at the top of that file. In particular: read the preview or screenshot image
before changing any biome number, never refetch or re-centre a patch unprompted, and do not write
new docs unless the item asks for one. Verify visually with `-- --shots <patch>` where the item is
visual. If the top item is blocked, note why in TASKS.md and take the next one. Keep output short.
'@

"=== tick $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8

# --permission-mode acceptEdits lets it edit and run without prompting; drop it and the run will
# stall on the first tool call with nobody there to answer. Check `claude --help` if flags have
# moved -- this is the part most likely to drift.
& claude -p $prompt --permission-mode acceptEdits 2>&1 |
    Tee-Object -FilePath $log -Append

"=== end $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8
