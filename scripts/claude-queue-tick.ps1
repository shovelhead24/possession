# One pass at the work queue, unattended, safe to fire repeatedly.
#
# Runs Claude Code in print mode against TASKS.md: it takes the top unchecked item, does it, ticks
# it, commits. One item per run.
#
# DESIGNED TO BE CALLED EVERY 30 MINUTES BY A SCHEDULED TASK. It is not a loop and it never sleeps
# for hours -- long sleeps die when the laptop suspends, which is exactly how the last attempt
# failed. Instead each run is short and decides for itself whether to work or stand down:
#
#   * already running?      -> exit (stale lock older than 3h is ignored)
#   * cooling down?         -> exit until the recorded reset time passes
#   * queue empty?          -> exit quietly
#   * hit a usage limit?    -> record when to resume, exit
#
# So a suspend just means some firings are missed; the next one after wake picks up. Nothing has to
# survive sleep except two small files.
#
# TWO THINGS TO DECIDE BEFORE SCHEDULING THIS:
#   1. It spends your usage quota with nobody watching.
#   2. Unattended means it cannot ask permission, so whatever tools it is allowed it uses without
#      confirmation. It is scoped to this repo, but inside the repo it can edit, delete, run
#      scripts and commit.
#
# Register with scripts/install-queue-task.ps1 (needs one elevated PowerShell).
# Watch it with:  Get-Content C:\Games\possession\logs\queue_tick.log -Tail 40 -Wait

$ErrorActionPreference = "Continue"
$repo  = "C:\Games\possession"
$logs  = "$repo\logs"
$log   = "$logs\queue_tick.log"
$lock  = "$logs\.queue_tick.lock"
$cool  = "$logs\.queue_cooldown"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
Set-Location $repo

# -Encoding utf8 on every write: Tee-Object and Out-File default to UTF-16 here, which made the
# log unreadable in anything that assumes text.
function Say($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

# --- already running? -----------------------------------------------------------------------
if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalHours -lt 3) { Say "skip: a run started $([int]$age.TotalMinutes) min ago"; exit 0 }
    Say "stale lock ($([int]$age.TotalHours)h) -- ignoring it"
}

# --- cooling down after a usage limit? ------------------------------------------------------
if (Test-Path $cool) {
    $until = Get-Content $cool -Raw
    try { $u = [datetime]::Parse($until.Trim()) } catch { $u = Get-Date }
    if ((Get-Date) -lt $u) {
        Say "skip: cooling down until $($u.ToString('HH:mm'))"
        exit 0
    }
    Remove-Item $cool -Force -ErrorAction SilentlyContinue
    Say "cooldown over, resuming"
}

# --- anything left to do? -------------------------------------------------------------------
$open = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]' -ErrorAction SilentlyContinue).Count
if (-not $open) { Say "queue empty -- nothing to do"; exit 0 }

New-Item -ItemType File -Path $lock -Force | Out-Null
Say "=== tick starting (${open} items open) ==="

$prompt = @'
Take the top unchecked item from TASKS.md, do it, tick it, and commit. One item only.
Follow the rules at the top of that file. In particular: read the preview or screenshot image
before changing any biome number, never refetch or re-centre a patch unprompted, and do not write
new docs unless the item asks for one. Verify visually with `-- --shots <patch>` where the item is
visual, and check whether a feature already exists before building it. If the top item is blocked,
note why in TASKS.md and take the next one. Keep output short.
'@

$out = & claude -p $prompt --permission-mode acceptEdits 2>&1 | Out-String
Add-Content -Path $log -Value $out -Encoding utf8

Remove-Item $lock -Force -ErrorAction SilentlyContinue

# --- did we run out of quota? ---------------------------------------------------------------
# Matched loosely on purpose: the exact wording changes, and a false positive only costs one
# skipped cycle whereas a false negative means hammering a limit we have already hit.
if ($out -match '(?i)(usage limit|rate limit|quota|too many requests|limit reached|resets? (at|in))') {
    $resume = (Get-Date).AddHours(5)                       # session limits reset on ~5h windows
    # NOTE: PowerShell needs elseif on the SAME line as the closing brace. On its own line it
    # parses as a separate statement and silently swallows the rest of the file.
    if ($out -match '(?i)resets? in\s+(\d+)\s*hr') {
        $resume = (Get-Date).AddHours([int]$Matches[1] + 1)
    } elseif ($out -match '(?i)resets? in\s+(\d+)\s*min') {
        $resume = (Get-Date).AddMinutes([int]$Matches[1] + 5)
    }
    $resume.ToString('o') | Set-Content $cool -Encoding ascii
    Say "hit a usage limit -- standing down until $($resume.ToString('HH:mm'))"
    exit 0
}

$left = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]' -ErrorAction SilentlyContinue).Count
Say "=== tick done (${left} items left) ==="
