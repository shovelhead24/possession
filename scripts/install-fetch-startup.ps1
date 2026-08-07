# Make the satellite refetch resume by itself at logon, with no Claude session and no terminal left
# open. Uses the per-user Startup folder rather than a Scheduled Task because the latter needs
# elevation and this does not.
#
# The driver skips anything already done, so running it at every logon is harmless -- with nothing
# outstanding it exits in about a second.
#
# To remove:  Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\possession-s2-refetch.cmd"
$startup = [Environment]::GetFolderPath('Startup')
$cmd = Join-Path $startup 'possession-s2-refetch.cmd'
@'
@echo off
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Games\possession\scripts\fetch-s2-resume.ps1"
'@ | Set-Content -Path $cmd -Encoding ascii
Write-Host "installed: $cmd"
