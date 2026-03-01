param(
  [string]$Flutter = "flutter",
  [string]$BaseHref = "",
  [string]$ProCtaUrl = "",
  [string]$SupportEmail = "",
  [string]$SupportWhatsApp = ""
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

function Resolve-DefineValue {
  param(
    [string]$ExplicitValue,
    [string]$EnvName,
    [string]$LegacyEnvName = ""
  )

  $value = $ExplicitValue.Trim()
  if ($value) { return $value }

  $envValue = [Environment]::GetEnvironmentVariable($EnvName)
  if ($envValue) {
    $envValue = $envValue.Trim()
    if ($envValue) { return $envValue }
  }

  if ($LegacyEnvName) {
    $legacyValue = [Environment]::GetEnvironmentVariable($LegacyEnvName)
    if ($legacyValue) {
      $legacyValue = $legacyValue.Trim()
      if ($legacyValue) { return $legacyValue }
    }
  }

  return ""
}

function Normalize-BaseHref {
  param([string]$Value)

  $trimmed = $Value.Trim()
  if (-not $trimmed) { return "/" }
  if ($trimmed -eq "/") { return "/" }

  if (-not $trimmed.StartsWith("/")) {
    $trimmed = "/$trimmed"
  }
  if (-not $trimmed.EndsWith("/")) {
    $trimmed = "$trimmed/"
  }

  return $trimmed
}

function Resolve-BaseHref {
  param([string]$RequestedBaseHref)

  $requested = $RequestedBaseHref.Trim()
  if ($requested) {
    return (Normalize-BaseHref -Value $requested)
  }

  try {
    $remote = (git remote get-url origin).Trim()
  }
  catch {
    return "/"
  }

  if (-not $remote) { return "/" }

  $repoName = ""
  if ($remote -match "github\.com[:/][^/]+/([^/]+?)(?:\.git)?$") {
    $repoName = $Matches[1]
  }
  if (-not $repoName) { return "/" }

  if ($repoName.ToLowerInvariant().EndsWith(".github.io")) {
    return "/"
  }

  return "/$repoName/"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
  if (-not (Get-Command $Flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no encontrado en PATH."
  }

  $resolvedBaseHref = Resolve-BaseHref -RequestedBaseHref $BaseHref
  $resolvedProCtaUrl = Resolve-DefineValue -ExplicitValue $ProCtaUrl -EnvName "PRO_CTA_URL" -LegacyEnvName "BITFLOW_PRO_CTA_URL"
  $resolvedSupportEmail = Resolve-DefineValue -ExplicitValue $SupportEmail -EnvName "SUPPORT_EMAIL"
  $resolvedSupportWhatsApp = Resolve-DefineValue -ExplicitValue $SupportWhatsApp -EnvName "SUPPORT_WHATSAPP"

  $buildArgs = @("build", "web", "--release", "--base-href", $resolvedBaseHref)
  if ($resolvedProCtaUrl) {
    $buildArgs += "--dart-define=PRO_CTA_URL=$resolvedProCtaUrl"
  }
  if ($resolvedSupportEmail) {
    $buildArgs += "--dart-define=SUPPORT_EMAIL=$resolvedSupportEmail"
  }
  if ($resolvedSupportWhatsApp) {
    $buildArgs += "--dart-define=SUPPORT_WHATSAPP=$resolvedSupportWhatsApp"
  }

  Run-Tool -Title "Flutter pub get" -Exe $Flutter -CommandArgs @("pub", "get")
  Run-Tool -Title "Flutter analyze (estricto)" -Exe $Flutter -CommandArgs @("analyze")
  Run-Tool -Title "Flutter test" -Exe $Flutter -CommandArgs @("test")
  Run-Tool -Title "Flutter build web --release" -Exe $Flutter -CommandArgs $buildArgs

  $webOut = Join-Path $repoRoot "build\\web"
  if (-not (Test-Path $webOut)) {
    throw "No se encontro output en build/web."
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
  Write-Host "Base href: $resolvedBaseHref"
  if ($resolvedProCtaUrl) { Write-Host "Define PRO_CTA_URL: configured" -ForegroundColor Green }
  if ($resolvedSupportEmail) { Write-Host "Define SUPPORT_EMAIL: configured" -ForegroundColor Green }
  if ($resolvedSupportWhatsApp) { Write-Host "Define SUPPORT_WHATSAPP: configured" -ForegroundColor Green }
  Write-Host "Checks: pub get, analyze, test, build web" -ForegroundColor Green
}
finally {
  Pop-Location
}