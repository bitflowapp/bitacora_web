Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title
    )
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Run-Diagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,
        [Parameter(Mandatory = $true)]
        [scriptblock] $Action
    )

    try {
        & $Action
    } catch {
        Write-Host "$Label failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Resolve-AndroidSdkPath {
    $sdkRoot = $env:ANDROID_SDK_ROOT
    $androidHome = $env:ANDROID_HOME

    if ($sdkRoot -and (Test-Path -LiteralPath $sdkRoot)) {
        return $sdkRoot
    }
    if ($androidHome -and (Test-Path -LiteralPath $androidHome)) {
        return $androidHome
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

Write-Section 'Repository'
Write-Host "Root: $repoRoot"

Write-Section 'Environment'
Write-Host "ANDROID_HOME=$($env:ANDROID_HOME)"
Write-Host "ANDROID_SDK_ROOT=$($env:ANDROID_SDK_ROOT)"

$sdkPath = Resolve-AndroidSdkPath
if ($null -eq $sdkPath) {
    Write-Host "Android SDK path not resolved from ANDROID_HOME/ANDROID_SDK_ROOT."
} else {
    Write-Host "Resolved SDK path: $sdkPath"
    $platformTools = Join-Path $sdkPath 'platform-tools'
    $adb = Join-Path $platformTools 'adb.exe'
    Write-Host "platform-tools: $platformTools (exists=$((Test-Path -LiteralPath $platformTools)))"
    Write-Host "adb.exe: $adb (exists=$((Test-Path -LiteralPath $adb)))"

    $sdkManager = Find-SdkManager -SdkPath $sdkPath
    if ($null -eq $sdkManager) {
        Write-Host "sdkmanager: NOT FOUND"
    } else {
        Write-Host "sdkmanager: $sdkManager"
    }
}

Write-Section 'Flutter Doctor'
Run-Diagnostic -Label 'flutter doctor -v' -Action { flutter doctor -v }

Write-Section 'Java Version'
Run-Diagnostic -Label 'java -version' -Action { & java -version }

Write-Section 'Gradle Version'
$gradleWrapper = Join-Path $repoRoot 'android\gradlew.bat'
if (Test-Path -LiteralPath $gradleWrapper) {
    Run-Diagnostic -Label 'gradlew -v' -Action { & $gradleWrapper -v }
} else {
    Run-Diagnostic -Label 'gradle -v' -Action { & gradle -v }
}

Write-Section 'Done'
Write-Host 'Android diagnostics completed.'
