Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [string] $Tag = ''
)

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Args
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-PubspecVersion {
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

    $semver = ($raw -split '\+')[0].Trim()
    if ($semver -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version '$raw' is invalid. Expected 'version: X.Y.Z+N' in pubspec.yaml."
    }

    return @{
        Raw = $raw
        SemVer = $semver
    }
}

function Get-BuildId {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $candidates = @(
        (Join-Path $RepoRoot 'web\version.json'),
        (Join-Path $RepoRoot 'web\assets\version.json'),
        (Join-Path $RepoRoot 'assets\version.json')
    )

    foreach ($path in $candidates) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        try {
            $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $buildId = ''
            if ($null -ne $json -and $null -ne $json.buildId) {
                $buildId = $json.buildId.ToString().Trim()
            }
            if (-not [string]::IsNullOrWhiteSpace($buildId)) {
                return $buildId
            }
        } catch {
            continue
        }
    }

    return ''
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$versionInfo = Get-PubspecVersion -PubspecPath (Join-Path $repoRoot 'pubspec.yaml')
$versionRaw = $versionInfo.Raw
$semver = $versionInfo.SemVer
$buildId = Get-BuildId -RepoRoot $repoRoot

$tagName = if ([string]::IsNullOrWhiteSpace($Tag)) { "v$semver" } else { $Tag.Trim() }
if ($tagName -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Tag '$tagName' is invalid. Use format vX.Y.Z."
}

Write-Host "Repo root: $repoRoot"
Write-Host "pubspec version: $versionRaw"
Write-Host "detected buildId: " + ($(if ([string]::IsNullOrWhiteSpace($buildId)) { '(not found)' } else { $buildId }))
Write-Host "tag to create: $tagName"
Write-Host ""

& git rev-parse -q --verify "refs/tags/$tagName" *> $null
if ($LASTEXITCODE -eq 0) {
    throw "Tag '$tagName' already exists locally. Aborting."
}

$remoteTag = & git ls-remote --tags origin "refs/tags/$tagName"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to query remote tags for '$tagName' on origin."
}
if (-not [string]::IsNullOrWhiteSpace($remoteTag)) {
    throw "Tag '$tagName' already exists on origin. Aborting."
}

Invoke-Git -Args @('tag', '-a', $tagName, '-m', "BitFlow release $tagName")
Write-Host "Tag created: $tagName" -ForegroundColor Green

Invoke-Git -Args @('push', 'origin', $tagName)
Write-Host "Tag pushed: $tagName" -ForegroundColor Green
