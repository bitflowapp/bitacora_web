Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [string] $Tag = '',
    [switch] $NoPush,
    [switch] $SkipNotes
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

function Read-PubspecVersion {
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
    if ($semver -notmatch '^\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$') {
        throw "Version '$raw' does not include a valid semver prefix."
    }

    return @{
        Raw = $raw
        Semver = $semver
    }
}

function Read-BuildIdFromVersionJson {
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

function Write-ReleaseNotes {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [string] $TagName,
        [Parameter(Mandatory = $true)]
        [string] $VersionRaw,
        [Parameter(Mandatory = $true)]
        [string] $BuildId
    )

    $notesPath = Join-Path $RepoRoot 'docs\release_notes.md'
    $utcNow = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    $commit = (& git rev-parse --short HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "git rev-parse --short HEAD failed with exit code $LASTEXITCODE"
    }

    $lines = @(
        "# Release notes: $TagName",
        "",
        "- Date (UTC): $utcNow",
        "- Version (pubspec): $VersionRaw",
        "- BuildId (version.json): " + ($(if ([string]::IsNullOrWhiteSpace($BuildId)) { '(not found)' } else { $BuildId })),
        "- Commit: $commit",
        "",
        "## Checklist",
        "- Android Release workflow should publish BitFlow-android.apk to GitHub Releases.",
        "- Landing download button should resolve to releases/latest/download/BitFlow-android.apk.",
        "- Pages deployment should expose the updated version.json."
    )

    Set-Content -LiteralPath $notesPath -Value $lines -Encoding UTF8
    Write-Host "Release notes written to $notesPath" -ForegroundColor Green
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$versionInfo = Read-PubspecVersion -PubspecPath (Join-Path $repoRoot 'pubspec.yaml')
$versionRaw = $versionInfo.Raw
$semver = $versionInfo.Semver
$buildId = Read-BuildIdFromVersionJson -RepoRoot $repoRoot

$tagName = if ([string]::IsNullOrWhiteSpace($Tag)) { "v$semver" } else { $Tag.Trim() }
if ($tagName -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$') {
    throw "Tag '$tagName' is invalid. Use format vX.Y.Z (optionally with suffix)."
}

Write-Host "Repo root: $repoRoot"
Write-Host "pubspec version: $versionRaw"
Write-Host "detected buildId: " + ($(if ([string]::IsNullOrWhiteSpace($buildId)) { '(not found)' } else { $buildId }))
Write-Host "tag to create: $tagName"

Invoke-Git -Args @('fetch', '--tags', 'origin')

& git rev-parse -q --verify "refs/tags/$tagName" *> $null
if ($LASTEXITCODE -eq 0) {
    throw "Tag '$tagName' already exists locally."
}

$remoteTag = & git ls-remote --tags origin $tagName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to query remote tags for '$tagName'."
}
if (-not [string]::IsNullOrWhiteSpace($remoteTag)) {
    throw "Tag '$tagName' already exists on origin."
}

if (-not $SkipNotes) {
    Write-ReleaseNotes `
        -RepoRoot $repoRoot `
        -TagName $tagName `
        -VersionRaw $versionRaw `
        -BuildId $buildId
}

Invoke-Git -Args @('tag', '-a', $tagName, '-m', "BitFlow release $tagName")
Write-Host "Tag created: $tagName" -ForegroundColor Green

if ($NoPush) {
    Write-Host "NoPush set: skipped 'git push origin $tagName'." -ForegroundColor Yellow
} else {
    Invoke-Git -Args @('push', 'origin', $tagName)
    Write-Host "Tag pushed: $tagName" -ForegroundColor Green
}
