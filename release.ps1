param(
  [string]$Flutter = "flutter",
  [switch]$Clean
)

$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$ErrorActionPreference = "Stop"

$flutterCmd = Get-Command $Flutter -ErrorAction SilentlyContinue
$dartCmd = Get-Command dart -ErrorAction SilentlyContinue
if (-not $flutterCmd -or -not $dartCmd) {
  Write-Host "Flutter no esta instalado." -ForegroundColor Red
  Write-Host "Instalar portable en E:\\tools\\flutter y agregar E:\\tools\\flutter\\bin al PATH."
  Write-Host "Reabrir PowerShell y correr: flutter doctor -v"
  exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$distDir = Join-Path $scriptDir "dist_release"
$legacyDir = Join-Path $scriptDir "_legacy"

if (Test-Path $distDir) {
  if (-not (Test-Path $legacyDir)) {
    New-Item -ItemType Directory -Path $legacyDir | Out-Null
  }
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $backup = Join-Path $legacyDir "dist_release_$stamp"
  Move-Item -Path $distDir -Destination $backup
}

Write-Host "Construyendo Flutter Web (release)..." -ForegroundColor Cyan
if ($Clean) {
  & $Flutter clean
}
& $Flutter pub get
& $Flutter build web --release

$webBuild = Join-Path $scriptDir "build\\web"
if (-not (Test-Path $webBuild)) {
  Write-Host "No se encontro build/web. Fallo el build." -ForegroundColor Red
  exit 1
}

# Copiar config editable al build final (si Flutter no lo incluyo)
if (Test-Path (Join-Path $scriptDir "web\\config.json")) {
  Copy-Item -Path (Join-Path $scriptDir "web\\config.json") -Destination (Join-Path $webBuild "config.json") -Force
}
if (Test-Path (Join-Path $scriptDir "web\\config.example.json")) {
  Copy-Item -Path (Join-Path $scriptDir "web\\config.example.json") -Destination (Join-Path $webBuild "config.example.json") -Force
}

New-Item -ItemType Directory -Path $distDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $distDir "web") | Out-Null
Copy-Item -Path (Join-Path $webBuild "*") -Destination (Join-Path $distDir "web") -Recurse

Copy-Item -Path (Join-Path $scriptDir "run.ps1") -Destination $distDir
if (Test-Path (Join-Path $scriptDir "run.bat")) {
  Copy-Item -Path (Join-Path $scriptDir "run.bat") -Destination $distDir
}
if (Test-Path (Join-Path $scriptDir "README_CLIENTE.md")) {
  Copy-Item -Path (Join-Path $scriptDir "README_CLIENTE.md") -Destination $distDir
} else {
  Copy-Item -Path (Join-Path $scriptDir "README.md") -Destination $distDir
}
Copy-Item -Path (Join-Path $scriptDir "CHANGELOG.md") -Destination $distDir
if (Test-Path (Join-Path $scriptDir "QA_CHECKLIST.md")) {
  Copy-Item -Path (Join-Path $scriptDir "QA_CHECKLIST.md") -Destination $distDir
}
if (Test-Path (Join-Path $scriptDir "QA_REPORT.md")) {
  Copy-Item -Path (Join-Path $scriptDir "QA_REPORT.md") -Destination $distDir
}
if (Test-Path (Join-Path $scriptDir "LICENSE")) {
  Copy-Item -Path (Join-Path $scriptDir "LICENSE") -Destination $distDir
}
Copy-Item -Path (Join-Path $scriptDir ".env.example") -Destination $distDir

# Config editable para el cliente (web/config.json)
if (Test-Path (Join-Path $scriptDir "web\\config.json")) {
  Copy-Item -Path (Join-Path $scriptDir "web\\config.json") -Destination (Join-Path $distDir "web\\config.json") -Force
}
if (Test-Path (Join-Path $scriptDir "web\\config.example.json")) {
  Copy-Item -Path (Join-Path $scriptDir "web\\config.example.json") -Destination (Join-Path $distDir "web\\config.example.json") -Force
  Copy-Item -Path (Join-Path $scriptDir "web\\config.example.json") -Destination (Join-Path $distDir "config.example.json") -Force
}

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$zipName = "bitacora_web_RELEASE_$stamp.zip"
$zipPath = Join-Path $scriptDir $zipName

if (Test-Path $zipPath) {
  if (-not (Test-Path $legacyDir)) {
    New-Item -ItemType Directory -Path $legacyDir | Out-Null
  }
  $zipStamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $zipBackup = Join-Path $legacyDir "bitacora_web_RELEASE_$zipStamp.zip"
  Move-Item -Path $zipPath -Destination $zipBackup
}

Compress-Archive -Path (Join-Path $distDir "*") -DestinationPath $zipPath

Write-Host "Release listo: $zipPath" -ForegroundColor Green
