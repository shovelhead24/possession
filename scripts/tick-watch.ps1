# Live view of what the queue tick is doing.
#
#   powershell -ExecutionPolicy Bypass -File C:\Games\possession\scripts\tick-watch.ps1
#
# Answers the three questions a person standing at the machine actually has -- is it alive, what is
# it working on, and how long has it been at it -- plus the last few actions so you can see it
# moving. Deliberately NOT the reasoning trace: that is in logs/queue_tick.log if you want it, and
# it is a wall of text that hides exactly the three facts above.
#
# Read-only. Ctrl+C to leave; it never touches the tick.

$repo   = "C:\Games\possession"
$logs   = "$repo\logs"
$status = "$logs\tick-status.txt"
$log    = "$logs\queue_tick.log"
$lock   = "$logs\.queue_tick.lock"
$pause  = "$logs\.queue_paused"

function Field($text, $name) {
    foreach ($l in $text) { if ($l -like "$name=*") { return $l.Substring($name.Length + 1) } }
    return ""
}

while ($true) {
    $running = Test-Path $lock
    $paused  = Test-Path $pause

    $state = "waiting"; $detail = ""; $item = ""; $started = ""; $updated = ""; $branch = ""
    if (Test-Path $status) {
        $s = Get-Content $status
        $state   = Field $s "STATE"
        $detail  = Field $s "DETAIL"
        $item    = Field $s "ITEM"
        $branch  = Field $s "BRANCH"
        $started = Field $s "STARTED"
        $updated = Field $s "UPDATED"
    }

    # elapsed comes from the lock file, which exists only while a run is in flight
    $elapsed = ""
    if ($running) {
        $age = (Get-Date) - (Get-Item $lock).LastWriteTime
        $elapsed = "{0:mm\:ss}" -f $age
    }

    # a run that has not updated its status in a while is a run that is stuck, and that is worth
    # seeing at a glance rather than inferring from a frozen clock
    $stale = ""
    if ($running -and $updated) {
        try {
            $since = (Get-Date) - [datetime]::Parse($updated)
            if ($since.TotalSeconds -gt 180) { $stale = "  (no update for {0:n0}s)" -f $since.TotalSeconds }
        } catch { }
    }

    $next = ""
    try {
        $next = (Get-ScheduledTaskInfo -TaskName 'possession-queue-tick' -EA Stop).NextRunTime
    } catch { $next = "(task not found)" }

    Clear-Host
    Write-Host ""
    if ($paused) {
        Write-Host "  QUEUE PAUSED" -ForegroundColor Yellow
        Write-Host "  $((Get-Content $pause -Raw).Trim())" -ForegroundColor DarkYellow
    } elseif ($running) {
        Write-Host "  RUNNING  $elapsed$stale" -ForegroundColor Green
    } else {
        Write-Host "  IDLE     next fire $next" -ForegroundColor DarkGray
    }
    Write-Host ""
    if ($item)   { Write-Host "  item    " -NoNewline -ForegroundColor DarkGray; Write-Host $item }
    if ($detail) { Write-Host "  doing   " -NoNewline -ForegroundColor DarkGray; Write-Host $detail }
    if ($branch) { Write-Host "  branch  " -NoNewline -ForegroundColor DarkGray; Write-Host $branch }

    $openCount = 0
    if (Test-Path "$repo\TASKS.md") {
        $openCount = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]').Count
    }
    Write-Host "  queue   " -NoNewline -ForegroundColor DarkGray; Write-Host "$openCount open"

    Write-Host ""
    Write-Host "  recent" -ForegroundColor DarkGray
    if (Test-Path $log) {
        Get-Content $log -Tail 12 | ForEach-Object {
            $line = $_
            if ($line -match 'PROBLEM|FAILED|PAUSED') { Write-Host "    $line" -ForegroundColor Red }
            elseif ($line -match 'tick done|pushed')   { Write-Host "    $line" -ForegroundColor Green }
            elseif ($line -match '^\s+\.')             { Write-Host "    $line" -ForegroundColor DarkCyan }
            else                                        { Write-Host "    $line" -ForegroundColor Gray }
        }
    }
    Write-Host ""
    Write-Host "  (Ctrl+C to exit; full trace in logs\queue_tick.log)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}
