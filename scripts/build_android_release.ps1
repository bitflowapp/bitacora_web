Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $Command
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host "    $Command"
    & powershell -NoProfile -ExecutionPolicy Bypass -Command $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

function Read-AppVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PubspecPath
    )

    $line = Get-Content -LiteralPath $PubspecPath |
        Where-Object { $_ -match '^\s*version\s*:\s*' } |
        Select-Object -First 1
    if (-not $line) {
        throw "Could not read version from $PubspecPath"
    }

    $raw = ($line -replace '^\s*version\s*:\s*', '').Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Version value is empty in $PubspecPath"
    }
    return $raw
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

Invoke-Step -Name 'Flutter clean' -Command 'flutter clean'
Invoke-Step -Name 'Flutter pub get' -Command 'flutter pub get'
Invoke-Step -Name 'Flutter build apk --release' -Command 'flutter build apk --release'

$apkSource = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apkSource)) {
    throw "Release APK not found at $apkSource"
}

$versionRaw = Read-AppVersion -PubspecPath (Join-Path $repoRoot 'pubspec.yaml')
$versionSafe = ($versionRaw -replace '[^0-9A-Za-z._-]', '-')
$distDir = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$apkTarget = Join-Path $distDir "BitFlow-$versionSafe-android.apk"
Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force

Write-Host ""
Write-Host "APK generated:" -ForegroundColor Green
Write-Host $apkTarget -ForegroundColor Green
