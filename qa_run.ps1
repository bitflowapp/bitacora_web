param(
  [string]$Flutter = "flutter",
  [int]$Port = 8787
)

$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportPath = Join-Path $scriptDir "QA_REPORT.md"

function Get-GitInfo {
  $branch = ""
  $commit = ""
  try { $branch = (git rev-parse --abbrev-ref HEAD) 2>$null } catch {}
  try { $commit = (git rev-parse HEAD) 2>$null } catch {}
  return @{ branch = $branch.Trim(); commit = $commit.Trim() }
}

function Append-Report([string[]]$lines) {
  if (-not (Test-Path $reportPath)) {
    New-Item -ItemType File -Path $reportPath | Out-Null
  }
  Add-Content -Path $reportPath -Value ($lines -join "`n")
}

function Run-Step([string]$label, [scriptblock]$block) {
  $status = "PASS"
  try {
    & $block
    $code = $LASTEXITCODE
    if ($code -ne 0) { $status = "FAIL" }
  } catch {
    $status = "FAIL"
  }
  $script:stepLines += "- ${label}: $status"
  return ($status -eq "PASS")
}

$info = Get-GitInfo
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$header = @(
  "",
  "## QA Run: $now",
  "Branch: $($info.branch)",
  "Commit: $($info.commit)",
  ""
)

$stepLines = @()

$flutterCmd = Get-Command $Flutter -ErrorAction SilentlyContinue
$dartCmd = Get-Command dart -ErrorAction SilentlyContinue
$dartExe = $null
if ($dartCmd) {
  $dartExe = $dartCmd.Source
} elseif ($flutterCmd) {
  $flutterBin = Split-Path -Parent $flutterCmd.Source
  $candidate = Join-Path $flutterBin "dart.bat"
  if (Test-Path $candidate) {
    $dartExe = $candidate
  }
}
if (-not $flutterCmd -or -not $dartExe) {
  $stepLines += "- Toolchain: FAIL (Flutter/Dart no instalado)"
  $stepLines += "- Recomendado: instalar en C:\\tools\\flutter y agregar C:\\tools\\flutter\\bin al PATH"
  Append-Report ($header + $stepLines)
  Write-Host "Flutter/Dart no instalado. QA detenida." -ForegroundColor Red
  exit 1
}

$allOk = $true
$allOk = (Run-Step "flutter --version" { & $Flutter --version }) -and $allOk
$allOk = (Run-Step "flutter doctor -v" { & $Flutter doctor -v }) -and $allOk
$allOk = (Run-Step "flutter pub get" { & $Flutter pub get }) -and $allOk
$allOk = (Run-Step "dart format ." { & $dartExe format . }) -and $allOk
$allOk = (Run-Step "flutter analyze" { & $Flutter analyze }) -and $allOk
$allOk = (Run-Step "flutter test" { & $Flutter test }) -and $allOk
$allOk = (Run-Step "flutter build web --release" { & $Flutter build web --release }) -and $allOk
$allOk = (Run-Step "release.ps1 -Clean" { & (Join-Path $scriptDir "release.ps1") -Clean }) -and $allOk

$zipLine = "- Release ZIP: NOT FOUND"
$smokeLine = "- Smoke test HTTP: SKIPPED"

if ($allOk) {
  $zip = Get-ChildItem -Path $scriptDir -Filter "bitacora_web_RELEASE_*.zip" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($zip) {
    $zipLine = "- Release ZIP: $($zip.FullName)"

    $temp = Join-Path $env:TEMP ("bitacora_release_smoke_" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $temp | Out-Null
    Expand-Archive -Path $zip.FullName -DestinationPath $temp -Force

    $runPath = Join-Path $temp "run.ps1"
    if (Test-Path $runPath) {
      $proc = Start-Process powershell -PassThru -ArgumentList "-ExecutionPolicy Bypass -File `"$runPath`" -Port $Port -NoBrowser"
      Start-Sleep -Seconds 2
      try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$Port/" -TimeoutSec 10
        if ($resp.StatusCode -eq 200) {
          $smokeLine = "- Smoke test HTTP: PASS ($($resp.StatusCode))"
        } else {
          $smokeLine = "- Smoke test HTTP: FAIL ($($resp.StatusCode))"
        }
      } catch {
        $smokeLine = "- Smoke test HTTP: FAIL (no response)"
      } finally {
        try { Stop-Process -Id $proc.Id -Force } catch {}
      }
    } else {
      $smokeLine = "- Smoke test HTTP: FAIL (run.ps1 no encontrado en ZIP)"
    }
  }
}

Append-Report ($header + $stepLines + @("", $zipLine, $smokeLine, ""))

if (-not $allOk) { exit 1 }
