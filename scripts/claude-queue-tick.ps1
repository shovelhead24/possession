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
#   * hit a usage limit?    -> commit whatever it wrote, record when to resume, exit
#   * left work uncommitted -> COMMIT IT (a run only starts clean, so the work is its own), leave
#                              the item unticked, and let the next run continue it
#   * HEAD does not compile -> pause; the work is safely committed but a human has to look
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
# Claude emits UTF-8; PowerShell 5.1 otherwise decodes it as the ANSI codepage, which is how a
# middot became "Â·" and every em-dash turned to mush in the log.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$repo  = "C:\Games\possession"
$logs  = "$repo\logs"
$log   = "$logs\queue_tick.log"
$lock  = "$logs\.queue_tick.lock"
$cool  = "$logs\.queue_cooldown"
$pause = "$logs\.queue_paused"
# Join-Path, not "$logs	ick-status.txt" -- writing that through a tool that treats backslash-t
# as an escape produced a literal TAB in the path, and every status write failed with
# "Illegal characters in path" for hours. No backslash in a literal means nothing to collapse.
$status = Join-Path $logs 'tick-status.txt'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$script:tickStart = Get-Date
$topitem = $null
$branch = ""
Set-Location $repo

# -Encoding utf8 on every write: Tee-Object and Out-File default to UTF-16 here, which made the
# log unreadable in anything that assumes text.
# The status file is what `scripts/tick-watch.ps1` renders. Deliberately a few short fields rather
# than the reasoning trace: the question a human standing at the machine has is "is it alive, what
# is it on, and how long has it been", and a wall of thinking answers none of those.
function SetStatus($state, $detail) {
    $item = if ($topitem) { $topitem.Trim() } else { "" }
    @(
        "STATE=$state"
        "DETAIL=$detail"
        "ITEM=$item"
        "BRANCH=$branch"
        "STARTED=$($script:tickStart.ToString('yyyy-MM-dd HH:mm:ss'))"
        "UPDATED=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ) | Set-Content $status -Encoding ascii
}

# Make a line readable in ANY terminal codepage. Three separate problems, all of them mine:
#   1. Claude emits UTF-8 and PowerShell 5.1 decoded it as the OEM codepage, so an em-dash arrived
#      as three junk characters and a degree sign as two. Prevented at source now by setting
#      [Console]::OutputEncoding, and repaired here for whatever was written before that.
#   2. Real Unicode punctuation renders inconsistently; "--" always works.
#   3. JSON escapes arrived as the two literal characters backslash-n and were printed, not rendered.
#      Written as single-quoted PowerShell strings, which take no escapes at all -- earlier attempts
#      using double quotes kept collapsing into real newlines before they reached the file.
function Clean($t) {
    if ($null -eq $t) { return "" }
    # already-mangled sequences FIRST, before the ASCII strip deletes them and leaves a hole
    $t = $t.Replace([string]([char]0x0393 + [char]0x00C7 + [char]0x00F6), '--')
    $t = $t.Replace([string]([char]0x0393 + [char]0x00C7 + [char]0x00D6), "'")
    $t = $t.Replace([string]([char]0x00C2 + [char]0x00B7), '.')
    $t = $t.Replace([string]([char]0x00C2 + [char]0x00B0), ' deg')
    # then genuine Unicode punctuation
    $t = $t.Replace([string][char]0x2014, '--').Replace([string][char]0x2013, '-')
    $t = $t.Replace([string][char]0x2018, "'").Replace([string][char]0x2019, "'")
    $t = $t.Replace([string][char]0x201C, '"').Replace([string][char]0x201D, '"')
    $t = $t.Replace([string][char]0x00B7, '.').Replace([string][char]0x2026, '...')
    $t = $t.Replace([string][char]0x00B0, ' deg').Replace([string][char]0x00A0, ' ')
    # literal backslash-n / backslash-t as they appear inside JSON text
    $t = $t.Replace('\n', ' ').Replace('\t', ' ').Replace('\r', '')
    # anything still unprintable goes; collapse the gaps it leaves
    $t = [regex]::Replace($t, '[^\u0020-\u007E]', '')
    return [regex]::Replace($t, ' {3,}', '  ')
}

function Say($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $(Clean $m)"
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

function Dirt { @(git status --porcelain -- . ':(exclude)logs') | Where-Object { $_ -ne "" } }

# RESCUE THE RUN'S OWN WORK RATHER THAN LATCHING OVER IT.
# This used to only ever pause, on the reasoning that a dirty tree is ambiguous -- a person mid-edit
# or a dead tick -- and committing blind is how the whole HUD implementation ended up inside a commit
# titled as a logging change. That reasoning is sound in general and does not apply HERE, because of
# a precondition established above: this script refuses to start unless the tree is clean. So
# anything dirty at THIS point was written by the run that just finished, and nothing else. It is the
# one place in the system where the authorship of a change is not a guess.
#
# The cost of getting this wrong the old way was measured on 2026-08-16: a rate limit landed at 23:27
# with two files unsaved, and because the pause only releases on a clean tree -- which nothing
# unattended could produce -- the queue skipped every ten minutes for TWELVE HOURS. The work was two
# small additive functions that would have committed cleanly.
#
# It commits, it does NOT tick the item off. Partial work stays on the queue and the next run
# continues it with the code in hand instead of rebuilding it from a cold start.
function CommitStranded($reason) {
    $s = @(Dirt)   # @() so an empty result is an empty array, not $null with no .Count
    if ($s.Count -eq 0) { return $true }
    Say "  rescuing $($s.Count) uncommitted files -- they can only be this run's own work"
    foreach ($d in $s | Select-Object -First 8) { Say "        $d" }
    # A patch alongside the commit, because a commit can still be reverted by mistake and this is
    # cheap. Keeps the pre-existing forensic habit rather than replacing it.
    $patch = Join-Path $logs ("uncommitted-" + (Get-Date -Format 'yyyyMMdd_HHmm') + ".patch")
    git diff -- . ':(exclude)logs' | Set-Content $patch -Encoding utf8
    $item = if ($topitem) { $topitem.Trim() } else { "(item unknown)" }
    git add -A -- . ':(exclude)logs'
    $msg = "wip(queue): partial work rescued by the tick -- $reason`n`n" `
         + "Committed by claude-queue-tick.ps1, not by the agent that wrote it: the run ended with a`n" `
         + "dirty tree, and a run only starts from a clean one, so this is its own unfinished work.`n`n" `
         + "The item is deliberately NOT ticked off -- it stays at the top of the queue and the next`n" `
         + "run continues it.`n`n" `
         + "Item: $item`n"
    git commit -q -m $msg
    if ($LASTEXITCODE -ne 0) {
        Say "  RESCUE FAILED: git commit returned $LASTEXITCODE -- pausing so nothing piles on"
        "AUTO-PAUSE. Set at $(Get-Date -Format 'HH:mm'): a run left work uncommitted AND the rescue commit failed.`nIt was working on: $topitem" |
            Set-Content $pause -Encoding ascii
        return $false
    }
    Say "  rescued as $(git rev-parse --short HEAD) (patch also at $patch)"
    return $true
}

# DOES THE PROJECT STILL PARSE? The gap that let a broken HEAD ship on 2026-08-15.
# Two type-registration failures neither of which reports itself: `Recipe` was renamed but
# .godot/global_script_class_cache.cfg still held the old name, and `Creature` had its class_name
# below a const so it never registered at all. Headless resolves global class names from that cache,
# so assembler.gd would not parse and everything downstream failed to compile -- while the queue
# logged three consecutive items as done, each noting only that it could not run-verify.
# `--editor --quit` rescans, which BOTH rewrites the stale cache (fixing that failure outright) and
# surfaces parse errors. Cheap insurance against committing a project that cannot load.
function ParseGate {
    $godot = "C:\Godot\Godot_v4.5.1-stable_win64.exe"
    if (-not (Test-Path $godot)) { Say "parse gate skipped: no Godot at $godot"; return $true }
    SetStatus "running" "parse gate (rescan)"
    $o = & $godot --headless --path "$repo\game" --editor --quit 2>&1 | Out-String
    $errs = @($o -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
    if ($errs.Count -gt 0) {
        Say "PARSE GATE FAILED -- the project does not compile. $($errs.Count) errors:"
        foreach ($e in $errs | Select-Object -First 12) { Say "        $(Clean $e)" }
        return $false
    }
    # The rescan writes .uid files and may rewrite the class cache. Untracked files count as a dirty
    # tree, so left alone they would stand the queue down forever on the next firing.
    if (@(Dirt).Count -gt 0) {
        git add -A -- . ':(exclude)logs'
        git commit -q -m "chore(godot): rescan artifacts (class cache / .uid) from the tick's parse gate"
        Say "  committed rescan artifacts"
    }
    Say "parse gate passed"
    return $true
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
        # DO NOT TRUST THE CLOCK -- TEST IT. The reset time is either parsed from a message or, worse,
        # guessed at five hours, and the real window is dynamic on Anthropic's side. On 2026-08-15 a
        # false positive parked the queue until 22:38 while the dashboard showed 25% used with four
        # hours left. A probe costs a few Haiku tokens and turns a lost evening into a lost cycle.
        # Haiku: the cooldown is account-wide, not per model, so the cheapest call answers the same
        # question as an expensive one. (I had switched this to the working model on the theory that
        # limits might be per-model; they are not.) Nearly free either way -- rejected costs nothing
        # because the request never runs, accepted is a one-word answer.
        $probe = & claude -p 'reply with the single word: ok' --model haiku 2>&1 | Out-String
        if ($probe -match '"api_error_status"\s*:\s*429' -or
            $probe -match '(?i)(session limit|usage limit|rate limit|limit reached)') {
            Say "skip: cooling down until $($u.ToString('HH:mm')) (probe confirms still limited)"
            exit 0
        }
        Remove-Item $cool -Force -ErrorAction SilentlyContinue
        Say "cooldown cleared early: probe says the limit is gone (was waiting until $($u.ToString('HH:mm')))"
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
    # AN AUTO-PAUSE MUST NOT OUTLIVE ITS CAUSE. The auto-pause below latches the queue when a run
    # leaves work uncommitted, so the next tick cannot pile onto it. That is right, but as first
    # written it was a latch with nobody watching: it fired on 2026-08-13 and the queue sat dead for
    # TWO DAYS while work carried on around it, which is the silent-failure pattern this project
    # keeps producing. If the tree is clean again the reason is gone, so clear it and carry on.
    # A pause set BY HAND has no such condition and stays until a human removes it.
    $dirtynow = @(git status --porcelain -- . ':(exclude)logs') | Where-Object { $_ -ne "" }
    if ($why -match 'AUTO' -and $dirtynow.Count -eq 0) {
        Remove-Item $pause -Force -ErrorAction SilentlyContinue
        Say "auto-pause cleared: the tree is clean again, so whatever caused it is resolved"
    } else {
        Say "skip: queue PAUSED. $($why.Trim())"
        exit 0
    }
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

# --- whatever branch is checked out ------------------------------------------------------------
# The tick works on the CURRENT branch and never switches. A previous version of this script forced
# a checkout of a dedicated branch, which was wrong in a way that only shows up in use: `git
# checkout` rewrites the working tree, so a tick firing while Godot is running or the editor is open
# would swap the files underneath them and leave the machine on a different branch than it was left
# on. One branch, shared with whoever is at the keyboard -- semi-attended, which is what this is.
$branch = (git rev-parse --abbrev-ref HEAD)

SetStatus "running" "starting"
Say "=== tick starting (${open} items open) ==="

# --- PRE-FLIGHT: does this already exist? ------------------------------------------------------
# Every tick is a COLD session. It cannot know what previous ticks built, so it rebuilds things.
# Twice on 2026-08-15 alone: the docking mechanic was fully implemented by an earlier run and simply
# never ticked off, and a second identical `rim` shot framing was appended next to the first. The
# check is pure reading, so it runs on a cheap model -- the expensive judgement is in the work, not
# in grepping for prior art.
$topitem = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]' | Select-Object -First 1).Line
$priorart = ""
if ($topitem) {
    Say "next item: $($topitem.Substring(0, [Math]::Min(100, $topitem.Length)))"
    $scoutprompt = @"
Read-only survey, no edits. The next task is:
$topitem

Does anything in this repository ALREADY implement this, in whole or in part? Search the code, and
check TASKS-done.md for a completed item covering it. Answer in at most 10 lines: either
'NOTHING FOUND' or a list of file:line references with one clause each on what is already there.
Do not suggest an approach and do not write anything.
"@
    SetStatus "running" "prior-art survey (sonnet)"
    $priorart = & claude -p $scoutprompt --model sonnet --permission-mode acceptEdits 2>&1 | Out-String
    Say "--- prior art (sonnet) ---"
    foreach ($ln in ($priorart -split "`n")) { if ($ln.Trim()) { Say "  $ln" } }
}

$prompt = @'
Take the top unchecked item from TASKS.md, do it, tick it, and commit. One item only.
Follow the rules at the top of that file. In particular: read the preview or screenshot image
before changing any biome number, never refetch or re-centre a patch unprompted, and do not write
new docs unless the item asks for one. Verify visually with `-- --shots <patch>` where the item is
visual, and check whether a feature already exists before building it. If the top item is blocked,
note why in TASKS.md and take the next one. Keep output short.

You ARE allowed to run Godot, but ONLY through the wrapper, and the exact spelling matters. Run it
as `scripts/godot.cmd` from the repo root, with no quotes, no `&` call operator and no absolute
path -- those forms are refused, which is why four items in a row shipped unverified. Example:
  scripts/godot.cmd --headless --path game res://mocks/ring_vibes.tscn -- --selftest
The harnesses are `-- --selftest`, `-- --proving`, `-- --range` and `-- --shots <patch>`. Note that
`--shots` captures from a live viewport, so it needs a real window -- omit `--headless` for it.
There are also script selftests: `scripts/godot.cmd --headless --path game -s res://tests/<name>.gd`
(assembler_test, bake_test, damage_test all currently pass).
A change that has not been run is not finished; say so plainly in TASKS.md if you could not run it.
If the wrapper is refused, say so explicitly in your summary and name the exact command you tried --
do not silently fall back to shipping unverified work.
'@

# BROADENED THREE TIMES, each because the narrow version was silently refusing the tick. The third:
# the allowlist named Bash only, and the agent reaches for the POWERSHELL tool on this machine -- so
# `PowerShell git -C ... add` was refused at 22:51 exactly as `git -C ... add` had been at 18:38.
# Allowlists are per TOOL, not per command: grant the command on every tool that can run it.
#
# 1. 'Bash(git add:*)' matches commands STARTING WITH 'git add'. The agent writes
#    'git -C C:\Games\possession add ...', which starts with 'git -C' and was therefore denied --
#    so on 2026-08-15 it implemented FPS controls, tried to commit, was refused, and the work sat
#    uncommitted. I had blamed that entirely on a false rate-limit; the refusal came first.
#    'Bash(git:*)' covers every form. It also permits destructive git, which is an accepted risk
#    here: the tick works on its own branch and everything is pushed, so the blast radius is a
#    force-push to semi-attended rather than lost history.
#
# 2. It could not run GODOT ('ls /c/Godot/ ; which godot' -- denied), which is why every completed
#    item carries a "NOT run-verified" note. A tick that can write code but never execute it cannot
#    do the one thing this project actually values, which is checking whether the thing works.
#
# --allowedTools for git: acceptEdits auto-approves FILE EDITS but not Bash, and passing
# --permission-mode here overrides the repo's own bypassPermissions in .claude/settings.local.json.
# So every tick could edit freely and then could not commit -- "git add/commit return 'This command
# requires approval' in every form I tried" is in this very log, from a tick that did the work and
# had to abandon it in the working tree. Least privilege: grant git, not the world.
if ($priorart.Trim()) {
    $prompt = $prompt + "`n`nA read-only survey of the repo reported the following prior art for this item. Verify before" `
        + " trusting it, but do NOT rebuild something that already exists -- finish, fix or tick it instead:`n" + $priorart
}
Say "models: sonnet (prior-art survey) + opus (work)"
# STREAMED, so progress is visible while it works rather than one blob at the end. Each tool call
# becomes a one-line status update -- the tool and what it touched, never the reasoning. The full
# JSON still goes to the log, and the plain text is accumulated separately because the usage-limit
# detection below scans prose, not JSON.
SetStatus "running" "opus working"
$sb = New-Object System.Text.StringBuilder
$acts = 0
& claude -p $prompt --permission-mode acceptEdits --output-format stream-json --verbose `
    --allowedTools 'Bash(git:*)' 'PowerShell(git:*)' `
    'Bash(scripts/godot.cmd:*)' 'Bash(./scripts/godot.cmd:*)' `
    'PowerShell(scripts\godot.cmd:*)' 'PowerShell(.\scripts\godot.cmd:*)' `
    'Bash(C:/Godot/Godot_v4.5.1-stable_win64.exe:*)' `
    'Bash(C:\Godot\Godot_v4.5.1-stable_win64.exe:*)' 'PowerShell(C:\Godot\Godot_v4.5.1-stable_win64.exe:*)' 2>&1 |
    ForEach-Object {
        $line = $_
        [void]$sb.AppendLine($line)
        # compact descriptor by regex rather than ConvertFrom-Json: one malformed line should not
        # take down the run, and PS 5.1 parsing a JSON object per line is needless work
        if ($line -match '"type"\s*:\s*"tool_use"') {
            $tool = ""
            if ($line -match '"name"\s*:\s*"([A-Za-z_]+)"') { $tool = $Matches[1] }
            $tgt = ""
            if ($line -match '"file_path"\s*:\s*"([^"]{1,120})"') { $tgt = Split-Path $Matches[1] -Leaf }
            elseif ($line -match '"command"\s*:\s*"([^"]{1,70})"') { $tgt = $Matches[1] }
            elseif ($line -match '"pattern"\s*:\s*"([^"]{1,50})"') { $tgt = $Matches[1] }
            $acts++
            SetStatus "running" ("$tool $tgt").Trim()
            Say "  . $tool $tgt"
        }
    }
$out = $sb.ToString()
# the raw transcript is for debugging, not for reading -- it does not belong in the human log
$raw = Join-Path $logs ("tick-raw-" + (Get-Date -Format 'yyyyMMdd') + ".jsonl")
Add-Content -Path $raw -Value $out -Encoding utf8
# what the agent finally SAID, which is the part worth having in the log
if ($out -match '"result"\s*:\s*"(.{0,4000}?)","') {
    $summary = $Matches[1] -replace '\n', "`n" -replace '\\"', '"' -replace '\\', ''
    Say "--- what it did ---"
    foreach ($ln in ($summary -split "`n")) { if ($ln.Trim()) { Say "  $ln" } }
    Say "--- end ---"
}

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
# DETECT THE ERROR, NOT THE PROSE. This used to substring-match the whole of $out for phrases
# including 'resets '. Since the run became streamed, $out is the entire JSON transcript -- every
# word the agent writes, not just its final answer -- so on 2026-08-15 the physics bake-off item
# tripped it by writing about RESETTING bodies between scenarios, and the queue stood down for five
# hours at 25% session usage. Match the structured failure instead: stream-json reports
# "is_error":true with "api_error_status":429, which cannot be produced by the agent talking.
$limited = ($out -match '"api_error_status"\s*:\s*429')
# and pull the human message out of the RESULT field only, never the transcript
$resultText = ""
# Non-greedy up to the field terminator. The previous pattern used an escaped-quote character
# class that did not survive being written to file and threw "Unterminated [] set" at runtime.
if ($out -match '"result"\s*:\s*"(.{0,400}?)","') { $resultText = $Matches[1] }
if (-not $limited -and $resultText -match '(?i)(session limit|usage limit|rate limit|limit reached)') {
    $limited = $true
}
if ($limited) {
    $out = $resultText   # so the reset-time parse below reads the message, not the whole run
    $resume = (Get-Date).AddHours(5)                       # last resort: session windows are ~5h
    # NOTE: PowerShell needs elseif on the SAME line as the closing brace. On its own line it
    # parses as a separate statement and silently swallows the rest of the file.
    # BOTH CLOCK FORMATS. This matched 12-hour only ('resets 8:40pm'). A 24-hour message
    # ('resets 17:20') fell through to the five-hour guess, which is worse than useless: guessed
    # from 15:45 it parks the queue until 20:45 over a limit that actually clears at 17:20, losing
    # the entire evening. The am/pm group is now optional and absence means 24-hour.
    if ($out -match '(?i)resets?\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?') {
        $hh = [int]$Matches[1]
        $mm = 0
        if ($Matches[2]) { $mm = [int]$Matches[2] }
        if ($Matches[3] -match '(?i)pm' -and $hh -lt 12) { $hh += 12 }
        if ($Matches[3] -match '(?i)am' -and $hh -eq 12) { $hh = 0 }
        # A bare number is not a clock time, but the guard that enforced that broke the 12-hour case
        # it was protecting, so it is out. The five-hour cap below bounds the damage from any
        # misparse to one session window, which is the property that actually matters.
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
    # Never stand down longer than one session window, whatever was parsed or guessed. A wrong
    # reset time should cost one wasted cycle, not an evening.
    $cap = (Get-Date).AddHours(5)
    if ($resume -gt $cap) { $resume = $cap }
    $resume.ToString('o') | Set-Content $cool -Encoding ascii
    Say "hit a usage limit -- standing down until $($resume.ToString('HH:mm'))"
    # BUT DO NOT WALK AWAY FROM WORK. This path used to exit before the uncommitted-work check
    # below, so on 2026-08-15 a run that had implemented FPS controls (+174 lines in player.gd) and
    # ticked the item hit a FALSE limit and left all of it unsaved and unflagged for forty minutes.
    # Being rate-limited says nothing about whether the tree is clean.
    #
    # It now COMMITS that work instead of pausing over it. The pause was worse than the disease: it
    # released only on a clean tree, and the only thing that could clean the tree was the pause
    # lifting, so a limit landing mid-item deadlocked the queue until a human noticed. On 2026-08-16
    # that cost twelve hours over two additive functions.
    if ($topitem) { Say "  it was working on: $($topitem.Trim())" }
    [void](CommitStranded "hit a usage limit mid-item")
    exit 0
}

# --- did it actually commit? ----------------------------------------------------------------
# A tick that does work and does not commit is worse than a tick that does nothing: the next firing
# starts on top of it, and the one after that. That is exactly how three runs were lost on
# 2026-08-10 -- a class_name that only resolves in the editor left the project unparseable, the
# agent could not verify anything, no commit happened, and each following tick piled on more.
# Nothing detected it. Now it does, and it stops the queue rather than compounding.
# SAY WHAT IT WAS DOING, not just that it failed. When this fired on 2026-08-13 it recorded only
# "2 files uncommitted", and those edits were later swept into an unrelated commit by a `git add -A`
# two days later. The code survived; the PURPOSE did not, and reconstructing it afterwards took five
# minutes of archaeology that a diffstat and one line of item text would have answered. So the
# rescue commit names the item in its message.
if (@(Dirt).Count -gt 0) {
    Say "the run left work uncommitted."
    if ($topitem) { Say "  it was working on: $($topitem.Trim())" }
    Say "  diffstat:"
    foreach ($l in @(git diff --stat -- . ':(exclude)logs')) { if ($l) { Say "        $l" } }
    if (-not (CommitStranded "the run ended without committing")) { exit 0 }
}

# NOW check the project still loads. This runs on every path that reaches here, committed by the
# agent or rescued above, because the failure it catches is invisible to everything else: three
# items in a row shipped against a HEAD that could not compile, each logging only that it had not
# been able to run-verify. A broken HEAD must stop the queue -- that is a human's problem, not
# something the next cold run should discover the hard way.
if (-not (ParseGate)) {
    SetStatus "idle" "PARSE GATE FAILED"
    "AUTO-PAUSE. Set at $(Get-Date -Format 'HH:mm'): the project does not compile after this run.`nThe work IS committed -- see the log for the parse errors. Fix them, then delete this file.`nIt was working on: $topitem" |
        Set-Content $pause -Encoding ascii
    Say "queue paused: HEAD does not compile. Nothing further will run until that is fixed."
    exit 0
}

# --- did it actually DO anything? -----------------------------------------------------------
# "tick done" used to be printed unconditionally, so a run that achieved nothing was indistinguishable
# in the log from one that shipped a feature. Nine consecutive no-ops on 2026-08-10 all read as
# success. If the open count did not move, say so plainly -- it is the difference between "the queue
# is progressing" and "the queue has been spinning for four hours".
$left = (Select-String -Path "$repo\TASKS.md" -Pattern '^- \[ \]' -ErrorAction SilentlyContinue).Count
if ($left -ge $open) {
    SetStatus "idle" "no item completed"
    Say "=== tick did NOT complete an item (${open} -> ${left} open) -- see the output above ==="
    exit 0
}
# --- get it off the machine -------------------------------------------------------------------
# A tick that commits and never pushes is a tick whose work exists on one disk. That is how 183
# commits accumulated locally over three weeks. Push every time; a no-op push costs nothing.
git push origin $branch --quiet
if ($LASTEXITCODE -eq 0) {
    SetStatus "idle" "pushed"
    Say "pushed $branch"
} else {
    Say "PUSH FAILED for $branch -- work is committed locally but not backed up"
}

SetStatus "idle" "done, $left items left"
Say "=== tick done (${left} items left) ==="

