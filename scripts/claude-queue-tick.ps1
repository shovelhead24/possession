# One pass at the work queue, unattended, safe to fire repeatedly.
#
# Runs Claude Code in print mode against TASKS.md: it takes the top unchecked item, does it, ticks
# it, commits. One item per run.
#
# DESIGNED TO BE CALLED EVERY 30 MINUTES BY A SCHEDULED TASK. It is not a loop and it never sleeps
# for hours -- long sleeps die when the laptop suspends, which is exactly how the last attempt
# failed. Instead each run is short and decides for itself whether to work or stand down:
#
#   * paused by hand?       -> exit (logs/.queue_paused is the kill switch; no elevation needed)
#   * already running?      -> exit (stale lock older than 3h is ignored)
#   * working tree dirty?   -> exit; someone is mid-edit, or the last tick did not commit
#   * cooling down?         -> exit until the recorded reset time passes
#   * queue empty?          -> exit quietly
#   * hit a usage limit?    -> record when to resume, exit
#   * left work uncommitted -> pause the queue and say so, rather than let the next tick pile on
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
$pause = "$logs\.queue_paused"
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

# --- paused by hand? ------------------------------------------------------------------------
# A kill switch that needs no elevation. Disabling the scheduled task requires an admin shell (and
# is blocked outright for an agent), so there was no way to stop this thing short of unregistering
# it. Create the file to stop the queue; delete it to resume.
#   pause:   New-Item -ItemType File C:\Games\possession\logs\.queue_paused
#   resume:  Remove-Item C:\Games\possession\logs\.queue_paused
if (Test-Path $pause) {
    $why = (Get-Content $pause -Raw -EA SilentlyContinue)
    Say "skip: queue PAUSED. $($why.Trim())"
    exit 0
}

# --- is someone else already working in here? -----------------------------------------------
# THE IMPORTANT ONE. The lock above only serialises tick against tick; an interactive Claude
# session takes no lock and is invisible to it, so both used to edit game/mocks/ring_vibes.gd at
# the same time. On 2026-08-10 a tick silently replaced an in-progress VEHICLE_DEFS dictionary with
# its own class -- the interactive session's version was simply gone -- and later declared a
# variable the session was declaring, which would have been a duplicate-declaration parse error.
#
# A dirty tree means EITHER a person/session is mid-edit OR a previous tick did work and failed to
# commit it. Both are reasons not to start: the second is how three ticks in a row were lost, each
# piling more uncommitted work on top of a parse error nobody had noticed.
$dirty = @(git status --porcelain -- . ':(exclude)logs') | Where-Object { $_ -ne "" }
if ($dirty.Count -gt 0) {
    Say "skip: working tree is dirty ($($dirty.Count) files) -- someone is mid-edit, or a previous tick did not commit"
    foreach ($d in $dirty | Select-Object -First 8) { Say "        $d" }
    exit 0
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

# --allowedTools for git: acceptEdits auto-approves FILE EDITS but not Bash, and passing
# --permission-mode here overrides the repo's own bypassPermissions in .claude/settings.local.json.
# So every tick could edit freely and then could not commit -- "git add/commit return 'This command
# requires approval' in every form I tried" is in this very log, from a tick that did the work and
# had to abandon it in the working tree. Least privilege: grant git, not the world.
$out = & claude -p $prompt --permission-mode acceptEdits `
    --allowedTools 'Bash(git add:*)' 'Bash(git commit:*)' 'Bash(git status:*)' 'Bash(git diff:*)' 2>&1 | Out-String
Add-Content -Path $log -Value $out -Encoding utf8

Remove-Item $lock -Force -ErrorAction SilentlyContinue

# --- did we run out of quota? ---------------------------------------------------------------
# Matched loosely on purpose: the exact wording changes, and a false positive only costs one
# skipped cycle whereas a false negative means hammering a limit we have already hit.
# "session limit" was NOT in this list, and the live wording is
#     You've hit your session limit . resets 8:40pm (Europe/Dublin)
# which also fails 'resets? (at|in)' because there is no preposition. So on 2026-08-10 the tick hit
# the wall every 30 minutes from ~17:00 to 21:00, matched nothing, recorded no cooldown, and logged
# "tick done" nine times in a row while doing absolutely nothing. Match the clock time it actually
# prints, and only fall back to the 5h guess when there is no time to read.
if ($out -match '(?i)(session limit|usage limit|rate limit|quota|too many requests|limit reached|resets?[ :])') {
    $resume = (Get-Date).AddHours(5)                       # last resort: session windows are ~5h
    # NOTE: PowerShell needs elseif on the SAME line as the closing brace. On its own line it
    # parses as a separate statement and silently swallows the rest of the file.
    if ($out -match '(?i)resets?\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)') {
        $hh = [int]$Matches[1]
        $mm = 0
        if ($Matches[2]) { $mm = [int]$Matches[2] }
        if ($Matches[3] -match '(?i)pm' -and $hh -lt 12) { $hh += 12 }
        if ($Matches[3] -match '(?i)am' -and $hh -eq 12) { $hh = 0 }
        $resume = (Get-Date).Date.AddHours($hh).AddMinutes($mm + 2)
        # A reset time already in the past means the window has ALREADY rolled over -- we are
        # reading the message moments after it was printed. Do not add a day: that would stand the
        # queue down for 24 hours over a limit that has just expired. Wait a token 15 minutes, which
        # also covers the midnight-wrap case ("resets 12:10am" seen at 23:50) at the cost of one
        # extra cycle rather than a lost day.
        if ($resume -lt (Get-Date)) { $resume = (Get-Date).AddMinutes(15) }
    } elseif ($out -match '(?i)resets? in\s+(\d+)\s*hr') {
        $resume = (Get-Date).AddHours([int]$Matches[1] + 1)
    } elseif ($out -match '(?i)resets? in\s+(\d+)\s*min') {
        $resume = (Get-Date).AddMinutes([int]$Matches[1] + 5)
    }
    $resume.ToString('o') | Set-Content $cool -Encoding ascii
    Say "hit a usage limit -- standing down until $($resume.ToString('HH:mm'))"
    exit 0
}

# --- did it actually commit? ----------------------------------------------------------------
# A tick that does work and does not commit is worse than a tick that does nothing: the next firing
# starts on top of it, and the one after that. That is exactly how three runs were lost on
# 2026-08-10 -- a class_name that only resolves in the editor left the project unparseable, the
# agent could not verify anything, no commit happened, and each following tick piled on more.
# Nothing detected it. Now it does, and it stops the queue rather than compounding.
$after = @(git status --porcelain -- . ':(exclude)logs') | Where-Object { $_ -ne "" }
if ($after.Count -gt 0) {
    Say "PROBLEM: the run left $($after.Count) files uncommitted. Pausing the queue so the next tick does not pile on."
    foreach ($d in $after | Select-Object -First 8) { Say "        $d" }
    "Auto-paused $(Get-Date -Format 'yyyy-MM-dd HH:mm'): a tick left work uncommitted. Review, commit or discard, then delete this file." |
        Set-Content $pause -Encoding ascii
    exit 0
}

# --- did it actually DO anything? -----------------------------------------------------------
# "tick done" used to be printed unconditionally, so a run that achieved nothing was indistinguishable
# in the log from one that shipped a feature. Nine consecutive no-ops on 2026-08-10 all read as
# success. If the open count did not move, say so plainly -- it is the difference between "the queue
# is progressing" and "the queue has been spinning for four hours".
$left = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]' -ErrorAction SilentlyContinue).Count
if ($left -ge $open) {
    Say "=== tick did NOT complete an item (${open} -> ${left} open) -- see the output above ==="
    exit 0
}
Say "=== tick done (${left} items left) ==="
