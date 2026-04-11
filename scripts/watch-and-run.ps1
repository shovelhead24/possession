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
    if (Test-Path "$projectPath\halo-test - heightmaps 13\project.godot") {
        Write-Host "[OK]  project.godot found" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] project.godot not found under: $projectPath" -ForegroundColor Red
        Write-Host "       Expected: $projectPath\halo-test - heightmaps 13\project.godot" -ForegroundColor Red
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
    $gameDir = "$projectPath\halo-test - heightmaps 13"
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
#  LAUNCH GODOT - captures stdout+stderr to log file                  #
# ------------------------------------------------------------------ #
function Start-Godot {
    param($currentProcess)

    if ($currentProcess -and -not $currentProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Stopping Godot..."
        $currentProcess.Kill()
        Start-Sleep -Seconds 2
    }

    Write-Host "$(Get-Date -Format HH:mm:ss) Launching Godot (log -> $logFile)..."

    # Rotate old log
    if (Test-Path $logFile) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Move-Item $logFile "$logDir\godot_$stamp.log" -Force
        # Keep only last 5 logs
        Get-ChildItem "$logDir\godot_*.log" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 5 |
            Remove-Item -Force
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $godotExe
    $psi.Arguments = "--path `"$projectPath\halo-test - heightmaps 13`" --verbose"
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $false

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    # Write stdout and stderr to log file asynchronously
    $logStream = [System.IO.StreamWriter]::new($logFile, $false)
    $logStream.AutoFlush = $true

    $proc.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) { $logStream.WriteLine($e.Data) }
    })
    $proc.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) { $logStream.WriteLine($e.Data) }
    })

    $proc.Start() | Out-Null
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()

    # Close log stream when process exits
    $proc.add_Exited({ $logStream.Close() })
    $proc.EnableRaisingEvents = $true

    return $proc
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

Write-Host "Watching for new commits every $pollSeconds seconds. Close this window to stop."
Write-Host ""

$godotProcess = Start-Godot $null
$lastHash = git -C $projectPath rev-parse HEAD 2>$null

while ($true) {
    Start-Sleep -Seconds $pollSeconds

    git -C $projectPath fetch --quiet origin main 2>$null
    $remoteHash = git -C $projectPath rev-parse origin/main 2>$null

    if ($remoteHash -and $remoteHash -ne $lastHash) {
        Write-Host "$(Get-Date -Format HH:mm:ss) New commits - pulling and relaunching..."
        git -C $projectPath pull --quiet origin main 2>$null
        $lastHash = $remoteHash
        $godotProcess = Start-Godot $godotProcess
    }

    if ($godotProcess -and $godotProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Godot exited (code $($godotProcess.ExitCode)). Relaunching..."
        $godotProcess = Start-Godot $null
    }
}
