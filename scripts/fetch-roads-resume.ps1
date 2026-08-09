# Fetch OSM roads + centrelines for every exported patch, resumably and politely.
#
# Driving is going to be a big part of the game, and right now Millstreet is the only patch with
# road data -- so it is the only place with hedgerows, a verge, or trees kept off the carriageway.
# Everywhere else has none of that because there are no roads to hang it on.
#
# Overpass is a donated service. This runs ONE query at a time with a pause between patches, caches
# every response so a re-run costs nothing, and backs off on 429/504 rather than retrying harder.
$ErrorActionPreference = "Continue"
$log = "C:\Games\possession\logs\roads_fetch.log"
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
Set-Location "C:\Games\possession\tools\dem"

"=== roads fetch $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8
$patches = Get-ChildItem "C:\Games\possession\game\mocks\dem\*.json" |
    Where-Object { $_.Name -notmatch "_sat\.json$" } |
    ForEach-Object { $_.BaseName } | Sort-Object

foreach ($n in $patches) {
    $out = "C:\Games\possession\game\mocks\dem\${n}_roadlines.dat"
    if (Test-Path $out) {
        "skip $n (already has centrelines)" | Tee-Object -FilePath $log -Append
        continue
    }
    "--- $n" | Tee-Object -FilePath $log -Append
    & python fetch_osm_roads.py $n 2>&1 |
        Select-String -Pattern "bbox matched|road ways|wrote|Overpass would not" |
        Tee-Object -FilePath $log -Append
    Start-Sleep -Seconds 20
}
"=== done $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8
