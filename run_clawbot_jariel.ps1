param(
  [Nullable[int]]$Port = $null,
  [switch]$Restart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".codex_home\.codex_plus_jariel"))
$repoEnv = Join-Path $repoRoot ".env"
$openClawConfig = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$logDir = Join-Path $repoRoot "logs"
$launcherLog = Join-Path $logDir ("openclaw_gateway_start_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-LauncherLog([string]$Message, [string]$Level = "INFO") {
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "s"), $Level, $Message
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  Add-Content -Path $launcherLog -Value $line
  Write-Host $line
}

function Fail([string]$Message) {
  Write-LauncherLog -Message $Message -Level "ERROR"
  Write-Error $Message
  exit 1
}

function Normalize-Path([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $null
  }

  try {
    return [System.IO.Path]::GetFullPath($Path.Trim())
  } catch {
    return $Path.Trim()
  }
}

function Get-ProcessInfo([int]$ProcessId) {
  return Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
}

function Get-OpenClawProcessChain([int]$LeafProcessId) {
  $ids = New-Object 'System.Collections.Generic.List[int]'
  $current = Get-ProcessInfo -ProcessId $LeafProcessId

  while ($current) {
    $cmd = [string]$current.CommandLine
    if ($cmd -notmatch "openclaw|gateway\.cmd|node_modules\\\\openclaw") {
      break
    }

    $processId = [int]$current.ProcessId
    if (-not $ids.Contains($processId)) {
      [void]$ids.Add($processId)
    }

    $parentId = [int]$current.ParentProcessId
    if ($parentId -le 0) {
      break
    }

    $current = Get-ProcessInfo -ProcessId $parentId
  }

  return $ids
}

$currentCodexHome = Normalize-Path $env:CODEX_HOME
if ($currentCodexHome -and $currentCodexHome -ne $codexHome) {
  Fail "CODEX_HOME ya viene definido a '$currentCodexHome'. Este launcher solo permite '$codexHome'."
}

if (-not (Test-Path $codexHome -PathType Container)) {
  Fail "CODEX_HOME no existe: $codexHome"
}

$authJson = Join-Path $codexHome "auth.json"
if (-not (Test-Path $authJson -PathType Leaf)) {
  Fail "Falta auth.json en el perfil Jariel esperado: $authJson"
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Fail "No encontre 'node' en PATH. Instala Node.js o agregalo al PATH."
}

$openclaw = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
if (-not $openclaw) {
  $openclaw = Get-Command openclaw -ErrorAction SilentlyContinue
}
if (-not $openclaw) {
  Fail "No encontre 'openclaw.cmd' ni 'openclaw' en PATH. Verifica la instalacion de OpenClaw."
}

if (Test-Path $repoEnv -PathType Leaf) {
  Get-Content $repoEnv | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      $name = $matches[1]
      $value = $matches[2].Trim().Trim('"')
      if ($name -ne "CODEX_HOME") {
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
      }
    }
  }
}

$resolvedPort = $Port
if (-not $resolvedPort -and (Test-Path $openClawConfig -PathType Leaf)) {
  try {
    $resolvedPort = (Get-Content $openClawConfig -Raw | ConvertFrom-Json).gateway.port
  } catch {
    $resolvedPort = $null
  }
}
if (-not $resolvedPort) {
  $resolvedPort = 18789
}

Set-Location $repoRoot
$env:CODEX_HOME = $codexHome
$env:WP_CODEX_BRIDGE_CODEX_HOME = $codexHome

$listener = Get-NetTCPConnection -LocalPort $resolvedPort -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($listener) {
  $proc = Get-ProcessInfo -ProcessId $listener.OwningProcess
  $cmd = if ($proc) { [string]$proc.CommandLine } else { "" }
  if ($cmd -notmatch "openclaw|gateway\.cmd|node_modules\\\\openclaw") {
    Fail "El puerto $resolvedPort esta ocupado por PID $($listener.OwningProcess) y no parece OpenClaw. No lo detuve."
  }

  if (-not $Restart) {
    Write-LauncherLog "Ya hay un gateway escuchando en el puerto $resolvedPort (PID $($listener.OwningProcess)). Usa -Restart para reiniciarlo."
    Write-LauncherLog "Proceso actual: $cmd"
    exit 0
  }

  $stopIds = Get-OpenClawProcessChain -LeafProcessId $listener.OwningProcess |
    Sort-Object -Descending -Unique
  foreach ($stopId in $stopIds) {
    Stop-Process -Id $stopId -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Seconds 2
}

$authInfo = Get-Item $authJson
Write-LauncherLog "CODEX_HOME=$env:CODEX_HOME"
Write-LauncherLog "WP_CODEX_BRIDGE_CODEX_HOME=$env:WP_CODEX_BRIDGE_CODEX_HOME"
Write-LauncherLog "AUTH_JSON=$($authInfo.FullName) | LastWriteTime=$($authInfo.LastWriteTime.ToString('s'))"
Write-LauncherLog "Usando: $($openclaw.Source) gateway run --port $resolvedPort"

& $openclaw.Source gateway run --port $resolvedPort
exit $LASTEXITCODE
