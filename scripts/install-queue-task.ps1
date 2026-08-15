# Register the unattended queue worker AND the satellite fetch as Scheduled Tasks.
#
# RUN THIS ONCE, IN AN ELEVATED POWERSHELL. Registering a task needs admin; that is why the earlier
# attempt fell back to the Startup folder, and why THAT never ran -- Startup only fires at logon and
# the laptop was never logged out. A scheduled task with a repeating trigger does not care.
#
#   Right-click PowerShell -> Run as Administrator, then:
#     & C:\Games\possession\scripts\install-queue-task.ps1
#
# What gets registered:
#   possession-queue-tick   every 30 min, forever. Each firing is short and decides for itself
#                           whether to work, skip, or stand down for a cooldown.
#   possession-s2-fetch     every 30 min. Exits in a second when there is nothing to fetch.
#
# Settings that matter, and why:
#   -StartWhenAvailable      run a missed firing after wake. Without it a suspend silently skips.
#   -WakeToRun               wake the machine for it. Without it nothing happens overnight at all.
#   -DontStopIfGoingOnBatteries / -AllowStartIfOnBatteries   otherwise unplugging kills the run.
#   -MultipleInstances IgnoreNew   belt and braces; the script also takes its own lock.
#
# Remove both:
#   Unregister-ScheduledTask -TaskName possession-queue-tick,possession-s2-fetch -Confirm:$false

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Needs an ELEVATED PowerShell. Right-click PowerShell -> Run as Administrator." -ForegroundColor Yellow
    exit 1
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Hours 3) `
    -MultipleInstances IgnoreNew

# repeat forever from a start a minute out, so the first firing is soon but not instant
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 10)
# 10 minutes, not 30. Measured over 54 runs: a productive tick works for a median of 7 minutes
# (range 3-12) and then the machine sat idle for the remaining 23. The lock makes overlap a non-event
# -- a firing that lands on a running tick just logs "skip: a run started N min ago" and exits -- so
# a shorter interval buys latency, not parallelism, and adds no new failure mode.

function Register($name, $file, $desc) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`""
    try { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction Stop } catch {}
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
        -Settings $settings -Description $desc -RunLevel Limited | Out-Null
    Write-Host "registered $name" -ForegroundColor Green
}

Register "possession-queue-tick" "C:\Games\possession\scripts\claude-queue-tick.ps1" `
    "Work one item from possession/TASKS.md. Skips itself if already running, cooling down, or the queue is empty."
Register "possession-s2-fetch" "C:\Games\possession\scripts\fetch-s2-resume.ps1" `
    "Resume the 8192 Sentinel-2 refetch. Exits immediately when nothing is outstanding."

Write-Host ""
Write-Host "Watch it:   Get-Content C:\Games\possession\logs\queue_tick.log -Tail 40 -Wait"
Write-Host "Run now:    Start-ScheduledTask -TaskName possession-queue-tick"
Write-Host "Stop it:    Unregister-ScheduledTask -TaskName possession-queue-tick,possession-s2-fetch -Confirm:`$false"
