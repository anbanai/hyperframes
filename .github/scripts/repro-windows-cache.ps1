# Throwaway repro: the CLI under a sandbox that refuses writes outside the project, stood in for by deny ACLs.
$ErrorActionPreference = "Continue"
$env:HYPERFRAMES_NO_TELEMETRY = "1"; $env:HYPERFRAMES_SKIP_SKILLS = "1"
$c = "C:\hfrepro"; New-Item -ItemType Directory -Force $c | Out-Null
npm install --prefix "$c\pub" hyperframes@0.9.15 --no-audit --no-fund 2>&1 | Select-Object -Last 1
$cli = "$c\pub\node_modules\hyperframes\bin\hyperframes.mjs"
$p = "$c\proj"; Set-Location $c
node $cli init $p --example blank --non-interactive --skip-skills 2>&1 | Select-Object -Last 1
$denied = @("$env:USERPROFILE\.cache\hyperframes", "$env:LOCALAPPDATA\hyperframes")
foreach ($d in $denied) {
  New-Item -ItemType Directory -Force $d | Out-Null
  icacls $d /deny "${env:USERNAME}:(OI)(CI)(W,AD,WD)" | Select-Object -Last 1
}
function Step($label, [string[]]$a) {
  $o = node $cli @a 2>&1 | Out-String
  $why = ($o -split "`n" | Where-Object { $_ -match "EPERM|EACCES|denied|Error|error|session|running|url|http" } | Select-Object -First 3) -join " | "
  Write-Output ("STEP {0,-34} exit={1} {2}" -f $label, $LASTEXITCODE, $why.Substring(0, [Math]::Min(600, $why.Length)))
}
Set-Location $p
Remove-Item Env:HYPERFRAMES_CACHE_DIR -ErrorAction SilentlyContinue
Step "render, default cache" @("render", "--output", "$c\a.mp4", "--quality", "draft")
$env:HYPERFRAMES_CACHE_DIR = "$p\.hfcache"
Step "render, cache in project" @("render", "--output", "$c\b.mp4", "--quality", "draft")
Step "preview --background, cache in proj" @("preview", "--background", "--json")
Step "preview --status" @("preview", "--status", "--json")
Step "preview --stop" @("preview", "--stop", "--json")
Write-Output ("FILES under the project cache: {0}" -f (Get-ChildItem -Recurse -File "$p\.hfcache" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "preview" }).Count)
$cli = "$env:GITHUB_WORKSPACE\packages\cli\bin\hyperframes.mjs"
Write-Output "== this branch (session follows HYPERFRAMES_CACHE_DIR)"
Step "branch preview --background" @("preview", "--background", "--json")
Step "branch preview --status" @("preview", "--status", "--json")
Step "branch preview --stop" @("preview", "--stop", "--json")
Write-Output ("FILES under the project cache: {0}" -f (Get-ChildItem -Recurse -File "$p\.hfcache" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "preview" }).Count)
