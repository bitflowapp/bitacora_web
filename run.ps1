param(
  [int]$Port = 8787,
  [switch]$Dev,
  [switch]$NoBrowser
)

$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$ErrorActionPreference = "Stop"

function Test-FlutterToolchain {
  $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
  $dartCmd = Get-Command dart -ErrorAction SilentlyContinue
  if (-not $flutterCmd -or -not $dartCmd) {
    Write-Host "Flutter no esta instalado." -ForegroundColor Yellow
    Write-Host "Instalar portable en E:\\tools\\flutter y agregar E:\\tools\\flutter\\bin al PATH."
    Write-Host "Reabrir PowerShell y correr: flutter doctor -v"
    Write-Host "Nota: solo es necesario para compilar. Para ejecutar esta release no hace falta."
    return $false
  }
  return $true
}

function Get-ContentType([string]$path) {
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  switch ($ext) {
    ".html" { return "text/html; charset=utf-8" }
    ".htm"  { return "text/html; charset=utf-8" }
    ".js"   { return "application/javascript; charset=utf-8" }
    ".mjs"  { return "application/javascript; charset=utf-8" }
    ".css"  { return "text/css; charset=utf-8" }
    ".json" { return "application/json; charset=utf-8" }
    ".wasm" { return "application/wasm" }
    ".png"  { return "image/png" }
    ".jpg"  { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".gif"  { return "image/gif" }
    ".svg"  { return "image/svg+xml" }
    ".ico"  { return "image/x-icon" }
    ".txt"  { return "text/plain; charset=utf-8" }
    ".woff" { return "font/woff" }
    ".woff2"{ return "font/woff2" }
    ".ttf"  { return "font/ttf" }
    ".otf"  { return "font/otf" }
    ".map"  { return "application/json; charset=utf-8" }
    default { return "application/octet-stream" }
  }
}

function Resolve-WebRoot([string]$base) {
  $candidates = @(
    (Join-Path $base "dist_release\\web"),
    (Join-Path $base "build\\web")
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webRoot = Resolve-WebRoot $scriptDir
if (-not $webRoot) {
  if ($Dev) {
    if (-not (Test-FlutterToolchain)) { exit 1 }
    Write-Host "Iniciando modo desarrollo (flutter run -d chrome)..." -ForegroundColor Cyan
    & flutter run -d chrome
    exit $LASTEXITCODE
  }
  if (Test-FlutterToolchain) {
    Write-Host "No se encontro build listo para servir." -ForegroundColor Yellow
    Write-Host "Buscado en: .\\dist_release\\web, .\\build\\web"
    Write-Host "Ejecutando modo desarrollo automaticamente..." -ForegroundColor Cyan
    & flutter run -d chrome
    exit $LASTEXITCODE
  }
  Write-Host "No se encontro build listo para servir." -ForegroundColor Red
  Write-Host "Buscado en: .\\dist_release\\web, .\\build\\web"
  Write-Host "Ejecute release.ps1 para generar el build (requiere Flutter)."
  exit 1
}

$webRootFull = [IO.Path]::GetFullPath($webRoot)

$listener = New-Object System.Net.HttpListener
$selectedPort = $null
for ($p = $Port; $p -lt ($Port + 15); $p++) {
  try {
    $listener.Prefixes.Clear()
    $listener.Prefixes.Add("http://localhost:$p/")
    $listener.Start()
    $selectedPort = $p
    break
  } catch {
    Start-Sleep -Milliseconds 120
  }
}

if (-not $selectedPort) {
  Write-Host "No se pudo iniciar el servidor. Puerto ocupado o bloqueado." -ForegroundColor Red
  exit 1
}

$url = "http://localhost:$selectedPort/"
Write-Host "Servidor listo en $url" -ForegroundColor Green
Write-Host "Sirviendo: $webRootFull"
if (Test-Path (Join-Path $webRootFull "config.json")) {
  Write-Host "Config: $(Join-Path $webRootFull "config.json")"
}

if (-not $NoBrowser) {
  try {
    Start-Process $url | Out-Null
  } catch {
    Write-Host "No se pudo abrir el navegador automaticamente. Abra: $url"
  }
} else {
  Write-Host "Apertura de navegador desactivada (-NoBrowser)."
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $rawPath = $request.Url.AbsolutePath
    if ([string]::IsNullOrWhiteSpace($rawPath) -or $rawPath -eq "/") {
      $rawPath = "index.html"
    } else {
      $rawPath = $rawPath.TrimStart("/")
    }

    $localPath = $rawPath -replace "/", "\"
    $fullPath = [IO.Path]::GetFullPath((Join-Path $webRootFull $localPath))

    if (-not $fullPath.StartsWith($webRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      $response.StatusCode = 403
      $response.Close()
      continue
    }

    $hasExtension = [IO.Path]::GetExtension($fullPath) -ne ""
    if (-not (Test-Path $fullPath -PathType Leaf)) {
      if (-not $hasExtension) {
        $fullPath = Join-Path $webRootFull "index.html"
      } else {
        $response.StatusCode = 404
        $response.Close()
        continue
      }
    }

    try {
      $bytes = [IO.File]::ReadAllBytes($fullPath)
      $response.ContentType = Get-ContentType $fullPath
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
      $response.StatusCode = 500
    } finally {
      $response.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
