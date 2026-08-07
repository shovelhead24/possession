# Resume the 8192 satellite refetch. Safe to run at any time and as often as you like: the driver
# skips patches whose drape is already at the right resolution, extent AND coverage, so with nothing
# outstanding it exits in a second.
#
# Registered as a Scheduled Task (see install-fetch-task.ps1) so it survives sleep, logout and
# reboot without needing a Claude session or a terminal left open. The fetch is ~40 min per patch of
# real work; the laptop sleeping just pauses it.
$ErrorActionPreference = "Continue"
$log = "C:\Games\possession\logs\s2_refetch.log"
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
"=== resumed $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8
Set-Location "C:\Games\possession\tools\dem"
& python refetch_s2_8k.py 2>&1 | Tee-Object -FilePath $log -Append
"=== finished $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8
