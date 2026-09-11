param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$homeDir = $PSScriptRoot
$config = Get-Content (Join-Path $homeDir 'config.json') -Raw | ConvertFrom-Json
$runtime = Join-Path $homeDir 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
try { $lock = [IO.File]::Open((Join-Path $runtime 'worker.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch [IO.IOException] { exit 0 }
$statePath = Join-Path $runtime 'state.json'
$script:state = $null
function Save-State {
    $script:state.updatedUtc = [DateTime]::UtcNow.ToString('o')
    $temp = "$statePath.tmp"
    [IO.File]::WriteAllText($temp, ($script:state | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
    if (Test-Path $statePath) { [IO.File]::Replace($temp, $statePath, "$statePath.bak") }
    else { [IO.File]::Move($temp, $statePath) }
    $done=@($script:state.items | Where-Object status -eq 'complete').Count
    $blocked=@($script:state.items | Where-Object status -eq 'blocked').Count
    $statusText=@('# Possession model production', '', "Completed: $done / $($script:state.items.Count). Needs attention: $blocked.", '', "State: $($script:state.status)", "Current asset: $($script:state.current)", "Updated (UTC): $($script:state.updatedUtc)", "Next retry (UTC): $($script:state.nextAttemptUtc)", '', $script:state.message, '', 'The Windows task checks every 15 minutes. Create runtime/PAUSE to pause after the current item.', '', "Model files: $($config.checkout)\model-workshop\assets") -join "`r`n"
    [IO.File]::WriteAllText((Join-Path $homeDir 'STATUS.md'), $statusText)
}
function Quote-Arg([string]$value) {
    '"' + [regex]::Replace([regex]::Replace($value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Run-Child([string]$exe, [string[]]$arguments, [string]$name, [string]$inputText = '', [int]$minutes = 45) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $exe
    $info.Arguments = (($arguments | ForEach-Object { Quote-Arg $_ }) -join ' ')
    $info.WorkingDirectory = $config.checkout
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    if (!$process.Start()) { throw "Cannot start $exe" }
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($inputText)
    $process.StandardInput.Close()
    if (!$process.WaitForExit($minutes * 60000)) {
        # Only this worker's child tree; never kill by executable name.
        $killInfo = New-Object Diagnostics.ProcessStartInfo
        $killInfo.FileName = "$env:SystemRoot\System32\taskkill.exe"
        $killInfo.Arguments = "/PID $($process.Id) /T /F"
        $killInfo.UseShellExecute = $false
        $killInfo.CreateNoWindow = $true
        $killer = [Diagnostics.Process]::Start($killInfo)
        $killer.WaitForExit()
        throw "$name exceeded $minutes minutes; partial files retained"
    }
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $runtime "$name.stdout.log"), $stdout)
    [IO.File]::WriteAllText((Join-Path $runtime "$name.stderr.log"), $stderr)
    $code = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ code=$code; output=($stdout + "`n" + $stderr) }
}
function Invoke-Agent([string]$prompt, [string]$model, [string]$name, [string[]]$images = @()) {
    [IO.File]::WriteAllText((Join-Path $runtime "$name.prompt.txt"), $prompt)
    $resultPath = Join-Path $runtime "$name.result.json"
    if (Test-Path $resultPath) { Remove-Item -LiteralPath $resultPath }
    $agentArgs = @('exec', '--ignore-user-config', '--sandbox', 'workspace-write', '-c', 'approval_policy="never"', '-c', 'windows.sandbox="elevated"',
        '-c', 'model_reasoning_effort="medium"', '-C', $config.checkout, '-m', $model,
        '--json', '--color', 'never', '--output-schema', (Join-Path $homeDir 'result.schema.json'), '-o', $resultPath)
    foreach ($img in $images) { $agentArgs += @('--image', $img) }
    $agentArgs += '-'
    $result = Run-Child $config.codex $agentArgs $name $prompt
    if ($result.code -ne 0 -and $result.output -match '(?i)usage.limit|rate.limit|quota.exceeded|usage_limit_reached|too many requests') {
        $script:state.status = 'waiting_for_usage'
        $script:state.nextAttemptUtc = [DateTime]::UtcNow.AddMinutes(15).ToString('o')
        $script:state.message = 'Usage limit: preserve current asset and retry in 15 minutes.'
        Save-State
        return $null
    }
    if ($result.code -ne 0) { throw "Agent exited $($result.code); see $name.stderr.log and stdout.log" }
    if (!(Test-Path $resultPath)) { throw 'Agent returned no structured result' }
    return (Get-Content $resultPath -Raw | ConvertFrom-Json)
}
try {
    foreach ($path in @($config.checkout, $config.codex, $config.blender, $config.godot)) {
        if (!(Test-Path -LiteralPath $path)) { throw "Missing prerequisite: $path" }
    }
    $queue = Get-Content (Join-Path $homeDir 'queue.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (Test-Path $statePath) { $script:state = Get-Content $statePath -Raw | ConvertFrom-Json }
    else {
        $script:state = [pscustomobject]@{ status='ready'; updatedUtc=''; nextAttemptUtc=''; current=''; message='';
            items=@($queue | ForEach-Object { [pscustomobject]@{id=$_.id; status='pending'; failures=0; note=''; phase='build'} }) }
        Save-State
    }
    if ($CheckOnly) { Write-Output "Configuration valid: $($queue.Count) assets; 15-minute retry; hidden children."; exit 0 }
    if (Test-Path (Join-Path $runtime 'PAUSE')) { $script:state.status='paused'; Save-State; exit 0 }
    if ($script:state.nextAttemptUtc -and [DateTime]::Parse($script:state.nextAttemptUtc).ToUniversalTime() -gt [DateTime]::UtcNow) { exit 0 }
    $script:state.nextAttemptUtc = ''
    $until = [DateTime]::UtcNow.AddMinutes(90)
    while ([DateTime]::UtcNow -lt $until) {
        if (Test-Path (Join-Path $runtime 'PAUSE')) { $script:state.status='paused'; Save-State; break }
        $item = $script:state.items | Where-Object { $_.status -in @('pending','working') } | Select-Object -First 1
        if (!$item) {
            $script:state.status = if (@($script:state.items | Where-Object status -eq 'blocked').Count) { 'needs_attention' } else { 'complete' }
            $script:state.message = 'Queue exhausted; no further model calls until more work is added.'
            Save-State; break
        }
        if (!$item.PSObject.Properties['phase']) { $item | Add-Member -NotePropertyName phase -NotePropertyValue 'build' }
        $spec = $queue | Where-Object id -eq $item.id | Select-Object -First 1
        if (!$spec -or !$spec.source -or !$spec.key) { throw "Missing catalogue specification for $($item.id)" }
        $item.status = 'working'
        $script:state.current = $item.id
        $script:state.status = 'building'
        Save-State
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $name = "$stamp-$($item.id)"
        $folder = Join-Path $config.checkout "model-workshop\assets\$($spec.category)\$($spec.key)"
        $model = if ($item.failures -ge 1 -or $spec.complex) { 'gpt-5.6-sol' } else { 'gpt-5.6-luna' }
        $prompt = @"
You are producing one finished low-poly 3D asset for Possession. Work only in model-workshop/ in this isolated checkout. Do not push, modify game mechanics, install software, access credentials, purchase anything, alter the scheduler, or commit; the supervisor commits validated assets. The 30-second gameplay loop is intentionally deferred. Read model-workshop/BRIEF.md and the selected asset's existing files; avoid loading unrelated repository docs. Task: $($spec.id). Catalogue data: $($spec.source)
Use Blender at $($config.blender) in background mode. Create a reusable, deterministic build.py (shared helpers may go in model-workshop/lib), source.blend, model.glb, and README.md inside $folder. You MUST run your build and export the actual files before returning. Use the existing catalogue purpose and scale; make an original design using Halo CE era visual principles. This is real finished art, not a generic collection of boxes or an image. Preserve useful separate moving parts and named attachment markers. Budget: 4500 triangles weapons, 14000 vehicles, at most 12 materials. Review source dimensions, normals, silhouette and detail; no geometry hidden inside other geometry without purpose. Missing deps or errors are not success. Finish only this asset. Build on partial work instead of restarting blindly. Previous failure/review: $($item.note)
When files are ready for the supervisor's independent render/validation return status ready and a short summary. If unable, return blocked and a concrete reason. Never claim that screenshots were inspected unless you actually opened them.
"@
        try {
            if ($item.phase -ne 'review') {
            $answer = Invoke-Agent $prompt $model "$name-build"
            if ($null -eq $answer) { break }
            if ($answer.status -ne 'ready') { throw $answer.summary }
            foreach ($file in @('build.py','source.blend','model.glb','README.md')) {
                if (!(Test-Path (Join-Path $folder $file))) { throw "Missing $file" }
            }
            $script:state.status='validating'; Save-State
            $validation = Run-Child $config.blender @('--background','--factory-startup','--python-exit-code','1','--python', (Join-Path $homeDir 'validate_model.py'), '--', $folder, $spec.category) "$name-validation" '' 15
            if ($validation.code -ne 0 -or $validation.output -notmatch 'MODEL_VALIDATION_PASSED') { throw "Geometry/render validation failed; see $name-validation logs" }
            $import = Run-Child $config.godot @('--headless','--path',(Join-Path $config.checkout 'model-workshop'),'--editor','--import') "$name-import" '' 5
            if ($import.code -ne 0 -or $import.output -match '(?m)^(SCRIPT ERROR|ERROR):') { throw "Godot import failed; see $name-import logs" }
            $item.phase='review'
            }
            $script:state.status='reviewing'; Save-State
            $reviewPrompt = @"
Review this Possession 3D asset using BOTH attached renders plus $folder/README.md and metrics.json. Catalogue: $($spec.source). Read model-workshop/BRIEF.md. Look critically at silhouette, recognizable function, proportions, original Halo CE era low-poly styling, material separation and useful pivots. Images were rendered independently from the actual exported GLB. Do not change files. Return ready only if this is a usable, convincing asset for the stated role; generic crude primitives or a wrong/missing part require revise with actionable fixes. Check documented dimensions against catalogue scale. Be economical but do not rubber-stamp. This is visual art review, not gameplay design.
"@
            $review = Invoke-Agent $reviewPrompt 'gpt-5.6-sol' "$name-review" @((Join-Path $folder 'preview.png'),(Join-Path $folder 'side.png'))
            if ($null -eq $review) { break }
            if ($review.status -ne 'ready') { throw "Visual review: $($review.summary)" }
            [IO.File]::WriteAllText((Join-Path $folder 'review.json'), ($review | ConvertTo-Json))
            $relative = "model-workshop/assets/$($spec.category)/$($spec.key)"
            $add = Run-Child 'git.exe' @('add','--',$relative,'model-workshop/lib') "$name-stage" '' 1
            if ($add.code -ne 0) { throw "Cannot stage asset; see $name-stage logs" }
            $diff = Run-Child 'git.exe' @('diff','--cached','--quiet','--',$relative,'model-workshop/lib') "$name-diff" '' 1
            if ($diff.code -eq 1) {
                $commit = Run-Child 'git.exe' @('commit','-m',"Add reviewed $($spec.key) model",'--',$relative,'model-workshop/lib') "$name-commit" '' 1
                if ($commit.code -ne 0) { throw "Cannot commit asset; see $name-commit logs" }
            } elseif ($diff.code -ne 0) { throw 'Unable to inspect staged model changes' }
            $item.status='complete'; $item.note=$review.summary
            $script:state.message="Completed $($item.id) using $model; visual review passed."
            Save-State
        } catch {
            $item.phase='build'
            $item.failures++
            $item.note=$_.Exception.Message
            $item.status=if ($item.failures -ge 3) { 'blocked' } else { 'pending' }
            $script:state.status='retry_pending'
            $script:state.message=$item.note
            $script:state.nextAttemptUtc=[DateTime]::UtcNow.AddMinutes(15).ToString('o')
            Save-State
            break
        }
    }
} catch {
    [IO.File]::WriteAllText((Join-Path $runtime 'fatal.log'), ($_ | Out-String))
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
