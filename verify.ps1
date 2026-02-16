param(
  [string]$Flutter = "flutter",
  [switch]$SkipPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  Write-Host "`n==> $Name" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Name (exit code $LASTEXITCODE)"
  }
}

$flutterCmd = Get-Command $Flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
  throw "Flutter command not found: '$Flutter'"
}

if (-not $SkipPubGet) {
  Invoke-Step "flutter pub get" { & $Flutter pub get }
}

Invoke-Step "dart format --set-exit-if-changed ." { & dart format --set-exit-if-changed . }
Invoke-Step "flutter analyze" { & $Flutter analyze }
Invoke-Step "flutter test" { & $Flutter test }
Invoke-Step "flutter build web --release" { & $Flutter build web --release }

Write-Host "`nverify: OK" -ForegroundColor Green
