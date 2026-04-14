# watch-and-run.ps1
# Polls GitHub for new commits every 15 seconds.
# When new code is detected, pulls and relaunches Godot automatically.
# Logs Godot output to a rolling log file for troubleshooting.
#
# ONE-TIME SETUP on the laptop:
#   1. Edit the three variables below to match your paths
#   2. Run once manually to test: powershell -ExecutionPolicy Bypass -File watch-and-run.ps1
#   3. To auto-start on login, add a shortcut to this file in:
#      %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup

# ---- CONFIGURE THESE ----
$projectPath = "C:\Games\possession"          # Where you cloned the repo
$godotExe    = "C:\Godot\Godot_v4.5.1-stable_win64.exe"
$pollSeconds = 15                              # How often to check for new commits
# -------------------------

$logDir  = "$projectPath\logs"
$logFile = "$logDir\godot_latest.log"
$ErrorActionPreference = "SilentlyContinue"

# ------------------------------------------------------------------ #
#  DIAGNOSTICS - run at startup and print a clear summary             #
# ------------------------------------------------------------------ #
function Run-Diagnostics {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  POSSESSION - startup diagnostics" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $ok = $true

    # 1. Godot executable
    if (Test-Path $godotExe) {
        $version = & $godotExe --version 2>&1 | Select-Object -First 1
        Write-Host "[OK]  Godot found: $version" -ForegroundColor Green
        if ($version -notmatch "^4\.5") {
            Write-Host "[WARN] Project requires Godot 4.5 - you have: $version" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[FAIL] Godot not found at: $godotExe" -ForegroundColor Red
        Write-Host "       Edit `$godotExe at the top of this script." -ForegroundColor Red
        $ok = $false
    }

    # 2. Project path and project.godot
    if (Test-Path "$projectPath\game\project.godot") {
        Write-Host "[OK]  project.godot found" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] project.godot not found under: $projectPath" -ForegroundColor Red
        Write-Host "       Expected: $projectPath\game\project.godot" -ForegroundColor Red
        $ok = $false
    }

    # 3. Git repo
    $gitHash = git -C $projectPath rev-parse HEAD 2>$null
    if ($gitHash) {
        Write-Host "[OK]  Git repo at commit: $($gitHash.Substring(0,8))" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Not a git repo (or git not on PATH): $projectPath" -ForegroundColor Red
        $ok = $false
    }

    # 4. Large asset packs (local-only, not in git)
    $gameDir = "$projectPath\game"
    $assetPacks = @(
        "custom_halo_classic_ring",
        "enemy",
        "fp_arms",
        "fps_arms",
        "halo_-_carbine",
        "halo_railgun_redesigned",
        "halo_warthog",
        "realistic_fir_trees_pack_lods_gameready",
        "realistic_trees_collection",
        "skybox",
        "grass_pack_of_9_vars_lowpoly_game_ready",
        "tall_coniferous_fir_variant_low_poly",
        "low_poly_red_spruce_tree_custom_textures"
    )
    $missingPacks = @()
    foreach ($pack in $assetPacks) {
        if (-not (Test-Path "$gameDir\$pack")) {
            $missingPacks += $pack
        }
    }
    if ($missingPacks.Count -eq 0) {
        Write-Host "[OK]  All asset packs present" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Missing asset packs ($($missingPacks.Count)/$($assetPacks.Count)) - game may have missing meshes:" -ForegroundColor Yellow
        foreach ($p in $missingPacks) {
            Write-Host "       - $p" -ForegroundColor Yellow
        }
    }

    # 5. Log directory
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    Write-Host "[OK]  Logs will be written to: $logFile" -ForegroundColor Green

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    return $ok
}

# ------------------------------------------------------------------ #
#  LAUNCH GODOT                                                       #
# ------------------------------------------------------------------ #
function Start-Godot {
    param($currentProcess)

    if ($currentProcess -and -not $currentProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Stopping Godot..."
        $currentProcess.Kill()
        Start-Sleep -Seconds 2
    }

    $gamePath = "$projectPath\game"
    $godotBuiltinLog = "$env:APPDATA\Godot\app_userdata\HaloTest\logs\godot.log"
    Write-Host "$(Get-Date -Format HH:mm:ss) Launching Godot..."
    Write-Host "  Path: $gamePath"
    Write-Host "  Log : $godotBuiltinLog"
    Write-Host "  Tip : Get-Content `"$godotBuiltinLog`" -Wait -Tail 40"

    # Launch Godot directly so its window appears on screen
    $args = '--path "' + $gamePath + '" --verbose'
    return Start-Process -FilePath $godotExe -ArgumentList $args -PassThru
}

# ------------------------------------------------------------------ #
#  MAIN                                                               #
# ------------------------------------------------------------------ #

$diagOk = Run-Diagnostics

if (-not $diagOk) {
    Write-Host "Fix the errors above then re-run this script." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Auto-extract any asset packs that are in assets/ but not yet in game/
$extractScript = "$projectPath\scripts\extract-assets.ps1"
if (Test-Path $extractScript) {
    & powershell -ExecutionPolicy Bypass -File $extractScript
}

# Reimport all resources (required when new assets are extracted or .godot/imported/ is stale)
# --headless --editor --quit: starts editor without GUI, imports everything, then exits
Write-Host ""
Write-Host "=== ASSET IMPORT ===" -ForegroundColor Cyan
Write-Host "Importing resources (this takes ~30-60s on first run, fast after)..." -ForegroundColor Yellow
$importArgs = '--headless --editor --quit --path "' + $gamePath + '"'
$importProc = Start-Process -FilePath $godotExe -ArgumentList $importArgs -PassThru -NoNewWindow 2>$null
# Wait up to 120 seconds — kill if it hangs (headless editor can hang on some machines)
$importProc.WaitForExit(120000) | Out-Null
if (-not $importProc.HasExited) {
    $importProc.Kill()
    Write-Host "Import timed out after 120s - continuing anyway" -ForegroundColor Yellow
} else {
    Write-Host "Import complete (exit: $($importProc.ExitCode))" -ForegroundColor Green
}
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Watching for new commits every $pollSeconds seconds. Close this window to stop."
Write-Host "Press L to push the current log so Claude can read it."
Write-Host ""

# ------------------------------------------------------------------ #
#  PUSH LOG TO REPO                                                   #
# ------------------------------------------------------------------ #
function Push-Log {
    $godotLog = "$env:APPDATA\Godot\app_userdata\HaloTest\logs\godot.log"
    if (-not (Test-Path $godotLog)) {
        Write-Host "$(Get-Date -Format HH:mm:ss) No Godot log found yet." -ForegroundColor Yellow
        return
    }
    Write-Host "$(Get-Date -Format HH:mm:ss) Pushing log to repo..." -ForegroundColor Cyan
    Copy-Item -Path $godotLog -Destination $logFile -Force
    git -C $projectPath add "logs/godot_latest.log" 2>$null
    $msg = "log: laptop push $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git -C $projectPath commit -m $msg 2>$null
    git -C $projectPath pull --rebase origin main 2>$null
    git -C $projectPath push --quiet origin main 2>$null
    Write-Host "$(Get-Date -Format HH:mm:ss) Log pushed - Claude can now read logs/godot_latest.log" -ForegroundColor Green
}

# ------------------------------------------------------------------ #
#  POLL LOOP - checks for keypresses every 0.5s between git polls    #
# ------------------------------------------------------------------ #

# Pull any commits that arrived since the last manual pull / watcher restart
Write-Host "$(Get-Date -Format HH:mm:ss) Checking for commits missed while watcher was offline..."
git -C $projectPath fetch origin main 2>$null
$startRemote = git -C $projectPath rev-parse origin/main 2>$null
$startLocal  = git -C $projectPath rev-parse HEAD 2>$null
if ($startRemote -and $startRemote -ne $startLocal) {
    Write-Host "$(Get-Date -Format HH:mm:ss) Behind origin - pulling now..." -ForegroundColor Cyan
    git -C $projectPath pull --rebase origin main 2>$null
    Write-Host "$(Get-Date -Format HH:mm:ss) Pulled." -ForegroundColor Green
} else {
    $localShort = $startLocal.Substring(0,8)
    Write-Host "$(Get-Date -Format HH:mm:ss) Already up to date ($localShort)." -ForegroundColor Green
}

$godotProcess = Start-Godot $null
$lastHash = git -C $projectPath rev-parse HEAD 2>$null
$pollCount = 0

while ($true) {
    # Wait $pollSeconds but stay responsive to keypresses
    $waited = 0
    while ($waited -lt $pollSeconds) {
        Start-Sleep -Milliseconds 500
        $waited += 0.5
        if ($host.UI.RawUI.KeyAvailable) {
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -eq 'l' -or $key.Character -eq 'L') {
                Push-Log
                $lastHash = git -C $projectPath rev-parse HEAD 2>$null
            }
        }
    }

    $pollCount++
    git -C $projectPath fetch origin main 2>$null
    $remoteHash = git -C $projectPath rev-parse origin/main 2>$null

    if ($remoteHash -and $remoteHash -ne $lastHash) {
        Write-Host "$(Get-Date -Format HH:mm:ss) New commits detected - pulling..."
        git -C $projectPath pull --rebase origin main 2>$null
        $lastHash = git -C $projectPath rev-parse HEAD 2>$null  # Use actual local state
        Write-Host "$(Get-Date -Format HH:mm:ss) Relaunching Godot..."
        $godotProcess = Start-Godot $godotProcess
    }

    # Heartbeat every 4 polls (~60s) so you can confirm the watcher is alive
    if ($pollCount % 4 -eq 0) {
        $hash8 = (git -C $projectPath rev-parse HEAD 2>$null).Substring(0,8)
        Write-Host "$(Get-Date -Format HH:mm:ss) [watching] commit $hash8 | poll #$pollCount" -ForegroundColor DarkGray
    }

    # Auto-push log every 20 polls (~5 minutes) so Claude can read it without L keypress
    if ($pollCount % 20 -eq 0) {
        Push-Log
        # Update lastHash so the log commit doesn't look like a new code change
        $lastHash = git -C $projectPath rev-parse HEAD 2>$null
    }

    if ($godotProcess -and $godotProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Godot exited (code $($godotProcess.ExitCode)). Relaunching..."
        $godotProcess = Start-Godot $null
    }
}
