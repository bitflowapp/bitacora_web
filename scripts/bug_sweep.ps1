param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
  param([Parameter(Mandatory = $true)][string]$Title)
  Write-Host ""
  Write-Host "==> $Title" -ForegroundColor Cyan
}

function New-UnicodeString {
  param([Parameter(Mandatory = $true)][int[]]$CodePoints)
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Parse-GrepLine {
  param([Parameter(Mandatory = $true)][string]$Line)

  $parts = $Line -split ":", 3
  if ($parts.Length -ge 2) {
    return "$($parts[0]):$($parts[1])"
  }

  return $Line.Trim()
}

function Invoke-GitGrepSafe {
  param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [switch]$Regex,
    [switch]$CaseInsensitive
  )

  if ($Paths.Count -eq 0) {
    return @()
  }

  $args = @("grep", "-n")
  if ($Regex) {
    $args += "-E"
  } else {
    $args += "-F"
  }
  if ($CaseInsensitive) {
    $args += "-i"
  }

  $args += $Pattern
  $args += "--"
  $args += $Paths

  $raw = & $script:GitExe @args 2>&1
  $code = $LASTEXITCODE

  if ($code -eq 0) {
    return @($raw | Where-Object { $_ -is [string] -and $_.Trim().Length -gt 0 })
  }

  if ($code -eq 1) {
    # git grep no matches
    return @()
  }

  $dump = @($raw) -join "`n"
  throw "git grep failed (exit code $code) for pattern '$Pattern'.`n$dump"
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
  Write-Error "git is not available in PATH."
  exit 1
}
$script:GitExe = $gitCmd.Source

Write-Section "Repo snapshot"
& $script:GitExe status -sb
& $script:GitExe diff --stat

$searchPaths = @()
if (Test-Path "lib") {
  $searchPaths += "lib"
} else {
  Write-Warning "./lib does not exist. Skipping scans."
}

$findings = New-Object System.Collections.Generic.List[object]

if ($searchPaths.Count -gt 0) {
  Write-Section "Mojibake sweep"
  $mojibakeCodeSets = @(
    @(0x00C3),
    @(0x00C2),
    @(0x00E2, 0x20AC, 0x2026),
    @(0x00E2, 0x20AC, 0x2122),
    @(0x00E2, 0x20AC, 0x2013),
    @(0x00E2, 0x20AC, 0x2014)
  )

  foreach ($codeSet in $mojibakeCodeSets) {
    $pattern = New-UnicodeString -CodePoints $codeSet
    $hits = Invoke-GitGrepSafe -Pattern $pattern -Paths $searchPaths
    foreach ($hit in $hits) {
      $findings.Add([pscustomobject]@{
          Category = "mojibake"
          Pattern  = $pattern
          Location = (Parse-GrepLine -Line $hit)
        })
    }
  }

  Write-Section "English UI sweep"
  $englishTerms = @("Jump", "Maps", "Photos", "Quick actions", "Attachments")
  foreach ($term in $englishTerms) {
    $hits = Invoke-GitGrepSafe -Pattern $term -Paths $searchPaths -CaseInsensitive
    foreach ($hit in $hits) {
      $findings.Add([pscustomobject]@{
          Category = "english_ui"
          Pattern  = $term
          Location = (Parse-GrepLine -Line $hit)
        })
    }
  }
}

Write-Section "Summary"
if ($findings.Count -eq 0) {
  Write-Host "OK: no findings." -ForegroundColor Green
  exit 0
}

Write-Host "Findings: $($findings.Count)" -ForegroundColor Yellow
foreach ($item in $findings) {
  Write-Host "[$($item.Category)] [$($item.Pattern)] $($item.Location)"
}

exit 2
