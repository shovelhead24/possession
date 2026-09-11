$ErrorActionPreference='Stop'
$repo='C:\Games\possession'
$checkout='C:\Users\Bran the builder\Documents\Codex\Possession-models'
$installed='C:\Users\Bran the builder\Documents\Codex\Possession-worker'
$source=$PSScriptRoot
New-Item -ItemType Directory -Force $installed,(Join-Path $installed 'original-tasks') | Out-Null
foreach ($name in @('possession-queue-tick','possession-s2-fetch')) {
    $backup=Join-Path $installed "original-tasks\$name.xml"
    if (!(Test-Path $backup)) { Export-ScheduledTask -TaskName $name | Set-Content -LiteralPath $backup -Encoding Unicode }
}
$scriptDest=Join-Path $repo 'scripts\model-worker'
$workshop=Join-Path $repo 'model-workshop'
$archive=Join-Path $repo 'docs\archive\TASKS-before-model-production.md'
New-Item -ItemType Directory -Force $scriptDest,$workshop,(Join-Path $workshop 'lib'),(Split-Path $archive) | Out-Null
if (!(Test-Path $archive)) { Copy-Item -LiteralPath (Join-Path $repo 'TASKS.md') -Destination $archive }
foreach ($file in @('worker.ps1','launch.vbs','result.schema.json','validate_model.py','README.md','install.ps1')) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $scriptDest -Force
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $installed -Force
}
Copy-Item -LiteralPath (Join-Path $source 'BRIEF.md') -Destination $workshop -Force
Copy-Item -LiteralPath (Join-Path $source 'project.godot') -Destination $workshop -Force
Set-Content (Join-Path $workshop 'lib\.gitkeep') ''
Set-Content (Join-Path $workshop '.gitignore') ".godot/`n**/*.png`n**/*.blend1`n**/__pycache__/`n"
$catalogue=Get-Content (Join-Path $repo 'game\mocks\ring_vibes.gd') -Raw
$queue=@()
foreach ($entry in @(@('WEAPON_ROWS','weapons'),@('VEHICLE_ROWS','vehicles'))) {
    $start=$catalogue.IndexOf('const '+$entry[0]+' := {')
    if ($start -lt 0) { throw "Missing catalogue $($entry[0])" }
    $end=$catalogue.IndexOf("`n}",$start)
    $block=$catalogue.Substring($start,$end-$start)
    $rows=[regex]::Matches($block,'(?ms)^\t"([a-z0-9_]+)":\s*\{.*?^\t\},?')
    foreach ($row in $rows) {
        $key=$row.Groups[1].Value
        $queue += [pscustomobject]@{id="$($entry[1])-$key"; category=$entry[1]; key=$key;
            complex=($key -in @('horse','elephant','strider','mech_biped','mech_quad','suit','rotor','airplane','lifter'));
            source=$row.Value}
    }
}
if ($queue.Count -ne 46) { throw "Expected 46 catalogue entries, found $($queue.Count); review before enabling." }
$queue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $installed 'queue.json') -Encoding UTF8
Copy-Item (Join-Path $installed 'queue.json') $scriptDest -Force
$lines=@('# Model production queue','','46 catalogue assets. Each requires source, exported GLB, dimensions/pivots, geometry validation, Godot import and independent visual approval.','','The previous development queue is preserved in docs/archive/TASKS-before-model-production.md. The 30-second gameplay loop is deferred. See model-workshop/BRIEF.md for the art brief and scripts/model-worker/README.md for operation.','','Completed models live on the isolated asset-production branch; this checkout keeps the initial checklist. Runtime state is authoritative while a job is running.','')
$lines += $queue | ForEach-Object { "- [ ] $($_.id)" }
$lines | Set-Content (Join-Path $repo 'TASKS.md') -Encoding UTF8
git -C $repo add -- scripts/model-worker model-workshop TASKS.md docs/archive/TASKS-before-model-production.md
if ($LASTEXITCODE -ne 0) { throw 'Cannot stage worker setup' }
git -C $repo diff --cached --quiet -- scripts/model-worker model-workshop TASKS.md docs/archive/TASKS-before-model-production.md
if ($LASTEXITCODE -eq 1) {
    git -C $repo commit -m 'Set up quiet resumable model production queue' -- scripts/model-worker model-workshop TASKS.md docs/archive/TASKS-before-model-production.md
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit worker setup' }
}
if (!(Test-Path $checkout)) {
    git -C $repo worktree add -b asset-production $checkout HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create isolated model worktree' }
} else { throw "Checkout already exists: inspect it before reinstalling to avoid overwriting active work." }
$config=[ordered]@{checkout=$checkout; codex='C:\Users\Bran the builder\AppData\Local\OpenAI\Codex\bin\8e5b6932251c2c1c\codex.exe'; blender='C:\Program Files\Blender Foundation\Blender 4.4\blender.exe'; godot='C:\Godot\Godot_v4.5.1-stable_win64.exe'}
$config | ConvertTo-Json | Set-Content (Join-Path $installed 'config.json') -Encoding UTF8
& (Join-Path $installed 'worker.ps1') -CheckOnly
if ($LASTEXITCODE -ne 0) { throw 'Worker preflight failed' }
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument ('//B //NoLogo "'+(Join-Path $installed 'launch.vbs')+'"') -WorkingDirectory $installed
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'possession-queue-tick' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Possession model production. Hidden worker; retries usage limits every 15 minutes; isolated asset-production checkout.' -Force | Out-Null
Start-ScheduledTask -TaskName 'possession-queue-tick'
Get-ScheduledTask -TaskName 'possession-queue-tick' | Select-Object TaskName,State
Write-Output "Worker installed: $installed"
Write-Output "Model checkout: $checkout"
