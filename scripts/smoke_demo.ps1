$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$logsDir = Join-Path $repoRoot 'logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

$analyzeLog = Join-Path $logsDir ("smoke_analyze_{0}.log" -f $ts)
flutter analyze *>&1 | Tee-Object -FilePath $analyzeLog
$analyzeExit = $LASTEXITCODE

$testLog = Join-Path $logsDir ("smoke_test_{0}.log" -f $ts)
flutter test --no-pub *>&1 | Tee-Object -FilePath $testLog
$testExit = $LASTEXITCODE

$buildLog = Join-Path $logsDir ("smoke_build_web_{0}.log" -f $ts)
flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false *>&1 | Tee-Object -FilePath $buildLog
$buildExit = $LASTEXITCODE

Write-Host ("flutter analyze EXITCODE={0} LOG={1}" -f $analyzeExit, $analyzeLog)
Write-Host ("flutter test --no-pub EXITCODE={0} LOG={1}" -f $testExit, $testLog)
Write-Host ("flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false EXITCODE={0} LOG={1}" -f $buildExit, $buildLog)

if ($analyzeExit -ne 0 -or $testExit -ne 0 -or $buildExit -ne 0) {
  exit 1
}

exit 0
