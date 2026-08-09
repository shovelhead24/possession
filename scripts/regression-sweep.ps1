#Requires -Version 5.1
<#
regression-sweep.ps1

Runs the headless probe modes (--align, --selftest, --texprobe), pulls the
DETERMINISTIC signal lines out of each run's log, and diffs them against the
last blessed baseline. Reports ONLY what changed.

Why this exists: this project's worst bugs were silent successes -- a mode
exited 0 and the log looked fine while a count had quietly halved (6 of 10
streams loading the wrong file; buildings 10-16% out; trees dropping by tier).
A [Y] probe or a glance never catches that class of thing. A line-by-line diff
against a recorded known-good does.

What it captures per mode (volatile timings like "(1082 ms)" / "(2.5s)" are
stripped so a slow run does not read as a regression):
  --align     ALIGN per-patch tier/sea lines + the two ALIGN: summary counts
  --selftest  SELFTEST per-patch stream/height/tree lines + the streamed-OK count
  --texprobe  TEXPROBE mode/res/bytes line
plus the one-time startup census printed before the first mode line (trees
placed, buildings kept, road centrelines, splice patch list).

Usage:
  # normal run: diff against baseline, exit 1 if anything moved
  powershell -ExecutionPolicy Bypass -File scripts\regression-sweep.ps1

  # bless the current outputs as the new known-good. Do this once to seed, and
  # again after a change whose new numbers you have actually eyeballed:
  powershell -ExecutionPolicy Bypass -File scripts\regression-sweep.ps1 -Accept

  # subset of modes
  powershell -ExecutionPolicy Bypass -File scripts\regression-sweep.ps1 -Modes align,selftest

Baselines live in logs\regression\baseline\<mode>.txt -- committed, because they
ARE the known-good. The latest normalised + raw capture lands in
logs\regression\current\ for evidence.

Exit code: 0 = matches baseline (or -Accept / first-seed), 1 = changes detected.
#>

[CmdletBinding()]
param(
    [string[]]$Modes = @('align','selftest','texprobe'),
    [string]$GodotExe,
    [string]$GodotUserLog = "$env:APPDATA\Godot\app_userdata\HaloTest\logs\godot.log",
    [switch]$Accept,
    [switch]$Headless,
    [int]$RunTimeout = 240,      # seconds -- align/selftest quit themselves
    [int]$TexprobeTimeout = 120  # seconds -- texprobe never quits; we wait for its line then kill
)

$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot
$game    = Join-Path $repo 'game'
$regDir  = Join-Path $repo 'logs\regression'
$baseDir = Join-Path $regDir 'baseline'
$curDir  = Join-Path $regDir 'current'
New-Item -ItemType Directory -Force -Path $baseDir, $curDir | Out-Null

# ---------------------------------------------------------------------------- #
function Find-Godot([string]$explicit) {
    if ($explicit) {
        if (Test-Path $explicit) { return (Get-Item $explicit).FullName }
        throw "Godot not found at -GodotExe path: $explicit"
    }
    $candidates = @(
        'C:\Godot\Godot_v4.5.1-stable_win64.exe',
        'C:\Godot\Godot_v4.5*win64.exe',
        'C:\Godot\Godot*win64.exe',
        "$env:USERPROFILE\Downloads\Godot*win64.exe",
        "$env:USERPROFILE\Desktop\Godot*win64.exe"
    )
    foreach ($c in $candidates) {
        $f = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    $onPath = Get-Command godot* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    throw "Could not find a Godot executable. Pass -GodotExe 'C:\path\to\Godot.exe'."
}

# Keep only the lines that carry real signal, and strip volatile timings so the
# same world does not diff against itself run to run. The startup census (trees
# placed / buildings kept / centrelines / splice list) is printed ONCE before
# the first mode line, so gate those on not having seen a mode tag yet -- that
# drops the per-jump "N trees placed" chatter selftest prints after it starts.
function Normalize-Log([string[]]$lines) {
    $out = New-Object System.Collections.ArrayList
    $seenTag = $false
    foreach ($raw in $lines) {
        if ($null -eq $raw) { continue }
        $l = $raw -replace "^﻿", ''                       # BOM
        $l = $l -replace '\(\s*\d+(\.\d+)?\s*ms\)', ''          # (1082 ms)
        $l = $l -replace '\(\s*\d+(\.\d+)?\s*s\)', ''           # (2.5s)
        $l = $l.TrimEnd()
        if ($l -match '^(ALIGN|SELFTEST|TEXPROBE)\b') {
            $seenTag = $true
            [void]$out.Add($l)
        } elseif (-not $seenTag -and
                  $l -match '^ring_vibes:.*(\d+ trees placed|buildings kept|road centrelines loaded|splice patches @|patch\(es\) clipped)') {
            [void]$out.Add($l)
        }
    }
    return ,$out.ToArray()
}

# Two lines "match shape" if they are identical once every number is blanked to
# '#'. Same shape + different text => a value moved (reported old -> new). A key
# in one side only => a line was added or removed outright.
function Mask([string]$s) { return [regex]::Replace($s, '\d+(\.\d+)?', '#') }

function Diff-Lines($base, $cur) {
    $changes = New-Object System.Collections.ArrayList
    $bMap = @{}
    $cMap = @{}
    foreach ($l in @($base)) { $k = Mask $l; if (-not $bMap.ContainsKey($k)) { $bMap[$k] = New-Object System.Collections.ArrayList }; [void]$bMap[$k].Add($l) }
    foreach ($l in @($cur))  { $k = Mask $l; if (-not $cMap.ContainsKey($k)) { $cMap[$k] = New-Object System.Collections.ArrayList }; [void]$cMap[$k].Add($l) }
    $keys = @($bMap.Keys) + @($cMap.Keys) | Select-Object -Unique
    foreach ($k in $keys) {
        $b = @(); if ($bMap.ContainsKey($k)) { $b = $bMap[$k] }
        $c = @(); if ($cMap.ContainsKey($k)) { $c = $cMap[$k] }
        $n = [Math]::Max($b.Count, $c.Count)
        for ($i = 0; $i -lt $n; $i++) {
            $bl = $null; if ($i -lt $b.Count) { $bl = $b[$i] }
            $cl = $null; if ($i -lt $c.Count) { $cl = $c[$i] }
            if ($bl -eq $cl) { continue }
            [void]$changes.Add([pscustomobject]@{ Old = $bl; New = $cl })
        }
    }
    return $changes
}

function Show-Diff($mode, $changes) {
    if ($changes.Count -eq 0) {
        Write-Host ("  {0,-9} no change" -f $mode) -ForegroundColor Green
        return
    }
    Write-Host ("  {0,-9} {1} line(s) changed" -f $mode, $changes.Count) -ForegroundColor Yellow
    foreach ($c in $changes) {
        if ($c.Old) { Write-Host ("    - {0}" -f $c.Old) -ForegroundColor Red }
        if ($c.New) { Write-Host ("    + {0}" -f $c.New) -ForegroundColor Green }
    }
}

function Invoke-Mode($mode) {
    $flag = "--$mode"
    $argList = @()
    if ($Headless) { $argList += '--headless' }
    $argList += @('--path', $game, '--', $flag)
    Write-Host ("  running $flag ...") -ForegroundColor Cyan
    # Godot rewrites godot.log on each launch, so the file is this run's output.
    $proc = Start-Process -FilePath $godot -ArgumentList $argList -PassThru
    try {
        if ($mode -eq 'texprobe') {
            # texprobe prints on decode and then just sits there -- wait for the
            # line to land, then kill it.
            $deadline = (Get-Date).AddSeconds($TexprobeTimeout)
            $got = $false
            while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
                Start-Sleep -Seconds 1
                if ((Test-Path $GodotUserLog) -and
                    (Select-String -Path $GodotUserLog -Pattern '^TEXPROBE' -Quiet -ErrorAction SilentlyContinue)) {
                    $got = $true; break
                }
            }
            if (-not $got) { Write-Host "    (no TEXPROBE line within ${TexprobeTimeout}s)" -ForegroundColor Yellow }
        } else {
            $exited = $proc.WaitForExit($RunTimeout * 1000)
            if (-not $exited) { Write-Host "    (timed out after ${RunTimeout}s)" -ForegroundColor Yellow }
        }
    } finally {
        if (-not $proc.HasExited) { $proc.Kill() | Out-Null; Start-Sleep -Milliseconds 500 }
    }
    if (-not (Test-Path $GodotUserLog)) {
        throw "No Godot log at $GodotUserLog after running $flag. Pass -GodotUserLog with the right app_userdata path."
    }
    $raw = @(Get-Content -LiteralPath $GodotUserLog)
    Copy-Item -LiteralPath $GodotUserLog -Destination (Join-Path $curDir "$mode.raw.log") -Force
    return (Normalize-Log $raw)
}

# ---------------------------------------------------------------------------- #
$godot = Find-Godot $GodotExe
Write-Host "Godot: $godot"
Write-Host "Game : $game"
if ($Headless) { Write-Host "Mode : headless" }
Write-Host ""

$ran = @()
foreach ($m in $Modes) {
    $mode = $m.ToLower().TrimStart('-')
    if ($mode -notin @('align','selftest','texprobe')) {
        Write-Host "  skip unknown mode: $mode" -ForegroundColor Yellow
        continue
    }
    $cur = @(Invoke-Mode $mode)
    Set-Content -Path (Join-Path $curDir "$mode.txt") -Value $cur -Encoding utf8
    $ran += [pscustomobject]@{ Mode = $mode; Lines = $cur }
}

Write-Host ""
Write-Host "=== regression diff ===" -ForegroundColor Cyan
$anyChange = $false
foreach ($r in $ran) {
    $mode = $r.Mode
    $cur  = @($r.Lines)
    $baseFile = Join-Path $baseDir "$mode.txt"
    if ($Accept) {
        Set-Content -Path $baseFile -Value $cur -Encoding utf8
        Write-Host ("  {0,-9} baseline updated ({1} lines)" -f $mode, $cur.Count) -ForegroundColor Cyan
        continue
    }
    if (-not (Test-Path $baseFile)) {
        Set-Content -Path $baseFile -Value $cur -Encoding utf8
        Write-Host ("  {0,-9} baseline established ({1} lines) -- no prior known-good" -f $mode, $cur.Count) -ForegroundColor Cyan
        continue
    }
    $base = @(Get-Content -LiteralPath $baseFile)
    $changes = @(Diff-Lines $base $cur)
    Show-Diff $mode $changes
    if ($changes.Count -gt 0) { $anyChange = $true }
}

Write-Host ""
if ($Accept)    { Write-Host "Baselines blessed." -ForegroundColor Cyan; exit 0 }
if ($anyChange) { Write-Host "CHANGES DETECTED -- review above. If intended, re-run with -Accept." -ForegroundColor Yellow; exit 1 }
Write-Host "All modes match the known-good baseline." -ForegroundColor Green
exit 0
