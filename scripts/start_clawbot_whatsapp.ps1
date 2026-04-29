param(
  [string]$RepoRoot = "D:\Work\bitflow_pr50_clean"
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { return }
    $name, $value = $line.Split("=", 2)
    $name = $name.Trim()
    $value = $value.Trim().Trim('"').Trim("'")
    if ($name) {
      [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
  }
}

Set-Location $RepoRoot

Write-Host "Starting Clawbot WhatsApp bridge..." -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw "Node.js is not available in PATH. Install Node.js and retry."
}

$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
  throw "npm is not available in PATH. Install Node.js/npm and retry."
}

$envFile = Join-Path $RepoRoot ".env.clawbot.local"
if (Test-Path $envFile) {
  Write-Host "Loading .env.clawbot.local" -ForegroundColor Green
  Import-DotEnv $envFile
} else {
  Write-Host ".env.clawbot.local not found. Safe defaults/examples will be used where possible." -ForegroundColor Yellow
}

$toolDir = Join-Path $RepoRoot "tools\clawbot-whatsapp"
if (-not (Test-Path $toolDir)) {
  throw "Missing tools\clawbot-whatsapp folder."
}

Set-Location $toolDir
if (-not (Test-Path "node_modules")) {
  Write-Host "Installing Clawbot WhatsApp dependencies..." -ForegroundColor Yellow
  npm install
}

Write-Host ""
Write-Host "If a QR appears, scan it from WhatsApp > Dispositivos vinculados > Vincular dispositivo." -ForegroundColor Cyan
Write-Host "Try sending: ping"
Write-Host "Press Ctrl+C to stop the bot."
Write-Host ""

npm start
