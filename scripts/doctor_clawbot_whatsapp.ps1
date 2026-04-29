param(
  [string]$RepoRoot = "D:\Work\bitflow_pr50_clean"
)

$ErrorActionPreference = "Continue"

function Read-DotEnvMap {
  param([string]$Path)
  $map = @{}
  if (-not (Test-Path $Path)) { return $map }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { return }
    $name, $value = $line.Split("=", 2)
    $map[$name.Trim()] = $value.Trim().Trim('"').Trim("'")
  }
  return $map
}

function Write-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail = ""
  )
  $color = if ($Ok) { "Green" } else { "Yellow" }
  $mark = if ($Ok) { "OK" } else { "WARN" }
  Write-Host ("[{0}] {1} {2}" -f $mark, $Name, $Detail) -ForegroundColor $color
}

Set-Location $RepoRoot
Write-Host "Clawbot WhatsApp doctor" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"

$nodeVersion = (& node -v) 2>$null
Write-Check "Node.js" ([bool]$nodeVersion) $nodeVersion

$npmVersion = (& npm -v) 2>$null
Write-Check "npm" ([bool]$npmVersion) $npmVersion

$toolDir = Join-Path $RepoRoot "tools\clawbot-whatsapp"
Write-Check "tools\clawbot-whatsapp" (Test-Path $toolDir) $toolDir
Write-Check "package.json" (Test-Path (Join-Path $toolDir "package.json"))
Write-Check "node_modules" (Test-Path (Join-Path $toolDir "node_modules"))

$localEnv = Join-Path $RepoRoot ".env.clawbot.local"
$exampleEnv = Join-Path $RepoRoot ".env.clawbot.example"
Write-Check ".env.clawbot.example" (Test-Path $exampleEnv)
Write-Check ".env.clawbot.local" (Test-Path $localEnv) "local secrets/config are not committed"

$envMap = Read-DotEnvMap $localEnv
$allowed = $envMap["CLAWBOT_ALLOWED_PHONES"]
Write-Check "allowlist configured" (-not [string]::IsNullOrWhiteSpace($allowed)) $(if ($allowed) { "configured" } else { "missing: bot will start safe and answer nobody" })

$allowGroups = $envMap["CLAWBOT_ALLOW_GROUPS"]
Write-Check "groups disabled" ($allowGroups -ne "true") "CLAWBOT_ALLOW_GROUPS=$allowGroups"

$sessionRoot = if ($envMap["CLAWBOT_SESSION_PATH"]) {
  Join-Path $RepoRoot $envMap["CLAWBOT_SESSION_PATH"]
} else {
  Join-Path $RepoRoot ".clawbot-whatsapp-session"
}
Write-Check "session folder" (Test-Path $sessionRoot) $sessionRoot

$logDir = Join-Path $RepoRoot "logs"
Write-Check "logs folder" (Test-Path $logDir) $logDir

$port = $envMap["CLAWBOT_PORT"]
if ($port) {
  $inUse = Get-NetTCPConnection -LocalPort ([int]$port) -ErrorAction SilentlyContinue
  Write-Check "port $port" (-not $inUse) $(if ($inUse) { "in use" } else { "available" })
} else {
  Write-Check "port" $true "not required by whatsapp-web.js bridge"
}

Write-Host ""
Write-Host "Doctor finished. Warnings may be normal before first install/login." -ForegroundColor Cyan
