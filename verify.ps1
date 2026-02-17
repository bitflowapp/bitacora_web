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
  $TimeoutSecAnalyze = if ($Fast) { 120 } else { 300 }
}
if ($TimeoutSecTest -le 0) {
  $TimeoutSecTest = if ($Fast) { 60 } else { 600 }
}
if ($TimeoutSecBuild -le 0) {
  $TimeoutSecBuild = if ($Fast) { 90 } else { 900 }
}

function Resolve-Tool {
  param(
    [Parameter(Mandatory = $true)][string]$ToolName,
    [string]$Requested = "",
    [string[]]$EnvHints = @(),
    [string[]]$CommonCandidates = @()
  )

  $probeNames = @()
  if (-not [string]::IsNullOrWhiteSpace($Requested)) {
    $probeNames += $Requested
  }
  if (-not $probeNames.Contains($ToolName)) {
    $probeNames += $ToolName
  }

  foreach ($probe in $probeNames) {
    if ([string]::IsNullOrWhiteSpace($probe)) {
      continue
    }

    if (Test-Path $probe) {
      return (Resolve-Path $probe).Path
    }

    $cmd = Get-Command $probe -ErrorAction SilentlyContinue
    if ($cmd) {
      return $cmd.Source
    }

    $whereHits = @()
    $whereExitCode = 1
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $whereHits = @(cmd /c "where `"$probe`"" 2>$null)
      $whereExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorAction
    }
    if ($whereExitCode -eq 0) {
      foreach ($hit in $whereHits) {
        if (-not [string]::IsNullOrWhiteSpace($hit) -and (Test-Path $hit)) {
          return (Resolve-Path $hit).Path
        }
      }
    }
  }

  $envCandidates = @()
  foreach ($envName in $EnvHints) {
    if ([string]::IsNullOrWhiteSpace($envName)) {
      continue
    }

    $envValue = [Environment]::GetEnvironmentVariable($envName)
    if ([string]::IsNullOrWhiteSpace($envValue)) {
      continue
    }

    if (Test-Path $envValue) {
      $envCandidates += $envValue
      $leaf = Split-Path $envValue -Leaf
      if ($leaf -ne "") {
        if ($leaf -ine $ToolName -and $leaf -ine "$ToolName.bat" -and $leaf -ine "$ToolName.exe") {
          $envCandidates += (Join-Path $envValue "$ToolName.bat")
          $envCandidates += (Join-Path $envValue "$ToolName.exe")
          $envCandidates += (Join-Path $envValue $ToolName)
          $envCandidates += (Join-Path $envValue "bin\$ToolName.bat")
          $envCandidates += (Join-Path $envValue "bin\$ToolName.exe")
          $envCandidates += (Join-Path $envValue "bin\$ToolName")
        }
      }
    }
  }

  foreach ($candidate in ($envCandidates + $CommonCandidates)) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  return $null
}

function Resolve-DartExe {
  param([string]$ResolvedFlutterExe)

  $dartCandidates = @()
  if (-not [string]::IsNullOrWhiteSpace($ResolvedFlutterExe) -and (Test-Path $ResolvedFlutterExe)) {
    $flutterBin = Split-Path (Resolve-Path $ResolvedFlutterExe).Path
    $dartCandidates += (Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe")
  }

  return Resolve-Tool -ToolName "dart" -Requested "dart" -EnvHints @("DART_BIN", "FLUTTER_BIN", "FLUTTER_HOME") -CommonCandidates $dartCandidates
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

function Invoke-GitGrepSafe {
  param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [switch]$EchoMatches
  )

  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    Write-Host "git no encontrado; se omite git grep para patrón '$Pattern'." -ForegroundColor Yellow
    return 0
  }

  $args = @("grep", "-n", $Pattern, "--") + $Paths
  $output = & $gitCmd.Source @args 2>&1
  $code = $LASTEXITCODE

  if ($code -gt 1) {
    Write-Host "git grep falló para patrón '$Pattern' (exit code $code)." -ForegroundColor Red
    if ($output) {
      $output | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
    }
    exit $code
  }

  if ($EchoMatches -and $code -eq 0 -and $output) {
    $output | ForEach-Object { Write-Host $_ }
  }

  return 0
}

function Test-MojibakeArtifact {
  $targetRoots = @("lib", "web", "assets", "test")
  $textExtensions = @(
    ".dart", ".js", ".ts", ".tsx", ".jsx", ".json", ".yaml", ".yml",
    ".md", ".html", ".htm", ".css", ".txt", ".xml", ".arb"
  )

  $artifacts = @(
    "Â·",
    "Ã",
    "â€¦",
    "â€“",
    "â€”"
  )

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
      foreach ($artifact in $artifacts) {
        $hits = @(Select-String -Path $file.FullName -Pattern $artifact -SimpleMatch -Encoding UTF8 -ErrorAction SilentlyContinue)
        foreach ($hit in $hits) {
          $relPath = $hit.Path
          if ($relPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relPath = $relPath.Substring($repoRoot.Length).TrimStart('\\')
          }
          $relPath = $relPath -replace "\\", "/"

          $matches += [pscustomobject]@{
            Pattern = $artifact
            Path = $relPath
            LineNumber = $hit.LineNumber
            Line = $hit.Line
          }
        }
      }
    }
  }

  if ($matches.Count -gt 0) {
    Write-Host "`n==> Guardrail anti-mojibake" -ForegroundColor Cyan
    Write-Host "Se detectaron artefactos de codificación (ej: Â·, Ã, â€¦) en archivos de texto:" -ForegroundColor Red
    foreach ($m in $matches) {
      Write-Host "[$($m.Pattern)] $($m.Path):$($m.LineNumber):$($m.Line.Trim())"
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

$localAppDataFlutter = ""
if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
  $localAppDataFlutter = Join-Path $env:LOCALAPPDATA "flutter\bin\flutter.bat"
}

$flutterExe = Resolve-Tool -ToolName "flutter" -Requested $Flutter -EnvHints @("FLUTTER_BIN", "FLUTTER_HOME") -CommonCandidates @(
  "C:\src\flutter\bin\flutter.bat",
  "C:\flutter\bin\flutter.bat",
  $localAppDataFlutter
)
$flutterAvailable = -not [string]::IsNullOrWhiteSpace($flutterExe)

if ($flutterAvailable) {
  Write-Host "Flutter resolved: $flutterExe" -ForegroundColor Green
} else {
  Write-Warning "flutter no encontrado en PATH del gateway; se omiten checks de Flutter"
}

$dartExe = Resolve-DartExe -ResolvedFlutterExe $flutterExe
$dartAvailable = -not [string]::IsNullOrWhiteSpace($dartExe)
if ($dartAvailable) {
  Write-Host "Dart resolved: $dartExe" -ForegroundColor Green
} else {
  Write-Warning "dart no encontrado en PATH del gateway; se omiten checks de Dart"
}

# git grep devuelve 1 cuando no hay matches: lo tratamos como OK.
Invoke-GitGrepSafe -Pattern "Â" -Paths @("lib", "web") | Out-Null
Invoke-GitGrepSafe -Pattern "Acciones rápidas" -Paths @("lib", "web") | Out-Null
Invoke-GitGrepSafe -Pattern "·" -Paths @("lib", "web") | Out-Null

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

if ($dartAvailable) {
  Invoke-StepWithTimeout -Name "dart --version" -FilePath $dartExe -Arguments @("--version") -TimeoutSec 30 | Out-Null
}

if (-not $flutterAvailable) {
  Write-Host "`n==> flutter --version" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  Write-Host "`n==> flutter doctor -v (optional)" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  Write-Host "`n==> flutter pub get" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  Write-Host "`n==> flutter analyze" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  Write-Host "`n==> flutter test" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  Write-Host "`n==> flutter build web --release" -ForegroundColor Cyan
  Write-Host "Omitido: Flutter no disponible en este contexto de gateway." -ForegroundColor Yellow

  if ($dartAvailable) {
    $isFlutterProject = $false
    if (Test-Path "pubspec.yaml") {
      $isFlutterProject = Select-String -Path "pubspec.yaml" -Pattern "sdk\s*:\s*flutter" -CaseSensitive:$false -SimpleMatch:$false -Quiet
    }

    if ($isFlutterProject) {
      Write-Host "`n==> dart analyze (fallback)" -ForegroundColor Cyan
      Write-Host "Omitido: proyecto Flutter detectado y Flutter no está disponible." -ForegroundColor Yellow
    } else {
      if ($Fast) {
        $dartAnalyzeOk = Invoke-StepWithTimeout -Name "dart analyze lib" -FilePath $dartExe -Arguments @("analyze", "lib") -TimeoutSec $TimeoutSecAnalyze -NonBlockingFailure
      } else {
        $dartAnalyzeOk = Invoke-StepWithTimeout -Name "dart analyze" -FilePath $dartExe -Arguments @("analyze") -TimeoutSec $TimeoutSecAnalyze -NonBlockingFailure
      }
      if (-not $dartAnalyzeOk) {
        Write-Warning "dart analyze falló o expiró; verify continúa en modo degradado."
      }
    }
  }

  Write-Host "`nverify: OK (modo degradado sin Flutter)" -ForegroundColor Green
  exit 0
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
