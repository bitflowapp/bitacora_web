param(
  [string]$Flutter = "flutter",
  [switch]$SkipPubGet,
  [switch]$SkipDoctor
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

function Resolve-FlutterExecutable {
  param([string]$Requested)

  if (-not [string]::IsNullOrWhiteSpace($Requested) -and $Requested -ne "flutter") {
    if (Test-Path $Requested) {
      return (Resolve-Path $Requested).Path
    }
  }

  $cmd = Get-Command $Requested -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  if ($Requested -ne "flutter") {
    $fallbackCmd = Get-Command "flutter" -ErrorAction SilentlyContinue
    if ($fallbackCmd) {
      return $fallbackCmd.Source
    }
  }

  $candidates = @()

  if ($env:FLUTTER_HOME) {
    $candidates += (Join-Path $env:FLUTTER_HOME "bin\flutter.bat")
  }
  if ($env:FLUTTER_ROOT) {
    $candidates += (Join-Path $env:FLUTTER_ROOT "bin\flutter.bat")
  }

  $candidates += @(
    "C:\src\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat",
    "D:\src\flutter\bin\flutter.bat",
    "D:\flutter\bin\flutter.bat",
    "E:\src\flutter\bin\flutter.bat",
    "E:\flutter\bin\flutter.bat"
  )

  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
      return (Resolve-Path $candidate).Path
    }
  }

  $userDirs = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
  foreach ($userDir in $userDirs) {
    $candidate = Join-Path $userDir.FullName "flutter\bin\flutter.bat"
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  return $null
}

$flutterExe = Resolve-FlutterExecutable -Requested $Flutter
if (-not $flutterExe) {
  Write-Host "Flutter command not found." -ForegroundColor Red
  Write-Host "Instalá Flutter o seteá FLUTTER_HOME/FLUTTER_ROOT apuntando al SDK." -ForegroundColor Yellow
  exit 1
}

Write-Host "Flutter resolved: $flutterExe" -ForegroundColor Green

Invoke-Step "flutter --version" { & $flutterExe --version }

if ($SkipDoctor) {
  Write-Host "`n==> flutter doctor -v (optional)" -ForegroundColor Cyan
  Write-Host "Skipped by flag -SkipDoctor" -ForegroundColor Yellow
} else {
  try {
    Invoke-Step "flutter doctor -v (optional)" { & $flutterExe doctor -v }
  } catch {
    Write-Warning "flutter doctor -v failed or timed out. Continuing with verify steps."
  }
}

if (-not $SkipPubGet) {
  Invoke-Step "flutter pub get" { & $flutterExe pub get }
}

Invoke-Step "flutter analyze --no-pub lib test" { & $flutterExe analyze --no-pub lib test }

$testFiles = @()
if (Test-Path "test") {
  $testFiles = Get-ChildItem -Path "test" -Recurse -File -Filter "*_test.dart" -ErrorAction SilentlyContinue
}

if ($testFiles.Count -eq 0) {
  Write-Host "`n==> flutter test" -ForegroundColor Cyan
  Write-Host "No tests detected (no *_test.dart under ./test)." -ForegroundColor Yellow
} else {
  Invoke-Step "flutter test" { & $flutterExe test }
}

Invoke-Step "flutter build web --release" { & $flutterExe build web --release }

Write-Host "`nverify: OK" -ForegroundColor Green
