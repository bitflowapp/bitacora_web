Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Run-Step {
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
        Fail "$Name failed with exit code $LASTEXITCODE."
    }
}

function Resolve-AndroidSdkPath {
    if ($env:ANDROID_SDK_ROOT -and (Test-Path -LiteralPath $env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }
    if ($env:ANDROID_HOME -and (Test-Path -LiteralPath $env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    return $null
}

function Find-SdkManager {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SdkPath
    )

    $candidates = @(
        (Join-Path $SdkPath 'cmdline-tools\latest\bin\sdkmanager.bat'),
        (Join-Path $SdkPath 'cmdline-tools\bin\sdkmanager.bat'),
        (Join-Path $SdkPath 'tools\bin\sdkmanager.bat')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

Write-Host "Repository root: $repoRoot"

$sdkPath = Resolve-AndroidSdkPath
if ($null -eq $sdkPath) {
    Fail "ANDROID_HOME or ANDROID_SDK_ROOT must point to a valid Android SDK folder."
}

$platformTools = Join-Path $sdkPath 'platform-tools'
$adb = Join-Path $platformTools 'adb.exe'
if (-not (Test-Path -LiteralPath $platformTools)) {
    Fail "Missing Android SDK platform-tools folder: $platformTools"
}
if (-not (Test-Path -LiteralPath $adb)) {
    Fail "Missing adb executable: $adb"
}

$sdkManager = Find-SdkManager -SdkPath $sdkPath
if ($null -eq $sdkManager) {
    Fail "sdkmanager.bat not found under $sdkPath (expected cmdline-tools or tools bin)."
}

$keyProperties = Join-Path $repoRoot 'android\key.properties'
if (-not (Test-Path -LiteralPath $keyProperties)) {
    Fail "Missing android/key.properties. Copy android/key.properties.example and fill real values."
}

Write-Host "Android SDK: $sdkPath"
Write-Host "sdkmanager: $sdkManager"
Write-Host "key.properties: $keyProperties"

Run-Step -Name 'Flutter clean' -Command 'flutter clean'
Run-Step -Name 'Flutter pub get' -Command 'flutter pub get'
Run-Step -Name 'Flutter test' -Command 'flutter test'

Run-Step -Name "Flutter analyze (error filter)" -Command '$out = flutter analyze 2>&1; $matches = $out | Select-String " error - "; if ($matches) { $matches; exit 1 }'
Run-Step -Name 'Flutter analyze (no fatal warnings/infos)' -Command 'flutter analyze --no-fatal-warnings --no-fatal-infos'
Run-Step -Name 'Build Android appbundle (release)' -Command 'flutter build appbundle --release'

$aab = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path -LiteralPath $aab)) {
    Fail "Build finished but AAB not found at expected path: $aab"
}

Write-Host ""
Write-Host "Release build completed successfully." -ForegroundColor Green
Write-Host "AAB: $aab" -ForegroundColor Green
