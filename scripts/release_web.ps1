param(
  [string]$Flutter = "flutter"
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

function Run-Tool {
  param(
    [string]$Title,
    [string]$Exe,
    [string[]]$CommandArgs
  )

  Write-Host "\n==> $Title" -ForegroundColor Cyan
  Write-Host "$Exe $($CommandArgs -join ' ')" -ForegroundColor DarkGray
  & $Exe @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "$Title failed (exit $LASTEXITCODE)."
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
  if (-not (Get-Command $Flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no encontrado en PATH."
  }

  Run-Tool -Title "Flutter pub get" -Exe $Flutter -CommandArgs @("pub", "get")
  Run-Tool -Title "Flutter analyze (estricto)" -Exe $Flutter -CommandArgs @("analyze")
  Run-Tool -Title "Flutter test" -Exe $Flutter -CommandArgs @("test")
  Run-Tool -Title "Flutter build web --release" -Exe $Flutter -CommandArgs @("build", "web", "--release")

  $webOut = Join-Path $repoRoot "build\\web"
  if (-not (Test-Path $webOut)) {
    throw "No se encontró output en build/web."
  }

  $required = @("index.html", "flutter_bootstrap.js", "manifest.json")
  $missing = @()
  foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $webOut $f))) {
      $missing += $f
    }
  }
  if ($missing.Count -gt 0) {
    throw "Build incompleto. Faltan: $($missing -join ', ')"
  }

  Write-Host "\nRelease web listo." -ForegroundColor Green
  Write-Host "Output: $webOut"
  Write-Host "Checks: pub get, analyze, test, build web" -ForegroundColor Green
}
finally {
  Pop-Location
}
