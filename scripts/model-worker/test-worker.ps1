$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'worker.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($function in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
    Invoke-Expression $function.Extent.Text
}
$homeDir=$PSScriptRoot
$runtime=Join-Path $env:TEMP ('possession-worker-test-'+[guid]::NewGuid())
New-Item -ItemType Directory $runtime | Out-Null
$statePath=Join-Path $runtime 'state.json'
$config=[pscustomobject]@{checkout=$runtime; codex='test'}
$catalogue = '[{"id":"weapons-spear","key":"spear"},{"id":"weapons-blade","key":"blade"}]' | ConvertFrom-Json
$selected=$catalogue | Where-Object id -eq 'weapons-spear' | Select-Object -First 1
if ($catalogue.Count -ne 2 -or $selected.key -ne 'spear') { throw 'Catalogue selection failed' }
$script:state=[pscustomobject]@{status='building'; updatedUtc=''; nextAttemptUtc=''; message=''}
Save-State
$script:state.message='second write'
Save-State
if ((Get-Content $statePath -Raw | ConvertFrom-Json).message -ne 'second write') { throw 'Atomic save failed' }
$lockFile=Join-Path $runtime 'lock'
$first=[IO.File]::Open($lockFile,'OpenOrCreate','ReadWrite','None')
$prevented=$false
try { $second=[IO.File]::Open($lockFile,'OpenOrCreate','ReadWrite','None'); $second.Dispose() } catch [IO.IOException] { $prevented=$true }
$first.Dispose()
if (!$prevented) { throw 'Concurrent access was not blocked' }
$values=@('space in path','embedded "quote"','C:\trailing\')
$child=Run-Child 'C:\Program Files\nodejs\node.exe' (@('-e','process.stdout.write(JSON.stringify(process.argv.slice(1)))')+$values) 'arguments' '' 1
$actual=@(($child.output.Trim() | ConvertFrom-Json))
for ($i=0;$i -lt $values.Count;$i++) { if ($actual[$i] -cne $values[$i]) { throw "Argument quoting mismatch $i" } }
$unicode='review '+[char]0x2014+' '+[char]0x00e9
$roundtrip=Run-Child 'C:\Program Files\nodejs\node.exe' @('-e','process.stdin.setEncoding("utf8");process.stdin.on("data",s=>process.stdout.write(s))') 'unicode' $unicode 1
if ($roundtrip.output.Trim() -cne $unicode) { throw 'Unicode prompt encoding failed' }
function Run-Child { return [pscustomobject]@{code=1; output='usage_limit_reached: try again later'} }
$answer=Invoke-Agent 'test' 'test' 'quota'
if ($null -ne $answer -or $script:state.status -ne 'waiting_for_usage') { throw 'Quota was not preserved' }
$delay=([DateTime]::Parse($script:state.nextAttemptUtc).ToUniversalTime()-[DateTime]::UtcNow).TotalMinutes
if ($delay -lt 14.9 -or $delay -gt 15.1) { throw 'Retry is not 15 minutes' }
$config | Add-Member -NotePropertyName pollAnchorUtc -NotePropertyValue ([DateTime]::UtcNow.AddMinutes(-1).ToString('o'))
$alignedDelay=([DateTime]::Parse((Next-PollUtc)).ToUniversalTime()-[DateTime]::UtcNow).TotalMinutes
if ($alignedDelay -lt 13.9 -or $alignedDelay -gt 14.1) { throw 'Retry skipped the next scheduled boundary' }
function Run-Child {
    [IO.File]::WriteAllText((Join-Path $runtime 'success.result.json'), '{"status":"ready","summary":"valid result"}')
    return [pscustomobject]@{code=0; output='Documentation discusses usage limits; this run succeeded.'}
}
$answer=Invoke-Agent 'test' 'test' 'success'
if ($answer.status -ne 'ready') { throw 'Successful documentation text falsely counted as rate limit' }
function Run-Child { return [pscustomobject]@{code=0; output='no structured result'} }
$rejected=$false
try { Invoke-Agent 'test' 'test' 'missing' | Out-Null } catch { $rejected=$true }
if (!$rejected) { throw 'Missing result incorrectly accepted' }
Write-Output 'PASS: Windows argument quoting, atomic state replacement, exclusive lock, 15-minute quota retry, false-positive protection, missing-result rejection.'
Write-Output "Test evidence: $runtime"
