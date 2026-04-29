param(
  [switch]$SummaryOnly,
  [ValidateRange(1, 1000000)][int]$MaxFindings = 200,
  [string]$ReportPath = "logs/bug_sweep_report.json",
  [bool]$IncludeEnglishScan = $true,
  [bool]$IncludeMojibakeScan = $true
)

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
  if ($parts.Length -ge 3) {
    return [pscustomobject]@{
      File    = $parts[0]
      Line    = $parts[1]
      Snippet = $parts[2]
      Location = "$($parts[0]):$($parts[1])"
    }
  }

  if ($parts.Length -eq 2) {
    return [pscustomobject]@{
      File    = $parts[0]
      Line    = $parts[1]
      Snippet = ""
      Location = "$($parts[0]):$($parts[1])"
    }
  }

  return [pscustomobject]@{
    File    = $Line.Trim()
    Line    = ""
    Snippet = ""
    Location = $Line.Trim()
  }
}

function Sanitize-Text {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  $chars = $Value.ToCharArray()
  $builder = New-Object System.Text.StringBuilder

  for ($i = 0; $i -lt $chars.Length; $i++) {
    $ch = $chars[$i]
    if ([char]::IsHighSurrogate($ch)) {
      if (($i + 1) -lt $chars.Length -and [char]::IsLowSurrogate($chars[$i + 1])) {
        [void]$builder.Append($ch)
        [void]$builder.Append($chars[$i + 1])
        $i++
      }
      continue
    }

    if ([char]::IsLowSurrogate($ch)) {
      continue
    }

    [void]$builder.Append($ch)
  }

  return $builder.ToString()
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
  if ($IncludeMojibakeScan) {
    Write-Section "Mojibake sweep"
    $mojibakePatterns = @(
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00C3)); Pattern = (New-UnicodeString -CodePoints @(0x00C3)) },
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00C2)); Pattern = (New-UnicodeString -CodePoints @(0x00C2)) },
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2026)); Pattern = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2026)) },
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2122)); Pattern = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2122)) },
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2013)); Pattern = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2013)) },
      [pscustomobject]@{ Label = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2014)); Pattern = (New-UnicodeString -CodePoints @(0x00E2, 0x20AC, 0x2014)) }
    )

    foreach ($entry in $mojibakePatterns) {
      $hits = Invoke-GitGrepSafe -Pattern $entry.Pattern -Paths $searchPaths
      foreach ($hit in $hits) {
        $parsed = Parse-GrepLine -Line $hit
      $findings.Add([pscustomobject]@{
          Category = "mojibake"
          Pattern  = $entry.Label
          File     = $parsed.File
          Line     = $parsed.Line
          Location = $parsed.Location
          Snippet  = (Sanitize-Text -Value $parsed.Snippet)
        })
      }
    }
  } else {
    Write-Host "Mojibake scan skipped (-IncludeMojibakeScan:`$false)." -ForegroundColor DarkYellow
  }

  if ($IncludeEnglishScan) {
    Write-Section "English UI sweep"
    $englishTerms = @("Jump", "Maps", "Photos", "Quick actions", "Attachments")
    foreach ($term in $englishTerms) {
      $hits = Invoke-GitGrepSafe -Pattern $term -Paths $searchPaths -CaseInsensitive
      foreach ($hit in $hits) {
        $parsed = Parse-GrepLine -Line $hit
      $findings.Add([pscustomobject]@{
          Category = "english_ui"
          Pattern  = $term
          File     = $parsed.File
          Line     = $parsed.Line
          Location = $parsed.Location
          Snippet  = (Sanitize-Text -Value $parsed.Snippet)
        })
      }
    }
  } else {
    Write-Host "English scan skipped (-IncludeEnglishScan:`$false)." -ForegroundColor DarkYellow
  }
}

$mojibakeCount = @($findings | Where-Object { $_.Category -eq "mojibake" }).Count
$englishCount = @($findings | Where-Object { $_.Category -eq "english_ui" }).Count
$totalCount = $findings.Count

$patternGroups = @($findings | Group-Object -Property Pattern | Sort-Object Count -Descending)
$fileGroups = @($findings | Group-Object -Property File | Sort-Object Count -Descending)

$topFiles = @(
  $fileGroups | Select-Object -First 20 | ForEach-Object {
    [pscustomobject]@{ file = $_.Name; count = $_.Count }
  }
)

$sampleFindings = @(
  $findings | Select-Object -First ([Math]::Min(50, $totalCount)) | ForEach-Object {
    [pscustomobject]@{
      pattern = $_.Pattern
      file = $_.File
      line = $_.Line
      textSnippet = $_.Snippet
    }
  }
)

$byPattern = [ordered]@{}
foreach ($group in $patternGroups) {
  $byPattern[$group.Name] = $group.Count
}

$reportObject = [pscustomobject]@{
  timestamp = (Get-Date).ToString("o")
  totals = [pscustomobject]@{
    mojibake_count = $mojibakeCount
    english_count = $englishCount
    total = $totalCount
  }
  byPattern = $byPattern
  topFiles = $topFiles
  sampleFindings = $sampleFindings
}

$reportDirectory = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path $reportDirectory)) {
  New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null
}

$reportJson = $reportObject | ConvertTo-Json -Depth 6
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReportPath, $reportJson, $utf8NoBom)

Write-Section "Summary"
Write-Host ("Totals -> mojibake: {0}, english: {1}, total: {2}" -f $mojibakeCount, $englishCount, $totalCount)
Write-Host "Report saved to: $ReportPath"

Write-Host ""
Write-Host "TOP patterns by count"
if ($patternGroups.Count -eq 0) {
  Write-Host "- none"
} else {
  foreach ($group in $patternGroups) {
    Write-Host ("- {0}: {1}" -f $group.Name, $group.Count)
  }
}

if (-not $SummaryOnly) {
  Write-Host ""
  Write-Host "TOP 20 files by findings"
  if ($fileGroups.Count -eq 0) {
    Write-Host "- none"
  } else {
    foreach ($group in ($fileGroups | Select-Object -First 20)) {
      Write-Host ("- {0}: {1}" -f $group.Name, $group.Count)
    }
  }

  if ($totalCount -gt 0) {
    Write-Host ""
    $toPrint = [Math]::Min($MaxFindings, $totalCount)
    Write-Host "Printing findings: $toPrint/$totalCount"
    foreach ($item in ($findings | Select-Object -First $toPrint)) {
      Write-Host ("[{0}] [{1}] {2}" -f $item.Category, $item.Pattern, $item.Location)
    }
    if ($totalCount -gt $toPrint) {
      Write-Host ("... output truncated. Use -MaxFindings to change limit.") -ForegroundColor DarkYellow
    }
  }
}

if ($totalCount -eq 0) {
  Write-Host "OK: no findings." -ForegroundColor Green
  exit 0
}

exit 2
