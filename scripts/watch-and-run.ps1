# watch-and-run.ps1
# Polls GitHub for new commits every 15 seconds.
# When new code is detected, pulls and relaunches Godot automatically.
#
# ONE-TIME SETUP on the laptop:
#   1. Edit the three variables below to match your paths
#   2. Run once manually to test: powershell -ExecutionPolicy Bypass -File watch-and-run.ps1
#   3. To auto-start on login: add a shortcut to this file in
#      %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
#      or use Task Scheduler (trigger: At log on, action: powershell.exe -WindowStyle Hidden -File "C:\path\to\watch-and-run.ps1")

# ---- CONFIGURE THESE ----
$projectPath = "C:\Games\possession"          # Where you cloned the repo on the laptop
$godotExe    = "C:\Godot\Godot_v4.x.exe"     # Path to your Godot 4 executable
$pollSeconds = 15                              # How often to check for new commits
# -------------------------

$ErrorActionPreference = "SilentlyContinue"

function Start-Godot {
    param($currentProcess)
    if ($currentProcess -and -not $currentProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Stopping Godot..."
        $currentProcess.Kill()
        Start-Sleep -Seconds 2
    }
    Write-Host "$(Get-Date -Format HH:mm:ss) Launching Godot..."
    return Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`"" -PassThru
}

# Verify paths before starting
if (-not (Test-Path $projectPath)) {
    Write-Error "Project path not found: $projectPath"
    Write-Error "Edit the `$projectPath variable at the top of this script."
    Read-Host "Press Enter to exit"
    exit 1
}
if (-not (Test-Path $godotExe)) {
    Write-Error "Godot executable not found: $godotExe"
    Write-Error "Edit the `$godotExe variable at the top of this script."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "=== Possession auto-launcher ==="
Write-Host "Project: $projectPath"
Write-Host "Polling every $pollSeconds seconds for new commits."
Write-Host "Close this window to stop."
Write-Host ""

# Initial launch
$godotProcess = Start-Godot $null
$lastHash = git -C $projectPath rev-parse HEAD 2>$null

while ($true) {
    Start-Sleep -Seconds $pollSeconds

    # Fetch silently — does not change local files
    git -C $projectPath fetch --quiet origin main 2>$null

    $remoteHash = git -C $projectPath rev-parse origin/main 2>$null

    if ($remoteHash -and $remoteHash -ne $lastHash) {
        Write-Host "$(Get-Date -Format HH:mm:ss) New commits found. Pulling..."
        git -C $projectPath pull --quiet origin main 2>$null
        $lastHash = $remoteHash
        $godotProcess = Start-Godot $godotProcess
    }

    # Relaunch if Godot was closed manually
    if ($godotProcess.HasExited) {
        Write-Host "$(Get-Date -Format HH:mm:ss) Godot closed. Relaunching..."
        $godotProcess = Start-Godot $null
    }
}
