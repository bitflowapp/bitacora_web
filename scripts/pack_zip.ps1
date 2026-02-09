param(
    [Parameter()]
    [string]$Source = 'C:\bitflow1122',

    [Parameter()]
    [ValidateSet('Clean', 'Full')]
    [string]$Mode = 'Clean',

    [Parameter()]
    [string]$OutDir = "$env:USERPROFILE\Desktop",

    [Parameter()]
    [switch]$OpenExplorer = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Resolve-ExistingDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $PathValue)) {
        Fail "$Label does not exist: $PathValue"
    }

    $item = Get-Item -LiteralPath $PathValue
    if (-not $item.PSIsContainer) {
        Fail "$Label must be a directory: $PathValue"
    }

    return [System.IO.Path]::GetFullPath($item.FullName)
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if (-not (Test-Path -LiteralPath $PathValue)) {
        New-Item -ItemType Directory -Path $PathValue -Force | Out-Null
    }

    $item = Get-Item -LiteralPath $PathValue
    if (-not $item.PSIsContainer) {
        Fail "OutDir must be a directory: $PathValue"
    }

    return [System.IO.Path]::GetFullPath($item.FullName)
}

function Get-NormalizedDirectoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $full = [System.IO.Path]::GetFullPath($PathValue).TrimEnd('\', '/')
    return "$full\"
}

function Test-IsSubPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,
        [Parameter(Mandatory = $true)]
        [string]$ParentPath
    )

    $candidate = Get-NormalizedDirectoryPath -PathValue $CandidatePath
    $parent = Get-NormalizedDirectoryPath -PathValue $ParentPath
    return $candidate.StartsWith($parent, [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-RobocopyToStage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,
        [Parameter(Mandatory = $true)]
        [string]$StageDir,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Clean', 'Full')]
        [string]$PackMode
    )

    $args = @(
        $SourceDir,
        $StageDir,
        '/E',
        '/XJ',
        '/R:1',
        '/W:1',
        '/NFL',
        '/NDL',
        '/NJH',
        '/NJS',
        '/NP'
    )

    if ($PackMode -eq 'Clean') {
        $excludedDirs = @(
            '.git',
            'node_modules',
            'build',
            'dist',
            '.dart_tool',
            '.gradle',
            '.idea',
            '.vscode',
            '.cache'
        ) | ForEach-Object {
            Join-Path $SourceDir $_
        }
        $args += '/XD'
        $args += $excludedDirs
    }

    & robocopy @args
    $roboExit = $LASTEXITCODE
    if ($roboExit -gt 7) {
        Fail "robocopy failed with exit code $roboExit."
    }
}

function New-ZipFromStage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StageDir,
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $sevenZipPath = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
    if (Test-Path -LiteralPath $sevenZipPath) {
        Push-Location $StageDir
        try {
            & $sevenZipPath a -tzip -mx=9 -y $ZipPath '.\*'
            if ($LASTEXITCODE -ne 0) {
                Fail "7-Zip failed with exit code $LASTEXITCODE."
            }
        }
        finally {
            Pop-Location
        }
        return
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $StageDir,
        $ZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}

$sourceDir = Resolve-ExistingDirectory -PathValue $Source -Label 'Source'
$outDirResolved = Ensure-Directory -PathValue $OutDir

if (Test-IsSubPath -CandidatePath $outDirResolved -ParentPath $sourceDir) {
    Fail "OutDir cannot be inside Source to avoid recursive packaging. Source=$sourceDir OutDir=$outDirResolved"
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$modeTag = $Mode.ToUpperInvariant()
$zipName = "bitflow1122_${modeTag}_${timestamp}.zip"
$zipPath = Join-Path $outDirResolved $zipName

if (Test-Path -LiteralPath $zipPath) {
    Fail "Output ZIP already exists: $zipPath"
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bitflow1122_pack_" + [System.Guid]::NewGuid().ToString('N'))
$stagePayload = Join-Path $stageRoot 'payload'

try {
    New-Item -ItemType Directory -Path $stagePayload -Force | Out-Null
    Invoke-RobocopyToStage -SourceDir $sourceDir -StageDir $stagePayload -PackMode $Mode
    New-ZipFromStage -StageDir $stagePayload -ZipPath $zipPath
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $zipPath)) {
    Fail "ZIP was not created: $zipPath"
}

$zipItem = Get-Item -LiteralPath $zipPath
$sizeMb = [Math]::Round($zipItem.Length / 1MB, 2)
$sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash

Write-Host ""
Write-Host "ZIP: $zipPath" -ForegroundColor Green
Write-Host "SizeMB: $sizeMb" -ForegroundColor Green
Write-Host "SHA256: $sha256" -ForegroundColor Green

if ($OpenExplorer) {
    Start-Process explorer.exe "/select,`"$zipPath`""
}
