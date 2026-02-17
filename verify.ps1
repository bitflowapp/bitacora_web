param(
  [string]$Flutter = "flutter",
  [switch]$Fast,
  [switch]$SkipDoctor,
  [switch]$SkipAnalyze,
  [switch]$SkipTest,
  [switch]$SkipBuild,
  [int]$TimeoutSecAnalyze = 0,
  [int]$TimeoutSecTest = 0,
  [int]$TimeoutSecBuild = 0,
  [int]$TimeoutSecPubGet = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($TimeoutSecAnalyze -le 0) {
  $TimeoutSecAnalyze = if ($Fast) { 45 } else { 300 }
}
if ($TimeoutSecTest -le 0) {
  $TimeoutSecTest = if ($Fast) { 60 } else { 600 }
}
if ($TimeoutSecBuild -le 0) {
  $TimeoutSecBuild = if ($Fast) { 90 } else { 900 }
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

function Stop-ProcessTree {
  param([int]$ProcessId)

  try {
    cmd /c "taskkill /PID $ProcessId /T /F >nul 2>nul" | Out-Null
  } catch {
    try {
      Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    } catch {}
  }
}

function Test-MojibakeArtifact {
  $targetRoots = @("lib", "web", "assets", "test")
  $textExtensions = @(
    ".dart", ".js", ".ts", ".tsx", ".jsx", ".json", ".yaml", ".yml",
    ".md", ".html", ".htm", ".css", ".txt", ".xml", ".arb"
  )

  # Archivos con mojibake legado preexistente fuera del scope de este fix.
  $allowList = @("lib/main.dart", "lib/start_page.dart")
  $allowList = $allowList | ForEach-Object { $_.ToLowerInvariant() }

  $artifact = [string][char]0x00C2
  $repoRoot = (Get-Location).Path
  $matches = @()

  foreach ($root in $targetRoots) {
    if (-not (Test-Path $root)) {
      continue
    }

    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $_.FullName -notmatch "\\build\\|\\.dart_tool\\|\\.git\\" -and
        $textExtensions -contains $_.Extension.ToLowerInvariant()
      }

    foreach ($file in $files) {
      $hits = @(Select-String -Path $file.FullName -Pattern $artifact -SimpleMatch -Encoding UTF8 -ErrorAction SilentlyContinue)
      foreach ($hit in $hits) {
        $relPath = $hit.Path
        if ($relPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
          $relPath = $relPath.Substring($repoRoot.Length).TrimStart('\\')
        }
        $relPath = $relPath -replace "\\", "/"
        if ($allowList -contains $relPath.ToLowerInvariant()) {
          continue
        }
        $matches += [pscustomobject]@{
          Path = $relPath
          LineNumber = $hit.LineNumber
          Line = $hit.Line
        }
      }
    }
  }

  if ($matches.Count -gt 0) {
    Write-Host "`n==> Guardrail anti-mojibake" -ForegroundColor Cyan
    Write-Host "Se detectó el artefacto 'Â' en archivos de texto:" -ForegroundColor Red
    foreach ($m in $matches) {
      Write-Host "$($m.Path):$($m.LineNumber):$($m.Line.Trim())"
    }
    exit 2
  }
}

function Test-EnglishUiLabels {
  $targetRoots = @("lib", "web", "assets", "test")
  $textExtensions = @(
    ".dart", ".js", ".ts", ".tsx", ".jsx", ".json", ".yaml", ".yml",
    ".md", ".html", ".htm", ".css", ".txt", ".xml", ".arb"
  )

  $patterns = @("Jump", "Maps", "Photos", "Sheet", "Quick actions", "Delete", "Save")
  $labelRegex = '["''][^"'']*\b(Jump|Maps|Photos|Sheet|Quick actions|Delete|Save)\b[^"'']*["'']'

  $repoRoot = (Get-Location).Path
  $englishHits = @()

  foreach ($root in $targetRoots) {
    if (-not (Test-Path $root)) {
      continue
    }

    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $_.FullName -notmatch "\\build\\|\\.dart_tool\\|\\.git\\" -and
        $textExtensions -contains $_.Extension.ToLowerInvariant()
      }

    foreach ($file in $files) {
      $hits = @(Select-String -Path $file.FullName -Pattern $patterns -SimpleMatch -CaseSensitive -Encoding UTF8 -ErrorAction SilentlyContinue)
      foreach ($hit in $hits) {
        $line = $hit.Line
        if ($line.TrimStart().StartsWith("//")) {
          continue
        }
        if ($line -cnotmatch $labelRegex) {
          continue
        }

        $relPath = $hit.Path
        if ($relPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
          $relPath = $relPath.Substring($repoRoot.Length).TrimStart('\\')
        }
        $relPath = $relPath -replace "\\", "/"

        $englishHits += [pscustomobject]@{
          Path = $relPath
          LineNumber = $hit.LineNumber
          Line = $line
        }
      }
    }
  }

  if ($englishHits.Count -gt 0) {
    Write-Host "`n==> Guardrail anti-inglés en UI" -ForegroundColor Cyan
    Write-Host "Se detectaron etiquetas en inglés (Jump/Maps/Photos/Sheet/Quick actions/Delete/Save):" -ForegroundColor Red
    foreach ($m in $englishHits) {
      Write-Host "$($m.Path):$($m.LineNumber):$($m.Line.Trim())"
    }
    exit 3
  }
}

function Invoke-StepWithTimeout {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][int]$TimeoutSec,
    [switch]$NonBlockingFailure
  )

  Write-Host "`n==> $Name (timeout ${TimeoutSec}s)" -ForegroundColor Cyan

  $logId = [guid]::NewGuid().ToString("N")
  $stdoutPath = Join-Path $env:TEMP "verify_${logId}.stdout.log"
  $stderrPath = Join-Path $env:TEMP "verify_${logId}.stderr.log"

  $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

  $timedOut = $false
  try {
    Wait-Process -Id $proc.Id -Timeout $TimeoutSec -ErrorAction Stop
  } catch {
    $timedOut = $true
  }

  if ($timedOut) {
    Stop-ProcessTree -ProcessId $proc.Id
  }

  $stdout = @()
  if (Test-Path $stdoutPath) {
    $stdout = @(Get-Content -Path $stdoutPath -ErrorAction SilentlyContinue)
  }
  $stderr = @()
  if (Test-Path $stderrPath) {
    $stderr = @(Get-Content -Path $stderrPath -ErrorAction SilentlyContinue)
  }

  if ($stdout.Count -gt 0) {
    $stdout | ForEach-Object { Write-Host $_ }
  }
  if ($stderr.Count -gt 0) {
    $stderr | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
  }

  Remove-Item -Path $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

  if ($timedOut) {
    Write-Host "TIMEOUT en $Name (>${TimeoutSec}s)." -ForegroundColor Red
    if ($NonBlockingFailure) {
      return $false
    }
    exit 124
  }

  $proc.Refresh()
  $exitCode = $proc.ExitCode
  if ($null -eq $exitCode) {
    $exitCode = 0
  }

  if ($exitCode -ne 0) {
    Write-Host "FALLO en $Name (exit code $exitCode)." -ForegroundColor Red
    if ($NonBlockingFailure) {
      return $false
    }
    exit $exitCode
  }

  return $true
}

$flutterExe = Resolve-FlutterExecutable -Requested $Flutter
if (-not $flutterExe) {
  Write-Host "Flutter command not found." -ForegroundColor Red
  Write-Host "Instalá Flutter o seteá FLUTTER_HOME/FLUTTER_ROOT apuntando al SDK." -ForegroundColor Yellow
  exit 1
}

Write-Host "Flutter resolved: $flutterExe" -ForegroundColor Green

Test-MojibakeArtifact
Test-EnglishUiLabels

$effectiveSkipTest = [bool]$SkipTest
$effectiveSkipBuild = [bool]$SkipBuild

if ($Fast) {
  if (-not $SkipTest) {
    $effectiveSkipTest = $true
  }
  if (-not $SkipBuild) {
    $effectiveSkipBuild = $true
  }
}

Invoke-StepWithTimeout -Name "flutter --version" -FilePath $flutterExe -Arguments @("--version") -TimeoutSec 30 | Out-Null

if ($SkipDoctor) {
  Write-Host "`n==> flutter doctor -v (optional)" -ForegroundColor Cyan
  Write-Host "Skipped by flag -SkipDoctor" -ForegroundColor Yellow
} else {
  $doctorOk = Invoke-StepWithTimeout -Name "flutter doctor -v (optional)" -FilePath $flutterExe -Arguments @("doctor", "-v") -TimeoutSec 180 -NonBlockingFailure
  if (-not $doctorOk) {
    Write-Warning "flutter doctor -v failed or timed out. Continuing with verify steps."
  }
}

Invoke-StepWithTimeout -Name "flutter pub get" -FilePath $flutterExe -Arguments @("pub", "get") -TimeoutSec $TimeoutSecPubGet | Out-Null

if ($SkipAnalyze) {
  Write-Host "`n==> flutter analyze" -ForegroundColor Cyan
  Write-Host "Skipped by flag -SkipAnalyze" -ForegroundColor Yellow
} else {
  if ($Fast) {
    Invoke-StepWithTimeout -Name "flutter analyze --no-pub lib" -FilePath $flutterExe -Arguments @("analyze", "--no-pub", "lib") -TimeoutSec $TimeoutSecAnalyze | Out-Null
  } else {
    Invoke-StepWithTimeout -Name "flutter analyze --no-pub lib test" -FilePath $flutterExe -Arguments @("analyze", "--no-pub", "lib", "test") -TimeoutSec $TimeoutSecAnalyze | Out-Null
  }
}

if ($effectiveSkipTest) {
  Write-Host "`n==> flutter test" -ForegroundColor Cyan
  if ($Fast -and -not $SkipTest) {
    Write-Host "Skipped in -Fast mode (default)." -ForegroundColor Yellow
  } else {
    Write-Host "Skipped by flag -SkipTest" -ForegroundColor Yellow
  }
} else {
  $testFiles = @()
  if (Test-Path "test") {
    $testFiles = Get-ChildItem -Path "test" -Recurse -File -Filter "*_test.dart" -ErrorAction SilentlyContinue
  }

  if ($testFiles.Count -eq 0) {
    Write-Host "`n==> flutter test" -ForegroundColor Cyan
    Write-Host "No tests detected (no *_test.dart under ./test)." -ForegroundColor Yellow
  } else {
    Invoke-StepWithTimeout -Name "flutter test" -FilePath $flutterExe -Arguments @("test") -TimeoutSec $TimeoutSecTest | Out-Null
  }
}

if ($effectiveSkipBuild) {
  Write-Host "`n==> flutter build web --release" -ForegroundColor Cyan
  if ($Fast -and -not $SkipBuild) {
    Write-Host "Skipped in -Fast mode (default)." -ForegroundColor Yellow
  } else {
    Write-Host "Skipped by flag -SkipBuild" -ForegroundColor Yellow
  }
} else {
  Invoke-StepWithTimeout -Name "flutter build web --release" -FilePath $flutterExe -Arguments @("build", "web", "--release") -TimeoutSec $TimeoutSecBuild | Out-Null
}

Write-Host "`nverify: OK" -ForegroundColor Green
